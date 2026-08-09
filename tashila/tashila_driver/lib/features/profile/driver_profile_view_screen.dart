import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/state/driver_app_state.dart';
import '../../core/theme/app_colors.dart';
import '../home/driver_home_screen.dart';

class DriverProfileViewScreen extends ConsumerWidget {
  const DriverProfileViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverAppStateProvider);
    final profile = state.profile;
    final approved = profile?.documentsApproved ?? false;
    final firstLetter = (profile?.name ?? 'D').characters.first.toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'profile_title'.tr(),
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
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(
              Icons.menu_rounded,
              color: AppColors.textPrimary,
              size: 24,
            ),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: AppColors.brandOrange,
                size: 20,
              ),
            ),
            tooltip: 'edit_profile'.tr(),
            onPressed: () => context.push('/profile-edit'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const DriverDrawer(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // ── HERO PROFILE HEADER CARD ──
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
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.brandOrange,
                                Color(0xFFFF9100),
                              ],
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
                        ),
                        Container(
                          width: 82,
                          height: 82,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CircleAvatar(
                              radius: 38,
                              backgroundColor: AppColors.brandOrange.withValues(
                                alpha: 0.15,
                              ),
                              backgroundImage: (profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(profile.avatarUrl!)
                                  : null,
                              child: (profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty)
                                  ? Text(
                                      firstLetter,
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.brandOrange,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Driver Name & Phone
                  Text(
                    profile?.name ?? 'driver_name'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.phone_iphone_rounded,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '\u200E${profile?.phone ?? state.phone}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Account Status Pill Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: approved
                          ? Colors.green.shade50
                          : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: approved
                            ? Colors.green.shade300
                            : AppColors.brandOrange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          approved
                              ? Icons.verified_user_rounded
                              : Icons.pending_actions_rounded,
                          size: 16,
                          color: approved
                              ? Colors.green.shade700
                              : AppColors.brandOrange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          approved
                              ? 'account_approved'.tr()
                              : 'pending_approval'.tr(),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: approved
                                ? Colors.green.shade700
                                : AppColors.brandOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── QUICK STATS ROW ──
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCardItem(
                      icon: Icons.local_shipping_rounded,
                      iconColor: AppColors.brandOrange,
                      value: '${state.tripHistory.length}',
                      label: 'total_trips'.tr(),
                    ),
                  ),
                  Container(height: 44, width: 1, color: Colors.grey.shade200),
                  Expanded(
                    child: _StatCardItem(
                      icon: Icons.star_rounded,
                      iconColor: Colors.amber.shade700,
                      value: '5.0',
                      label: 'driver_rating'.tr(),
                    ),
                  ),
                  Container(height: 44, width: 1, color: Colors.grey.shade200),
                  Expanded(
                    child: _StatCardItem(
                      icon: Icons.shield_rounded,
                      iconColor: approved ? AppColors.success : Colors.orange,
                      value: approved ? 'Active' : 'Pending',
                      label: 'Status',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── VEHICLE SPECIFICATION DETAILS CARD ──
            _SectionHeader(
              title: 'vehicle_info_title'.tr(),
              icon: Icons.directions_car_rounded,
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
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
                  _InfoTile(
                    icon: Icons.local_shipping_rounded,
                    label: 'truck_type'.tr(),
                    value: (profile?.truckType ?? '').isNotEmpty
                        ? (profile?.truckType == 'double_cabin'
                              ? 'truck_double_cabin'.tr()
                              : 'truck_single_cabin'.tr())
                        : 'not_specified'.tr(),
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _InfoTile(
                    icon: Icons.directions_car_rounded,
                    label: 'vehicle_model'.tr(),
                    value: profile?.vehicleModel.isNotEmpty == true
                        ? profile!.vehicleModel
                        : 'not_specified'.tr(),
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _InfoTile(
                    icon: Icons.palette_rounded,
                    label: 'vehicle_color'.tr(),
                    value: profile?.vehicleColor.isNotEmpty == true
                        ? profile!.vehicleColor
                        : 'not_specified'.tr(),
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _InfoTile(
                    icon: Icons.badge_rounded,
                    label: 'vehicle_plate'.tr(),
                    value: profile?.vehiclePlate.isNotEmpty == true
                        ? profile!.vehiclePlate
                        : 'not_specified'.tr(),
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.brandOrange),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.brandOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.brandOrange),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCardItem extends StatelessWidget {
  const _StatCardItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
