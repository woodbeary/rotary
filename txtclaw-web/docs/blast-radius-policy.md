# Blast Radius Policy: A2P 10DLC Compliance

This document outlines the blast radius and risk mitigation strategies for TXT CLAW's A2P 10DLC campaign management, based on the `docs/anti-abuse-compliance-readiness-matrix-10dlc.md`.

## 1. Campaign Isolation vs. Blast Radius

The architecture of our A2P campaign determines the "blast radius" in the event of carrier rejection, suspension, or compliance violations.

| Control Surface | Shared Campaign (Current) | Dedicated Campaign (Future) | Blast Radius Impact |
| --- | --- | --- | --- |
| **Campaign Model** | One shared `Agents`-style A2P campaign for all users. | Per-user or per-customer campaign (if legal entity differs). | **High (Shared):** A single violation or rejection can suspend all traffic for the entire product. |
| **Number Ownership** | Shared number pool or dedicated numbers under a single campaign. | Per-tenant sub-account + per-tenant campaign. | **High (Shared):** Abuse associated with one number can taint the entire campaign or brand reputation. |

## 2. Risk Mitigation Strategies

To minimize the blast radius, we implement the following controls:

### A. Consent and Opt-Out Enforcement
- **Immediate Suppression:** Any recipient who replies `STOP` is immediately added to a suppression list.
- **Hard Retention:** Consent artifacts (timestamp, IP, source page, wording version) are retained for audit purposes.
- **Branded Confirmation:** Every initial opt-in receives a branded message with clear instructions on how to opt-out.

### B. Traffic Monitoring and Rate Limiting
- **Abuse Telemetry:** Monitor per-actor risk scores and action history.
- **Automated Controls:** Reversible controls (Warn → Pause → Disable) based on abuse detection.
- **30034 Error Handling:** Automated escalation and support paths for carrier-specific delivery failures.

### C. Remediation Workflow
In the event of a campaign rejection (e.g., Error 30909):
1. **Payload Alignment:** Immediately align all public disclosure pages (Terms, Privacy, Consent) with the canonical submission payload.
2. **Evidence Collection:** Capture screenshots and timestamps of all public-facing compliance language.
3. **Resubmission Tracking:** Use the `docs/a2p-10dlc-remediation-tracker.md` to document the exact diff of the resubmission.

## 3. Transition to Lower Blast Radius
As the service scales, we will evaluate the transition from a shared campaign model to per-tenant sub-accounts. This transition will be triggered by:
- Sustained high-volume traffic.
- Carrier stability proof-of-concept.
- Complexity of managing diverse user-initiated content under a single campaign.
