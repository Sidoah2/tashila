import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/app_format.dart';
import '../../core/models/models.dart';
import '../../core/state/driver_app_state.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_language_menu.dart';
import 'earnings_analytics.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  EarningsPeriod _period = EarningsPeriod.week;
  EarningsMetric _metric = EarningsMetric.earnings;
  int _pageOffset = 0;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(driverAppStateProvider.notifier).syncPlatformEarningsFromServer();
    });
  }

  void _showTripDetailSheet(TripRecord trip, NumberFormat money, String dateLabel) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final statusLabel = trip.cashConfirmed ? 'confirmed'.tr() : 'pending'.tr();
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
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
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
              _detailRow(ctx, 'earnings_trip_detail_client'.tr(), trip.clientName),
              _detailRow(
                ctx,
                'earnings_trip_detail_distance'.tr(),
                '${westernDigits(trip.distanceKm.toStringAsFixed(1))} ${'trip_summary_km_unit'.tr()}',
              ),
              _detailRow(ctx, 'earnings_trip_detail_pickup'.tr(), trip.pickup),
              _detailRow(ctx, 'earnings_trip_detail_dropoff'.tr(), trip.dropOff),
              _detailRow(ctx, 'earnings_trip_detail_completed'.tr(), dateLabel),
              if (trip.rating != null)
                _detailRow(
                  ctx,
                  'rating'.tr(),
                  westernDigits('${trip.rating}'),
                ),
              _detailRow(
                ctx,
                'earnings_trip_detail_id'.tr(),
                trip.id,
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                    color: emphasize ? AppColors.brandOrange : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _platformEarningsCard({
    required DriverPlatformEarnings? earnings,
    required NumberFormat money,
  }) {
    final e = earnings ?? const DriverPlatformEarnings();
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'earnings_platform_summary'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _platformStatRow('earnings_platform_due'.tr(), money.format(e.platformDueDzd)),
            const SizedBox(height: 8),
            _platformStatRow('earnings_platform_paid'.tr(), money.format(e.paidDzd)),
            const SizedBox(height: 8),
            _platformStatRow(
              'earnings_platform_net'.tr(),
              money.format(e.netDzd),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _platformStatRow(String label, String value, {bool emphasize = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: emphasize ? 18 : 15,
            color: emphasize ? AppColors.brandOrange : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverAppStateProvider);
    final money = dzdCurrency();
    final dateFmt = DateFormat('MMM d, HH:mm', context.locale.languageCode);
    String formatTripDate(DateTime d) => westernDigits(dateFmt.format(d));
    final allTrips = state.tripHistory;
    final data = EarningsAnalytics.build(
      allTrips: allTrips,
      period: _period,
      metric: _metric,
      pageOffset: _pageOffset,
      selectedIndex: _selectedIndex,
      locale: context.locale.languageCode,
    );
    final maxValue = data.points.fold<double>(0, (m, p) => p.value > m ? p.value : m);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final trendPrefix = data.trendPercent >= 0 ? '+' : '';

    return Scaffold(
      appBar: AppBar(
        title: Text('earnings_summary'.tr()),
        actions: const [AuthLanguageMenu()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _platformEarningsCard(earnings: state.platformEarnings, money: money),
          const SizedBox(height: 12),
          _summaryCard(
            total: _metric == EarningsMetric.earnings
                ? money.format(data.totalEarnings)
                : westernDigits('${data.totalTrips}'),
            trend: '$trendPrefix${westernDigits(data.trendPercent.toStringAsFixed(1))}%',
          ),
          const SizedBox(height: 12),
          _chartCard(
            data: data,
            maxValue: safeMax,
            money: money,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'completed_trips'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (data.completedTrips.isEmpty) Text('no_completed_trips'.tr()),
          for (final trip in data.completedTrips.take(10))
            _tripRow(
              trip: trip,
              dateLabel: formatTripDate(trip.completedAt),
              money: money,
              onTap: () => _showTripDetailSheet(trip, money, formatTripDate(trip.completedAt)),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard({required String total, required String trend}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandOrange,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'earnings_weekly_summary'.tr(),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            total,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'earnings_vs_previous'.tr(namedArgs: {'value': trend}),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartCard({
    required EarningsViewData data,
    required double maxValue,
    required NumberFormat money,
  }) {
    final selected = data.selectedPoint;
    final metricValue = _metric == EarningsMetric.earnings
        ? money.format(selected.value)
        : westernDigits('${selected.tripCount}');

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'earnings_week_chart'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _pageOffset += 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(data.periodLabel, style: const TextStyle(fontSize: 12)),
                IconButton(
                  onPressed: _pageOffset > 0
                      ? () => setState(() => _pageOffset -= 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _metricChip(
                    label: 'earnings_metric_earnings'.tr(),
                    selected: _metric == EarningsMetric.earnings,
                    onTap: () => setState(() => _metric = EarningsMetric.earnings),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metricChip(
                    label: 'earnings_metric_trips'.tr(),
                    selected: _metric == EarningsMetric.trips,
                    onTap: () => setState(() => _metric = EarningsMetric.trips),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  metricValue,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 28),
                ),
                const SizedBox(width: 8),
                Text(selected.label, style: const TextStyle(color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < data.points.length; i++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedIndex = i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                height: 12 + (data.points[i].value / maxValue) * 84,
                                decoration: BoxDecoration(
                                  color: i == data.selectedIndex
                                      ? AppColors.brandOrange
                                      : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                data.points[i].label,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: i == data.selectedIndex
                                      ? AppColors.brandOrange
                                      : Colors.black54,
                                  fontWeight: i == data.selectedIndex
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _periodChip(EarningsPeriod.week, 'earnings_period_week'.tr()),
                _periodChip(EarningsPeriod.month, 'earnings_period_month'.tr()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandOrange.withValues(alpha: 0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.brandOrange : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.brandOrange : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _periodChip(EarningsPeriod period, String label) {
    final selected = _period == period;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _period = period;
        _selectedIndex = 0;
      }),
      selectedColor: AppColors.brandOrange.withValues(alpha: 0.18),
    );
  }

  Widget _tripRow({
    required TripRecord trip,
    required String dateLabel,
    required NumberFormat money,
    required VoidCallback onTap,
  }) {
    final statusLabel = trip.cashConfirmed ? 'confirmed'.tr() : 'pending'.tr();
    final statusColor = trip.cashConfirmed ? Colors.green : Colors.orange;
    return Semantics(
      button: true,
      label: '${trip.clientName}, ${money.format(trip.fare)}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.shade100,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor.shade800,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              money.format(trip.fare),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${trip.id} • ${trip.clientName}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      Text(
                        dateLabel,
                        style: const TextStyle(color: Colors.black38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_taxi, size: 18, color: AppColors.brandOrange),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
