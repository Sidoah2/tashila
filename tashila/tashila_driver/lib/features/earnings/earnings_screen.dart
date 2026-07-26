import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/app_format.dart';
import '../../core/models/models.dart';
import '../../core/state/driver_app_state.dart';
import '../../core/theme/app_colors.dart';
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
      ref
          .read(driverAppStateProvider.notifier)
          .syncPlatformEarningsFromServer();
    });
  }

  void _showTripDetailSheet(
    TripRecord trip,
    NumberFormat money,
    String dateLabel,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final statusLabel = trip.cashConfirmed
            ? 'confirmed'.tr()
            : 'pending'.tr();
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          elevation: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(28),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Orange gradient header
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.brandOrange, Color(0xFFFF9E80)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'earnings_trip_detail_title'.tr(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  money.format(trip.fare),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Route section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF43A047),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      width: 2,
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      color: AppColors.textSecondary.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: AppColors.brandOrange,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trip.pickup,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      trip.dropOff,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Details
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _detailRow(
                            ctx,
                            'earnings_trip_detail_client'.tr(),
                            trip.clientName,
                          ),
                          _detailRow(
                            ctx,
                            'earnings_trip_detail_distance'.tr(),
                            '${westernDigits(trip.distanceKm.toStringAsFixed(1))} ${'trip_summary_km_unit'.tr()}',
                          ),
                          _detailRow(
                            ctx,
                            'earnings_trip_detail_completed'.tr(),
                            dateLabel,
                          ),
                          if (trip.rating != null)
                            _detailRow(
                              ctx,
                              'rating'.tr(),
                              westernDigits('${trip.rating}'),
                            ),
                          _detailRow(ctx, 'earnings_trip_detail_id'.tr(), trip.id),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
      padding: const EdgeInsets.all(18),
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
                  Icons.account_balance_rounded,
                  color: AppColors.brandOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'earnings_platform_summary'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _platformStatRow(
            label: 'earnings_platform_due'.tr(),
            value: money.format(e.platformDueDzd),
            icon: Icons.receipt_long_rounded,
            iconBg: Colors.blue.shade50,
            iconColor: Colors.blue.shade700,
          ),
          const SizedBox(height: 12),
          _platformStatRow(
            label: 'earnings_platform_paid'.tr(),
            value: money.format(e.paidDzd),
            icon: Icons.check_circle_outline_rounded,
            iconBg: Colors.teal.shade50,
            iconColor: Colors.teal.shade700,
          ),
          const SizedBox(height: 12),
          _platformStatRow(
            label: 'earnings_platform_net'.tr(),
            value: money.format(e.netDzd),
            icon: Icons.monetization_on_rounded,
            iconBg: AppColors.brandOrange.withValues(alpha: 0.12),
            iconColor: AppColors.brandOrange,
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _platformStatRow({
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
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: emphasize ? 17 : 14.5,
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
    final maxValue = data.points.fold<double>(
      0,
      (m, p) => p.value > m ? p.value : m,
    );
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final trendPrefix = data.trendPercent >= 0 ? '+' : '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            backgroundColor: AppColors.brandOrange,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
              title: Text(
                'earnings_summary'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.brandOrange, Color(0xFFFF9E80)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _platformEarningsCard(
                  earnings: state.platformEarnings,
                  money: money,
                ),
                const SizedBox(height: 14),
                _summaryCard(
                  total: _metric == EarningsMetric.earnings
                      ? money.format(data.totalEarnings)
                      : westernDigits('${data.totalTrips}'),
                  trend:
                      '$trendPrefix${westernDigits(data.trendPercent.toStringAsFixed(1))}%',
                ),
                const SizedBox(height: 14),
                _chartCard(data: data, maxValue: safeMax, money: money),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        color: Colors.green.shade700,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'completed_trips'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (data.completedTrips.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'no_completed_trips'.tr(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                for (final trip in data.completedTrips.take(10))
                  _tripRow(
                    trip: trip,
                    dateLabel: formatTripDate(trip.completedAt),
                    money: money,
                    onTap: () => _showTripDetailSheet(
                      trip,
                      money,
                      formatTripDate(trip.completedAt),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({required String total, required String trend}) {
    final isNegative = trend.startsWith('-');
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandOrange, Color(0xFFFF9E80)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandOrange.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'earnings_weekly_summary'.tr(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            total,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isNegative ? Icons.trending_down : Icons.trending_up,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  'earnings_vs_previous'.tr(namedArgs: {'value': trend}),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'earnings_week_chart'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _pageOffset += 1),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chevron_left, size: 20),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  data.periodLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _pageOffset > 0
                    ? () => setState(() => _pageOffset -= 1)
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: _pageOffset > 0
                        ? AppColors.textPrimary
                        : AppColors.textSecondary.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricChip(
                  label: 'earnings_metric_earnings'.tr(),
                  selected: _metric == EarningsMetric.earnings,
                  onTap: () =>
                      setState(() => _metric = EarningsMetric.earnings),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                metricValue,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                selected.label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                              duration: const Duration(milliseconds: 200),
                              height:
                                  12 + (data.points[i].value / maxValue) * 84,
                              decoration: BoxDecoration(
                                color: i == data.selectedIndex
                                    ? AppColors.brandOrange
                                    : AppColors.brandOrange.withValues(
                                        alpha: 0.18,
                                      ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              data.points[i].label,
                              style: TextStyle(
                                fontSize: 11,
                                color: i == data.selectedIndex
                                    ? AppColors.brandOrange
                                    : AppColors.textSecondary,
                                fontWeight: i == data.selectedIndex
                                    ? FontWeight.w800
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _periodChip(EarningsPeriod.week, 'earnings_period_week'.tr()),
              _periodChip(EarningsPeriod.month, 'earnings_period_month'.tr()),
            ],
          ),
        ],
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandOrange.withValues(alpha: 0.12)
              : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.brandOrange.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13,
              color: selected ? AppColors.brandOrange : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _periodChip(EarningsPeriod period, String label) {
    final selected = _period == period;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.brandOrange.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        fontSize: 12,
        color: selected ? AppColors.brandOrange : AppColors.textSecondary,
      ),
      side: BorderSide(
        color: selected
            ? AppColors.brandOrange.withValues(alpha: 0.4)
            : AppColors.textSecondary.withValues(alpha: 0.15),
      ),
      onSelected: (_) => setState(() {
        _period = period;
        _selectedIndex = 0;
      }),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    size: 22,
                    color: AppColors.brandOrange,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            money.format(trip.fare),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor.shade800,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trip.clientName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
    );
  }
}
