import { AdminPrompts } from "@/components/admin-prompts"
import type { Metadata } from "next"

export const metadata: Metadata = {
  title: "Prompts — TXT CLAW",
  description: "Create and activate TXT CLAW prompt versions.",
}

export default function AdminPromptsPage() {
  return <AdminPrompts />
}
