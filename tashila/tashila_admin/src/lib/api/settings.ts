import { apiFetch } from "./client";

export type PlatformSettings = {
  commissionRate: number;
  serviceAreaCenter: { lat: number; lng: number };
  serviceAreaRadiusKm: number;
};

export async function getPlatformSettings(): Promise<PlatformSettings> {
  return apiFetch<PlatformSettings>("/admin/settings");
}

export async function updatePlatformSettings(
  patch: Partial<PlatformSettings>,
): Promise<PlatformSettings> {
  return apiFetch<PlatformSettings>("/admin/settings", {
    method: "PUT",
    body: JSON.stringify(patch),
  });
}
