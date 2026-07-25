/** Tamanrasset neighborhood list (synced with tashila-api/data/neighborhoods.json). */
export type Neighborhood = {
  id: string;
  label: string;
  labelAr: string;
  lat: number;
  lng: number;
  supported: boolean;
};

export const ADMIN_NEIGHBORHOODS: Neighborhood[] = [
  { id: "tamanrasset_center", label: "Tamanrasset Center", labelAr: "وسط تمنراست", lat: 22.785, lng: 5.523, supported: true },
  { id: "tamanrasset_airport", label: "Tamanrasset Airport", labelAr: "مطار تمنراست", lat: 22.812, lng: 5.451, supported: true },
  { id: "abalessa", label: "Abalessa", labelAr: "أباليسة", lat: 22.873, lng: 4.847, supported: true },
  { id: "in_ghar", label: "In Ghar", labelAr: "إين غار", lat: 27.108, lng: 1.808, supported: true },
  { id: "in_salah", label: "In Salah", labelAr: "إين صالح", lat: 27.197, lng: 2.483, supported: true },
  { id: "tazrouk", label: "Tazrouk", labelAr: "تازروك", lat: 23.424, lng: 5.675, supported: true },
  { id: "idles", label: "Idles", labelAr: "إدلس", lat: 23.817, lng: 5.917, supported: true },
  { id: "in_amenas", label: "In Amenas", labelAr: "إن أمenas", lat: 28.042, lng: 9.553, supported: false },
];

export function neighborhoodLabel(n: Neighborhood, locale: string): string {
  return locale === "ar" ? n.labelAr : n.label;
}

export function filterNeighborhoods(query: string, locale: string): Neighborhood[] {
  const q = query.trim().toLowerCase();
  if (!q) return ADMIN_NEIGHBORHOODS.filter((n) => n.supported);
  return ADMIN_NEIGHBORHOODS.filter(
    (n) =>
      n.supported &&
      (n.label.toLowerCase().includes(q) ||
        n.labelAr.includes(query.trim()) ||
        n.id.includes(q)),
  );
}
