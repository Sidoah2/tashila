"use client";

import { use, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import Box from "@mui/material/Box";
import Card from "@mui/material/Card";
import CardContent from "@mui/material/CardContent";
import Stack from "@mui/material/Stack";
import Typography from "@mui/material/Typography";
import Avatar from "@mui/material/Avatar";
import Button from "@mui/material/Button";
import Chip from "@mui/material/Chip";
import Divider from "@mui/material/Divider";
import Skeleton from "@mui/material/Skeleton";
import Dialog from "@mui/material/Dialog";
import DialogTitle from "@mui/material/DialogTitle";
import DialogContent from "@mui/material/DialogContent";
import DialogActions from "@mui/material/DialogActions";
import TextField from "@mui/material/TextField";
import Paper from "@mui/material/Paper";
import List from "@mui/material/List";
import ListItem from "@mui/material/ListItem";
import ListItemText from "@mui/material/ListItemText";
import Select from "@mui/material/Select";
import MenuItem from "@mui/material/MenuItem";
import FormControl from "@mui/material/FormControl";
import InputLabel from "@mui/material/InputLabel";
import ArrowBackRoundedIcon from "@mui/icons-material/ArrowBackRounded";
import CheckCircleRoundedIcon from "@mui/icons-material/CheckCircleRounded";
import CancelRoundedIcon from "@mui/icons-material/CancelRounded";
import DescriptionRoundedIcon from "@mui/icons-material/DescriptionRounded";
import StarRoundedIcon from "@mui/icons-material/StarRounded";
import LocalShippingRoundedIcon from "@mui/icons-material/LocalShippingRounded";
import { useDriversStore } from "@/lib/store/drivers";
import { useToast } from "@/components/ToastProvider";
import { DriverApprovalChip } from "@/components/StatusChip";
import {
  getDocumentStatusLabel,
  getDocumentTypeLabel,
  getTruckTypeLabel,
} from "@/lib/labels";
import type { DocumentStatus, DocumentType, DriverDocument } from "@/lib/types";
import { brand } from "@/theme/colors";
import { useTranslation } from "@/i18n/useTranslation";
import { useFormatDate, useFormatDzd, useFormatDateTime } from "@/i18n/format";
import FiberManualRecordRoundedIcon from "@mui/icons-material/FiberManualRecordRounded";
import LiveTruckMap from "@/components/LiveTruckMap";

export default function DriverDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const router = useRouter();
  const { t, locale } = useTranslation();
  const formatDate = useFormatDate();
  const formatDzd = useFormatDzd();
  const formatDateTime = useFormatDateTime();

  const drivers = useDriversStore((s) => s.drivers);
  const loaded = useDriversStore((s) => s.loaded);
  const load = useDriversStore((s) => s.load);
  const loadDriver = useDriversStore((s) => s.loadDriver);
  const setDocStatus = useDriversStore((s) => s.setDocStatus);
  const setApproval = useDriversStore((s) => s.setApproval);
  const applyPlatformPayment = useDriversStore((s) => s.applyPlatformPayment);
  const showToast = useToast();

  const [rejectingDoc, setRejectingDoc] = useState<DocumentType | null>(null);
  const [rejectingDriver, setRejectingDriver] = useState(false);
  const [rejectReason, setRejectReason] = useState("");
  const [previewDoc, setPreviewDoc] = useState<DriverDocument | null>(null);
  const [filterStatus, setFilterStatus] = useState("all");
  const [filterDateFrom, setFilterDateFrom] = useState("");
  const [filterDateTo, setFilterDateTo] = useState("");
  const [platformAmount, setPlatformAmount] = useState("");
  const [platformNote, setPlatformNote] = useState("");
  const [platformBusy, setPlatformBusy] = useState(false);

  useEffect(() => {
    load();
    loadDriver(id);
  }, [load, loadDriver, id]);

  const driver = useMemo(
    () => drivers.find((d) => d.id === id) ?? null,
    [drivers, id]
  );

  const filteredTrips = useMemo(() => {
    if (!driver || !driver.trips) return [];
    return driver.trips.filter((tItem) => {
      if (filterStatus !== "all" && tItem.status !== filterStatus) return false;
      if (filterDateFrom) {
        const fromDate = new Date(filterDateFrom);
        const tripDate = new Date(tItem.createdAt);
        if (tripDate < fromDate) return false;
      }
      if (filterDateTo) {
        const toDate = new Date(filterDateTo);
        toDate.setHours(23, 59, 59, 999);
        const tripDate = new Date(tItem.createdAt);
        if (tripDate > toDate) return false;
      }
      return true;
    });
  }, [driver, filterStatus, filterDateFrom, filterDateTo]);

  const completedCountInPeriod = useMemo(() => {
    return filteredTrips.filter((tItem) => tItem.status === "completed").length;
  }, [filteredTrips]);

  const cancelledCountInPeriod = useMemo(() => {
    return filteredTrips.filter((tItem) => tItem.status === "cancelled").length;
  }, [filteredTrips]);

  const ratingFormatter = useMemo(() => {
    const fmt = new Intl.NumberFormat(
      locale === "ar" ? "ar-DZ" : locale === "fr" ? "fr-DZ" : "en-DZ",
      { minimumFractionDigits: 1, maximumFractionDigits: 1 }
    );
    return (v: number) => fmt.format(v);
  }, [locale]);

  if (!loaded) {
    return <Skeleton variant="rounded" height={420} />;
  }

  if (!driver) {
    return (
      <Card>
        <CardContent>
          <Stack spacing={2}>
            <Typography variant="h6">
              {t("driver_detail.doc_not_found_title")}
            </Typography>
            <Typography color="text.secondary">
              {t("driver_detail.doc_not_found_body", { id })}
            </Typography>
            <Box>
              <Button
                component={Link}
                href="/drivers"
                startIcon={<ArrowBackRoundedIcon />}
              >
                {t("driver_detail.back_to_list")}
              </Button>
            </Box>
          </Stack>
        </CardContent>
      </Card>
    );
  }

  const allApproved = driver.documents.every((d) => d.status === "approved");

  const handleDocStatus = async (
    docType: DocumentType,
    status: DocumentStatus,
    reason?: string
  ) => {
    await setDocStatus(driver.id, docType, status, reason);
    const docName = getDocumentTypeLabel(t, docType);
    showToast(
      status === "approved"
        ? t("toast.doc_approved", { doc: docName })
        : t("toast.doc_rejected", { doc: docName }),
      status === "approved" ? "success" : "warning"
    );
  };

  const handleMasterApprove = async () => {
    await setApproval(driver.id, "approved");
    showToast(t("toast.driver_fully_approved", { name: driver.name }));
  };

  const handleMasterReject = () => {
    setRejectReason("");
    setRejectingDriver(true);
  };

  const handleMasterRejectSubmit = async () => {
    if (!rejectReason.trim()) {
      showToast("Please enter a rejection reason.", "error");
      return;
    }
    try {
      await setApproval(driver.id, "rejected", rejectReason);
      showToast(t("toast.driver_rejected", { name: driver.name }), "warning");
      setRejectingDriver(false);
      setRejectReason("");
      router.push("/drivers");
    } catch (err: any) {
      showToast(err.message || "Failed to reject driver.", "error");
    }
  };

  return (
    <Stack spacing={3}>
      <Stack direction="row" alignItems="center" spacing={1}>
        <Button
          component={Link}
          href="/drivers"
          startIcon={<ArrowBackRoundedIcon />}
          variant="outlined"
          size="small"
        >
          {t("common.back")}
        </Button>
        <Box sx={{ flex: 1 }} />
        <DriverApprovalChip status={driver.approvalStatus} />
      </Stack>

      <Card>
        <CardContent>
          <Stack
            direction={{ xs: "column", sm: "row" }}
            spacing={2}
            alignItems={{ sm: "center" }}
          >
            <Avatar
              src={driver.avatarUrl ?? undefined}
              sx={{
                width: 72,
                height: 72,
                bgcolor: `${brand.orange}1F`,
                color: brand.orange,
                fontSize: 28,
                fontWeight: 800,
              }}
            >
              {(driver.name || "")
                .split(" ")
                .filter(Boolean)
                .map((s) => s[0])
                .slice(0, 2)
                .join("")}
            </Avatar>
            <Box sx={{ flex: 1 }}>
              <Typography variant="h5" sx={{ fontWeight: 800 }}>
                {driver.name}
              </Typography>
              <Typography color="text.secondary">{driver.phone}</Typography>
              <Stack direction="row" spacing={1} sx={{ mt: 1 }} flexWrap="wrap">
                <Chip
                  size="small"
                  variant="outlined"
                  icon={<LocalShippingRoundedIcon />}
                  label={getTruckTypeLabel(t, driver.truckType)}
                />
                <Chip
                  size="small"
                  variant="outlined"
                  label={t("driver_detail.vehicle_header", {
                    model: driver.vehicleModel,
                    color: driver.vehicleColor,
                    plate: driver.vehiclePlate,
                  })}
                />
                {driver.rating > 0 && (
                  <Chip
                    size="small"
                    variant="outlined"
                    icon={
                      <StarRoundedIcon sx={{ color: brand.warning + " !important" }} />
                    }
                    label={t("driver_detail.trips_count_with_rating", {
                      rating: ratingFormatter(driver.rating),
                      count: driver.completedTrips,
                    })}
                  />
                )}
                <Chip
                  size="small"
                  variant="outlined"
                  label={t("driver_detail.joined_on", {
                    date: `\u2068${formatDate(driver.createdAt)}\u2069`,
                  })}
                />
              </Stack>
            </Box>
          </Stack>
        </CardContent>
      </Card>

      {/* Live Map / Broadcast Card */}
      <Card>
        <CardContent>
          <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
            <FiberManualRecordRoundedIcon
              sx={{
                fontSize: 14,
                color:
                  driver.availability === "online"
                    ? brand.success
                    : brand.textSecondary,
              }}
            />
            <Typography variant="h6" sx={{ fontWeight: 800 }}>
              {t("common.live")} · {driver.availability === "online" ? t("common.online") : t("common.offline")}
            </Typography>
          </Stack>
          <Box sx={{ height: 300, width: "100%", borderRadius: 2, overflow: "hidden" }}>
            <LiveTruckMap
              drivers={[driver]}
              center={driver.lastLocation}
              selectedDriverId={driver.id}
              onSelectDriver={() => {}}
            />
          </Box>
        </CardContent>
      </Card>

      <Card>
        <CardContent>
          <Typography variant="h6" sx={{ mb: 1 }}>
            {t("driver_detail.platform_dues_title")}
          </Typography>
          {(driver.creditDzd ?? 0) > 0 ? (
            <Typography variant="h4" sx={{ fontWeight: 800, mb: 2, color: "success.main" }}>
              +{formatDzd(driver.creditDzd ?? 0)} ({locale === "ar" ? "رصيد دائن" : "Credit"})
            </Typography>
          ) : (
            <Typography variant="h4" sx={{ fontWeight: 800, mb: 2 }}>
              {formatDzd(driver.platformDueDzd)}
            </Typography>
          )}
          <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 1 }}>
            {t("driver_detail.platform_payments_title")}
          </Typography>
          {driver.platformPayments.length === 0 ? (
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              —
            </Typography>
          ) : (
            <List dense sx={{ mb: 2 }}>
              {driver.platformPayments.map((p) => (
                <ListItem key={p.id} disableGutters>
                  <ListItemText
                    primary={`${formatDzd(p.amountDzd)} · ${p.note}`}
                    secondary={formatDateTime(p.date)}
                  />
                </ListItem>
              ))}
            </List>
          )}
          <Stack direction={{ xs: "column", sm: "row" }} spacing={1} alignItems={{ sm: "flex-end" }}>
            <TextField
              label={t("driver_detail.platform_amount_label")}
              type="number"
              value={platformAmount}
              onChange={(e) => setPlatformAmount(e.target.value)}
              sx={{ flex: 1 }}
            />
            <TextField
              label={t("driver_detail.platform_payment_note")}
              placeholder={t("driver_detail.platform_note_placeholder")}
              value={platformNote}
              onChange={(e) => setPlatformNote(e.target.value)}
              sx={{ flex: 2 }}
            />
            <Button
              variant="contained"
              disabled={
                platformBusy ||
                !platformAmount.trim() ||
                Number(platformAmount) <= 0
              }
              onClick={async () => {
                const n = Number(platformAmount);
                if (!Number.isFinite(n) || n <= 0) return;
                setPlatformBusy(true);
                try {
                  await applyPlatformPayment(driver.id, n, platformNote);
                  showToast(
                    t("toast.platform_payment_recorded", {
                      amount: formatDzd(n),
                    }),
                    "success"
                  );
                  setPlatformAmount("");
                  setPlatformNote("");
                } catch (err) {
                  showToast(err instanceof Error ? err.message : t("toast.action_failed"), "error");
                } finally {
                  setPlatformBusy(false);
                }
              }}
            >
              {t("driver_detail.platform_record_payment")}
            </Button>
          </Stack>
        </CardContent>
      </Card>

      {/* Driver Trips Card */}
      <Card>
        <CardContent>
          <Typography variant="h6" sx={{ fontWeight: 800, mb: 2 }}>
            {t("driver_detail.trips_title")}
          </Typography>

          {/* Filters Row */}
          <Stack
            direction={{ xs: "column", sm: "row" }}
            spacing={2}
            sx={{ mb: 3 }}
          >
            <FormControl size="small" sx={{ minWidth: 160 }}>
              <InputLabel id="filter-status-label">
                {t("driver_detail.filter_status")}
              </InputLabel>
              <Select
                labelId="filter-status-label"
                value={filterStatus}
                label={t("driver_detail.filter_status")}
                onChange={(e) => setFilterStatus(e.target.value)}
              >
                <MenuItem value="all">{t("users.filter_all")}</MenuItem>
                <MenuItem value="requested">{t("trip_status.requested")}</MenuItem>
                <MenuItem value="accepted">{t("trip_status.accepted")}</MenuItem>
                <MenuItem value="headingToPickup">{t("trip_status.headingToPickup")}</MenuItem>
                <MenuItem value="inProgress">{t("trip_status.inProgress")}</MenuItem>
                <MenuItem value="awaitingCash">{t("trip_status.awaitingCash")}</MenuItem>
                <MenuItem value="completed">{t("trip_status.completed")}</MenuItem>
                <MenuItem value="cancelled">{t("trip_status.cancelled")}</MenuItem>
              </Select>
            </FormControl>

            <TextField
              type="date"
              size="small"
              label={t("driver_detail.filter_date_from")}
              slotProps={{ inputLabel: { shrink: true } }}
              value={filterDateFrom}
              onChange={(e) => setFilterDateFrom(e.target.value)}
              sx={{ flex: 1 }}
            />

            <TextField
              type="date"
              size="small"
              label={t("driver_detail.filter_date_to")}
              slotProps={{ inputLabel: { shrink: true } }}
              value={filterDateTo}
              onChange={(e) => setFilterDateTo(e.target.value)}
              sx={{ flex: 1 }}
            />
          </Stack>

          {/* Completed and Cancelled counters for selected period */}
          <Stack direction="row" spacing={2} sx={{ mb: 2 }}>
            <Box
              sx={{
                p: 1.5,
                borderRadius: 2,
                bgcolor: `${brand.success}0F`,
                border: `1px solid ${brand.success}33`,
                flex: 1,
                textAlign: "center",
              }}
            >
              <Typography variant="body2" sx={{ fontWeight: 700, color: brand.success }}>
                {t("driver_detail.completed_count_period")}: {completedCountInPeriod}
              </Typography>
            </Box>
            <Box
              sx={{
                p: 1.5,
                borderRadius: 2,
                bgcolor: `${brand.danger || "#d32f2f"}0F`,
                border: `1px solid ${brand.danger || "#d32f2f"}33`,
                flex: 1,
                textAlign: "center",
              }}
            >
              <Typography variant="body2" sx={{ fontWeight: 700, color: brand.danger || "#d32f2f" }}>
                {t("driver_detail.cancelled_count_period")}: {cancelledCountInPeriod}
              </Typography>
            </Box>
          </Stack>

          {/* Trips List */}
          {filteredTrips.length === 0 ? (
            <Typography variant="body2" color="text.secondary">
              {t("driver_detail.trips_empty") || "No trips found."}
            </Typography>
          ) : (
            <List dense sx={{ maxHeight: 400, overflow: "auto" }}>
              {filteredTrips.map((tItem) => (
                <ListItem
                  key={tItem.id}
                  disableGutters
                  sx={{
                    borderBottom: `1px solid ${brand.border}`,
                    py: 1.5,
                    display: "flex",
                    flexDirection: { xs: "column", sm: "row" },
                    alignItems: { xs: "flex-start", sm: "center" },
                    justifyContent: "space-between",
                    gap: 1,
                  }}
                >
                  <Box>
                    <Typography variant="body2" sx={{ fontWeight: 700 }}>
                      ID: <bdi>{tItem.id.slice(-6).toUpperCase()}</bdi> · <bdi>{formatDzd(tItem.fare)}</bdi>
                    </Typography>
                    <Typography variant="caption" color="text.secondary" display="block">
                      <bdi>{formatDateTime(tItem.createdAt)}</bdi> · <bdi>{tItem.clientName}</bdi>
                    </Typography>
                    <Typography variant="caption" color="text.secondary" display="block">
                      {tItem.pickup} ➔ {tItem.dropOff}
                    </Typography>
                  </Box>
                  <Stack direction="row" spacing={1} alignItems="center">
                    <Chip
                      size="small"
                      label={
                        tItem.status === "requested" ? t("trip_status.requested") :
                        tItem.status === "accepted" ? t("trip_status.accepted") :
                        tItem.status === "headingToPickup" ? t("trip_status.headingToPickup") :
                        tItem.status === "inProgress" ? t("trip_status.inProgress") :
                        tItem.status === "awaitingCash" ? t("trip_status.awaitingCash") :
                        tItem.status === "completed" ? t("trip_status.completed") :
                        t("trip_status.cancelled")
                      }
                      color={
                        tItem.status === "completed" ? "success" :
                        tItem.status === "cancelled" ? "error" :
                        "warning"
                      }
                      variant="outlined"
                    />
                  </Stack>
                </ListItem>
              ))}
            </List>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardContent>
          <Typography variant="h6" sx={{ mb: 1 }}>
            {t("driver_detail.customer_reviews_title")}
          </Typography>
          {driver.customerReviews.length === 0 ? (
            <Typography variant="body2" color="text.secondary">
              {t("driver_detail.customer_reviews_empty")}
            </Typography>
          ) : (
            <Stack spacing={1.25}>
              {driver.customerReviews.map((r) => (
                <Paper key={r.id} variant="outlined" sx={{ p: 1.5 }}>
                  <Stack direction="row" justifyContent="space-between">
                    <Typography sx={{ fontWeight: 700 }}>{r.customerName}</Typography>
                    <Typography variant="body2">{r.rating}★</Typography>
                  </Stack>
                  <Typography variant="body2" sx={{ mt: 0.5 }}>
                    {r.comment}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    <bdi>{r.tripId}</bdi> · <bdi>{formatDate(r.date)}</bdi>
                  </Typography>
                </Paper>
              ))}
            </Stack>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardContent>
          <Box sx={{ mb: 2 }}>
            <Typography variant="h6">
              {t("driver_detail.documents_title")}
            </Typography>
            <Typography variant="body2" color="text.secondary">
              {t("driver_detail.documents_subtitle")}
            </Typography>
          </Box>
          <Box
            sx={{
              display: "grid",
              gridTemplateColumns: { xs: "1fr", md: "repeat(3, 1fr)" },
              gap: 2,
            }}
          >
            {driver.documents.map((doc) => (
              <Card
                key={doc.type}
                variant="outlined"
                sx={{
                  borderColor:
                    doc.status === "approved"
                      ? brand.success
                      : doc.status === "rejected"
                      ? brand.danger
                      : brand.border,
                }}
              >
                <CardContent>
                  <Stack
                    direction="row"
                    alignItems="center"
                    spacing={1}
                    sx={{ mb: 1.5 }}
                  >
                    <Avatar
                      sx={{
                        width: 36,
                        height: 36,
                        bgcolor: `${brand.orange}1F`,
                        color: brand.orange,
                      }}
                    >
                      <DescriptionRoundedIcon fontSize="small" />
                    </Avatar>
                    <Typography sx={{ fontWeight: 700 }}>
                      {getDocumentTypeLabel(t, doc.type)}
                    </Typography>
                  </Stack>
                  <Box
                    sx={{
                      height: 120,
                      borderRadius: 2,
                      backgroundColor: brand.bg,
                      border: `1px dashed ${brand.border}`,
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      mb: 1.5,
                      cursor: doc.fileName ? "pointer" : "default",
                      overflow: "hidden",
                    }}
                    onClick={() => {
                      if (doc.fileName) setPreviewDoc(doc);
                    }}
                  >
                    {doc.fileName ? (
                      <img
                        src={doc.fileName}
                        alt={getDocumentTypeLabel(t, doc.type)}
                        style={{ width: "100%", height: "100%", objectFit: "cover" }}
                      />
                    ) : (
                      <Typography variant="caption" color="text.secondary">
                        {t("driver_detail.doc_not_uploaded")}
                      </Typography>
                    )}
                  </Box>
                  <Stack
                    direction="row"
                    justifyContent="space-between"
                    alignItems="center"
                    sx={{ mb: 1 }}
                  >
                    <Chip
                      size="small"
                      label={getDocumentStatusLabel(t, doc.status)}
                      color={
                        doc.status === "approved"
                          ? "success"
                          : doc.status === "rejected"
                          ? "error"
                          : "warning"
                      }
                      variant="outlined"
                    />
                  </Stack>
                  {doc.rejectionReason && (
                    <Typography
                      variant="caption"
                      color="error"
                      sx={{ display: "block", mb: 1 }}
                    >
                      {t("driver_detail.doc_reason_label", {
                        reason: doc.rejectionReason,
                      })}
                    </Typography>
                  )}
                  <Stack direction="row" spacing={1}>
                    <Button
                      fullWidth
                      size="small"
                      color="success"
                      variant={doc.status === "approved" ? "contained" : "outlined"}
                      startIcon={<CheckCircleRoundedIcon />}
                      disabled={!doc.fileName}
                      onClick={() => handleDocStatus(doc.type, "approved")}
                    >
                      {t("common.approve")}
                    </Button>
                    <Button
                      fullWidth
                      size="small"
                      color="error"
                      variant={doc.status === "rejected" ? "contained" : "outlined"}
                      startIcon={<CancelRoundedIcon />}
                      disabled={!doc.fileName}
                      onClick={() => {
                        setRejectingDoc(doc.type);
                        setRejectReason(doc.rejectionReason ?? "");
                      }}
                    >
                      {t("common.reject")}
                    </Button>
                  </Stack>
                </CardContent>
              </Card>
            ))}
          </Box>
        </CardContent>
        <Divider />
        <Box sx={{ p: 2 }}>
          <Stack
            direction={{ xs: "column", sm: "row" }}
            spacing={1.5}
            justifyContent="flex-end"
          >
            <Button
              variant="contained"
              color="error"
              size="large"
              startIcon={<CancelRoundedIcon />}
              onClick={handleMasterReject}
            >
              {t("driver_detail.reject_driver")}
            </Button>
            <Button
              variant="contained"
              size="large"
              color="success"
              startIcon={<CheckCircleRoundedIcon />}
              disabled={driver.approvalStatus === "approved" || !allApproved}
              onClick={handleMasterApprove}
            >
              {driver.approvalStatus === "approved"
                ? t("driver_detail.driver_approved")
                : t("driver_detail.approve_driver")}
            </Button>
          </Stack>
          {!allApproved && (
            <Typography
              variant="caption"
              color="text.secondary"
              sx={{ display: "block", mt: 1, textAlign: "right" }}
            >
              {t("driver_detail.all_docs_required_hint")}
            </Typography>
          )}
        </Box>
      </Card>

      <Dialog
        open={Boolean(rejectingDoc)}
        onClose={() => setRejectingDoc(null)}
        fullWidth
        maxWidth="xs"
      >
        <DialogTitle>{t("driver_detail.reject_dialog_title")}</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            {t("driver_detail.reject_dialog_helper")}
          </Typography>
          <TextField
            autoFocus
            multiline
            minRows={3}
            placeholder={t("driver_detail.reject_dialog_placeholder")}
            value={rejectReason}
            onChange={(e) => setRejectReason(e.target.value)}
          />
        </DialogContent>
        <DialogActions>
          <Button variant="outlined" onClick={() => setRejectingDoc(null)}>
            {t("common.cancel")}
          </Button>
          <Button
            variant="contained"
            color="error"
            onClick={async () => {
              if (!rejectingDoc) return;
              await handleDocStatus(rejectingDoc, "rejected", rejectReason);
              setRejectingDoc(null);
              setRejectReason("");
            }}
          >
            {t("common.reject")}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog
        open={Boolean(previewDoc)}
        onClose={() => setPreviewDoc(null)}
        fullWidth
        maxWidth="sm"
      >
        <DialogTitle>
          {previewDoc ? getDocumentTypeLabel(t, previewDoc.type) : ""}
        </DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            {t("driver_detail.doc_preview_body")}
          </Typography>
          {previewDoc?.fileName ? (
            <Box sx={{ display: "flex", justifyContent: "center", mt: 1 }}>
              <img
                src={previewDoc.fileName}
                alt={getDocumentTypeLabel(t, previewDoc.type)}
                style={{ maxWidth: "100%", maxHeight: 350, objectFit: "contain", borderRadius: 8 }}
              />
            </Box>
          ) : (
            <Box
              sx={{
                height: 220,
                borderRadius: 2,
                bgcolor: brand.bg,
                border: `1px solid ${brand.border}`,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              <Typography color="text.secondary">
                {t("driver_detail.doc_not_uploaded")}
              </Typography>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setPreviewDoc(null)}>{t("common.cancel")}</Button>
        </DialogActions>
      </Dialog>

      {/* Driver Account Rejection Dialog */}
      <Dialog
        open={rejectingDriver}
        onClose={() => {
          setRejectingDriver(false);
          setRejectReason("");
        }}
        fullWidth
        maxWidth="xs"
      >
        <DialogTitle>{t("driver_detail.reject_driver_dialog_title")}</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            {t("driver_detail.reject_driver_dialog_helper") || "Please specify the reason for rejecting this driver application:"}
          </Typography>
          <TextField
            autoFocus
            multiline
            minRows={3}
            fullWidth
            placeholder={t("driver_detail.reject_driver_dialog_placeholder") || "e.g., Expired documents or incomplete profile details."}
            value={rejectReason}
            onChange={(e) => setRejectReason(e.target.value)}
          />
        </DialogContent>
        <DialogActions>
          <Button
            variant="outlined"
            onClick={() => {
              setRejectingDriver(false);
              setRejectReason("");
            }}
          >
            {t("common.cancel")}
          </Button>
          <Button variant="contained" color="error" onClick={handleMasterRejectSubmit}>
            {t("common.reject")}
          </Button>
        </DialogActions>
      </Dialog>
    </Stack>
  );
}
