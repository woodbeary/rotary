# A2P 10DLC Remediation Tracker

This document tracks Twilio Trust Hub / A2P 10DLC validation attempts and the canonical payload used for submission.

## Canonical Submission Payload

| Field | Value |
| --- | --- |
| **Campaign description** | TXT CLAW (a product of The Interpreting App, LLC) handles user-initiated conversational SMS. End users start by texting +1 (855) 408-8675 to request AI help with scheduling, tasks, and account support. We also send transactional responses the user requests (including secure payment links). We do not send unsolicited marketing and we do not use purchased leads. |
| **Sample message #1** | TXT CLAW: You are now connected to TXT CLAW AI. Message and data rates may apply. Message frequency varies. Reply HELP for help. Reply STOP to opt out. |
| **Sample message #2** | TXT CLAW: I scheduled your meeting for Tuesday at 3:00 PM. Would you like me to send the invite? Reply HELP for help. Reply STOP to opt out. |
| **Sample message #3** | TXT CLAW: Here is your secure payment link: https://txtclaw.com/pay. Reply HELP for help. Reply STOP to opt out. |
| **Sample message #4** | TXT CLAW Help: For support, email support@txtclaw.com or visit https://www.txtclaw.com. Reply STOP to opt out. Reply START to re-subscribe. |
| **Sample message #5** | TXT CLAW: You have been unsubscribed and will no longer receive messages. Reply START to re-subscribe. |
| **How do end-users consent?** | End users opt in through a single public method: they text +1 (855) 408-8675 from their handset after viewing the disclosure on https://www.txtclaw.com and https://www.txtclaw.com/sms-consent. Public disclosure text: "TXT CLAW is a product of The Interpreting App, LLC. By texting +1 (855) 408-8675, you agree to receive conversational AI messages from TXT CLAW. Message and data rates may apply. Reply STOP to opt out. Reply HELP for help. Consent is not a condition of purchase." Program type is user-initiated two-way conversational SMS; message frequency varies by user interaction. We do not use purchased lists, scraped numbers, or third-party opt-ins. HELP provides support guidance. STOP unsubscribes. START re-subscribes. |
| **Privacy Policy URL** | https://www.txtclaw.com/privacy |
| **Terms and Conditions URL** | https://www.txtclaw.com/terms |

### Message Content Checkboxes

- [x] Messages will include embedded links
- [x] Messages will include phone numbers
- [ ] Direct lending/loan content
- [ ] Age-gated content

---

## Submission History

| Timestamp | Result | Reason / Delta Notes | Evidence |
| --- | --- | --- | --- |
| 2026-02-18 | REJECTED | CTA Rejection (30909) - Missing frequency disclosure / payload alignment | [Issue Artifacts](#) |
| [Pending] | | | |
