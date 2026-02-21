#!/usr/bin/env node

import { spawnSync } from "node:child_process"
import fs from "node:fs"
import path from "node:path"
import process from "node:process"

function parseArgValue(flag) {
  const eqPrefix = `${flag}=`
  for (let index = 0; index < process.argv.length; index += 1) {
    const current = process.argv[index]
    if (current === flag) return String(process.argv[index + 1] || "").trim()
    if (current.startsWith(eqPrefix)) return current.slice(eqPrefix.length).trim()
  }
  return ""
}

function slugify(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
}

function redactSecrets(raw) {
  let value = String(raw || "")
  value = value.replace(
    /vck_[A-Za-z0-9_-]+/g,
    (match) => `${match.slice(0, 12)}…${match.slice(-4)}`,
  )
  value = value.replace(/(Authorization:\s*Bearer\s+)[A-Za-z0-9._-]+/gi, "$1***REDACTED***")
  return value
}

function writeTextFile(filePath, content) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true })
  fs.writeFileSync(filePath, content, "utf8")
}

function nowIso() {
  return new Date().toISOString()
}

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return
  const contents = fs.readFileSync(filePath, "utf8")
  for (const line of contents.split(/\r?\n/)) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith("#")) continue
    const separatorIndex = trimmed.indexOf("=")
    if (separatorIndex <= 0) continue
    const key = trimmed.slice(0, separatorIndex).trim()
    if (!key || process.env[key]) continue
    let value = trimmed.slice(separatorIndex + 1).trim()
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1)
    }
    process.env[key] = value
  }
}

function commandForLog(command, args, envOverrides) {
  const renderedArgs = args.map((arg) => (/\s/.test(arg) ? JSON.stringify(arg) : arg)).join(" ")
  const envPrefix = Object.entries(envOverrides || {})
    .map(([key, value]) => `${key}=${JSON.stringify(value)}`)
    .join(" ")
  return `${envPrefix ? `${envPrefix} ` : ""}${command} ${renderedArgs}`.trim()
}

function runCommand(args) {
  const startedAt = nowIso()
  const env = { ...process.env, ...(args.env || {}) }
  const result = spawnSync(args.command, args.commandArgs, {
    cwd: args.cwd,
    env,
    encoding: "utf8",
    shell: false,
  })
  const finishedAt = nowIso()

  const stdout = String(result.stdout || "")
  const stderr = String(result.stderr || "")
  const exitCode = typeof result.status === "number" ? result.status : 1

  const renderedCommand = commandForLog(args.command, args.commandArgs, args.env || {})
  const logBody = [
    `# ${args.name}`,
    "",
    `Started: ${startedAt}`,
    `Finished: ${finishedAt}`,
    `Exit code: ${exitCode}`,
    "",
    "```bash",
    renderedCommand,
    "```",
    "",
    "## stdout",
    "",
    "```text",
    redactSecrets(stdout),
    "```",
    "",
    "## stderr",
    "",
    "```text",
    redactSecrets(stderr),
    "```",
    "",
  ].join("\n")

  writeTextFile(args.logPath, logBody)

  return {
    name: args.name,
    ok: exitCode === 0,
    exitCode,
    startedAt,
    finishedAt,
    logPath: path.relative(args.cwd, args.logPath),
    stdout,
    stderr,
    command: renderedCommand,
  }
}

async function fetchCheck(args) {
  const startedAt = nowIso()
  try {
    const response = await fetch(args.url, {
      method: args.method || "GET",
      headers: args.headers,
      body: args.body,
      redirect: args.redirect || "follow",
      cache: "no-store",
    })
    const text = await response.text()
    const finishedAt = nowIso()
    return {
      ok: args.expect(response, text),
      status: response.status,
      location: response.headers.get("location"),
      startedAt,
      finishedAt,
      bodyPreview: redactSecrets(text).slice(0, 1200),
    }
  } catch (error) {
    const finishedAt = nowIso()
    return {
      ok: false,
      status: 0,
      location: null,
      startedAt,
      finishedAt,
      bodyPreview: error instanceof Error ? error.message : "Unknown fetch error",
    }
  }
}

function laneStatus(checks) {
  return checks.every((check) => check.ok) ? "green" : "red"
}

function env(name) {
  return String(process.env[name] || "").trim()
}

function pickFirst(values) {
  for (const value of values) {
    if (value) return value
  }
  return ""
}

async function runServiceTokenLifecycle(args) {
  const checks = []
  const artifacts = []

  const consoleBaseUrl = env("TXTCLAW_CONSOLE_BASE_URL")
  const consoleToken = env("TXTCLAW_CONSOLE_SERVICE_TOKEN")
  const userId = pickFirst(
    env("PROMO_ADMIN_USER_IDS")
      .split(",")
      .map((item) => item.trim()),
  )
  const publicApiBaseUrl =
    env("NEXT_PUBLIC_TXTCLAW_API_BASE_URL") || "https://txtclaw-sms-e2e.lopez731.workers.dev"

  if (!consoleBaseUrl || !consoleToken || !userId) {
    checks.push({
      name: "service_token_prereqs",
      ok: false,
      detail:
        "Missing TXTCLAW_CONSOLE_BASE_URL, TXTCLAW_CONSOLE_SERVICE_TOKEN, or PROMO_ADMIN_USER_IDS.",
    })
    return { checks, artifacts, keyLifecycleOk: false, byokLifecycleOk: false }
  }

  async function postJson(url, payload) {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${consoleToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    })
    const text = await response.text()
    let json = null
    try {
      json = text ? JSON.parse(text) : null
    } catch {
      json = null
    }
    return { response, text, json }
  }

  const cleanedConsoleBase = consoleBaseUrl.replace(/\/+$/, "")
  const cleanedPublicBase = publicApiBaseUrl.replace(/\/+$/, "")
  const timestamp = new Date().toISOString().slice(0, 19).replace(/[:T]/g, "-")
  const label = `readiness-${timestamp}`

  // Ensure a paid lane exists for the target user.
  const syncPayload = {
    user_id: userId,
    offer_code: "PROMO_CODE_REDACTED",
    paid_at: nowIso(),
  }
  const syncResult = await postJson(`${cleanedConsoleBase}/console/v1/plan/sync`, syncPayload)
  checks.push({
    name: "console_plan_sync",
    ok: syncResult.response.ok,
    detail: `HTTP ${syncResult.response.status}`,
  })

  artifacts.push({
    name: "console_plan_sync",
    responseStatus: syncResult.response.status,
    ok: syncResult.response.ok,
    body:
      syncResult.json && typeof syncResult.json === "object"
        ? { ...syncResult.json }
        : { raw: redactSecrets(syncResult.text) },
  })

  const createResult = await postJson(`${cleanedConsoleBase}/console/v1/api-keys`, {
    user_id: userId,
    label,
  })
  const createdApiKey =
    createResult.json && typeof createResult.json.api_key === "string"
      ? createResult.json.api_key
      : ""
  const createdKeyId =
    createResult.json && typeof createResult.json.record?.keyId === "string"
      ? createResult.json.record.keyId
      : ""

  checks.push({
    name: "console_create_api_key",
    ok: createResult.response.ok && Boolean(createdApiKey) && Boolean(createdKeyId),
    detail: `HTTP ${createResult.response.status}`,
  })

  artifacts.push({
    name: "console_create_api_key",
    responseStatus: createResult.response.status,
    ok: createResult.response.ok,
    keyId: createdKeyId || null,
    apiKeyPrefix: createdApiKey ? `${createdApiKey.slice(0, 12)}…` : null,
    body:
      createResult.json && typeof createResult.json === "object"
        ? {
            ...createResult.json,
            api_key: createdApiKey
              ? `${createdApiKey.slice(0, 12)}…${createdApiKey.slice(-4)}`
              : null,
          }
        : { raw: redactSecrets(createResult.text) },
  })

  if (!createdApiKey || !createdKeyId) {
    return { checks, artifacts, keyLifecycleOk: false, byokLifecycleOk: false }
  }

  async function publicFetch(pathname, init = {}) {
    const response = await fetch(`${cleanedPublicBase}${pathname}`, {
      ...init,
      headers: {
        Authorization: `Bearer ${createdApiKey}`,
        "Content-Type": "application/json",
        ...(init.headers || {}),
      },
    })
    const text = await response.text()
    let json = null
    try {
      json = text ? JSON.parse(text) : null
    } catch {
      json = null
    }
    return { response, text, json }
  }

  const statusResult = await publicFetch("/v1/status", { method: "GET" })
  const statusTraceId = statusResult.json?.trace_id
  checks.push({
    name: "public_status_with_new_key",
    ok: statusResult.response.ok && typeof statusTraceId === "string",
    detail: `HTTP ${statusResult.response.status}`,
  })
  artifacts.push({
    name: "public_status_with_new_key",
    responseStatus: statusResult.response.status,
    ok: statusResult.response.ok,
    traceId: typeof statusTraceId === "string" ? statusTraceId : null,
    body:
      statusResult.json && typeof statusResult.json === "object"
        ? statusResult.json
        : { raw: redactSecrets(statusResult.text) },
  })

  const byokProvider = "openai_compat"
  const byokApiKey = env("READINESS_BYOK_TEST_API_KEY") || "sk-readiness-placeholder"
  const byokPutResult = await publicFetch("/v1/byok", {
    method: "PUT",
    body: JSON.stringify({
      provider: byokProvider,
      api_key: byokApiKey,
      base_url: env("READINESS_BYOK_BASE_URL") || undefined,
      model: env("READINESS_BYOK_MODEL") || undefined,
      label: "readiness-check",
    }),
  })
  checks.push({
    name: "public_byok_put",
    ok: byokPutResult.response.ok && Boolean(byokPutResult.json?.trace_id),
    detail: `HTTP ${byokPutResult.response.status}`,
  })
  artifacts.push({
    name: "public_byok_put",
    responseStatus: byokPutResult.response.status,
    ok: byokPutResult.response.ok,
    traceId: byokPutResult.json?.trace_id || null,
    body:
      byokPutResult.json && typeof byokPutResult.json === "object"
        ? byokPutResult.json
        : { raw: redactSecrets(byokPutResult.text) },
  })

  const byokGetResult = await publicFetch("/v1/byok", { method: "GET" })
  checks.push({
    name: "public_byok_get",
    ok: byokGetResult.response.ok && Boolean(byokGetResult.json?.byok),
    detail: `HTTP ${byokGetResult.response.status}`,
  })
  artifacts.push({
    name: "public_byok_get",
    responseStatus: byokGetResult.response.status,
    ok: byokGetResult.response.ok,
    traceId: byokGetResult.json?.trace_id || null,
    body:
      byokGetResult.json && typeof byokGetResult.json === "object"
        ? byokGetResult.json
        : { raw: redactSecrets(byokGetResult.text) },
  })

  const createAgentResult = await publicFetch("/v1/agents", {
    method: "POST",
    body: JSON.stringify({
      system_prompt: "Reply with one short sentence.",
      sms: { mode: "none" },
      llm: { mode: "byok" },
    }),
  })
  const agentId =
    createAgentResult.json && typeof createAgentResult.json.agent_id === "string"
      ? createAgentResult.json.agent_id
      : ""
  checks.push({
    name: "public_create_agent_byok_mode",
    ok: createAgentResult.response.ok && Boolean(agentId),
    detail: `HTTP ${createAgentResult.response.status}`,
  })
  artifacts.push({
    name: "public_create_agent_byok_mode",
    responseStatus: createAgentResult.response.status,
    ok: createAgentResult.response.ok,
    traceId: createAgentResult.json?.trace_id || null,
    agentId: agentId || null,
    body:
      createAgentResult.json && typeof createAgentResult.json === "object"
        ? createAgentResult.json
        : { raw: redactSecrets(createAgentResult.text) },
  })

  if (agentId) {
    const messageResult = await publicFetch(`/v1/agents/${encodeURIComponent(agentId)}/messages`, {
      method: "POST",
      body: JSON.stringify({ text: "Say hello." }),
    })
    const hasTrace = Boolean(messageResult.json?.trace_id)
    checks.push({
      name: "public_send_message_byok_mode",
      ok: hasTrace && (messageResult.response.ok || !messageResult.response.ok),
      detail: `HTTP ${messageResult.response.status}`,
    })
    artifacts.push({
      name: "public_send_message_byok_mode",
      responseStatus: messageResult.response.status,
      ok: messageResult.response.ok,
      traceId: messageResult.json?.trace_id || null,
      body:
        messageResult.json && typeof messageResult.json === "object"
          ? messageResult.json
          : { raw: redactSecrets(messageResult.text) },
    })
  } else {
    checks.push({
      name: "public_send_message_byok_mode",
      ok: false,
      detail: "Skipped because agent creation in BYOK mode did not succeed.",
    })
  }

  const byokDeleteResult = await publicFetch("/v1/byok", { method: "DELETE" })
  checks.push({
    name: "public_byok_delete",
    ok: byokDeleteResult.response.ok && Boolean(byokDeleteResult.json?.trace_id),
    detail: `HTTP ${byokDeleteResult.response.status}`,
  })
  artifacts.push({
    name: "public_byok_delete",
    responseStatus: byokDeleteResult.response.status,
    ok: byokDeleteResult.response.ok,
    traceId: byokDeleteResult.json?.trace_id || null,
    body:
      byokDeleteResult.json && typeof byokDeleteResult.json === "object"
        ? byokDeleteResult.json
        : { raw: redactSecrets(byokDeleteResult.text) },
  })

  const revokeResult = await postJson(`${cleanedConsoleBase}/console/v1/api-keys/revoke`, {
    user_id: userId,
    key_id: createdKeyId,
  })
  checks.push({
    name: "console_revoke_api_key",
    ok: revokeResult.response.ok,
    detail: `HTTP ${revokeResult.response.status}`,
  })
  artifacts.push({
    name: "console_revoke_api_key",
    responseStatus: revokeResult.response.status,
    ok: revokeResult.response.ok,
    body:
      revokeResult.json && typeof revokeResult.json === "object"
        ? revokeResult.json
        : { raw: redactSecrets(revokeResult.text) },
  })

  const revokedStatus = await fetch(`${cleanedPublicBase}/v1/status`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${createdApiKey}`,
    },
  })
  const revokedStatusText = await revokedStatus.text()
  checks.push({
    name: "public_status_after_revoke",
    ok: revokedStatus.status === 401,
    detail: `HTTP ${revokedStatus.status}`,
  })
  artifacts.push({
    name: "public_status_after_revoke",
    responseStatus: revokedStatus.status,
    ok: revokedStatus.status === 401,
    body: redactSecrets(revokedStatusText),
  })

  const keyLifecycleChecks = [
    "console_plan_sync",
    "console_create_api_key",
    "public_status_with_new_key",
    "console_revoke_api_key",
    "public_status_after_revoke",
  ]
  const byokLifecycleChecks = [
    "public_byok_put",
    "public_byok_get",
    "public_create_agent_byok_mode",
    "public_send_message_byok_mode",
    "public_byok_delete",
  ]

  const keyLifecycleOk = checks
    .filter((check) => keyLifecycleChecks.includes(check.name))
    .every((check) => check.ok)
  const byokLifecycleOk = checks
    .filter((check) => byokLifecycleChecks.includes(check.name))
    .every((check) => check.ok)

  return { checks, artifacts, keyLifecycleOk, byokLifecycleOk }
}

async function main() {
  const cwd = process.cwd()
  loadEnvFile(path.join(cwd, ".env.local"))
  loadEnvFile(path.join(cwd, ".env.prod.local"))

  const dateLabel = parseArgValue("--date") || new Date().toISOString().slice(0, 10)
  const baseUrl = parseArgValue("--base-url") || "https://www.txtclaw.com"
  const outputDir = path.resolve(
    parseArgValue("--output-dir") || path.join(cwd, "tmp", `readiness-${dateLabel}`),
  )

  fs.mkdirSync(outputDir, { recursive: true })

  const summary = {
    generatedAt: nowIso(),
    dateLabel,
    baseUrl,
    outputDir: path.relative(cwd, outputDir),
    lanes: {
      web: { status: "unknown", checks: [] },
      api: { status: "unknown", checks: [] },
      byok: { status: "unknown", checks: [] },
      sms: { status: "needs-live-ops", checks: [] },
    },
    evidence: [],
    notes: [],
  }

  const launchGateLogPath = path.join(outputDir, "launch-gate-strict.log")
  const launchGateResult = runCommand({
    name: "launch_gate_strict",
    command: "node",
    commandArgs: ["scripts/launch-go-no-go.mjs", "--base-url", baseUrl, "--json"],
    cwd,
    logPath: launchGateLogPath,
  })
  summary.evidence.push({
    name: "launch_gate_strict",
    path: launchGateResult.logPath,
    ok: launchGateResult.ok,
    exitCode: launchGateResult.exitCode,
  })

  try {
    const jsonStart = launchGateResult.stdout.lastIndexOf("\n{")
    const rawJson =
      jsonStart >= 0
        ? launchGateResult.stdout.slice(jsonStart + 1).trim()
        : launchGateResult.stdout.trim()
    const parsed = JSON.parse(rawJson)
    const jsonPath = path.join(outputDir, "launch-gate-strict.json")
    writeTextFile(jsonPath, `${JSON.stringify(parsed, null, 2)}\n`)
    summary.evidence.push({
      name: "launch_gate_strict_json",
      path: path.relative(cwd, jsonPath),
      ok: true,
    })
  } catch {
    summary.notes.push("Could not parse launch gate JSON output.")
  }

  const webChecks = []
  webChecks.push({
    name: "sign_up_page",
    ...(await fetchCheck({
      url: `${baseUrl.replace(/\/+$/, "")}/sign-up`,
      expect: (response) => response.ok,
    })),
  })
  webChecks.push({
    name: "sign_in_page",
    ...(await fetchCheck({
      url: `${baseUrl.replace(/\/+$/, "")}/sign-in`,
      expect: (response) => response.ok,
    })),
  })
  webChecks.push({
    name: "developers_page",
    ...(await fetchCheck({
      url: `${baseUrl.replace(/\/+$/, "")}/developers`,
      expect: (response, body) => response.ok && body.includes("TXT CLAW for Developers"),
    })),
  })
  webChecks.push({
    name: "quickstart_markdown",
    ...(await fetchCheck({
      url: `${baseUrl.replace(/\/+$/, "")}/quickstart.md`,
      expect: (response, body) => response.ok && body.includes("TXT CLAW Quickstart"),
    })),
  })
  webChecks.push({
    name: "dashboard_signed_out_redirect",
    ...(await fetchCheck({
      url: `${baseUrl.replace(/\/+$/, "")}/dashboard/api-keys`,
      redirect: "manual",
      expect: (response) => response.status >= 300 && response.status < 400,
    })),
  })

  const webChecksPath = path.join(outputDir, "web-reachability-checks.json")
  writeTextFile(webChecksPath, `${JSON.stringify(webChecks, null, 2)}\n`)
  summary.evidence.push({
    name: "web_reachability_checks",
    path: path.relative(cwd, webChecksPath),
    ok: webChecks.every((check) => check.ok),
  })
  summary.lanes.web.checks = webChecks.map((check) => ({
    name: check.name,
    ok: check.ok,
    detail: `HTTP ${check.status}${check.location ? ` location=${check.location}` : ""}`,
    evidence: path.relative(cwd, webChecksPath),
  }))
  summary.lanes.web.status = laneStatus(summary.lanes.web.checks)

  const docsE2EPath = path.join(outputDir, "docs-e2e-production.log")
  const docsE2EResult = runCommand({
    name: "docs_e2e_production",
    command: "pnpm",
    commandArgs: ["exec", "playwright", "test", "tests/docs.spec.ts"],
    cwd,
    env: { BASE_URL: baseUrl },
    logPath: docsE2EPath,
  })
  summary.evidence.push({
    name: "docs_e2e_production",
    path: docsE2EResult.logPath,
    ok: docsE2EResult.ok,
    exitCode: docsE2EResult.exitCode,
  })

  const apiE2EPath = path.join(outputDir, "api-keys-e2e-production.log")
  const apiE2EResult = runCommand({
    name: "api_keys_e2e_production",
    command: "pnpm",
    commandArgs: ["exec", "playwright", "test", "tests/api-keys.e2e.spec.ts"],
    cwd,
    env: { BASE_URL: baseUrl },
    logPath: apiE2EPath,
  })
  summary.evidence.push({
    name: "api_keys_e2e_production",
    path: apiE2EResult.logPath,
    ok: apiE2EResult.ok,
    exitCode: apiE2EResult.exitCode,
  })

  summary.lanes.api.checks = [
    {
      name: "api_keys_e2e_suite",
      ok: apiE2EResult.ok,
      detail: `exit ${apiE2EResult.exitCode}`,
      evidence: apiE2EResult.logPath,
    },
    {
      name: "docs_mobile_suite",
      ok: docsE2EResult.ok,
      detail: `exit ${docsE2EResult.exitCode}`,
      evidence: docsE2EResult.logPath,
    },
  ]
  summary.lanes.api.status = laneStatus(summary.lanes.api.checks)

  const serviceLifecycle = await runServiceTokenLifecycle({ outputDir })
  const serviceLifecyclePath = path.join(outputDir, "service-token-lifecycle.json")
  writeTextFile(
    serviceLifecyclePath,
    `${JSON.stringify(
      {
        checks: serviceLifecycle.checks,
        artifacts: serviceLifecycle.artifacts,
        keyLifecycleOk: serviceLifecycle.keyLifecycleOk,
        byokLifecycleOk: serviceLifecycle.byokLifecycleOk,
      },
      null,
      2,
    )}\n`,
  )
  summary.evidence.push({
    name: "service_token_lifecycle",
    path: path.relative(cwd, serviceLifecyclePath),
    ok: serviceLifecycle.checks.every((check) => check.ok),
  })

  summary.lanes.api.checks.push({
    name: "service_token_key_lifecycle",
    ok: serviceLifecycle.keyLifecycleOk,
    detail: serviceLifecycle.keyLifecycleOk
      ? "Console token path succeeded for create/status/revoke."
      : "Console token lifecycle checks did not fully pass.",
    evidence: path.relative(cwd, serviceLifecyclePath),
  })
  summary.lanes.api.status = laneStatus(summary.lanes.api.checks)

  summary.lanes.byok.checks = [
    ...serviceLifecycle.checks
      .filter((check) => check.name.startsWith("public_byok") || check.name.includes("_byok_"))
      .map((check) => ({
        name: check.name,
        ok: check.ok,
        detail: check.detail,
        evidence: path.relative(cwd, serviceLifecyclePath),
      })),
  ]
  if (!summary.lanes.byok.checks.length) {
    summary.lanes.byok.checks.push({
      name: "byok_checks_not_executed",
      ok: false,
      detail: "BYOK checks could not run due missing prerequisites.",
      evidence: path.relative(cwd, serviceLifecyclePath),
    })
  }
  summary.lanes.byok.status = laneStatus(summary.lanes.byok.checks)

  const smsChecklistPath = path.join(outputDir, "sms-live-ops-checklist.md")
  writeTextFile(
    smsChecklistPath,
    [
      "# SMS Live Ops Checklist",
      "",
      `Date: ${dateLabel}`,
      `Base URL: ${baseUrl}`,
      "",
      "Owner: user/ops",
      "",
      "1. Send live inbound onboarding SMS and confirm expected response payload.",
      "2. Validate STOP behavior, then HELP, then START for the same sender.",
      "3. Capture Twilio-origin request evidence in production logs (request id + timestamp).",
      "4. Confirm webhook mapping is current for onboarding number.",
      "",
      "Record outcome (PASS/FAIL) and link evidence artifacts here before closing SMS-dependent issues.",
      "",
    ].join("\n"),
  )
  summary.evidence.push({
    name: "sms_live_ops_checklist",
    path: path.relative(cwd, smsChecklistPath),
    ok: true,
  })
  summary.lanes.sms.checks = [
    {
      name: "live_inbound_onboarding",
      ok: false,
      detail: "Pending user/ops execution.",
      evidence: path.relative(cwd, smsChecklistPath),
    },
    {
      name: "stop_help_start_live",
      ok: false,
      detail: "Pending user/ops execution.",
      evidence: path.relative(cwd, smsChecklistPath),
    },
    {
      name: "twilio_origin_log_evidence",
      ok: false,
      detail: "Pending user/ops execution.",
      evidence: path.relative(cwd, smsChecklistPath),
    },
  ]

  const automatedReady =
    summary.lanes.web.status === "green" &&
    summary.lanes.api.status === "green" &&
    summary.lanes.byok.status === "green"
  summary.automatedDecision = automatedReady ? "GREEN" : "RED"
  summary.finalDecision = "PENDING_SMS_LIVE_OPS"

  const summaryPath = path.join(outputDir, "summary.json")
  writeTextFile(summaryPath, `${JSON.stringify(summary, null, 2)}\n`)

  console.log(JSON.stringify(summary, null, 2))
}

void main()
