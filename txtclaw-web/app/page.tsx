import { AppleProofSection } from "@/components/apple-proof-section"
import { CTA } from "@/components/cta"
import { Features } from "@/components/features"
import { Footer } from "@/components/footer"
import { Hero } from "@/components/hero"
import { HowItWorks } from "@/components/how-it-works"
import { LifestyleHighlights } from "@/components/lifestyle-highlights"
import { Navbar } from "@/components/navbar"
import { Pricing } from "@/components/pricing"
import { SmsDemoSection } from "@/components/sms-demo-section"
import { WhyFirstSection } from "@/components/why-first-section"

export default function Page() {
  return (
    <div className="min-h-screen">
      <Navbar />
      <main>
        <Hero />
        <SmsDemoSection />
        <AppleProofSection />
        <HowItWorks />
        <Features />
        <Pricing />
        <CTA />
        <LifestyleHighlights />
        <WhyFirstSection />
      </main>
      <Footer />
    </div>
  )
}
