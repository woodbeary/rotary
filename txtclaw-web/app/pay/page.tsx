import { SMS_GATEWAY_LIVE } from "@/lib/launch"
import { redirect } from "next/navigation"

export default function PayRedirectPage() {
  // `/pay` is not part of the public flow. Keep it as a safe redirect target.
  redirect(SMS_GATEWAY_LIVE ? "/" : "/waitlist")
}
