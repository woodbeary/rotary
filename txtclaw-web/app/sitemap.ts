import { DEV_DOCS } from "@/lib/dev-docs"
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
    "/byok",
    "/openclaw-api",
    "/openclaw-router",
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

  const docs = [
    "/quickstart.md",
    "/agents.md",
    "/openapi.yaml",
    "/pricing.md",
    "/api-keys.md",
    "/cli.md",
    "/mcp.md",
    "/byok.md",
    "/routing.md",
    "/skills.md",
    "/rate-limits.md",
    "/security.md",
    "/llms.txt",
  ]

  const renderedDocs = DEV_DOCS.map((doc) => `/developers/docs/${doc.slug}`)

  return [
    ...paths.map((path) => ({
      url: `${baseUrl}${path}`,
      lastModified: now,
    })),
    ...renderedDocs.map((path) => ({
      url: `${baseUrl}${path}`,
      lastModified: now,
    })),
    ...docs.map((path) => ({
      url: `${baseUrl}${path}`,
      lastModified: now,
    })),
  ]
}
