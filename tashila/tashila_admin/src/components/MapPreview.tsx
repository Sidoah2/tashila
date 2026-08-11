"use client";

import { useEffect, useRef } from "react";
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
  const ref = useRef<HTMLDivElement | null>(null);
  const key = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;

  useEffect(() => {
    if (!key || !ref.current) return;

    const el = ref.current;
    let cancelled = false;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let map: any = null;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const elements: any[] = [];

    const bootstrap = () => {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const g = (window as any).google?.maps;
      if (cancelled || !g) return;

      map = new g.Map(el, {
        center: { lat: pickup.lat, lng: pickup.lng },
        zoom: 12,
        mapTypeControl: false,
        streetViewControl: false,
        fullscreenControl: false,
      });

      const pMarker = new g.Marker({
        map,
        position: { lat: pickup.lat, lng: pickup.lng },
        title: `Pickup: ${pickup.label}`,
        icon: "https://maps.google.com/mapfiles/ms/icons/green-dot.png",
      });
      elements.push(pMarker);

      const dMarker = new g.Marker({
        map,
        position: { lat: dropOff.lat, lng: dropOff.lng },
        title: `Drop-off: ${dropOff.label}`,
        icon: "https://maps.google.com/mapfiles/ms/icons/red-dot.png",
      });
      elements.push(dMarker);

      const polyline = new g.Polyline({
        path: [
          { lat: pickup.lat, lng: pickup.lng },
          { lat: dropOff.lat, lng: dropOff.lng },
        ],
        geodesic: true,
        strokeColor: brand.orange,
        strokeOpacity: 0.8,
        strokeWeight: 4,
        map,
      });
      elements.push(polyline);

      const bounds = new g.LatLngBounds();
      bounds.extend({ lat: pickup.lat, lng: pickup.lng });
      bounds.extend({ lat: dropOff.lat, lng: dropOff.lng });
      map.fitBounds(bounds);

      const listener = map.addListener("bounds_changed", () => {
        if (map.getZoom() > 14) map.setZoom(14);
        g.event.removeListener(listener);
      });
    };

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const w = window as any;
    if (w.google?.maps) {
      bootstrap();
      return () => {
        cancelled = true;
        elements.forEach((e) => e.setMap(null));
      };
    }

    const existing = document.querySelector(
      "script[data-tashila-google-maps]"
    ) as HTMLScriptElement | null;
    let script: HTMLScriptElement;
    if (existing) {
      script = existing;
    } else {
      script = document.createElement("script");
      script.async = true;
      script.defer = true;
      script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(key)}&libraries=places`;
      script.dataset.tashilaGoogleMaps = "1";
      document.head.appendChild(script);
    }
    script.addEventListener("load", bootstrap);

    return () => {
      cancelled = true;
      elements.forEach((e) => e.setMap(null));
    };
  }, [key, pickup, dropOff]);

  if (key) {
    return (
      <Box
        ref={ref}
        sx={{
          width: "100%",
          height: 220,
          borderRadius: 2,
          overflow: "hidden",
          border: `1px solid ${brand.border}`,
        }}
      />
    );
  }

  // Fallback to SVG curve
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
