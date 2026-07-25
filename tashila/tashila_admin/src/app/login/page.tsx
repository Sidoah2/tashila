"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Box from "@mui/material/Box";
import Button from "@mui/material/Button";
import Card from "@mui/material/Card";
import CardContent from "@mui/material/CardContent";
import Stack from "@mui/material/Stack";
import TextField from "@mui/material/TextField";
import Typography from "@mui/material/Typography";
import Alert from "@mui/material/Alert";
import InputAdornment from "@mui/material/InputAdornment";
import IconButton from "@mui/material/IconButton";
import VisibilityRoundedIcon from "@mui/icons-material/VisibilityRounded";
import VisibilityOffRoundedIcon from "@mui/icons-material/VisibilityOffRounded";
import EmailRoundedIcon from "@mui/icons-material/EmailRounded";
import LockRoundedIcon from "@mui/icons-material/LockRounded";
import { useAuthStore } from "@/lib/store/auth";
import Logo from "@/components/Logo";
import LanguageMenu from "@/components/LanguageMenu";
import { brand } from "@/theme/colors";
import { useTranslation } from "@/i18n/useTranslation";

export default function LoginPage() {
  const router = useRouter();
  const { t } = useTranslation();
  const session = useAuthStore((s) => s.session);
  const hydrate = useAuthStore((s) => s.hydrate);
  const hydrated = useAuthStore((s) => s.hydrated);
  const isBusy = useAuthStore((s) => s.isBusy);
  const error = useAuthStore((s) => s.error);
  const login = useAuthStore((s) => s.login);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);

  useEffect(() => {
    if (!hydrated) hydrate();
  }, [hydrate, hydrated]);

  useEffect(() => {
    if (hydrated && session) router.replace("/");
  }, [hydrated, session, router]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const ok = await login(email, password);
    if (ok) router.replace("/");
  };

  return (
    <Box
      sx={{
        minHeight: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        p: 2,
        background: `radial-gradient(1200px 600px at 0% 0%, ${brand.orange}1A 0%, transparent 60%), radial-gradient(900px 500px at 100% 100%, ${brand.orange}14 0%, transparent 60%), ${brand.bg}`,
      }}
    >
      <Card
        sx={{
          width: "100%",
          maxWidth: 440,
          borderRadius: 4,
          boxShadow: "0 24px 48px -24px rgba(0,0,0,0.18)",
        }}
      >
        <CardContent sx={{ p: { xs: 3, sm: 4 } }}>
          <Stack spacing={3}>
            <Box sx={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
              <Logo />
              <LanguageMenu size="small" />
            </Box>
            <Box>
              <Typography variant="h4" sx={{ fontWeight: 800, mb: 0.5 }}>
                {t("auth.welcome")}
              </Typography>
              <Typography color="text.secondary">
                {t("auth.subtitle")}
              </Typography>
            </Box>

            <form onSubmit={handleSubmit} noValidate>
              <Stack spacing={2}>
                <TextField
                  label={t("auth.email")}
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  autoComplete="email"
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <EmailRoundedIcon
                          fontSize="small"
                          sx={{ color: brand.textSecondary }}
                        />
                      </InputAdornment>
                    ),
                  }}
                />
                <TextField
                  label={t("auth.password")}
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  autoComplete="current-password"
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <LockRoundedIcon
                          fontSize="small"
                          sx={{ color: brand.textSecondary }}
                        />
                      </InputAdornment>
                    ),
                    endAdornment: (
                      <InputAdornment position="end">
                        <IconButton
                          size="small"
                          onClick={() => setShowPassword((v) => !v)}
                          aria-label={t("auth.toggle_password")}
                        >
                          {showPassword ? (
                            <VisibilityOffRoundedIcon fontSize="small" />
                          ) : (
                            <VisibilityRoundedIcon fontSize="small" />
                          )}
                        </IconButton>
                      </InputAdornment>
                    ),
                  }}
                />
                {error && <Alert severity="error">{error}</Alert>}
                <Button
                  type="submit"
                  size="large"
                  disabled={isBusy}
                  sx={{ mt: 0.5 }}
                >
                  {isBusy ? t("auth.signing_in") : t("auth.sign_in")}
                </Button>
              </Stack>
            </form>
          </Stack>
        </CardContent>
      </Card>
    </Box>
  );
}
