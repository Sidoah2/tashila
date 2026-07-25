"use client";

import { create } from "zustand";
import * as usersApi from "@/lib/api/users";
import type { User, UserStatus } from "@/lib/types";

type UsersState = {
  users: User[];
  loading: boolean;
  loaded: boolean;
  error: string | null;
  load: (force?: boolean) => Promise<void>;
  setStatus: (id: string, status: UserStatus) => Promise<User>;
};

export const useUsersStore = create<UsersState>((set, get) => ({
  users: [],
  loading: false,
  loaded: false,
  error: null,
  load: async (force = false) => {
    if (!force && get().loaded) return;
    set({ loading: true, error: null });
    try {
      const users = await usersApi.listUsers();
      set({ users, loading: false, loaded: true });
    } catch (e) {
      set({
        error: e instanceof Error ? e.message : "Failed to load users",
        loading: false,
      });
    }
  },
  setStatus: async (id, status) => {
    const updated = await usersApi.setUserStatus(id, status);
    set({
      users: get().users.map((u) => (u.id === updated.id ? updated : u)),
    });
    return updated;
  },
}));
