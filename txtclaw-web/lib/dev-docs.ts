export type DevDocKind = "markdown" | "yaml" | "text"

export type DevDoc = {
  slug: string
  title: string
  rawPath: `/${string}`
  kind: DevDocKind
}

export const DEV_DOCS = [
  { slug: "quickstart", title: "Quickstart", rawPath: "/quickstart.md", kind: "markdown" },
  { slug: "agents", title: "Agents", rawPath: "/agents.md", kind: "markdown" },
  { slug: "openapi", title: "OpenAPI", rawPath: "/openapi.yaml", kind: "yaml" },
  { slug: "api-keys", title: "API Keys", rawPath: "/api-keys.md", kind: "markdown" },
  { slug: "pricing", title: "Pricing", rawPath: "/pricing.md", kind: "markdown" },
  { slug: "cli", title: "CLI", rawPath: "/cli.md", kind: "markdown" },
  { slug: "mcp", title: "MCP", rawPath: "/mcp.md", kind: "markdown" },
  { slug: "skills", title: "Skills", rawPath: "/skills.md", kind: "markdown" },
  { slug: "byok", title: "BYOK", rawPath: "/byok.md", kind: "markdown" },
  { slug: "routing", title: "Routing", rawPath: "/routing.md", kind: "markdown" },
  { slug: "rate-limits", title: "Rate Limits", rawPath: "/rate-limits.md", kind: "markdown" },
  { slug: "security", title: "Security", rawPath: "/security.md", kind: "markdown" },
] as const satisfies readonly DevDoc[]

export const DEV_DOCS_BY_SLUG = Object.fromEntries(
  DEV_DOCS.map((doc) => [doc.slug, doc]),
) as Record<string, DevDoc>

export const DEV_DOCS_BY_RAW_PATH = Object.fromEntries(
  DEV_DOCS.map((doc) => [doc.rawPath, doc]),
) as Record<string, DevDoc>

export function getRenderedDevDocHref(slug: string): string {
  return `/developers/docs/${slug}`
}

export function getRenderedDevDocHrefForRawPath(rawPath: string): string | null {
  const doc = DEV_DOCS_BY_RAW_PATH[rawPath as keyof typeof DEV_DOCS_BY_RAW_PATH]
  return doc ? getRenderedDevDocHref(doc.slug) : null
}

export function maybeRewriteDevDocHref(href: string | undefined): string | null {
  const value = String(href || "").trim()
  if (!value) return null
  if (value.startsWith("#")) return null
  if (value.startsWith("mailto:")) return null
  if (value.startsWith("tel:")) return null

  // Direct raw-path match: "/quickstart.md" -> "/developers/docs/quickstart"
  if (value.startsWith("/")) {
    return getRenderedDevDocHrefForRawPath(value)
  }

  // Absolute URL match (e.g. https://www.txtclaw.com/quickstart.md)
  if (value.startsWith("http://") || value.startsWith("https://")) {
    try {
      const url = new URL(value)
      return getRenderedDevDocHrefForRawPath(url.pathname)
    } catch {
      return null
    }
  }

  return null
}
