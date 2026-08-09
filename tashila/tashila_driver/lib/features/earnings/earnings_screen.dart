import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/app_format.dart';
import '../../core/models/models.dart';
import '../../core/state/driver_app_state.dart';
import '../../core/theme/app_colors.dart';
import '../home/driver_home_screen.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(driverAppStateProvider.notifier)
          .syncPlatformEarningsFromServer();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverAppStateProvider);
    final money = dzdCurrency();
    final trips = state.tripHistory;
    final CompletedTrips = trips.where((t) => t.status == "completed");
    final totalBalance = CompletedTrips.fold(0.0, (sum, t) => sum + t.fare);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    final dailyTrips = trips.where((t) {
      final localTime = t.completedAt.toLocal();
      return localTime.isAfter(todayStart) ||
          localTime.isAtSameMomentAs(todayStart);
    }).toList();

    final monthlyTrips = trips.where((t) {
      final localTime = t.completedAt.toLocal();
      return localTime.isAfter(monthStart) ||
          localTime.isAtSameMomentAs(monthStart);
    }).toList();

    final yearlyTrips = trips.where((t) {
      final localTime = t.completedAt.toLocal();
      return localTime.isAfter(yearStart) ||
          localTime.isAtSameMomentAs(yearStart);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,

        title: Text(
          'earnings_tab'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),

      body: Column(
        children: [
          const SizedBox(height: 16),
          // Total Balance Header Section
          Text(
            'total_balance'.tr(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            money.format(totalBalance),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.brandOrange,
            ),
          ),
          const SizedBox(height: 20),

          // Tab Bar Filters: Daily | Monthly | Yearly
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),

            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.brandOrange,
              indicatorWeight: 3,
              labelColor: AppColors.brandOrange,
              indicatorSize: TabBarIndicatorSize.tab,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              dividerColor: Colors.transparent,
              dividerHeight: 0,

              tabs: [
                Tab(text: 'daily'.tr()),
                Tab(text: 'monthly'.tr()),
                Tab(text: 'yearly'.tr()),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Earnings Transaction List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _EarningsListView(trips: dailyTrips, money: money),
                _EarningsListView(trips: monthlyTrips, money: money),
                _EarningsListView(trips: yearlyTrips, money: money),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsListView extends StatelessWidget {
  const _EarningsListView({required this.trips, required this.money});

  final List<TripRecord> trips;
  final NumberFormat money;

  void _showTripDetailSheet(
    BuildContext context,
    TripRecord trip,
    NumberFormat money,
    String dateLabel,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        final statusLabel = trip.status == "completed"
            ? 'order_completed'.tr()
            : trip.status == "cancelled"
            ? 'order_cancelled'.tr()
            : trip.status;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            20 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'earnings_trip_detail_title'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _detailRow(
                ctx,
                'earnings_trip_detail_fare'.tr(),
                money.format(trip.fare),
                emphasize: true,
              ),
              _detailRow(ctx, 'earnings_trip_detail_status'.tr(), statusLabel),
              _detailRow(
                ctx,
                'earnings_trip_detail_distance'.tr(),
                '${westernDigits(trip.distanceKm.toStringAsFixed(1))} km',
              ),
              _detailRow(ctx, 'earnings_trip_detail_pickup'.tr(), trip.pickup),
              _detailRow(
                ctx,
                'earnings_trip_detail_dropoff'.tr(),
                trip.dropOff,
              ),
              _detailRow(ctx, 'earnings_trip_detail_completed'.tr(), dateLabel),
              if (trip.rating != null)
                _detailRow(ctx, 'rating'.tr(), westernDigits('${trip.rating}')),
              _detailRow(ctx, 'earnings_trip_detail_id'.tr(), trip.id),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                color: emphasize
                    ? AppColors.brandOrange
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'no_earnings_records'.tr(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final dateFmt = DateFormat('MMM d, yyyy h:mm a');

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: trips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final record = trips[index];
        final dateStr = westernDigits(dateFmt.format(record.completedAt));

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showTripDetailSheet(context, record, money, dateStr),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    color: record.status == "completed"
                        ? AppColors.brandOrange
                        : Colors.red,
                    width: 2,
                    height: 60,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          record.status == "completed"
                              ? 'order_completed'.tr()
                              : record.status == "cancelled"
                              ? "order_cancelled".tr()
                              : record.status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: record.status == "completed"
                                ? const Color(0xFF2E7D32)
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    money.format(record.fare),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
