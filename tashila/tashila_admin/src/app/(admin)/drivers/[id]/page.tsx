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
  const setDocStatus = useDriversStore((s) => s.setDocStatus);
  const setApproval = useDriversStore((s) => s.setApproval);
  const applyPlatformPayment = useDriversStore((s) => s.applyPlatformPayment);
  const showToast = useToast();

  const [rejectingDoc, setRejectingDoc] = useState<DocumentType | null>(null);
  const [rejectReason, setRejectReason] = useState("");
  const [previewDoc, setPreviewDoc] = useState<DriverDocument | null>(null);
  const [platformAmount, setPlatformAmount] = useState("");
  const [platformNote, setPlatformNote] = useState("");
  const [platformBusy, setPlatformBusy] = useState(false);

  useEffect(() => {
    load();
  }, [load]);

  const driver = useMemo(
    () => drivers.find((d) => d.id === id) ?? null,
    [drivers, id]
  );

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

  const handleMasterReject = async () => {
    await setApproval(driver.id, "rejected");
    showToast(t("toast.driver_rejected", { name: driver.name }), "warning");
    router.push("/drivers");
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
                    date: formatDate(driver.createdAt),
                  })}
                />
              </Stack>
            </Box>
          </Stack>
        </CardContent>
      </Card>

      <Card>
        <CardContent>
          <Typography variant="h6" sx={{ mb: 1 }}>
            {t("driver_detail.platform_dues_title")}
          </Typography>
          <Typography variant="h4" sx={{ fontWeight: 800, mb: 2 }}>
            {formatDzd(driver.platformDueDzd)}
          </Typography>
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
                Number(platformAmount) <= 0 ||
                driver.platformDueDzd <= 0
              }
              onClick={async () => {
                const n = Number(platformAmount);
                if (!Number.isFinite(n) || n <= 0) return;
                setPlatformBusy(true);
                try {
                  const applied = Math.min(n, driver.platformDueDzd);
                  await applyPlatformPayment(driver.id, n, platformNote);
                  showToast(
                    t("toast.platform_payment_recorded", {
                      amount: formatDzd(applied),
                    }),
                    "success"
                  );
                  setPlatformAmount("");
                  setPlatformNote("");
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
                    {r.tripId} · {formatDate(r.date)}
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
                    }}
                    onClick={() => {
                      if (doc.fileName) setPreviewDoc(doc);
                    }}
                  >
                    <Typography variant="caption" color="text.secondary">
                      {doc.fileName ?? t("driver_detail.doc_not_uploaded")}
                    </Typography>
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
                      disabled={doc.status === "pending"}
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
                      disabled={doc.status === "pending"}
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
              variant="outlined"
              color="error"
              size="large"
              startIcon={<CancelRoundedIcon />}
              onClick={handleMasterReject}
            >
              {t("driver_detail.reject_driver")}
            </Button>
            <Button
              size="large"
              color="success"
              startIcon={<CheckCircleRoundedIcon />}
              disabled={driver.approvalStatus === "approved"}
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
          <Button variant="text" onClick={() => setRejectingDoc(null)}>
            {t("common.cancel")}
          </Button>
          <Button
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
              {previewDoc?.fileName ?? "—"}
            </Typography>
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setPreviewDoc(null)}>{t("common.cancel")}</Button>
        </DialogActions>
      </Dialog>
    </Stack>
  );
}
