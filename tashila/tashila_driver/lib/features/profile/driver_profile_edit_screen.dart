import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/state/driver_app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/picked_image_io.dart';

class DriverProfileEditScreen extends ConsumerStatefulWidget {
  const DriverProfileEditScreen({super.key});

  @override
  ConsumerState<DriverProfileEditScreen> createState() =>
      _DriverProfileEditScreenState();
}

enum _MediaPickSource { camera, gallery, files }

class _DriverProfileEditScreenState
    extends ConsumerState<DriverProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  Future<void> _changeAvatar() async {
    if (!mounted) return;
    final appStateNotifier = ref.read(driverAppStateProvider.notifier);
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

    if (path == null) return;
    if (mounted) {
      setState(() => _saving = true);
    }
    try {
      await appStateNotifier.setProfilePhotoPath(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text('profile_updated_success'.tr()),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_updating_profile'.tr()),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<_MediaPickSource?> _showMediaSourceSheet() {
    return showDialog<_MediaPickSource>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'doc_pick_title'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sourceTile(
                    ctx,
                    icon: Icons.camera_alt_rounded,
                    title: 'doc_pick_camera'.tr(),
                    subtitle: 'doc_pick_camera_sub'.tr(),
                    source: _MediaPickSource.camera,
                  ),
                  const SizedBox(height: 12),
                  _sourceTile(
                    ctx,
                    icon: Icons.photo_library_rounded,
                    title: 'doc_pick_gallery'.tr(),
                    subtitle: 'doc_pick_gallery_sub'.tr(),
                    source: _MediaPickSource.gallery,
                  ),
                  const SizedBox(height: 12),
                  _sourceTile(
                    ctx,
                    icon: Icons.folder_rounded,
                    title: 'doc_pick_files'.tr(),
                    subtitle: 'doc_pick_files_sub'.tr(),
                    source: _MediaPickSource.files,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sourceTile(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required _MediaPickSource source,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(ctx, source),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.brandOrange, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  late final TextEditingController _nameCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _plateCtrl;
  late final TextEditingController _plateSerialCtrl;
  late final TextEditingController _plateYearCtrl;
  late final TextEditingController _plateStateCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(driverAppStateProvider).profile;
    _nameCtrl = TextEditingController(text: profile?.name ?? '');
    _modelCtrl = TextEditingController(text: profile?.vehicleModel ?? '');
    _colorCtrl = TextEditingController(text: profile?.vehicleColor ?? '');
    _plateCtrl = TextEditingController(text: profile?.vehiclePlate ?? '');

    final plate = profile?.vehiclePlate.trim() ?? '';
    final parts = plate.split(' ');
    if (parts.length >= 3) {
      _plateSerialCtrl = TextEditingController(text: parts[0]);
      _plateYearCtrl = TextEditingController(text: parts[1]);
      _plateStateCtrl = TextEditingController(text: parts[2]);
    } else {
      _plateSerialCtrl = TextEditingController(text: plate);
      _plateYearCtrl = TextEditingController();
      _plateStateCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _modelCtrl.dispose();
    _colorCtrl.dispose();
    _plateCtrl.dispose();
    _plateSerialCtrl.dispose();
    _plateYearCtrl.dispose();
    _plateStateCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final serial = _plateSerialCtrl.text.trim();
    final year = _plateYearCtrl.text.trim();
    final state = _plateStateCtrl.text.trim();

    if (serial.isEmpty || year.isEmpty || state.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('validation_required_vehicle_plate'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (year.length != 3 || state.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('validation_invalid_plate_format'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _plateCtrl.text = '$serial $year $state';

    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final notifier = ref.read(driverAppStateProvider.notifier);
    try {
      await notifier.updateProfile(
        name: _nameCtrl.text.trim(),
        vehicleModel: _modelCtrl.text.trim(),
        vehicleColor: _colorCtrl.text.trim(),
        vehiclePlate: _plateCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text('profile_updated_success'.tr()),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_updating_profile'.tr()),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(driverAppStateProvider).profile;
    final firstLetter = (profile?.name ?? 'D').characters.first.toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'edit_profile'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 19,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar Edit Hero Container
              Center(
                child: GestureDetector(
                  onTap: _changeAvatar,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.brandOrange, Color(0xFFFF9100)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandOrange.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: CircleAvatar(
                            radius: 44,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 41,
                              backgroundColor: AppColors.brandOrange.withValues(
                                alpha: 0.15,
                              ),
                              backgroundImage:
                                  (profile?.avatarUrl != null &&
                                      profile!.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(profile.avatarUrl!)
                                  : null,
                              child:
                                  (profile?.avatarUrl == null ||
                                      profile!.avatarUrl!.isEmpty)
                                  ? Text(
                                      firstLetter,
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.brandOrange,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.brandOrange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Official Documents Notice Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.brandOrange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: AppColors.brandOrange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'official_docs_notice'.tr(),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form Section Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildModernInputField(
                      controller: _nameCtrl,
                      label: 'driver_name'.tr(),
                      icon: Icons.person_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'field_required'.tr()
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildModernInputField(
                      controller: _modelCtrl,
                      label: 'vehicle_model'.tr(),
                      icon: Icons.directions_car_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildModernInputField(
                      controller: _colorCtrl,
                      label: 'vehicle_color'.tr(),
                      icon: Icons.palette_rounded,
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 2, bottom: 6),
                          child: Text(
                            'vehicle_plate'.tr(),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Directionality(
                          textDirection: ui.TextDirection.ltr,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _plateSerialCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  maxLength: 6,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '12938',
                                    counterText: "",
                                    filled: true,
                                    fillColor: AppColors.bg,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onChanged: (val) {
                                    if (val.length == 6) {
                                      FocusScope.of(context).nextFocus();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _plateYearCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  maxLength: 3,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '213',
                                    counterText: "",
                                    filled: true,
                                    fillColor: AppColors.bg,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onChanged: (val) {
                                    if (val.length == 3) {
                                      FocusScope.of(context).nextFocus();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _plateStateCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  maxLength: 2,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '29',
                                    counterText: "",
                                    filled: true,
                                    fillColor: AppColors.bg,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Save Changes Gradient Button
              Container(
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [AppColors.brandOrange, Color(0xFFE65100)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandOrange.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveProfile,
                  icon: _saving
                      ? const SizedBox.shrink()
                      : const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                  label: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'save_changes'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16.5,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          validator: validator,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText ?? label,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.brandOrange),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.brandOrange,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
