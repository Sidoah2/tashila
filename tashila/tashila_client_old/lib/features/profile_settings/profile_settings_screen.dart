import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tashila_client/core/config/app_social_links.dart';
import 'package:tashila_client/core/config/support_config.dart';
import 'package:tashila_client/core/state/app_state.dart';
import 'package:tashila_client/core/theme/app_colors.dart';
import 'package:tashila_client/core/widgets/upload_image_preview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final notifier = ref.read(appStateProvider.notifier);
    final theme = Theme.of(context);
    final tripCount = state.history.length;
    final completedCount = state.history.where((t) => !t.cancelled).length;
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
                  'profile'.tr(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _ProfileHeroCard(
                  firstName: state.firstName,
                  lastName: state.lastName,
                  profileImageUrl: state.profileImageUrl.trim(),
                  profilePhotoPath: state.profilePhotoPath.trim(),
                  phone: state.phone,
                  tripCount: tripCount,
                  completedCount: completedCount,
                  onPhotoTap: () => _pickProfilePhoto(context, ref),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(text: 'profile_section_account'.tr()),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _SettingsCard(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.brandOrange.withValues(alpha: 0.15),
                        child: Icon(
                          Icons.badge_outlined,
                          color: AppColors.brandOrange,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        'profile_first_name'.tr(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          state.firstName.trim().isEmpty
                              ? 'profile_name_placeholder'.tr()
                              : state.firstName.trim(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.textSecondary.withValues(alpha: 0.1),
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.brandOrange.withValues(alpha: 0.15),
                        child: Icon(
                          Icons.badge_outlined,
                          color: AppColors.brandOrange,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        'profile_family_name'.tr(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          state.lastName.trim().isEmpty
                              ? 'profile_name_placeholder'.tr()
                              : state.lastName.trim(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.textSecondary.withValues(alpha: 0.1),
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.brandOrange.withValues(alpha: 0.15),
                        child: Icon(
                          Icons.phone_android_rounded,
                          color: AppColors.brandOrange,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        'profile_phone_label'.tr(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          state.phone.isEmpty
                              ? 'profile_phone_placeholder'.tr()
                              : state.phone,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.textSecondary.withValues(alpha: 0.1),
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.brandOrange.withValues(alpha: 0.15),
                        child: Icon(
                          Icons.email_outlined,
                          color: AppColors.brandOrange,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        'profile_onboarding_email_optional'.tr(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          state.email.trim().isEmpty
                              ? 'profile_name_placeholder'.tr()
                              : state.email.trim(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.textSecondary.withValues(alpha: 0.1),
                    ),
                    ListTile(
                      leading: Icon(Icons.delete_forever_outlined, color: Colors.red.shade700),
                      title: Text(
                        'profile_delete_account'.tr(context: context),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade800,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: Colors.red.shade200),
                      onTap: () => _showDeleteAccountDialog(context, ref),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(text: 'profile_section_preferences'.tr()),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _SettingsCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'language'.tr(),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _LangChip(
                            label: 'lang_ar'.tr(),
                            locale: const Locale('ar'),
                            ref: ref,
                          ),
                          _LangChip(
                            label: 'lang_en'.tr(),
                            locale: const Locale('en'),
                            ref: ref,
                          ),
                          _LangChip(
                            label: 'lang_fr'.tr(),
                            locale: const Locale('fr'),
                            ref: ref,
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: AppColors.textSecondary.withValues(alpha: 0.12),
                    ),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      activeThumbColor: AppColors.brandOrange,
                      activeTrackColor:
                          AppColors.brandOrange.withValues(alpha: 0.35),
                      secondary: Icon(
                        Icons.notifications_active_outlined,
                        color: AppColors.textSecondary,
                      ),
                      title: Text(
                        'notifications'.tr(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'profile_notifications_subtitle'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      value: state.notificationsEnabled,
                      onChanged: (v) => notifier.setNotificationsEnabled(v),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(text: 'profile_section_help'.tr()),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _SettingsCard(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.lightbulb_outline_rounded,
                        color: AppColors.textSecondary,
                      ),
                      title: Text(
                        'profile_legal_tips_title'.tr(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      onTap: () => _showLegalScrollSheet(
                        context,
                        'profile_legal_tips_title'.tr(),
                        'profile_legal_tips_body'.tr(),
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
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      onTap: () => _showLegalScrollSheet(
                        context,
                        'profile_legal_terms_title'.tr(),
                        'profile_legal_terms_body'.tr(),
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
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      onTap: () => _showLegalScrollSheet(
                        context,
                        'profile_legal_privacy_title'.tr(),
                        'profile_legal_privacy_body'.tr(),
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
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      onTap: () => _openWhatsApp(),
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
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      onTap: () => _showAboutDialog(context),
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.textSecondary.withValues(alpha: 0.1),
                    ),
                    const _ProfileVersionTile(),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(text: 'profile_social_section'.tr()),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _SettingsCard(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
                      title: Text('profile_link_facebook'.tr()),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () => _openExternalUrl(AppSocialLinks.facebook),
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.textSecondary.withValues(alpha: 0.1),
                    ),
                    ListTile(
                      leading: const Icon(Icons.music_note, color: Colors.black87),
                      title: Text('profile_link_tiktok'.tr()),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () => _openExternalUrl(AppSocialLinks.tiktok),
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.textSecondary.withValues(alpha: 0.1),
                    ),
                    ListTile(
                      leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFFE4405F)),
                      title: Text('profile_link_instagram'.tr()),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () => _openExternalUrl(AppSocialLinks.instagram),
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.textSecondary.withValues(alpha: 0.1),
                    ),
                    ListTile(
                      leading: Icon(Icons.language, color: AppColors.textSecondary),
                      title: Text('profile_link_website'.tr()),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () => _openExternalUrl(AppSocialLinks.website),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              sliver: SliverToBoxAdapter(
                child: OutlinedButton(
                  onPressed: () async {
                    await notifier.logout();
                    if (context.mounted) context.go('/login');
                  },
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
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProfilePhoto(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file == null || !context.mounted) return;
    await ref.read(appStateProvider.notifier).uploadProfilePhoto(file.path);
  }

  void _showLegalScrollSheet(BuildContext context, String title, String body) {
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

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/$kSupportWhatsAppDigits');
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('profile_about'.tr()),
        content: Text(
          'profile_about_body'.tr(),
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45),
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

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _DeleteAccountDialogContent(
        onConfirmDelete: () async {
          Navigator.pop(ctx);
          await ref.read(appStateProvider.notifier).deleteAccount();
          if (context.mounted) context.go('/login');
        },
      ),
    );
  }
}

class _DeleteAccountDialogContent extends StatefulWidget {
  const _DeleteAccountDialogContent({required this.onConfirmDelete});

  final Future<void> Function() onConfirmDelete;

  @override
  State<_DeleteAccountDialogContent> createState() => _DeleteAccountDialogContentState();
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
      title: Text('profile_delete_account_confirm_title'.tr(context: context)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'profile_delete_account_confirm_body'.tr(context: context),
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
            TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: word,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _understood,
              onChanged: (v) => setState(() => _understood = v ?? false),
              title: Text('profile_delete_understand'.tr(context: context)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('profile_delete_account_cancel'.tr(context: context)),
        ),
        TextButton(
          onPressed: _understood && typedOk ? () => widget.onConfirmDelete() : null,
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade800),
          child: Text('profile_delete_account_confirm'.tr(context: context)),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary.withValues(alpha: 0.85),
            ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.firstName,
    required this.lastName,
    required this.profileImageUrl,
    required this.profilePhotoPath,
    required this.phone,
    required this.tripCount,
    required this.completedCount,
    this.onPhotoTap,
  });

  final String firstName;
  final String lastName;
  final String profileImageUrl;
  final String profilePhotoPath;
  final String phone;
  final int tripCount;
  final int completedCount;
  final VoidCallback? onPhotoTap;

  String _initialsFrom(String f, String l) {
    if (f.isNotEmpty && l.isNotEmpty) {
      return '${f.characters.first}${l.characters.first}'.toUpperCase();
    }
    if (f.isNotEmpty) {
      final chars = f.characters;
      if (chars.length >= 2) {
        return '${chars.first}${chars.elementAt(1)}'.toUpperCase();
      }
      return chars.first.toUpperCase();
    }
    final digits = RegExp(r'\d')
        .allMatches(phone)
        .map((m) => m.group(0)!)
        .toList();
    if (digits.length >= 2) {
      return '${digits[digits.length - 2]}${digits.last}';
    }
    if (digits.isNotEmpty) return digits.first;
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = firstName.trim();
    final l = lastName.trim();
    final String firstLine;
    final String familyLine;
    if (f.isEmpty && l.isEmpty) {
      firstLine = 'profile_guest_user'.tr();
      familyLine = '';
    } else {
      firstLine = f.isEmpty ? 'profile_name_placeholder'.tr() : f;
      familyLine = l.isEmpty ? 'profile_name_placeholder'.tr() : l;
    }
    final initials = _initialsFrom(f, l);
    final a11yName = familyLine.isEmpty
        ? firstLine
        : '$firstLine, $familyLine';

    return Material(
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              AppColors.brandOrange,
              AppColors.brandOrange.withValues(alpha: 0.82),
              const Color(0xFFE07810),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onPhotoTap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: UploadImagePreview(
                          localPath: profilePhotoPath,
                          remoteUrl: profileImageUrl,
                          width: 72,
                          height: 72,
                          borderRadius: 36,
                          placeholder: _InitialsAvatar(initials: initials),
                        ),
                      ),
                      if (onPhotoTap != null)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onPhotoTap,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: AppColors.brandOrange,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Semantics(
                    label: '${'profile_name'.tr()}: $a11yName',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstLine,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        if (familyLine.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            familyLine,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.96),
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'profile_tagline'.tr(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _HeroStatPill(
                    icon: Icons.route_rounded,
                    label: 'profile_stat_trips'.tr(),
                    value: '$tripCount',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeroStatPill(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'profile_stat_completed'.tr(),
                    value: '$completedCount',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.brandOrange,
          height: 1,
        ),
      ),
    );
  }
}

class _HeroStatPill extends StatelessWidget {
  const _HeroStatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.95), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileVersionTile extends StatefulWidget {
  const _ProfileVersionTile();

  @override
  State<_ProfileVersionTile> createState() => _ProfileVersionTileState();
}

class _ProfileVersionTileState extends State<_ProfileVersionTile> {
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

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.locale,
    required this.ref,
  });

  final String label;
  final Locale locale;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final selected =
        context.locale.languageCode == locale.languageCode;
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
        await ref.read(appStateProvider.notifier).setLocale(locale);
      },
    );
  }
}
