"use client";
import { useEffect, useRef } from "react";
import Box from "@mui/material/Box";
import Typography from "@mui/material/Typography";
import type { Driver } from "@/lib/types";
import { brand } from "@/theme/colors";

type Props = {
  drivers: Driver[];
  center: { lat: number; lng: number };
  selectedDriverId: string | null;
  onSelectDriver: (id: string) => void;
  pickup?: { lat: number; lng: number } | null;
  dropOff?: { lat: number; lng: number } | null;
  onDragPickup?: (lat: number, lng: number) => void;
  onDragDropOff?: (lat: number, lng: number) => void;
};

/**
 * Loads Google Maps JS with Places Library when `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` is set.
 * Otherwise shows a compact fallback list.
 */
export default function LiveTruckMap({
  drivers,
  center,
  selectedDriverId,
  onSelectDriver,
  pickup,
  dropOff,
  onDragPickup,
  onDragDropOff,
}: Props) {
  const ref = useRef<HTMLDivElement | null>(null);
  const key = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;

  useEffect(() => {
    if (!key || !ref.current) return;

    const el = ref.current;
    let cancelled = false;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let map: any = null;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const mapElements: any[] = [];

    const bootstrap = () => {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const g = (window as any).google?.maps;
      if (cancelled || !g) return;

      map = new g.Map(el, {
        center,
        zoom: 11,
        mapTypeControl: false,
        streetViewControl: false,
        fullscreenControl: false,
      });

      // 1. Render drivers
      for (const d of drivers) {
        const pos = d.lastLocation
          ? { lat: d.lastLocation.lat, lng: d.lastLocation.lng }
          : center;
        const marker = new g.Marker({
          map,
          position: pos,
          title: d.name,
          icon: d.id === selectedDriverId
            ? "https://maps.google.com/mapfiles/ms/icons/truck.png"
            : undefined,
        });
        marker.addListener("click", () => onSelectDriver(d.id));
        mapElements.push(marker);
      }

      // 2. Render pickup marker
      let pickupMarker: any = null;
      if (pickup && typeof pickup.lat === "number" && typeof pickup.lng === "number") {
        pickupMarker = new g.Marker({
          map,
          position: pickup,
          title: "Pickup Point (Drag to adjust)",
          draggable: Boolean(onDragPickup),
          icon: "https://maps.google.com/mapfiles/ms/icons/green-dot.png",
        });
        if (onDragPickup) {
          pickupMarker.addListener("dragend", () => {
            const pos = pickupMarker.getPosition();
            if (pos) onDragPickup(pos.lat(), pos.lng());
          });
        }
        mapElements.push(pickupMarker);
      }

      // 3. Render drop-off marker
      let dropoffMarker: any = null;
      if (dropOff && typeof dropOff.lat === "number" && typeof dropOff.lng === "number") {
        dropoffMarker = new g.Marker({
          map,
          position: dropOff,
          title: "Drop-off Point (Drag to adjust)",
          draggable: Boolean(onDragDropOff),
          icon: "https://maps.google.com/mapfiles/ms/icons/red-dot.png",
        });
        if (onDragDropOff) {
          dropoffMarker.addListener("dragend", () => {
            const pos = dropoffMarker.getPosition();
            if (pos) onDragDropOff(pos.lat(), pos.lng());
          });
        }
        mapElements.push(dropoffMarker);
      }

      // 4. Render polyline path
      if (pickup && dropOff) {
        const polyline = new g.Polyline({
          path: [pickup, dropOff],
          geodesic: true,
          strokeColor: brand.orange,
          strokeOpacity: 0.8,
          strokeWeight: 4,
          map,
        });
        mapElements.push(polyline);
      }

      // 5. Adjust bounds to fit pickup and dropoff
      if (pickup || dropOff) {
        const bounds = new g.LatLngBounds();
        if (pickup && typeof pickup.lat === "number") bounds.extend(pickup);
        if (dropOff && typeof dropOff.lat === "number") bounds.extend(dropOff);
        map.fitBounds(bounds);
        
        // Prevent map from zooming in too far
        const listener = map.addListener("bounds_changed", () => {
          if (map.getZoom() > 14) map.setZoom(14);
          g.event.removeListener(listener);
        });
      }
    };

    const w = window as any;
    if (w.google?.maps) {
      bootstrap();
      return () => {
        cancelled = true;
        mapElements.forEach((m) => m.setMap(null));
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
      mapElements.forEach((m) => m.setMap(null));
    };
  }, [drivers, center.lat, center.lng, onSelectDriver, pickup, dropOff, onDragPickup, onDragDropOff, selectedDriverId]);

  if (!key) {
    return (
      <Box
        sx={{
          borderRadius: 2,
          border: `1px dashed ${brand.border}`,
          p: 2,
          bgcolor: `${brand.orange}08`,
        }}
      >
        <Typography variant="subtitle2" sx={{ fontWeight: 800, mb: 1 }}>
          Live map
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
          Set <code>NEXT_PUBLIC_GOOGLE_MAPS_API_KEY</code> to enable the live
          truck map. Until then, pick a driver from the list beside the form.
        </Typography>
        {drivers.map((d) => (
          <Box
            key={d.id}
            onClick={() => onSelectDriver(d.id)}
            sx={{
              py: 0.75,
              px: 1,
              borderRadius: 1,
              cursor: "pointer",
              bgcolor:
                d.id === selectedDriverId ? `${brand.orange}22` : "transparent",
              fontWeight: d.id === selectedDriverId ? 800 : 500,
            }}
          >
            {d.name} · {d.truckType}
          </Box>
        ))}
      </Box>
    );
  }

  return (
    <Box
      ref={ref}
      sx={{
        width: "100%",
        height: 380,
        borderRadius: 2,
        overflow: "hidden",
        border: `1px solid ${brand.border}`,
      }}
    />
  );
}
