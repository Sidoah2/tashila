import type { AdminAccount } from "@/lib/types";
import { apiFetch } from "./client";

export async function listAdmins(): Promise<AdminAccount[]> {
  return apiFetch<AdminAccount[]>("/admin/accounts");
}

export async function createAdmin(data: {
  email: string;
  password: string;
  name: string;
  role: string;
}): Promise<AdminAccount> {
  return apiFetch<AdminAccount>("/admin/accounts", {
    method: "POST",
    body: JSON.stringify(data),
  });
}

export async function updateAdminStatus(
  id: string,
  status: "active" | "suspended",
): Promise<AdminAccount> {
  return apiFetch<AdminAccount>(`/admin/accounts/${id}/status`, {
    method: "PUT",
    body: JSON.stringify({ status }),
  });
}

export async function updateMyProfile(data: {
  name?: string;
  email?: string;
  password?: string;
}): Promise<{ id: string; email: string; name: string; role: string }> {
  return apiFetch("/admin/accounts/me/profile", {
    method: "PUT",
    body: JSON.stringify(data),
  });
}
