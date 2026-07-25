"use client";

import { create } from "zustand";
import * as tripsApi from "@/lib/api/trips";
import type { DispatchInput } from "@/lib/api/trips";
import type { Trip, TripStatus } from "@/lib/types";

type TripsState = {
  trips: Trip[];
  loading: boolean;
  loaded: boolean;
  error: string | null;
  load: (force?: boolean) => Promise<void>;
  dispatch: (input: DispatchInput) => Promise<Trip>;
  setStatus: (id: string, status: TripStatus) => Promise<Trip>;
};

export const useTripsStore = create<TripsState>((set, get) => ({
  trips: [],
  loading: false,
  loaded: false,
  error: null,
  load: async (force = false) => {
    if (!force && get().loaded) return;
    set({ loading: true, error: null });
    try {
      const trips = await tripsApi.listTrips();
      set({ trips, loading: false, loaded: true });
    } catch (e) {
      set({
        error: e instanceof Error ? e.message : "Failed to load trips",
        loading: false,
      });
    }
  },
  dispatch: async (input) => {
    const trip = await tripsApi.dispatchTrip(input);
    set({ trips: [trip, ...get().trips] });
    return trip;
  },
  setStatus: async (id, status) => {
    const updated = await tripsApi.setTripStatus(id, status);
    set({
      trips: get().trips.map((t) => (t.id === updated.id ? updated : t)),
    });
    return updated;
  },
}));
