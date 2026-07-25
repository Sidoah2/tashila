import type { Metadata } from "next";
import { Tajawal } from "next/font/google";
import ThemeProviders from "@/theme/ThemeProviders";
import { ToastProvider } from "@/components/ToastProvider";
import "./globals.css";

const tajawal = Tajawal({
  subsets: ["latin", "arabic"],
  weight: ["400", "500", "700", "800"],
  variable: "--font-tajawal",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Tashila Admin",
  description: "Admin dashboard for Tashila",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={tajawal.variable} suppressHydrationWarning>
      <body suppressHydrationWarning>
        <ThemeProviders>
          <ToastProvider>{children}</ToastProvider>
        </ThemeProviders>
      </body>
    </html>
  );
}
