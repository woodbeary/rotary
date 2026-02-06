import { SmsDemo } from "./sms-demo"
import { ArrowRight } from "lucide-react"

export function Hero() {
  return (
    <section className="px-6 pb-24 pt-20 md:pt-28">
      <div className="mx-auto flex max-w-5xl flex-col items-center gap-16 lg:flex-row lg:items-start lg:gap-12">
        {/* Left: Copy */}
        <div className="flex max-w-xl flex-col gap-6 text-center lg:text-left">
          <p className="font-mono text-sm text-primary">SMS-based AI agent</p>

          <h1 className="text-balance text-4xl font-bold leading-tight tracking-tight text-foreground md:text-5xl lg:text-6xl">
            An AI that lives on a real phone number
          </h1>

          <p className="text-pretty text-lg leading-relaxed text-muted-foreground">
            Text it. It texts back. Your own persistent AI agent with memory,
            web browsing, code execution, and tools — all over plain SMS. No
            app. No login. Works on any phone.
          </p>

          <div className="flex flex-col items-center gap-4 sm:flex-row lg:items-start">
            <a
              href="sms:+15738792529"
              className="group flex items-center gap-2 rounded-lg bg-primary px-6 py-3.5 font-mono text-sm font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
            >
              Text +1 (573) 879-2529
              <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" />
            </a>
            <span className="text-sm text-muted-foreground">
              Free to try, no account needed
            </span>
          </div>
        </div>

        {/* Right: SMS Demo */}
        <div className="w-full max-w-sm shrink-0">
          <SmsDemo />
        </div>
      </div>
    </section>
  )
}
