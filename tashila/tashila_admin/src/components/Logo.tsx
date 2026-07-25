"use client";

import Box from "@mui/material/Box";
import Typography from "@mui/material/Typography";
import Image from "next/image";
import { brand } from "@/theme/colors";

export default function Logo({ compact = false }: { compact?: boolean }) {
  return (
    <Box
      sx={{ display: "flex", alignItems: "center", gap: 1.25, minHeight: 40 }}
    >
      <Box
        sx={{
          width: 36,
          height: 36,
          borderRadius: 2,
          overflow: "hidden",
          backgroundColor: "#fff",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          boxShadow: "0 4px 12px rgba(245,138,12,0.35)",
        }}
      >
        <Image
          src="/arabic_logo.jpeg"
          alt="Tashila"
          width={36}
          height={36}
          style={{ objectFit: "cover" }}
          priority
        />
      </Box>
      {!compact && (
        <Box sx={{ lineHeight: 1.1 }}>
          <Typography
            sx={{
              fontWeight: 800,
              fontSize: "1.05rem",
              letterSpacing: 0.2,
            }}
          >
            Tashila
          </Typography>
          <Typography
            variant="caption"
            sx={{ color: brand.textSecondary, fontWeight: 600 }}
          >
            Admin Console
          </Typography>
        </Box>
      )}
    </Box>
  );
}
