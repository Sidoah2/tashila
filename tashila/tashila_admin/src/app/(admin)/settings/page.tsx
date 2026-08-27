"use client";

import { useState } from "react";
import Box from "@mui/material/Box";
import Button from "@mui/material/Button";
import Card from "@mui/material/Card";
import CardContent from "@mui/material/CardContent";
import Divider from "@mui/material/Divider";
import Stack from "@mui/material/Stack";
import TextField from "@mui/material/TextField";
import Typography from "@mui/material/Typography";
import ManageAccountsRoundedIcon from "@mui/icons-material/ManageAccountsRounded";
import { useAuthStore } from "@/lib/store/auth";
import { updateMyProfile } from "@/lib/api/admin-accounts";
import { STORAGE_KEYS, writeJson, readJson } from "@/lib/storage";
import { useToast } from "@/components/ToastProvider";
import { brand } from "@/theme/colors";
import type { AdminSession } from "@/lib/types";

export default function SettingsPage() {
  const session = useAuthStore((s) => s.session);
  const showToast = useToast();

  const [nameForm, setNameForm] = useState({ name: session?.name ?? "" });
  const [emailForm, setEmailForm] = useState({ email: session?.email ?? "" });
  const [passwordForm, setPasswordForm] = useState({
    password: "",
    confirm: "",
  });
  const [saving, setSaving] = useState<"name" | "email" | "password" | null>(null);

  const handleSaveName = async () => {
    if (!nameForm.name.trim()) return;
    setSaving("name");
    try {
      const updated = await updateMyProfile({ name: nameForm.name.trim() });
      _patchSession({ name: updated.name });
      showToast("Name updated successfully");
    } catch {
      showToast("Failed to update name");
    } finally {
      setSaving(null);
    }
  };

  const handleSaveEmail = async () => {
    if (!emailForm.email.trim()) return;
    setSaving("email");
    try {
      const updated = await updateMyProfile({ email: emailForm.email.trim() });
      _patchSession({ email: updated.email });
      showToast("Email updated successfully");
    } catch {
      showToast("Failed to update email");
    } finally {
      setSaving(null);
    }
  };

  const handleSavePassword = async () => {
    if (passwordForm.password.length < 6) {
      showToast("Password must be at least 6 characters");
      return;
    }
    if (passwordForm.password !== passwordForm.confirm) {
      showToast("Passwords do not match");
      return;
    }
    setSaving("password");
    try {
      await updateMyProfile({ password: passwordForm.password });
      setPasswordForm({ password: "", confirm: "" });
      showToast("Password updated successfully");
    } catch {
      showToast("Failed to update password");
    } finally {
      setSaving(null);
    }
  };

  return (
    <Stack spacing={3}>
      {/* Header */}
      <Stack direction="row" alignItems="center" spacing={1.5}>
        <Box
          sx={{
            width: 44, height: 44, borderRadius: 2,
            bgcolor: `${brand.orange}1F`, color: brand.orange,
            display: "flex", alignItems: "center", justifyContent: "center",
          }}
        >
          <ManageAccountsRoundedIcon />
        </Box>
        <Box>
          <Typography variant="h5" fontWeight={800}>Account Settings</Typography>
          <Typography variant="body2" color="text.secondary">
            Update your profile information and credentials
          </Typography>
        </Box>
      </Stack>

      {/* Name */}
      <Card>
        <CardContent>
          <Typography variant="h6" fontWeight={700} mb={2}>Display Name</Typography>
          <Stack direction={{ xs: "column", sm: "row" }} spacing={2} alignItems="flex-start">
            <TextField
              label="Full Name"
              value={nameForm.name}
              onChange={(e) => setNameForm({ name: e.target.value })}
              fullWidth
              sx={{ maxWidth: 400 }}
              id="settings-name"
            />
            <Button
              onClick={handleSaveName}
              disabled={saving === "name" || !nameForm.name.trim()}
              sx={{ minWidth: 120, alignSelf: { sm: "center" } }}
              id="settings-save-name"
            >
              {saving === "name" ? "Saving..." : "Save Name"}
            </Button>
          </Stack>
        </CardContent>
      </Card>

      {/* Email */}
      <Card>
        <CardContent>
          <Typography variant="h6" fontWeight={700} mb={0.5}>Email Address</Typography>
          <Typography variant="body2" color="text.secondary" mb={2}>
            This is the email you use to log in to the dashboard.
          </Typography>
          <Stack direction={{ xs: "column", sm: "row" }} spacing={2} alignItems="flex-start">
            <TextField
              label="Email Address"
              type="email"
              value={emailForm.email}
              onChange={(e) => setEmailForm({ email: e.target.value })}
              fullWidth
              sx={{ maxWidth: 400 }}
              id="settings-email"
            />
            <Button
              onClick={handleSaveEmail}
              disabled={saving === "email" || !emailForm.email.trim()}
              sx={{ minWidth: 120, alignSelf: { sm: "center" } }}
              id="settings-save-email"
            >
              {saving === "email" ? "Saving..." : "Save Email"}
            </Button>
          </Stack>
        </CardContent>
      </Card>

      {/* Password */}
      <Card>
        <CardContent>
          <Typography variant="h6" fontWeight={700} mb={0.5}>Change Password</Typography>
          <Typography variant="body2" color="text.secondary" mb={2}>
            Password must be at least 6 characters.
          </Typography>
          <Stack spacing={2} maxWidth={400}>
            <TextField
              label="New Password"
              type="password"
              value={passwordForm.password}
              onChange={(e) => setPasswordForm((f) => ({ ...f, password: e.target.value }))}
              fullWidth
              id="settings-password"
            />
            <TextField
              label="Confirm Password"
              type="password"
              value={passwordForm.confirm}
              onChange={(e) => setPasswordForm((f) => ({ ...f, confirm: e.target.value }))}
              fullWidth
              id="settings-confirm-password"
            />
            <Button
              onClick={handleSavePassword}
              disabled={saving === "password" || !passwordForm.password}
              sx={{ alignSelf: "flex-start", minWidth: 160 }}
              id="settings-save-password"
            >
              {saving === "password" ? "Saving..." : "Update Password"}
            </Button>
          </Stack>
        </CardContent>
      </Card>

      {/* Current session info */}
      <Card>
        <CardContent>
          <Typography variant="h6" fontWeight={700} mb={1.5}>Current Session</Typography>
          <Divider sx={{ mb: 1.5 }} />
          <Stack spacing={0.75}>
            <Stack direction="row" spacing={1}>
              <Typography variant="body2" color="text.secondary" minWidth={80}>Name:</Typography>
              <Typography variant="body2">{session?.name}</Typography>
            </Stack>
            <Stack direction="row" spacing={1}>
              <Typography variant="body2" color="text.secondary" minWidth={80}>Email:</Typography>
              <Typography variant="body2">{session?.email}</Typography>
            </Stack>
            <Stack direction="row" spacing={1}>
              <Typography variant="body2" color="text.secondary" minWidth={80}>Role:</Typography>
              <Typography variant="body2" textTransform="capitalize">
                {session?.role?.replace("_", " ")}
              </Typography>
            </Stack>
          </Stack>
        </CardContent>
      </Card>
    </Stack>
  );
}

/** Patch the stored session after a profile update so the UI stays in sync. */
function _patchSession(patch: Partial<AdminSession>) {
  const existing = readJson<AdminSession | null>(STORAGE_KEYS.session, null);
  if (!existing) return;
  writeJson<AdminSession>(STORAGE_KEYS.session, { ...existing, ...patch });
  // Force a refresh of the auth store hydration
  if (typeof window !== "undefined") window.dispatchEvent(new Event("storage"));
}
