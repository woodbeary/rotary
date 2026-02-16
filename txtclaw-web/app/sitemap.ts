import type { MetadataRoute } from "next"

function getBaseUrl(): string {
  const raw = String(process.env.NEXT_PUBLIC_APP_URL || "").trim()
  const fallback = "https://www.txtclaw.com"
  if (!raw) return fallback

  try {
    const url = new URL(raw.startsWith("http") ? raw : `https://${raw}`)
    if (url.hostname === "txtclaw.com") url.hostname = "www.txtclaw.com"
    return url.toString().replace(/\/+$/, "")
  } catch {
    return fallback
  }
}

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = getBaseUrl()
  const now = new Date()

  const paths = [
    "/",
    "/developers",
    "/openclaw-api",
    "/openclaw-mcp",
    "/openclaw-sdk",
    "/sms-agent-api",
    "/api-reference",
    "/changelog",
    "/privacy",
    "/terms",
    "/sms-consent",
    "/waitlist",
  ]

  const docs = ["/agents.md", "/openapi.yaml", "/llms.txt"]

  return [
    ...paths.map((path) => ({
      url: `${baseUrl}${path}`,
      lastModified: now,
    })),
    ...docs.map((path) => ({
      url: `${baseUrl}${path}`,
      lastModified: now,
    })),
  ]
}
