import type {
  DocumentStatus,
  DocumentType,
  DriverApprovalStatus,
  TripStatus,
  TruckType,
  UserStatus,
} from "./types";

export type Translator = (
  key: string,
  params?: Record<string, string | number>
) => string;

export function getTruckTypeLabel(t: Translator, type: TruckType): string {
  return t(`truck.${type}`);
}

export function getDocumentTypeLabel(
  t: Translator,
  type: DocumentType
): string {
  switch (type) {
    case "drivingLicense":
      return t("doc.driving_license");
    case "vehicleRegistration":
      return t("doc.vehicle_registration");
    case "vehiclePhoto":
      return t("doc.vehicle_photo");
    default:
      return type;
  }
}

export function getDocumentStatusLabel(
  t: Translator,
  status: DocumentStatus
): string {
  return t(`doc_status.${status}`);
}

export function getTripStatusLabel(t: Translator, status: TripStatus): string {
  return t(`trip_status.${status}`);
}

export function getDriverApprovalStatusLabel(
  t: Translator,
  status: DriverApprovalStatus
): string {
  return t(`driver_status.${status}`);
}

export function getUserStatusLabel(t: Translator, status: UserStatus): string {
  return t(`user_status.${status}`);
}

// Color maps (no localization needed)
export const tripStatusColor: Record<
  TripStatus,
  "default" | "primary" | "success" | "warning" | "info" | "error"
> = {
  requested: "info",
  accepted: "primary",
  headingToPickup: "primary",
  inProgress: "warning",
  awaitingCash: "warning",
  completed: "success",
  cancelled: "error",
};

export const driverApprovalStatusColor: Record<
  DriverApprovalStatus,
  "default" | "primary" | "success" | "warning" | "error"
> = {
  pending: "warning",
  approved: "success",
  rejected: "error",
};

export const userStatusColor: Record<
  UserStatus,
  "default" | "success" | "error"
> = {
  active: "success",
  suspended: "error",
  deleted: "default",
};
