import { expect, test } from "@playwright/test"

const DOC_ROUTES: Array<{ path: string; mustContain: string }> = [
  { path: "/quickstart.md", mustContain: "TXT CLAW Quickstart" },
  { path: "/quickstart.md", mustContain: "pnpm i txtclaw" },
  { path: "/agents.md", mustContain: "TXT CLAW Developer API" },
  { path: "/openapi.yaml", mustContain: "openapi:" },
  { path: "/pricing.md", mustContain: "Dev API Pricing" },
  { path: "/api-keys.md", mustContain: "API Keys" },
  { path: "/cli.md", mustContain: "TXT CLAW CLI" },
  { path: "/mcp.md", mustContain: "TXT CLAW MCP" },
  { path: "/skills.md", mustContain: "TXT CLAW Skills" },
  { path: "/byok.md", mustContain: "BYOK" },
  { path: "/routing.md", mustContain: "Routing" },
  { path: "/rate-limits.md", mustContain: "HTTP `429`" },
  { path: "/security.md", mustContain: "Security" },
]

const RENDERED_DOC_ROUTES: Array<{ path: string; mustContain: string }> = [
  { path: "/developers/docs/quickstart", mustContain: "Quickstart" },
  { path: "/developers/docs/agents", mustContain: "TXT CLAW Developer API" },
  { path: "/developers/docs/openapi", mustContain: "openapi:" },
  { path: "/developers/docs/api-keys", mustContain: "TXT CLAW API Keys" },
  { path: "/developers/docs/pricing", mustContain: "Dev API Pricing" },
  { path: "/developers/docs/cli", mustContain: "TXT CLAW CLI" },
  { path: "/developers/docs/mcp", mustContain: "TXT CLAW MCP" },
  { path: "/developers/docs/skills", mustContain: "TXT CLAW Skills" },
  { path: "/developers/docs/byok", mustContain: "Bring Your Own Key" },
  { path: "/developers/docs/routing", mustContain: "Routing" },
  { path: "/developers/docs/rate-limits", mustContain: "TXT CLAW Rate Limits" },
  { path: "/developers/docs/security", mustContain: "Security" },
]

test("docs endpoints are live and contain expected content", async ({ request }) => {
  for (const route of DOC_ROUTES) {
    const res = await request.get(route.path)
    expect(res.ok(), `${route.path} should return 200`).toBeTruthy()
    const body = await res.text()
    expect(body, `${route.path} should contain ${route.mustContain}`).toContain(route.mustContain)
  }
})

test("rendered developer docs pages are live", async ({ request }) => {
  for (const route of RENDERED_DOC_ROUTES) {
    const res = await request.get(route.path)
    expect(res.ok(), `${route.path} should return 200`).toBeTruthy()
    const body = await res.text()
    expect(body, `${route.path} should contain ${route.mustContain}`).toContain(route.mustContain)
  }
})

test("custom 404 page renders for missing docs slug", async ({ request }) => {
  const res = await request.get("/developers/docs/does-not-exist")
  expect(res.status()).toBe(404)
  const body = await res.text()
  expect(body).toContain("404: this page slipped between pixels")
})

test("developers page is mobile-friendly and links to key/dashboard + docs", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto("/developers")

  await expect(page.getByRole("heading", { name: "TXT CLAW for Developers" })).toBeVisible()
  await expect(page.getByText("Pasteable Docs Links")).toBeVisible()
  await expect(page.getByRole("link", { name: "/quickstart.md" })).toBeVisible()

  const hasHorizontalScroll = await page.evaluate(() => {
    const root = document.documentElement
    return root.scrollWidth > window.innerWidth + 2
  })
  expect(hasHorizontalScroll).toBeFalsy()
})
