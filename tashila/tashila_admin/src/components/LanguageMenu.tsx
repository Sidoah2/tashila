"use client";

import { useState } from "react";
import IconButton from "@mui/material/IconButton";
import Menu from "@mui/material/Menu";
import MenuItem from "@mui/material/MenuItem";
import ListItemIcon from "@mui/material/ListItemIcon";
import ListItemText from "@mui/material/ListItemText";
import Tooltip from "@mui/material/Tooltip";
import LanguageRoundedIcon from "@mui/icons-material/LanguageRounded";
import CheckRoundedIcon from "@mui/icons-material/CheckRounded";
import { useTranslation } from "@/i18n/useTranslation";
import { LOCALES, LOCALE_LABELS, type Locale } from "@/i18n/types";

type Props = {
  size?: "small" | "medium";
};

export default function LanguageMenu({ size = "medium" }: Props) {
  const { locale, setLocale, t } = useTranslation();
  const [anchor, setAnchor] = useState<null | HTMLElement>(null);

  const handleSelect = (next: Locale) => {
    setLocale(next);
    setAnchor(null);
  };

  return (
    <>
      <Tooltip title={t("lang.label")}>
        <IconButton
          size={size}
          onClick={(e) => setAnchor(e.currentTarget)}
          aria-label={t("lang.label")}
        >
          <LanguageRoundedIcon fontSize={size === "small" ? "small" : "medium"} />
        </IconButton>
      </Tooltip>
      <Menu
        anchorEl={anchor}
        open={Boolean(anchor)}
        onClose={() => setAnchor(null)}
        anchorOrigin={{ vertical: "bottom", horizontal: "right" }}
        transformOrigin={{ vertical: "top", horizontal: "right" }}
      >
        {LOCALES.map((code) => (
          <MenuItem
            key={code}
            selected={locale === code}
            onClick={() => handleSelect(code)}
          >
            <ListItemIcon>
              {locale === code ? (
                <CheckRoundedIcon fontSize="small" color="primary" />
              ) : null}
            </ListItemIcon>
            <ListItemText
              primary={LOCALE_LABELS[code]}
              primaryTypographyProps={{
                fontWeight: locale === code ? 700 : 500,
              }}
            />
          </MenuItem>
        ))}
      </Menu>
    </>
  );
}
