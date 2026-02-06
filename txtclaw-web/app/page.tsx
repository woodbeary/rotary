import { Navbar } from "@/components/navbar"
import { Hero } from "@/components/hero"
import { Features } from "@/components/features"
import { HowItWorks } from "@/components/how-it-works"
import { Pricing } from "@/components/pricing"
import { CTA } from "@/components/cta"
import { Footer } from "@/components/footer"

export default function Page() {
  return (
    <div className="min-h-screen">
      <Navbar />
      <main>
        <Hero />
        <div className="mx-auto max-w-5xl border-t border-border" />
        <div id="features">
          <Features />
        </div>
        <div className="mx-auto max-w-5xl border-t border-border" />
        <HowItWorks />
        <div className="mx-auto max-w-5xl border-t border-border" />
        <div id="pricing">
          <Pricing />
        </div>
        <div className="mx-auto max-w-5xl border-t border-border" />
        <CTA />
      </main>
      <Footer />
    </div>
  )
}
