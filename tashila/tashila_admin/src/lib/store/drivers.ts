"use client";

import { create } from "zustand";
import * as driversApi from "@/lib/api/drivers";
import type {
  DocumentStatus,
  DocumentType,
  Driver,
  DriverApprovalStatus,
  TruckType,
} from "@/lib/types";

type DriversState = {
  drivers: Driver[];
  loading: boolean;
  loaded: boolean;
  error: string | null;
  load: (force?: boolean) => Promise<void>;
  loadDriver: (id: string) => Promise<void>;
  create: (input: {
    name: string;
    phone: string;
    truckType: TruckType;
    vehicleColor: string;
    vehicleModel: string;
    vehiclePlate: string;
    uploadedDocs?: DocumentType[];
  }) => Promise<Driver>;
  setDocStatus: (
    driverId: string,
    docType: DocumentType,
    status: DocumentStatus,
    rejectionReason?: string
  ) => Promise<Driver>;
  setApproval: (
    driverId: string,
    status: DriverApprovalStatus,
    reason?: string
  ) => Promise<Driver>;
  applyPlatformPayment: (
    driverId: string,
    amountDzd: number,
    note: string
  ) => Promise<Driver>;
  patchDriverLocation: (driverId: string, lat: number, lng: number) => void;
  setDriverOffline: (driverId: string) => void;
};

export const useDriversStore = create<DriversState>((set, get) => ({
  drivers: [],
  loading: false,
  loaded: false,
  error: null,
  load: async (force = false) => {
    if (!force && get().loaded) return;
    set({ loading: true, error: null });
    try {
      const drivers = await driversApi.listDrivers();
      const current = get().drivers;
      const merged = drivers.map((d) => {
        const existing = current.find((curr) => curr.id === d.id);
        if (existing && existing.trips !== undefined) {
          return {
            ...d,
            trips: existing.trips,
            platformPayments: existing.platformPayments,
            customerReviews: existing.customerReviews,
          };
        }
        return d;
      });
      set({ drivers: merged, loading: false, loaded: true });
    } catch (e) {
      set({
        error: e instanceof Error ? e.message : "Failed to load drivers",
        loading: false,
      });
    }
  },
  loadDriver: async (id) => {
    set({ loading: true, error: null });
    try {
      const driver = await driversApi.getDriver(id);
      if (!driver) {
        set({ error: "Driver not found", loading: false });
        return;
      }
      const current = get().drivers;
      const exists = current.some((d) => d.id === id);
      if (exists) {
        set({
          drivers: current.map((d) => (d.id === id ? driver : d)),
          loading: false,
        });
      } else {
        set({
          drivers: [...current, driver],
          loading: false,
        });
      }
    } catch (e) {
      set({
        error: e instanceof Error ? e.message : "Failed to load driver details",
        loading: false,
      });
    }
  },
  create: async (input) => {
    const driver = await driversApi.createDriver(input);
    set({ drivers: [driver, ...get().drivers] });
    return driver;
  },
  setDocStatus: async (driverId, docType, status, rejectionReason) => {
    const updated = await driversApi.updateDocumentStatus(
      driverId,
      docType,
      status,
      rejectionReason
    );
    set({
      drivers: get().drivers.map((d) => (d.id === updated.id ? updated : d)),
    });
    return updated;
  },
  setApproval: async (driverId, status, reason) => {
    const updated = await driversApi.setDriverApproval(driverId, status, reason);
    set({
      drivers: get().drivers.map((d) => (d.id === updated.id ? updated : d)),
    });
    return updated;
  },
  applyPlatformPayment: async (driverId, amountDzd, note) => {
    const updated = await driversApi.applyPlatformPayment(
      driverId,
      amountDzd,
      note
    );
    set({
      drivers: get().drivers.map((d) => (d.id === updated.id ? updated : d)),
    });
    return updated;
  },
  patchDriverLocation: (driverId, lat, lng) => {
    set({
      drivers: get().drivers.map((d) =>
        d.id === driverId
          ? { ...d, lastLocation: { lat, lng }, availability: "online" }
          : d,
      ),
    });
  },
  setDriverOffline: (driverId) => {
    set({
      drivers: get().drivers.map((d) =>
        d.id === driverId ? { ...d, availability: "offline" } : d,
      ),
    });
  },
}));
