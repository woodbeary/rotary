import { randomBytes } from "node:crypto"
import fs from "node:fs"
import path from "node:path"
import { createClerkClient } from "@clerk/backend"
import { clerk, clerkSetup } from "@clerk/testing/playwright"
import { expect, test } from "@playwright/test"

// This suite handles secrets (API keys). Disable Playwright traces to avoid leaking
// response bodies (the newly-created API key) into CI artifacts.
test.use({ trace: "off" })

function env(name: string): string {
  return String(process.env[name] || "").trim()
}

function loadEnvFile(filePath: string) {
  try {
    if (!fs.existsSync(filePath)) return
    const contents = fs.readFileSync(filePath, "utf8")
    for (const line of contents.split(/\r?\n/)) {
      const trimmed = line.trim()
      if (!trimmed || trimmed.startsWith("#")) continue
      const idx = trimmed.indexOf("=")
      if (idx <= 0) continue
      const key = trimmed.slice(0, idx).trim()
      if (!key || process.env[key]) continue
      let value = trimmed.slice(idx + 1).trim()
      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1)
      }
      process.env[key] = value
    }
  } catch {
    // Ignore dotenv parsing errors; tests can still run if env is provided explicitly.
  }
}

loadEnvFile(path.join(process.cwd(), ".env.local"))

// @clerk/testing helpers expect CLERK_SECRET_KEY / NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY.
if (!process.env.CLERK_SECRET_KEY) {
  const fallback = String(process.env.E2E_CLERK_SECRET_KEY || "").trim()
  if (fallback) process.env.CLERK_SECRET_KEY = fallback
}

test.beforeAll(async () => {
  // Fetch and install the Clerk testing token so bot protection doesn't break E2E.
  await clerkSetup({ dotenv: false })
})

async function fillFirstVisible(page: any, selectors: string[], value: string, timeoutMs = 15_000) {
  const started = Date.now()
  while (Date.now() - started < timeoutMs) {
    for (const sel of selectors) {
      const locator = page.locator(sel).first()
      if (await locator.count()) {
        if (await locator.isVisible().catch(() => false)) {
          await locator.fill(value)
          return true
        }
      }
    }
    await page.waitForTimeout(150)
  }
  return false
}

async function clickFirstVisible(page: any, selectors: string[], timeoutMs = 15_000) {
  const started = Date.now()
  while (Date.now() - started < timeoutMs) {
    for (const sel of selectors) {
      const locator = page.locator(sel).first()
      if (await locator.count()) {
        if (await locator.isVisible().catch(() => false)) {
          await locator.click()
          return true
        }
      }
    }
    await page.waitForTimeout(150)
  }
  return false
}

function randomPassword(): string {
  return `pw_${randomBytes(18).toString("base64url")}`
}

async function provisionVerifiedClerkUser(): Promise<{
  userId: string
  email: string
  password: string
  cleanup: () => Promise<void>
}> {
  const secretKey = env("E2E_CLERK_SECRET_KEY") || env("CLERK_SECRET_KEY")
  if (!secretKey) {
    throw new Error(
      "Missing CLERK_SECRET_KEY (or E2E_CLERK_SECRET_KEY) for Clerk E2E provisioning.",
    )
  }

  const clerk = createClerkClient({ secretKey })

  const email = `e2e+${Date.now()}_${randomBytes(4).toString("hex")}@example.com`
  const password = randomPassword()
  const username = `e2e_${Date.now()}_${randomBytes(3).toString("hex")}`

  const user = (await clerk.users.createUser({
    emailAddress: [email],
    password,
    username,
    skipPasswordChecks: true,
    legalAcceptedAt: new Date(),
  })) as any

  const emailAddressId: string | undefined =
    String(user?.primaryEmailAddressId || "").trim() || user?.emailAddresses?.[0]?.id

  if (!emailAddressId) {
    throw new Error("Clerk user provisioning failed: missing email address id.")
  }

  await clerk.emailAddresses.updateEmailAddress(emailAddressId, { verified: true, primary: true })
  await clerk.users
    .updateUser(String(user.id), { primaryEmailAddressID: emailAddressId })
    .catch(() => {})

  return {
    userId: String(user.id),
    email,
    password,
    cleanup: async () => {
      await clerk.users.deleteUser(String(user.id)).catch(() => {})
    },
  }
}

test("signed-out dashboard routes redirect to sign-in", async ({ page }) => {
  await page.goto("/dashboard/api-keys")
  await expect(page).toHaveURL(/\/sign-in/i)
})

test("signed-in user can create/revoke key and call /v1/status", async ({
  page,
  context,
  request,
}) => {
  test.setTimeout(150_000)

  const provisioned = await provisionVerifiedClerkUser()

  const apiBaseUrl =
    env("TXTCLAW_E2E_API_BASE_URL") ||
    env("E2E_API_BASE_URL") ||
    "https://txtclaw-sms-e2e.lopez731.workers.dev"

  try {
    // Deterministic Clerk auth: bypass bot protection via @clerk/testing token, then
    // sign in using a ticket for the provisioned Clerk user.
    await page.goto("/developers")
    await clerk.signIn({ page, emailAddress: provisioned.email })

    await page.goto("/dashboard/api-keys")
    await page.getByRole("button", { name: "Generate key" }).waitFor({ timeout: 60_000 })

    const origin = new URL(page.url()).origin
    await context.grantPermissions(["clipboard-read", "clipboard-write"], {
      origin,
    })

    const createResponsePromise = page.waitForResponse((resp) => {
      return resp.url().includes("/api/console/api-keys") && resp.request().method() === "POST"
    })

    await page.getByRole("button", { name: "Generate key" }).click()
    const createResponse = await createResponsePromise
    expect(createResponse.ok()).toBeTruthy()

    const created = (await createResponse.json()) as any
    expect(Boolean(created?.ok)).toBeTruthy()
    expect(typeof created?.apiKey === "string").toBeTruthy()
    expect(String(created?.apiKey || "").startsWith("vck_")).toBeTruthy()
    expect(typeof created?.record?.keyId === "string").toBeTruthy()

    // Copy env snippet should succeed (clipboard permissions granted above).
    await page.getByRole("button", { name: "Copy snippet" }).click()
    const clipboardText = await page.evaluate(() => navigator.clipboard.readText())
    expect(clipboardText.includes('TXTCLAW_API_KEY="vck_')).toBeTruthy()
    expect(clipboardText.includes("TXTCLAW_API_BASE_URL=")).toBeTruthy()

    // Runtime API proof: /v1/status works with the new key.
    const statusRes = await request.get(`${apiBaseUrl.replace(/\/+$/, "")}/v1/status`, {
      headers: { Authorization: `Bearer ${String(created.apiKey)}` },
    })
    expect(statusRes.ok()).toBeTruthy()
    const statusJson = (await statusRes.json().catch(() => null)) as any
    expect(Boolean(statusJson?.ok)).toBeTruthy()
    expect(typeof statusJson?.trace_id === "string").toBeTruthy()

    // Revoke through the dashboard API (server-to-server to the worker).
    const revokeRes = await page.request.post("/api/console/api-keys/revoke", {
      data: { keyId: String(created.record.keyId) },
    })
    expect(revokeRes.ok()).toBeTruthy()

    const statusAfterRevoke = await request.get(`${apiBaseUrl.replace(/\/+$/, "")}/v1/status`, {
      headers: { Authorization: `Bearer ${String(created.apiKey)}` },
    })
    expect(statusAfterRevoke.status()).toBe(401)
  } finally {
    await provisioned.cleanup()
  }
})
