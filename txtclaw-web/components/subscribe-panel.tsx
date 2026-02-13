"use client"

import { type FormEvent, useEffect, useMemo, useState } from "react"
import { ArrowRight, CheckCircle2, Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { cn } from "@/lib/utils"

type SubscribePanelProps = {
  email?: string
  betaState?: string
  offerCode?: string
  promoBalanceCents?: number
  promoTotalGrantedCents?: number
}

type LaunchStatsPayload = {
  ok?: boolean
  earlyBirdClaimed?: number
  earlyBirdCap?: number
  ltdClaimed?: number
  ltdCap?: number
}

type CheckoutResponse = {
  ok?: boolean
  checkoutUrl?: string
  error?: string
}

type PromoRedeemResponse = {
  ok?: boolean
  applied?: boolean
  idempotent?: boolean
  grantCents?: number
  balanceCents?: number
  totalGrantedCents?: number
  message?: string
  error?: string
}

const DEFAULT_STATS = {
  earlyBirdClaimed: 0,
  earlyBirdCap: 100,
  ltdClaimed: 0,
  ltdCap: 10,
}

function toUsd(cents: number) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(cents / 100)
}

export function SubscribePanel({
  email,
  betaState,
  offerCode,
  promoBalanceCents = 0,
  promoTotalGrantedCents = 0,
}: SubscribePanelProps) {
  const [stats, setStats] = useState(DEFAULT_STATS)
  const [loadingStats, setLoadingStats] = useState(true)
  const [loadingType, setLoadingType] = useState<"monthly" | "ltd" | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [promoCodeInput, setPromoCodeInput] = useState("")
  const [promoBalance, setPromoBalance] = useState(Math.max(promoBalanceCents, 0))
  const [promoTotalGranted, setPromoTotalGranted] = useState(
    Math.max(promoTotalGrantedCents, 0)
  )
  const [promoLoading, setPromoLoading] = useState(false)
  const [promoError, setPromoError] = useState<string | null>(null)
  const [promoNotice, setPromoNotice] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false

    const load = async () => {
      setLoadingStats(true)
      try {
        const response = await fetch("/api/launch/stats", {
          method: "GET",
          cache: "no-store",
        })
        const payload = (await response.json().catch(() => null)) as
          | LaunchStatsPayload
          | null

        if (cancelled) return
        if (!response.ok || !payload?.ok) {
          setStats(DEFAULT_STATS)
          return
        }

        setStats({
          earlyBirdClaimed:
            typeof payload.earlyBirdClaimed === "number"
              ? payload.earlyBirdClaimed
              : DEFAULT_STATS.earlyBirdClaimed,
          earlyBirdCap:
            typeof payload.earlyBirdCap === "number"
              ? payload.earlyBirdCap
              : DEFAULT_STATS.earlyBirdCap,
          ltdClaimed:
            typeof payload.ltdClaimed === "number"
              ? payload.ltdClaimed
              : DEFAULT_STATS.ltdClaimed,
          ltdCap:
            typeof payload.ltdCap === "number"
              ? payload.ltdCap
              : DEFAULT_STATS.ltdCap,
        })
      } finally {
        if (!cancelled) {
          setLoadingStats(false)
        }
      }
    }

    void load()

    return () => {
      cancelled = true
    }
  }, [])

  useEffect(() => {
    setPromoBalance(Math.max(promoBalanceCents, 0))
    setPromoTotalGranted(Math.max(promoTotalGrantedCents, 0))
  }, [promoBalanceCents, promoTotalGrantedCents])

  const earlyBirdRemaining = Math.max(stats.earlyBirdCap - stats.earlyBirdClaimed, 0)
  const ltdRemaining = Math.max(stats.ltdCap - stats.ltdClaimed, 0)
  const monthlyPrice = earlyBirdRemaining > 0 ? "$16/mo" : "$19/mo"
  const monthlyTag = earlyBirdRemaining > 0 ? "Early bird" : "Standard"
  const normalizedPromoCode = promoCodeInput.trim().toUpperCase()
  const promoBalanceLabel = useMemo(() => toUsd(promoBalance), [promoBalance])
  const promoTotalGrantedLabel = useMemo(
    () => toUsd(promoTotalGranted),
    [promoTotalGranted]
  )

  const alreadyPaid =
    betaState === "paid_waiting_apple_invite" || betaState === "apple_invited"

  const statusLabel = useMemo(() => {
    if (betaState === "apple_invited") return "Apple invite sent"
    if (betaState === "paid_waiting_apple_invite") return "Paid · awaiting Apple invite"
    if (betaState === "invited_to_pay") return "Invited to pay"
    if (betaState === "waitlist_pending") return "Waitlist pending"
    return "Invite in progress"
  }, [betaState])

  const startCheckout = async (offerType: "monthly" | "ltd") => {
    if (alreadyPaid) return
    if (offerType === "ltd" && ltdRemaining <= 0) return

    setError(null)
    setLoadingType(offerType)

    try {
      const response = await fetch("/api/billing/checkout", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ offerType }),
      })

      const payload = (await response.json().catch(() => null)) as
        | CheckoutResponse
        | null

      if (!response.ok || !payload?.ok || !payload.checkoutUrl) {
        throw new Error(payload?.error || "Unable to start checkout.")
      }

      window.location.assign(payload.checkoutUrl)
    } catch (checkoutError) {
      setError(
        checkoutError instanceof Error
          ? checkoutError.message
          : "Unable to start checkout."
      )
    } finally {
      setLoadingType(null)
    }
  }

  const redeemPromoCode = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (!normalizedPromoCode || promoLoading) return

    setPromoLoading(true)
    setPromoError(null)
    setPromoNotice(null)

    try {
      const response = await fetch("/api/promo/redeem", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          code: normalizedPromoCode,
        }),
      })

      const payload = (await response.json().catch(() => null)) as
        | PromoRedeemResponse
        | null

      if (!response.ok || !payload?.ok) {
        throw new Error(payload?.error || "Unable to redeem code.")
      }

      if (typeof payload.balanceCents === "number") {
        setPromoBalance(Math.max(payload.balanceCents, 0))
      }
      if (typeof payload.totalGrantedCents === "number") {
        setPromoTotalGranted(Math.max(payload.totalGrantedCents, 0))
      }

      if (payload.message) {
        setPromoNotice(payload.message)
      } else if (payload.idempotent) {
        setPromoNotice("Code already redeemed on this account.")
      } else {
        const granted = typeof payload.grantCents === "number" ? payload.grantCents : 0
        setPromoNotice(`Code redeemed. ${toUsd(granted)} added to usage credits.`)
      }

      setPromoCodeInput("")
    } catch (redeemError) {
      setPromoError(
        redeemError instanceof Error
          ? redeemError.message
          : "Unable to redeem code."
      )
    } finally {
      setPromoLoading(false)
    }
  }

  return (
    <div className="grid gap-6">
      <div className="rounded-xl border border-border/60 bg-card p-5 md:p-6">
        <div className="flex flex-wrap items-center gap-2">
          <Badge variant="secondary" className="font-mono text-[11px]">
            Apple beta billing
          </Badge>
          <Badge
            variant="outline"
            className="font-mono text-[11px] text-muted-foreground"
          >
            {statusLabel}
          </Badge>
        </div>
        <h1 className="mt-4 text-balance text-3xl font-semibold tracking-tight text-foreground md:text-4xl">
          Complete subscription
        </h1>
        <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground md:text-base">
          Fixed launch pricing. No negotiation. After successful payment,
          you&apos;ll receive Apple invite instructions. Usually within 24h.
        </p>
        {email ? (
          <p className="mt-3 text-xs text-muted-foreground">
            Signed in as <span className="text-foreground">{email}</span>
          </p>
        ) : null}
      </div>

      <Card className="border-foreground/15">
        <CardHeader>
          <CardTitle className="text-xl">Redeem launch credit code</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="rounded-lg border border-border/60 bg-muted/20 p-4">
            <p className="text-xs text-muted-foreground">Usage credit balance</p>
            <p className="mt-1 text-3xl font-bold text-foreground">{promoBalanceLabel}</p>
            <p className="mt-1 text-xs text-muted-foreground">
              Total granted to this account: {promoTotalGrantedLabel}
            </p>
          </div>
          <p className="text-xs text-muted-foreground">
            Credits apply to usage budget; subscription checkout is unchanged.
          </p>
          <form className="space-y-3" onSubmit={redeemPromoCode}>
            <Input
              value={promoCodeInput}
              onChange={(event) => setPromoCodeInput(event.target.value)}
              placeholder="TXT100-XXXXXXXXXXXX-XXXXXXXX"
              className="font-mono uppercase"
              maxLength={40}
              autoCapitalize="characters"
              autoCorrect="off"
              spellCheck={false}
            />
            <Button
              type="submit"
              variant="secondary"
              className="w-full gap-2 md:w-auto"
              disabled={!normalizedPromoCode || promoLoading}
            >
              {promoLoading ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  Redeeming...
                </>
              ) : (
                "Redeem code"
              )}
            </Button>
          </form>
          {promoNotice ? (
            <p className="text-sm text-emerald-300">{promoNotice}</p>
          ) : null}
          {promoError ? <p className="text-sm text-red-400">{promoError}</p> : null}
        </CardContent>
      </Card>

      <div className="grid gap-4 md:grid-cols-2">
        <Card className="border-foreground/15">
          <CardHeader>
            <CardTitle className="text-xl">Launch monthly</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-baseline gap-2">
              <span className="text-3xl font-bold text-foreground">{monthlyPrice}</span>
              <span className="rounded-full border border-border px-2 py-0.5 text-[11px] text-muted-foreground">
                {monthlyTag}
              </span>
            </div>
            <p className="text-sm text-muted-foreground">
              Early bird seats claimed: {stats.earlyBirdClaimed}/{stats.earlyBirdCap}
            </p>
            <p className="text-xs text-muted-foreground">
              {earlyBirdRemaining > 0
                ? `${earlyBirdRemaining} early bird seats remaining.`
                : "Early bird sold out. New checkouts use $19/mo."}
            </p>
            <Button
              className="w-full gap-2"
              onClick={() => startCheckout("monthly")}
              disabled={alreadyPaid || loadingType !== null}
            >
              {loadingType === "monthly" ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  Opening checkout...
                </>
              ) : (
                <>
                  Subscribe monthly
                  <ArrowRight className="h-4 w-4" />
                </>
              )}
            </Button>
          </CardContent>
        </Card>

        <Card className={cn("border-border", ltdRemaining <= 0 && "opacity-70")}>
          <CardHeader>
            <CardTitle className="text-xl">BYOK lifetime</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-baseline gap-2">
              <span className="text-3xl font-bold text-foreground">$299</span>
              <span className="text-xs text-muted-foreground">one-time</span>
            </div>
            <p className="text-sm text-muted-foreground">
              Lifetime seats claimed: {stats.ltdClaimed}/{stats.ltdCap}
            </p>
            <p className="text-xs text-muted-foreground">
              {ltdRemaining > 0
                ? `${ltdRemaining} lifetime seats remaining.`
                : "Lifetime allocation sold out."}
            </p>
            <Button
              variant="outline"
              className="w-full gap-2"
              onClick={() => startCheckout("ltd")}
              disabled={alreadyPaid || ltdRemaining <= 0 || loadingType !== null}
            >
              {loadingType === "ltd" ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  Opening checkout...
                </>
              ) : ltdRemaining <= 0 ? (
                "Sold out"
              ) : (
                "Claim lifetime"
              )}
            </Button>
          </CardContent>
        </Card>
      </div>

      {alreadyPaid ? (
        <div className="rounded-xl border border-emerald-500/40 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-200">
          <div className="flex items-center gap-2 text-emerald-100">
            <CheckCircle2 className="h-4 w-4" />
            Payment already confirmed.
          </div>
          <p className="mt-1 text-emerald-200/90">
            Your Apple invite instructions are on the way.
          </p>
        </div>
      ) : null}

      {offerCode ? (
        <p className="text-xs text-muted-foreground">
          Current offer code: <span className="text-foreground">{offerCode}</span>
        </p>
      ) : null}

      {loadingStats ? (
        <p className="text-xs text-muted-foreground">Loading live seat counters…</p>
      ) : null}

      {error ? <p className="text-sm text-red-400">{error}</p> : null}
    </div>
  )
}
