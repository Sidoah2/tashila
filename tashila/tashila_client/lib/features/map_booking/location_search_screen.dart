import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tashila_client/core/config/map_config.dart';
import 'package:tashila_client/core/data/neighborhoods.dart';
import 'package:tashila_client/core/formatting/app_format.dart';
import 'package:tashila_client/core/services/places_service.dart';
import 'package:tashila_client/core/state/app_state.dart';
import 'package:tashila_client/core/theme/app_colors.dart';

class LocationSearchScreen extends ConsumerStatefulWidget {
  const LocationSearchScreen({super.key, required this.isPickup});

  final bool isPickup;

  @override
  ConsumerState<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends ConsumerState<LocationSearchScreen> {
  final _focusNode = FocusNode();
  final _controller = TextEditingController();
  Timer? _debounce;

  List<PlacePrediction> _predictions = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<(double, double)> _biasCoords() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      if (p != null) return (p.latitude, p.longitude);
    } catch (_) {}
    final s = ref.read(appStateProvider);
    return (s.pickupLat, s.pickupLng);
  }

  Future<void> _runSearch(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) {
      setState(() {
        _predictions = [];
        _loading = false;
      });
      return;
    }

    if (!MapConfig.canRenderGoogleMap) {
      setState(() => _predictions = []);
      return;
    }

    setState(() => _loading = true);
    try {
      final places = ref.read(placesServiceProvider);
      final lang = context.locale.languageCode;
      final bias = await _biasCoords();
      final list = await places.autocomplete(
        input: query,
        language: lang,
        biasLat: bias.$1,
        biasLng: bias.$2,
      );
      if (!mounted) return;
      setState(() {
        _predictions = list;
        _loading = false;
      });
    } on PlacesException catch (e) {
      if (!mounted) return;
      setState(() {
        _predictions = [];
        _loading = false;
      });
      _showPlacesError(e);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _predictions = [];
        _loading = false;
      });
      _showErrorSnack('places_network_error'.tr());
    }
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _showPlacesError(PlacesException e) {
    final String text;
    if (e.status == 'REQUEST_DENIED') {
      text = 'places_error_request_denied'.tr();
    } else if (e.status == 'OVER_QUERY_LIMIT' || e.status == 'RESOURCE_EXHAUSTED') {
      text = 'places_error_quota'.tr();
    } else {
      text = 'places_error'.tr();
    }
    final detail = (kDebugMode &&
            e.googleErrorMessage != null &&
            e.googleErrorMessage!.isNotEmpty)
        ? '$text\n\n[Debug] ${e.googleErrorMessage}'
        : text;
    _showErrorSnack(detail);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(value));
  }

  Future<void> _selectPrediction(PlacePrediction p) async {
    if (!MapConfig.canRenderGoogleMap) {
      _showErrorSnack('places_error'.tr());
      return;
    }
    setState(() => _loading = true);
    try {
      final places = ref.read(placesServiceProvider);
      final details = await places.placeDetails(
        placeId: p.placeId,
        language: context.locale.languageCode,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (details == null) {
        _showErrorSnack('places_error'.tr());
        return;
      }
      final label = details.formattedAddress.isNotEmpty
          ? details.formattedAddress
          : p.description;
      await _applySelection(label, details.lat, details.lng);
    } on PlacesException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showPlacesError(e);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showErrorSnack('places_network_error'.tr());
    }
  }

  Future<bool> _coordinatesInAlgeria(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return true;
      final code = marks.first.isoCountryCode;
      if (code == null || code.isEmpty) return true;
      return code.toUpperCase() == 'DZ';
    } catch (_) {
      return false;
    }
  }

  Future<void> _applySelection(String label, double lat, double lng) async {
    final inDz = await _coordinatesInAlgeria(lat, lng);
    if (!mounted) return;
    if (!inDz) {
      _showErrorSnack('service_area_unavailable'.tr());
      return;
    }
    final inService = coordinatesInSupportedServiceArea(lat, lng);
    final notifier = ref.read(appStateProvider.notifier);
    if (widget.isPickup) {
      notifier.setPickupPlace(
        label: label,
        lat: lat,
        lng: lng,
        inServiceArea: inService,
      );
    } else {
      notifier.setDropoffPlace(
        label: label,
        lat: lat,
        lng: lng,
        inServiceArea: inService,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _selectQuickPick(NeighborhoodPick pick) async {
    if (!pick.supported) {
      _showErrorSnack('service_not_in_area_message'.tr());
      return;
    }
    final label = pick.labelForLocale(context.locale.languageCode);
    await _applySelection(label, pick.lat, pick.lng);
  }

  Future<void> _useCurrentLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _showErrorSnack('location_disabled'.tr());
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
      _showErrorSnack('location_permission_denied'.tr());
      return;
    }

    setState(() => _loading = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      String label;
      try {
        final marks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (marks.isNotEmpty) {
          final m = marks.first;
          final parts = <String>[];
          for (final raw in [m.street, m.subLocality, m.locality, m.country]) {
            if (raw != null && raw.trim().isNotEmpty) parts.add(raw.trim());
          }
          label = parts.isEmpty
              ? ltrNumber(
                  '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
                )
              : parts.join(', ');
        } else {
          label = ltrNumber(
            '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
          );
        }
      } catch (_) {
        label = ltrNumber(
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
        );
      }
      if (!mounted) return;
      setState(() => _loading = false);
      if (!coordinatesInSupportedServiceArea(position.latitude, position.longitude)) {
        _showErrorSnack('service_not_in_area_message'.tr());
        return;
      }
      final snap = nearestSupportedNeighborhood(position.latitude, position.longitude);
      if (snap != null &&
          neighborhoodDistanceKm(
                position.latitude,
                position.longitude,
                snap.lat,
                snap.lng,
              ) <=
              4) {
        await _applySelection(
          snap.labelForLocale(context.locale.languageCode),
          snap.lat,
          snap.lng,
        );
      } else {
        await _applySelection(label, position.latitude, position.longitude);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showErrorSnack('location_error'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final lang = context.locale.languageCode;
    final quick = NeighborhoodPick.matching(query, languageCode: lang);
    final showQuick = _predictions.isEmpty && (query.isNotEmpty || _loading == false);
    final title = widget.isPickup ? 'choose_pickup_title'.tr() : 'choose_destination_title'.tr();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Card(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'search_address_hint'.tr(),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search, color: AppColors.brandOrange),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                ),
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _loading ? null : _useCurrentLocation,
              icon: const Icon(Icons.gps_fixed, size: 22),
              label: Text(
                'use_current_location'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'gps_location_hint'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              children: [
                if (_predictions.isNotEmpty)
                  ..._predictions.map(
                    (p) => ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: _loading ? null : () => _selectPrediction(p),
                    ),
                  ),
                if (_predictions.isEmpty && showQuick && quick.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'booking_neighborhoods_title'.tr(),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  ...quick.map(
                    (e) => ListTile(
                      leading: const Icon(Icons.location_city_outlined),
                      title: Text(e.labelForLocale(lang)),
                      onTap: _loading ? null : () => _selectQuickPick(e),
                    ),
                  ),
                ],
                if (_predictions.isEmpty &&
                    query.isNotEmpty &&
                    !_loading &&
                    quick.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'no_search_results'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
