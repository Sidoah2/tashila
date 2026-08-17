import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tashila_client/core/state/app_state.dart';
import 'package:tashila_client/core/theme/app_colors.dart';
import 'package:tashila_client/core/widgets/primary_button.dart';
import 'package:tashila_client/core/widgets/upload_image_preview.dart';

class ProfileOnboardingScreen extends ConsumerStatefulWidget {
  const ProfileOnboardingScreen({super.key});

  @override
  ConsumerState<ProfileOnboardingScreen> createState() => _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends ConsumerState<ProfileOnboardingScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  String? _photoPath;
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (!mounted || file == null) return;
    setState(() => _photoPath = file.path);
  }

  Future<void> _submit() async {
    final fn = _firstName.text.trim();
    final ln = _lastName.text.trim();
    if (fn.isEmpty || ln.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile_onboarding_required'.tr())),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(appStateProvider.notifier).saveProfileSetup(
            firstName: fn,
            lastName: ln,
            email: _email.text.trim(),
            profilePhotoPath: _photoPath,
          );
      if (!mounted) return;
      context.go('/home');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_occurred'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            ref.read(appStateProvider.notifier).logout();
          },
        ),
        title: Text(
          'profile_onboarding_title'.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          physics: const BouncingScrollPhysics(),
          children: [
            Text(
              'profile_onboarding_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.brandOrange, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: UploadImagePreview(
                        localPath: _photoPath,
                        width: 108,
                        height: 108,
                        borderRadius: 54,
                        placeholder: Container(
                          color: AppColors.brandOrange.withValues(alpha: 0.08),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.person_rounded,
                            size: 54,
                            color: AppColors.brandOrange,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Material(
                      color: AppColors.brandOrange,
                      shape: const CircleBorder(),
                      elevation: 3,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _pickPhoto,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
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
            Center(
              child: TextButton(
                onPressed: _pickPhoto,
                style: TextButton.styleFrom(foregroundColor: AppColors.brandOrange),
                child: Text(
                  'profile_onboarding_photo_hint'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.04),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _firstName,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'profile_first_name'.tr(),
                      filled: true,
                      fillColor: AppColors.bg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lastName,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'profile_family_name'.tr(),
                      filled: true,
                      fillColor: AppColors.bg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'profile_onboarding_email_optional'.tr(),
                      filled: true,
                      fillColor: AppColors.bg,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'profile_onboarding_continue'.tr(),
              icon: Icons.check_circle_outline,
              onPressed: _submit,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}
