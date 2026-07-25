"use client";

import EmotionRegistry from "./EmotionRegistry";
import LocaleProvider from "@/i18n/LocaleProvider";

export default function ThemeProviders({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <EmotionRegistry options={{ key: "mui" }}>
      <LocaleProvider>{children}</LocaleProvider>
    </EmotionRegistry>
  );
}
