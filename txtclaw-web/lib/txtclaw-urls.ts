// Until a dedicated custom domain exists, the Worker domain is the canonical base URL.
export const DEFAULT_PUBLIC_API_BASE_URL = "https://txtclaw-sms-e2e.lopez731.workers.dev"
export const DEFAULT_CONSOLE_API_BASE_URL = "https://txtclaw-sms-e2e.lopez731.workers.dev"

function normalizeBaseUrl(raw: string | undefined, fallback: string): string {
  const value = String(raw || "")
    .trim()
    .replace(/\/+$/, "")
  if (!value) return fallback

  try {
    const url = new URL(value.startsWith("http") ? value : `https://${value}`)
    return url.toString().replace(/\/+$/, "")
  } catch {
    return fallback
  }
}

export function getPublicAppUrl(): string {
  const fallback = "https://www.txtclaw.com"
  const url = normalizeBaseUrl(process.env.NEXT_PUBLIC_APP_URL, fallback)
  try {
    const parsed = new URL(url)
    if (parsed.hostname === "txtclaw.com") parsed.hostname = "www.txtclaw.com"
    return parsed.toString().replace(/\/+$/, "")
  } catch {
    return fallback
  }
}

export function getPublicApiBaseUrl(): string {
  return normalizeBaseUrl(process.env.NEXT_PUBLIC_TXTCLAW_API_BASE_URL, DEFAULT_PUBLIC_API_BASE_URL)
}

export function getConsoleBaseUrl(): string {
  // Server-side base URL for console endpoints (service-to-service). Keep the preview fallback so
  // local/dev environments work even without explicit configuration.
  return normalizeBaseUrl(process.env.TXTCLAW_CONSOLE_BASE_URL, DEFAULT_CONSOLE_API_BASE_URL)
}

export function joinUrl(baseUrl: string, pathname: string): string {
  const base = String(baseUrl || "").replace(/\/+$/, "")
  const path = String(pathname || "").replace(/^\/+/, "")
  if (!base) return `/${path}`
  if (!path) return base
  return `${base}/${path}`
}
