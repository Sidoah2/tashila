"use client";

import { useEffect } from "react";
import { io, type Socket } from "socket.io-client";
import { STORAGE_KEYS } from "@/lib/storage";
import type { AdminSession } from "@/lib/types";
import { useDriversStore } from "@/lib/store/drivers";
import { useTripsStore } from "@/lib/store/trips";

const SOCKET_URL =
  process.env.NEXT_PUBLIC_API_URL ??
  "https://tashila-api-production.up.railway.app";

function readSession(): AdminSession | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEYS.session);
    if (!raw) return null;
    return JSON.parse(raw) as AdminSession;
  } catch {
    return null;
  }
}

/**
 * Live admin socket: driver locations, trip status, approval queue hints.
 */
export function useAdminRealtime(enabled: boolean) {
  const patchDriverLocation = useDriversStore((s) => s.patchDriverLocation);
  const setDriverOffline = useDriversStore((s) => s.setDriverOffline);
  const loadDrivers = useDriversStore((s) => s.load);
  const loadTrips = useTripsStore((s) => s.load);

  useEffect(() => {
    if (!enabled) return;

    const session = readSession();
    if (!session?.accessToken) return;

    const socket: Socket = io(SOCKET_URL, {
      transports: ["websocket"],
      auth: { token: session.accessToken },
    });

    socket.on("admin:driver_location", (payload: unknown) => {
      if (!payload || typeof payload !== "object") return;
      const data = payload as Record<string, unknown>;
      const driverId = data.driverId as string | undefined;
      const lat = data.lat as number | undefined;
      const lng = data.lng as number | undefined;
      if (!driverId || lat == null || lng == null) return;
      patchDriverLocation(driverId, lat, lng);
    });

    socket.on("admin:driver_went_offline", (payload: unknown) => {
      if (!payload || typeof payload !== "object") return;
      const driverId = (payload as Record<string, unknown>).driverId as
        | string
        | undefined;
      if (driverId) setDriverOffline(driverId);
    });

    socket.on("admin:trip_status_changed", () => {
      void loadTrips(true);
    });

    socket.on("admin:approval_pending", () => {
      void loadDrivers(true);
    });

    const poll = window.setInterval(() => {
      void loadDrivers(true);
    }, 30_000);

    return () => {
      window.clearInterval(poll);
      socket.disconnect();
    };
  }, [enabled, patchDriverLocation, setDriverOffline, loadDrivers, loadTrips]);
}
