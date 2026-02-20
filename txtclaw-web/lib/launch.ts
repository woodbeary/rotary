// Flip this via env when the public SMS gateway is live.
export const SMS_GATEWAY_LIVE = process.env.NEXT_PUBLIC_SMS_GATEWAY_LIVE === "true"

// Official public opt-in number (toll-free) used for Twilio compliance review.
export const SMS_PHONE_DISPLAY = "+1 (855) 408-8675"
export const SMS_PHONE_HREF = "sms:+18554088675"
