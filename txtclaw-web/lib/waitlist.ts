const WAITLIST_SUCCESS_PATH = "/waitlist/success"

function withNoTrailingSlash(url: string) {
  return url.endsWith("/") ? url.slice(0, -1) : url
}

export function getWaitlistSuccessRedirectUrl() {
  const appUrl = process.env.NEXT_PUBLIC_APP_URL?.trim()

  if (!appUrl) {
    return WAITLIST_SUCCESS_PATH
  }

  const normalizedAppUrl =
    appUrl.startsWith("http://") || appUrl.startsWith("https://")
      ? appUrl
      : `https://${appUrl}`

  try {
    const url = new URL(normalizedAppUrl)
    return `${withNoTrailingSlash(url.toString())}${WAITLIST_SUCCESS_PATH}`
  } catch {
    return WAITLIST_SUCCESS_PATH
  }
}
