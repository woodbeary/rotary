import { expect, test } from "@playwright/test"

const COMPLIANCE_ROUTES = [
  "/",
  "/sms-consent",
  "/privacy",
  "/terms",
  "/developers",
  "/changelog",
  "/waitlist",
]

test("compliance CTA is visible on public routes", async ({ page }) => {
  for (const route of COMPLIANCE_ROUTES) {
    await page.goto(route)
    await expect(page.getByText(/Text us:/i).first()).toBeVisible()
    await expect(page.getByText("+1 (855) 408-8675").first()).toBeVisible()
    await expect(page.getByText(/Reply STOP to opt out\./i).first()).toBeVisible()
    await expect(page.getByRole("link", { name: /Privacy Policy/i }).first()).toBeVisible()
    await expect(page.getByRole("link", { name: /Terms and Conditions/i }).first()).toBeVisible()
  }
})

test("sticky compliance strip is mobile-readable with no horizontal overflow", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto("/")

  await expect(page.getByText(/Text us:/i).first()).toBeVisible()
  await expect(page.getByText("+1 (855) 408-8675").first()).toBeVisible()

  const hasHorizontalScroll = await page.evaluate(() => {
    const root = document.documentElement
    return root.scrollWidth > window.innerWidth + 2
  })
  expect(hasHorizontalScroll).toBeFalsy()
})

test("compliance UI is hidden on dashboard/admin routes when they render", async ({ page }) => {
  const hiddenRoutes = ["/dashboard/api-keys", "/admin/compliance"]

  for (const route of hiddenRoutes) {
    await page.goto(route)
    const pathname = await page.evaluate(() => window.location.pathname)

    if (pathname.startsWith("/dashboard") || pathname.startsWith("/admin")) {
      await expect(page.getByText("+1 (855) 408-8675")).toHaveCount(0)
      await expect(page.getByText(/Text us:/i)).toHaveCount(0)
    }
  }
})
