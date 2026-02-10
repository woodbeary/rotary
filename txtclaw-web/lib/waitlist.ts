const WAITLIST_SUCCESS_PATH = "/waitlist/success"

function withNoTrailingSlash(url: string) {
  return url.endsWith("/") ? url.slice(0, -1) : url
}

export function getWaitlistSuccessRedirectUrl() {
  const appUrl = process.env.NEXT_PUBLIC_APP_URL

  if (!appUrl) {
    return WAITLIST_SUCCESS_PATH
  }

  return `${withNoTrailingSlash(appUrl)}${WAITLIST_SUCCESS_PATH}`
}

