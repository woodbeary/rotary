import { expect, test } from "@playwright/test"

const DOC_ROUTES: Array<{ path: string; mustContain: string }> = [
  { path: "/quickstart.md", mustContain: "TXT CLAW Quickstart" },
  { path: "/quickstart.md", mustContain: "pnpm dlx txtclaw@latest init" },
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

test("docs endpoints are live and contain expected content", async ({ request }) => {
  for (const route of DOC_ROUTES) {
    const res = await request.get(route.path)
    expect(res.ok(), `${route.path} should return 200`).toBeTruthy()
    const body = await res.text()
    expect(body, `${route.path} should contain ${route.mustContain}`).toContain(route.mustContain)
  }
})

test("developers page is mobile-friendly and links to key/dashboard + docs", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto("/developers")

  await expect(page.getByRole("heading", { name: "TXT CLAW for Developers" })).toBeVisible()
  await expect(page.getByText("Pasteable Docs Links")).toBeVisible()
  await expect(page.locator('a[href="/quickstart.md"]')).toBeVisible()

  const hasHorizontalScroll = await page.evaluate(() => {
    const root = document.documentElement
    return root.scrollWidth > window.innerWidth + 2
  })
  expect(hasHorizontalScroll).toBeFalsy()
})
