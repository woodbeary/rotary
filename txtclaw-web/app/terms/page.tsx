import type { Metadata } from "next"
import Link from "next/link"
import { ArrowLeft } from "lucide-react"

export const metadata: Metadata = {
  title: "Terms of Service — TXT CLAW",
  description:
    "Terms of Service for TXT CLAW SMS-based AI agent service.",
}

export default function TermsOfService() {
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
          Terms of Service
        </h1>
        <p className="mt-3 text-sm text-muted-foreground">
          Last updated: February 5, 2026
        </p>

        <div className="mt-12 space-y-10 text-[15px] leading-relaxed text-foreground/90">
          {/* 1 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              1. Acceptance of Terms
            </h2>
            <p>
              By texting the TXT CLAW phone number{" "}
              <span className="font-mono font-medium">+1 (573) 879-2529</span>{" "}
              or using the TXT CLAW website (collectively, the
              &quot;Service&quot;), you agree to be bound by these Terms of
              Service (&quot;Terms&quot;). If you do not agree, do not use the
              Service. These Terms constitute a legally binding agreement between
              you and Jacob Lopez d/b/a TXT CLAW (&quot;we,&quot; &quot;us,&quot;
              or &quot;our&quot;).
            </p>
          </section>

          {/* 2 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              2. Description of Service
            </h2>
            <p>
              TXT CLAW provides an AI-powered conversational agent accessible
              via SMS text messaging. The Service includes:
            </p>
            <ul className="mt-3 list-disc space-y-2 pl-5">
              <li>
                A free trial via our shared gateway number, limited to
                approximately 15-20 conversational turns.
              </li>
              <li>
                Paid subscription plans that provision a dedicated US phone
                number routed to a private, persistent AI agent with memory,
                tools, browser automation, code execution, custom prompts, and
                bring-your-own-key (BYOK) model support.
              </li>
            </ul>
          </section>

          {/* 3 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              3. Eligibility
            </h2>
            <p>
              You must be at least 13 years of age to use this Service. If you
              are under 18, you must have parental or guardian consent. By using
              the Service, you represent and warrant that you meet these
              eligibility requirements.
            </p>
          </section>

          {/* 4 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              4. SMS Messaging Terms
            </h2>
            <p>
              By texting our number, you consent to receive AI-generated SMS
              responses. Important information about SMS messaging:
            </p>
            <ul className="mt-3 list-disc space-y-2 pl-5">
              <li>
                <strong>User-initiated only.</strong> All conversations are
                initiated by you. We will never send unsolicited messages.
              </li>
              <li>
                <strong>Message and data rates may apply.</strong> Your wireless
                carrier may charge for messages sent and received.
              </li>
              <li>
                <strong>Opt-out.</strong> Reply{" "}
                <span className="font-mono font-medium">STOP</span> at any time
                to stop receiving messages from TXT CLAW.
              </li>
              <li>
                <strong>Help.</strong> Reply{" "}
                <span className="font-mono font-medium">HELP</span> for
                assistance, or email{" "}
                <a
                  href="mailto:support@txtclaw.com"
                  className="font-medium text-foreground underline underline-offset-4"
                >
                  support@txtclaw.com
                </a>
                .
              </li>
              <li>
                <strong>Consent not required for purchase.</strong> Agreeing to
                receive SMS messages is not a condition of purchasing any goods
                or services from us.
              </li>
            </ul>
          </section>

          {/* 5 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              5. Subscriptions &amp; Payments
            </h2>
            <ul className="list-disc space-y-2 pl-5">
              <li>
                Paid plans are billed monthly in advance through Stripe.
              </li>
              <li>
                Your subscription renews automatically each month until
                cancelled.
              </li>
              <li>
                You may cancel at any time. Cancellation takes effect at the end
                of your current billing period. No prorated refunds are issued
                for partial months.
              </li>
              <li>
                Introductory pricing or negotiated discounts apply only to the
                first billing period unless stated otherwise.
              </li>
              <li>
                We reserve the right to change pricing with 30 days&apos; notice.
                Continued use of the Service after a price change constitutes
                acceptance of the new pricing.
              </li>
            </ul>
          </section>

          {/* 6 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              6. Acceptable Use
            </h2>
            <p>You agree not to use the Service to:</p>
            <ul className="mt-3 list-disc space-y-2 pl-5">
              <li>
                Engage in any illegal activity or violate applicable laws.
              </li>
              <li>
                Send harmful, threatening, abusive, harassing, defamatory, or
                otherwise objectionable content.
              </li>
              <li>
                Attempt to exploit, overload, or disrupt the Service or its
                infrastructure.
              </li>
              <li>
                Use the Service to send spam or unsolicited messages to third
                parties.
              </li>
              <li>
                Reverse engineer, decompile, or attempt to extract the source
                code of the Service.
              </li>
              <li>
                Impersonate another person or entity.
              </li>
              <li>
                Use the Service for any purpose that violates{" "}
                <a
                  href="https://www.twilio.com/en-us/legal/aup"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="font-medium text-foreground underline underline-offset-4"
                >
                  Twilio&apos;s Acceptable Use Policy
                </a>
                .
              </li>
            </ul>
            <p className="mt-3">
              We reserve the right to suspend or terminate your access to the
              Service at any time, without notice, for violation of these Terms
              or for any conduct we deem harmful.
            </p>
          </section>

          {/* 7 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              7. AI-Generated Content Disclaimer
            </h2>
            <p>
              The Service uses artificial intelligence to generate responses.
              AI-generated content may not always be accurate, complete, or
              current. You acknowledge that:
            </p>
            <ul className="mt-3 list-disc space-y-2 pl-5">
              <li>
                AI responses are provided &quot;as is&quot; and should not be
                relied upon as professional, legal, medical, financial, or other
                expert advice.
              </li>
              <li>
                You are solely responsible for how you use or act upon
                AI-generated responses.
              </li>
              <li>
                We do not guarantee the accuracy of any information provided by
                the AI agent.
              </li>
            </ul>
          </section>

          {/* 8 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              8. Intellectual Property
            </h2>
            <p>
              The TXT CLAW name, logo, website design, and all associated
              intellectual property are owned by us. You retain ownership of the
              content you send to us via SMS. By using the Service, you grant us
              a limited, non-exclusive license to store and process your message
              content solely for the purpose of providing the Service.
            </p>
          </section>

          {/* 9 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              9. Limitation of Liability
            </h2>
            <p>
              To the maximum extent permitted by law, TXT CLAW and its
              operator, Jacob Lopez, shall not be liable for any indirect,
              incidental, special, consequential, or punitive damages arising
              from your use of (or inability to use) the Service. Our total
              liability for any claim related to the Service shall not exceed the
              amount you paid to us in the 3 months preceding the claim.
            </p>
          </section>

          {/* 10 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              10. Disclaimer of Warranties
            </h2>
            <p>
              The Service is provided on an &quot;AS IS&quot; and &quot;AS
              AVAILABLE&quot; basis without warranties of any kind, either
              express or implied, including but not limited to implied warranties
              of merchantability, fitness for a particular purpose, and
              non-infringement. We do not guarantee uninterrupted, secure, or
              error-free operation of the Service.
            </p>
          </section>

          {/* 11 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              11. Privacy
            </h2>
            <p>
              Your use of the Service is also governed by our{" "}
              <Link
                href="/privacy"
                className="font-medium text-foreground underline underline-offset-4"
              >
                Privacy Policy
              </Link>
              , which is incorporated into these Terms by reference. Please
              review our Privacy Policy to understand how we collect, use, and
              protect your information.
            </p>
          </section>

          {/* 12 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              12. Changes to Terms
            </h2>
            <p>
              We may modify these Terms at any time by posting updated Terms on
              our website. Material changes will be communicated via SMS to
              active subscribers. Your continued use of the Service after changes
              are posted constitutes your acceptance of the revised Terms.
            </p>
          </section>

          {/* 13 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              13. Governing Law
            </h2>
            <p>
              These Terms are governed by the laws of the State of Missouri,
              United States, without regard to its conflict of law provisions.
              Any disputes arising under these Terms shall be resolved
              exclusively in the courts of Missouri.
            </p>
          </section>

          {/* 14 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              14. Contact
            </h2>
            <p>
              For questions about these Terms, contact us at:
            </p>
            <ul className="mt-3 space-y-2 pl-5">
              <li>
                <strong>Email:</strong>{" "}
                <a
                  href="mailto:support@txtclaw.com"
                  className="font-medium text-foreground underline underline-offset-4"
                >
                  support@txtclaw.com
                </a>
              </li>
              <li>
                <strong>SMS:</strong> Reply{" "}
                <span className="font-mono font-medium">HELP</span> to{" "}
                <span className="font-mono font-medium">
                  +1 (573) 879-2529
                </span>
              </li>
            </ul>
          </section>
        </div>
      </div>
    </main>
  )
}
