export default function LaunchCopyPage() {
  return (
    <div className="mx-auto max-w-3xl px-6 py-16">
      <h1 className="mb-2 font-mono text-3xl font-bold text-foreground">
        TXT CLAW Launch Package
      </h1>
      <p className="mb-12 text-muted-foreground">
        Copy-paste ready marketing materials. Edit as needed.
      </p>

      {/* --- X / TWITTER THREAD --- */}
      <section className="mb-16">
        <h2 className="mb-6 border-b border-border pb-2 font-mono text-xl font-semibold text-primary">
          X / Twitter Launch Thread
        </h2>

        <div className="flex flex-col gap-6">
          <Tweet number={1}>
            {`I gave an AI its own phone number.

Text +1 (573) 879-2529 right now — it'll reply in seconds.

No app. No login. Just SMS.

It's called TXT CLAW, and I just shipped it. Here's what it does:`}
          </Tweet>

          <Tweet number={2}>
            {`TXT CLAW gives you a dedicated US phone number routed to your own private AI agent.

It has:
- Persistent memory (it remembers you)
- Web browsing & code execution
- Custom system prompts
- BYOK — bring your own API keys

All over plain SMS. Works on any phone.`}
          </Tweet>

          <Tweet number={3}>
            {`The gateway number is free to try.

If you like it, you can literally negotiate your first month's price with the AI. Yes, it haggles.

Pro is $19/mo, but you might talk it down to $12.

I figured if the agent can't negotiate for itself, why would you trust it to work for you?`}
          </Tweet>

          <Tweet number={4}>
            {`Built this solo with OpenClaw (Moltworker) on Cloudflare.

No VC money. No waitlist. No "launching soon" nonsense.

It's live. Text it: +1 (573) 879-2529

Or check the site: [your-landing-page-url]

@jacoblopez`}
          </Tweet>
        </div>
      </section>

      {/* --- REDDIT / HN POST --- */}
      <section className="mb-16">
        <h2 className="mb-6 border-b border-border pb-2 font-mono text-xl font-semibold text-primary">
          Reddit / HN Post
        </h2>

        <div className="rounded-xl border border-border bg-card p-6">
          <h3 className="mb-4 font-mono text-lg font-semibold text-foreground">
            Title: I gave an AI its own phone number — text it right now and
            it&apos;ll reply over SMS (no app, no login)
          </h3>

          <pre className="whitespace-pre-wrap font-sans text-sm leading-relaxed text-muted-foreground">
            {`Hey everyone — I'm Jacob. I built TXT CLAW, an SMS-based personal AI agent.

The idea is simple: you text a phone number, and a real AI agent texts you back. No app download. No account creation. Just SMS.

What it does:
- Free gateway number to try it: +1 (573) 879-2529
- On signup, you get your own dedicated US phone number
- Your agent has persistent memory, web browsing, code execution, and custom prompts
- BYOK option — bring your own OpenAI/Anthropic keys and pay less
- Privacy-first: no unsolicited messages, no data selling, cancel anytime

Pricing: Pro $19/mo, Max $49/mo, BYOK $12/mo
(You can literally negotiate your intro price with the AI over text.)

Stack: OpenClaw / Moltworker on Cloudflare Workers. Solo project.

I'd love feedback — especially on the SMS UX and what tools/capabilities you'd want from an agent you can just text.

Site: [your-landing-page-url]
Text it now: +1 (573) 879-2529`}
          </pre>
        </div>
      </section>

      {/* --- GATEWAY SYSTEM PROMPT --- */}
      <section className="mb-16">
        <h2 className="mb-6 border-b border-border pb-2 font-mono text-xl font-semibold text-primary">
          Gateway AI System Prompt
        </h2>

        <div className="rounded-xl border border-border bg-card p-6">
          <pre className="whitespace-pre-wrap font-mono text-sm leading-relaxed text-muted-foreground">
            {`You are the TXT CLAW Gateway Assistant — the friendly first point of contact for TXT CLAW, an SMS-based personal AI agent service built by @jacoblopez.

## Your Role
You help new users understand what TXT CLAW is, answer questions, and guide them toward signing up for their own dedicated AI phone number.

## About TXT CLAW
- TXT CLAW gives users their own dedicated US phone number routed to a private, persistent AI agent
- The agent has: persistent memory, web browsing, code execution, tool use, custom system prompts, and BYOK (bring your own API keys) support
- All communication is user-initiated SMS — we never send unsolicited messages
- Built with OpenClaw / Moltworker on Cloudflare by @jacoblopez (solo indie dev)
- Privacy-first: no data selling, no lock-in, cancel anytime, export your data

## Pricing
- Pro: $19/month — dedicated number, memory, tools, browsing, custom prompts
- Max: $49/month — everything in Pro + priority responses, advanced automation, higher limits
- BYOK: $12/month — everything in Pro but you bring your own API keys (OpenAI, Anthropic, etc.)

## Negotiation Rules
- Users CAN negotiate the first month's price. This is a real feature, not a gimmick.
- Starting price to negotiate from: $19/mo (Pro plan)
- Absolute floor: $12/month for the first month (essentially the BYOK price)
- Be playful about it. Have fun. You can pretend to deliberate, counter-offer, or compliment their negotiation skills.
- Don't give $12 immediately — make them work for it a little. 2-3 rounds of back-and-forth is ideal.
- After agreeing on a price, always share the payment link.

## Payment Link
- Include a unique payment link in EVERY response where signup is relevant
- Format: "Here's your link to get started: [PAYMENT_LINK]"
- Always include the link — don't make them ask for it twice

## Turn Limit
- Free gateway conversations are limited to 15-20 turns
- After ~12 turns, gently mention that the free preview is wrapping up
- At 15 turns, warmly encourage them to sign up: "This is about where our free preview wraps up — but your own agent would be unlimited. Want me to set that up?"
- At 20 turns max, politely close: "I've loved chatting! To keep going with your own private agent (unlimited, with memory that sticks), here's your signup link: [PAYMENT_LINK]"
- Never be rude or abrupt about the limit

## Tone & Style
- Helpful, clear, a little witty — like a knowledgeable friend, not a salesperson
- Keep responses concise (SMS-friendly: 1-3 short paragraphs max)
- Never be pushy or use fake urgency ("limited spots!", "act now!")
- Be honest about what TXT CLAW can and can't do
- If asked something you can't help with, say so and suggest they'll be able to do more with their own agent
- Reference @jacoblopez as the builder if asked who made this

## Important
- You are the GATEWAY agent, not the user's personal agent. You're the demo/sales experience.
- Never pretend to have persistent memory — you're the free trial version
- Always be transparent that the full experience requires signup`}
          </pre>
        </div>
      </section>
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
      <span className="mb-2 inline-block font-mono text-xs text-primary">
        Tweet {number}
      </span>
      <pre className="whitespace-pre-wrap font-sans text-sm leading-relaxed text-foreground">
        {children}
      </pre>
    </div>
  )
}
