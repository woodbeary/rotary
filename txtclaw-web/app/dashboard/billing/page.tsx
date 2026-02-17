import { DevApiBilling } from "@/components/dev-api-billing"
import type { Metadata } from "next"

export const metadata: Metadata = {
  title: "Billing — TXT CLAW",
  description: "Upgrade TXT CLAW Dev API limits (hosted router + BYOK).",
}

export default async function BillingPage() {
  return <DevApiBilling />
}
