"use client";

import { useEffect, useMemo, useState } from "react";
import Box from "@mui/material/Box";
import Card from "@mui/material/Card";
import CardContent from "@mui/material/CardContent";
import Stack from "@mui/material/Stack";
import Typography from "@mui/material/Typography";
import TextField from "@mui/material/TextField";
import Button from "@mui/material/Button";
import Skeleton from "@mui/material/Skeleton";
import Table from "@mui/material/Table";
import TableBody from "@mui/material/TableBody";
import TableCell from "@mui/material/TableCell";
import TableHead from "@mui/material/TableHead";
import TableRow from "@mui/material/TableRow";
import Chip from "@mui/material/Chip";
import { LineChart } from "@mui/x-charts/LineChart";
import { BarChart } from "@mui/x-charts/BarChart";
import PaymentsRoundedIcon from "@mui/icons-material/PaymentsRounded";
import RouteRoundedIcon from "@mui/icons-material/RouteRounded";
import LocalShippingRoundedIcon from "@mui/icons-material/LocalShippingRounded";
import HourglassTopRoundedIcon from "@mui/icons-material/HourglassTopRounded";
import {
  defaultDashboardChartRange,
  getDashboardStats,
  type DashboardStats,
} from "@/lib/api/stats";
import KpiCard from "@/components/KpiCard";
import { brand } from "@/theme/colors";
import { getTripStatusLabel } from "@/lib/labels";
import { TripStatusChip } from "@/components/StatusChip";
import type { TripStatus } from "@/lib/types";
import { useTranslation } from "@/i18n/useTranslation";
import { parseLocalYmd } from "@/lib/format";
import {
  localeToIntl,
  useFormatDzd,
  useFormatNumber,
} from "@/i18n/format";

export default function DashboardPage() {
  const { t, locale } = useTranslation();
  const formatDzd = useFormatDzd();
  const formatNumber = useFormatNumber();
  const defaultRange = useMemo(() => defaultDashboardChartRange(), []);
  const [chartFrom, setChartFrom] = useState(defaultRange.start);
  const [chartTo, setChartTo] = useState(defaultRange.end);
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [chartsLoading, setChartsLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setChartsLoading(true);
    getDashboardStats({ start: chartFrom, end: chartTo }).then((s) => {
      if (cancelled) return;
      setStats(s);
      setChartsLoading(false);
    });
    return () => {
      cancelled = true;
    };
  }, [chartFrom, chartTo]);

  const dailyDates =
    stats?.dailyRevenue.map((d) => parseLocalYmd(d.date)) ?? [];
  const dailyRevenue = stats?.dailyRevenue.map((d) => d.revenue) ?? [];
  const dailyTrips = stats?.dailyRevenue.map((d) => d.trips) ?? [];

  const dateAxisFormatter = useMemo(() => {
    const fmt = new Intl.DateTimeFormat(localeToIntl(locale), {
      day: "2-digit",
      month: "short",
    });
    return (v: Date) => fmt.format(v);
  }, [locale]);

  return (
    <Stack spacing={3}>
      <Box
        sx={{
          display: "grid",
          gridTemplateColumns: { xs: "1fr", sm: "1fr 1fr", lg: "repeat(3, 1fr)" },
          gap: 2,
        }}
      >
        {stats ? (
          <>
            <KpiCard
              label={t("dashboard.trips_today")}
              value={formatNumber(stats.todayTrips)}
              hint={t("dashboard.trips_period_hint", {
                count: formatNumber(stats.periodTrips),
              })}
              icon={<RouteRoundedIcon />}
              accentColor={brand.orange}
            />
            <KpiCard
              label={t("dashboard.revenue_today")}
              value={formatDzd(stats.todayRevenue)}
              hint={t("dashboard.revenue_period_hint", {
                amount: formatDzd(stats.periodRevenue),
              })}
              icon={<PaymentsRoundedIcon />}
              accentColor={brand.success}
            />
            <KpiCard
              label={t("dashboard.active_drivers")}
              value={`${stats.activeDrivers} / ${stats.totalDrivers}`}
              hint={t("dashboard.live_trips_hint", {
                count: formatNumber(stats.liveTrips),
              })}
              icon={<LocalShippingRoundedIcon />}
              accentColor="#3478F6"
            />
            <KpiCard
              label={t("dashboard.net_platform_period")}
              value={formatDzd(stats.netPlatformRevenue)}
              hint={t("dashboard.net_platform_period_hint")}
              icon={<PaymentsRoundedIcon />}
              accentColor="#6C4AB6"
            />
            <KpiCard
              label={t("dashboard.cancellation_rate")}
              value={`${formatNumber(stats.cancellationRatePercent)}%`}
              hint={t("dashboard.cancellation_rate_hint", {
                cancelled: formatNumber(stats.periodCancelledTrips),
                completed: formatNumber(stats.periodCompletedTrips),
                total: formatNumber(
                  stats.periodCompletedTrips + stats.periodCancelledTrips,
                ),
              })}
              icon={<RouteRoundedIcon />}
              accentColor={brand.danger}
            />
            <Stack direction="row" spacing={1} sx={{ gridColumn: "1 / -1" }}>
              <Chip
                size="small"
                label={t("dashboard.cancellation_breakdown_cancelled", {
                  count: formatNumber(stats.periodCancelledTrips),
                })}
                sx={{ fontWeight: 600 }}
              />
              <Chip
                size="small"
                label={t("dashboard.cancellation_breakdown_completed", {
                  count: formatNumber(stats.periodCompletedTrips),
                })}
                sx={{ fontWeight: 600 }}
              />
            </Stack>
          </>
        ) : (
          Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} variant="rounded" height={108} />
          ))
        )}
      </Box>

      <Stack spacing={2}>
        <Card variant="outlined">
          <CardContent sx={{ py: 2 }}>
            <Stack
              direction={{ xs: "column", md: "row" }}
              spacing={2}
              alignItems={{ md: "center" }}
              justifyContent="space-between"
            >
              <Box>
                <Typography variant="subtitle1" sx={{ fontWeight: 700 }}>
                  {t("dashboard.chart_period_title")}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  {t("dashboard.chart_max_days_hint", { max: 180 })}
                </Typography>
              </Box>
              <Stack
                direction={{ xs: "column", sm: "row" }}
                spacing={1}
                alignItems={{ sm: "center" }}
              >
                <TextField
                  type="date"
                  label={t("common.from")}
                  value={chartFrom}
                  onChange={(e) => setChartFrom(e.target.value)}
                  InputLabelProps={{ shrink: true }}
                  size="small"
                  sx={{ minWidth: 150 }}
                />
                <TextField
                  type="date"
                  label={t("common.to")}
                  value={chartTo}
                  onChange={(e) => setChartTo(e.target.value)}
                  InputLabelProps={{ shrink: true }}
                  size="small"
                  sx={{ minWidth: 150 }}
                />
                <Button
                  variant="outlined"
                  size="small"
                  onClick={() => {
                    const r = defaultDashboardChartRange();
                    setChartFrom(r.start);
                    setChartTo(r.end);
                  }}
                >
                  {t("dashboard.chart_reset_last_14")}
                </Button>
              </Stack>
            </Stack>
          </CardContent>
        </Card>

        <Box
          sx={{
            display: "grid",
            gridTemplateColumns: { xs: "1fr", lg: "2fr 1fr" },
            gap: 2,
          }}
        >
        <Card>
          <CardContent>
            <Box sx={{ mb: 1 }}>
              <Typography variant="h6">
                {t("dashboard.revenue_chart_title")}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                {t("dashboard.revenue_chart_subtitle")}
              </Typography>
            </Box>
            {stats && !chartsLoading ? (
              <LineChart
                xAxis={[
                  {
                    data: dailyDates,
                    scaleType: "time",
                    valueFormatter: dateAxisFormatter,
                  },
                ]}
                series={[
                  {
                    data: dailyRevenue,
                    label: t("dashboard.revenue_series_label"),
                    color: brand.orange,
                    area: true,
                    showMark: false,
                    valueFormatter: (v) =>
                      v != null ? formatDzd(v as number) : "—",
                  },
                ]}
                height={280}
                margin={{ left: 60, right: 16, top: 24, bottom: 32 }}
                grid={{ horizontal: true }}
              />
            ) : (
              <Skeleton variant="rounded" height={280} />
            )}
          </CardContent>
        </Card>

        <Card>
          <CardContent>
            <Box sx={{ mb: 1 }}>
              <Typography variant="h6">
                {t("dashboard.trips_chart_title")}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                {t("dashboard.trips_chart_subtitle")}
              </Typography>
            </Box>
            {stats && !chartsLoading ? (
              <BarChart
                xAxis={[
                  {
                    data: dailyDates.map((d) => dateAxisFormatter(d)),
                    scaleType: "band",
                  },
                ]}
                series={[
                  {
                    data: dailyTrips,
                    label: t("dashboard.trips_series_label"),
                    color: brand.orange,
                  },
                ]}
                height={280}
                margin={{ left: 40, right: 16, top: 24, bottom: 50 }}
                grid={{ horizontal: true }}
              />
            ) : (
              <Skeleton variant="rounded" height={280} />
            )}
          </CardContent>
        </Card>
        </Box>
      </Stack>

      <Box
        sx={{
          display: "grid",
          gridTemplateColumns: { xs: "1fr", lg: "1fr 1fr" },
          gap: 2,
        }}
      >
        <Card>
          <CardContent>
            <Box sx={{ mb: 1 }}>
              <Typography variant="h6">
                {t("dashboard.top_drivers_title")}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                {t("dashboard.top_drivers_subtitle")}
              </Typography>
            </Box>
            {stats && !chartsLoading ? (
              stats.topDrivers.length === 0 ? (
                <Typography color="text.secondary" sx={{ py: 3 }}>
                  {t("dashboard.no_completed_trips")}
                </Typography>
              ) : (
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell sx={{ fontWeight: 700 }}>
                        {t("common.driver")}
                      </TableCell>
                      <TableCell sx={{ fontWeight: 700 }} align="right">
                        {t("common.trips")}
                      </TableCell>
                      <TableCell sx={{ fontWeight: 700 }} align="right">
                        {t("dashboard.revenue_series_label")}
                      </TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {stats.topDrivers.map((d) => (
                      <TableRow key={d.driverId}>
                        <TableCell sx={{ fontWeight: 600 }}>
                          {d.driverName}
                        </TableCell>
                        <TableCell align="right">
                          {formatNumber(d.trips)}
                        </TableCell>
                        <TableCell align="right">
                          {formatDzd(d.revenue)}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )
            ) : (
              <Skeleton variant="rounded" height={200} />
            )}
          </CardContent>
        </Card>

        <Card>
          <CardContent>
            <Box sx={{ mb: 1.5 }}>
              <Typography variant="h6">
                {t("dashboard.status_breakdown_title")}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                {t("dashboard.status_breakdown_subtitle")}
              </Typography>
            </Box>
            {stats ? (
              <Stack direction="row" flexWrap="wrap" gap={1.25}>
                {(Object.keys(stats.statusCounts) as TripStatus[]).filter(
                  (s) => s !== "headingToPickup"
                ).map(
                  (status) => (
                    <Box
                      key={status}
                      sx={{
                        flex: "1 1 140px",
                        minWidth: 140,
                        p: 1.5,
                        borderRadius: 2,
                        border: `1px solid ${brand.border}`,
                      }}
                    >
                      <Typography
                        variant="caption"
                        color="text.secondary"
                        sx={{ fontWeight: 700, letterSpacing: 0.3 }}
                      >
                        {getTripStatusLabel(t, status).toUpperCase()}
                      </Typography>
                      <Stack
                        direction="row"
                        alignItems="center"
                        justifyContent="space-between"
                        sx={{ mt: 0.5 }}
                      >
                        <Typography variant="h5" sx={{ fontWeight: 800 }}>
                          {formatNumber(stats.statusCounts[status])}
                        </Typography>
                        <TripStatusChip status={status} />
                      </Stack>
                    </Box>
                  )
                )}
              </Stack>
            ) : (
              <Skeleton variant="rounded" height={200} />
            )}
          </CardContent>
        </Card>
      </Box>

    </Stack>
  );
}
