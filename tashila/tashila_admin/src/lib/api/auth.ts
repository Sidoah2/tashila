import { STORAGE_KEYS, readJson, removeKey, writeJson } from "../storage";
import type { AdminSession } from "../types";
import { apiFetch } from "./client";

interface AdminLoginResponse {
  accessToken: string;
  refreshToken: string;
  admin: {
    id: string;
    email: string;
    name: string;
    role: string;
  };
}

export async function login(
  email: string,
  password: string,
): Promise<AdminSession> {
  const data = await apiFetch<AdminLoginResponse>("/auth/admin/login", {
    method: "POST",
    body: JSON.stringify({ email, password }),
    skipAuth: true,
  });

  const session: AdminSession = {
    email: data.admin.email,
    name: data.admin.name,
    role: data.admin.role,
    accessToken: data.accessToken,
    refreshToken: data.refreshToken,
    loggedInAt: new Date().toISOString(),
  };
  writeJson<AdminSession>(STORAGE_KEYS.session, session);
  return session;
}

export async function logout(): Promise<void> {
  try {
    await apiFetch("/auth/admin/logout", { method: "POST" });
  } catch {
    // best-effort — clear local session regardless
  } finally {
    removeKey(STORAGE_KEYS.session);
  }
}

export function getSession(): AdminSession | null {
  return readJson<AdminSession | null>(STORAGE_KEYS.session, null);
}
