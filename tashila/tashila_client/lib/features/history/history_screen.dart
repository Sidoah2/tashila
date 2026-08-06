import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tashila_client/core/formatting/app_format.dart';
import 'package:tashila_client/core/state/app_state.dart';
import 'package:tashila_client/core/theme/app_colors.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(appStateProvider).history;
    final money = dzdCurrency();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    final dailyTrips = history.where((t) {
      final localTime = t.date.toLocal();
      return localTime.isAfter(todayStart) ||
          localTime.isAtSameMomentAs(todayStart);
    }).toList();

    final monthlyTrips = history.where((t) {
      final localTime = t.date.toLocal();
      return localTime.isAfter(monthStart) ||
          localTime.isAtSameMomentAs(monthStart);
    }).toList();

    final yearlyTrips = history.where((t) {
      final localTime = t.date.toLocal();
      return localTime.isAfter(yearStart) ||
          localTime.isAtSameMomentAs(yearStart);
    }).toList();

    return ColoredBox(
      color: AppColors.bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'trip_history_title'.tr(),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),
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
            // History Transaction List
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _HistoryListView(trips: dailyTrips, money: money),
                  _HistoryListView(trips: monthlyTrips, money: money),
                  _HistoryListView(trips: yearlyTrips, money: money),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryListView extends StatelessWidget {
  const _HistoryListView({required this.trips, required this.money});

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
        final statusLabel = trip.cancelled
            ? 'trip_status_cancelled'.tr()
            : 'trip_status_completed'.tr();
        final truckLabel = trip.truckType == TruckType.singleCabine
            ? 'single_cabine'.tr()
            : 'double_cabine'.tr();

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
                trip.cancelled ? '—' : money.format(trip.price),
                emphasize: !trip.cancelled,
              ),
              _detailRow(ctx, 'earnings_trip_detail_status'.tr(), statusLabel),
              _detailRow(ctx, 'truck_type_label'.tr(), truckLabel),
              _detailRow(ctx, 'earnings_trip_detail_pickup'.tr(), trip.pickup),
              _detailRow(
                ctx,
                'earnings_trip_detail_dropoff'.tr(),
                trip.dropoff,
              ),
              _detailRow(ctx, 'earnings_trip_detail_completed'.tr(), dateLabel),
              if (!trip.cancelled && trip.rating > 0)
                _detailRow(ctx, 'rating'.tr(), westernDigits('${trip.rating}')),
              if (trip.cancelled && trip.cancellationReason.isNotEmpty)
                _detailRow(
                  ctx,
                  'cancellation_reason_label'.tr(),
                  trip.cancellationReason.tr(),
                ),
              if (trip.comment.isNotEmpty)
                _detailRow(ctx, 'comment_label'.tr(), trip.comment),
              if (trip.goodTraits.isNotEmpty)
                _detailRow(
                  ctx,
                  'good_traits_label'.tr(),
                  trip.goodTraits.join(', '),
                ),
              if (trip.badTraits.isNotEmpty)
                _detailRow(
                  ctx,
                  'bad_traits_label'.tr(),
                  trip.badTraits.join(', '),
                ),
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
              Icons.history_rounded,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'no_history'.tr(),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      itemCount: trips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final record = trips[index];
        final dateStr = westernDigits(dateFmt.format(record.date));

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
                    color: !record.cancelled
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
                          !record.cancelled
                              ? 'trip_status_completed'.tr()
                              : 'trip_status_cancelled'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: !record.cancelled
                                ? const Color(0xFF2E7D32)
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    record.cancelled ? '—' : money.format(record.price),
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
