import type { User, UserStatus } from "../types";
import { apiFetch } from "./client";

interface ApiUser {
  id?: string;
  _id?: string;
  firstName?: string;
  lastName?: string;
  name?: string;
  phone: string;
  status: string;
  createdAt: string;
  tripCount?: number;
  totalTrips?: number;
  averageRating?: number;
  avatarUrl?: string | null;
  completedTripsCount?: number;
  cancelledTripsCount?: number;
  reviews?: Array<{
    tripId: string;
    rating: number;
    comment?: string | null;
    driverName?: string | null;
    createdAt?: string;
  }>;
}

interface PaginatedUsers {
  items: ApiUser[];
  total: number;
  page: number;
  limit: number;
}

function mapUser(u: ApiUser): User {
  const fullName = u.name ?? `${u.firstName ?? ""} ${u.lastName ?? ""}`.trim();
  const parts = fullName.split(" ");
  return {
    id: u.id ?? u._id ?? "",
    firstName: u.firstName ?? parts[0] ?? "",
    lastName: u.lastName ?? parts.slice(1).join(" ") ?? "",
    phone: u.phone,
    status: u.status as UserStatus,
    createdAt: u.createdAt,
    totalTrips: u.tripCount ?? u.totalTrips ?? 0,
    averageRating: u.averageRating ?? 0,
    avatarUrl: u.avatarUrl ?? null,
    completedTripsCount: u.completedTripsCount ?? 0,
    cancelledTripsCount: u.cancelledTripsCount ?? 0,
    driverReviews: (u.reviews ?? []).map((r) => ({
      id: r.tripId,
      rating: r.rating,
      comment: r.comment ?? "",
      driverName: r.driverName ?? "Driver",
      tripId: r.tripId,
      date: r.createdAt ?? new Date().toISOString(),
    })),
  };
}

export async function listUsers(): Promise<User[]> {
  const data = await apiFetch<PaginatedUsers>(
    "/admin/users?limit=100&page=1",
  );
  return data.items.map(mapUser);
}

export async function getUser(id: string): Promise<User | null> {
  try {
    const u = await apiFetch<ApiUser>(`/admin/users/${id}`);
    return mapUser(u);
  } catch {
    return null;
  }
}

export async function getUserReviews(id: string): Promise<User["driverReviews"]> {
  const reviews = await apiFetch<
    Array<{
      tripId: string;
      rating: number;
      comment?: string | null;
      driverName?: string | null;
      createdAt?: string;
    }>
  >(`/admin/users/${id}/reviews`);
  return reviews.map((r) => ({
    id: r.tripId,
    rating: r.rating,
    comment: r.comment ?? "",
    driverName: r.driverName ?? "Driver",
    tripId: r.tripId,
    date: r.createdAt ?? new Date().toISOString(),
  }));
}

export async function setUserStatus(
  id: string,
  status: UserStatus,
): Promise<User> {
  const u = await apiFetch<ApiUser>(`/admin/users/${id}/status`, {
    method: "PUT",
    body: JSON.stringify({ status }),
  });
  return mapUser(u);
}
