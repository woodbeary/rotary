# Anti-Abuse Escalation Playbook and KYC Thresholds

Last updated: **2026-02-18**

## Default policy posture

- Keep onboarding user flow unchanged until risk score thresholds are reached.
- Use reversible controls first:
  1. `warn_actor`
  2. `pause_actor_egress` (time-boxed)
  3. `disable_actor_numbers`
  4. `unfreeze_actor` after review

## Risk score windows

- `window_1h` controls burst behavior and short-term abuse.
- `window_24h` controls sustained suspicious activity.
- `window_7d` controls campaign-level abuse drift.

## Detection model (MVP)

Use weighted sum of normalized features:

- 1h burst factor
- STOP/complaint anomaly
- delivery failure anomaly
- consent anomalies (first-message-to-many / identical repeated templates)

Each feature maps to 0–100. Weighted total maps to:

- `low` = 0–34
- `medium` = 35–59
- `high` = 60–79
- `critical` = 80–100

## Score thresholds and actions

- **score 30–44**:
  - Add `warn_actor` if not already warned.
  - Keep egress enabled.
- **score 45–64**:
  - `warn_actor` (required) and auto-require operator ack for next 20 outbound attempts.
- **score 65–84**:
  - `pause_actor_egress` for 60 minutes.
  - Send warning SMS + admin notification with evidence.
- **score 85+**:
  - `disable_actor_numbers`.
  - Keep in disabled state until manual `unfreeze_actor`.

## KYC trigger policy (risk-based)

- No blanket KYC on sign-up.
- Add soft verification trigger when actor reaches `warn_actor` state twice in 24h.
- Add stronger verification before reactivation from `disabled` or repeated `pause_actor_egress` within 7d.

Soft KYC options:

- tokenized identity challenge;
- secondary phone confirmation challenge;
- payment/identity check for high-risk plan upgrades.

## Evidence for KYC decisions

Each escalation to soft/strong KYC must include:

- actor id;
- risk events used;
- exact `trace_id`s;
- compliance state (`STOP` coverage, opt-out count, complaint rate);
- operator note.

## Operator workflow

1. Auto alert enters queue with actor summary and links.
2. Operator chooses action.
3. If no action in defined SLA window, system should escalate to pause.
4. Re-enable flow requires:
   - re-check opt-out state,
   - explicit reason,
   - evidence bundle exported.

## Audit logging requirements

- Keep immutable action records for 180+ days.
- Link every action to:
  - admin user,
  - reason,
  - source traces,
  - resulting action state.
