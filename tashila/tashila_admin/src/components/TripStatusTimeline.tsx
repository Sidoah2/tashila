"use client";

import Box from "@mui/material/Box";
import Stack from "@mui/material/Stack";
import Typography from "@mui/material/Typography";
import CheckCircleRoundedIcon from "@mui/icons-material/CheckCircleRounded";
import RadioButtonUncheckedRoundedIcon from "@mui/icons-material/RadioButtonUncheckedRounded";
import CancelRoundedIcon from "@mui/icons-material/CancelRounded";
import SearchRoundedIcon from "@mui/icons-material/SearchRounded";
import { brand } from "@/theme/colors";
import type { TripStatus } from "@/lib/types";
import { useTranslation } from "@/i18n/useTranslation";

const STEPS: { labelKey: string; match: (s: TripStatus) => boolean }[] = [
  {
    labelKey: "trips.timeline_to_client",
    match: (s) => s === "accepted" || s === "headingToPickup",
  },
  {
    labelKey: "trips.timeline_trip_started",
    match: (s) => s === "inProgress",
  },
  {
    labelKey: "trips.timeline_arrived",
    match: (s) => s === "awaitingCash" || s === "completed",
  },
];

function activeStepIndex(status: TripStatus): number {
  if (status === "requested") return -1;
  const idx = STEPS.findIndex((step) => step.match(status));
  return idx === -1 ? 0 : idx;
}

export default function TripStatusTimeline({ status }: { status: TripStatus }) {
  const { t } = useTranslation();
  if (status === "cancelled") {
    return (
      <Stack
        direction="row"
        spacing={1}
        alignItems="center"
        sx={{
          color: brand.danger,
          backgroundColor: `${brand.danger}10`,
          p: 1.5,
          borderRadius: 2,
        }}
      >
        <CancelRoundedIcon />
        <Typography sx={{ fontWeight: 700 }}>{t("trips.trip_cancelled")}</Typography>
      </Stack>
    );
  }

  if (status === "requested") {
    return (
      <Stack
        direction="row"
        spacing={1}
        alignItems="center"
        sx={{
          color: brand.orange,
          backgroundColor: `${brand.orange}12`,
          p: 1.5,
          borderRadius: 2,
        }}
      >
        <SearchRoundedIcon />
        <Typography sx={{ fontWeight: 700 }}>
          {t("trips.timeline_search_driver")}
        </Typography>
      </Stack>
    );
  }

  const current = activeStepIndex(status);

  return (
    <Stack spacing={1}>
      {STEPS.map((step, i) => {
        const reached = i <= current;
        const isCurrent = i === current;
        return (
          <Stack
            key={step.labelKey}
            direction="row"
            spacing={1.5}
            alignItems="center"
            sx={{ opacity: reached ? 1 : 0.45 }}
          >
            <Box sx={{ position: "relative", display: "flex" }}>
              {reached ? (
                <CheckCircleRoundedIcon
                  sx={{
                    color: isCurrent ? brand.orange : brand.success,
                  }}
                />
              ) : (
                <RadioButtonUncheckedRoundedIcon sx={{ color: brand.textSecondary }} />
              )}
              {i < STEPS.length - 1 && (
                <Box
                  sx={{
                    position: "absolute",
                    left: 11,
                    top: 24,
                    width: 2,
                    height: 16,
                    backgroundColor: reached ? brand.success : brand.border,
                  }}
                />
              )}
            </Box>
            <Typography sx={{ fontWeight: isCurrent ? 800 : 500 }}>
              {t(step.labelKey)}
            </Typography>
          </Stack>
        );
      })}
    </Stack>
  );
}
