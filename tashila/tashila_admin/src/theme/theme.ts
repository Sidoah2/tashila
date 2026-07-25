"use client";

import { createTheme, type Theme } from "@mui/material/styles";
import { brand } from "./colors";

export type ThemeDirection = "ltr" | "rtl";

export default function buildTheme(direction: ThemeDirection = "ltr"): Theme {
  return createTheme({
    cssVariables: true,
    direction,
    palette: {
      mode: "light",
      primary: { main: brand.orange, contrastText: "#FFFFFF" },
      success: { main: brand.success },
      error: { main: brand.danger },
      warning: { main: brand.warning },
      background: { default: brand.bg, paper: brand.card },
      text: { primary: brand.textPrimary, secondary: brand.textSecondary },
      divider: brand.border,
    },
    shape: { borderRadius: 14 },
    typography: {
      fontFamily: 'var(--font-tajawal), "Helvetica Neue", Arial, sans-serif',
      h1: { fontWeight: 800 },
      h2: { fontWeight: 800 },
      h3: { fontWeight: 800 },
      h4: { fontWeight: 800, fontSize: "1.6rem" },
      h5: { fontWeight: 700, fontSize: "1.25rem" },
      h6: { fontWeight: 700, fontSize: "1.05rem" },
      button: { fontWeight: 700, textTransform: "none" },
    },
    components: {
      MuiAppBar: {
        defaultProps: { color: "transparent", elevation: 0 },
        styleOverrides: {
          root: {
            backgroundColor: brand.card,
            borderBottom: `1px solid ${brand.border}`,
            color: brand.textPrimary,
          },
        },
      },
      MuiDrawer: {
        styleOverrides: {
          paper: {
            backgroundColor: brand.card,
            borderRight: `1px solid ${brand.border}`,
          },
        },
      },
      MuiCard: {
        defaultProps: { elevation: 0 },
        styleOverrides: {
          root: {
            borderRadius: 18,
            border: `1px solid ${brand.border}`,
            backgroundColor: brand.card,
          },
        },
      },
      MuiPaper: {
        defaultProps: { elevation: 0 },
        styleOverrides: {
          rounded: { borderRadius: 14 },
        },
      },
      MuiButton: {
        defaultProps: { disableElevation: true, variant: "contained" },
        styleOverrides: {
          root: { borderRadius: 12, paddingInline: 18, minHeight: 44 },
          sizeLarge: { minHeight: 52, fontSize: "1rem" },
        },
      },
      MuiOutlinedInput: {
        styleOverrides: {
          root: {
            borderRadius: 12,
            backgroundColor: brand.card,
          },
        },
      },
      MuiTextField: {
        defaultProps: { fullWidth: true, size: "small" },
      },
      MuiChip: {
        styleOverrides: { root: { borderRadius: 999, fontWeight: 600 } },
      },
      MuiTableHead: {
        styleOverrides: {
          root: { backgroundColor: brand.bg },
        },
      },
      MuiListItemButton: {
        styleOverrides: {
          root: {
            borderRadius: 10,
            margin: "2px 8px",
            "&.Mui-selected": {
              backgroundColor: `${brand.orange}1A`,
              color: brand.orange,
              "& .MuiListItemIcon-root": { color: brand.orange },
              "&:hover": { backgroundColor: `${brand.orange}26` },
            },
          },
        },
      },
    },
  });
}
