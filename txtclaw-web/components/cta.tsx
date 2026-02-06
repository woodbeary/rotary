import { ArrowRight } from "lucide-react"

export function CTA() {
  return (
    <section className="px-6 py-24">
      <div className="mx-auto max-w-3xl rounded-2xl border border-primary/20 bg-primary/5 p-8 text-center md:p-12">
        <h2 className="mb-3 text-3xl font-bold text-foreground md:text-4xl">
          Ready? Just text it.
        </h2>
        <p className="mx-auto mb-8 max-w-md text-muted-foreground">
          No sign-up form. No app store. Send a text, meet your AI.
        </p>
        <a
          href="sms:+15738792529"
          className="group inline-flex items-center gap-2 rounded-lg bg-primary px-8 py-4 font-mono text-base font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
        >
          Text +1 (573) 879-2529
          <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" />
        </a>
      </div>
    </section>
  )
}
