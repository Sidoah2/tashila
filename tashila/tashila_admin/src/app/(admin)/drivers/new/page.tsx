"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import Box from "@mui/material/Box";
import Card from "@mui/material/Card";
import CardContent from "@mui/material/CardContent";
import Stack from "@mui/material/Stack";
import Typography from "@mui/material/Typography";
import TextField from "@mui/material/TextField";
import Button from "@mui/material/Button";
import Chip from "@mui/material/Chip";
import Dialog from "@mui/material/Dialog";
import DialogTitle from "@mui/material/DialogTitle";
import DialogContent from "@mui/material/DialogContent";
import DialogActions from "@mui/material/DialogActions";
import FormHelperText from "@mui/material/FormHelperText";
import IconButton from "@mui/material/IconButton";
import InputAdornment from "@mui/material/InputAdornment";
import ArrowBackRoundedIcon from "@mui/icons-material/ArrowBackRounded";
import CloudUploadRoundedIcon from "@mui/icons-material/CloudUploadRounded";
import CheckRoundedIcon from "@mui/icons-material/CheckRounded";
import { useDriversStore } from "@/lib/store/drivers";
import { uploadDriverDocument, uploadDriverAvatar } from "@/lib/api/drivers";
import { useToast } from "@/components/ToastProvider";
import { getDocumentTypeLabel, getTruckTypeLabel } from "@/lib/labels";
import {
  DOCUMENT_TYPES,
  TRUCK_TYPES,
  type DocumentType,
} from "@/lib/types";
import { brand } from "@/theme/colors";
import { useTranslation } from "@/i18n/useTranslation";
import type { Translator } from "@/lib/labels";

function makeSchema(t: Translator) {
  return z.object({
    name: z.string().min(2, t("validation.name_min")),
    phone: z
      .string()
      .regex(/^(0\d{9}|\d{9})$/, t("validation.phone_min")),
    truckType: z.enum(["single_cabin", "double_cabin"] as const),
    vehicleColor: z.string().min(1, t("validation.vehicle_color_min")),
    vehicleModel: z.string().min(1, t("validation.vehicle_model_min")),
    vehiclePlate: z.string().min(2, t("validation.vehicle_plate_min")),
  });
}

type FormValues = z.infer<ReturnType<typeof makeSchema>>;

export default function NewDriverPage() {
  const router = useRouter();
  const { t } = useTranslation();
  const create = useDriversStore((s) => s.create);
  const showToast = useToast();
  const [docFiles, setDocFiles] = useState<Partial<Record<DocumentType, File>>>({});
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [phoneVal, setPhoneVal] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [previewType, setPreviewType] = useState<DocumentType | null>(null);

  const schema = useMemo(() => makeSchema(t), [t]);

  const {
    control,
    register,
    handleSubmit,
    setValue,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: "",
      phone: "",
      truckType: "single_cabin",
      vehicleColor: "",
      vehicleModel: "",
      vehiclePlate: "",
    },
  });

  const handleDocPick = (type: DocumentType, file: File | null) => {
    setDocFiles((prev) => {
      const next = { ...prev };
      if (file) next[type] = file;
      else delete next[type];
      return next;
    });
  };

  const onSubmit = handleSubmit(async (values) => {
    setSubmitting(true);
    try {
      const rawPhone = values.phone;
      const cleanPhone = rawPhone.startsWith("0")
        ? "+213" + rawPhone.slice(1)
        : "+213" + rawPhone;
      const driver = await create({
        name: values.name,
        phone: cleanPhone,
        truckType: values.truckType,
        vehicleColor: values.vehicleColor,
        vehicleModel: values.vehicleModel,
        vehiclePlate: values.vehiclePlate,
      });
      for (const [type, file] of Object.entries(docFiles) as [
        DocumentType,
        File,
      ][]) {
        if (file) await uploadDriverDocument(driver.id, type, file);
      }
      if (avatarFile) {
        await uploadDriverAvatar(driver.id, avatarFile);
      }
      showToast(t("toast.driver_created", { name: driver.name }));
      router.push(`/drivers/${driver.id}`);
    } catch (err: any) {
      console.error(err);
      showToast(err.message || t("common.error_occurred"), "error");
    } finally {
      setSubmitting(false);
    }
  });

  return (
    <Box sx={{ maxWidth: 760, mx: "auto" }}>
      <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
        <IconButton component={Link} href="/drivers" size="small">
          <ArrowBackRoundedIcon />
        </IconButton>
        <Typography color="text.secondary">
          {t("driver_new.back_to_drivers")}
        </Typography>
      </Stack>

      <Card>
        <CardContent>
          <Stack spacing={3} component="form" onSubmit={onSubmit}>
            <Box>
              <Typography variant="h5" sx={{ fontWeight: 800 }}>
                {t("driver_new.title")}
              </Typography>
              <Typography color="text.secondary">
                {t("driver_new.subtitle")}
              </Typography>
            </Box>

            <Stack spacing={2}>
              <TextField
                label={t("driver_new.full_name")}
                placeholder={t("driver_new.full_name_placeholder")}
                error={Boolean(errors.name)}
                helperText={errors.name?.message}
                {...register("name")}
              />
              <TextField
                label={t("driver_new.phone_with_country")}
                placeholder={phoneVal.startsWith("0") ? "0661452711" : "661452711"}
                error={Boolean(errors.phone)}
                helperText={
                  errors.phone?.message ??
                  t("driver_new.phone_helper_default_country")
                }
                dir="ltr"
                slotProps={{
                  input: {
                    startAdornment: (
                      <InputAdornment position="start" sx={{ dir: "ltr" }}>
                        +213
                      </InputAdornment>
                    ),
                  },
                }}
                inputProps={{
                  style: { textAlign: "left" },
                }}
                value={phoneVal}
                onChange={(e) => {
                  const val = e.target.value.replace(/\D/g, ""); // digits only
                  const max = val.startsWith("0") ? 10 : 9;
                  if (val.length <= max) {
                    setPhoneVal(val);
                    setValue("phone", val, { shouldValidate: true });
                  }
                }}
              />
              <Stack direction={{ xs: "column", sm: "row" }} spacing={2}>
                <TextField
                  label={t("driver_new.vehicle_model")}
                  placeholder={t("driver_new.vehicle_model_placeholder")}
                  error={Boolean(errors.vehicleModel)}
                  helperText={errors.vehicleModel?.message}
                  {...register("vehicleModel")}
                  sx={{ flex: 1 }}
                />
                <TextField
                  label={t("driver_new.vehicle_color")}
                  placeholder={t("driver_new.vehicle_color_placeholder")}
                  error={Boolean(errors.vehicleColor)}
                  helperText={errors.vehicleColor?.message}
                  {...register("vehicleColor")}
                  sx={{ flex: 1 }}
                />
              </Stack>
              <TextField
                label={t("driver_new.vehicle_plate")}
                placeholder={t("driver_new.vehicle_plate_placeholder")}
                error={Boolean(errors.vehiclePlate)}
                helperText={errors.vehiclePlate?.message}
                {...register("vehiclePlate")}
              />
            </Stack>

            <Box>
              <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1 }}>
                {t("driver_new.truck_type_section")}
              </Typography>
              <Controller
                control={control}
                name="truckType"
                render={({ field }) => (
                  <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                    {TRUCK_TYPES.map((tt) => {
                      const selected = field.value === tt;
                      return (
                        <Chip
                          key={tt}
                          label={getTruckTypeLabel(t, tt)}
                          onClick={() => field.onChange(tt)}
                          color={selected ? "primary" : "default"}
                          variant={selected ? "filled" : "outlined"}
                          sx={{ px: 2, py: 2.5, fontSize: 14 }}
                        />
                      );
                    })}
                  </Stack>
                )}
              />
              {errors.truckType && (
                <FormHelperText error>{errors.truckType.message}</FormHelperText>
              )}
            </Box>

            <Box>
              <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1 }}>
                {t("driver_new.avatar_section")}
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
                {t("driver_new.avatar_help")}
              </Typography>
              <Box
                component="label"
                sx={{
                  cursor: "pointer",
                  p: 2,
                  borderRadius: 2,
                  maxWidth: 240,
                  display: "block",
                  border: `2px dashed ${
                    avatarFile ? brand.success : brand.border
                  }`,
                  backgroundColor: avatarFile
                    ? `${brand.success}0F`
                    : brand.bg,
                  textAlign: "center",
                  transition: "all 0.15s",
                  "&:hover": { borderColor: brand.orange },
                }}
              >
                <input
                  type="file"
                  hidden
                  accept="image/jpeg,image/png,image/webp"
                  onChange={(e) => setAvatarFile(e.target.files?.[0] ?? null)}
                />
                {avatarFile ? (
                  <CheckRoundedIcon sx={{ color: brand.success }} />
                ) : (
                  <CloudUploadRoundedIcon
                    sx={{ color: brand.textSecondary }}
                  />
                )}
                <Typography
                  sx={{ fontWeight: 700, mt: 0.5 }}
                  variant="body2"
                >
                  {t("driver_new.avatar")}
                </Typography>
                <Typography variant="caption" color="text.secondary" sx={{ display: "block" }}>
                  {avatarFile
                    ? avatarFile.name
                    : t("driver_new.tap_to_upload")}
                </Typography>
              </Box>
            </Box>

            <Box>
              <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1 }}>
                {t("driver_new.documents_section")}
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
                {t("driver_new.documents_help")}
              </Typography>
              <Box
                sx={{
                  display: "grid",
                  gridTemplateColumns: { xs: "1fr", sm: "repeat(3, 1fr)" },
                  gap: 1.5,
                }}
              >
                {DOCUMENT_TYPES.map((type) => {
                  const uploaded = Boolean(docFiles[type]);
                  return (
                    <Box
                      key={type}
                      component="label"
                      sx={{
                        cursor: "pointer",
                        p: 2,
                        borderRadius: 2,
                        border: `2px dashed ${
                          uploaded ? brand.success : brand.border
                        }`,
                        backgroundColor: uploaded
                          ? `${brand.success}0F`
                          : brand.bg,
                        textAlign: "center",
                        transition: "all 0.15s",
                        "&:hover": { borderColor: brand.orange },
                      }}
                    >
                      <input
                        type="file"
                        hidden
                        accept="image/jpeg,image/png,image/webp"
                        onChange={(e) =>
                          handleDocPick(type, e.target.files?.[0] ?? null)
                        }
                      />
                      {uploaded ? (
                        <CheckRoundedIcon sx={{ color: brand.success }} />
                      ) : (
                        <CloudUploadRoundedIcon
                          sx={{ color: brand.textSecondary }}
                        />
                      )}
                      <Typography
                        sx={{ fontWeight: 700, mt: 0.5 }}
                        variant="body2"
                      >
                        {getDocumentTypeLabel(t, type)}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        {uploaded
                          ? docFiles[type]?.name ?? t("driver_new.uploaded")
                          : t("driver_new.tap_to_upload")}
                      </Typography>
                      <Button
                        type="button"
                        size="small"
                        sx={{ mt: 0.5 }}
                        onClick={(e) => {
                          e.stopPropagation();
                          setPreviewType(type);
                        }}
                      >
                        {t("driver_new.doc_preview_open")}
                      </Button>
                    </Box>
                  );
                })}
              </Box>
            </Box>

            <Stack
              direction="row"
              spacing={1.5}
              justifyContent="flex-end"
              sx={{ pt: 1 }}
            >
              <Button
                type="button"
                variant="outlined"
                component={Link}
                href="/drivers"
              >
                {t("common.cancel")}
              </Button>
              <Button type="submit" disabled={submitting} size="large">
                {submitting
                  ? t("driver_new.creating")
                  : t("driver_new.create_driver")}
              </Button>
            </Stack>
          </Stack>
        </CardContent>
      </Card>

      <Dialog
        open={Boolean(previewType)}
        onClose={() => setPreviewType(null)}
        fullWidth
        maxWidth="xs"
      >
        <DialogTitle>
          {previewType ? getDocumentTypeLabel(t, previewType) : ""}
        </DialogTitle>
        <DialogContent>
          {previewType && docFiles[previewType] ? (
            <Box sx={{ mt: 1.5, display: "flex", justifyContent: "center" }}>
              <img
                src={URL.createObjectURL(docFiles[previewType]!)}
                alt={getDocumentTypeLabel(t, previewType)}
                style={{ maxWidth: "100%", maxHeight: 300, objectFit: "contain", borderRadius: 8 }}
              />
            </Box>
          ) : (
            <Typography variant="body2" color="text.secondary">
              {t("driver_detail.doc_preview_body")}
            </Typography>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setPreviewType(null)}>{t("common.cancel")}</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
