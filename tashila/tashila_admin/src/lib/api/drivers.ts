import type {
  DocumentStatus,
  DocumentType,
  Driver,
  DriverApprovalStatus,
  TruckType,
} from "../types";
import { apiFetch, getImageUrl } from "./client";

interface ApiDocumentEntry {
  url?: string;
  status?: string;
  rejectionReason?: string | null;
}

interface ApiReview {
  tripId: string;
  rating: number;
  comment?: string | null;
  clientName?: string | null;
  driverName?: string | null;
  createdAt?: string;
}

interface ApiPayment {
  id?: string;
  _id?: string;
  amountDzd: number;
  note?: string | null;
  createdAt: string;
}

interface ApiDriver {
  id?: string;
  _id?: string;
  name: string;
  phone: string;
  truckType: string;
  vehicleColor?: string;
  vehicleModel?: string;
  vehiclePlate?: string;
  location?: { type?: string; coordinates?: [number, number] } | null;
  lastLocation?: { lat: number; lng: number } | null;
  documents?: Record<string, ApiDocumentEntry> | Array<{
    type: string;
    fileName: string | null;
    status: string;
    rejectionReason?: string;
  }>;
  approvalStatus: string;
  documentsApproved?: boolean;
  availability: string;
  createdAt: string;
  rating?: number;
  completedTrips?: number;
  platformDueDzd?: number;
  earnings?: { platformDueDzd?: number };
  customerReviews?: ApiReview[];
  platformPayments?: ApiPayment[];
  avatarUrl?: string | null;
  trips?: any[];
}

interface PaginatedDrivers {
  items: ApiDriver[];
  total: number;
  page: number;
  limit: number;
}

interface PaymentResponse {
  payment?: unknown;
  driver: ApiDriver;
}

function mapDocStatus(status: string | undefined): DocumentStatus {
  if (status === "approved") return "approved";
  if (status === "rejected") return "rejected";
  if (status === "pending") return "pending";
  return "uploaded";
}

function mapDocuments(
  documents: ApiDriver["documents"],
): Driver["documents"] {
  const docTypes: DocumentType[] = [
    "drivingLicense",
    "vehicleRegistration",
    "vehiclePhoto",
  ];
  const mapped: Record<DocumentType, DriverDocument> = {
    drivingLicense: { type: "drivingLicense", fileName: null, status: "pending" },
    vehicleRegistration: { type: "vehicleRegistration", fileName: null, status: "pending" },
    vehiclePhoto: { type: "vehiclePhoto", fileName: null, status: "pending" },
  };
  
  if (documents) {
    if (Array.isArray(documents)) {
      documents.forEach((doc) => {
        const type = doc.type as DocumentType;
        if (docTypes.includes(type)) {
          mapped[type] = {
            type,
            fileName: doc.fileName ? getImageUrl(doc.fileName) : null,
            status: mapDocStatus(doc.status),
            rejectionReason: doc.rejectionReason,
          };
        }
      });
    } else {
      Object.entries(documents).forEach(([type, doc]) => {
        const t = type as DocumentType;
        if (docTypes.includes(t)) {
          mapped[t] = {
            type: t,
            fileName: doc.url ? getImageUrl(doc.url) : null,
            status: mapDocStatus(doc.status),
            rejectionReason: doc.rejectionReason ?? undefined,
          };
        }
      });
    }
  }
  return docTypes.map((t) => mapped[t]);
}

function mapLocation(d: ApiDriver): { lat: number; lng: number } {
  if (d.lastLocation) return d.lastLocation;
  const coords = d.location?.coordinates;
  if (coords && coords.length >= 2) {
    return { lat: coords[1], lng: coords[0] };
  }
  return { lat: 22.785, lng: 5.523 };
}

function mapDriver(d: ApiDriver): Driver {
  const reviews = (d.customerReviews ?? []).map((r) => ({
    id: r.tripId,
    rating: r.rating,
    comment: r.comment ?? "",
    customerName: r.clientName ?? "Client",
    tripId: r.tripId,
    date: r.createdAt ?? new Date().toISOString(),
  }));
  const payments = (d.platformPayments ?? []).map((p) => ({
    id: p.id ?? p._id ?? "",
    amountDzd: p.amountDzd,
    note: p.note ?? "",
    date: p.createdAt,
  }));
  return {
    id: d.id ?? d._id ?? "",
    name: d.name,
    phone: d.phone,
    truckType: d.truckType as TruckType,
    vehicleColor: d.vehicleColor ?? "—",
    vehicleModel: d.vehicleModel ?? "—",
    vehiclePlate: d.vehiclePlate ?? "—",
    lastLocation: mapLocation(d),
    documents: mapDocuments(d.documents),
    approvalStatus: d.approvalStatus as DriverApprovalStatus,
    documentsApproved: d.documentsApproved ?? false,
    availability: d.availability as Driver["availability"],
    createdAt: d.createdAt,
    rating: d.rating ?? 0,
    completedTrips: d.completedTrips ?? 0,
    customerReviews: reviews,
    platformDueDzd: d.earnings?.platformDueDzd ?? d.platformDueDzd ?? 0,
    platformPayments: payments,
    avatarUrl: d.avatarUrl ? getImageUrl(d.avatarUrl) : null,
    trips: (d.trips ?? []).map((t: any) => ({
      id: t.id ?? t._id ?? "",
      clientId: t.clientId ?? "",
      clientName: t.clientName ?? "Client",
      driverId: t.driverId ?? null,
      driverName: t.driverName ?? null,
      pickup: t.pickup?.address || `${t.pickup?.lat ?? 0},${t.pickup?.lng ?? 0}`,
      dropOff: t.dropoff?.address || `${t.dropoff?.lat ?? 0},${t.dropoff?.lng ?? 0}`,
      pickupLat: t.pickup?.lat ?? 0,
      pickupLng: t.pickup?.lng ?? 0,
      dropOffLat: t.dropoff?.lat ?? 0,
      dropOffLng: t.dropoff?.lng ?? 0,
      fare: t.finalFare ?? t.fare ?? 0,
      finalFare: t.finalFare ?? null,
      distanceKm: t.distanceKm ?? 0,
      truckType: t.truckType ?? "single_cabin",
      status: t.status ?? "requested",
      createdAt: t.createdAt ?? "",
      completedAt: t.completedAt ?? null,
      rating: t.driverRating ?? null,
      cashConfirmed: t.status === "completed" || t.cashConfirmed === true,
      paymentMethod: t.paymentMethod ?? "cash",
      dispatchedByAdmin: t.dispatchedByAdmin ?? false,
      clientPhone: t.clientPhone ?? null,
    })),
  };
}

export async function listDrivers(): Promise<Driver[]> {
  const data = await apiFetch<PaginatedDrivers>(
    "/admin/drivers?limit=100&page=1",
  );
  return data.items.map(mapDriver);
}

export async function getDriver(id: string): Promise<Driver | null> {
  try {
    const d = await apiFetch<ApiDriver>(`/admin/drivers/${id}`);
    return mapDriver(d);
  } catch {
    return null;
  }
}

export async function uploadDriverDocument(
  driverId: string,
  documentType: DocumentType,
  file: File,
): Promise<Driver> {
  const form = new FormData();
  form.append("file", file);
  const d = await apiFetch<ApiDriver>(
    `/admin/drivers/${driverId}/documents/${documentType}/upload`,
    { method: "POST", body: form },
  );
  return mapDriver(d);
}

export async function createDriver(input: {
  name: string;
  phone: string;
  truckType: TruckType;
  vehicleColor: string;
  vehicleModel: string;
  vehiclePlate: string;
  uploadedDocs?: DocumentType[];
}): Promise<Driver> {
  const d = await apiFetch<ApiDriver>("/admin/drivers", {
    method: "POST",
    body: JSON.stringify({
      name: input.name.trim(),
      phone: input.phone.trim(),
      truckType: input.truckType,
      vehicleColor: input.vehicleColor.trim(),
      vehicleModel: input.vehicleModel.trim(),
      vehiclePlate: input.vehiclePlate.trim(),
    }),
  });
  return mapDriver(d);
}

export async function updateDocumentStatus(
  driverId: string,
  documentType: DocumentType,
  status: DocumentStatus,
  rejectionReason?: string,
): Promise<Driver> {
  const apiStatus =
    status === "uploaded" ? "approved" : status === "pending" ? "pending" : status;
  const d = await apiFetch<ApiDriver>(
    `/admin/drivers/${driverId}/documents/${documentType}/status`,
    {
      method: "PUT",
      body: JSON.stringify({ status: apiStatus, rejectionReason }),
    },
  );
  return mapDriver(d);
}

export async function setDriverApproval(
  driverId: string,
  status: DriverApprovalStatus,
  reason?: string,
): Promise<Driver> {
  const d = await apiFetch<ApiDriver>(`/admin/drivers/${driverId}/approval`, {
    method: "PUT",
    body: JSON.stringify({ status, reason }),
  });
  return mapDriver(d);
}

export async function setDriverAvailability(
  driverId: string,
  availability: Driver["availability"],
): Promise<Driver> {
  const d = await apiFetch<ApiDriver>(
    `/admin/drivers/${driverId}/availability`,
    {
      method: "PUT",
      body: JSON.stringify({ availability }),
    },
  );
  return mapDriver(d);
}

export async function applyPlatformPayment(
  driverId: string,
  amountDzd: number,
  note: string,
): Promise<Driver> {
  if (amountDzd <= 0) throw new Error("Amount must be positive");
  const res = await apiFetch<PaymentResponse | ApiDriver>(
    `/admin/drivers/${driverId}/payments`,
    {
      method: "POST",
      body: JSON.stringify({ amountDzd, note }),
    },
  );
  const d = "driver" in (res as PaymentResponse)
    ? (res as PaymentResponse).driver
    : (res as ApiDriver);
  return mapDriver(d);
}

export async function uploadDriverAvatar(
  driverId: string,
  file: File,
): Promise<Driver> {
  const form = new FormData();
  form.append("file", file);
  const d = await apiFetch<ApiDriver>(
    `/admin/drivers/${driverId}/avatar`,
    { method: "POST", body: form },
  );
  return mapDriver(d);
}
