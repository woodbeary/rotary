# TXT CLAW E2E Go-Live Checklist Report (Strict)

Date: 2026-02-11
Environment: staging worker `txtclaw-sms-e2e`
Run timestamp: 2026-02-11T05:30:30.286Z

## Summary
- Total scenarios: **19**
- Passed: **18**
- Failed: **1**
- Onboarding number: `+18662511599`
- Provisioned dedicated number during run: `+1XXXXXXXXXX`
- Provisioned owner during run: `+14155558168`

## Provider-Side E2E Callbacks Verified
- Twilio signed webhook callbacks: verified (invalid signature rejected, valid accepted).
- Square signed webhook callbacks: verified (invalid signature rejected, valid accepted).
- Twilio Virtual Phone endpoint (`+18777804236`) real-send checks:
  - `SMd2b55f0aa51572f24f33e4b964d8bf3d` onboarding number -> delivered
  - `SMe518a637935c2d2c1d31d7575daf0e5d` dedicated number -> delivered

## Persona Simulation Matrix
Simulated user types included elderly, student, baby boomer, business owner, privacy-first ideology, and enterprise operator across different US regions.

| Persona Key | Region | Segment | Checkout Link | Offer ($/mo) | Result |
|---|---|---|---|---:|---|
| elderly_florida | Florida | elderly | https://sandbox.square.link/u/JKPisFAQ | 19 | PASS |
| student_california | California | student | https://sandbox.square.link/u/136thHZq | 18 | PASS |
| boomer_midwest | Midwest | baby boomer | https://sandbox.square.link/u/YAt067fs | 19 | PASS |
| smallbiz_texas | Texas | business owner | https://sandbox.square.link/u/3982iG8b | 19 | PASS |
| privacy_newyork | New York | privacy-first ideology | https://sandbox.square.link/u/PCwA8ray | 19 | PASS |
| enterprise_chicago | Illinois | enterprise operator | https://sandbox.square.link/u/ZxKwVACs | 19 | PASS |

## Scenario Pass/Fail Table
| Scenario | Result | Evidence |
|---|---|---|
| T01_invalid_twilio_signature_rejected | PASS | ok |
| T02_onboarding_elderly_florida | PASS | ok |
| T02_onboarding_student_california | PASS | ok |
| T02_onboarding_boomer_midwest | PASS | ok |
| T02_onboarding_smallbiz_texas | PASS | ok |
| T02_onboarding_privacy_newyork | PASS | ok |
| T02_onboarding_enterprise_chicago | PASS | ok |
| T03_negotiation_ladder_student | PASS | ok |
| T04_stop_suppresses_then_start_restores | PASS | ok |
| T05_twilio_idempotency_message_sid | PASS | ok |
| T06_square_invalid_signature_rejected | PASS | ok |
| T07_square_completed_payment_provisions_dedicated | PASS | ok |
| T08_square_replay_idempotency_on_completed_event | PASS | ok |
| T09_dedicated_owner_flow_and_llm_reply | FAIL | Error: no outbound messages found from dedicated number |
| T10_dedicated_non_owner_denied | PASS | ok |
| T11_dedicated_status_keyword | PASS | ok |
| T12_square_non_completed_freeze_path | PASS | ok |
| T13_square_unsupported_event_acknowledged | PASS | ok |
| T14_help_keywords_on_onboarding | PASS | ok |

## Strict Go-Live Checklist
| Control | Status | Evidence / Gate |
|---|---|---|
| Webhook auth (Twilio + Square) | PASS | Invalid signatures rejected in T01 and T06. |
| Twilio idempotency (MessageSid replay) | PASS | Replay ignored in T05. |
| Square idempotency (event_id replay) | PASS | Replay ignored in T08. |
| Onboarding conversion flow (link issuance) | PASS | All persona onboarding paths emitted checkout links in T02. |
| Negotiation guardrail ladder | PASS | Offer lowered deterministically in T03. |
| STOP/START/HELP compliance keywords | PASS | Enforced in T04 and T14. |
| Payment completed -> provisioning | PASS | Dedicated number provisioned in T07. |
| Dedicated ownership enforcement | PASS | Non-owner denied in T10. |
| Dedicated status introspection | PASS | STATUS returned counters/state in T11. |
| Non-completed payment handling | PASS | not_completed path acknowledged in T12. |
| Unsupported Square event safety | PASS | Ignored safely in T13. |
| Dedicated outbound reply reliability (freshly provisioned user) | FAIL | T09 observed zero outbound records for fresh dedicated number during matrix window. |
| Carrier delivery to US mobiles on dedicated locals (pre-approval) | BLOCKED_EXTERNAL | Twilio error 30034 on dedicated local sends until registration state allows traffic. |
| Twilio Virtual Phone pre-approval transport check | PASS | Both onboarding and dedicated numbers delivered to Twilio Virtual endpoint. |
| Scale cap policy for test run | PASS_WITH_OVERRIDE | Caps were raised to 500/500 for matrix execution. |

## Critical Findings
1. **Dedicated outbound reliability has one failing path**
- Freshly provisioned dedicated number scenario (T09) did not produce an outbound record during the test window.
- Impact: some users may see async ack but not receive a reply immediately after provisioning.

2. **Carrier gating still active on dedicated local numbers**
- Dedicated sends to real US mobiles are currently returning Twilio `30034` in this environment.
- Impact: app logic executes, but carrier delivery on local dedicated numbers is still blocked by registration/compliance state.

3. **OpenClaw runtime can answer successfully after warm window**
- Additional targeted run outside the matrix produced non-fallback content (example body: `READY`) from another dedicated number, confirming the model path itself can work.

## Recommended Launch Decision
- **Do not hard-launch dedicated local-number experience yet**.
- **Safe to launch controlled funnel on onboarding/toll-free path** while dedicated delivery approval completes.

## Required Actions Before Full Public Launch
1. Add explicit retry/queue for first dedicated reply after provisioning (minimum 2 retries with backoff).
2. Add structured logging around outbound send failures and gateway timeouts for per-user traceability.
3. Keep onboarding fallback messaging clear when dedicated delivery is carrier-blocked.
4. Re-run this matrix after carrier status changes to confirm dedicated local delivery transitions from `30034`.

## Test Run Overrides Applied
- `SQUARE_WEBHOOK_SIGNATURE_KEY` was set to a known deterministic value for signed callback replay tests.
- `TXTCLAW_MAX_NEW_PER_DAY=500` and `TXTCLAW_MAX_ACTIVE_USERS=500` were set to prevent cap-related false negatives in this matrix.
- `TXTCLAW_OPENCLAW_TIMEOUT_MS=60000` was used for runtime warmup tolerance during dedicated-agent checks.
