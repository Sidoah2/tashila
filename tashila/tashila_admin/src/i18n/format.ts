"use client";

import { useMemo } from "react";
import { useLocaleContext } from "./LocaleProvider";
import type { Locale } from "./types";

const intlLocale: Record<Locale, string> = {
  en: "en-DZ",
  ar: "ar-DZ",
  fr: "fr-DZ",
};

export function localeToIntl(locale: Locale): string {
  return intlLocale[locale];
}

export function useFormatDzd() {
  const { locale } = useLocaleContext();
  return useMemo(() => {
    const fmt = new Intl.NumberFormat(intlLocale[locale], {
      style: "currency",
      currency: "DZD",
      maximumFractionDigits: 0,
    });
    return (value: number): string => {
      if (!Number.isFinite(value)) return "—";
      return fmt.format(value);
    };
  }, [locale]);
}

export function useFormatNumber() {
  const { locale } = useLocaleContext();
  return useMemo(() => {
    const fmt = new Intl.NumberFormat(intlLocale[locale]);
    return (value: number): string => {
      if (!Number.isFinite(value)) return "—";
      return fmt.format(value);
    };
  }, [locale]);
}

export function useFormatDate() {
  const { locale } = useLocaleContext();
  return useMemo(() => {
    const fmt = new Intl.DateTimeFormat(intlLocale[locale], {
      day: "2-digit",
      month: "short",
      year: "numeric",
    });
    return (value: string | number | Date): string => {
      const d = new Date(value);
      if (Number.isNaN(d.getTime())) return "—";
      return fmt.format(d);
    };
  }, [locale]);
}

export function useFormatDateTime() {
  const { locale } = useLocaleContext();
  return useMemo(() => {
    const fmt = new Intl.DateTimeFormat(intlLocale[locale], {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
    return (value: string | number | Date): string => {
      const d = new Date(value);
      if (Number.isNaN(d.getTime())) return "—";
      return fmt.format(d);
    };
  }, [locale]);
}
