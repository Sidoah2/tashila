import type { Trip, TripStatus } from "../types";
import { apiFetch } from "./client";

interface ApiTripCoord {
  lat: number;
  lng: number;
  address: string;
}

interface ApiDispatchOffer {
  driverId: string;
  expiresAt: string;
  generation?: number;
  candidateIndex?: number;
  driver?: { id?: string; name?: string | null; phone?: string | null } | null;
}

interface ApiTrip {
  id: string;
  _id?: string;
  status: string;
  clientId: string;
  clientName?: string;
  clientPhone?: string | null;
  driverId: string | null;
  driverName?: string | null;
  driver?: { id?: string; name?: string | null; phone?: string | null } | null;
  pickup: ApiTripCoord;
  dropoff: ApiTripCoord;
  truckType: string;
  fare: number;
  finalFare?: number | null;
  distanceKm?: number;
  paymentMethod: string;
  createdAt: string;
  completedAt: string | null;
  driverRating: number | null;
  dispatchedByAdmin?: boolean;
  cashConfirmed?: boolean;
  dispatchOffer?: ApiDispatchOffer | null;
}

interface PaginatedTrips {
  items: ApiTrip[];
  total: number;
  page: number;
  limit: number;
  pages: number;
}

function mapTrip(t: ApiTrip): Trip {
  return {
    id: t.id ?? t._id ?? "",
    clientId: t.clientId,
    clientName: t.clientName ?? t.clientId,
    driverId: t.driverId ?? null,
    driverName: t.driverName ?? t.driver?.name ?? null,
    pickup: t.pickup.address || `${t.pickup.lat},${t.pickup.lng}`,
    dropOff: t.dropoff.address || `${t.dropoff.lat},${t.dropoff.lng}`,
    pickupLat: t.pickup.lat,
    pickupLng: t.pickup.lng,
    dropOffLat: t.dropoff.lat,
    dropOffLng: t.dropoff.lng,
    fare: t.finalFare ?? t.fare,
    finalFare: t.finalFare ?? null,
    distanceKm: t.distanceKm ?? 0,
    truckType: t.truckType as Trip["truckType"],
    status: t.status as TripStatus,
    createdAt: t.createdAt,
    completedAt: t.completedAt,
    rating: t.driverRating,
    cashConfirmed: t.status === "completed" || t.cashConfirmed === true,
    paymentMethod: "cash",
    dispatchedByAdmin: t.dispatchedByAdmin ?? false,
    clientPhone: t.clientPhone ?? null,
  };
}

export interface TripFilters {
  status?: string;
  from?: string;
  to?: string;
}

export async function listTrips(
  page: number = 1,
  limit: number = 100,
  filters?: TripFilters
): Promise<Trip[]> {
  const params = new URLSearchParams();
  params.set("limit", String(limit));
  params.set("page", String(page));
  if (filters?.status && filters.status !== "all") {
    params.set("status", filters.status);
  }
  if (filters?.from) {
    params.set("from", new Date(filters.from).toISOString());
  }
  if (filters?.to) {
    const d = new Date(filters.to);
    d.setHours(23, 59, 59, 999);
    params.set("to", d.toISOString());
  }
  const data = await apiFetch<PaginatedTrips>(
    `/admin/trips?${params.toString()}`,
  );
  return data.items.map(mapTrip);
}

export type TripDetail = Trip & {
  dispatchOffer?: {
    driverId: string;
    driverName: string | null;
    expiresAt: string;
    generation?: number;
  } | null;
};

export async function getTrip(id: string): Promise<TripDetail> {
  try {
    const t = await apiFetch<ApiTrip>(`/admin/trips/${id}`);
    const base = mapTrip(t);
    const offer = t.dispatchOffer;
    if (!offer) {
      return { ...base, dispatchOffer: null };
    }
    return {
      ...base,
      dispatchOffer: {
        driverId: offer.driverId,
        driverName: offer.driver?.name ?? null,
        expiresAt: offer.expiresAt,
        generation: offer.generation,
      },
    };
  } catch (error) {
    console.error(`Failed to fetch trip details for ${id}:`, error);
    throw error;
  }
}

export type DispatchInput = {
  clientId: string | null;
  clientName: string;
  externalLabel?: string;
  externalPhone?: string;
  driverId: string;
  driverName: string;
  pickup: string;
  dropOff: string;
  pickupLat: number;
  pickupLng: number;
  dropOffLat: number;
  dropOffLng: number;
  truckType: string;
  fare: number;
  dispatchMode: "accepted" | "requested";
};

export async function dispatchTrip(input: DispatchInput): Promise<Trip> {
  const body = {
    pickup: {
      lat: input.pickupLat,
      lng: input.pickupLng,
      address: input.pickup,
    },
    dropoff: {
      lat: input.dropOffLat,
      lng: input.dropOffLng,
      address: input.dropOff,
    },
    truckType: input.truckType,
    driverId: input.driverId,
    clientId: input.clientId,
    externalLabel: input.externalLabel ?? null,
    externalPhone: input.externalPhone ?? null,
    paymentMethod: "cash",
    dispatchMode: input.dispatchMode,
  };
  const t = await apiFetch<ApiTrip>("/admin/trips/dispatch", {
    method: "POST",
    body: JSON.stringify(body),
  });
  return {
    ...mapTrip(t),
    clientName: input.clientName,
    driverName: input.driverName,
    distanceKm: t.distanceKm ?? 0,
  };
}

export async function setTripStatus(
  id: string,
  status: TripStatus,
): Promise<Trip> {
  const t = await apiFetch<ApiTrip>(`/admin/trips/${id}/status`, {
    method: "PUT",
    body: JSON.stringify({ status }),
  });
  return mapTrip(t);
}

export async function confirmTripCash(id: string): Promise<Trip> {
  const t = await apiFetch<ApiTrip>(`/admin/trips/${id}/cash-confirm`, {
    method: "PUT",
  });
  return mapTrip(t);
}

export { estimateFareFromApi, estimateTripFromApi, findRule } from "./pricing";
