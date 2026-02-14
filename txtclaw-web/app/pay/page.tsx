import { redirect } from "next/navigation"
import { SMS_GATEWAY_LIVE } from "@/lib/launch"

export default function PayRedirectPage() {
  // `/pay` is not part of the public flow. Keep it as a safe redirect target.
  redirect(SMS_GATEWAY_LIVE ? "/" : "/waitlist")
}

