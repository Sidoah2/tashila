"use client";

import Box from "@mui/material/Box";
import Typography from "@mui/material/Typography";
import { useTranslation } from "@/i18n/useTranslation";
import { brand } from "@/theme/colors";

type Props = {
  pickup: { label: string; lat: number; lng: number };
  dropOff: { label: string; lat: number; lng: number };
};

export default function MapPreview({ pickup, dropOff }: Props) {
  const { t } = useTranslation();
  return (
    <Box
      sx={{
        position: "relative",
        borderRadius: 2,
        overflow: "hidden",
        backgroundColor: brand.bg,
        border: `1px solid ${brand.border}`,
        height: 220,
        backgroundImage: `repeating-linear-gradient(45deg, ${brand.card} 0 8px, transparent 8px 16px)`,
      }}
    >
      <svg
        viewBox="0 0 400 220"
        width="100%"
        height="100%"
        style={{ position: "absolute", inset: 0 }}
      >
        <path
          d="M 60 170 C 140 60, 240 220, 340 60"
          fill="none"
          stroke={brand.orange}
          strokeWidth="4"
          strokeLinecap="round"
          strokeDasharray="6 8"
        />
        <circle cx="60" cy="170" r="9" fill={brand.success} stroke="white" strokeWidth="3" />
        <circle cx="340" cy="60" r="9" fill={brand.danger} stroke="white" strokeWidth="3" />
      </svg>
      <Box
        sx={{
          position: "absolute",
          left: 12,
          bottom: 12,
          right: 12,
          display: "flex",
          gap: 1,
          flexWrap: "wrap",
        }}
      >
        <PointBadge color={brand.success} title={t("map.pickup")} label={pickup.label} />
        <PointBadge color={brand.danger} title={t("map.dropoff")} label={dropOff.label} />
      </Box>
      <Box
        sx={{
          position: "absolute",
          right: 8,
          top: 8,
          backgroundColor: "rgba(255,255,255,0.85)",
          borderRadius: 1,
          px: 1,
          py: 0.25,
        }}
      >
        <Typography variant="caption" color="text.secondary">
          {t("map.city")}
        </Typography>
      </Box>
    </Box>
  );
}

function PointBadge({
  color,
  title,
  label,
}: {
  color: string;
  title: string;
  label: string;
}) {
  return (
    <Box
      sx={{
        flex: "1 1 160px",
        backgroundColor: "white",
        borderRadius: 1.5,
        px: 1.25,
        py: 0.75,
        border: `1px solid ${brand.border}`,
        display: "flex",
        alignItems: "center",
        gap: 1,
        minWidth: 0,
      }}
    >
      <Box
        sx={{
          width: 10,
          height: 10,
          borderRadius: "50%",
          backgroundColor: color,
          flexShrink: 0,
        }}
      />
      <Box sx={{ minWidth: 0 }}>
        <Typography
          variant="caption"
          color="text.secondary"
          sx={{ display: "block", lineHeight: 1 }}
        >
          {title}
        </Typography>
        <Typography
          variant="body2"
          sx={{
            fontWeight: 600,
            overflow: "hidden",
            textOverflow: "ellipsis",
            whiteSpace: "nowrap",
          }}
        >
          {label}
        </Typography>
      </Box>
    </Box>
  );
}
