import { defineConfig, devices } from "@playwright/test"

const baseURL = (process.env.BASE_URL || "http://127.0.0.1:3100").trim()
const useExternalServer = Boolean(process.env.BASE_URL)

export default defineConfig({
  testDir: "./tests",
  timeout: 60_000,
  retries: 0,
  use: {
    baseURL,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: useExternalServer
    ? undefined
    : {
        command: "pnpm dev -p 3100",
        url: "http://127.0.0.1:3100",
        reuseExistingServer: true,
        timeout: 120_000,
      },
})
