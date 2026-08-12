"use client";

import { useEffect, useMemo, useState } from "react";
import Box from "@mui/material/Box";
import Card from "@mui/material/Card";
import Stack from "@mui/material/Stack";
import TextField from "@mui/material/TextField";
import ToggleButton from "@mui/material/ToggleButton";
import ToggleButtonGroup from "@mui/material/ToggleButtonGroup";
import Button from "@mui/material/Button";
import Drawer from "@mui/material/Drawer";
import Typography from "@mui/material/Typography";
import Avatar from "@mui/material/Avatar";
import Divider from "@mui/material/Divider";
import IconButton from "@mui/material/IconButton";
import InputAdornment from "@mui/material/InputAdornment";
import VisibilityRoundedIcon from "@mui/icons-material/VisibilityRounded";
import BlockRoundedIcon from "@mui/icons-material/BlockRounded";
import CheckCircleRoundedIcon from "@mui/icons-material/CheckCircleRounded";
import SearchRoundedIcon from "@mui/icons-material/SearchRounded";
import CloseRoundedIcon from "@mui/icons-material/CloseRounded";
import StarRoundedIcon from "@mui/icons-material/StarRounded";
import Paper from "@mui/material/Paper";
import {
  DataGrid,
  type GridColDef,
  type GridRenderCellParams,
} from "@mui/x-data-grid";
import { getUser } from "@/lib/api/users";
import { useUsersStore } from "@/lib/store/users";
import { useToast } from "@/components/ToastProvider";
import { UserStatusChip } from "@/components/StatusChip";
import type { User } from "@/lib/types";
import { brand } from "@/theme/colors";
import { useTranslation } from "@/i18n/useTranslation";
import { useFormatDate, useFormatNumber } from "@/i18n/format";
import { useDataGridLocaleText } from "@/i18n/dataGridLocale";

type StatusFilter = "all" | "active" | "suspended";

export default function UsersPage() {
  const users = useUsersStore((s) => s.users);
  const loading = useUsersStore((s) => s.loading);
  const load = useUsersStore((s) => s.load);
  const setStatus = useUsersStore((s) => s.setStatus);
  const showToast = useToast();
  const { t } = useTranslation();
  const formatDate = useFormatDate();
  const formatNumber = useFormatNumber();
  const dataGridLocale = useDataGridLocaleText();

  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [selected, setSelected] = useState<User | null>(null);

  useEffect(() => {
    load();
  }, [load]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return users.filter((u) => {
      if (statusFilter !== "all" && u.status !== statusFilter) return false;
      if (!q) return true;
      const fullName = `${u.firstName} ${u.lastName}`.toLowerCase();
      return (
        fullName.includes(q) ||
        u.phone.toLowerCase().includes(q) ||
        u.id.toLowerCase().includes(q)
      );
    });
  }, [users, search, statusFilter]);

  const handleToggleStatus = async (user: User) => {
    const next = user.status === "active" ? "suspended" : "active";
    const updated = await setStatus(user.id, next);
    setSelected((prev) => (prev?.id === updated.id ? updated : prev));
    const fullName = `${user.firstName} ${user.lastName}`;
    showToast(
      next === "suspended"
        ? t("toast.user_suspended", { name: fullName })
        : t("toast.user_reactivated", { name: fullName }),
      next === "suspended" ? "warning" : "success"
    );
  };

  const columns: GridColDef<User>[] = [
    { field: "id", headerName: t("common.id"), width: 110 },
    {
      field: "name",
      headerName: t("common.name_field"),
      flex: 1,
      minWidth: 180,
      valueGetter: (_value, row) => `${row.firstName} ${row.lastName}`,
      renderCell: (params: GridRenderCellParams<User>) => (
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
            {params.row.firstName[0]}
            {params.row.lastName[0]}
          </Avatar>
          <Typography sx={{ fontWeight: 600 }}>
            {params.row.firstName} {params.row.lastName}
          </Typography>
        </Stack>
      ),
    },
    { field: "phone", headerName: t("common.phone"), width: 160 },
    {
      field: "averageRating",
      headerName: t("users.column_avg_rating"),
      width: 120,
      renderCell: (params: GridRenderCellParams<User>) =>
        params.row.averageRating > 0 ? (
          <Stack direction="row" alignItems="center" spacing={0.5}>
            <StarRoundedIcon sx={{ fontSize: 16, color: brand.warning }} />
            <Typography variant="body2" sx={{ fontWeight: 600 }}>
              {formatNumber(params.row.averageRating)}
            </Typography>
          </Stack>
        ) : (
          <Typography variant="body2" color="text.secondary">
            —
          </Typography>
        ),
    },
    {
      field: "totalTrips",
      headerName: t("users.column_total_trips"),
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
      field: "status",
      headerName: t("common.status"),
      width: 130,
      renderCell: (params: GridRenderCellParams<User>) => (
        <UserStatusChip status={params.row.status} />
      ),
    },
    {
      field: "actions",
      headerName: t("common.actions"),
      width: 240,
      sortable: false,
      filterable: false,
      renderCell: (params: GridRenderCellParams<User>) => (
        <Stack direction="row" spacing={0.5}>
          <Button
            size="small"
            variant="outlined"
            startIcon={<VisibilityRoundedIcon fontSize="small" />}
            onClick={async () => {
              const full = await getUser(params.row.id);
              setSelected(full ?? params.row);
            }}
          >
            {t("common.view")}
          </Button>
          {params.row.status !== "deleted" && (
            <Button
              size="small"
              color={params.row.status === "active" ? "error" : "success"}
              variant="outlined"
              startIcon={
                params.row.status === "active" ? (
                  <BlockRoundedIcon fontSize="small" />
                ) : (
                  <CheckCircleRoundedIcon fontSize="small" />
                )
              }
              onClick={() => handleToggleStatus(params.row)}
            >
              {params.row.status === "active"
                ? t("users.suspend")
                : t("users.activate")}
            </Button>
          )}
        </Stack>
      ),
    },
  ];

  return (
    <>
      <Card>
        <Box sx={{ p: 2, display: "flex", flexWrap: "wrap", gap: 1.5 }}>
          <TextField
            placeholder={t("users.search_placeholder")}
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
          <ToggleButtonGroup
            value={statusFilter}
            exclusive
            onChange={(_, v) => v && setStatusFilter(v as StatusFilter)}
            size="small"
          >
            <ToggleButton value="all" sx={{ px: 2 }}>
              {t("users.filter_all")}
            </ToggleButton>
            <ToggleButton value="active" sx={{ px: 2 }}>
              {t("users.filter_active")}
            </ToggleButton>
            <ToggleButton value="suspended" sx={{ px: 2 }}>
              {t("users.filter_suspended")}
            </ToggleButton>
          </ToggleButtonGroup>
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

      <Drawer
        anchor="right"
        open={Boolean(selected)}
        onClose={() => setSelected(null)}
        PaperProps={{ sx: { width: { xs: "100%", sm: 420 } } }}
      >
        {selected && (
          <Box sx={{ p: 3 }}>
            <Stack
              direction="row"
              justifyContent="space-between"
              alignItems="center"
              sx={{ mb: 2 }}
            >
              <Typography variant="h6">{t("users.drawer_title")}</Typography>
              <IconButton onClick={() => setSelected(null)}>
                <CloseRoundedIcon />
              </IconButton>
            </Stack>
            <Stack direction="row" alignItems="center" spacing={2} sx={{ mb: 3 }}>
              <Avatar
                src={selected.avatarUrl ?? undefined}
                sx={{
                  width: 56,
                  height: 56,
                  bgcolor: `${brand.orange}1F`,
                  color: brand.orange,
                  fontSize: 22,
                  fontWeight: 800,
                }}
              >
                {selected.firstName[0]}
                {selected.lastName[0]}
              </Avatar>
              <Box>
                <Typography variant="h6" sx={{ fontWeight: 800 }}>
                  {selected.firstName} {selected.lastName}
                </Typography>
                <Typography color="text.secondary">{selected.phone}</Typography>
              </Box>
            </Stack>
            <Divider sx={{ mb: 2 }} />
            <DetailRow label={t("common.id")} value={selected.id} />
            <DetailRow label={t("common.status")}>
              <UserStatusChip status={selected.status} />
            </DetailRow>
            <DetailRow
              label={t("users.row_total_trips")}
              value={formatNumber(selected.totalTrips)}
            />
            <DetailRow
              label={t("users.row_completed_trips")}
              value={formatNumber(selected.completedTripsCount ?? 0)}
            />
            <DetailRow
              label={t("users.row_cancelled_trips")}
              value={formatNumber(selected.cancelledTripsCount ?? 0)}
            />
            <DetailRow
              label={t("common.joined")}
              value={formatDate(selected.createdAt)}
            />
            <DetailRow
              label={t("users.drawer_avg_rating")}
              value={
                selected.averageRating > 0
                  ? formatNumber(selected.averageRating)
                  : "—"
              }
            />
            <Typography variant="subtitle2" sx={{ fontWeight: 700, mt: 2, mb: 1 }}>
              {t("users.drawer_reviews_title")}
            </Typography>
            {selected.driverReviews.length === 0 ? (
              <Typography variant="body2" color="text.secondary">
                {t("users.drawer_reviews_empty")}
              </Typography>
            ) : (
              <Stack spacing={1.25}>
                {selected.driverReviews.map((r) => (
                  <Paper key={r.id} variant="outlined" sx={{ p: 1.5 }}>
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography sx={{ fontWeight: 700 }}>{r.driverName}</Typography>
                      <Stack direction="row" alignItems="center" spacing={0.25}>
                        <StarRoundedIcon sx={{ fontSize: 16, color: brand.warning }} />
                        <Typography variant="body2">{r.rating}</Typography>
                      </Stack>
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
            {selected.status !== "deleted" && (
              <Box sx={{ mt: 3 }}>
                <Button
                  fullWidth
                  variant="contained"
                  color={selected.status === "active" ? "error" : "success"}
                  size="large"
                  onClick={() => handleToggleStatus(selected)}
                  startIcon={
                    selected.status === "active" ? (
                      <BlockRoundedIcon />
                    ) : (
                      <CheckCircleRoundedIcon />
                    )
                  }
                >
                  {selected.status === "active"
                    ? t("users.suspend_account")
                    : t("users.reactivate_account")}
                </Button>
              </Box>
            )}
          </Box>
        )}
      </Drawer>
    </>
  );
}

function DetailRow({
  label,
  value,
  children,
}: {
  label: string;
  value?: string;
  children?: React.ReactNode;
}) {
  return (
    <Stack
      direction="row"
      justifyContent="space-between"
      alignItems="center"
      sx={{ py: 1 }}
    >
      <Typography color="text.secondary">{label}</Typography>
      {children ?? (
        <Typography sx={{ fontWeight: 600 }}>{value}</Typography>
      )}
    </Stack>
  );
}
