"use client";

import { arSD, enUS, frFR } from "@mui/x-data-grid/locales";
import { useLocaleContext } from "./LocaleProvider";
import type { Locale } from "./types";

const localeText: Record<
  Locale,
  | typeof enUS.components.MuiDataGrid.defaultProps.localeText
  | undefined
> = {
  en: enUS.components.MuiDataGrid.defaultProps.localeText,
  ar: arSD.components.MuiDataGrid.defaultProps.localeText,
  fr: frFR.components.MuiDataGrid.defaultProps.localeText,
};

export function useDataGridLocaleText() {
  const { locale } = useLocaleContext();
  return localeText[locale];
}
