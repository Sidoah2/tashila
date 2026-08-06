import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/support_config.dart';
import '../../core/formatting/app_format.dart';
import '../../core/models/models.dart';
import '../../core/state/driver_app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/confirm_logout.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/utils/picked_image_io.dart';
import '../../core/widgets/upload_image_preview.dart';
import '../auth/auth_language_menu.dart';
import 'local_profile_avatar.dart';

enum _MediaPickSource { camera, gallery, files }

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  String? _truckType;
  bool _didAttemptSubmit = false;
  String? _truckTypeError;
  String? _vehiclePlateError;
  String? _vehicleColorError;
  String? _vehicleModelError;
  String? _documentsError;
  String? _profilePhotoError;
  int _wizardStep = 0;
  Timer? _approvalPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncApprovalPolling();
      ref.read(driverAppStateProvider.notifier).syncPlatformEarningsFromServer();
    });
  }

  @override
  void dispose() {
    _approvalPollTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _vehiclePlateController.dispose();
    _vehicleColorController.dispose();
    _vehicleModelController.dispose();
    super.dispose();
  }

  void _syncApprovalPolling() {
    if (!mounted) return;
    final profile = ref.read(driverAppStateProvider).profile;
    final awaiting = profile != null &&
        profile.isComplete &&
        !profile.documentsApproved;
    if (awaiting && _approvalPollTimer == null) {
      _approvalPollTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
        await ref.read(driverAppStateProvider.notifier).syncApprovalFromServer();
        if (!mounted) return;
        if (!(ref.read(driverAppStateProvider).profile?.isReadyForDashboard ??
            false)) {
          return;
        }
        context.go('/home');
      });
    } else if (!awaiting) {
      _approvalPollTimer?.cancel();
      _approvalPollTimer = null;
    }
  }

  void _showAboutTashilaDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('profile_about'.tr()),
        content: SingleChildScrollView(
          child: Text(
            'driver_profile_about_body'.tr(),
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).closeButtonLabel),
          ),
        ],
      ),
    );
  }

  void _showLegalScrollSheet(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              body,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).closeButtonLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/$kSupportWhatsAppDigits');
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showDeleteAccountDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _DeleteAccountDialogContent(
        onConfirmDelete: () async {
          Navigator.pop(ctx);
          await ref.read(driverAppStateProvider.notifier).deleteAccount();
          if (mounted) context.go('/login');
        },
      ),
    );
  }

  Future<_MediaPickSource?> _showMediaSourceSheet() {
    return showModalBottomSheet<_MediaPickSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text('doc_pick_camera'.tr()),
              onTap: () => Navigator.pop(ctx, _MediaPickSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('doc_pick_gallery'.tr()),
              onTap: () => Navigator.pop(ctx, _MediaPickSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text('doc_pick_files'.tr()),
              onTap: () => Navigator.pop(ctx, _MediaPickSource.files),
            ),
          ],
        ),
      ),
    );
  }

  String _fileNameFromXFile(XFile file, String fallbackPrefix) {
    final n = file.name.trim();
    if (n.isNotEmpty) return n;
    return '${fallbackPrefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  Future<void> _pickProfilePhoto() async {
    if (!mounted) return;
    final source = await _showMediaSourceSheet();
    if (!mounted || source == null) return;

    final picker = ImagePicker();
    String? path;

    switch (source) {
      case _MediaPickSource.camera:
        final x = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        if (x != null) {
          path = await persistPickedImage(x, 'profile_photo');
        }
        break;
      case _MediaPickSource.gallery:
        final xg = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (xg != null) {
          path = await persistPickedImage(xg, 'profile_photo');
        }
        break;
      case _MediaPickSource.files:
        final result = await FilePicker.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: false,
        );
        if (result != null && result.files.isNotEmpty) {
          path = result.files.single.path;
        }
        break;
    }

    if (path == null || !mounted) return;
    await ref.read(driverAppStateProvider.notifier).setProfilePhotoPath(path);
  }

  Future<void> _pickDocument(DocumentType type) async {
    final notifier = ref.read(driverAppStateProvider.notifier);
    if (!mounted) return;
    final source = await _showMediaSourceSheet();
    if (!mounted || source == null) return;

    final picker = ImagePicker();
    String? fileName;

    switch (source) {
      case _MediaPickSource.camera:
        final x = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        if (x != null) {
          fileName = _fileNameFromXFile(x, type.name);
          final stablePath = await persistPickedImage(x, type.name);
          if (!mounted) return;
          await notifier.uploadDocument(
            type,
            fileName: fileName,
            filePath: stablePath,
          );
          return;
        }
        break;
      case _MediaPickSource.gallery:
        final xg = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (xg != null) {
          fileName = _fileNameFromXFile(xg, type.name);
          final stablePath = await persistPickedImage(xg, type.name);
          if (!mounted) return;
          await notifier.uploadDocument(
            type,
            fileName: fileName,
            filePath: stablePath,
          );
          return;
        }
        break;
      case _MediaPickSource.files:
        final result = await FilePicker.pickFiles(
          allowMultiple: false,
          withData: false,
        );
        if (result != null && result.files.isNotEmpty) {
          final f = result.files.single;
          fileName = f.name.isNotEmpty
              ? f.name
              : '${type.name}_${DateTime.now().millisecondsSinceEpoch}';
          final path = f.path;
          if (path != null && mounted) {
            await notifier.uploadDocument(
              type,
              fileName: fileName,
              filePath: path,
            );
          }
        }
        break;
    }

    if (!mounted) return;
    final updated = ref.read(driverAppStateProvider).profile;
    if (updated != null &&
        updated.documents.every(
          (d) => d.hasUploadedImage,
        )) {
      setState(() => _documentsError = null);
    }
  }

  String _docLabel(DocumentType type) {
    switch (type) {
      case DocumentType.drivingLicense:
        return 'doc_driving_license'.tr();
      case DocumentType.vehicleRegistration:
        return 'doc_vehicle_registration'.tr();
      case DocumentType.vehiclePhoto:
        return 'doc_vehicle_photo'.tr();
    }
  }

  String _docSubtitle(DocumentType type) {
    switch (type) {
      case DocumentType.drivingLicense:
        return 'driver_verify_doc_sub_license'.tr();
      case DocumentType.vehicleRegistration:
        return 'driver_verify_doc_sub_registration'.tr();
      case DocumentType.vehiclePhoto:
        return 'driver_verify_doc_sub_vehicle_photo'.tr();
    }
  }

  String _truckLabel(String type) {
    final normalized = migrateTruckType(type);
    return normalized == kTruckDoubleCabin
        ? 'truck_double_cabin'.tr()
        : 'truck_single_cabin'.tr();
  }

  String _wizardStepTitle() {
    switch (_wizardStep) {
      case 0:
        return 'driver_verify_step1_title'.tr();
      case 1:
        return 'driver_verify_step2_title'.tr();
      default:
        return 'driver_verify_step3_title'.tr();
    }
  }

  String _wizardStepSubtitle() {
    switch (_wizardStep) {
      case 0:
        return 'driver_verify_step1_subtitle'.tr();
      case 1:
        return 'driver_verify_step2_subtitle'.tr();
      default:
        return 'driver_verify_step3_subtitle'.tr();
    }
  }

  /// [Form] is only mounted on step 0; on later steps [FormState] is null.
  bool _validateWizardNameAndPhone() {
    final formState = _formKey.currentState;
    if (formState != null) {
      return formState.validate();
    }
    final name = _nameController.text.trim();
    final raw = _phoneController.text.trim();
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return name.length >= 2 && raw.isNotEmpty && digits.length >= 8;
  }

  Future<void> _onWizardPrimaryAction({
    required DriverAppState state,
    required DriverAppNotifier notifier,
    required DriverProfile profile,
    required bool allDocsUploaded,
    required bool awaitingApproval,
  }) async {
    if (_wizardStep == 2 && awaitingApproval) {
      await notifier.syncApprovalFromServer();
      if (!mounted) return;
      if (!(ref.read(driverAppStateProvider).profile?.isReadyForDashboard ??
          false)) {
        return;
      }
      context.go('/home');
      return;
    }

    if (_wizardStep == 0) {
      setState(() {
        _didAttemptSubmit = true;
        _profilePhotoError =
            profile.profilePhotoPath == null ||
                profile.profilePhotoPath!.isEmpty
            ? 'validation_required_profile_photo'.tr()
            : null;
      });
      final formOk = _formKey.currentState?.validate() ?? false;
      if (!formOk || _profilePhotoError != null) return;
      setState(() => _wizardStep = 1);
      return;
    }

    if (_wizardStep == 1) {
      if (!allDocsUploaded) {
        setState(
          () => _documentsError = 'validation_required_documents'.tr(),
        );
        return;
      }
      setState(() {
        _documentsError = null;
        _wizardStep = 2;
      });
      return;
    }

    if (_wizardStep == 2) {
      setState(() {
        _didAttemptSubmit = true;
        _truckTypeError = isValidCabinTruckType(_truckType ?? '')
            ? null
            : 'validation_required_truck_type'.tr();
        _vehiclePlateError = _vehiclePlateController.text.trim().length >= 2
            ? null
            : 'validation_required_vehicle_plate'.tr();
        _vehicleColorError = _vehicleColorController.text.trim().isNotEmpty
            ? null
            : 'validation_required_vehicle_color'.tr();
        _vehicleModelError = _vehicleModelController.text.trim().isNotEmpty
            ? null
            : 'validation_required_vehicle_model'.tr();
        _documentsError = null;
        _profilePhotoError = null;
      });
      if (!_validateWizardNameAndPhone() ||
          _truckTypeError != null ||
          _vehiclePlateError != null ||
          _vehicleColorError != null ||
          _vehicleModelError != null) {
        return;
      }
      await notifier.saveProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        truckType: _truckType,
        vehiclePlate: _vehiclePlateController.text.trim(),
        vehicleColor: _vehicleColorController.text.trim(),
        vehicleModel: _vehicleModelController.text.trim(),
      );
      if (!mounted) return;
      await notifier.syncApprovalFromServer();
      if (!mounted) return;
      _syncApprovalPolling();
      if (!(ref.read(driverAppStateProvider).profile?.isReadyForDashboard ??
          false)) {
        return;
      }
      context.go('/home');
    }
  }

  Widget _infoCallout(BuildContext context, String text) {
    final base = Theme.of(context).textTheme.bodyMedium;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.brandOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.brandOrange.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline,
              color: AppColors.brandOrange,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SelectionContainer.disabled(
                child: Text(
                  text,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    inherit: false,
                    color: AppColors.textPrimary,
                    fontFamily: base?.fontFamily,
                    fontFamilyFallback: base?.fontFamilyFallback,
                    fontSize: base?.fontSize ?? 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    letterSpacing: base?.letterSpacing,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationWizard({
    required BuildContext context,
    required DriverAppState state,
    required DriverAppNotifier notifier,
    required DriverProfile profile,
    required bool allDocsUploaded,
    required bool awaitingApproval,
  }) {
    final bottomAwaiting = _wizardStep == 2 && awaitingApproval;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'back'.tr(),
                onPressed: state.isBusy
                    ? null
                    : () {
                        if (_wizardStep > 0) {
                          setState(() => _wizardStep--);
                        } else if (context.canPop()) {
                          context.pop();
                        }
                      },
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(child: _WizardProgressBar(step: _wizardStep)),
              const AuthLanguageMenu(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'driver_verify_step_fraction'.tr(
              namedArgs: {
                'current': '${_wizardStep + 1}',
                'total': '3',
              },
            ),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _wizardStepTitle(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _wizardStepSubtitle(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_wizardStep == 0) ...[
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: !state.isBusy ? _pickProfilePhoto : null,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              buildLocalProfileAvatar(
                                path: profile.profilePhotoPath,
                                networkUrl: profile.avatarUrl,
                                radius: 48,
                              ),
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: Material(
                                  color: AppColors.brandOrange,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: state.isBusy
                                        ? null
                                        : _pickProfilePhoto,
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: state.isBusy ? null : _pickProfilePhoto,
                          child: Text('profile_photo_upload'.tr()),
                        ),
                        if (_profilePhotoError != null)
                          Text(
                            _profilePhotoError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    autovalidateMode: _didAttemptSubmit
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: Material(
                      color: AppColors.card,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'name_label'.tr(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'validation_required_name'.tr();
                                }
                                if (value.trim().length < 2) {
                                  return 'validation_short_name'.tr();
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'profile_onboarding_email_optional'.tr(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'phone_label'.tr(),
                              ),
                              validator: (value) {
                                final raw = value?.trim() ?? '';
                                if (raw.isEmpty) {
                                  return 'validation_required_phone'.tr();
                                }
                                final digitsOnly =
                                    raw.replaceAll(RegExp(r'[^0-9]'), '');
                                if (digitsOnly.length < 8) {
                                  return 'validation_invalid_phone'.tr();
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (_wizardStep == 1) ...[
                  _infoCallout(context, 'driver_verify_docs_callout'.tr()),
                  const SizedBox(height: 16),
                  Material(
                    color: AppColors.card,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        for (final doc in profile.documents)
                          ListTile(
                            leading: UploadImagePreview(
                              localPath: doc.localFilePath,
                              remoteUrl: doc.displayRemoteUrl,
                              width: 52,
                              height: 52,
                              borderRadius: 10,
                              placeholder: Icon(
                                Icons.description_outlined,
                                color: AppColors.brandOrange,
                              ),
                            ),
                            title: Text(_docLabel(doc.type)),
                            subtitle: Text(
                              doc.hasUploadedImage
                                  ? (doc.displaySubtitle ??
                                      'doc_uploaded'.tr())
                                  : _docSubtitle(doc.type),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: TextButton(
                              onPressed: state.isBusy
                                  ? null
                                  : () => _pickDocument(doc.type),
                              child: Text(
                                doc.hasUploadedImage
                                    ? 'replace'.tr()
                                    : 'upload'.tr(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_documentsError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _documentsError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
                if (_wizardStep == 2) ...[
                  _infoCallout(context, 'driver_verify_vehicle_callout'.tr()),
                  const SizedBox(height: 16),
                  _VehicleTypeCard(
                    title: _truckLabel(kTruckSingleCabin),
                    subtitle: 'driver_verify_vehicle_single_sub'.tr(),
                    assetImage: 'assets/images/singlecabin_icon.png',
                    selected: _truckType == kTruckSingleCabin,
                    onTap: state.isBusy
                        ? null
                        : () => setState(() {
                            _truckType = kTruckSingleCabin;
                            _truckTypeError = null;
                          }),
                  ),
                  const SizedBox(height: 12),
                  _VehicleTypeCard(
                    title: _truckLabel(kTruckDoubleCabin),
                    subtitle: 'driver_verify_vehicle_double_sub'.tr(),
                    assetImage: 'assets/images/doublecabin_icon.png',
                    selected: _truckType == kTruckDoubleCabin,
                    onTap: state.isBusy
                        ? null
                        : () => setState(() {
                            _truckType = kTruckDoubleCabin;
                            _truckTypeError = null;
                          }),
                  ),
                  if (_truckTypeError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _truckTypeError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Material(
                    color: AppColors.card,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _vehicleModelController,
                            decoration: InputDecoration(
                              labelText: 'vehicle_model_label'.tr(),
                              hintText: 'vehicle_model_hint'.tr(),
                              errorText: _vehicleModelError,
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _vehicleColorController,
                            decoration: InputDecoration(
                              labelText: 'vehicle_color_label'.tr(),
                              hintText: 'vehicle_color_hint'.tr(),
                              errorText: _vehicleColorError,
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _vehiclePlateController,
                            decoration: InputDecoration(
                              labelText: 'vehicle_plate_label'.tr(),
                              hintText: 'vehicle_plate_hint'.tr(),
                              errorText: _vehiclePlateError,
                            ),
                            textInputAction: TextInputAction.done,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (bottomAwaiting) ...[
                    const SizedBox(height: 20),
                    Material(
                      color: AppColors.card,
                      elevation: 2,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'doc_review_title'.tr(),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'doc_review_body'.tr(),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: PrimaryButton(
            label: bottomAwaiting
                ? 'doc_review_check_status'.tr()
                : 'continue'.tr(),
            icon: bottomAwaiting ? Icons.refresh_rounded : Icons.arrow_forward,
            isBusy: state.isBusy,
            onPressed: state.isBusy
                ? null
                : () => _onWizardPrimaryAction(
                    state: state,
                    notifier: notifier,
                    profile: profile,
                    allDocsUploaded: allDocsUploaded,
                    awaitingApproval: awaitingApproval,
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverAppStateProvider);
    final notifier = ref.read(driverAppStateProvider.notifier);
    final profile = state.profile ?? DriverProfile.empty();
    final inInitialSetup = state.needsProfileSetup;
    final allDocsUploaded = profile.documents.isNotEmpty &&
        profile.documents.every((d) => d.hasUploadedImage);
    final awaitingApproval =
        profile.isComplete && !profile.documentsApproved;

    ref.listen<DriverAppState>(driverAppStateProvider, (_, __) {
      _syncApprovalPolling();
    });

    if (_nameController.text.isEmpty) {
      _nameController.text = profile.name;
      _phoneController.text = profile.phone;
      _emailController.text = profile.email;
      _vehiclePlateController.text = profile.vehiclePlate;
      _vehicleColorController.text = profile.vehicleColor;
      _vehicleModelController.text = profile.vehicleModel;
      if (isValidCabinTruckType(profile.truckType)) {
        _truckType = profile.truckType;
      }
    }

    if (inInitialSetup) {
      return ColoredBox(
        color: AppColors.bg,
        child: SafeArea(
          child: _buildVerificationWizard(
            context: context,
            state: state,
            notifier: notifier,
            profile: profile,
            allDocsUploaded: allDocsUploaded,
            awaitingApproval: awaitingApproval,
          ),
        ),
      );
    }

    return ColoredBox(
      color: AppColors.bg,
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'profile_title'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: buildLocalProfileAvatar(
                    path: profile.profilePhotoPath,
                    networkUrl: profile.avatarUrl,
                    radius: 48,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _ProfileOverviewCard(
                  tripHistory: state.tripHistory,
                  platformEarnings: state.platformEarnings,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: Form(
                  key: _formKey,
                  autovalidateMode: _didAttemptSubmit
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: Material(
                    color: AppColors.card,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'name_label'.tr(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'validation_required_name'.tr();
                              }
                              if (value.trim().length < 2) {
                                return 'validation_short_name'.tr();
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'profile_onboarding_email_optional'.tr(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'phone_label'.tr(),
                            ),
                            validator: (value) {
                              final raw = value?.trim() ?? '';
                              if (raw.isEmpty) {
                                return 'validation_required_phone'.tr();
                              }
                              final digitsOnly =
                                  raw.replaceAll(RegExp(r'[^0-9]'), '');
                              if (digitsOnly.length < 8) {
                                return 'validation_invalid_phone'.tr();
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Material(
                  color: AppColors.card,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'truck_type_label'.tr(),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Text(
                                _truckLabel(profile.truckType),
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (profile.vehicleModel.trim().isNotEmpty ||
                                profile.vehicleColor.trim().isNotEmpty ||
                                profile.vehiclePlate.trim().isNotEmpty)
                              Text(
                                [
                                  profile.vehicleModel.trim(),
                                  profile.vehicleColor.trim(),
                                  profile.vehiclePlate.trim(),
                                ].where((p) => p.isNotEmpty).join(' · '),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Material(
                  color: AppColors.card,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'language'.tr(),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _LangChip(
                              label: 'lang_en'.tr(),
                              locale: const Locale('en'),
                            ),
                            _LangChip(
                              label: 'lang_ar'.tr(),
                              locale: const Locale('ar'),
                            ),
                            _LangChip(
                              label: 'lang_fr'.tr(),
                              locale: const Locale('fr'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'profile_section_help'.tr(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Material(
                  color: AppColors.card,
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.06),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: AppColors.textSecondary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.lightbulb_outline_rounded,
                          color: AppColors.textSecondary,
                        ),
                        title: Text(
                          'profile_legal_tips_title'.tr(),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        onTap: () => _showLegalScrollSheet(
                          'profile_legal_tips_title'.tr(),
                          'driver_legal_tips_body'.tr(),
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: AppColors.textSecondary.withValues(alpha: 0.1),
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.article_outlined,
                          color: AppColors.textSecondary,
                        ),
                        title: Text(
                          'profile_legal_terms_title'.tr(),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        onTap: () => _showLegalScrollSheet(
                          'profile_legal_terms_title'.tr(),
                          'driver_legal_terms_body'.tr(),
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: AppColors.textSecondary.withValues(alpha: 0.1),
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.privacy_tip_outlined,
                          color: AppColors.textSecondary,
                        ),
                        title: Text(
                          'profile_legal_privacy_title'.tr(),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        onTap: () => _showLegalScrollSheet(
                          'profile_legal_privacy_title'.tr(),
                          'driver_legal_privacy_body'.tr(),
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: AppColors.textSecondary.withValues(alpha: 0.1),
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.chat_outlined,
                          color: AppColors.brandOrange,
                        ),
                        title: Text(
                          'profile_support_whatsapp'.tr(),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        onTap: _openWhatsApp,
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: AppColors.textSecondary.withValues(alpha: 0.1),
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.textSecondary,
                        ),
                        title: Text(
                          'profile_about'.tr(),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        onTap: _showAboutTashilaDialog,
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: AppColors.textSecondary.withValues(alpha: 0.1),
                      ),
                      Semantics(
                        button: true,
                        label: 'profile_delete_account'.tr(),
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_forever_outlined,
                            color: Colors.red.shade700,
                          ),
                          title: Text(
                            'profile_delete_account'.tr(),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade800,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.red.shade200,
                          ),
                          onTap: _showDeleteAccountDialog,
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: AppColors.textSecondary.withValues(alpha: 0.1),
                      ),
                      const _DriverProfileVersionTile(),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              sliver: SliverToBoxAdapter(
                child: OutlinedButton(
                  onPressed: () => confirmDriverLogout(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade200),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'logout'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverProfileVersionTile extends StatefulWidget {
  const _DriverProfileVersionTile();

  @override
  State<_DriverProfileVersionTile> createState() =>
      _DriverProfileVersionTileState();
}

class _DriverProfileVersionTileState extends State<_DriverProfileVersionTile> {
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snap) {
        final v = snap.data?.version ?? '…';
        final b = snap.data?.buildNumber ?? '';
        final line = b.isEmpty ? v : '$v ($b)';
        return ListTile(
          leading: Icon(
            Icons.verified_outlined,
            color: AppColors.textSecondary,
          ),
          title: Text(
            'profile_app_version_label'.tr(),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Text(
            line,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}

class _WizardProgressBar extends StatelessWidget {
  const _WizardProgressBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final filled = i <= step;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              decoration: BoxDecoration(
                color: filled
                    ? AppColors.brandOrange
                    : AppColors.textSecondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _VehicleTypeCard extends StatelessWidget {
  const _VehicleTypeCard({
    required this.title,
    required this.subtitle,
    required this.assetImage,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String assetImage;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      elevation: selected ? 3 : 1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.brandOrange
                  : AppColors.textSecondary.withValues(alpha: 0.2),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Image.asset(
                  assetImage,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.brandOrange),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileOverviewCard extends StatelessWidget {
  const _ProfileOverviewCard({
    required this.tripHistory,
    this.platformEarnings,
  });

  final List<TripRecord> tripHistory;
  final DriverPlatformEarnings? platformEarnings;

  @override
  Widget build(BuildContext context) {
    final trips = tripHistory;
    final totalEarnings = trips.fold<double>(0, (s, t) => s + t.fare);
    final rated = trips.where((t) => t.rating != null).toList();
    final avgRating = rated.isEmpty
        ? 0.0
        : rated.map((t) => t.rating!.toDouble()).reduce((a, b) => a + b) /
            rated.length;
    final money = dzdCurrency();
    final platform = platformEarnings ?? const DriverPlatformEarnings();

    return Material(
      color: AppColors.card,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'profile_overview_title'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _statRow(
              context,
              'profile_stat_completed_trips'.tr(),
              westernDigits('${trips.length}'),
            ),
            const SizedBox(height: 10),
            _statRow(
              context,
              'profile_stat_avg_rating'.tr(),
              westernDigits(avgRating > 0 ? avgRating.toStringAsFixed(1) : '—'),
            ),
            const SizedBox(height: 10),
            _statRow(
              context,
              'profile_stat_total_earnings'.tr(),
              money.format(totalEarnings),
            ),
            const SizedBox(height: 10),
            _statRow(
              context,
              'earnings_platform_due'.tr(),
              money.format(platform.platformDueDzd),
            ),
            const SizedBox(height: 10),
            _statRow(
              context,
              'earnings_platform_paid'.tr(),
              money.format(platform.paidDzd),
            ),
            const SizedBox(height: 10),
            _statRow(
              context,
              'earnings_platform_net'.tr(),
              money.format(platform.netDzd),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({required this.label, required this.locale});

  final String label;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final selected = context.locale.languageCode == locale.languageCode;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.brandOrange.withValues(alpha: 0.22),
      checkmarkColor: AppColors.brandOrange,
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        color: selected ? AppColors.brandOrange : AppColors.textSecondary,
      ),
      side: BorderSide(
        color: selected
            ? AppColors.brandOrange.withValues(alpha: 0.5)
            : AppColors.textSecondary.withValues(alpha: 0.25),
      ),
      onSelected: (_) async {
        await context.setLocale(locale);
      },
    );
  }
}

class _DeleteAccountDialogContent extends StatefulWidget {
  const _DeleteAccountDialogContent({required this.onConfirmDelete});

  final Future<void> Function() onConfirmDelete;

  @override
  State<_DeleteAccountDialogContent> createState() =>
      _DeleteAccountDialogContentState();
}

class _DeleteAccountDialogContentState extends State<_DeleteAccountDialogContent> {
  final _ctrl = TextEditingController();
  bool _understood = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final word = 'profile_delete_confirm_word'.tr();
    final typedOk = _ctrl.text.trim() == word;
    return AlertDialog(
      title: Text('profile_delete_account_confirm_title'.tr()),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'profile_delete_account_confirm_body'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 14),
            Text(
              'profile_delete_type_hint'.tr(namedArgs: {'word': word}),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: 'profile_delete_type_hint'.tr(namedArgs: {'word': word}),
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: word,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _understood,
              onChanged: (v) => setState(() => _understood = v ?? false),
              title: Text('profile_delete_understand'.tr()),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('profile_delete_account_cancel'.tr()),
        ),
        TextButton(
          onPressed: _understood && typedOk ? () => widget.onConfirmDelete() : null,
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade800),
          child: Text('profile_delete_account_confirm'.tr()),
        ),
      ],
    );
  }
}
