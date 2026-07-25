"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
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
  const [client, setClient] = useState<(typeof users)[number] | null>(null);
  const [pickup, setPickup] = useState<LocationOption | null>(
    ADMIN_NEIGHBORHOODS[0] ?? null
  );
  const [dropOff, setDropOff] = useState<LocationOption | null>(
    ADMIN_NEIGHBORHOODS[1] ?? ADMIN_NEIGHBORHOODS[0] ?? null
  );
  const [driver, setDriver] = useState<(typeof drivers)[number] | null>(null);
  const [submitting, setSubmitting] = useState(false);

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
    if (!pickup) return eligibleDrivers;
    return [...eligibleDrivers].sort((a, b) => {
      const da = haversineKm(
        pickup.lat,
        pickup.lng,
        a.lastLocation.lat,
        a.lastLocation.lng
      );
      const db = haversineKm(
        pickup.lat,
        pickup.lng,
        b.lastLocation.lat,
        b.lastLocation.lng
      );
      return da - db;
    });
  }, [eligibleDrivers, pickup]);

  useEffect(() => {
    if (driver && !sortedEligibleDrivers.some((d) => d.id === driver.id)) {
      setDriver(null);
    }
  }, [truckType, driver, sortedEligibleDrivers]);

  useEffect(() => {
    if (externalOrder) setClient(null);
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
    if (!pickup || !dropOff) return 0;
    return Number(
      haversineKm(pickup.lat, pickup.lng, dropOff.lat, dropOff.lng).toFixed(1)
    );
  }, [pickup, dropOff]);

  const rule = useMemo(() => findRule(rules, truckType), [rules, truckType]);
  const estimatedMinutes = useMemo(
    () => Math.max(5, distanceKm * 2.4),
    [distanceKm]
  );
  const [apiFare, setApiFare] = useState<number | null>(null);
  const [fareLoading, setFareLoading] = useState(false);

  useEffect(() => {
    if (!pickup || !dropOff || distanceKm <= 0) {
      setApiFare(null);
      return;
    }
    let cancelled = false;
    setFareLoading(true);
    estimateFareFromApi(
      { lat: pickup.lat, lng: pickup.lng, address: pickup.label },
      { lat: dropOff.lat, lng: dropOff.lng, address: dropOff.label },
      truckType,
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
  }, [pickup, dropOff, truckType, distanceKm]);

  const mapCenter = pickup
    ? { lat: pickup.lat, lng: pickup.lng }
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
    pickup &&
    dropOff &&
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
    if (!canSubmit || !pickup || !dropOff || !driver) return;
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
        driverId: driver.id,
        driverName: driver.name,
        pickup: pickup.label,
        dropOff: dropOff.label,
        pickupLat: pickup.lat,
        pickupLng: pickup.lng,
        dropOffLat: dropOff.lat,
        dropOffLng: dropOff.lng,
        truckType,
        fare: apiFare!,
      });
      showToast(
        t("toast.trip_dispatched", { id: trip.id, name: driver.name })
      );
      router.push("/trips");
    } finally {
      setSubmitting(false);
    }
  };

  const truckTypeLabelLower = (tt: TruckType) =>
    getTruckTypeLabel(t, tt).toLowerCase();

  return (
    <Box sx={{ maxWidth: 1100, mx: "auto" }}>
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
                <Stack spacing={0.5}>
                  <TextField
                    label={t("dispatch.external_order_label")}
                    placeholder={t("dispatch.external_order_placeholder")}
                    value={externalLabel}
                    onChange={(e) => setExternalLabel(e.target.value)}
                    helperText={t("dispatch.external_order_hint")}
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

              <Stack direction={{ xs: "column", sm: "row" }} spacing={2}>
                <Autocomplete
                  fullWidth
                  value={pickup}
                  onChange={(_, v) => setPickup(v)}
                  options={ADMIN_NEIGHBORHOODS}
                  getOptionLabel={(o) => neighborhoodLabel(o, locale)}
                  renderInput={(params) => (
                    <TextField
                      {...params}
                      label={t("dispatch.pickup_label")}
                      InputProps={{
                        ...params.InputProps,
                        startAdornment: (
                          <LocationOnRoundedIcon
                            sx={{ color: brand.success, mr: 1, ml: 0.5 }}
                            fontSize="small"
                          />
                        ),
                      }}
                    />
                  )}
                />
                <Autocomplete
                  fullWidth
                  value={dropOff}
                  onChange={(_, v) => setDropOff(v)}
                  options={ADMIN_NEIGHBORHOODS}
                  getOptionLabel={(o) => neighborhoodLabel(o, locale)}
                  renderInput={(params) => (
                    <TextField
                      {...params}
                      label={t("dispatch.dropoff_label")}
                      InputProps={{
                        ...params.InputProps,
                        startAdornment: (
                          <FlagRoundedIcon
                            sx={{ color: brand.danger, mr: 1, ml: 0.5 }}
                            fontSize="small"
                          />
                        ),
                      }}
                    />
                  )}
                />
              </Stack>

              <Autocomplete
                value={driver}
                onChange={(_, v) => setDriver(v)}
                options={sortedEligibleDrivers}
                getOptionLabel={(o) => {
                  if (!pickup) return `${o.name} · ${o.phone}`;
                  const km = haversineKm(
                    pickup.lat,
                    pickup.lng,
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

              {sortedEligibleDrivers.length > 0 && pickup && (
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
                  disabled={!canSubmit || submitting}
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
