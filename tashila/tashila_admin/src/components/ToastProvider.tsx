"use client";

import { createContext, useCallback, useContext, useState } from "react";
import Snackbar from "@mui/material/Snackbar";
import Alert, { type AlertColor } from "@mui/material/Alert";

type ToastFn = (message: string, severity?: AlertColor) => void;

const ToastContext = createContext<ToastFn>(() => {});

export function useToast() {
  return useContext(ToastContext);
}

type ToastState = {
  open: boolean;
  message: string;
  severity: AlertColor;
};

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<ToastState>({
    open: false,
    message: "",
    severity: "success",
  });

  const showToast = useCallback<ToastFn>((message, severity = "success") => {
    setState({ open: true, message, severity });
  }, []);

  return (
    <ToastContext.Provider value={showToast}>
      {children}
      <Snackbar
        open={state.open}
        autoHideDuration={3500}
        onClose={() => setState((s) => ({ ...s, open: false }))}
        anchorOrigin={{ vertical: "bottom", horizontal: "right" }}
      >
        <Alert
          onClose={() => setState((s) => ({ ...s, open: false }))}
          severity={state.severity}
          variant="filled"
          sx={{ borderRadius: 2 }}
        >
          {state.message}
        </Alert>
      </Snackbar>
    </ToastContext.Provider>
  );
}
