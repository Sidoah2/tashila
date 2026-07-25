"use client";

import Chip from "@mui/material/Chip";
import {
  driverApprovalStatusColor,
  getDriverApprovalStatusLabel,
  getTripStatusLabel,
  getUserStatusLabel,
  tripStatusColor,
  userStatusColor,
} from "@/lib/labels";
import { useTranslation } from "@/i18n/useTranslation";
import type { DriverApprovalStatus, TripStatus, UserStatus } from "@/lib/types";

export function TripStatusChip({ status }: { status: TripStatus }) {
  const { t } = useTranslation();
  return (
    <Chip
      size="small"
      color={tripStatusColor[status]}
      label={getTripStatusLabel(t, status)}
      variant={status === "completed" ? "filled" : "outlined"}
      sx={{ fontWeight: 700 }}
    />
  );
}

export function DriverApprovalChip({
  status,
}: {
  status: DriverApprovalStatus;
}) {
  const { t } = useTranslation();
  return (
    <Chip
      size="small"
      color={driverApprovalStatusColor[status]}
      label={getDriverApprovalStatusLabel(t, status)}
      variant={status === "approved" ? "filled" : "outlined"}
      sx={{ fontWeight: 700 }}
    />
  );
}

export function UserStatusChip({ status }: { status: UserStatus }) {
  const { t } = useTranslation();
  return (
    <Chip
      size="small"
      color={userStatusColor[status]}
      label={getUserStatusLabel(t, status)}
      variant={status === "active" ? "filled" : "outlined"}
      sx={{ fontWeight: 700 }}
    />
  );
}
