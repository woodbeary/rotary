import { SMS_COMPLIANCE_DISCLOSURE_WITH_POLICY, SMS_PHONE_DISPLAY, SMS_PHONE_HREF } from "@/lib/launch"
import { ArrowLeft } from "lucide-react"
import type { Metadata } from "next"
import Link from "next/link"

export const metadata: Metadata = {
  title: "SMS Consent / Opt-In Proof — TXT CLAW",
  description:
    "Proof of consumer opt-in for TXT CLAW messaging, including explicit consent language and STOP/HELP/START behavior.",
}

export default function SmsConsentPage() {
  return (
    <main className="min-h-screen bg-background">
      <div className="mx-auto max-w-3xl px-6 py-16 md:py-24">
        <Link
          href="/"
          className="mb-10 inline-flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" />
          Back to home
        </Link>

        <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
          SMS Consent / Opt-In Proof
        </h1>
        <p className="mt-3 text-sm text-muted-foreground">
          This page documents our SMS consent workflow and message compliance language for toll-free
          verification.
        </p>

        <div className="mt-12 space-y-10 text-[15px] leading-relaxed text-foreground/90">
          <section className="rounded-lg border border-border bg-card p-6">
            <h2 className="mb-3 text-lg font-semibold text-foreground">Quick Proof Summary</h2>
            <p className="text-sm text-muted-foreground">
              TXT CLAW is a product of The Interpreting App, LLC.
            </p>
            <p className="mt-3 text-sm text-muted-foreground">
              Public disclosure language used for SMS consent:
            </p>
            <p className="mt-2 rounded-md border border-border bg-background p-4 text-sm text-foreground/90">
              “{SMS_COMPLIANCE_DISCLOSURE_WITH_POLICY}”
            </p>
            <p className="mt-3 text-sm text-muted-foreground">
              Text us here:{" "}
              <a
                href={SMS_PHONE_HREF}
                className="font-mono font-medium text-foreground underline underline-offset-4"
              >
                {SMS_PHONE_DISPLAY}
              </a>
            </p>
            <ul className="mt-4 list-disc space-y-2 pl-5 text-sm text-muted-foreground">
              <li>Program type: User-initiated, conversational two-way SMS.</li>
              <li>Message category: Account support and transactional AI responses.</li>
              <li>No unsolicited marketing campaigns or purchased lead lists.</li>
            </ul>
          </section>

          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              1. How consent is collected
            </h2>
            <ol className="list-decimal space-y-2 pl-5">
              <li>
                The user sees our SMS disclosure and policy links on our website, including this
                page.
              </li>
              <li>
                The user opts in by sending the first SMS from their handset to{" "}
                <a
                  href={SMS_PHONE_HREF}
                  className="font-mono font-medium text-foreground underline underline-offset-4"
                >
                  {SMS_PHONE_DISPLAY}
                </a>
                .
              </li>
              <li>
                TXT CLAW sends a branded confirmation response that includes message-rate and
                keyword instructions.
              </li>
            </ol>
          </section>

          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              2. Sample messages used for compliance
            </h2>
            <div className="space-y-4">
              <div>
                <p className="text-sm font-semibold text-foreground">Opt-In Confirmation Message</p>
                <p className="mt-1 rounded-md border border-border bg-background p-4 text-sm text-foreground/90">
                  TXT CLAW: You are now connected to TXT CLAW AI. Message and data rates may apply.
                  Reply HELP for help. Reply STOP to cancel.
                </p>
              </div>
              <div>
                <p className="text-sm font-semibold text-foreground">Help Message Sample</p>
                <p className="mt-1 rounded-md border border-border bg-background p-4 text-sm text-foreground/90">
                  TXT CLAW Help: For support, email support@txtclaw.com or visit
                  https://www.txtclaw.com. Reply STOP to cancel.
                </p>
              </div>
              <div>
                <p className="text-sm font-semibold text-foreground">Opt-Out Confirmation</p>
                <p className="mt-1 rounded-md border border-border bg-background p-4 text-sm text-foreground/90">
                  TXT CLAW: You have been unsubscribed and will no longer receive messages. Reply
                  START to re-subscribe.
                </p>
              </div>
            </div>
          </section>

          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              3. STOP / HELP / START keyword behavior
            </h2>
            <ul className="list-disc space-y-2 pl-5">
              <li>
                <strong>Opt-out:</strong> Reply <span className="font-mono font-medium">STOP</span>{" "}
                at any time to stop receiving messages.
              </li>
              <li>
                <strong>Help:</strong> Reply <span className="font-mono font-medium">HELP</span> for
                help.
              </li>
              <li>
                <strong>Re-subscribe:</strong> After opting out, reply{" "}
                <span className="font-mono font-medium">START</span> to resume receiving messages.
              </li>
            </ul>
            <p className="mt-3">
              Message and data rates may apply based on the user’s carrier plan.
            </p>
          </section>

          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">4. Consent boundaries</h2>
            <ul className="list-disc space-y-2 pl-5">
              <li>Consent is specific to TXT CLAW messaging and can be revoked at any time.</li>
              <li>Consent is not a condition of purchasing any goods or services.</li>
              <li>We do not transfer, sell, or share opt-in data for third-party marketing.</li>
            </ul>
          </section>

          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              5. Policies and proof URLs
            </h2>
            <p>
              For more details, see our{" "}
              <Link
                href="/privacy"
                className="font-medium text-foreground underline underline-offset-4"
              >
                Privacy Policy
              </Link>{" "}
              and{" "}
              <Link
                href="/terms"
                className="font-medium text-foreground underline underline-offset-4"
              >
                Terms
              </Link>
              .
            </p>
            <ul className="mt-3 list-disc space-y-2 pl-5 text-sm">
              <li>
                <span className="font-medium">Proof page:</span>{" "}
                <span className="font-mono">https://www.txtclaw.com/sms-consent</span>
              </li>
              <li>
                <span className="font-medium">Privacy:</span>{" "}
                <span className="font-mono">https://www.txtclaw.com/privacy</span>
              </li>
              <li>
                <span className="font-medium">Terms:</span>{" "}
                <span className="font-mono">https://www.txtclaw.com/terms</span>
              </li>
            </ul>
          </section>
        </div>
      </div>
    </main>
  )
}
