export type TruckType = "single_cabin" | "double_cabin";

export const TRUCK_TYPES: TruckType[] = ["single_cabin", "double_cabin"];

export type DocumentType = "drivingLicense" | "vehicleRegistration" | "vehiclePhoto";

export const DOCUMENT_TYPES: DocumentType[] = [
  "drivingLicense",
  "vehicleRegistration",
  "vehiclePhoto",
];

export type DocumentStatus = "pending" | "uploaded" | "approved" | "rejected";

export type DriverDocument = {
  type: DocumentType;
  fileName: string | null;
  status: DocumentStatus;
  rejectionReason?: string;
};

export type AvailabilityStatus = "online" | "offline";

export type DriverApprovalStatus = "pending" | "approved" | "rejected";

/** Review left by a customer about this driver. */
export type DriverCustomerReview = {
  id: string;
  comment: string;
  rating: number;
  customerName: string;
  tripId: string;
  date: string;
};

/** Manual deduction recorded against platform dues. */
export type PlatformPayment = {
  id: string;
  amountDzd: number;
  note: string;
  date: string;
};

export type Driver = {
  id: string;
  name: string;
  phone: string;
  truckType: TruckType;
  /** Shown in admin list / dispatch. */
  vehicleColor: string;
  vehicleModel: string;
  vehiclePlate: string;
  /** Last known position for live map / nearby filter. */
  lastLocation: { lat: number; lng: number };
  documents: DriverDocument[];
  approvalStatus: DriverApprovalStatus;
  documentsApproved: boolean;
  availability: AvailabilityStatus;
  createdAt: string;
  rating: number;
  completedTrips: number;
  customerReviews: DriverCustomerReview[];
  /** Outstanding commission owed to platform (DZD). */
  platformDueDzd: number;
  platformPayments: PlatformPayment[];
};

export type UserStatus = "active" | "suspended";

/** Review the user left for a driver after a trip. */
export type UserDriverReview = {
  id: string;
  comment: string;
  rating: number;
  driverName: string;
  tripId: string;
  date: string;
};

export type User = {
  id: string;
  firstName: string;
  lastName: string;
  phone: string;
  status: UserStatus;
  createdAt: string;
  totalTrips: number;
  /** Average of ratings given to drivers (0 if none). */
  averageRating: number;
  driverReviews: UserDriverReview[];
};

export type TripStatus =
  | "requested"
  | "accepted"
  | "headingToPickup"
  | "inProgress"
  | "awaitingCash"
  | "completed"
  | "cancelled";

export const TRIP_STATUSES: TripStatus[] = [
  "requested",
  "accepted",
  "headingToPickup",
  "inProgress",
  "awaitingCash",
  "completed",
  "cancelled",
];

export type Trip = {
  id: string;
  clientId: string;
  clientName: string;
  driverId: string | null;
  driverName: string | null;
  pickup: string;
  dropOff: string;
  pickupLat: number;
  pickupLng: number;
  dropOffLat: number;
  dropOffLng: number;
  fare: number;
  finalFare: number | null;
  distanceKm: number;
  truckType: TruckType;
  status: TripStatus;
  createdAt: string;
  completedAt: string | null;
  rating: number | null;
  cashConfirmed: boolean;
  paymentMethod: "cash";
  dispatchedByAdmin: boolean;
};

export type PricingRule = {
  id: string;
  truckType: TruckType;
  baseFare: number;
  perKm: number;
  perMinute: number;
  minFare: number;
  surgeMultiplier: number;
  active: boolean;
};

export type AdminSession = {
  email: string;
  name: string;
  role: string;
  accessToken: string;
  refreshToken: string;
  loggedInAt: string;
};
