import { Check } from "lucide-react"

const tiers = [
  {
    name: "Pro",
    price: "$19",
    period: "/mo",
    description: "For most people. A capable personal AI agent on SMS.",
    features: [
      "Dedicated US phone number",
      "Persistent memory across conversations",
      "Web browsing & code execution",
      "Custom system prompts",
      "Standard model access",
    ],
    highlight: true,
  },
  {
    name: "Max",
    price: "$49",
    period: "/mo",
    description: "For power users who want the full stack.",
    features: [
      "Everything in Pro",
      "Priority response times",
      "Advanced browser automation",
      "Higher usage limits",
      "Early access to new tools",
    ],
    highlight: false,
  },
  {
    name: "BYOK",
    price: "$12",
    period: "/mo",
    description: "Bring your own API keys. Pay for what you use.",
    features: [
      "Everything in Pro",
      "Use your own OpenAI / Anthropic keys",
      "No markup on model costs",
      "Full model selection",
      "Same great agent infrastructure",
    ],
    highlight: false,
  },
]

export function Pricing() {
  return (
    <section className="mx-auto max-w-5xl px-4 py-20">
      <h2 className="mb-2 text-center text-sm font-medium uppercase tracking-widest text-primary">
        Pricing
      </h2>
      <p className="mb-4 text-center text-2xl font-semibold text-foreground md:text-3xl">
        Simple, honest pricing
      </p>
      <p className="mx-auto mb-12 max-w-md text-center text-sm text-muted-foreground">
        Try it free first. Then negotiate your intro price with the AI — floor
        is $12/mo for BYOK. No hidden fees.
      </p>

      <div className="grid gap-6 md:grid-cols-3">
        {tiers.map((tier) => (
          <div
            key={tier.name}
            className={`flex flex-col rounded-lg border p-6 ${
              tier.highlight
                ? "border-primary/40 bg-primary/5"
                : "border-border bg-card"
            }`}
          >
            <h3 className="mb-1 text-lg font-semibold text-foreground">
              {tier.name}
            </h3>
            <div className="mb-3 flex items-baseline gap-1">
              <span className="text-3xl font-bold text-foreground">
                {tier.price}
              </span>
              <span className="text-sm text-muted-foreground">
                {tier.period}
              </span>
            </div>
            <p className="mb-6 text-sm text-muted-foreground">
              {tier.description}
            </p>
            <ul className="mb-6 flex flex-col gap-3">
              {tier.features.map((feature) => (
                <li
                  key={feature}
                  className="flex items-start gap-2 text-sm text-muted-foreground"
                >
                  <Check className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
                  <span>{feature}</span>
                </li>
              ))}
            </ul>
            <a
              href="sms:+15738792529"
              className={`mt-auto rounded-md px-4 py-2.5 text-center text-sm font-medium transition-colors ${
                tier.highlight
                  ? "bg-primary text-primary-foreground hover:bg-primary/90"
                  : "border border-border bg-secondary text-secondary-foreground hover:bg-secondary/80"
              }`}
            >
              Text to start
            </a>
          </div>
        ))}
      </div>
    </section>
  )
}
