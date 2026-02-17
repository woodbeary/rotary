import { AdminTraces } from "@/components/admin-traces"
import type { Metadata } from "next"

export const metadata: Metadata = {
  title: "Traces — TXT CLAW",
  description: "View and grade TXT CLAW API traces.",
}

export default function AdminTracesPage() {
  return <AdminTraces />
}
