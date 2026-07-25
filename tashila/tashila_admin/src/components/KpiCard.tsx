"use client";

import Box from "@mui/material/Box";
import Card from "@mui/material/Card";
import CardContent from "@mui/material/CardContent";
import Typography from "@mui/material/Typography";
import { brand } from "@/theme/colors";

type Props = {
  label: string;
  value: string;
  hint?: string;
  icon: React.ReactNode;
  accentColor?: string;
};

export default function KpiCard({
  label,
  value,
  hint,
  icon,
  accentColor = brand.orange,
}: Props) {
  return (
    <Card sx={{ height: "100%" }}>
      <CardContent
        sx={{ display: "flex", gap: 2, alignItems: "flex-start", py: 2.5 }}
      >
        <Box
          sx={{
            width: 48,
            height: 48,
            borderRadius: 2,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            color: accentColor,
            backgroundColor: `${accentColor}1F`,
          }}
        >
          {icon}
        </Box>
        <Box sx={{ flex: 1, minWidth: 0 }}>
          <Typography
            variant="caption"
            sx={{
              color: brand.textSecondary,
              fontWeight: 700,
              letterSpacing: 0.4,
              textTransform: "uppercase",
            }}
          >
            {label}
          </Typography>
          <Typography
            variant="h4"
            sx={{ fontWeight: 800, lineHeight: 1.2, mt: 0.25 }}
          >
            {value}
          </Typography>
          {hint && (
            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
              {hint}
            </Typography>
          )}
        </Box>
      </CardContent>
    </Card>
  );
}
