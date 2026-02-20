# TXT CLAW SMS Anti-Abuse Instrumentation Specification

Last updated: **2026-02-18**

## Purpose

Collect enough traceable telemetry to detect abuse per actor and per number, then drive reversible controls with low false-positive impact.

## Backend event stream schema (required)

Every SMS decision must emit one or more events with the same trace lineage.

### `sms_send_attempt`

Required fields:

- `event_id` (UUID)
- `actor_id`
- `user_id`
- `from_phone`
- `to_phone`
- `campaign_id`
- `message_sid` (if available)
- `message_hash` (sha-256 of normalized message content)
- `event_kind` = `sms_send_attempt`
- `trace_id`
- `created_at`
- `direction` (`inbound`/`outbound`)

Optional fields:

- `sandbox_key`
- `dedicated_number`
- `message_length`
- `token_bucket_id`

### `sms_send_result`

Required fields:

- `event_id`
- `actor_id`
- `to_phone`
- `trace_id`
- `message_sid`
- `http_status`
- `error_code`
- `twilio_status`
- `campaign_id`
- `created_at`
- `ms_since_enqueue`

Optional fields:

- `provider_message_id`
- `retry_count`
- `carrier`
- `final_status`

### `sms_opt_out`

Required fields:

- `event_id`
- `actor_id`
- `phone`
- `opt_out_type` (`STOP`, `UNSUBSCRIBE`, etc)
- `trace_id`
- `created_at`
- `campaign_id`

### `sms_help`

Required fields:

- `event_id`
- `actor_id`
- `phone`
- `trace_id`
- `created_at`
- `campaign_id`

### `risk_score_update`

Required fields:

- `event_id`
- `actor_id`
- `risk_score_1h`
- `risk_score_24h`
- `risk_score_7d`
- `risk_bucket` (`low`, `medium`, `high`, `critical`)
- `triggers` (array of trigger keys)
- `trace_ids` (array)
- `created_at`

### `actor_action`

Required fields:

- `event_id`
- `actor_id`
- `action` (`warn_actor`, `pause_actor_egress`, `disable_actor_numbers`, `unfreeze_actor`)
- `trigger` (`risk_score_threshold`, `manual`)
- `requested_by`
- `trace_ids`
- `result` (`applied`, `queued`, `rejected`)
- `created_at`
- `expires_at` (for pause/unfreeze windows)

## Trace extension fields (existing trace objects)

Add these non-sensitive keys to outbound and inbound SMS traces:

- `actor_id`
- `user_id`
- `campaign_id`
- `from_phone`
- `to_phone`
- `twilio_message_sid`
- `http_status`
- `error_code`
- `risk_score`
- `risk_tier`
- `content_hash`
- `event_type`

## Retention and redaction

- Raw message body: do **not** retain.
- Keep message hash for dedupe/fraud correlation.
- Keep event records and traces for at least 30 days in hot storage.
- Keep action/audit records for at least 180 days.
- Any identifier map (`phone -> hash`, `campaign -> id`) should be rotated/re-keyed if used for forensic export.

## Query requirements

- “Actor trace/evidence” query must return:
  - actor row;
  - last 7 days actor events;
  - last 200 traces;
  - action history sorted reverse chronologically.
- P95 query latency target: **< 2s** for actor/events query over 7 days.

## Action API contract

Admin actions are reversible by design:

- `warn_actor` requires `reason`
- `pause_actor_egress` requires `reason` + `duration_minutes`
- `disable_actor_numbers` requires `reason`
- `unfreeze_actor` requires `reason`

Every action response must include:

- `trace_ids` used in scoring decision
- action ID for audit lookup
- `applied_by` admin identity and timestamp
