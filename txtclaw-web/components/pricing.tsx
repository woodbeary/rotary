import { Check, ArrowRight } from "lucide-react"

const tiers = [
  {
    name: "Pro",
    price: "$19",
    period: "/mo",
    description: "A capable personal AI agent over SMS.",
    features: [
      "Dedicated US phone number",
      "Persistent memory",
      "Web browsing & code execution",
      "Custom system prompts",
      "Standard model access",
    ],
    highlight: true,
    label: "Most popular",
  },
  {
    name: "Max",
    price: "$49",
    period: "/mo",
    description: "For power users who want everything.",
    features: [
      "Everything in Pro",
      "Priority response times",
      "Advanced browser automation",
      "Higher usage limits",
      "Early access to new tools",
    ],
    highlight: false,
    label: null,
  },
  {
    name: "BYOK",
    price: "$12",
    period: "/mo",
    description: "Bring your own API keys. Pay for what you use.",
    features: [
      "Everything in Pro",
      "Your own OpenAI / Anthropic keys",
      "No markup on model costs",
      "Full model selection",
      "Same agent infrastructure",
    ],
    highlight: false,
    label: "Best value",
  },
]

export function Pricing() {
  return (
    <section id="pricing" className="px-6 py-24">
      <div className="mx-auto max-w-5xl">
        <p className="mb-3 font-mono text-sm text-primary">Pricing</p>
        <h2 className="mb-4 text-3xl font-bold text-foreground md:text-4xl">
          Simple, honest pricing
        </h2>
        <p className="mb-12 max-w-md text-muted-foreground">
          Try it free. Then negotiate your intro price with the AI. Seriously
          — the floor is $12/mo.
        </p>

        <div className="grid gap-6 lg:grid-cols-3">
          {tiers.map((tier) => (
            <div
              key={tier.name}
              className={`relative flex flex-col rounded-xl border p-6 ${
                tier.highlight
                  ? "border-primary/50 bg-primary/5"
                  : "border-border bg-card"
              }`}
            >
              {tier.label && (
                <span className="absolute -top-3 left-4 rounded-full bg-primary px-3 py-1 font-mono text-xs font-semibold text-primary-foreground">
                  {tier.label}
                </span>
              )}

              <h3 className="mb-1 font-mono text-lg font-bold text-foreground">
                {tier.name}
              </h3>
              <div className="mb-3 flex items-baseline gap-1">
                <span className="text-4xl font-bold tracking-tight text-foreground">
                  {tier.price}
                </span>
                <span className="text-sm text-muted-foreground">
                  {tier.period}
                </span>
              </div>
              <p className="mb-6 text-sm text-muted-foreground">
                {tier.description}
              </p>

              <ul className="mb-8 flex flex-col gap-3">
                {tier.features.map((feature) => (
                  <li
                    key={feature}
                    className="flex items-start gap-2.5 text-sm text-muted-foreground"
                  >
                    <Check className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
                    <span>{feature}</span>
                  </li>
                ))}
              </ul>

              <a
                href="sms:+15738792529"
                className={`mt-auto flex items-center justify-center gap-2 rounded-lg px-4 py-3 text-sm font-medium transition-colors ${
                  tier.highlight
                    ? "bg-primary text-primary-foreground hover:bg-primary/90"
                    : "border border-border bg-secondary text-secondary-foreground hover:bg-secondary/80"
                }`}
              >
                Get started
                <ArrowRight className="h-3.5 w-3.5" />
              </a>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
