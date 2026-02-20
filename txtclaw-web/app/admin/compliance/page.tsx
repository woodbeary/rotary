import { AdminCompliance } from "@/components/admin-compliance"
import type { Metadata } from "next"

export const metadata: Metadata = {
  title: "Compliance Controls — TXT CLAW",
  description: "Review actor risk signals and run reversible anti-abuse controls.",
}

export default function AdminCompliancePage() {
  return <AdminCompliance />
}
