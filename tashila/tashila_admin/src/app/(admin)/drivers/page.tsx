"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import Box from "@mui/material/Box";
import Card from "@mui/material/Card";
import Stack from "@mui/material/Stack";
import Tab from "@mui/material/Tab";
import Tabs from "@mui/material/Tabs";
import Avatar from "@mui/material/Avatar";
import Button from "@mui/material/Button";
import Chip from "@mui/material/Chip";
import IconButton from "@mui/material/IconButton";
import TextField from "@mui/material/TextField";
import Tooltip from "@mui/material/Tooltip";
import Typography from "@mui/material/Typography";
import Divider from "@mui/material/Divider";
import InputAdornment from "@mui/material/InputAdornment";
import AddRoundedIcon from "@mui/icons-material/AddRounded";
import VisibilityRoundedIcon from "@mui/icons-material/VisibilityRounded";
import CheckCircleRoundedIcon from "@mui/icons-material/CheckCircleRounded";
import CancelRoundedIcon from "@mui/icons-material/CancelRounded";
import SearchRoundedIcon from "@mui/icons-material/SearchRounded";
import StarRoundedIcon from "@mui/icons-material/StarRounded";
import FiberManualRecordRoundedIcon from "@mui/icons-material/FiberManualRecordRounded";
import {
  DataGrid,
  type GridColDef,
  type GridRenderCellParams,
} from "@mui/x-data-grid";
import { useDriversStore } from "@/lib/store/drivers";
import { useToast } from "@/components/ToastProvider";
import { DriverApprovalChip } from "@/components/StatusChip";
import { getTruckTypeLabel } from "@/lib/labels";
import type { Driver, DriverApprovalStatus } from "@/lib/types";
import { brand } from "@/theme/colors";
import { useTranslation } from "@/i18n/useTranslation";
import { useFormatDate, useFormatNumber } from "@/i18n/format";
import { useDataGridLocaleText } from "@/i18n/dataGridLocale";

type TabValue = "all" | DriverApprovalStatus;

export default function DriversPage() {
  const drivers = useDriversStore((s) => s.drivers);
  const loading = useDriversStore((s) => s.loading);
  const load = useDriversStore((s) => s.load);
  const setApproval = useDriversStore((s) => s.setApproval);
  const showToast = useToast();
  const { t, locale } = useTranslation();
  const formatDate = useFormatDate();
  const formatNumber = useFormatNumber();
  const dataGridLocale = useDataGridLocaleText();

  const [tab, setTab] = useState<TabValue>("all");
  const [search, setSearch] = useState("");

  useEffect(() => {
    load();
  }, [load]);

  const counts = useMemo(() => {
    return {
      all: drivers.length,
      pending: drivers.filter((d) => d.approvalStatus === "pending").length,
      approved: drivers.filter((d) => d.approvalStatus === "approved").length,
      rejected: drivers.filter((d) => d.approvalStatus === "rejected").length,
    };
  }, [drivers]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return drivers.filter((d) => {
      if (tab !== "all" && d.approvalStatus !== tab) return false;
      if (!q) return true;
      return (
        d.name.toLowerCase().includes(q) ||
        d.phone.toLowerCase().includes(q) ||
        d.id.toLowerCase().includes(q)
      );
    });
  }, [drivers, tab, search]);

  const handleApproval = async (
    driver: Driver,
    status: DriverApprovalStatus
  ) => {
    try {
      await setApproval(driver.id, status);
      showToast(
        status === "approved"
          ? t("toast.driver_approved", { name: driver.name })
          : t("toast.driver_rejected", { name: driver.name }),
        status === "approved" ? "success" : "warning"
      );
    } catch (e) {
      showToast(
        e instanceof Error ? e.message : t("toast.action_failed"),
        "error"
      );
    }
  };

  const ratingFormatter = useMemo(() => {
    const fmt = new Intl.NumberFormat(
      locale === "ar" ? "ar-DZ" : locale === "fr" ? "fr-DZ" : "en-DZ",
      { minimumFractionDigits: 1, maximumFractionDigits: 1 }
    );
    return (v: number) => fmt.format(v);
  }, [locale]);

  const columns: GridColDef<Driver>[] = [
    { field: "id", headerName: t("common.id"), width: 110 },
    {
      field: "name",
      headerName: t("common.driver"),
      flex: 1,
      minWidth: 220,
      renderCell: (params: GridRenderCellParams<Driver>) => (
        <Stack direction="row" spacing={1.25} alignItems="center" sx={{ py: 1 }}>
          <Avatar
            src={params.row.avatarUrl ?? undefined}
            sx={{
              bgcolor: `${brand.orange}1F`,
              color: brand.orange,
              width: 32,
              height: 32,
              fontSize: 14,
              fontWeight: 700,
            }}
          >
            {(params.row.name || "")
              .split(" ")
              .filter(Boolean)
              .map((s) => s[0])
              .slice(0, 2)
              .join("")}
          </Avatar>
          <Box>
            <Typography sx={{ fontWeight: 600 }}>{params.row.name}</Typography>
            <Typography variant="caption" color="text.secondary">
              {params.row.phone}
            </Typography>
          </Box>
        </Stack>
      ),
    },
    {
      field: "truckType",
      headerName: t("common.truck"),
      width: 120,
      renderCell: (params: GridRenderCellParams<Driver>) => (
        <Chip
          size="small"
          variant="outlined"
          label={getTruckTypeLabel(t, params.row.truckType)}
        />
      ),
    },
    {
      field: "vehicle",
      headerName: t("drivers.column_vehicle"),
      minWidth: 150,
      flex: 0.6,
      sortable: false,
      renderCell: (params: GridRenderCellParams<Driver>) => (
        <Box sx={{ py: 1 }}>
          <Typography variant="body2" sx={{ fontWeight: 600 }}>
            {params.row.vehicleModel}
          </Typography>
          <Typography variant="caption" color="text.secondary" display="block">
            {params.row.vehicleColor}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            {params.row.vehiclePlate}
          </Typography>
        </Box>
      ),
    },
    {
      field: "latestReview",
      headerName: t("drivers.column_latest_review"),
      minWidth: 200,
      flex: 1,
      sortable: false,
      renderCell: (params: GridRenderCellParams<Driver>) => {
        const r = params.row.customerReviews[0];
        if (!r) {
          return (
            <Typography variant="body2" color="text.secondary">
              —
            </Typography>
          );
        }
        return (
          <Typography
            variant="body2"
            sx={{
              py: 1,
              display: "-webkit-box",
              WebkitLineClamp: 2,
              WebkitBoxOrient: "vertical",
              overflow: "hidden",
            }}
          >
            {r.rating}★ — {r.comment}
          </Typography>
        );
      },
    },
    {
      field: "availability",
      headerName: t("common.live"),
      width: 110,
      renderCell: (params: GridRenderCellParams<Driver>) => (
        <Stack direction="row" alignItems="center" spacing={0.5}>
          <FiberManualRecordRoundedIcon
            sx={{
              fontSize: 12,
              color:
                params.row.availability === "online"
                  ? brand.success
                  : brand.textSecondary,
            }}
          />
          <Typography variant="body2">
            {params.row.availability === "online"
              ? t("common.online")
              : t("common.offline")}
          </Typography>
        </Stack>
      ),
    },
    {
      field: "rating",
      headerName: t("common.rating"),
      width: 100,
      renderCell: (params: GridRenderCellParams<Driver>) =>
        params.row.rating ? (
          <Stack direction="row" alignItems="center" spacing={0.5}>
            <StarRoundedIcon sx={{ fontSize: 16, color: brand.warning }} />
            <Typography variant="body2" sx={{ fontWeight: 600 }}>
              {ratingFormatter(params.row.rating)}
            </Typography>
          </Stack>
        ) : (
          <Typography variant="body2" color="text.secondary">
            —
          </Typography>
        ),
    },
    {
      field: "platformDueDzd",
      headerName: t("drivers.column_platform_dues"),
      width: 130,
      type: "number",
      renderCell: (params: GridRenderCellParams<Driver>) => (
        <Typography variant="body2" sx={{ fontWeight: 600 }}>
          {formatNumber(params.row.platformDueDzd)} DZD
        </Typography>
      ),
    },
    {
      field: "completedTrips",
      headerName: t("common.trips"),
      width: 90,
      type: "number",
      valueFormatter: (value: number) => formatNumber(value),
    },
    {
      field: "createdAt",
      headerName: t("common.joined"),
      width: 130,
      valueFormatter: (value: string) => formatDate(value),
    },
    {
      field: "approvalStatus",
      headerName: t("common.status"),
      width: 150,
      renderCell: (params: GridRenderCellParams<Driver>) => (
        <DriverApprovalChip status={params.row.approvalStatus} />
      ),
    },
    {
      field: "actions",
      headerName: t("common.actions"),
      width: 180,
      sortable: false,
      filterable: false,
      renderCell: (params: GridRenderCellParams<Driver>) => (
        <Stack direction="row" spacing={0.5}>
          <Tooltip title={t("drivers.tooltip_view_documents")}>
            <IconButton
              size="small"
              component={Link}
              href={`/drivers/${params.row.id}`}
            >
              <VisibilityRoundedIcon fontSize="small" />
            </IconButton>
          </Tooltip>
          {params.row.approvalStatus !== "approved" && (
            <Tooltip title={t("drivers.tooltip_approve")}>
              <IconButton
                size="small"
                color="success"
                onClick={() => handleApproval(params.row, "approved")}
              >
                <CheckCircleRoundedIcon fontSize="small" />
              </IconButton>
            </Tooltip>
          )}
          {params.row.approvalStatus !== "rejected" && (
            <Tooltip title={t("drivers.tooltip_reject")}>
              <IconButton
                size="small"
                color="error"
                onClick={() => handleApproval(params.row, "rejected")}
              >
                <CancelRoundedIcon fontSize="small" />
              </IconButton>
            </Tooltip>
          )}
        </Stack>
      ),
    },
  ];

  return (
    <Card>
      <Box sx={{ p: 2, display: "flex", flexWrap: "wrap", gap: 1.5 }}>
        <TextField
          placeholder={t("drivers.search_placeholder")}
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          sx={{ flex: 1, minWidth: 220 }}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <SearchRoundedIcon fontSize="small" />
              </InputAdornment>
            ),
          }}
        />
        <Button
          component={Link}
          href="/drivers/new"
          startIcon={<AddRoundedIcon />}
        >
          {t("drivers.add_driver")}
        </Button>
      </Box>
      <Box sx={{ px: 2 }}>
        <Tabs
          value={tab}
          onChange={(_, v) => setTab(v as TabValue)}
          variant="scrollable"
          allowScrollButtonsMobile
        >
          <Tab
            value="pending"
            label={
              <Stack direction="row" alignItems="center" spacing={1}>
                <span>{t("drivers.tab_pending")}</span>
                <Chip
                  size="small"
                  color="warning"
                  label={counts.pending}
                  sx={{ height: 20, fontSize: 12 }}
                />
              </Stack>
            }
          />
          <Tab
            value="approved"
            label={t("drivers.tab_approved", { count: counts.approved })}
          />
          <Tab
            value="rejected"
            label={t("drivers.tab_rejected", { count: counts.rejected })}
          />
          <Tab
            value="all"
            label={t("drivers.tab_all", { count: counts.all })}
          />
        </Tabs>
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
          initialState={{
            pagination: { paginationModel: { pageSize: 10 } },
          }}
          pageSizeOptions={[10, 25, 50]}
          sx={{
            border: "none",
            "& .MuiDataGrid-columnHeaders": { backgroundColor: brand.bg },
            "& .MuiDataGrid-cell:focus": { outline: "none" },
            "& .MuiDataGrid-cell:focus-within": { outline: "none" },
          }}
        />
      </Box>
    </Card>
  );
}
