import { Navbar } from "@/components/navbar"
import { ArrowLeft } from "lucide-react"
import Link from "next/link"

export default function LaunchCopyPage() {
  return (
    <div className="min-h-screen">
      <Navbar />
      <main className="mx-auto max-w-3xl px-6 py-16">
        <Link
          href="/"
          className="mb-10 inline-flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" />
          Back to home
        </Link>

        <h1 className="mb-2 font-mono text-3xl font-bold text-foreground">TXT CLAW Launch Copy</h1>
        <p className="mb-12 text-muted-foreground">
          Private beta launch copy with fixed pricing and invite cadence.
        </p>

        <section className="mb-16">
          <h2 className="mb-6 border-b border-border pb-2 font-mono text-xl font-semibold text-primary">
            X / Twitter Thread
          </h2>

          <div className="flex flex-col gap-6">
            <Tweet number={1}>
              {`Launching TXT CLAW in private beta.

No app download. No learning curve.
You chat in your normal messaging app.

Invite-only rollout starts now.`}
            </Tweet>

            <Tweet number={2}>
              {`How access works:
1) Join waitlist
2) Get invite email
3) Redeem code or continue to payment
4) Receive invite instructions
5) Chat instantly on first inbound

Usually within 24h after payment.`}
            </Tweet>

            <Tweet number={3}>
              {`Launch pricing is fixed:
- $16/mo early bird (first 100 paid seats)
- $19/mo standard after seat 100
- $299 BYOK lifetime (10 seats)

No negotiation. First-come, first-served.`}
            </Tweet>

            <Tweet number={4}>
              {`We’re running invite-only first for a tighter privacy + reliability baseline, then expanding after beta hardening.

Join the list: [your-landing-page-url]

@jacoblopez`}
            </Tweet>
          </div>
        </section>

        <section className="mb-16">
          <h2 className="mb-6 border-b border-border pb-2 font-mono text-xl font-semibold text-primary">
            Website Headlines
          </h2>

          <div className="rounded-xl border border-border bg-card p-6">
            <pre className="whitespace-pre-wrap font-sans text-sm leading-relaxed text-muted-foreground">
              {`Primary:
Private beta is open

Subhead:
No download. No account. No learning curve.

Support copy:
Join the invite-only beta waitlist. We'll email invite instructions as capacity opens.

Pricing strip:
$16/mo early bird for first 100 paid seats · then $19/mo · BYOK lifetime $299 (10 seats)

Post-payment copy:
Payment confirmed. Your invite instructions are on the way. Usually within 24h.`}
            </pre>
          </div>
        </section>

        <section className="mb-16">
          <h2 className="mb-6 border-b border-border pb-2 font-mono text-xl font-semibold text-primary">
            Ops Notes
          </h2>

          <div className="rounded-xl border border-border bg-card p-6">
            <pre className="whitespace-pre-wrap font-sans text-sm leading-relaxed text-muted-foreground">
              {`Daily runbook:
- Invite up to 10 waitlist users to pay
- Review successful Square payments in Clerk metadata
- Manually send invites to paid users only

Public proof:
- Counter uses successful payments only
- Social proof list uses anonymized initial + timestamp only
- No city or personal details`}
            </pre>
          </div>
        </section>
      </main>
    </div>
  )
}

function Tweet({
  number,
  children,
}: {
  number: number
  children: string
}) {
  return (
    <div className="rounded-xl border border-border bg-card p-5">
      <span className="mb-2 inline-block font-mono text-xs text-primary">Tweet {number}</span>
      <pre className="whitespace-pre-wrap font-sans text-sm leading-relaxed text-foreground">
        {children}
      </pre>
    </div>
  )
}
