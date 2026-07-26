import '../../core/formatting/app_format.dart';
import '../../core/models/models.dart';
import 'package:intl/intl.dart';

enum EarningsPeriod { week, month }

enum EarningsMetric { earnings, trips }

class EarningsPoint {
  const EarningsPoint({
    required this.label,
    required this.value,
    required this.tripCount,
    required this.bucketStart,
  });

  final String label;
  final double value;
  final int tripCount;
  final DateTime bucketStart;
}

class EarningsViewData {
  const EarningsViewData({
    required this.period,
    required this.periodAnchor,
    required this.periodLabel,
    required this.totalEarnings,
    required this.totalTrips,
    required this.points,
    required this.selectedIndex,
    required this.selectedPoint,
    required this.completedTrips,
    required this.trendPercent,
  });

  final EarningsPeriod period;
  final DateTime periodAnchor;
  final String periodLabel;
  final double totalEarnings;
  final int totalTrips;
  final List<EarningsPoint> points;
  final int selectedIndex;
  final EarningsPoint selectedPoint;
  final List<TripRecord> completedTrips;
  final double trendPercent;
}

class EarningsAnalytics {
  const EarningsAnalytics._();

  static EarningsViewData build({
    required List<TripRecord> allTrips,
    required EarningsPeriod period,
    required EarningsMetric metric,
    required int pageOffset,
    required int selectedIndex,
    required String locale,
  }) {
    final now = DateTime.now();
    final anchor = _shiftedAnchor(now, period, pageOffset);
    final range = _periodRange(anchor, period);
    final previous = _periodRange(_shiftedAnchor(now, period, pageOffset + 1), period);

    final validTrips = allTrips.where((t) => !t.isCancelled && t.isCompleted).toList();

    final periodTrips = validTrips
        .where((t) => !t.completedAt.isBefore(range.start) && t.completedAt.isBefore(range.end))
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    final previousTrips = validTrips
        .where((t) => !t.completedAt.isBefore(previous.start) && t.completedAt.isBefore(previous.end))
        .toList();

    final points = _buildPoints(periodTrips, period, range.start, metric, locale);
    final safeIndex = points.isEmpty
        ? 0
        : (selectedIndex.clamp(0, points.length - 1));
    final fallbackPoint = EarningsPoint(
      label: '',
      value: 0,
      tripCount: 0,
      bucketStart: range.start,
    );
    final selectedPoint = points.isEmpty ? fallbackPoint : points[safeIndex];

    final totalEarnings = periodTrips.fold<double>(0, (sum, t) => sum + t.fare);
    final prevEarnings = previousTrips.fold<double>(0, (sum, t) => sum + t.fare);
    final trend = prevEarnings <= 0
        ? 0.0
        : ((totalEarnings - prevEarnings) / prevEarnings) * 100;

    return EarningsViewData(
      period: period,
      periodAnchor: anchor,
      periodLabel: _labelForPeriod(anchor, period, locale),
      totalEarnings: totalEarnings,
      totalTrips: periodTrips.length,
      points: points,
      selectedIndex: safeIndex,
      selectedPoint: selectedPoint,
      completedTrips: periodTrips,
      trendPercent: trend,
    );
  }

  static DateTime _shiftedAnchor(DateTime now, EarningsPeriod period, int pageOffset) {
    switch (period) {
      case EarningsPeriod.week:
        final start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        return start.subtract(Duration(days: 7 * pageOffset));
      case EarningsPeriod.month:
        return DateTime(now.year, now.month - pageOffset, 1);
    }
  }

  static ({DateTime start, DateTime end}) _periodRange(DateTime anchor, EarningsPeriod period) {
    switch (period) {
      case EarningsPeriod.week:
        return (start: anchor, end: anchor.add(const Duration(days: 7)));
      case EarningsPeriod.month:
        return (start: anchor, end: DateTime(anchor.year, anchor.month + 1, 1));
    }
  }

  static List<EarningsPoint> _buildPoints(
    List<TripRecord> trips,
    EarningsPeriod period,
    DateTime periodStart,
    EarningsMetric metric,
    String locale,
  ) {
    final buckets = <DateTime, List<TripRecord>>{};
    final labels = <String>[];
    final starts = <DateTime>[];
    final count = period == EarningsPeriod.week ? 7 : 6;

    for (var i = 0; i < count; i++) {
      DateTime start;
      String label;
      if (period == EarningsPeriod.week) {
        start = periodStart.add(Duration(days: i));
        label = westernDigits(DateFormat.E(locale).format(start));
      } else {
        start = DateTime(periodStart.year, periodStart.month, (i * 5) + 1);
        label = westernDigits('${i + 1}');
      }
      starts.add(start);
      labels.add(label);
      buckets[start] = <TripRecord>[];
    }

    for (final trip in trips) {
      DateTime key;
      if (period == EarningsPeriod.week) {
        final idx = trip.completedAt.weekday - 1;
        key = starts[idx];
      } else {
        final idx = ((trip.completedAt.day - 1) / 5).floor().clamp(0, 5);
        key = starts[idx];
      }
      buckets[key]!.add(trip);
    }

    return List.generate(starts.length, (index) {
      final list = buckets[starts[index]]!;
      final earnings = list.fold<double>(0, (sum, t) => sum + t.fare);
      return EarningsPoint(
        label: labels[index],
        value: metric == EarningsMetric.earnings ? earnings : list.length.toDouble(),
        tripCount: list.length,
        bucketStart: starts[index],
      );
    });
  }

  static String _labelForPeriod(DateTime anchor, EarningsPeriod period, String locale) {
    if (period == EarningsPeriod.week) {
      final end = anchor.add(const Duration(days: 6));
      return '${formatDateWesternDigits('MMMd', anchor, locale)} - ${formatDateWesternDigits('MMMd', end, locale)}';
    }
    return formatDateWesternDigits('yMMM', anchor, locale);
  }
}
