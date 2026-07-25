import type { TripStatus } from "../types";
import { apiFetch } from "./client";
import { getPlatformSettings } from "./settings";

/** Inclusive YYYY-MM-DD bounds for the chart range selector in the UI. */
export type DashboardChartRange = { start: string; end: string };

export type DashboardStats = {
  todayRevenue: number;
  todayTrips: number;
  periodRevenue: number;
  periodTrips: number;
  netPlatformRevenue: number;
  cancellationRatePercent: number;
  periodCompletedTrips: number;
  periodCancelledTrips: number;
  activeDrivers: number;
  totalDrivers: number;
  pendingApprovals: number;
  totalUsers: number;
  liveTrips: number;
  dailyRevenue: { date: string; revenue: number; trips: number }[];
  statusCounts: Record<TripStatus, number>;
  topDrivers: {
    driverId: string;
    driverName: string;
    revenue: number;
    trips: number;
  }[];
};

interface ApiDashboardKpis {
  activeUsers: number;
  approvedDrivers: number;
  onlineDrivers?: number;
  tripsByStatus: Record<string, number>;
  monthRevenue: number;
  allTimeRevenue: number;
  todayRevenue?: number;
  todayTrips?: number;
  activeTrips: number;
  pendingApprovals: number;
  periodRevenue?: number;
  periodCompletedTrips?: number;
  periodCancelledTrips?: number;
}

interface ApiRevenueChart {
  labels: string[];
  revenue: number[];
  trips: number[];
}

interface ApiTopDriver {
  driverId: string;
  name: string | null;
  truckType: string | null;
  totalEarnedDzd: number;
  completedTrips: number;
}

function rangeQuery(range: DashboardChartRange): string {
  return `from=${encodeURIComponent(range.start)}&to=${encodeURIComponent(range.end)}`;
}

export function defaultDashboardChartRange(): DashboardChartRange {
  const end = new Date();
  const start = new Date(end);
  start.setDate(start.getDate() - 13);
  return {
    start: start.toISOString().slice(0, 10),
    end: end.toISOString().slice(0, 10),
  };
}

export async function getDashboardStats(
  range: DashboardChartRange,
): Promise<DashboardStats> {
  const q = rangeQuery(range);

  const [kpis, revenueChart, topDrivers, settings] = await Promise.all([
    apiFetch<ApiDashboardKpis>(`/admin/stats/dashboard?${q}`),
    apiFetch<ApiRevenueChart>(`/admin/stats/revenue?${q}`),
    apiFetch<ApiTopDriver[]>(`/admin/stats/top-drivers?limit=10&${q}`),
    getPlatformSettings(),
  ]);

  const statusCounts: Record<TripStatus, number> = {
    requested: 0,
    accepted: 0,
    headingToPickup: 0,
    inProgress: 0,
    awaitingCash: 0,
    completed: 0,
    cancelled: 0,
  };
  for (const [k, v] of Object.entries(kpis.tripsByStatus)) {
    if (k in statusCounts) {
      statusCounts[k as TripStatus] = v;
    }
  }

  const dailyRevenue = revenueChart.labels.map((date, i) => ({
    date,
    revenue: revenueChart.revenue[i] ?? 0,
    trips: revenueChart.trips[i] ?? 0,
  }));

  const periodCompleted = kpis.periodCompletedTrips ?? statusCounts.completed;
  const periodCancelled = kpis.periodCancelledTrips ?? statusCounts.cancelled;
  const finished = periodCompleted + periodCancelled;
  const cancellationRatePercent =
    finished > 0 ? Math.round((periodCancelled / finished) * 100) : 0;

  const periodTrips = dailyRevenue.reduce((s, d) => s + d.trips, 0);
  const periodRevenue = kpis.periodRevenue ?? revenueChart.revenue.reduce((s, v) => s + v, 0);
  const netPlatformRevenue = Math.round(periodRevenue * settings.commissionRate);

  return {
    todayRevenue: kpis.todayRevenue ?? 0,
    todayTrips: kpis.todayTrips ?? 0,
    periodRevenue,
    periodTrips,
    netPlatformRevenue,
    cancellationRatePercent,
    periodCompletedTrips: periodCompleted,
    periodCancelledTrips: periodCancelled,
    activeDrivers: kpis.onlineDrivers ?? kpis.approvedDrivers,
    totalDrivers: kpis.approvedDrivers,
    pendingApprovals: kpis.pendingApprovals,
    totalUsers: kpis.activeUsers,
    liveTrips: kpis.activeTrips,
    dailyRevenue,
    statusCounts,
    topDrivers: topDrivers.map((d) => ({
      driverId: d.driverId,
      driverName: d.name ?? d.driverId,
      revenue: d.totalEarnedDzd,
      trips: d.completedTrips,
    })),
  };
}

export async function getPendingApprovalCount(): Promise<number> {
  const data = await apiFetch<{ pendingDrivers: number; pendingDocuments: number }>(
    "/admin/stats/pending-approvals",
  );
  return data.pendingDrivers;
}
