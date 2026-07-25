"use client";

import { useLocaleContext } from "./LocaleProvider";
import type { Locale } from "./types";
import type { TranslateParams } from "./translate";

export type UseTranslationResult = {
  t: (key: string, params?: TranslateParams) => string;
  locale: Locale;
  setLocale: (next: Locale) => void;
};

export function useTranslation(): UseTranslationResult {
  const { t, locale, setLocale } = useLocaleContext();
  return { t, locale, setLocale };
}
