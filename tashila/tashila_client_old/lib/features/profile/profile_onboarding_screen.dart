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
    await ref.read(appStateProvider.notifier).saveProfileSetup(
          firstName: fn,
          lastName: ln,
          email: _email.text.trim(),
          profilePhotoPath: _photoPath,
        );
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('profile_onboarding_title'.tr())),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'profile_onboarding_subtitle'.tr(),
              style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: UploadImagePreview(
                      localPath: _photoPath,
                      width: 104,
                      height: 104,
                      borderRadius: 52,
                      placeholder: Icon(
                        Icons.person,
                        size: 52,
                        color: AppColors.brandOrange,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppColors.brandOrange),
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _pickPhoto,
                child: Text('profile_onboarding_photo_hint'.tr()),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _firstName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'profile_first_name'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'profile_family_name'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'profile_onboarding_email_optional'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'profile_onboarding_continue'.tr(),
              icon: Icons.check_circle_outline,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
