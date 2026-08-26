"use client";

import { useEffect, useMemo, useState } from "react";
import Box from "@mui/material/Box";
import Card from "@mui/material/Card";
import CardContent from "@mui/material/CardContent";
import Stack from "@mui/material/Stack";
import Typography from "@mui/material/Typography";
import TextField from "@mui/material/TextField";
import Button from "@mui/material/Button";
import Switch from "@mui/material/Switch";
import Skeleton from "@mui/material/Skeleton";
import InputAdornment from "@mui/material/InputAdornment";
import Slider from "@mui/material/Slider";
import LocalShippingRoundedIcon from "@mui/icons-material/LocalShippingRounded";
import { usePricingStore } from "@/lib/store/pricing";
import { useToast } from "@/components/ToastProvider";
import { getTruckTypeLabel } from "@/lib/labels";
import { estimateFare, estimateFareFromApi, tashilaDynamicFare } from "@/lib/api/pricing";
import type { PricingRule } from "@/lib/types";
import { brand } from "@/theme/colors";
import { useTranslation } from "@/i18n/useTranslation";
import { useFormatDzd } from "@/i18n/format";
import ServiceAreaMap from "@/components/ServiceAreaMap";
import {
  getPlatformSettings,
  updatePlatformSettings,
  type PlatformSettings,
} from "@/lib/api/settings";

export default function PricingPage() {
  const rules = usePricingStore((s) => s.rules);
  const loaded = usePricingStore((s) => s.loaded);
  const load = usePricingStore((s) => s.load);
  const update = usePricingStore((s) => s.update);
  const showToast = useToast();
  const { t } = useTranslation();

  const [draft, setDraft] = useState<Record<string, PricingRule>>({});
  const [savingId, setSavingId] = useState<string | null>(null);
  const [settings, setSettings] = useState<PlatformSettings | null>(null);
  const [settingsDraft, setSettingsDraft] = useState<PlatformSettings | null>(null);
  const [savingSettings, setSavingSettings] = useState(false);

  useEffect(() => {
    load();
    getPlatformSettings().then((s) => {
      setSettings(s);
      setSettingsDraft(s);
    });
  }, [load]);

  useEffect(() => {
    setDraft((prev) => {
      const next: Record<string, PricingRule> = { ...prev };
      for (const r of rules) {
        if (!next[r.id]) next[r.id] = { ...r };
      }
      return next;
    });
  }, [rules]);

  const isDirty = (rule: PricingRule) => {
    const d = draft[rule.id];
    if (!d) return false;
    return (
      d.baseFare !== rule.baseFare ||
      d.perKm !== rule.perKm ||
      d.perMinute !== rule.perMinute ||
      d.minFare !== rule.minFare ||
      d.surgeMultiplier !== rule.surgeMultiplier ||
      d.active !== rule.active
    );
  };

  const handleChange = (id: string, patch: Partial<PricingRule>) => {
    setDraft((prev) => ({ ...prev, [id]: { ...prev[id], ...patch } }));
  };

  const handleSave = async (rule: PricingRule) => {
    const d = draft[rule.id];
    if (!d) return;
    setSavingId(rule.id);
    try {
      await update(d);
      showToast(
        t("toast.pricing_saved", { type: getTruckTypeLabel(t, rule.truckType) })
      );
    } finally {
      setSavingId(null);
    }
  };

  const handleReset = (rule: PricingRule) => {
    setDraft((prev) => ({ ...prev, [rule.id]: { ...rule } }));
  };

  const handleSaveSettings = async () => {
    if (!settingsDraft) return;
    setSavingSettings(true);
    try {
      const saved = await updatePlatformSettings(settingsDraft);
      setSettings(saved);
      setSettingsDraft(saved);
      showToast(t("toast.settings_saved"));
    } finally {
      setSavingSettings(false);
    }
  };

  const settingsDirty =
    settings &&
    settingsDraft &&
    (settings.commissionRate !== settingsDraft.commissionRate ||
      settings.serviceAreaRadiusKm !== settingsDraft.serviceAreaRadiusKm ||
      settings.maxDispatchDistanceKm !== settingsDraft.maxDispatchDistanceKm ||
      settings.waitGraceMinutes !== settingsDraft.waitGraceMinutes ||
      settings.waitMinutePriceDzd !== settingsDraft.waitMinutePriceDzd ||
      settings.serviceAreaCenter.lat !== settingsDraft.serviceAreaCenter.lat ||
      settings.serviceAreaCenter.lng !== settingsDraft.serviceAreaCenter.lng);

  if (!loaded) {
    return (
      <Stack spacing={2}>
        {Array.from({ length: 2 }).map((_, i) => (
          <Skeleton key={i} variant="rounded" height={220} />
        ))}
      </Stack>
    );
  }

  return (
    <Stack spacing={3}>
      <Card>
        <CardContent>
          <Typography variant="h6">{t("pricing.formula_title")}</Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
            <code>{t("pricing.formula_tashila")}</code>
          </Typography>
        </CardContent>
      </Card>

      {settingsDraft && (
        <Card>
          <CardContent>
            <Typography variant="h6" sx={{ mb: 2 }}>
              {t("pricing.commission_title")}
            </Typography>
            <TextField
              label={t("pricing.commission_rate_label")}
              type="number"
              value={Math.round(settingsDraft.commissionRate * 1000) / 10}
              onChange={(e) => {
                const pct = Number(e.target.value);
                setSettingsDraft({
                  ...settingsDraft,
                  commissionRate: Number.isFinite(pct) ? pct / 100 : 0.1,
                });
              }}
              InputProps={{
                endAdornment: (
                  <InputAdornment position="end">%</InputAdornment>
                ),
              }}
              sx={{ maxWidth: 200, mb: 3 }}
            />

            <Typography variant="h6" sx={{ mb: 2 }}>
              {t("pricing.wait_settings_title")}
            </Typography>
            <Stack direction="row" spacing={2} sx={{ mb: 3 }}>
              <TextField
                label={t("pricing.wait_grace_label")}
                type="number"
                value={settingsDraft.waitGraceMinutes ?? 5}
                onChange={(e) => {
                  const val = Number(e.target.value);
                  setSettingsDraft({
                    ...settingsDraft,
                    waitGraceMinutes: Number.isFinite(val) ? val : 5,
                  });
                }}
                sx={{ maxWidth: 200 }}
              />
              <TextField
                label={t("pricing.wait_price_label")}
                type="number"
                value={settingsDraft.waitMinutePriceDzd ?? 25}
                onChange={(e) => {
                  const val = Number(e.target.value);
                  setSettingsDraft({
                    ...settingsDraft,
                    waitMinutePriceDzd: Number.isFinite(val) ? val : 25,
                  });
                }}
                sx={{ maxWidth: 200 }}
              />
            </Stack>

            <Typography variant="h6" sx={{ mb: 1 }}>
              {t("pricing.geofence_title")}
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              {t("pricing.geofence_body")}
            </Typography>
            <ServiceAreaMap
              center={settingsDraft.serviceAreaCenter}
              radiusKm={settingsDraft.serviceAreaRadiusKm}
              onCenterChange={(center) =>
                setSettingsDraft({ ...settingsDraft, serviceAreaCenter: center })
              }
            />
            <Stack direction="row" spacing={2} alignItems="center" sx={{ mt: 2 }}>
              <Typography variant="body2" sx={{ minWidth: 120 }}>
                {t("pricing.geofence_radius_label")}
              </Typography>
              <Slider
                value={settingsDraft.serviceAreaRadiusKm}
                min={5}
                max={1000}
                step={5}
                valueLabelDisplay="auto"
                onChange={(_, v) =>
                  setSettingsDraft({
                    ...settingsDraft,
                    serviceAreaRadiusKm: v as number,
                  })
                }
                sx={{ flex: 1 }}
              />
              <Typography variant="body2" sx={{ minWidth: 64 }}>
                {settingsDraft.serviceAreaRadiusKm} km
              </Typography>
            </Stack>
            <Stack direction="row" spacing={2} alignItems="center" sx={{ mt: 2, mb: 1 }}>
              <Typography variant="body2" sx={{ minWidth: 120 }}>
                {t("pricing.max_dispatch_distance_label")}
              </Typography>
              <Slider
                value={settingsDraft.maxDispatchDistanceKm ?? 50}
                min={1}
                max={200}
                step={1}
                valueLabelDisplay="auto"
                onChange={(_, v) =>
                  setSettingsDraft({
                    ...settingsDraft,
                    maxDispatchDistanceKm: v as number,
                  })
                }
                sx={{ flex: 1 }}
              />
              <Typography variant="body2" sx={{ minWidth: 64 }}>
                {settingsDraft.maxDispatchDistanceKm ?? 50} km
              </Typography>
            </Stack>
            <Button
              sx={{ mt: 2 }}
              disabled={!settingsDirty || savingSettings}
              onClick={handleSaveSettings}
            >
              {savingSettings ? t("common.saving") : t("pricing.save_scope")}
            </Button>
          </CardContent>
        </Card>
      )}

      {rules.map((rule) => {
        const d = draft[rule.id] ?? rule;
        const dirty = isDirty(rule);
        return (
          <PricingCard
            key={rule.id}
            rule={d}
            dirty={dirty}
            saving={savingId === rule.id}
            onChange={(patch) => handleChange(rule.id, patch)}
            onSave={() => handleSave(rule)}
            onReset={() => handleReset(rule)}
          />
        );
      })}
    </Stack>
  );
}

function PricingCard({
  rule,
  dirty,
  saving,
  onChange,
  onSave,
  onReset,
}: {
  rule: PricingRule;
  dirty: boolean;
  saving: boolean;
  onChange: (patch: Partial<PricingRule>) => void;
  onSave: () => void;
  onReset: () => void;
}) {
  const { t } = useTranslation();
  const formatDzd = useFormatDzd();
  const previewDistance = 8;
  const previewFare = useMemo(
    () => Math.ceil((rule.baseFare + rule.perKm * previewDistance) / 100) * 100,
    [rule.baseFare, rule.perKm],
  );
  const [apiPreviewFare, setApiPreviewFare] = useState<number | null>(null);

  useEffect(() => {
    let cancelled = false;
    estimateFareFromApi(
      { lat: 22.785, lng: 5.523, address: "Tamanrasset Center" },
      { lat: 22.812, lng: 5.451, address: "Tamanrasset Airport" },
      rule.truckType,
    )
      .then((fare) => {
        if (!cancelled) setApiPreviewFare(fare);
      })
      .catch(() => {
        if (!cancelled) setApiPreviewFare(null);
      });
    return () => {
      cancelled = true;
    };
  }, [rule.truckType, rule.baseFare, rule.perKm]);

  return (
    <Card>
      <CardContent>
        <Stack
          direction={{ xs: "column", sm: "row" }}
          alignItems={{ sm: "center" }}
          justifyContent="space-between"
          spacing={1.5}
          sx={{ mb: 2 }}
        >
          <Stack direction="row" alignItems="center" spacing={1.5}>
            <Box
              sx={{
                width: 44,
                height: 44,
                borderRadius: 2,
                bgcolor: `${brand.orange}1F`,
                color: brand.orange,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              <LocalShippingRoundedIcon />
            </Box>
            <Box>
              <Typography variant="h6" sx={{ fontWeight: 800 }}>
                {getTruckTypeLabel(t, rule.truckType)}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                {rule.active ? t("pricing.active") : t("pricing.inactive")}
              </Typography>
            </Box>
          </Stack>
          <Stack direction="row" alignItems="center" spacing={1.5}>
            <Typography variant="caption" color="text.secondary">
              {t("pricing.active_toggle")}
            </Typography>
            <Switch
              checked={rule.active}
              onChange={(_, v) => onChange({ active: v })}
            />
          </Stack>
        </Stack>

        <Box
          sx={{
            display: "grid",
            gridTemplateColumns: {
              xs: "1fr",
              sm: "repeat(2, 1fr)",
            },
            gap: 2,
          }}
        >
          <NumberField
            label={t("pricing.base_fare")}
            value={rule.baseFare}
            onChange={(v) => onChange({ baseFare: v })}
          />
          <NumberField
            label={t("pricing.per_km")}
            value={rule.perKm}
            onChange={(v) => onChange({ perKm: v })}
          />
        </Box>

        <Stack
          direction={{ xs: "column", sm: "row" }}
          alignItems={{ sm: "center" }}
          justifyContent="space-between"
          spacing={1.5}
          sx={{ mt: 2 }}
        >
          <Box
            sx={{
              p: 1.5,
              borderRadius: 2,
              backgroundColor: brand.bg,
              border: `1px solid ${brand.border}`,
              flex: 1,
            }}
          >
            <Typography variant="caption" color="text.secondary">
              {t("pricing.example_label")}
            </Typography>
            <Typography variant="h6" sx={{ fontWeight: 800 }}>
              {t("pricing.example_rule_fare", { amount: formatDzd(previewFare) })}
            </Typography>
            <Typography variant="caption" color="text.secondary" sx={{ display: "block", mt: 1 }}>
              {t("pricing.example_api_fare", {
                amount:
                  apiPreviewFare != null ? formatDzd(apiPreviewFare) : "—",
              })}
            </Typography>
          </Box>
          <Stack direction="row" spacing={1.5}>
            <Button variant="outlined" disabled={!dirty} onClick={onReset}>
              {t("common.reset")}
            </Button>
            <Button disabled={!dirty || saving} onClick={onSave}>
              {saving ? t("common.saving") : t("common.save_changes")}
            </Button>
          </Stack>
        </Stack>
      </CardContent>
    </Card>
  );
}

function NumberField({
  label,
  value,
  onChange,
  step = 1,
  adornment = "DZD",
}: {
  label: string;
  value: number;
  onChange: (v: number) => void;
  step?: number;
  adornment?: string;
}) {
  return (
    <TextField
      label={label}
      type="number"
      value={Number.isFinite(value) ? value : 0}
      onChange={(e) => {
        const next = Number(e.target.value);
        onChange(Number.isFinite(next) ? next : 0);
      }}
      inputProps={{ step, min: 0 }}
      InputProps={{
        endAdornment: (
          <InputAdornment position="end">
            <Typography variant="caption" color="text.secondary">
              {adornment}
            </Typography>
          </InputAdornment>
        ),
      }}
    />
  );
}
