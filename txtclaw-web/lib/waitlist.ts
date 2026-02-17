const WAITLIST_SUCCESS_PATH = "/waitlist/success"
export const WAITLIST_JOINED_STORAGE_KEY = "txtclaw.waitlist.joined"

function withNoTrailingSlash(url: string) {
  return url.endsWith("/") ? url.slice(0, -1) : url
}

export function getWaitlistSuccessRedirectUrl() {
  const appUrl = process.env.NEXT_PUBLIC_APP_URL?.trim()

  if (!appUrl) {
    return WAITLIST_SUCCESS_PATH
  }

  const normalizedAppUrl =
    appUrl.startsWith("http://") || appUrl.startsWith("https://") ? appUrl : `https://${appUrl}`

  try {
    const url = new URL(normalizedAppUrl)
    return `${withNoTrailingSlash(url.toString())}${WAITLIST_SUCCESS_PATH}`
  } catch {
    return WAITLIST_SUCCESS_PATH
  }
}

export function isWaitlistMarkedJoinedInBrowser() {
  if (typeof window === "undefined") return false

  try {
    return window.localStorage.getItem(WAITLIST_JOINED_STORAGE_KEY) === "1"
  } catch {
    return false
  }
}

export function markWaitlistJoinedInBrowser() {
  if (typeof window === "undefined") return

  try {
    window.localStorage.setItem(WAITLIST_JOINED_STORAGE_KEY, "1")
  } catch {
    // Ignore storage failures (private mode, disabled storage, etc.).
  }
}
