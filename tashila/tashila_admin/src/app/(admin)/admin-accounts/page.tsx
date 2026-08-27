"use client";

import { useEffect, useState } from "react";
import Box from "@mui/material/Box";
import Button from "@mui/material/Button";
import Card from "@mui/material/Card";
import CardContent from "@mui/material/CardContent";
import Chip from "@mui/material/Chip";
import Dialog from "@mui/material/Dialog";
import DialogActions from "@mui/material/DialogActions";
import DialogContent from "@mui/material/DialogContent";
import DialogTitle from "@mui/material/DialogTitle";
import IconButton from "@mui/material/IconButton";
import MenuItem from "@mui/material/MenuItem";
import Skeleton from "@mui/material/Skeleton";
import Stack from "@mui/material/Stack";
import Table from "@mui/material/Table";
import TableBody from "@mui/material/TableBody";
import TableCell from "@mui/material/TableCell";
import TableHead from "@mui/material/TableHead";
import TableRow from "@mui/material/TableRow";
import TextField from "@mui/material/TextField";
import Tooltip from "@mui/material/Tooltip";
import Typography from "@mui/material/Typography";
import AddRoundedIcon from "@mui/icons-material/AddRounded";
import BlockRoundedIcon from "@mui/icons-material/BlockRounded";
import CheckCircleRoundedIcon from "@mui/icons-material/CheckCircleRounded";
import AdminPanelSettingsRoundedIcon from "@mui/icons-material/AdminPanelSettingsRounded";
import { useAdminAccountsStore } from "@/lib/store/admin-accounts";
import { useAuthStore } from "@/lib/store/auth";
import { useToast } from "@/components/ToastProvider";
import { brand } from "@/theme/colors";

export default function AdminAccountsPage() {
  const accounts = useAdminAccountsStore((s) => s.accounts);
  const isBusy = useAdminAccountsStore((s) => s.isBusy);
  const load = useAdminAccountsStore((s) => s.load);
  const createAccount = useAdminAccountsStore((s) => s.create);
  const updateStatus = useAdminAccountsStore((s) => s.updateStatus);
  const session = useAuthStore((s) => s.session);
  const showToast = useToast();

  const [createOpen, setCreateOpen] = useState(false);
  const [form, setForm] = useState({ name: "", email: "", password: "", role: "admin" });
  const [formBusy, setFormBusy] = useState(false);

  useEffect(() => {
    load();
  }, [load]);

  const isSuperAdmin = session?.role === "super_admin";

  if (!isSuperAdmin) {
    return (
      <Box display="flex" alignItems="center" justifyContent="center" minHeight={300}>
        <Typography color="text.secondary">Access restricted to Super Admin only.</Typography>
      </Box>
    );
  }

  const handleCreate = async () => {
    if (!form.name || !form.email || !form.password) {
      showToast("Please fill all fields");
      return;
    }
    setFormBusy(true);
    const ok = await createAccount(form);
    setFormBusy(false);
    if (ok) {
      setCreateOpen(false);
      setForm({ name: "", email: "", password: "", role: "admin" });
      showToast("Admin account created successfully");
    } else {
      showToast("Failed to create admin account");
    }
  };

  const handleToggleStatus = async (id: string, current: "active" | "suspended") => {
    const next = current === "active" ? "suspended" : "active";
    const ok = await updateStatus(id, next);
    if (ok) {
      showToast(`Admin account ${next === "suspended" ? "suspended" : "activated"}`);
    } else {
      showToast("Failed to update admin status");
    }
  };

  return (
    <Stack spacing={3}>
      {/* Header */}
      <Stack direction="row" alignItems="center" justifyContent="space-between">
        <Stack direction="row" alignItems="center" spacing={1.5}>
          <Box
            sx={{
              width: 44, height: 44, borderRadius: 2,
              bgcolor: `${brand.orange}1F`, color: brand.orange,
              display: "flex", alignItems: "center", justifyContent: "center",
            }}
          >
            <AdminPanelSettingsRoundedIcon />
          </Box>
          <Box>
            <Typography variant="h5" fontWeight={800}>Admin Accounts</Typography>
            <Typography variant="body2" color="text.secondary">
              Manage dashboard admin users
            </Typography>
          </Box>
        </Stack>
        <Button
          startIcon={<AddRoundedIcon />}
          onClick={() => setCreateOpen(true)}
          variant="contained"
          id="create-admin-btn"
        >
          New Admin
        </Button>
      </Stack>

      {/* Table */}
      <Card>
        <CardContent sx={{ p: 0 }}>
          {isBusy && accounts.length === 0 ? (
            <Stack spacing={1} p={2}>
              {Array.from({ length: 3 }).map((_, i) => (
                <Skeleton key={i} variant="rounded" height={52} />
              ))}
            </Stack>
          ) : (
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell>Name</TableCell>
                  <TableCell>Email</TableCell>
                  <TableCell>Role</TableCell>
                  <TableCell>Status</TableCell>
                  <TableCell>Created</TableCell>
                  <TableCell align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {accounts.map((acc) => (
                  <TableRow key={acc.id} hover>
                    <TableCell>
                      <Typography variant="body2" fontWeight={600}>{acc.name}</Typography>
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" color="text.secondary">{acc.email}</Typography>
                    </TableCell>
                    <TableCell>
                      <Chip
                        label={acc.role === "super_admin" ? "Super Admin" : "Admin"}
                        size="small"
                        color={acc.role === "super_admin" ? "primary" : "default"}
                        variant="outlined"
                      />
                    </TableCell>
                    <TableCell>
                      <Chip
                        label={acc.status === "active" ? "Active" : "Suspended"}
                        size="small"
                        color={acc.status === "active" ? "success" : "error"}
                      />
                    </TableCell>
                    <TableCell>
                      <Typography variant="caption" color="text.secondary">
                        {new Date(acc.createdAt).toLocaleDateString()}
                      </Typography>
                    </TableCell>
                    <TableCell align="right">
                      {acc.role !== "super_admin" && (
                        <Tooltip
                          title={acc.status === "active" ? "Suspend account" : "Activate account"}
                        >
                          <IconButton
                            size="small"
                            onClick={() => handleToggleStatus(acc.id, acc.status)}
                            color={acc.status === "active" ? "warning" : "success"}
                            id={`toggle-admin-${acc.id}`}
                          >
                            {acc.status === "active" ? (
                              <BlockRoundedIcon fontSize="small" />
                            ) : (
                              <CheckCircleRoundedIcon fontSize="small" />
                            )}
                          </IconButton>
                        </Tooltip>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
                {accounts.length === 0 && !isBusy && (
                  <TableRow>
                    <TableCell colSpan={6} align="center">
                      <Typography variant="body2" color="text.secondary" py={4}>
                        No admin accounts found
                      </Typography>
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Create Admin Dialog */}
      <Dialog open={createOpen} onClose={() => setCreateOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Create Admin Account</DialogTitle>
        <DialogContent>
          <Stack spacing={2.5} pt={1}>
            <TextField
              label="Full Name"
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              fullWidth
              id="new-admin-name"
            />
            <TextField
              label="Email Address"
              type="email"
              value={form.email}
              onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))}
              fullWidth
              id="new-admin-email"
            />
            <TextField
              label="Password"
              type="password"
              value={form.password}
              onChange={(e) => setForm((f) => ({ ...f, password: e.target.value }))}
              fullWidth
              id="new-admin-password"
            />
            <TextField
              select
              label="Role"
              value={form.role}
              onChange={(e) => setForm((f) => ({ ...f, role: e.target.value }))}
              fullWidth
              id="new-admin-role"
            >
              <MenuItem value="admin">Admin</MenuItem>
              <MenuItem value="super_admin">Super Admin</MenuItem>
            </TextField>
          </Stack>
        </DialogContent>
        <DialogActions sx={{ p: 2.5, pt: 0 }}>
          <Button variant="outlined" onClick={() => setCreateOpen(false)}>Cancel</Button>
          <Button onClick={handleCreate} disabled={formBusy} variant="contained" id="create-admin-submit-btn">
            {formBusy ? "Creating..." : "Create Admin"}
          </Button>
        </DialogActions>
      </Dialog>
    </Stack>
  );
}
