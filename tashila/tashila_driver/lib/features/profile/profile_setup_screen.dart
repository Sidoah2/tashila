import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/config/app_social_links.dart';

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
  final _plateSerialController = TextEditingController();
  final _plateYearController = TextEditingController();
  final _plateStateController = TextEditingController();
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
      ref
          .read(driverAppStateProvider.notifier)
          .syncPlatformEarningsFromServer();
    });
  }

  @override
  void dispose() {
    print(
      "[DEBUG_PHOTO] ProfileSetupScreenState dispose() called! Is it really dead?",
    );
    _approvalPollTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _vehiclePlateController.dispose();
    _plateSerialController.dispose();
    _plateYearController.dispose();
    _plateStateController.dispose();
    _vehicleColorController.dispose();
    _vehicleModelController.dispose();
    super.dispose();
  }

  void _syncApprovalPolling() {
    if (!mounted) return;
    final profile = ref.read(driverAppStateProvider).profile;
    final isRejected = profile?.approvalStatus == 'rejected';
    final awaiting =
        profile != null && profile.isComplete && !profile.documentsApproved && !isRejected;
    if (awaiting && _approvalPollTimer == null) {
      _approvalPollTimer = Timer.periodic(const Duration(seconds: 15), (
        _,
      ) async {
        await ref
            .read(driverAppStateProvider.notifier)
            .syncApprovalFromServer();
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
              constraints: const BoxConstraints(maxWidth: 440),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.brandOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: AppColors.brandOrange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'profile_about'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        'driver_profile_about_body'.tr(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        MaterialLocalizations.of(ctx).closeButtonLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLegalScrollSheet(String title, String body) {
    showDialog<void>(
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
              constraints: const BoxConstraints(maxWidth: 440),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.article_rounded,
                          color: Colors.blue.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        body,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        MaterialLocalizations.of(ctx).closeButtonLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/$kSupportWhatsAppDigits');
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showEditEmailDialog(BuildContext context, String currentEmail) {
    final controller = TextEditingController(text: currentEmail);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text('profile_onboarding_email_optional'.tr()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'email@example.com',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.locale.languageCode == 'ar'
                  ? 'إلغاء'
                  : (context.locale.languageCode == 'fr'
                        ? 'Annuler'
                        : 'Cancel'),
            ),
          ),
          FilledButton(
            onPressed: () async {
              final newEmail = controller.text.trim();
              Navigator.pop(ctx);
              final state = ref.read(driverAppStateProvider);
              final profile = state.profile ?? DriverProfile.empty();
              await ref
                  .read(driverAppStateProvider.notifier)
                  .saveProfile(
                    name: profile.name,
                    phone: profile.phone,
                    email: newEmail,
                    truckType: profile.truckType,
                    vehiclePlate: profile.vehiclePlate,
                    vehicleColor: profile.vehicleColor,
                    vehicleModel: profile.vehicleModel,
                  );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandOrange,
            ),
            child: Text(
              context.locale.languageCode == 'ar'
                  ? 'حفظ'
                  : (context.locale.languageCode == 'fr'
                        ? 'Enregistrer'
                        : 'Save'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSocialUrl(String url) async {
    final uri = Uri.parse(url);
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
                  const SizedBox(height: 12),
                  _mediaOptionTile(
                    ctx: ctx,
                    icon: Icons.photo_camera_rounded,
                    iconBg: Colors.blue.shade50,
                    iconColor: Colors.blue.shade700,
                    title: 'doc_pick_camera'.tr(),
                    source: _MediaPickSource.camera,
                  ),
                  const SizedBox(height: 10),
                  _mediaOptionTile(
                    ctx: ctx,
                    icon: Icons.photo_library_rounded,
                    iconBg: Colors.purple.shade50,
                    iconColor: Colors.purple.shade700,
                    title: 'doc_pick_gallery'.tr(),
                    source: _MediaPickSource.gallery,
                  ),
                  const SizedBox(height: 10),
                  _mediaOptionTile(
                    ctx: ctx,
                    icon: Icons.folder_open_rounded,
                    iconBg: Colors.amber.shade50,
                    iconColor: Colors.amber.shade800,
                    title: 'doc_pick_files'.tr(),
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

  Widget _mediaOptionTile({
    required BuildContext ctx,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required _MediaPickSource source,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pop(ctx, source),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
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
    print("[DEBUG_PHOTO] _pickProfilePhoto called");
    if (!mounted) return;
    final appStateNotifier = ref.read(driverAppStateProvider.notifier);
    final source = await _showMediaSourceSheet();
    print("[DEBUG_PHOTO] Selected source: $source");
    if (!mounted || source == null) {
      print("[DEBUG_PHOTO] Source is null or widget not mounted");
      return;
    }

    final picker = ImagePicker();
    String? path;

    switch (source) {
      case _MediaPickSource.camera:
        print("[DEBUG_PHOTO] Launching camera picker...");
        final x = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        print("[DEBUG_PHOTO] Camera returned: ${x?.path}");
        if (x != null) {
          path = await persistPickedImage(x, 'profile_photo');
          print("[DEBUG_PHOTO] Persisted camera path: $path");
        }
        break;
      case _MediaPickSource.gallery:
        print("[DEBUG_PHOTO] Launching gallery picker...");
        final xg = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        print("[DEBUG_PHOTO] Gallery returned: ${xg?.path}");
        if (xg != null) {
          path = await persistPickedImage(xg, 'profile_photo');
          print("[DEBUG_PHOTO] Persisted gallery path: $path");
        }
        break;
      case _MediaPickSource.files:
        print("[DEBUG_PHOTO] Launching file picker...");
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png'],
          allowMultiple: false,
          withData: false,
        );
        print(
          "[DEBUG_PHOTO] File picker returned: ${result?.files.single.path}",
        );
        if (result != null && result.files.isNotEmpty) {
          path = result.files.single.path;
          print("[DEBUG_PHOTO] File path: $path");
        }
        break;
    }

    print("[DEBUG_PHOTO] Final path to save: $path");
    if (path == null) {
      print("[DEBUG_PHOTO] Path is null, aborting upload");
      return;
    }
    final ext = path.split('.').last.toLowerCase();
    if (['mp4', 'mov', 'avi', 'mkv', '3gp', 'webm', 'gif'].contains(ext)) {
      setState(() {
        _profilePhotoError = 'validation_video_not_allowed'.tr();
      });
      return;
    }
    setState(() {
      _profilePhotoError = null;
    });
    print("[DEBUG_PHOTO] Invoking setProfilePhotoPath in AppState...");
    await appStateNotifier.setProfilePhotoPath(path);
    print("[DEBUG_PHOTO] setProfilePhotoPath execution finished");
  }

  Future<void> _pickDocument(DocumentType type) async {
    if (!mounted) return;
    final appStateNotifier = ref.read(driverAppStateProvider.notifier);
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
          await appStateNotifier.uploadDocument(
            type,
            fileName: fileName,
            filePath: stablePath,
          );
          break;
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
          await appStateNotifier.uploadDocument(
            type,
            fileName: fileName,
            filePath: stablePath,
          );
          break;
        }
        break;
      case _MediaPickSource.files:
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
          allowMultiple: false,
          withData: false,
        );
        if (result != null && result.files.isNotEmpty) {
          final f = result.files.single;
          fileName = f.name.isNotEmpty
              ? f.name
              : '${type.name}_${DateTime.now().millisecondsSinceEpoch}';
          final path = f.path;
          if (path != null) {
            await appStateNotifier.uploadDocument(
              type,
              fileName: fileName,
              filePath: path,
            );
          }
        }
        break;
    }

    if (mounted) {
      final updated = ref.read(driverAppStateProvider).profile;
      if (updated != null &&
          updated.documents.every((d) => d.hasUploadedImage)) {
        setState(() => _documentsError = null);
      }
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
        setState(() => _documentsError = 'validation_required_documents'.tr());
        return;
      }
      setState(() {
        _documentsError = null;
        _wizardStep = 2;
      });
      return;
    }

    if (_wizardStep == 2) {
      final serial = _plateSerialController.text.trim();
      final year = _plateYearController.text.trim();
      final state = _plateStateController.text.trim();

      setState(() {
        _didAttemptSubmit = true;
        _truckTypeError = isValidCabinTruckType(_truckType ?? '')
            ? null
            : 'validation_required_truck_type'.tr();

        if (serial.isEmpty || year.isEmpty || state.isEmpty) {
          _vehiclePlateError = 'validation_required_vehicle_plate'.tr();
        } else if (year.length != 3 || state.length != 2) {
          _vehiclePlateError = 'validation_invalid_plate_format'.tr();
        } else {
          _vehiclePlateError = null;
        }

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
      _vehiclePlateController.text = '$serial $year $state';
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
    final isRejected = profile.approvalStatus == 'rejected';

    // ---- REJECTION SCREEN ------------------------------------------------
    if (isRejected) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () async {
              await notifier.logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDED),
                    borderRadius: BorderRadius.circular(44),
                  ),
                  child: const Icon(
                    Icons.cancel_rounded,
                    color: Color(0xFFE53935),
                    size: 44,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'account_rejected_title'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFE53935),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'account_rejected_body'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (profile.rejectionReason != null && profile.rejectionReason!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      profile.rejectionReason!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFE53935),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.headset_mic_rounded),
                    label: Text(
                      'contact_support'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    onPressed: () {
                      launchUrl(
                        Uri.parse('https://wa.me/$kSupportWhatsAppDigits'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // ---- END REJECTION SCREEN --------------------------------------------

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
                    : () async {
                        if (_wizardStep > 0) {
                          setState(() => _wizardStep--);
                        } else {
                          await notifier.logout();
                          if (context.mounted) {
                            context.go('/login');
                          }
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
              namedArgs: {'current': '${_wizardStep + 1}', 'total': '3'},
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
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
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
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
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
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: 'name_label'.tr(),
                              filled: true,
                              fillColor: AppColors.bg,
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                                color: AppColors.brandOrange,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AppColors.brandOrange,
                                  width: 2,
                                ),
                              ),
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
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Colors.black12),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'profile_onboarding_email_optional'
                                  .tr(),
                              filled: true,
                              fillColor: AppColors.bg,
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: AppColors.brandOrange,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AppColors.brandOrange,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Colors.black12),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            readOnly: true,
                            textAlign: TextAlign.end,
                            textDirection: ui.TextDirection.ltr,
                            decoration: InputDecoration(
                              hintText: 'phone_label'.tr(),
                              filled: true,
                              fillColor: AppColors.bg,
                              prefixIcon: const Icon(
                                Icons.phone_iphone_rounded,
                                color: AppColors.brandOrange,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              final raw = value?.trim() ?? '';
                              if (raw.isEmpty) {
                                return 'validation_required_phone'.tr();
                              }
                              final digitsOnly = raw.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              );
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
                ],
                if (_wizardStep == 1) ...[
                  _infoCallout(context, 'driver_verify_docs_callout'.tr()),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < profile.documents.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: Colors.black12),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            leading: UploadImagePreview(
                              localPath: profile.documents[i].localFilePath,
                              remoteUrl: profile.documents[i].displayRemoteUrl,
                              width: 52,
                              height: 52,
                              borderRadius: 12,
                              placeholder: const Icon(
                                Icons.description_outlined,
                                color: AppColors.brandOrange,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _docLabel(profile.documents[i].type),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                                if (profile.documents[i].hasUploadedImage)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              profile.documents[i].hasUploadedImage
                                  ? (profile.documents[i].displaySubtitle ??
                                        'doc_uploaded'.tr())
                                  : _docSubtitle(profile.documents[i].type),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            trailing: TextButton(
                              onPressed: state.isBusy
                                  ? null
                                  : () => _pickDocument(
                                      profile.documents[i].type,
                                    ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.brandOrange,
                              ),
                              child: Text(
                                profile.documents[i].hasUploadedImage
                                    ? 'replace'.tr()
                                    : 'upload'.tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
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
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _vehicleModelController,
                          scrollPadding: const EdgeInsets.only(bottom: 250),
                          decoration: InputDecoration(
                            hintText: 'vehicle_model_hint'.tr(),
                            errorText: _vehicleModelError,
                            filled: true,
                            fillColor: AppColors.bg,
                            prefixIcon: const Icon(
                              Icons.local_shipping_outlined,
                              color: AppColors.brandOrange,
                              size: 20,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.brandOrange,
                                width: 2,
                              ),
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Colors.black12),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _vehicleColorController,
                          scrollPadding: const EdgeInsets.only(bottom: 250),
                          decoration: InputDecoration(
                            hintText: 'vehicle_color_hint'.tr(),
                            errorText: _vehicleColorError,
                            filled: true,
                            fillColor: AppColors.bg,
                            prefixIcon: const Icon(
                              Icons.palette_outlined,
                              color: AppColors.brandOrange,
                              size: 20,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.brandOrange,
                                width: 2,
                              ),
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Colors.black12),
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'vehicle_plate'.tr(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
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
                                    child: TextField(
                                      controller: _plateSerialController,
                                      scrollPadding: const EdgeInsets.only(bottom: 250),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      maxLength: 6,
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
                                    child: TextField(
                                      controller: _plateYearController,
                                      scrollPadding: const EdgeInsets.only(bottom: 250),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      maxLength: 3,
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
                                    child: TextField(
                                      controller: _plateStateController,
                                      scrollPadding: const EdgeInsets.only(bottom: 250),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      maxLength: 2,
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
                            if (_vehiclePlateError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0, left: 4, right: 4),
                                child: Text(
                                  _vehiclePlateError!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (bottomAwaiting) ...[
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.brandOrange.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
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
    final allDocsUploaded =
        profile.documents.isNotEmpty &&
        profile.documents.every((d) => d.hasUploadedImage);
    final awaitingApproval = profile.isComplete && !profile.documentsApproved;

    ref.listen<DriverAppState>(driverAppStateProvider, (_, __) {
      _syncApprovalPolling();
    });

    if (_nameController.text.isEmpty) {
      _nameController.text = profile.name;
      _phoneController.text = profile.phone;
      _emailController.text = profile.email;
      _vehiclePlateController.text = profile.vehiclePlate;
      final plate = profile.vehiclePlate.trim();
      final parts = plate.split(' ');
      if (parts.length >= 3) {
        _plateSerialController.text = parts[0];
        _plateYearController.text = parts[1];
        _plateStateController.text = parts[2];
      } else {
        _plateSerialController.text = plate;
      }
      _vehicleColorController.text = profile.vehicleColor;
      _vehicleModelController.text = profile.vehicleModel;
      if (isValidCabinTruckType(profile.truckType)) {
        _truckType = profile.truckType;
      }
    }

    if (inInitialSetup) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
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

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Premium horizontal hero profile header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(color: AppColors.brandOrange),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'profile_title'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Horizontal Hero Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                GestureDetector(
                                  onTap: state.isBusy
                                      ? null
                                      : _pickProfilePhoto,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.15,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: buildLocalProfileAvatar(
                                      path: profile.profilePhotoPath,
                                      networkUrl: profile.avatarUrl,
                                      radius: 36,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Material(
                                    color: Colors.white,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: state.isBusy
                                          ? null
                                          : _pickProfilePhoto,
                                      child: const Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Icon(
                                          Icons.camera_alt,
                                          size: 14,
                                          color: AppColors.brandOrange,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (profile.name.trim().isNotEmpty)
                                    Text(
                                      profile.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (profile.phone.trim().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '\u200E${profile.phone}',
                                      textAlign: TextAlign.end,
                                      textDirection: ui.TextDirection.ltr,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: profile.documentsApproved
                                          ? Colors.white.withValues(alpha: 0.25)
                                          : Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          profile.documentsApproved
                                              ? Icons.verified_rounded
                                              : Icons.pending_outlined,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          profile.documentsApproved
                                              ? 'documents_approved'.tr()
                                              : 'documents_pending'.tr(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            sliver: SliverToBoxAdapter(
              child: _ProfileOverviewCard(
                tripHistory: state.tripHistory,
                platformEarnings: state.platformEarnings,
              ),
            ),
          ),
          // Section: Personal Information
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileSectionHeader(
                    title: 'driver_verify_step1_title'.tr(),
                    icon: Icons.person_rounded,
                    iconBg: Colors.blue.shade50,
                    iconColor: Colors.blue.shade700,
                  ),
                  _ProfileCardContainer(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppColors.brandOrange.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person_outline_rounded,
                              color: AppColors.brandOrange,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'name_label'.tr(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          subtitle: Text(
                            profile.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'driver_personal_info_locked'.tr(),
                                ),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          },
                        ),
                        _tileDivider(),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppColors.brandOrange.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.phone_outlined,
                              color: AppColors.brandOrange,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'phone_label'.tr(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          subtitle: Text(
                            '\u200E${profile.phone}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'driver_personal_info_locked'.tr(),
                                ),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          },
                        ),
                        _tileDivider(),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppColors.brandOrange.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.email_outlined,
                              color: AppColors.brandOrange,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'profile_onboarding_email_optional'.tr(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          subtitle: Text(
                            profile.email.isEmpty ? '—' : profile.email,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.brandOrange,
                            size: 18,
                          ),
                          onTap: () =>
                              _showEditEmailDialog(context, profile.email),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Section: Vehicle & Equipment
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileSectionHeader(
                    title: 'truck_type_label'.tr(),
                    icon: Icons.local_shipping_rounded,
                    iconBg: AppColors.brandOrange.withValues(alpha: 0.12),
                    iconColor: AppColors.brandOrange,
                  ),
                  _ProfileCardContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandOrange.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.brandOrange.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.local_shipping_outlined,
                                    size: 16,
                                    color: AppColors.brandOrange,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _truckLabel(profile.truckType),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.brandOrange,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
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
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Section: App Preferences (Language)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileSectionHeader(
                    title: 'language'.tr(),
                    icon: Icons.language_rounded,
                    iconBg: Colors.indigo.shade50,
                    iconColor: Colors.indigo.shade700,
                  ),
                  _ProfileCardContainer(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
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
                  ),
                ],
              ),
            ),
          ),
          // Section: Help & Legal
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileSectionHeader(
                    title: 'profile_section_help'.tr(),
                    icon: Icons.help_outline_rounded,
                    iconBg: Colors.teal.shade50,
                    iconColor: Colors.teal.shade700,
                  ),
                  _ProfileCardContainer(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _profileTile(
                          context: context,
                          icon: Icons.lightbulb_rounded,
                          iconBg: Colors.amber.shade50,
                          iconColor: Colors.amber.shade800,
                          title: 'profile_legal_tips_title'.tr(),
                          onTap: () => _showLegalScrollSheet(
                            'profile_legal_tips_title'.tr(),
                            'driver_legal_tips_body'.tr(),
                          ),
                        ),
                        _tileDivider(),
                        _profileTile(
                          context: context,
                          icon: Icons.gavel_rounded,
                          iconBg: Colors.blue.shade50,
                          iconColor: Colors.blue.shade700,
                          title: 'profile_legal_terms_title'.tr(),
                          onTap: () => _showLegalScrollSheet(
                            'profile_legal_terms_title'.tr(),
                            'driver_legal_terms_body'.tr(),
                          ),
                        ),
                        _tileDivider(),
                        _profileTile(
                          context: context,
                          icon: Icons.shield_rounded,
                          iconBg: Colors.green.shade50,
                          iconColor: Colors.green.shade700,
                          title: 'profile_legal_privacy_title'.tr(),
                          onTap: () => _showLegalScrollSheet(
                            'profile_legal_privacy_title'.tr(),
                            'driver_legal_privacy_body'.tr(),
                          ),
                        ),
                        _tileDivider(),
                        _profileTile(
                          context: context,
                          icon: FontAwesomeIcons.whatsapp,
                          iconBg: const Color(0xFFE8F5E9),
                          iconColor: const Color(0xFF25D366),
                          title: 'profile_support_whatsapp'.tr(),
                          onTap: _openWhatsApp,
                        ),
                        _tileDivider(),
                        // _profileTile(
                        //   context: context,
                        //   icon: Icons.info_rounded,
                        //   iconBg: Colors.purple.shade50,
                        //   iconColor: Colors.purple.shade700,
                        //   title: 'profile_about h'.tr(),
                        //   onTap: _showAboutTashilaDialog,
                        // ),
                        // _tileDivider(),
                        _profileTile(
                          context: context,
                          icon: Icons.delete_forever_rounded,
                          iconBg: Colors.red.shade50,
                          iconColor: Colors.red.shade700,
                          title: 'profile_delete_account'.tr(),
                          titleColor: Colors.red.shade800,
                          onTap: _showDeleteAccountDialog,
                          isCircle: true,
                        ),
                        _tileDivider(),
                        const _DriverProfileVersionTile(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Section: Follow Us (Social Links)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileSectionHeader(
                    title: 'profile_social_section'.tr(),
                    icon: Icons.share_rounded,
                    iconBg: Colors.indigo.shade50,
                    iconColor: Colors.indigo.shade700,
                  ),
                  _ProfileCardContainer(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _profileTile(
                          context: context,
                          icon: FontAwesomeIcons.facebook,
                          iconBg: const Color(0xFFE8F0FE),
                          iconColor: const Color(0xFF1877F2),
                          title: 'profile_link_facebook'.tr(),
                          onTap: () => _openSocialUrl(AppSocialLinks.facebook),
                        ),
                        _tileDivider(),
                        _profileTile(
                          context: context,
                          icon: FontAwesomeIcons.tiktok,
                          iconBg: Colors.grey.shade100,
                          iconColor: Colors.black,
                          title: 'profile_link_tiktok'.tr(),
                          onTap: () => _openSocialUrl(AppSocialLinks.tiktok),
                        ),
                        _tileDivider(),
                        _profileTile(
                          context: context,
                          icon: FontAwesomeIcons.instagram,
                          iconBg: const Color(0xFFFDF0F2),
                          iconColor: const Color(0xFFE1306C),
                          title: 'profile_link_instagram'.tr(),
                          onTap: () => _openSocialUrl(AppSocialLinks.instagram),
                        ),
                        _tileDivider(),
                        _profileTile(
                          context: context,
                          icon: Icons.language_rounded,
                          iconBg: Colors.purple.shade50,
                          iconColor: Colors.purple.shade700,
                          title: 'profile_link_website'.tr(),
                          onTap: () => _openSocialUrl(AppSocialLinks.website),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Logout Action Button
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: () => confirmDriverLogout(context, ref),
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  label: Text(
                    'logout'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.transparent, width: 1.5),
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileTile({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    Color? titleColor,
    required VoidCallback onTap,
    bool isCircle = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: iconBg,
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
          color: titleColor ?? AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Widget _tileDivider() {
    return Divider(
      height: 1,
      indent: 58,
      color: Colors.black.withValues(alpha: 0.04),
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
                flex: 2,
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
              Spacer(),
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
    final trips = tripHistory.where((t) => t.isCompleted).toList();
    final totalEarnings = trips.fold<double>(0, (s, t) => s + t.fare);
    final rated = trips.where((t) => t.rating != null).toList();
    final avgRating = rated.isEmpty
        ? 0.0
        : rated.map((t) => t.rating!.toDouble()).reduce((a, b) => a + b) /
              rated.length;
    final money = dzdCurrency();
    final platform = platformEarnings ?? const DriverPlatformEarnings();

    return _ProfileCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: AppColors.brandOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'profile_overview_title'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _statRow(
            context,
            label: 'profile_stat_completed_trips'.tr(),
            value: westernDigits('${trips.length}'),
            icon: Icons.task_alt_rounded,
            iconBg: Colors.green.shade50,
            iconColor: Colors.green.shade700,
          ),
          const SizedBox(height: 12),
          _statRow(
            context,
            label: 'profile_stat_avg_rating'.tr(),
            value: westernDigits(
              avgRating > 0 ? avgRating.toStringAsFixed(1) : '—',
            ),
            icon: Icons.star_rounded,
            iconBg: Colors.amber.shade50,
            iconColor: Colors.amber.shade700,
          ),
          const SizedBox(height: 12),
          _statRow(
            context,
            label: 'profile_stat_total_earnings'.tr(),
            value: money.format(platform.totalEarnedDzd),
            icon: Icons.payments_rounded,
            iconBg: AppColors.brandOrange.withValues(alpha: 0.1),
            iconColor: AppColors.brandOrange,
            emphasize: true,
          ),
          const SizedBox(height: 12),
          _statRow(
            context,
            label: 'earnings_platform_due'.tr(),
            value: money.format(platform.platformDueDzd),
            icon: Icons.receipt_long_rounded,
            iconBg: Colors.blue.shade50,
            iconColor: Colors.blue.shade700,
          ),
          const SizedBox(height: 12),
          _statRow(
            context,
            label: 'earnings_platform_paid'.tr(),
            value: money.format(platform.paidDzd),
            icon: Icons.check_circle_outline_rounded,
            iconBg: Colors.teal.shade50,
            iconColor: Colors.teal.shade700,
          ),
          const SizedBox(height: 12),
          _statRow(
            context,
            label: 'earnings_platform_net'.tr(),
            value: money.format(platform.netDzd),
            icon: Icons.account_balance_wallet_rounded,
            iconBg: Colors.purple.shade50,
            iconColor: Colors.purple.shade700,
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _statRow(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    bool emphasize = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: emphasize ? 15 : 14,
            color: emphasize ? AppColors.brandOrange : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── Helper Container Cards & Headers ────────────────────────────────────────

class _ProfileCardContainer extends StatelessWidget {
  const _ProfileCardContainer({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.04),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _ProfileSectionHeader extends StatelessWidget {
  const _ProfileSectionHeader({
    required this.title,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  final String title;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
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

class _DeleteAccountDialogContentState
    extends State<_DeleteAccountDialogContent> {
  final _ctrl = TextEditingController();
  bool _understood = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final word = 'profile_delete_confirm_word'.tr();
    final typedOk = _ctrl.text.trim() == word;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.delete_forever_rounded,
                          color: Colors.red.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'profile_delete_account_confirm_title'.tr(),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'profile_delete_account_confirm_body'.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'profile_delete_type_hint'.tr(namedArgs: {'word': word}),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    label: 'profile_delete_type_hint'.tr(
                      namedArgs: {'word': word},
                    ),
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: word,
                        filled: true,
                        fillColor: AppColors.bg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.red.shade400,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _understood,
                    activeColor: Colors.red.shade700,
                    onChanged: (v) => setState(() => _understood = v ?? false),
                    title: Text(
                      'profile_delete_understand'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        child: Text('profile_delete_account_cancel'.tr()),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _understood && typedOk
                            ? () => widget.onConfirmDelete()
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(100, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          'profile_delete_account_confirm'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
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
    );
  }
}
