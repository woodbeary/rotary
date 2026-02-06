const steps = [
  {
    number: "01",
    title: "Text the gateway number",
    description:
      "Send any message to +1 (573) 879-2529. You'll get a free taste of your AI agent — no account needed.",
  },
  {
    number: "02",
    title: "Chat & negotiate",
    description:
      "Try the agent for free (limited turns). If you like it, negotiate a fun discount for your first month. Yes, really.",
  },
  {
    number: "03",
    title: "Get your own number",
    description:
      "On payment, you instantly receive a dedicated US phone number routed to your own private agent.",
  },
  {
    number: "04",
    title: "Make it yours",
    description:
      "Customize prompts, connect your own API keys, use tools — your agent evolves with you over time.",
  },
]

export function HowItWorks() {
  return (
    <section className="mx-auto max-w-3xl px-4 py-20">
      <h2 className="mb-2 text-center text-sm font-medium uppercase tracking-widest text-primary">
        How it works
      </h2>
      <p className="mb-12 text-center text-2xl font-semibold text-foreground md:text-3xl">
        Four texts to your own AI
      </p>

      <div className="flex flex-col gap-8">
        {steps.map((step) => (
          <div key={step.number} className="flex gap-5">
            <span className="shrink-0 font-mono text-3xl font-bold text-primary/30">
              {step.number}
            </span>
            <div>
              <h3 className="mb-1 font-semibold text-foreground">
                {step.title}
              </h3>
              <p className="text-sm leading-relaxed text-muted-foreground">
                {step.description}
              </p>
            </div>
          </div>
        ))}
      </div>
    </section>
  )
}
