import { STORAGE_KEYS, removeKey, writeJson } from "../storage";
import type { AdminSession } from "../types";

const BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? "/api";

function networkErrorMessage(error: unknown): string {
  if (error instanceof TypeError && error.message === "Failed to fetch") {
    return "Cannot reach the Tashila API. Check your connection or API URL configuration.";
  }
  return error instanceof Error ? error.message : "Request failed.";
}

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

function getStoredSession(): AdminSession | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEYS.session);
    if (!raw) return null;
    return JSON.parse(raw) as AdminSession;
  } catch {
    return null;
  }
}

function clearSessionAndRedirect() {
  if (typeof window === "undefined") return;
  removeKey(STORAGE_KEYS.session);
  if (!window.location.pathname.startsWith("/login")) {
    window.location.href = "/login";
  }
}

async function refreshAdminToken(session: AdminSession): Promise<string | null> {
  try {
    const res = await fetch(`${BASE_URL}/auth/admin/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refreshToken: session.refreshToken }),
    });
    if (!res.ok) return null;
    const data = (await res.json()) as { accessToken: string };
    const updated: AdminSession = {
      ...session,
      accessToken: data.accessToken,
    };
    writeJson(STORAGE_KEYS.session, updated);
    return data.accessToken;
  } catch {
    return null;
  }
}

interface ApiFetchOptions extends Omit<RequestInit, "headers"> {
  headers?: Record<string, string>;
  skipAuth?: boolean;
  retried?: boolean;
}

export async function apiFetch<T = unknown>(
  path: string,
  options: ApiFetchOptions = {},
): Promise<T> {
  const { skipAuth = false, headers: extraHeaders = {}, retried = false, ...rest } =
    options;

  const isFormData =
    typeof FormData !== "undefined" && rest.body instanceof FormData;

  const headers: Record<string, string> = {
    ...(isFormData ? {} : { "Content-Type": "application/json" }),
    ...extraHeaders,
  };

  const session = getStoredSession();
  if (!skipAuth && session?.accessToken) {
    headers["Authorization"] = `Bearer ${session.accessToken}`;
  }

  const res = await fetch(`${BASE_URL}${path}`, { ...rest, headers }).catch(
    (error) => {
      throw new ApiError(0, networkErrorMessage(error));
    },
  );

  if (res.status === 401 && !skipAuth && !retried && session?.refreshToken) {
    const newToken = await refreshAdminToken(session);
    if (newToken) {
      return apiFetch<T>(path, {
        ...options,
        retried: true,
        headers: { ...extraHeaders, Authorization: `Bearer ${newToken}` },
      });
    }
    clearSessionAndRedirect();
    throw new ApiError(401, "Session expired");
  }

  if (res.status === 401 && !skipAuth) {
    clearSessionAndRedirect();
    throw new ApiError(401, "Unauthorized");
  }

  if (!res.ok) {
    let message = `Request failed with status ${res.status}`;
    try {
      const body = await res.json();
      if (typeof body?.detail === "string") message = body.detail;
      else if (typeof body?.message === "string") message = body.message;
    } catch {
      // ignore parse errors
    }
    throw new ApiError(res.status, message);
  }

  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}
