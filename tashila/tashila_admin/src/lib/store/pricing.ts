"use client";

import { create } from "zustand";
import * as pricingApi from "@/lib/api/pricing";
import type { PricingRule } from "@/lib/types";

type PricingState = {
  rules: PricingRule[];
  loading: boolean;
  loaded: boolean;
  error: string | null;
  load: (force?: boolean) => Promise<void>;
  update: (rule: PricingRule) => Promise<PricingRule>;
};

export const usePricingStore = create<PricingState>((set, get) => ({
  rules: [],
  loading: false,
  loaded: false,
  error: null,
  load: async (force = false) => {
    if (!force && get().loaded) return;
    set({ loading: true, error: null });
    try {
      const rules = await pricingApi.listPricing();
      set({ rules, loading: false, loaded: true });
    } catch (e) {
      set({
        error: e instanceof Error ? e.message : "Failed to load pricing",
        loading: false,
      });
    }
  },
  update: async (rule) => {
    const updated = await pricingApi.updatePricing(rule);
    set({
      rules: get().rules.map((r) => (r.id === updated.id ? updated : r)),
    });
    return updated;
  },
}));
