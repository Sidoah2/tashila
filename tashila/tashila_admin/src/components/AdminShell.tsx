"use client";

import { useEffect, useMemo, useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import Link from "next/link";
import AppBar from "@mui/material/AppBar";
import Avatar from "@mui/material/Avatar";
import Badge from "@mui/material/Badge";
import Box from "@mui/material/Box";
import Divider from "@mui/material/Divider";
import Drawer from "@mui/material/Drawer";
import IconButton from "@mui/material/IconButton";
import List from "@mui/material/List";
import ListItem from "@mui/material/ListItem";
import ListItemButton from "@mui/material/ListItemButton";
import ListItemIcon from "@mui/material/ListItemIcon";
import ListItemText from "@mui/material/ListItemText";
import Menu from "@mui/material/Menu";
import MenuItem from "@mui/material/MenuItem";
import Toolbar from "@mui/material/Toolbar";
import Typography from "@mui/material/Typography";
import { useTheme } from "@mui/material/styles";
import useMediaQuery from "@mui/material/useMediaQuery";
import DashboardRoundedIcon from "@mui/icons-material/DashboardRounded";
import GroupRoundedIcon from "@mui/icons-material/GroupRounded";
import LocalShippingRoundedIcon from "@mui/icons-material/LocalShippingRounded";
import RouteRoundedIcon from "@mui/icons-material/RouteRounded";
import SendRoundedIcon from "@mui/icons-material/SendRounded";
import PaymentsRoundedIcon from "@mui/icons-material/PaymentsRounded";
import LogoutRoundedIcon from "@mui/icons-material/LogoutRounded";
import MenuRoundedIcon from "@mui/icons-material/MenuRounded";
import AdminPanelSettingsRoundedIcon from "@mui/icons-material/AdminPanelSettingsRounded";
import ManageAccountsRoundedIcon from "@mui/icons-material/ManageAccountsRounded";
import { useAuthStore } from "@/lib/store/auth";
import { useDriversStore } from "@/lib/store/drivers";
import { useAdminRealtime } from "@/lib/realtime/useAdminRealtime";
import Logo from "./Logo";
import LanguageMenu from "./LanguageMenu";
import { brand } from "@/theme/colors";
import { useTranslation } from "@/i18n/useTranslation";

const DRAWER_WIDTH = 264;

type NavItem = {
  labelKey: string;
  href: string;
  icon: React.ReactNode;
  badgeKey?: "pendingApprovals";
};

const NAV: NavItem[] = [
  { labelKey: "nav.dashboard", href: "/", icon: <DashboardRoundedIcon /> },
  { labelKey: "nav.users", href: "/users", icon: <GroupRoundedIcon /> },
  {
    labelKey: "nav.drivers",
    href: "/drivers",
    icon: <LocalShippingRoundedIcon />,
    badgeKey: "pendingApprovals",
  },
  { labelKey: "nav.trips", href: "/trips", icon: <RouteRoundedIcon /> },
  { labelKey: "nav.dispatch", href: "/trips/dispatch", icon: <SendRoundedIcon /> },
  { labelKey: "nav.pricing", href: "/pricing", icon: <PaymentsRoundedIcon /> },
];

export default function AdminShell({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const theme = useTheme();
  const isDesktop = useMediaQuery(theme.breakpoints.up("md"));
  const [mobileOpen, setMobileOpen] = useState(false);
  const [menuAnchor, setMenuAnchor] = useState<null | HTMLElement>(null);
  const { t } = useTranslation();

  const session = useAuthStore((s) => s.session);
  const hydrated = useAuthStore((s) => s.hydrated);
  const hydrate = useAuthStore((s) => s.hydrate);
  const logout = useAuthStore((s) => s.logout);

  const drivers = useDriversStore((s) => s.drivers);
  const loadDrivers = useDriversStore((s) => s.load);

  useEffect(() => {
    if (!hydrated) hydrate();
  }, [hydrate, hydrated]);

  useEffect(() => {
    if (hydrated && !session) {
      router.replace("/login");
    }
  }, [hydrated, session, router]);

  useEffect(() => {
    if (session) loadDrivers();
  }, [session, loadDrivers]);

  useAdminRealtime(Boolean(session));

  const pendingApprovals = useMemo(
    () => drivers.filter((d) => d.approvalStatus === "pending").length,
    [drivers]
  );

  const handleNavClick = () => {
    if (!isDesktop) setMobileOpen(false);
  };

  const handleLogout = () => {
    logout();
    router.replace("/login");
  };

  const isActive = (href: string) => {
    if (href === "/") return pathname === "/";
    return pathname === href || pathname.startsWith(`${href}/`);
  };

  const drawerContent = (
    <Box
      sx={{
        height: "100%",
        display: "flex",
        flexDirection: "column",
        bgcolor: brand.card,
      }}
    >
      <Box sx={{ p: 2.25, pl: 2.5 }}>
        <Logo />
      </Box>
      <Divider />
      <List sx={{ py: 1, flex: 1 }}>
        {NAV.map((item) => {
          const badgeCount =
            item.badgeKey === "pendingApprovals" ? pendingApprovals : 0;
          return (
            <ListItem key={item.href} disablePadding>
              <ListItemButton
                component={Link}
                href={item.href}
                onClick={handleNavClick}
                selected={isActive(item.href)}
              >
                <ListItemIcon sx={{ minWidth: 36 }}>
                  {badgeCount > 0 ? (
                    <Badge color="error" badgeContent={badgeCount}>
                      {item.icon}
                    </Badge>
                  ) : (
                    item.icon
                  )}
                </ListItemIcon>
                <ListItemText
                  primary={t(item.labelKey)}
                  primaryTypographyProps={{ fontWeight: 600 }}
                />
              </ListItemButton>
            </ListItem>
          );
        })}
        {/* Super admin only nav items */}
        {session?.role === "super_admin" && (
          <ListItem disablePadding>
            <ListItemButton
              component={Link}
              href="/admin-accounts"
              onClick={handleNavClick}
              selected={isActive("/admin-accounts")}
            >
              <ListItemIcon sx={{ minWidth: 36 }}>
                <AdminPanelSettingsRoundedIcon />
              </ListItemIcon>
              <ListItemText
                primary="Admin Accounts"
                primaryTypographyProps={{ fontWeight: 600 }}
              />
            </ListItemButton>
          </ListItem>
        )}
      </List>
    </Box>
  );

  if (!hydrated || !session) {
    return (
      <Box
        sx={{
          minHeight: "100vh",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <Typography color="text.secondary">{t("common.loading")}</Typography>
      </Box>
    );
  }

  return (
    <Box sx={{ display: "flex", minHeight: "100vh", bgcolor: brand.bg }}>
      <AppBar
        position="fixed"
        sx={{
          width: { md: `calc(100% - ${DRAWER_WIDTH}px)` },
          ml: { md: `${DRAWER_WIDTH}px` },
          zIndex: (z) => z.zIndex.drawer + 1,
        }}
      >
        <Toolbar sx={{ gap: 1 }}>
          <IconButton
            edge="start"
            onClick={() => setMobileOpen(true)}
            sx={{ display: { md: "none" } }}
            aria-label="menu"
          >
            <MenuRoundedIcon />
          </IconButton>
          <Box sx={{ flex: 1 }}>
            <Typography variant="h6" sx={{ fontWeight: 800 }}>
              {pageTitle(pathname, t)}
            </Typography>
            <Typography variant="caption" color="text.secondary">
              {pageSubtitle(pathname, t)}
            </Typography>
          </Box>
          <LanguageMenu />
          <IconButton
            onClick={(e) => setMenuAnchor(e.currentTarget)}
            sx={{ p: 0.5 }}
            aria-label="account menu"
          >
            <Avatar
              sx={{
                bgcolor: `${brand.orange}22`,
                color: brand.orange,
                width: 36,
                height: 36,
                fontWeight: 800,
              }}
            >
              {session.email[0]?.toUpperCase() ?? "A"}
            </Avatar>
          </IconButton>
          <Menu
            anchorEl={menuAnchor}
            open={Boolean(menuAnchor)}
            onClose={() => setMenuAnchor(null)}
            anchorOrigin={{ vertical: "bottom", horizontal: "right" }}
            transformOrigin={{ vertical: "top", horizontal: "right" }}
          >
            <Box sx={{ px: 2, py: 1 }}>
              <Typography variant="body2" sx={{ fontWeight: 700 }}>
                {session.name || session.email}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                {session.role?.replace("_", " ")}
              </Typography>
            </Box>
            <Divider />
            <MenuItem
              component={Link}
              href="/settings"
              onClick={() => setMenuAnchor(null)}
            >
              <ListItemIcon>
                <ManageAccountsRoundedIcon fontSize="small" />
              </ListItemIcon>
              Account Settings
            </MenuItem>
            <MenuItem
              onClick={() => {
                setMenuAnchor(null);
                handleLogout();
              }}
            >
              <ListItemIcon>
                <LogoutRoundedIcon fontSize="small" />
              </ListItemIcon>
              {t("common.logout")}
            </MenuItem>
          </Menu>
        </Toolbar>
      </AppBar>

      <Box
        component="nav"
        sx={{ width: { md: DRAWER_WIDTH }, flexShrink: { md: 0 } }}
      >
        <Drawer
          variant="temporary"
          open={mobileOpen}
          onClose={() => setMobileOpen(false)}
          ModalProps={{ keepMounted: true }}
          sx={{
            display: { xs: "block", md: "none" },
            "& .MuiDrawer-paper": { width: DRAWER_WIDTH },
          }}
        >
          {drawerContent}
        </Drawer>
        <Drawer
          variant="permanent"
          open
          sx={{
            display: { xs: "none", md: "block" },
            "& .MuiDrawer-paper": { width: DRAWER_WIDTH, boxSizing: "border-box" },
          }}
        >
          {drawerContent}
        </Drawer>
      </Box>

      <Box
        component="main"
        sx={{
          flexGrow: 1,
          p: { xs: 2, md: 3 },
          width: { md: `calc(100% - ${DRAWER_WIDTH}px)` },
          mt: 8,
        }}
      >
        {children}
      </Box>
    </Box>
  );
}

type T = (key: string, params?: Record<string, string | number>) => string;

function pageTitle(pathname: string, t: T): string {
  if (pathname === "/") return t("page.dashboard_title");
  if (pathname.startsWith("/users")) return t("page.users_title");
  if (pathname.startsWith("/drivers/new")) return t("page.drivers_new_title");
  if (pathname.startsWith("/drivers/")) return t("page.drivers_detail_title");
  if (pathname.startsWith("/drivers")) return t("page.drivers_title");
  if (pathname.startsWith("/trips/dispatch")) return t("page.dispatch_title");
  if (pathname.startsWith("/trips")) return t("page.trips_title");
  if (pathname.startsWith("/pricing")) return t("page.pricing_title");
  if (pathname.startsWith("/admin-accounts")) return "Admin Accounts";
  if (pathname.startsWith("/settings")) return "Account Settings";
  return t("app.name");
}

function pageSubtitle(pathname: string, t: T): string {
  if (pathname === "/") return t("page.dashboard_subtitle");
  if (pathname.startsWith("/users")) return t("page.users_subtitle");
  if (pathname.startsWith("/drivers/new")) return t("page.drivers_new_subtitle");
  if (pathname.startsWith("/drivers/")) return t("page.drivers_detail_subtitle");
  if (pathname.startsWith("/drivers")) return t("page.drivers_subtitle");
  if (pathname.startsWith("/trips/dispatch")) return t("page.dispatch_subtitle");
  if (pathname.startsWith("/trips")) return t("page.trips_subtitle");
  if (pathname.startsWith("/pricing")) return t("page.pricing_subtitle");
  if (pathname.startsWith("/admin-accounts")) return "Manage dashboard admin users";
  if (pathname.startsWith("/settings")) return "Update your profile and credentials";
  return "";
}
