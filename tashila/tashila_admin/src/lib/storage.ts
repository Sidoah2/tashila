const PREFIX = "tashila_admin_";

/** Browser persistence for admin auth session (supports secure cookies and storage fallback). */
export const STORAGE_KEYS = {
  session: `${PREFIX}session`,
} as const;

function getCookie(name: string): string | null {
  if (typeof document === "undefined") return null;
  const match = document.cookie.match(new RegExp("(^|;\\s*)(" + name + ")=([^;]*)"));
  return match ? decodeURIComponent(match[3]) : null;
}

function setCookie(name: string, value: string, days: number = 7): void {
  if (typeof document === "undefined") return;
  const expires = new Date(Date.now() + days * 864e5).toUTCString();
  const secure = typeof window !== "undefined" && window.location.protocol === "https:" ? "; Secure" : "";
  document.cookie = `${name}=${encodeURIComponent(value)}; expires=${expires}; path=/; SameSite=Strict${secure}`;
}

function deleteCookie(name: string): void {
  if (typeof document === "undefined") return;
  document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/; SameSite=Strict`;
}

export function readJson<T>(key: string, fallback: T): T {
  if (typeof window === "undefined") return fallback;
  try {
    const raw = window.localStorage.getItem(key);
    if (raw) return JSON.parse(raw) as T;
    if (key === STORAGE_KEYS.session) {
      const cookieVal = getCookie("tashila_admin_session");
      if (cookieVal) return JSON.parse(cookieVal) as T;
    }
    return fallback;
  } catch {
    return fallback;
  }
}

export function writeJson<T>(key: string, value: T): void {
  if (typeof window === "undefined") return;
  try {
    const serialized = JSON.stringify(value);
    window.localStorage.setItem(key, serialized);
    if (key === STORAGE_KEYS.session) {
      setCookie("tashila_admin_session", serialized);
      const token = (value as { token?: string; accessToken?: string })?.token || (value as { accessToken?: string })?.accessToken;
      if (token) setCookie("tashila_admin_token", token);
    }
  } catch {
    // ignore quota errors
  }
}

export function removeKey(key: string): void {
  if (typeof window === "undefined") return;
  window.localStorage.removeItem(key);
  if (key === STORAGE_KEYS.session) {
    deleteCookie("tashila_admin_session");
    deleteCookie("tashila_admin_token");
  }
}
