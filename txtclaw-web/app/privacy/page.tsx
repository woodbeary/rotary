import type { Metadata } from "next"
import Link from "next/link"
import { ArrowLeft } from "lucide-react"

export const metadata: Metadata = {
  title: "Privacy Policy — TXT CLAW",
  description:
    "Privacy Policy for TXT CLAW SMS-based AI agent service. How we collect, use, and protect your data.",
}

export default function PrivacyPolicy() {
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
          Privacy Policy
        </h1>
        <p className="mt-3 text-sm text-muted-foreground">
          Last updated: February 5, 2026
        </p>

        <div className="mt-12 space-y-10 text-[15px] leading-relaxed text-foreground/90">
          {/* 1 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              1. Introduction
            </h2>
            <p>
              TXT CLAW (&quot;we,&quot; &quot;us,&quot; or &quot;our&quot;) is an
              SMS-based AI agent service operated by The Interpreting App, LLC
              (&quot;Operator&quot;). This Privacy Policy explains how we
              collect, use, disclose, and safeguard your personal information
              when you interact with our service by sending text messages (SMS)
              to our phone number{" "}
              <span className="font-mono font-medium">+1 (866) 251-1599</span>{" "}
              or by visiting our website at{" "}
              <span className="font-medium">txtclaw.com</span> (collectively,
              the &quot;Service&quot;).
            </p>
            <p className="mt-3">
              By texting our number or using our website, you agree to the
              collection and use of your information in accordance with this
              Privacy Policy. If you do not agree, please do not text our number
              or use our website.
            </p>
          </section>

          {/* 2 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              2. Information We Collect
            </h2>

            <h3 className="mb-2 mt-4 text-sm font-semibold uppercase tracking-wider text-muted-foreground">
              2.1 Information You Provide via SMS
            </h3>
            <ul className="list-disc space-y-2 pl-5">
              <li>
                <strong>Mobile phone number.</strong> When you text our gateway
                number, your phone number is transmitted to us by your mobile
                carrier. We use your phone number to receive and respond to your
                messages and to associate your conversation history with your
                account.
              </li>
              <li>
                <strong>Message content.</strong> The text content of every SMS
                message you send to us is stored to maintain conversation
                context, enable the AI agent to provide relevant responses, and
                improve our service.
              </li>
              <li>
                <strong>Payment information.</strong> If you subscribe to a paid
                plan, we collect payment details (such as credit/debit card
                information) through our third-party payment processor (Square).
                We do not store your full card number on our servers.
              </li>
            </ul>

            <h3 className="mb-2 mt-4 text-sm font-semibold uppercase tracking-wider text-muted-foreground">
              2.2 Information Collected Automatically
            </h3>
            <ul className="list-disc space-y-2 pl-5">
              <li>
                <strong>SMS metadata.</strong> We receive technical metadata from
                our messaging provider (Twilio), including timestamps, message
                delivery status, carrier information, and approximate geographic
                location (based on area code).
              </li>
              <li>
                <strong>Website analytics.</strong> When you visit our website,
                we may collect standard log data such as your IP address, browser
                type, device type, referring URLs, and pages viewed. We use
                privacy-respecting analytics tools and do not sell this data.
              </li>
            </ul>

            <h3 className="mb-2 mt-4 text-sm font-semibold uppercase tracking-wider text-muted-foreground">
              2.3 Information We Do Not Collect
            </h3>
            <ul className="list-disc space-y-2 pl-5">
              <li>
                We do not collect biometric data, Social Security numbers, or
                government-issued identification.
              </li>
              <li>
                We do not access your phone contacts, photos, or any data on
                your device beyond the SMS messages you choose to send us.
              </li>
            </ul>
          </section>

          {/* 3 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              3. How We Use Your Information
            </h2>
            <p>We use the information we collect to:</p>
            <ul className="mt-3 list-disc space-y-2 pl-5">
              <li>
                <strong>Provide the Service.</strong> Deliver AI-powered SMS
                responses, maintain conversation history, and provision dedicated
                phone numbers for paid subscribers.
              </li>
              <li>
                <strong>Process payments.</strong> Complete subscription
                transactions and manage billing through Square.
              </li>
              <li>
                <strong>Improve the Service.</strong> Analyze aggregate usage
                patterns (not individual message content) to improve response
                quality, reliability, and features.
              </li>
              <li>
                <strong>Communicate with you.</strong> Send transactional
                messages related to your account, such as payment confirmations,
                service updates, or responses to your support inquiries.
              </li>
              <li>
                <strong>Comply with legal obligations.</strong> Respond to lawful
                requests from law enforcement or regulatory bodies.
              </li>
            </ul>
          </section>

          {/* 4 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              4. SMS Messaging Terms &amp; Consent
            </h2>
            <p>
              This section outlines important information about our SMS
              messaging practices in compliance with the Telephone Consumer
              Protection Act (TCPA), Cellular Telecommunications Industry
              Association (CTIA) guidelines, and carrier requirements.
            </p>

            <h3 className="mb-2 mt-4 text-sm font-semibold uppercase tracking-wider text-muted-foreground">
              4.1 User-Initiated Messaging &amp; Opt-In
            </h3>
            <p>
              TXT CLAW is a <strong>user-initiated, two-way SMS service</strong>
              . You opt in to our service by texting our gateway number{" "}
              <span className="font-mono font-medium">+1 (866) 251-1599</span>{" "}
              first. We will never send you unsolicited messages. Every
              conversation is started by you.
            </p>
            <p className="mt-3">
              By texting our number, you expressly consent to receive
              AI-generated SMS responses from TXT CLAW in reply to your
              messages. If you subscribe to a paid plan, you also consent to
              receive transactional messages related to your account (e.g.,
              payment confirmations, plan changes, service notifications).
            </p>

            <h3 className="mb-2 mt-4 text-sm font-semibold uppercase tracking-wider text-muted-foreground">
              4.2 Message Frequency
            </h3>
            <p>
              Message frequency varies based on your usage. On the free gateway
              tier, conversations are limited to approximately 15-20 exchanges.
              On paid plans, there is no hard cap on message volume, but
              reasonable usage limits apply as outlined in our{" "}
              <Link
                href="/terms"
                className="font-medium text-foreground underline underline-offset-4"
              >
                Terms of Service
              </Link>
              .
            </p>

            <h3 className="mb-2 mt-4 text-sm font-semibold uppercase tracking-wider text-muted-foreground">
              4.3 Opt-Out
            </h3>
            <p>
              You may opt out of receiving messages from TXT CLAW at any time by
              replying <strong className="font-mono">STOP</strong> to any
              message from us. Upon receiving your opt-out request, we will send
              a single confirmation message and cease all further messaging to
              your number.
            </p>
            <p className="mt-3">
              To re-subscribe after opting out, text{" "}
              <strong className="font-mono">START</strong> to our number.
            </p>

            <h3 className="mb-2 mt-4 text-sm font-semibold uppercase tracking-wider text-muted-foreground">
              4.4 Help
            </h3>
            <p>
              For assistance, reply <strong className="font-mono">HELP</strong>{" "}
              to any message from TXT CLAW, or contact us at{" "}
              <a
                href="mailto:support@txtclaw.com"
                className="font-medium text-foreground underline underline-offset-4"
              >
                support@txtclaw.com
              </a>
              .
            </p>

            <h3 className="mb-2 mt-4 text-sm font-semibold uppercase tracking-wider text-muted-foreground">
              4.5 Message &amp; Data Rates
            </h3>
            <p>
              Standard message and data rates from your mobile carrier may apply
              to messages you send to and receive from TXT CLAW. TXT CLAW does
              not charge per-message fees; however, your wireless carrier may
              charge you for each SMS/MMS message sent or received. Please
              contact your carrier for details about your messaging plan.
            </p>

            <h3 className="mb-2 mt-4 text-sm font-semibold uppercase tracking-wider text-muted-foreground">
              4.6 Supported Carriers
            </h3>
            <p>
              TXT CLAW is compatible with all major U.S. wireless carriers
              including AT&amp;T, Verizon, T-Mobile, Sprint, and their
              respective MVNOs. Carrier support may vary. We are not responsible
              for delayed or undelivered messages caused by carrier issues.
            </p>

            <h3 className="mb-2 mt-4 text-sm font-semibold uppercase tracking-wider text-muted-foreground">
              4.7 No Unsolicited Marketing
            </h3>
            <p>
              We will <strong>never</strong> use your phone number to send
              promotional or marketing text messages. We will{" "}
              <strong>never</strong> share, sell, rent, or lease your phone
              number or opt-in data to any third parties for marketing purposes.
              Your consent to receive messages from TXT CLAW is not a condition
              of any purchase.
            </p>
          </section>

          {/* 5 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              5. Data Sharing &amp; Third Parties
            </h2>
            <p>
              We do not sell your personal information. We share data only with
              the following categories of service providers, strictly as
              necessary to operate the Service:
            </p>
            <ul className="mt-3 list-disc space-y-2 pl-5">
              <li>
                <strong>Twilio</strong> — Our SMS messaging infrastructure
                provider. Twilio processes your phone number and message content
                to deliver messages. See{" "}
                <a
                  href="https://www.twilio.com/en-us/legal/privacy"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="font-medium text-foreground underline underline-offset-4"
                >
                  Twilio&apos;s Privacy Policy
                </a>
                .
              </li>
              <li>
                <strong>Cloudflare</strong> — Our hosting and edge computing
                provider. See{" "}
                <a
                  href="https://www.cloudflare.com/privacypolicy/"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="font-medium text-foreground underline underline-offset-4"
                >
                  Cloudflare&apos;s Privacy Policy
                </a>
                .
              </li>
              <li>
                <strong>OpenClaw / Moltworker</strong> — Our AI agent
                infrastructure provider. Message content is processed by AI
                models to generate responses. Conversation data may be stored
                temporarily for context continuity.
              </li>
              <li>
                <strong>Square</strong> — Our payment processor for subscription
                billing. See{" "}
                <a
                  href="https://squareup.com/us/en/legal/general/privacy"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="font-medium text-foreground underline underline-offset-4"
                >
                  Square&apos;s Privacy Policy
                </a>
                .
              </li>
            </ul>
            <p className="mt-3">
              We may also disclose your information if required by law, court
              order, or governmental regulation, or if we believe disclosure is
              necessary to protect our rights, your safety, or the safety of
              others.
            </p>
          </section>

          {/* 6 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              6. Data Retention
            </h2>
            <ul className="list-disc space-y-2 pl-5">
              <li>
                <strong>Free tier conversations:</strong> Message data from the
                free gateway trial is retained for up to 30 days after your last
                interaction, then permanently deleted.
              </li>
              <li>
                <strong>Paid subscriber conversations:</strong> Conversation
                history is retained for the duration of your active subscription
                plus 30 days after cancellation, after which it is permanently
                deleted.
              </li>
              <li>
                <strong>Phone numbers:</strong> Your phone number is retained
                for the duration of your use of the Service. If you opt out (by
                replying STOP), we retain your number solely on a suppression
                list to ensure we do not contact you again. You may request
                removal from the suppression list by contacting us.
              </li>
              <li>
                <strong>Payment records:</strong> Billing and transaction records
                are retained for the period required by applicable tax and
                accounting laws (typically 7 years).
              </li>
            </ul>
          </section>

          {/* 7 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              7. Data Security
            </h2>
            <p>
              We implement industry-standard technical and organizational
              safeguards to protect your data, including:
            </p>
            <ul className="mt-3 list-disc space-y-2 pl-5">
              <li>
                Encryption in transit (TLS/SSL) for all web traffic and API
                communications.
              </li>
              <li>
                Encryption at rest for stored conversation data and account
                information.
              </li>
              <li>
                Access controls limiting employee access to user data on a
                need-to-know basis.
              </li>
              <li>Regular security reviews of our infrastructure and code.</li>
            </ul>
            <p className="mt-3">
              While we strive to protect your information, no method of
              electronic transmission or storage is 100% secure. We cannot
              guarantee absolute security.
            </p>
          </section>

          {/* 8 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              8. Your Rights
            </h2>
            <p>Depending on your jurisdiction, you may have the right to:</p>
            <ul className="mt-3 list-disc space-y-2 pl-5">
              <li>
                <strong>Access</strong> the personal data we hold about you.
              </li>
              <li>
                <strong>Correct</strong> inaccurate personal data.
              </li>
              <li>
                <strong>Delete</strong> your personal data (subject to legal
                retention requirements).
              </li>
              <li>
                <strong>Opt out</strong> of SMS messaging at any time by
                replying STOP.
              </li>
              <li>
                <strong>Data portability</strong> — Request a copy of your data
                in a machine-readable format.
              </li>
            </ul>
            <p className="mt-3">
              To exercise any of these rights, contact us at{" "}
              <a
                href="mailto:privacy@txtclaw.com"
                className="font-medium text-foreground underline underline-offset-4"
              >
                privacy@txtclaw.com
              </a>
              . We will respond to all requests within 30 days.
            </p>
          </section>

          {/* 9 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              9. California Residents (CCPA)
            </h2>
            <p>
              If you are a California resident, the California Consumer Privacy
              Act (CCPA) provides you with additional rights regarding your
              personal information:
            </p>
            <ul className="mt-3 list-disc space-y-2 pl-5">
              <li>
                <strong>Right to know</strong> what personal information we
                collect about you and how it is used.
              </li>
              <li>
                <strong>Right to delete</strong> personal information we have
                collected from you.
              </li>
              <li>
                <strong>Right to opt out</strong> of the sale of your personal
                information. We do not sell personal information.
              </li>
              <li>
                <strong>Right to non-discrimination</strong> for exercising your
                privacy rights.
              </li>
            </ul>
            <p className="mt-3">
              To exercise your CCPA rights, email{" "}
              <a
                href="mailto:privacy@txtclaw.com"
                className="font-medium text-foreground underline underline-offset-4"
              >
                privacy@txtclaw.com
              </a>{" "}
              with the subject line &quot;CCPA Request.&quot;
            </p>
          </section>

          {/* 10 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              10. Children&apos;s Privacy
            </h2>
            <p>
              TXT CLAW is not intended for use by anyone under the age of 13. We
              do not knowingly collect personal information from children under
              13. If we learn that we have collected information from a child
              under 13, we will delete it promptly. If you believe a child has
              provided us with personal information, please contact us at{" "}
              <a
                href="mailto:privacy@txtclaw.com"
                className="font-medium text-foreground underline underline-offset-4"
              >
                privacy@txtclaw.com
              </a>
              .
            </p>
          </section>

          {/* 11 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              11. Changes to This Policy
            </h2>
            <p>
              We may update this Privacy Policy from time to time. If we make
              material changes, we will notify you by posting the updated policy
              on our website with a new &quot;Last updated&quot; date. For
              material changes affecting SMS messaging, we will send a text
              notification to active subscribers. Your continued use of the
              Service after changes constitutes acceptance of the updated policy.
            </p>
          </section>

          {/* 12 */}
          <section>
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              12. Contact Us
            </h2>
            <p>
              If you have any questions about this Privacy Policy, your data, or
              our SMS messaging practices, please contact us:
            </p>
            <ul className="mt-3 space-y-2 pl-5">
              <li>
                <strong>Email:</strong>{" "}
                <a
                  href="mailto:privacy@txtclaw.com"
                  className="font-medium text-foreground underline underline-offset-4"
                >
                  privacy@txtclaw.com
                </a>
              </li>
              <li>
                <strong>SMS:</strong> Reply{" "}
                <span className="font-mono font-medium">HELP</span> to any
                message from{" "}
                <span className="font-mono font-medium">
                  +1 (866) 251-1599
                </span>
              </li>
              <li>
                <strong>X (Twitter):</strong>{" "}
                <a
                  href="https://x.com/jacoblopez"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="font-medium text-foreground underline underline-offset-4"
                >
                  @jacoblopez
                </a>
              </li>
            </ul>
          </section>

          {/* Summary box */}
          <section className="rounded-lg border border-border bg-card p-6">
            <h2 className="mb-3 text-lg font-semibold text-foreground">
              SMS Messaging Summary
            </h2>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between border-b border-border pb-2">
                <span className="text-muted-foreground">Service</span>
                <span className="font-medium text-foreground">
                  TXT CLAW AI Agent
                </span>
              </div>
              <div className="flex justify-between border-b border-border pb-2">
                <span className="text-muted-foreground">Phone Number</span>
                <span className="font-mono font-medium text-foreground">
                  +1 (866) 251-1599
                </span>
              </div>
              <div className="flex justify-between border-b border-border pb-2">
                <span className="text-muted-foreground">Message Type</span>
                <span className="font-medium text-foreground">
                  User-initiated, two-way SMS
                </span>
              </div>
              <div className="flex justify-between border-b border-border pb-2">
                <span className="text-muted-foreground">Frequency</span>
                <span className="font-medium text-foreground">
                  Varies by usage
                </span>
              </div>
              <div className="flex justify-between border-b border-border pb-2">
                <span className="text-muted-foreground">Opt-Out</span>
                <span className="font-mono font-medium text-foreground">
                  Reply STOP
                </span>
              </div>
              <div className="flex justify-between border-b border-border pb-2">
                <span className="text-muted-foreground">Help</span>
                <span className="font-mono font-medium text-foreground">
                  Reply HELP
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Data Rates</span>
                <span className="font-medium text-foreground">
                  Msg &amp; data rates may apply
                </span>
              </div>
            </div>
          </section>
        </div>
      </div>
    </main>
  )
}
