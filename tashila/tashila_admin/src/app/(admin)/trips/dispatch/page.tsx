"use client";

import { useCallback, useEffect, useMemo, useState, useRef } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import Box from "@mui/material/Box";
import Card from "@mui/material/Card";
import CardContent from "@mui/material/CardContent";
import Stack from "@mui/material/Stack";
import Typography from "@mui/material/Typography";
import TextField from "@mui/material/TextField";
import Button from "@mui/material/Button";
import Chip from "@mui/material/Chip";
import Autocomplete from "@mui/material/Autocomplete";
import Divider from "@mui/material/Divider";
import IconButton from "@mui/material/IconButton";
import Alert from "@mui/material/Alert";
import Checkbox from "@mui/material/Checkbox";
import FormControlLabel from "@mui/material/FormControlLabel";
import ArrowBackRoundedIcon from "@mui/icons-material/ArrowBackRounded";
import SendRoundedIcon from "@mui/icons-material/SendRounded";
import LocationOnRoundedIcon from "@mui/icons-material/LocationOnRounded";
import FlagRoundedIcon from "@mui/icons-material/FlagRounded";
import { usePricingStore } from "@/lib/store/pricing";
import { useDriversStore } from "@/lib/store/drivers";
import { useUsersStore } from "@/lib/store/users";
import { useTripsStore } from "@/lib/store/trips";
import { useToast } from "@/components/ToastProvider";
import { estimateFareFromApi, findRule } from "@/lib/api/pricing";
import { ADMIN_NEIGHBORHOODS, neighborhoodLabel } from "@/lib/neighborhoods";
import { TRUCK_TYPES, type TruckType } from "@/lib/types";
import { getTruckTypeLabel } from "@/lib/labels";
import { haversineKm } from "@/lib/format";
import { brand } from "@/theme/colors";
import { useTranslation } from "@/i18n/useTranslation";
import { useFormatDzd } from "@/i18n/format";
import LiveTruckMap from "@/components/LiveTruckMap";

/** Live driver locations map on dispatch (`dispatch.live_map_title`). */
const SHOW_DRIVER_LOCATIONS_MAP = true;

type LocationOption = (typeof ADMIN_NEIGHBORHOODS)[number];

export default function DispatchTripPage() {
  const router = useRouter();
  const showToast = useToast();
  const { t, locale } = useTranslation();
  const formatDzd = useFormatDzd();

  const users = useUsersStore((s) => s.users);
  const loadUsers = useUsersStore((s) => s.load);
  const drivers = useDriversStore((s) => s.drivers);
  const loadDrivers = useDriversStore((s) => s.load);
  const rules = usePricingStore((s) => s.rules);
  const loadPricing = usePricingStore((s) => s.load);
  const dispatchTrip = useTripsStore((s) => s.dispatch);

  useEffect(() => {
    loadUsers();
    loadDrivers();
    loadPricing();
  }, [loadUsers, loadDrivers, loadPricing]);

  const [truckType, setTruckType] = useState<TruckType>("single_cabin");
  const [externalOrder, setExternalOrder] = useState(false);
  const [externalLabel, setExternalLabel] = useState("");
  const [externalPhone, setExternalPhone] = useState("");
  const [client, setClient] = useState<(typeof users)[number] | null>(null);

  const customLocation = true;
  const [dispatchMode, setDispatchMode] = useState<"accepted" | "requested">("accepted");
  const [customPickupAddress, setCustomPickupAddress] = useState("");
  const [customPickupLat, setCustomPickupLat] = useState<number>(22.785);
  const [customPickupLng, setCustomPickupLng] = useState<number>(5.523);

  const [customDropOffAddress, setCustomDropOffAddress] = useState("");
  const [customDropOffLat, setCustomDropOffLat] = useState<number>(22.812);
  const [customDropOffLng, setCustomDropOffLng] = useState<number>(5.451);

  const pickupInputRef = useRef<HTMLInputElement | null>(null);
  const dropOffInputRef = useRef<HTMLInputElement | null>(null);

  const [driver, setDriver] = useState<(typeof drivers)[number] | null>(null);
  const [submitting, setSubmitting] = useState(false);

  // Setup Google Autocomplete on text fields when custom location mode is active
  useEffect(() => {
    if (!customLocation) return;

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const g = (window as any).google?.maps;
    if (!g || !g.places) return;

    let pickupAutocomplete: any = null;
    let dropOffAutocomplete: any = null;

    if (pickupInputRef.current) {
      pickupAutocomplete = new g.places.Autocomplete(pickupInputRef.current);
      pickupAutocomplete.addListener("place_changed", () => {
        const place = pickupAutocomplete.getPlace();
        if (place.geometry?.location) {
          setCustomPickupAddress(place.formatted_address || place.name || "");
          setCustomPickupLat(place.geometry.location.lat());
          setCustomPickupLng(place.geometry.location.lng());
        }
      });
    }

    if (dropOffInputRef.current) {
      dropOffAutocomplete = new g.places.Autocomplete(dropOffInputRef.current);
      dropOffAutocomplete.addListener("place_changed", () => {
        const place = dropOffAutocomplete.getPlace();
        if (place.geometry?.location) {
          setCustomDropOffAddress(place.formatted_address || place.name || "");
          setCustomDropOffLat(place.geometry.location.lat());
          setCustomDropOffLng(place.geometry.location.lng());
        }
      });
    }

    return () => {
      if (pickupAutocomplete) g.event.clearInstanceListeners(pickupAutocomplete);
      if (dropOffAutocomplete) g.event.clearInstanceListeners(dropOffAutocomplete);
    };
  }, [customLocation]);

  const effectivePickup = useMemo(() => {
    return {
      label: customPickupAddress || "Custom Pickup Point",
      lat: Number(customPickupLat),
      lng: Number(customPickupLng),
    };
  }, [customPickupAddress, customPickupLat, customPickupLng]);

  const effectiveDropOff = useMemo(() => {
    return {
      label: customDropOffAddress || "Custom Drop-off Point",
      lat: Number(customDropOffLat),
      lng: Number(customDropOffLng),
    };
  }, [customDropOffAddress, customDropOffLat, customDropOffLng]);

  const eligibleDrivers = useMemo(
    () =>
      drivers.filter(
        (d) =>
          d.approvalStatus === "approved" &&
          d.availability === "online" &&
          d.truckType === truckType
      ),
    [drivers, truckType]
  );

  const sortedEligibleDrivers = useMemo(() => {
    if (!effectivePickup) return eligibleDrivers;
    return [...eligibleDrivers].sort((a, b) => {
      const da = haversineKm(
        effectivePickup.lat,
        effectivePickup.lng,
        a.lastLocation.lat,
        a.lastLocation.lng
      );
      const db = haversineKm(
        effectivePickup.lat,
        effectivePickup.lng,
        b.lastLocation.lat,
        b.lastLocation.lng
      );
      return da - db;
    });
  }, [eligibleDrivers, effectivePickup]);

  useEffect(() => {
    if (driver && !sortedEligibleDrivers.some((d) => d.id === driver.id)) {
      setDriver(null);
    }
  }, [truckType, driver, sortedEligibleDrivers]);

  useEffect(() => {
    if (externalOrder) {
      setClient(null);
    } else {
      setExternalPhone("");
    }
  }, [externalOrder]);

  const oneDecimal = useMemo(() => {
    const fmt = new Intl.NumberFormat(
      locale === "ar" ? "ar-DZ" : locale === "fr" ? "fr-DZ" : "en-DZ",
      { minimumFractionDigits: 1, maximumFractionDigits: 1 }
    );
    return (v: number) => fmt.format(v);
  }, [locale]);

  const twoDecimal = useMemo(() => {
    const fmt = new Intl.NumberFormat(
      locale === "ar" ? "ar-DZ" : locale === "fr" ? "fr-DZ" : "en-DZ",
      { minimumFractionDigits: 2, maximumFractionDigits: 2 }
    );
    return (v: number) => fmt.format(v);
  }, [locale]);

  const integer = useMemo(() => {
    const fmt = new Intl.NumberFormat(
      locale === "ar" ? "ar-DZ" : locale === "fr" ? "fr-DZ" : "en-DZ",
      { maximumFractionDigits: 0 }
    );
    return (v: number) => fmt.format(v);
  }, [locale]);

  const distanceKm = useMemo(() => {
    if (!effectivePickup || !effectiveDropOff) return 0;
    return Number(
      haversineKm(
        effectivePickup.lat,
        effectivePickup.lng,
        effectiveDropOff.lat,
        effectiveDropOff.lng
      ).toFixed(1)
    );
  }, [effectivePickup, effectiveDropOff]);

  const rule = useMemo(() => findRule(rules, truckType), [rules, truckType]);
  const estimatedMinutes = useMemo(
    () => Math.max(5, distanceKm * 2.4),
    [distanceKm]
  );
  const [apiFare, setApiFare] = useState<number | null>(null);
  const [fareLoading, setFareLoading] = useState(false);

  useEffect(() => {
    if (!effectivePickup || !effectiveDropOff || distanceKm <= 0) {
      setApiFare(null);
      return;
    }
    let cancelled = false;
    setFareLoading(true);
    estimateFareFromApi(
      { lat: effectivePickup.lat, lng: effectivePickup.lng, address: effectivePickup.label },
      { lat: effectiveDropOff.lat, lng: effectiveDropOff.lng, address: effectiveDropOff.label },
      truckType,
      customLocation
    )
      .then((fare) => {
        if (!cancelled) setApiFare(fare);
      })
      .catch(() => {
        if (!cancelled) setApiFare(null);
      })
      .finally(() => {
        if (!cancelled) setFareLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [effectivePickup, effectiveDropOff, truckType, distanceKm, customLocation]);

  const mapCenter = effectivePickup
    ? { lat: effectivePickup.lat, lng: effectivePickup.lng }
    : { lat: 22.785, lng: 5.523 };

  const handleSelectFromMap = useCallback(
    (id: string) => {
      const d = sortedEligibleDrivers.find((x) => x.id === id);
      if (d) setDriver(d);
    },
    [sortedEligibleDrivers]
  );

  const canSubmit =
    (externalOrder || Boolean(client)) &&
    effectivePickup &&
    effectiveDropOff &&
    driver &&
    rule &&
    rule.active &&
    distanceKm > 0 &&
    apiFare != null &&
    apiFare > 0 &&
    !fareLoading;

  const handleSendNearest = () => {
    const nearest = sortedEligibleDrivers[0];
    if (nearest) setDriver(nearest);
  };

  const handleSubmit = async () => {
    if (!effectivePickup) {
      showToast(t("validation.pickup_required"), "error");
      return;
    }
    if (!effectiveDropOff) {
      showToast(t("validation.dropoff_required"), "error");
      return;
    }
    if (!externalOrder && !client) {
      showToast(t("validation.client_required"), "error");
      return;
    }
    if (externalOrder && !externalLabel.trim()) {
      showToast(t("validation.external_name_required"), "error");
      return;
    }
    if (externalOrder && !externalPhone.trim()) {
      showToast(t("validation.external_phone_required"), "error");
      return;
    }
    if (!driver) {
      showToast(t("validation.driver_required"), "error");
      return;
    }
    if (!rule || !rule.active) {
      showToast(t("validation.rule_disabled"), "error");
      return;
    }
    if (fareLoading) {
      showToast(t("common.loading"), "info");
      return;
    }
    if (apiFare == null || apiFare <= 0) {
      showToast(t("validation.fare_required"), "error");
      return;
    }

    setSubmitting(true);
    try {
      const clientId = externalOrder ? null : client!.id;
      const clientName = externalOrder
        ? externalLabel.trim() || t("dispatch.external_order_default_name")
        : `${client!.firstName} ${client!.lastName}`;
      const trip = await dispatchTrip({
        clientId,
        clientName,
        externalLabel: externalOrder ? clientName : undefined,
        externalPhone: externalOrder ? externalPhone.trim() : undefined,
        driverId: driver.id,
        driverName: driver.name,
        pickup: effectivePickup.label,
        dropOff: effectiveDropOff.label,
        pickupLat: effectivePickup.lat,
        pickupLng: effectivePickup.lng,
        dropOffLat: effectiveDropOff.lat,
        dropOffLng: effectiveDropOff.lng,
        truckType,
        fare: apiFare!,
        dispatchMode,
      });
      showToast(
        t("toast.trip_dispatched", { id: trip.id, name: driver.name })
      );
      router.push("/trips");
    } catch {
      showToast(t("toast.action_failed"), "error");
    } finally {
      setSubmitting(false);
    }
  };

  const truckTypeLabelLower = (tt: TruckType) =>
    getTruckTypeLabel(t, tt).toLowerCase();

  return (
    <Box sx={{ maxWidth: 1100, mx: "auto" }}>
      {/* Notes & Tips Alert Box */}
      <Box sx={{ mb: 3 }}>
        <Alert severity="info" sx={{ borderRadius: 2, border: `1px solid ${brand.border}` }}>
          <Typography variant="subtitle2" sx={{ fontWeight: 800, mb: 0.5 }}>
            {t("dispatch.guide_title")}
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ whiteSpace: "pre-line" }}>
            {t("dispatch.guide_body")}
          </Typography>
        </Alert>
      </Box>
      <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
        <IconButton component={Link} href="/trips" size="small">
          <ArrowBackRoundedIcon />
        </IconButton>
        <Typography color="text.secondary">
          {t("dispatch.back_to_trips")}
        </Typography>
      </Stack>

      <Box
        sx={{
          display: "grid",
          gridTemplateColumns: { xs: "1fr", lg: "1.2fr 1fr" },
          gap: 2,
        }}
      >
        <Card>
          <CardContent>
            <Stack spacing={3}>
              <Box>
                <Typography variant="h5" sx={{ fontWeight: 800 }}>
                  {t("dispatch.title")}
                </Typography>
                <Typography color="text.secondary">
                  {t("dispatch.subtitle")}
                </Typography>
              </Box>

              <Box>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1 }}>
                  {t("dispatch.truck_type_section")}
                </Typography>
                <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                  {TRUCK_TYPES.map((tt) => {
                    const selected = truckType === tt;
                    return (
                      <Chip
                        key={tt}
                        label={getTruckTypeLabel(t, tt)}
                        onClick={() => setTruckType(tt)}
                        color={selected ? "primary" : "default"}
                        variant={selected ? "filled" : "outlined"}
                        sx={{ px: 2, py: 2.5, fontSize: 14 }}
                      />
                    );
                  })}
                </Stack>
              </Box>

              <Box>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1 }}>
                  Dispatch Mode (Status of Depart)
                </Typography>
                <Stack direction="row" spacing={1.5} flexWrap="wrap" useFlexGap>
                  <Chip
                    label="Directly Accepted (Auto-assigned)"
                    onClick={() => setDispatchMode("accepted")}
                    color={dispatchMode === "accepted" ? "primary" : "default"}
                    variant={dispatchMode === "accepted" ? "filled" : "outlined"}
                    sx={{ px: 2, py: 2.5, fontSize: 14 }}
                  />
                  <Chip
                    label="Normal Dispatch Order (Requires Driver Acceptance)"
                    onClick={() => setDispatchMode("requested")}
                    color={dispatchMode === "requested" ? "primary" : "default"}
                    variant={dispatchMode === "requested" ? "filled" : "outlined"}
                    sx={{ px: 2, py: 2.5, fontSize: 14 }}
                  />
                </Stack>
              </Box>

              <FormControlLabel
                control={
                  <Checkbox
                    checked={externalOrder}
                    onChange={(_, c) => setExternalOrder(c)}
                  />
                }
                label={t("dispatch.external_order")}
              />
              {externalOrder && (
                <Stack spacing={2}>
                  <TextField
                    label={t("dispatch.external_order_label")}
                    placeholder={t("dispatch.external_order_placeholder")}
                    value={externalLabel}
                    onChange={(e) => setExternalLabel(e.target.value)}
                    helperText={t("dispatch.external_order_hint")}
                  />
                  <TextField
                    label={t("dispatch.external_phone_label")}
                    placeholder={t("dispatch.external_phone_placeholder")}
                    value={externalPhone}
                    onChange={(e) => setExternalPhone(e.target.value)}
                    helperText={t("dispatch.external_phone_hint")}
                  />
                </Stack>
              )}

              <Autocomplete
                value={client}
                onChange={(_, v) => setClient(v)}
                options={users}
                disabled={externalOrder}
                getOptionLabel={(o) => `${o.firstName} ${o.lastName} · ${o.phone}`}
                renderInput={(params) => (
                  <TextField
                    {...params}
                    label={t("dispatch.client_label")}
                    placeholder={t("dispatch.client_placeholder")}
                  />
                )}
              />

              <Stack spacing={2}>
                {/* Pickup Search & Lat/Lng Inputs */}
                <Card variant="outlined" sx={{ p: 2, bgcolor: "rgba(0,0,0,0.01)" }}>
                  <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1, color: brand.success }}>
                    🟢 Custom Pickup Location
                  </Typography>
                  <Stack spacing={1.5}>
                    <TextField
                      fullWidth
                      inputRef={pickupInputRef}
                      label="Search or enter Pickup Address"
                      value={customPickupAddress}
                      onChange={(e) => setCustomPickupAddress(e.target.value)}
                      placeholder="Type address (e.g. In Salah Center)"
                    />
                    <Stack direction="row" spacing={2}>
                      <TextField
                        type="number"
                        label="Latitude"
                        value={customPickupLat}
                        onChange={(e) => setCustomPickupLat(Number(e.target.value) || 0)}
                        sx={{ flex: 1 }}
                      />
                      <TextField
                        type="number"
                        label="Longitude"
                        value={customPickupLng}
                        onChange={(e) => setCustomPickupLng(Number(e.target.value) || 0)}
                        sx={{ flex: 1 }}
                      />
                    </Stack>
                  </Stack>
                </Card>

                {/* Drop-off Search & Lat/Lng Inputs */}
                <Card variant="outlined" sx={{ p: 2, bgcolor: "rgba(0,0,0,0.01)" }}>
                  <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1, color: brand.danger }}>
                    🔴 Custom Drop-off Location
                  </Typography>
                  <Stack spacing={1.5}>
                    <TextField
                      fullWidth
                      inputRef={dropOffInputRef}
                      label="Search or enter Drop-off Address"
                      value={customDropOffAddress}
                      onChange={(e) => setCustomDropOffAddress(e.target.value)}
                      placeholder="Type address (e.g. Tamanrasset Airport)"
                    />
                    <Stack direction="row" spacing={2}>
                      <TextField
                        type="number"
                        label="Latitude"
                        value={customDropOffLat}
                        onChange={(e) => setCustomDropOffLat(Number(e.target.value) || 0)}
                        sx={{ flex: 1 }}
                      />
                      <TextField
                        type="number"
                        label="Longitude"
                        value={customDropOffLng}
                        onChange={(e) => setCustomDropOffLng(Number(e.target.value) || 0)}
                        sx={{ flex: 1 }}
                      />
                    </Stack>
                  </Stack>
                </Card>
              </Stack>

              <Autocomplete
                value={driver}
                onChange={(_, v) => setDriver(v)}
                options={sortedEligibleDrivers}
                getOptionLabel={(o) => {
                  if (!effectivePickup) return `${o.name} · ${o.phone}`;
                  const km = haversineKm(
                    effectivePickup.lat,
                    effectivePickup.lng,
                    o.lastLocation.lat,
                    o.lastLocation.lng
                  );
                  return `${o.name} · ${oneDecimal(km)} km`;
                }}
                noOptionsText={
                  sortedEligibleDrivers.length === 0
                    ? t("dispatch.no_online_drivers", {
                        type: truckTypeLabelLower(truckType),
                      })
                    : t("dispatch.no_drivers_match")
                }
                renderInput={(params) => (
                  <TextField
                    {...params}
                    label={t("dispatch.driver_label", {
                      count: sortedEligibleDrivers.length,
                    })}
                    placeholder={t("dispatch.driver_placeholder")}
                  />
                )}
              />

              {sortedEligibleDrivers.length > 0 && effectivePickup && (
                <Stack direction="row" spacing={1} alignItems="center">
                  <Alert severity="info" sx={{ flex: 1 }}>
                    {t("dispatch.nearby_hint")}
                  </Alert>
                  <Button
                    variant="outlined"
                    size="small"
                    onClick={handleSendNearest}
                    disabled={!sortedEligibleDrivers[0]}
                  >
                    {t("dispatch.send_nearest")}
                  </Button>
                </Stack>
              )}

              {!rule?.active && (
                <Alert severity="warning">
                  {t("dispatch.pricing_disabled_alert", {
                    type: truckTypeLabelLower(truckType),
                  })}
                </Alert>
              )}

              <Stack
                direction={{ xs: "column", sm: "row" }}
                spacing={1.5}
                justifyContent="flex-end"
              >
                <Button
                  type="button"
                  variant="outlined"
                  component={Link}
                  href="/trips"
                >
                  {t("common.cancel")}
                </Button>
                <Button
                  size="large"
                  startIcon={<SendRoundedIcon />}
                  onClick={handleSubmit}
                  disabled={submitting}
                >
                  {submitting
                    ? t("dispatch.sending")
                    : t("dispatch.send_to_driver")}
                </Button>
              </Stack>
            </Stack>
          </CardContent>
        </Card>

        <Stack spacing={2}>
          <Card>
            <CardContent>
              <Typography variant="h6" sx={{ mb: 1 }}>
                {t("dispatch.fare_estimate_title")}
              </Typography>
              <Box
                sx={{
                  p: 2,
                  borderRadius: 2,
                  background: `linear-gradient(135deg, ${brand.orange} 0%, #FF9F2D 100%)`,
                  color: "white",
                  mb: 1,
                }}
              >
                <Typography variant="caption" sx={{ opacity: 0.9, fontWeight: 700 }}>
                  {t("dispatch.estimated_fare_label")}
                </Typography>
                <Typography variant="h4" sx={{ fontWeight: 800, mt: 0.5 }}>
                  {fareLoading
                    ? "…"
                    : apiFare != null && apiFare > 0
                      ? formatDzd(apiFare)
                      : "—"}
                </Typography>
                <Typography variant="body2" sx={{ opacity: 0.9 }}>
                  {t("dispatch.distance_value", { km: oneDecimal(distanceKm) })}
                </Typography>
              </Box>
              <Typography variant="caption" color="text.secondary" sx={{ display: "block", mb: 2 }}>
                {t("dispatch.fare_formula_caption")}
              </Typography>
              <Divider />
              <Stack spacing={1} sx={{ mt: 2 }}>
                <Row
                  label={t("dispatch.row_base_fare")}
                  value={rule ? formatDzd(rule.baseFare) : "—"}
                />
                <Row
                  label={t("dispatch.row_per_km")}
                  value={
                    rule
                      ? t("dispatch.row_per_km_value", {
                          amount: formatDzd(rule.perKm),
                          km: oneDecimal(distanceKm),
                        })
                      : "—"
                  }
                />
                <Row
                  label={t("dispatch.row_per_minute")}
                  value={
                    rule
                      ? t("dispatch.row_per_minute_value", {
                          amount: formatDzd(rule.perMinute),
                          minutes: integer(estimatedMinutes),
                        })
                      : "—"
                  }
                />
                <Row
                  label={t("dispatch.row_surge")}
                  value={
                    rule
                      ? t("dispatch.row_surge_value", {
                          value: twoDecimal(rule.surgeMultiplier),
                        })
                      : "—"
                  }
                />
                <Row
                  label={t("dispatch.row_min_fare")}
                  value={rule ? formatDzd(rule.minFare) : "—"}
                />
              </Stack>
            </CardContent>
          </Card>

          {SHOW_DRIVER_LOCATIONS_MAP ? (
            <Card>
              <CardContent>
                <Typography variant="subtitle1" sx={{ fontWeight: 800, mb: 1 }}>
                  {t("dispatch.live_map_title")}
                </Typography>
                <LiveTruckMap
                  drivers={sortedEligibleDrivers}
                  center={mapCenter}
                  selectedDriverId={driver?.id ?? null}
                  onSelectDriver={handleSelectFromMap}
                  pickup={effectivePickup}
                  dropOff={effectiveDropOff}
                  onDragPickup={customLocation ? (lat, lng) => {
                    setCustomPickupLat(lat);
                    setCustomPickupLng(lng);
                  } : undefined}
                  onDragDropOff={customLocation ? (lat, lng) => {
                    setCustomDropOffLat(lat);
                    setCustomDropOffLng(lng);
                  } : undefined}
                />
              </CardContent>
            </Card>
          ) : null}
        </Stack>
      </Box>
    </Box>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <Stack
      direction="row"
      justifyContent="space-between"
      alignItems="flex-start"
      sx={{ py: 0.5, gap: 1 }}
    >
      <Typography color="text.secondary" variant="body2" sx={{ flex: 1 }}>
        {label}
      </Typography>
      <Typography variant="body2" sx={{ fontWeight: 600, maxWidth: "52%" }} textAlign="right">
        {value}
      </Typography>
    </Stack>
  );
}
