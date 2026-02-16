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

export default function robots(): MetadataRoute.Robots {
  const baseUrl = getBaseUrl()
  return {
    rules: [
      {
        userAgent: "*",
        allow: "/",
        disallow: ["/api/", "/admin/", "/sign-in", "/subscribe", "/pay", "/paid"],
      },
    ],
    sitemap: `${baseUrl}/sitemap.xml`,
  }
}

