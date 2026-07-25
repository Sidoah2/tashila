import type { Messages } from "./messages";
import { messagesByLocale } from "./messages";
import { DEFAULT_LOCALE, type Locale } from "./types";

export type TranslateParams = Record<string, string | number>;

function lookup(messages: Messages, key: string): string | undefined {
  const segments = key.split(".");
  let current: unknown = messages;
  for (const segment of segments) {
    if (current && typeof current === "object" && segment in (current as Record<string, unknown>)) {
      current = (current as Record<string, unknown>)[segment];
    } else {
      return undefined;
    }
  }
  return typeof current === "string" ? current : undefined;
}

function interpolate(template: string, params?: TranslateParams): string {
  if (!params) return template;
  return template.replace(/\{(\w+)\}/g, (_, name: string) => {
    const value = params[name];
    return value === undefined || value === null ? `{${name}}` : String(value);
  });
}

export function translateWithLocale(
  locale: Locale,
  key: string,
  params?: TranslateParams
): string {
  const direct = lookup(messagesByLocale[locale], key);
  if (direct !== undefined) return interpolate(direct, params);
  if (locale !== DEFAULT_LOCALE) {
    const fallback = lookup(messagesByLocale[DEFAULT_LOCALE], key);
    if (fallback !== undefined) return interpolate(fallback, params);
  }
  return key;
}
