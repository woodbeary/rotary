import type { Metadata } from "next"
import Link from "next/link"
import { ArrowLeft } from "lucide-react"
import { SMS_PHONE_DISPLAY, SMS_PHONE_HREF } from "@/lib/launch"

export const metadata: Metadata = {
  title: "SMS Consent / Opt-In Proof — TXT CLAW",
  description:
    "Proof of consumer opt-in for TXT CLAW messaging. How users consent to receive messages by texting our toll-free number.",
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
          This page documents how a user opts in to receive messages from TXT
          CLAW.
        </p>

        <div className="mt-12 space-y-10 text-[15px] leading-relaxed text-foreground/90">
          <section className="rounded-lg border border-border bg-card p-6">
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              Quick Proof Summary
            </h2>
            <p className="text-sm text-muted-foreground">
              TXT CLAW is a product of The Interpreting App, LLC.
            </p>
            <p className="mt-3 text-sm text-muted-foreground">
              Exact disclosure shown on our public website footer:
            </p>
            <p className="mt-2 rounded-md border border-border bg-background p-4 text-sm text-foreground/90">
              “TXT CLAW is a product of The Interpreting App, LLC. By texting{" "}
              {SMS_PHONE_DISPLAY}, you agree to receive conversational AI messages
              from TXT CLAW. Message and data rates may apply. Reply STOP to opt
              out. Reply HELP for help. View our Privacy Policy and Terms.”
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
          </section>

          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              1. Where the user sees the disclosure
            </h2>
            <p>
              Users locate our toll-free number in the footer of our public
              website (<span className="font-medium">txtclaw.com</span>). The
              footer includes a clear disclosure stating that texting the number
              constitutes consent to receive conversational AI messages, along
              with opt-out and help instructions and links to our policies.
            </p>
          </section>

          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              2. Handset-initiated opt-in
            </h2>
            <p>
              The user opts in by sending an SMS from their handset to our
              toll-free number:{" "}
              <a
                href={SMS_PHONE_HREF}
                className="font-mono font-medium text-foreground underline underline-offset-4"
              >
                {SMS_PHONE_DISPLAY}
              </a>
              . This is a user-initiated, two-way messaging service: the user
              starts the conversation, and TXT CLAW replies in response to the
              user’s messages.
            </p>
          </section>

          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              3. Opt-out, help, and re-subscribe
            </h2>
            <ul className="list-disc space-y-2 pl-5">
              <li>
                <strong>Opt-out:</strong> Reply{" "}
                <span className="font-mono font-medium">STOP</span> at any time
                to stop receiving messages.
              </li>
              <li>
                <strong>Help:</strong> Reply{" "}
                <span className="font-mono font-medium">HELP</span> for help.
              </li>
              <li>
                <strong>Re-subscribe:</strong> After opting out, reply{" "}
                <span className="font-mono font-medium">START</span> to resume
                receiving messages.
              </li>
            </ul>
            <p className="mt-3">
              Message and data rates may apply based on the user’s carrier
              plan.
            </p>
          </section>

          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              4. Policies
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
          </section>
        </div>
      </div>
    </main>
  )
}
