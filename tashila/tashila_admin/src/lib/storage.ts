const PREFIX = "tashila_admin_";

/** Browser persistence for admin auth session only (all domain data comes from the API). */
export const STORAGE_KEYS = {
  session: `${PREFIX}session`,
} as const;

export function readJson<T>(key: string, fallback: T): T {
  if (typeof window === "undefined") return fallback;
  try {
    const raw = window.localStorage.getItem(key);
    if (!raw) return fallback;
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

export function writeJson<T>(key: string, value: T): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // ignore quota errors
  }
}

export function removeKey(key: string): void {
  if (typeof window === "undefined") return;
  window.localStorage.removeItem(key);
}
