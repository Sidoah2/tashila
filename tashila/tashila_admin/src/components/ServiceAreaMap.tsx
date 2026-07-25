"use client";

import { useEffect, useRef } from "react";
import Box from "@mui/material/Box";
import Typography from "@mui/material/Typography";
import { brand } from "@/theme/colors";

type Props = {
  center: { lat: number; lng: number };
  radiusKm: number;
  onCenterChange: (center: { lat: number; lng: number }) => void;
};

export default function ServiceAreaMap({ center, radiusKm, onCenterChange }: Props) {
  const ref = useRef<HTMLDivElement | null>(null);
  const key = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;

  useEffect(() => {
    if (!key || !ref.current) return;

    const el = ref.current;
    let cancelled = false;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let map: any = null;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let marker: any = null;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let circle: any = null;

    const bootstrap = () => {
      const g = (window as unknown as { google?: { maps?: unknown } }).google
        ?.maps as any;
      if (cancelled || !g) return;

      map = new g.Map(el, {
        center,
        zoom: 10,
        mapTypeControl: false,
        streetViewControl: false,
      });

      marker = new g.Marker({
        map,
        position: center,
        draggable: true,
        title: "Service area center",
      });

      circle = new g.Circle({
        map,
        center,
        radius: radiusKm * 1000,
        fillColor: brand.orange,
        fillOpacity: 0.15,
        strokeColor: brand.orange,
        strokeWeight: 2,
      });

      marker.addListener("dragend", () => {
        const pos = marker.getPosition();
        if (!pos) return;
        const next = { lat: pos.lat(), lng: pos.lng() };
        circle.setCenter(next);
        onCenterChange(next);
      });
    };

    const w = window as unknown as { google?: { maps?: unknown } };
    if (w.google?.maps) {
      bootstrap();
    } else {
      const script = document.createElement("script");
      script.src = `https://maps.googleapis.com/maps/api/js?key=${key}`;
      script.async = true;
      script.dataset.tashilaGoogleMaps = "1";
      script.onload = bootstrap;
      document.head.appendChild(script);
    }

    return () => {
      cancelled = true;
      if (circle) circle.setMap(null);
      if (marker) marker.setMap(null);
    };
  }, [key, onCenterChange]);

  useEffect(() => {
    if (!key || !ref.current) return;
    const g = (window as unknown as { google?: { maps?: unknown } }).google?.maps as any;
    if (!g) return;
  }, [center.lat, center.lng, radiusKm, key]);

  if (!key) {
    return (
      <Box
        sx={{
          p: 2,
          borderRadius: 2,
          border: `1px dashed ${brand.border}`,
          bgcolor: brand.bg,
        }}
      >
        <Typography variant="body2" color="text.secondary">
          Set NEXT_PUBLIC_GOOGLE_MAPS_API_KEY to configure the service area on the map.
        </Typography>
        <Typography variant="caption" color="text.secondary" sx={{ display: "block", mt: 1 }}>
          Center: {center.lat.toFixed(4)}, {center.lng.toFixed(4)} · Radius: {radiusKm} km
        </Typography>
      </Box>
    );
  }

  return (
    <Box
      ref={ref}
      sx={{
        height: 320,
        borderRadius: 2,
        overflow: "hidden",
        border: `1px solid ${brand.border}`,
      }}
    />
  );
}
