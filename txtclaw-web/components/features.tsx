import { Brain, Globe, KeyRound, Lock, Smartphone } from "lucide-react"

const features = [
  {
    icon: Smartphone,
    title: "Real phone number",
    description:
      "A dedicated US number that's yours. Text it from any phone on the planet. No apps, no accounts.",
  },
  {
    icon: Brain,
    title: "Persistent memory",
    description:
      "Your agent remembers every conversation. Context builds over time. It actually knows you.",
  },
  {
    icon: Globe,
    title: "Web + code execution",
    description:
      "Browse the web, run code, automate tasks. Not a chatbot — an agent that does things.",
  },
  {
    icon: KeyRound,
    title: "Bring your own keys",
    description:
      "Use your OpenAI, Anthropic, or any supported model API keys. No markup on model costs.",
  },
  {
    icon: Lock,
    title: "Privacy-first, no lock-in",
    description:
      "No unsolicited messages. No data selling. Cancel anytime. Export everything.",
  },
]

export function Features() {
  return (
    <section id="features" className="px-6 py-24">
      <div className="mx-auto max-w-5xl">
        <p className="mb-3 font-mono text-sm text-primary">Capabilities</p>
        <h2 className="mb-4 max-w-lg text-3xl font-bold text-foreground md:text-4xl">
          Not a chatbot. An agent that works for you.
        </h2>
        <p className="mb-12 max-w-lg text-muted-foreground">
          Everything you need from an AI assistant, delivered over the simplest interface there is: a text message.
        </p>

        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((feature) => (
            <div
              key={feature.title}
              className="group rounded-xl border border-border bg-card p-6 transition-colors hover:border-primary/30"
            >
              <div className="mb-4 flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10 transition-colors group-hover:bg-primary/20">
                <feature.icon className="h-5 w-5 text-primary" />
              </div>
              <h3 className="mb-2 font-semibold text-foreground">
                {feature.title}
              </h3>
              <p className="text-sm leading-relaxed text-muted-foreground">
                {feature.description}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
