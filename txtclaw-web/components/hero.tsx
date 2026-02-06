import { PhoneNumber } from "./phone-number"

export function Hero() {
  return (
    <section className="flex flex-col items-center gap-8 px-4 pb-20 pt-24 text-center md:pt-32">
      <div className="inline-flex items-center gap-2 rounded-full border border-border px-3 py-1 text-sm text-muted-foreground">
        <span className="inline-block h-2 w-2 rounded-full bg-primary" />
        <span>Live now — text it and see</span>
      </div>

      <h1 className="max-w-3xl text-balance text-4xl font-bold tracking-tight text-foreground md:text-6xl">
        Your personal AI that lives on a real phone number
      </h1>

      <p className="max-w-xl text-pretty text-lg leading-relaxed text-muted-foreground md:text-xl">
        Text it like a friend, no app needed. Get your own dedicated US number
        routed to a private, persistent AI agent with memory, tools, and full
        autonomy.
      </p>

      <PhoneNumber />

      <p className="text-sm text-muted-foreground">
        Free to try. No app download. No account needed to start.
      </p>
    </section>
  )
}
