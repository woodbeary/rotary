import { Brain, Globe, KeyRound, Lock, Smartphone } from "lucide-react"

const features = [
  {
    icon: Smartphone,
    title: "Real phone number, real SMS",
    description:
      "Your agent gets a dedicated US phone number. Text it from any phone, anywhere. No app, no login.",
  },
  {
    icon: Brain,
    title: "Persistent memory & tools",
    description:
      "Your agent remembers past conversations. It can browse the web, run code, and use tools on your behalf.",
  },
  {
    icon: KeyRound,
    title: "Bring your own keys",
    description:
      "Use your own API keys for OpenAI, Anthropic, or any supported model. Pay less, own more.",
  },
  {
    icon: Lock,
    title: "Privacy-first, no lock-in",
    description:
      "Your data stays yours. No unsolicited messages, ever. Cancel anytime, export everything.",
  },
  {
    icon: Globe,
    title: "Powered by OpenClaw on Cloudflare",
    description:
      "Built on the OpenClaw / Moltworker stack running at the edge. Fast, reliable, open.",
  },
]

export function Features() {
  return (
    <section className="mx-auto max-w-4xl px-4 py-20">
      <h2 className="mb-2 text-center text-sm font-medium uppercase tracking-widest text-primary">
        What you get
      </h2>
      <p className="mb-12 text-center text-2xl font-semibold text-foreground md:text-3xl">
        A real AI agent, not a chatbot toy
      </p>

      <div className="grid gap-6 md:grid-cols-2">
        {features.map((feature) => (
          <div
            key={feature.title}
            className="rounded-lg border border-border bg-card p-6"
          >
            <div className="mb-3 flex items-center gap-3">
              <feature.icon className="h-5 w-5 text-primary" />
              <h3 className="font-semibold text-foreground">{feature.title}</h3>
            </div>
            <p className="text-sm leading-relaxed text-muted-foreground">
              {feature.description}
            </p>
          </div>
        ))}
      </div>
    </section>
  )
}
