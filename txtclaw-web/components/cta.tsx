import { PhoneNumber } from "./phone-number"

export function CTA() {
  return (
    <section className="flex flex-col items-center gap-6 px-4 py-20 text-center">
      <h2 className="text-2xl font-semibold text-foreground md:text-3xl">
        Ready? Just text it.
      </h2>
      <p className="max-w-md text-muted-foreground">
        No sign-up form. No app store. Just send a message and meet your new AI
        agent.
      </p>
      <PhoneNumber />
    </section>
  )
}
