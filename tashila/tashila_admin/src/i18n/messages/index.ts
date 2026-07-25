import en from "./en.json";
import ar from "./ar.json";
import fr from "./fr.json";
import type { Locale } from "../types";

export type Messages = typeof en;

export const messagesByLocale: Record<Locale, Messages> = {
  en: en as Messages,
  ar: ar as Messages,
  fr: fr as Messages,
};
