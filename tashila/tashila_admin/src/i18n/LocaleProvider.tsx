"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { CacheProvider } from "@emotion/react";
import createCache, {
  type EmotionCache,
  type StylisPlugin,
} from "@emotion/cache";
import { ThemeProvider } from "@mui/material/styles";
import CssBaseline from "@mui/material/CssBaseline";
import { prefixer } from "stylis";
import rtlPlugin from "stylis-plugin-rtl";
import buildTheme from "@/theme/theme";
import { translateWithLocale, type TranslateParams } from "./translate";
import {
  DEFAULT_LOCALE,
  isLocale,
  isRtl,
  type Locale,
} from "./types";

const STORAGE_KEY = "tashila_admin_locale";

type LocaleContextValue = {
  locale: Locale;
  setLocale: (next: Locale) => void;
  t: (key: string, params?: TranslateParams) => string;
  hydrated: boolean;
};

const LocaleContext = createContext<LocaleContextValue | null>(null);

export function useLocaleContext(): LocaleContextValue {
  const ctx = useContext(LocaleContext);
  if (!ctx) {
    throw new Error("useLocaleContext must be used within LocaleProvider");
  }
  return ctx;
}

function readInitialLocale(): Locale {
  if (typeof window === "undefined") return DEFAULT_LOCALE;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (isLocale(raw)) return raw;
  } catch {
    // ignore
  }
  return DEFAULT_LOCALE;
}

function makeRtlCache(): EmotionCache {
  return createCache({
    key: "mui-rtl",
    stylisPlugins: [prefixer as StylisPlugin, rtlPlugin as StylisPlugin],
    prepend: true,
  });
}

export default function LocaleProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>(DEFAULT_LOCALE);
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    const initial = readInitialLocale();
    setLocaleState(initial);
    setHydrated(true);
  }, []);

  useEffect(() => {
    if (typeof document === "undefined") return;
    document.documentElement.lang = locale;
    document.documentElement.dir = isRtl(locale) ? "rtl" : "ltr";
  }, [locale]);

  const setLocale = useCallback((next: Locale) => {
    setLocaleState(next);
    try {
      window.localStorage.setItem(STORAGE_KEY, next);
    } catch {
      // ignore
    }
  }, []);

  const t = useCallback(
    (key: string, params?: TranslateParams) =>
      translateWithLocale(locale, key, params),
    [locale]
  );

  const rtlCache = useMemo(
    () => (isRtl(locale) ? makeRtlCache() : null),
    [locale]
  );
  const theme = useMemo(
    () => buildTheme(isRtl(locale) ? "rtl" : "ltr"),
    [locale]
  );

  const value = useMemo<LocaleContextValue>(
    () => ({ locale, setLocale, t, hydrated }),
    [locale, setLocale, t, hydrated]
  );

  const themed = (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      {children}
    </ThemeProvider>
  );

  return (
    <LocaleContext.Provider value={value}>
      {rtlCache ? <CacheProvider value={rtlCache}>{themed}</CacheProvider> : themed}
    </LocaleContext.Provider>
  );
}
