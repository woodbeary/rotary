import { ApiKeysDashboard } from "@/components/api-keys-dashboard"
import type { Metadata } from "next"

export const metadata: Metadata = {
  title: "API Keys — TXT CLAW",
  description: "Create and manage TXT CLAW API keys.",
}

export default async function ApiKeysPage() {
  return <ApiKeysDashboard />
}
