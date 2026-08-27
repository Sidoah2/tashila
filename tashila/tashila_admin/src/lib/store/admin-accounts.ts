"use client";

import { create } from "zustand";
import * as adminAccountsApi from "@/lib/api/admin-accounts";
import { ApiError } from "@/lib/api/client";
import type { AdminAccount } from "@/lib/types";

type AdminAccountsState = {
  accounts: AdminAccount[];
  isBusy: boolean;
  error: string | null;
  load: () => Promise<void>;
  create: (data: {
    email: string;
    password: string;
    name: string;
    role: string;
  }) => Promise<boolean>;
  updateStatus: (id: string, status: "active" | "suspended") => Promise<boolean>;
};

export const useAdminAccountsStore = create<AdminAccountsState>((set, get) => ({
  accounts: [],
  isBusy: false,
  error: null,

  load: async () => {
    set({ isBusy: true, error: null });
    try {
      const accounts = await adminAccountsApi.listAdmins();
      set({ accounts, isBusy: false });
    } catch (e) {
      const error = e instanceof ApiError ? e.message : "Failed to load admin accounts";
      set({ error, isBusy: false });
    }
  },

  create: async (data) => {
    set({ isBusy: true, error: null });
    try {
      const newAccount = await adminAccountsApi.createAdmin(data);
      set((s) => ({ accounts: [...s.accounts, newAccount], isBusy: false }));
      return true;
    } catch (e) {
      const error = e instanceof ApiError ? e.message : "Failed to create admin";
      set({ error, isBusy: false });
      return false;
    }
  },

  updateStatus: async (id, status) => {
    set({ isBusy: true, error: null });
    try {
      const updated = await adminAccountsApi.updateAdminStatus(id, status);
      set((s) => ({
        accounts: s.accounts.map((a) => (a.id === id ? updated : a)),
        isBusy: false,
      }));
      return true;
    } catch (e) {
      const error = e instanceof ApiError ? e.message : "Failed to update admin status";
      set({ error, isBusy: false });
      return false;
    }
  },
}));
