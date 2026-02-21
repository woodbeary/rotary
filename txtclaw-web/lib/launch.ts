// Flip this via env when the public SMS gateway is live.
export const SMS_GATEWAY_LIVE = process.env.NEXT_PUBLIC_SMS_GATEWAY_LIVE === "true"

// Official public opt-in number (toll-free) used for Twilio compliance review.
export const SMS_PHONE_DISPLAY = "+1 (855) 408-8675"
export const SMS_PHONE_HREF = "sms:+18554088675"

export const SMS_COMPLIANCE_DISCLOSURE =
  "TXT CLAW is a product of The Interpreting App, LLC. By texting +1 (855) 408-8675, you agree to receive conversational AI messages from TXT CLAW. Message and data rates may apply. Reply STOP to opt out. Reply HELP for help. Consent is not a condition of purchase."

export const SMS_COMPLIANCE_DISCLOSURE_WITH_POLICY =
  `${SMS_COMPLIANCE_DISCLOSURE} View our Privacy Policy and Terms and Conditions.`
