export const ROUTES = {
  HOME:     "/",
  DISCOVER: "/search",
  LIBRARY:  "/library",
  SCHEDULE: "/schedule",
  SETTINGS: "/settings",
  PROFILE: "/profile",
} as const;

export type Route = (typeof ROUTES)[keyof typeof ROUTES];