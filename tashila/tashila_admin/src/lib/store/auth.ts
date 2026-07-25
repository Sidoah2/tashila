"use client";

import { create } from "zustand";
import * as authApi from "@/lib/api/auth";
import { ApiError } from "@/lib/api/client";
import type { AdminSession } from "@/lib/types";

type AuthState = {
  session: AdminSession | null;
  hydrated: boolean;
  isBusy: boolean;
  error: string | null;
  hydrate: () => void;
  login: (email: string, password: string) => Promise<boolean>;
  logout: () => Promise<void>;
};

export const useAuthStore = create<AuthState>((set) => ({
  session: null,
  hydrated: false,
  isBusy: false,
  error: null,
  hydrate: () => {
    const session = authApi.getSession();
    set({ session, hydrated: true });
  },
  login: async (email, password) => {
    set({ isBusy: true, error: null });
    try {
      const session = await authApi.login(email, password);
      set({ session, isBusy: false });
      return true;
    } catch (e) {
      const error =
        e instanceof ApiError
          ? e.message
          : e instanceof Error
            ? e.message
            : "Login failed.";
      set({ error, isBusy: false });
      return false;
    }
  },
  logout: async () => {
    await authApi.logout();
    set({ session: null });
  },
}));
