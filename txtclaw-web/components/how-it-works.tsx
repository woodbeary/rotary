import { MessageSquare, Handshake, Smartphone, Settings } from "lucide-react"

const steps = [
  {
    icon: MessageSquare,
    number: "1",
    title: "Text the number",
    description:
      "Send anything to +1 (573) 879-2529. You'll hit the free gateway agent instantly. No signup.",
  },
  {
    icon: Handshake,
    number: "2",
    title: "Try it out, haggle a price",
    description:
      "Chat for free. Like it? Negotiate your first month's price with the AI. It starts at $19 but you can talk it down.",
  },
  {
    icon: Smartphone,
    number: "3",
    title: "Get your own number",
    description:
      "Pay and instantly receive a dedicated US phone number routed to your own private, persistent agent.",
  },
  {
    icon: Settings,
    number: "4",
    title: "Make it yours",
    description:
      "Custom prompts, BYOK model access, persistent memory. Your agent learns and grows with you.",
  },
]

export function HowItWorks() {
  return (
    <section id="how" className="px-6 py-24">
      <div className="mx-auto max-w-5xl">
        <p className="mb-3 font-mono text-sm text-primary">How it works</p>
        <h2 className="mb-12 text-3xl font-bold text-foreground md:text-4xl">
          Four texts to your own AI
        </h2>

        <div className="grid gap-px overflow-hidden rounded-xl border border-border bg-border md:grid-cols-2 lg:grid-cols-4">
          {steps.map((step) => (
            <div key={step.number} className="flex flex-col gap-4 bg-card p-6">
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10">
                  <step.icon className="h-5 w-5 text-primary" />
                </div>
                <span className="font-mono text-sm text-muted-foreground">
                  Step {step.number}
                </span>
              </div>
              <h3 className="text-lg font-semibold text-foreground">
                {step.title}
              </h3>
              <p className="text-sm leading-relaxed text-muted-foreground">
                {step.description}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
