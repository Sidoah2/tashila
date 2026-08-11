import type { PricingRule, TruckType } from "../types";
import { apiFetch } from "./client";

interface ApiPricingRule {
  id?: string;
  _id?: string;
  truckType: string;
  baseFareDzd?: number;
  pricePerKmDzd?: number;
  label?: string;
  baseFare?: number;
  perKm?: number;
}

function mapRule(r: ApiPricingRule): PricingRule {
  const baseFare = r.baseFareDzd ?? r.baseFare ?? 0;
  const perKm = r.pricePerKmDzd ?? r.perKm ?? 0;
  return {
    id: r.id ?? r._id ?? r.truckType,
    truckType: r.truckType as TruckType,
    baseFare,
    perKm,
    perMinute: 0,
    minFare: baseFare,
    surgeMultiplier: 1,
    active: true,
  };
}

export async function listPricing(): Promise<PricingRule[]> {
  const data = await apiFetch<ApiPricingRule[]>("/pricing");
  return data.map(mapRule);
}

export async function updatePricing(rule: PricingRule): Promise<PricingRule> {
  const r = await apiFetch<ApiPricingRule>(
    `/admin/pricing/${rule.truckType}`,
    {
      method: "PUT",
      body: JSON.stringify({
        baseFareDzd: rule.baseFare,
        pricePerKmDzd: rule.perKm,
        label: rule.truckType.replace("_", " "),
      }),
    },
  );
  return mapRule(r);
}

/** Estimate fare via API when possible. */
export async function estimateFareFromApi(
  pickup: { lat: number; lng: number; address?: string },
  dropoff: { lat: number; lng: number; address?: string },
  truckType: TruckType,
  bypassServiceArea = false,
): Promise<number> {
  const url = bypassServiceArea ? "/trips/estimate?bypass_service_area=true" : "/trips/estimate";
  const data = await apiFetch<{ fare: number }>(url, {
    method: "POST",
    body: JSON.stringify({ pickup, dropoff, truckType }),
  });
  return data.fare;
}

/** Tashila dynamic pricing (DZD): base 5 km, distance + time surcharges, ceil to 100. */
export function tashilaDynamicFare(
  distanceKm: number,
  durationMinutes: number,
): number {
  const raw =
    1000 +
    Math.max(0, distanceKm - 5) * 100 +
    Math.max(0, durationMinutes - 60) * 20;
  return Math.ceil(raw / 100) * 100;
}

/** fare = max(minFare, round((baseFare + perKm×distance + perMinute×duration) × surge)) */
export function estimateFare(
  rule: PricingRule | undefined,
  distanceKm: number,
  estimatedMinutes = 0,
): number {
  if (!rule || !rule.active) return 0;
  const base =
    rule.baseFare +
    rule.perKm * distanceKm +
    rule.perMinute * estimatedMinutes;
  const surged = base * (rule.surgeMultiplier || 1);
  return Math.max(rule.minFare, Math.round(surged));
}

export function findRule(
  rules: PricingRule[],
  truckType: TruckType,
): PricingRule | undefined {
  return rules.find((r) => r.truckType === truckType);
}
