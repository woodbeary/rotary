const publishableKey = process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY?.trim() ?? ""

const isLiveKey = publishableKey.startsWith("pk_live_")
const isDevelopment = process.env.NODE_ENV !== "production"
export const CLERK_DISABLED_FOR_LOCAL_LIVE_KEY = isDevelopment && isLiveKey

export const CLERK_ENABLED =
  publishableKey.length > 0 && !CLERK_DISABLED_FOR_LOCAL_LIVE_KEY
