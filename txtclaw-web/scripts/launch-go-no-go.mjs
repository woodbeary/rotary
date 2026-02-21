#!/usr/bin/env node

import { spawnSync } from "node:child_process"
import process from "node:process"

function parseBoolean(raw) {
  const normalized = String(raw || "")
    .trim()
    .toLowerCase()
  return ["1", "true", "yes", "on"].includes(normalized)
}

function parseArgValue(flag) {
  const eqPrefix = `${flag}=`
  for (let index = 0; index < process.argv.length; index += 1) {
    const current = process.argv[index]
    if (current === flag) {
      return String(process.argv[index + 1] || "").trim()
    }
    if (current.startsWith(eqPrefix)) {
      return current.slice(eqPrefix.length).trim()
    }
  }
  return ""
}

function hasFlag(flag) {
  return process.argv.includes(flag)
}

const options = {
  baseUrl:
    parseArgValue("--base-url") ||
    String(process.env.BASE_URL || process.env.LAUNCH_BASE_URL || ""),
  skipSmoke: hasFlag("--skip-smoke"),
  skipRepoGates: hasFlag("--skip-repo-gates"),
  allowUnverifiedProvider: hasFlag("--allow-unverified-provider"),
  allowUnverifiedOps: hasFlag("--allow-unverified-ops"),
  json: hasFlag("--json"),
}

/** @type {Array<{name: string, status: "PASS"|"FAIL"|"WARN"|"SKIP", detail: string}>} */
const checks = []

function addCheck(name, status, detail) {
  checks.push({ name, status, detail })
}

function runPnpmScript(name) {
  const result = spawnSync("pnpm", ["run", name], {
    stdio: "inherit",
    env: process.env,
    shell: false,
  })
  return result.status === 0
}

function assertEnvExact(name, expected, allowWarn) {
  const raw = String(process.env[name] || "").trim()
  if (!raw) {
    if (allowWarn) {
      addCheck(name, "WARN", "Missing in current shell. Verify in production deployment env.")
    } else {
      addCheck(name, "FAIL", "Missing in current shell. Required for strict launch.")
    }
    return
  }
  if (raw !== expected) {
    if (allowWarn) {
      addCheck(name, "WARN", `Expected ${expected}, found ${raw}. Verify production value.`)
    } else {
      addCheck(name, "FAIL", `Expected ${expected}, found ${raw}.`)
    }
    return
  }
  addCheck(name, "PASS", `Set to ${expected}.`)
}

function assertAck(name, description, allowWarn) {
  const enabled = parseBoolean(process.env[name])
  if (enabled) {
    addCheck(name, "PASS", description)
    return
  }
  if (allowWarn) {
    addCheck(name, "WARN", `Unverified: ${description}`)
  } else {
    addCheck(name, "FAIL", `Missing ack for: ${description}`)
  }
}

async function fetchWithTimeout(url, init = {}, timeoutMs = 15_000) {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), timeoutMs)
  try {
    return await fetch(url, { ...init, signal: controller.signal })
  } finally {
    clearTimeout(timer)
  }
}

async function runSmokeChecks() {
  if (options.skipSmoke) {
    addCheck("Smoke gate", "SKIP", "Skipped by --skip-smoke.")
    return
  }
  if (!options.baseUrl) {
    addCheck("Smoke gate", "FAIL", "Missing --base-url (or BASE_URL / LAUNCH_BASE_URL).")
    return
  }

  const baseUrl = options.baseUrl.replace(/\/+$/, "")
  const docsChecks = [
    { path: "/quickstart.md", contains: "TXT CLAW Quickstart" },
    { path: "/openapi.yaml", contains: "openapi:" },
    { path: "/rate-limits.md", contains: "HTTP `429`" },
  ]

  for (const check of docsChecks) {
    try {
      const res = await fetchWithTimeout(`${baseUrl}${check.path}`)
      const body = await res.text()
      if (!res.ok) {
        addCheck(`Smoke ${check.path}`, "FAIL", `Expected 200, got ${res.status}.`)
        continue
      }
      if (!body.includes(check.contains)) {
        addCheck(`Smoke ${check.path}`, "FAIL", `Response missing marker: ${check.contains}`)
        continue
      }
      addCheck(`Smoke ${check.path}`, "PASS", "Endpoint returned expected content.")
    } catch (error) {
      addCheck(
        `Smoke ${check.path}`,
        "FAIL",
        error instanceof Error ? error.message : "Failed to fetch endpoint.",
      )
    }
  }

  try {
    const developersRes = await fetchWithTimeout(`${baseUrl}/developers`)
    const developersBody = await developersRes.text()
    if (!developersRes.ok) {
      addCheck("Smoke /developers", "FAIL", `Expected 200, got ${developersRes.status}.`)
    } else if (!developersBody.includes("TXT CLAW for Developers")) {
      addCheck("Smoke /developers", "FAIL", "Page missing expected heading text.")
    } else {
      addCheck("Smoke /developers", "PASS", "Developers page rendered expected content.")
    }
  } catch (error) {
    addCheck(
      "Smoke /developers",
      "FAIL",
      error instanceof Error ? error.message : "Failed to fetch developers page.",
    )
  }

  try {
    const payRes = await fetchWithTimeout(`${baseUrl}/pay`, { redirect: "manual" })
    const location = String(payRes.headers.get("location") || "")
    const expectedPath = parseBoolean(process.env.NEXT_PUBLIC_SMS_GATEWAY_LIVE) ? "/" : "/waitlist"
    const resolved = new URL(location || "/", baseUrl)
    if (!location) {
      addCheck("Smoke /pay", "FAIL", "Expected redirect but no Location header was returned.")
    } else if (resolved.pathname !== expectedPath) {
      addCheck(
        "Smoke /pay",
        "FAIL",
        `Expected redirect path ${expectedPath}, got ${resolved.pathname}.`,
      )
    } else {
      addCheck("Smoke /pay", "PASS", `Redirect target matched expected path ${expectedPath}.`)
    }
  } catch (error) {
    addCheck("Smoke /pay", "FAIL", error instanceof Error ? error.message : "Failed to fetch /pay.")
  }
}

function runRepoGates() {
  if (options.skipRepoGates) {
    addCheck("Repo gate", "SKIP", "Skipped by --skip-repo-gates.")
    return
  }

  const scripts = ["biome:check", "typecheck", "lint", "build", "test:e2e"]
  for (const name of scripts) {
    const ok = runPnpmScript(name)
    addCheck(`Repo ${name}`, ok ? "PASS" : "FAIL", ok ? "Command passed." : "Command failed.")
    if (!ok) return
  }
}

function runOpsChecks() {
  assertEnvExact("NEXT_PUBLIC_SMS_GATEWAY_LIVE", "true", options.allowUnverifiedOps)
  assertEnvExact("TXTCLAW_MAX_NEW_PER_DAY", "5", options.allowUnverifiedOps)
  assertEnvExact("TXTCLAW_MAX_ACTIVE_USERS", "50", options.allowUnverifiedOps)
  assertEnvExact("TXTCLAW_UNPAID_PROMPTS_PER_DAY", "2", options.allowUnverifiedOps)

  assertAck(
    "LAUNCH_ACK_WEBHOOK_SECRETS_CURRENT",
    "Twilio/Square webhook secrets confirmed current and not test-overridden.",
    options.allowUnverifiedOps,
  )
  assertAck(
    "LAUNCH_ACK_ONCALL_VISIBILITY",
    "On-call visibility confirmed for webhook/send/timeout failures.",
    options.allowUnverifiedOps,
  )
}

function runProviderChecks() {
  assertAck(
    "LAUNCH_ACK_SMS_ONBOARDING_CHECKOUT",
    "Real inbound onboarding SMS returns expected response + checkout path.",
    options.allowUnverifiedProvider,
  )
  assertAck(
    "LAUNCH_ACK_SMS_STOP_HELP_START",
    "STOP/HELP/START behavior verified end-to-end.",
    options.allowUnverifiedProvider,
  )
  assertAck(
    "LAUNCH_ACK_SMS_WEBHOOK_SIGNATURES",
    "Signed Twilio and Square webhook paths validated.",
    options.allowUnverifiedProvider,
  )
  assertAck(
    "LAUNCH_ACK_SMS_PAYMENT_ACTIVATION",
    "Completed payment path activates account in controlled lane.",
    options.allowUnverifiedProvider,
  )
}

function printReportAndExit() {
  const counts = {
    pass: checks.filter((entry) => entry.status === "PASS").length,
    fail: checks.filter((entry) => entry.status === "FAIL").length,
    warn: checks.filter((entry) => entry.status === "WARN").length,
    skip: checks.filter((entry) => entry.status === "SKIP").length,
  }

  const decision = counts.fail > 0 ? "RED" : "GREEN"
  const report = {
    generatedAt: new Date().toISOString(),
    options,
    counts,
    decision,
    checks,
  }

  if (options.json) {
    console.log(JSON.stringify(report, null, 2))
  } else {
    console.log("")
    console.log("Controlled funnel launch checklist")
    console.log("---------------------------------")
    for (const entry of checks) {
      console.log(`[${entry.status}] ${entry.name}: ${entry.detail}`)
    }
    console.log("")
    console.log(
      `Totals -> PASS ${counts.pass} | FAIL ${counts.fail} | WARN ${counts.warn} | SKIP ${counts.skip}`,
    )
    console.log("")
    console.log(`Launch decision: ${decision}`)
  }

  process.exit(decision === "RED" ? 1 : 0)
}

async function main() {
  runRepoGates()
  runOpsChecks()
  runProviderChecks()
  await runSmokeChecks()
  printReportAndExit()
}

void main()
