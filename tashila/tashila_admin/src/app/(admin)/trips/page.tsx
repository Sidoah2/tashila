"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import Box from "@mui/material/Box";
import Card from "@mui/material/Card";
import Stack from "@mui/material/Stack";
import Typography from "@mui/material/Typography";
import Button from "@mui/material/Button";
import Drawer from "@mui/material/Drawer";
import Divider from "@mui/material/Divider";
import IconButton from "@mui/material/IconButton";
import TextField from "@mui/material/TextField";
import MenuItem from "@mui/material/MenuItem";
import InputAdornment from "@mui/material/InputAdornment";
import Chip from "@mui/material/Chip";
import SearchRoundedIcon from "@mui/icons-material/SearchRounded";
import SendRoundedIcon from "@mui/icons-material/SendRounded";
import CloseRoundedIcon from "@mui/icons-material/CloseRounded";
import Alert from "@mui/material/Alert";
import {
  DataGrid,
  type GridColDef,
  type GridRenderCellParams,
} from "@mui/x-data-grid";
import { confirmTripCash, getTrip, type TripDetail } from "@/lib/api/trips";
import { useTripsStore } from "@/lib/store/trips";
import { TripStatusChip } from "@/components/StatusChip";
import TripStatusTimeline from "@/components/TripStatusTimeline";
import MapPreview from "@/components/MapPreview";
import {
  TRIP_STATUSES,
  type Trip,
  type TripStatus,
  type TruckType,
} from "@/lib/types";
import { getTripStatusLabel, getTruckTypeLabel } from "@/lib/labels";
import { brand } from "@/theme/colors";
import { useTranslation } from "@/i18n/useTranslation";
import {
  useFormatDateTime,
  useFormatDzd,
  useFormatNumber,
} from "@/i18n/format";
import { useDataGridLocaleText } from "@/i18n/dataGridLocale";

export default function TripsPage() {
  const trips = useTripsStore((s) => s.trips);
  const loading = useTripsStore((s) => s.loading);
  const load = useTripsStore((s) => s.load);
  const { t, locale } = useTranslation();
  const formatDateTime = useFormatDateTime();
  const formatDzd = useFormatDzd();
  const formatNumber = useFormatNumber();
  const dataGridLocale = useDataGridLocaleText();

  const [search, setSearch] = useState("");
  const [status, setStatus] = useState<TripStatus | "all">("all");
  const [truck, setTruck] = useState<TruckType | "all">("all");
  const [from, setFrom] = useState<string>("");
  const [to, setTo] = useState<string>("");
  const [selected, setSelected] = useState<Trip | null>(null);
  const [selectedDetail, setSelectedDetail] = useState<TripDetail | null>(null);
  const [cashConfirmBusy, setCashConfirmBusy] = useState(false);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (!selected) {
      setSelectedDetail(null);
      return;
    }
    let cancelled = false;
    getTrip(selected.id).then((detail) => {
      if (!cancelled) setSelectedDetail(detail);
    });
    return () => {
      cancelled = true;
    };
  }, [selected]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    const fromTs = from ? new Date(from).getTime() : null;
    const toTs = to ? new Date(to).getTime() + 24 * 60 * 60 * 1000 - 1 : null;
    return trips.filter((tr) => {
      if (status !== "all" && tr.status !== status) return false;
      if (truck !== "all" && tr.truckType !== truck) return false;
      const ts = new Date(tr.createdAt).getTime();
      if (fromTs && ts < fromTs) return false;
      if (toTs && ts > toTs) return false;
      if (!q) return true;
      return (
        tr.id.toLowerCase().includes(q) ||
        tr.clientName.toLowerCase().includes(q) ||
        (tr.driverName ?? "").toLowerCase().includes(q) ||
        tr.pickup.toLowerCase().includes(q) ||
        tr.dropOff.toLowerCase().includes(q)
      );
    });
  }, [trips, search, status, truck, from, to]);

  const oneDecimal = useMemo(() => {
    const fmt = new Intl.NumberFormat(
      locale === "ar" ? "ar-DZ" : locale === "fr" ? "fr-DZ" : "en-DZ",
      { minimumFractionDigits: 1, maximumFractionDigits: 1 }
    );
    return (v: number) => fmt.format(v);
  }, [locale]);

  const columns: GridColDef<Trip>[] = [
    { field: "id", headerName: t("trips.column_id"), width: 120 },
    {
      field: "clientName",
      headerName: t("trips.column_client"),
      width: 160,
      renderCell: (p: GridRenderCellParams<Trip>) => (
        <Typography sx={{ fontWeight: 600 }}>{p.row.clientName}</Typography>
      ),
    },
    {
      field: "driverName",
      headerName: t("trips.column_driver"),
      width: 160,
      valueFormatter: (value: string | null) => value ?? "—",
    },
    {
      field: "route",
      headerName: t("trips.column_route"),
      flex: 1,
      minWidth: 260,
      valueGetter: (_v, row) => `${row.pickup} → ${row.dropOff}`,
      renderCell: (p: GridRenderCellParams<Trip>) => (
        <Stack sx={{ py: 0.75 }}>
          <Typography variant="body2" sx={{ fontWeight: 600 }}>
            {p.row.pickup}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            → {p.row.dropOff}
          </Typography>
        </Stack>
      ),
    },
    {
      field: "truckType",
      headerName: t("trips.column_truck"),
      width: 100,
      renderCell: (p: GridRenderCellParams<Trip>) => (
        <Chip
          size="small"
          variant="outlined"
          label={getTruckTypeLabel(t, p.row.truckType)}
        />
      ),
    },
    {
      field: "distanceKm",
      headerName: t("trips.column_km"),
      width: 80,
      type: "number",
      valueFormatter: (value: number) => oneDecimal(value),
    },
    {
      field: "fare",
      headerName: t("trips.column_fare"),
      width: 130,
      type: "number",
      valueFormatter: (value: number) => formatDzd(value),
    },
    {
      field: "status",
      headerName: t("trips.column_status"),
      width: 150,
      renderCell: (p: GridRenderCellParams<Trip>) => (
        <TripStatusChip status={p.row.status} />
      ),
    },
    {
      field: "createdAt",
      headerName: t("trips.column_created"),
      width: 180,
      valueFormatter: (value: string) => formatDateTime(value),
    },
  ];

  return (
    <>
      <Box sx={{ mb: 3 }}>
        <Alert severity="info" sx={{ borderRadius: 2, border: `1px solid ${brand.border}` }}>
          <Typography variant="subtitle2" sx={{ fontWeight: 800, mb: 0.5 }}>
            {t("trips.guide_title")}
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ whiteSpace: "pre-line" }}>
            {t("trips.guide_body")}
          </Typography>
        </Alert>
      </Box>

      <Card>
        <Box sx={{ p: 2, display: "flex", flexWrap: "wrap", gap: 1.5 }}>
          <TextField
            placeholder={t("trips.search_placeholder")}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            sx={{ flex: 1, minWidth: 260 }}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <SearchRoundedIcon fontSize="small" />
                </InputAdornment>
              ),
            }}
          />
          <TextField
            select
            label={t("trips.filter_status")}
            value={status}
            onChange={(e) => setStatus(e.target.value as TripStatus | "all")}
            sx={{ minWidth: 150 }}
          >
            <MenuItem value="all">{t("common.all")}</MenuItem>
            {TRIP_STATUSES.map((s) => (
              <MenuItem key={s} value={s}>
                {getTripStatusLabel(t, s)}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            select
            label={t("trips.filter_truck")}
            value={truck}
            onChange={(e) => setTruck(e.target.value as TruckType | "all")}
            sx={{ minWidth: 130 }}
          >
            <MenuItem value="all">{t("common.all")}</MenuItem>
            <MenuItem value="single_cabin">{t("truck.single_cabin")}</MenuItem>
            <MenuItem value="double_cabin">{t("truck.double_cabin")}</MenuItem>
          </TextField>
          <TextField
            type="date"
            label={t("common.from")}
            value={from}
            onChange={(e) => setFrom(e.target.value)}
            InputLabelProps={{ shrink: true }}
            sx={{ minWidth: 150 }}
          />
          <TextField
            type="date"
            label={t("common.to")}
            value={to}
            onChange={(e) => setTo(e.target.value)}
            InputLabelProps={{ shrink: true }}
            sx={{ minWidth: 150 }}
          />
          <Button
            component={Link}
            href="/trips/dispatch"
            startIcon={<SendRoundedIcon />}
          >
            {t("trips.dispatch_button")}
          </Button>
        </Box>
        <Divider />
        <Box sx={{ width: "100%" }}>
          <DataGrid
            rows={filtered}
            columns={columns}
            loading={loading}
            autoHeight
            disableRowSelectionOnClick
            localeText={dataGridLocale}
            onRowClick={(p) => setSelected(p.row as Trip)}
            initialState={{
              pagination: { paginationModel: { pageSize: 10 } },
            }}
            pageSizeOptions={[10, 25, 50]}
            sx={{
              border: "none",
              cursor: "pointer",
              "& .MuiDataGrid-columnHeaders": { backgroundColor: brand.bg },
              "& .MuiDataGrid-cell:focus": { outline: "none" },
              "& .MuiDataGrid-cell:focus-within": { outline: "none" },
            }}
          />
        </Box>
      </Card>

      <Drawer
        anchor="right"
        open={Boolean(selected)}
        onClose={() => setSelected(null)}
        PaperProps={{ sx: { width: { xs: "100%", sm: 500 } } }}
      >
        {selected && (
          <Box sx={{ p: 3 }}>
            <Stack
              direction="row"
              justifyContent="space-between"
              alignItems="center"
              sx={{ mb: 1 }}
            >
              <Typography variant="h6" sx={{ fontWeight: 800 }}>
                {t("trips.drawer_title", { id: selected.id })}
              </Typography>
              <IconButton onClick={() => setSelected(null)}>
                <CloseRoundedIcon />
              </IconButton>
            </Stack>
            <Stack direction="row" spacing={1} sx={{ mb: 2 }} flexWrap="wrap">
              <TripStatusChip status={selected.status} />
              <Chip
                size="small"
                variant="outlined"
                label={getTruckTypeLabel(t, selected.truckType)}
              />
              {selected.dispatchedByAdmin && (
                <Chip
                  size="small"
                  color="primary"
                  variant="outlined"
                  label={t("trips.admin_dispatch_chip")}
                />
              )}
              {selectedDetail?.dispatchOffer && (
                <Chip
                  size="small"
                  color="warning"
                  variant="outlined"
                  label={t("trips.dispatch_offer_chip", {
                    driver:
                      selectedDetail.dispatchOffer.driverName ??
                      selectedDetail.dispatchOffer.driverId,
                  })}
                />
              )}
            </Stack>

            {selectedDetail?.dispatchOffer && (
              <Typography
                variant="body2"
                color="text.secondary"
                sx={{ mb: 2 }}
              >
                {t("trips.dispatch_offer_expires", {
                  time: formatDateTime(selectedDetail.dispatchOffer.expiresAt),
                })}
              </Typography>
            )}

            <MapPreview
              pickup={{
                label: selected.pickup,
                lat: selected.pickupLat,
                lng: selected.pickupLng,
              }}
              dropOff={{
                label: selected.dropOff,
                lat: selected.dropOffLat,
                lng: selected.dropOffLng,
              }}
            />

            <Box sx={{ mt: 2 }}>
              <DetailRow
                label={t("common.client")}
                value={selected.clientName}
              />
              {selected.clientPhone && (
                <DetailRow
                  label={t("common.phone")}
                  value={selected.clientPhone}
                />
              )}
              <DetailRow
                label={t("common.driver")}
                value={selected.driverName ?? t("trips.row_unassigned")}
              />
              <DetailRow
                label={t("trips.row_distance")}
                value={`${oneDecimal(selected.distanceKm)} ${t("common.distance_km")}`}
              />
              <DetailRow
                label={t("common.fare")}
                value={formatDzd(selected.fare)}
              />
              {selected.finalFare != null && selected.finalFare !== selected.fare && (
                <DetailRow
                  label={t("trips.final_fare")}
                  value={formatDzd(selected.finalFare)}
                />
              )}
              <DetailRow
                label={t("common.created")}
                value={formatDateTime(selected.createdAt)}
              />
              {selected.completedAt && (
                <DetailRow
                  label={t("trips.row_completed")}
                  value={formatDateTime(selected.completedAt)}
                />
              )}
              <DetailRow
                label={t("common.payment")}
                value={t("trips.row_payment_value", {
                  state: selected.cashConfirmed
                    ? t("payment_state.confirmed")
                    : t("payment_state.pending"),
                })}
              />
              {selected.rating != null && (
                <DetailRow
                  label={t("common.rating")}
                  value={t("trips.row_rating", {
                    rating: formatNumber(selected.rating),
                  })}
                />
              )}
            </Box>

            <Divider sx={{ my: 2 }} />
            <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1 }}>
              {t("trips.status_timeline_title")}
            </Typography>
            <TripStatusTimeline status={selected.status} />

            {selected.status === "awaitingCash" && (
              <Button
                fullWidth
                variant="contained"
                color="warning"
                sx={{ mt: 2 }}
                disabled={cashConfirmBusy}
                onClick={async () => {
                  setCashConfirmBusy(true);
                  try {
                    const updated = await confirmTripCash(selected.id);
                    setSelected(updated);
                    await load();
                  } finally {
                    setCashConfirmBusy(false);
                  }
                }}
              >
                {t("trips.resolve_dispute_confirm_cash")}
              </Button>
            )}
          </Box>
        )}
      </Drawer>
    </>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <Stack
      direction="row"
      justifyContent="space-between"
      alignItems="center"
      sx={{ py: 0.75 }}
    >
      <Typography color="text.secondary">{label}</Typography>
      <Typography sx={{ fontWeight: 600, textAlign: "end" }}>
        {value}
      </Typography>
    </Stack>
  );
}
