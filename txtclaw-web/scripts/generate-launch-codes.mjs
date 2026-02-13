#!/usr/bin/env node

import { createHmac, randomBytes } from "node:crypto";

const CODE_PREFIX = "TXT100";
const DEFAULT_CAMPAIGN_ID = "x_launch_2026_02";
const DEFAULT_GRANT_CENTS = 10000;
const DEFAULT_COUNT = 10;
const MAX_COUNT = 10000;

function printUsageAndExit() {
  console.error("Usage: pnpm codes:generate --count 50 [--campaign x_launch_2026_02] [--grant-cents 10000] [--secret <value>]");
  process.exit(1);
}

function parsePositiveInt(rawValue, fallback) {
  if (rawValue == null || String(rawValue).trim() === "") return fallback;
  const parsed = Number(rawValue);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }
  return Math.floor(parsed);
}

function parseArgs(argv) {
  const result = {
    count: undefined,
    campaign: undefined,
    grantCents: undefined,
    secret: undefined,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];

    if (token === "--help" || token === "-h") {
      printUsageAndExit();
    }

    if (token === "--count") {
      result.count = argv[i + 1];
      i += 1;
      continue;
    }
    if (token.startsWith("--count=")) {
      result.count = token.slice("--count=".length);
      continue;
    }

    if (token === "--campaign") {
      result.campaign = argv[i + 1];
      i += 1;
      continue;
    }
    if (token.startsWith("--campaign=")) {
      result.campaign = token.slice("--campaign=".length);
      continue;
    }

    if (token === "--grant-cents") {
      result.grantCents = argv[i + 1];
      i += 1;
      continue;
    }
    if (token.startsWith("--grant-cents=")) {
      result.grantCents = token.slice("--grant-cents=".length);
      continue;
    }

    if (token === "--secret") {
      result.secret = argv[i + 1];
      i += 1;
      continue;
    }
    if (token.startsWith("--secret=")) {
      result.secret = token.slice("--secret=".length);
      continue;
    }

    console.error(`Unknown argument: ${token}`);
    printUsageAndExit();
  }

  return result;
}

function signingMessage({ campaignId, amountCents, codeId }) {
  return `v1:${campaignId}:${amountCents}:${codeId}`;
}

function generateCodeId() {
  return randomBytes(6).toString("hex").toUpperCase();
}

function signCode({ campaignId, amountCents, codeId, secret }) {
  return createHmac("sha256", secret)
    .update(signingMessage({ campaignId, amountCents, codeId }), "utf8")
    .digest("hex")
    .slice(0, 8)
    .toUpperCase();
}

function buildCode({ campaignId, amountCents, secret }) {
  const codeId = generateCodeId();
  const sig = signCode({ campaignId, amountCents, codeId, secret });
  return `${CODE_PREFIX}-${codeId}-${sig}`;
}

function main() {
  const args = parseArgs(process.argv.slice(2));

  const secret =
    (args.secret && String(args.secret).trim()) ||
    process.env.PROMO_CODE_SECRET?.trim();
  if (!secret) {
    console.error("Missing secret. Set PROMO_CODE_SECRET or pass --secret.");
    process.exit(1);
  }

  const campaignId =
    (args.campaign && String(args.campaign).trim()) ||
    process.env.PROMO_CAMPAIGN_ID?.trim() ||
    DEFAULT_CAMPAIGN_ID;
  const amountCents = parsePositiveInt(
    args.grantCents || process.env.PROMO_GRANT_CENTS,
    DEFAULT_GRANT_CENTS
  );
  const count = Math.min(
    parsePositiveInt(args.count, DEFAULT_COUNT),
    MAX_COUNT
  );

  const generated = new Set();
  while (generated.size < count) {
    generated.add(buildCode({ campaignId, amountCents, secret }));
  }

  console.log(
    `# campaign=${campaignId} grant_cents=${amountCents} count=${generated.size}`
  );
  for (const code of generated) {
    console.log(code);
  }
}

main();
