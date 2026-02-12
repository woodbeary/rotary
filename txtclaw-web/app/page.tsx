import { Navbar } from "@/components/navbar"
import { Hero } from "@/components/hero"
import { LifestyleHighlights } from "@/components/lifestyle-highlights"
import { AppleProofSection } from "@/components/apple-proof-section"
import { HowItWorks } from "@/components/how-it-works"
import { Features } from "@/components/features"
import { Pricing } from "@/components/pricing"
import { CTA } from "@/components/cta"
import { Footer } from "@/components/footer"

export default function Page() {
  return (
    <div className="min-h-screen">
      <Navbar />
      <main>
        <Hero />
        <LifestyleHighlights />
        <AppleProofSection />
        <HowItWorks />
        <Features />
        <Pricing />
        <CTA />
      </main>
      <Footer />
    </div>
  )
}
