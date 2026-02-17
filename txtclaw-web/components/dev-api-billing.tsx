"use client"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Separator } from "@/components/ui/separator"
import { CheckCircle2, CreditCard, Loader2, RefreshCw } from "lucide-react"
import Link from "next/link"
import { useCallback, useEffect, useMemo, useState } from "react"
import { toast } from "sonner"

type ApiUserPlan = {
  userId: string
  plan: "free" | "pro" | "max" | "byok"
  provider?: "square" | "manual"
  offerCode?: string
  paidAt?: string
  updatedAt: string
}

function planLabel(plan: ApiUserPlan["plan"]) {
  if (plan === "pro") return "Pro"
  if (plan === "byok") return "BYOK"
  if (plan === "max") return "Max"
  return "Free"
}

export function DevApiBilling() {
  const [loadingPlan, setLoadingPlan] = useState(true)
  const [plan, setPlan] = useState<ApiUserPlan | null>(null)
  const [starting, setStarting] = useState<"monthly" | "ltd" | null>(null)

  const loadPlan = useCallback(async () => {
    setLoadingPlan(true)
    try {
      const res = await fetch("/api/console/plan", { method: "GET", cache: "no-store" })
      const data = (await res.json().catch(() => null)) as
        | { ok: true; plan: ApiUserPlan }
        | { ok: false; error: string }
        | null
      if (!res.ok || !data || !("ok" in data) || !data.ok) {
        throw new Error((data as any)?.error || "Failed to load plan.")
      }
      setPlan(data.plan)
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Failed to load plan.")
      setPlan(null)
    } finally {
      setLoadingPlan(false)
    }
  }, [])

  useEffect(() => {
    void loadPlan()
  }, [loadPlan])

  const current = useMemo(() => plan?.plan || "free", [plan])

  const startCheckout = useCallback(
    async (offerType: "monthly" | "ltd") => {
      if (starting) return
      setStarting(offerType)
      try {
        const res = await fetch("/api/billing/checkout", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ offerType }),
        })
        const data = (await res.json().catch(() => null)) as
          | { ok: true; checkoutUrl: string }
          | { ok: false; error: string }
          | null

        if (!res.ok || !data || !("ok" in data) || !data.ok || !("checkoutUrl" in data)) {
          throw new Error((data as any)?.error || "Unable to start checkout.")
        }

        window.location.assign(data.checkoutUrl)
      } catch (error) {
        toast.error(error instanceof Error ? error.message : "Unable to start checkout.")
      } finally {
        setStarting(null)
      }
    },
    [starting],
  )

  return (
    <div className="space-y-8">
      <header className="space-y-3">
        <div className="inline-flex items-center rounded-full border border-border/70 bg-muted/30 px-3 py-1 font-mono text-[11px] text-muted-foreground">
          Dev API Billing
        </div>
        <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
          Billing
        </h1>
        <p className="max-w-2xl text-sm leading-relaxed text-muted-foreground">
          Upgrade to raise hosted routing limits and unlock BYOK tiers. Rate limits are enforced in
          the Worker (no “best-effort” billing).
        </p>
      </header>

      <section className="grid gap-4 md:grid-cols-3">
        <Card className="rounded-2xl border-border/60">
          <CardHeader className="pb-3">
            <CardTitle className="text-base">Current plan</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="flex items-center gap-2">
              <Badge variant="secondary" className="font-mono text-[11px]">
                {loadingPlan ? "Loading…" : planLabel(current as any)}
              </Badge>
              {plan?.offerCode ? (
                <Badge variant="outline" className="font-mono text-[11px] text-muted-foreground">
                  {plan.offerCode}
                </Badge>
              ) : null}
            </div>
            <div className="text-xs text-muted-foreground">
              {plan?.updatedAt ? `Updated: ${new Date(plan.updatedAt).toLocaleString()}` : "—"}
            </div>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => void loadPlan()}
              disabled={loadingPlan}
            >
              <RefreshCw className="mr-2 h-4 w-4" />
              Refresh
            </Button>
          </CardContent>
        </Card>

        <Card className="rounded-2xl border-border/60">
          <CardHeader className="pb-3">
            <CardTitle className="text-base">Pro</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="text-sm text-muted-foreground">
              Higher limits on the hosted lane. Same API surface.
            </div>
            <Separator />
            <div className="space-y-1 text-xs text-muted-foreground">
              <div className="flex items-center gap-2">
                <CheckCircle2 className="h-4 w-4 text-emerald-400" />
                Plan-based rate limits (RPM + daily caps)
              </div>
              <div className="flex items-center gap-2">
                <CheckCircle2 className="h-4 w-4 text-emerald-400" />
                Traces + prompt versions + grading UI
              </div>
            </div>
            <Button
              className="w-full"
              onClick={() => void startCheckout("monthly")}
              disabled={starting !== null}
            >
              {starting === "monthly" ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Starting checkout…
                </>
              ) : (
                <>
                  <CreditCard className="mr-2 h-4 w-4" />
                  Upgrade (monthly)
                </>
              )}
            </Button>
          </CardContent>
        </Card>

        <Card className="rounded-2xl border-border/60">
          <CardHeader className="pb-3">
            <CardTitle className="text-base">BYOK lifetime</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="text-sm text-muted-foreground">
              Bring your own provider key. Stored encrypted. Higher caps.
            </div>
            <Separator />
            <div className="space-y-1 text-xs text-muted-foreground">
              <div className="flex items-center gap-2">
                <CheckCircle2 className="h-4 w-4 text-emerald-400" />
                BYOK lane (`PUT /v1/byok` + `llm.mode=\"byok\"`)
              </div>
              <div className="flex items-center gap-2">
                <CheckCircle2 className="h-4 w-4 text-emerald-400" />
                Higher plan-based limits
              </div>
            </div>
            <Button
              className="w-full"
              variant="secondary"
              onClick={() => void startCheckout("ltd")}
              disabled={starting !== null}
            >
              {starting === "ltd" ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Starting checkout…
                </>
              ) : (
                <>
                  <CreditCard className="mr-2 h-4 w-4" />
                  Upgrade (one-time)
                </>
              )}
            </Button>
          </CardContent>
        </Card>
      </section>

      <section className="rounded-2xl border border-border/60 bg-card p-6 md:p-8">
        <h2 className="text-lg font-semibold text-foreground">Pricing + limits</h2>
        <p className="mt-2 text-sm text-muted-foreground">
          Public docs are kept agent-friendly for AI search and copy/paste workflows.
        </p>
        <div className="mt-4 flex flex-wrap gap-3">
          <Link
            href="/pricing.md"
            className="inline-flex items-center rounded-md border border-border bg-background px-4 py-2 text-sm text-foreground hover:bg-accent"
          >
            View pricing
          </Link>
          <Link
            href="/rate-limits.md"
            className="inline-flex items-center rounded-md border border-border bg-background px-4 py-2 text-sm text-foreground hover:bg-accent"
          >
            View rate limits
          </Link>
        </div>
      </section>
    </div>
  )
}
