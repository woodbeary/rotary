"use client"

import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Separator } from "@/components/ui/separator"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Copy, RefreshCw, ShieldAlert, ShieldCheck, ShieldOff, TriangleAlert } from "lucide-react"
import { useCallback, useEffect, useMemo, useState } from "react"
import { toast } from "sonner"

type ActorStatus = "clean" | "warned" | "paused" | "disabled" | "unknown"

type ComplianceActor = {
  actorId: string
  userId?: string
  ownerPhone?: string | null
  campaignId?: string | null
  status: ActorStatus
  tier?: string
  riskScore?: number | null
  riskScore1h?: number | null
  riskScore24h?: number | null
  riskScore7d?: number | null
  stopRate?: number | null
  complaintRate?: number | null
  undeliveredRate?: number | null
  burstRatePerMinute?: number | null
  firstPartyUseRate?: number | null
  lastActionAt?: string | null
}

type ComplianceEvent = {
  eventId: string
  actorId: string
  kind: string
  occurredAt: string
  severity: string | undefined
  phone: string | undefined
  toNumber: string | undefined
  traceId: string | undefined
  campaignId: string | undefined
  status: string | undefined
  httpStatus: number | null
  errorCode: string | undefined
  messageSid: string | undefined
  note: string | undefined
}

type ComplianceAction =
  | "warn_actor"
  | "pause_actor_egress"
  | "disable_actor_numbers"
  | "unfreeze_actor"

function normalizeActor(raw: unknown): ComplianceActor | null {
  if (!raw || typeof raw !== "object") return null
  const asRecord = raw as Record<string, unknown>
  const actorId = String(asRecord.actor_id || asRecord.actorId || asRecord.user_id || "").trim()
  if (!actorId) return null

  const riskScore = asNumber(asRecord.risk_score ?? asRecord.riskScore)
  const riskScore1h = asNumber(asRecord.risk_score_1h ?? asRecord.riskScore1h)
  const riskScore24h = asNumber(asRecord.risk_score_24h ?? asRecord.riskScore24h)
  const riskScore7d = asNumber(asRecord.risk_score_7d ?? asRecord.riskScore7d)
  const status = normalizeStatus(asRecord.status || asRecord.state)

  return {
    actorId,
    userId: asString(asRecord.user_id || asRecord.userId) || undefined,
    ownerPhone: asString(asRecord.owner_phone || asRecord.ownerPhone),
    campaignId: asString(asRecord.campaign_id || asRecord.campaignId) || null,
    status,
    tier: asString(asRecord.tier) || undefined,
    riskScore,
    riskScore1h,
    riskScore24h,
    riskScore7d,
    stopRate: asRate(asRecord.stop_rate || asRecord.stopRate),
    complaintRate: asRate(asRecord.complaint_rate || asRecord.complaintRate),
    undeliveredRate: asRate(asRecord.undelivered_rate || asRecord.undeliveredRate),
    burstRatePerMinute: asNumber(asRecord.burst_rate_per_minute || asRecord.burstRatePerMinute),
    firstPartyUseRate: asRate(asRecord.first_party_use_rate || asRecord.firstPartyUseRate),
    lastActionAt: asString(asRecord.last_action_at || asRecord.lastActionAt),
  }
}

function normalizeEvents(raw: unknown): ComplianceEvent[] {
  if (!Array.isArray(raw)) return []
  return raw
    .map((item) => {
      if (!item || typeof item !== "object") return null
      const asRecord = item as Record<string, unknown>
      const eventId = String(asRecord.event_id || asRecord.eventId || asRecord.id || "").trim()
      if (!eventId) return null
      return {
        eventId,
        actorId: String(asRecord.actor_id || asRecord.actorId || "").trim(),
        kind: String(asRecord.kind || "event").trim(),
        occurredAt:
          asString(asRecord.occurred_at || asRecord.occurredAt) || new Date().toISOString(),
        severity: asString(asRecord.severity) || undefined,
        phone: asString(asRecord.phone),
        toNumber: asString(asRecord.to_number || asRecord.toNumber) || undefined,
        traceId: asString(asRecord.trace_id || asRecord.traceId) || undefined,
        campaignId: asString(asRecord.campaign_id || asRecord.campaignId) || undefined,
        status: asString(asRecord.status) || undefined,
        httpStatus: asNumber(asRecord.http_status || asRecord.httpStatus),
        errorCode: asString(asRecord.error_code || asRecord.errorCode) || undefined,
        messageSid: asString(asRecord.message_sid || asRecord.messageSid) || undefined,
        note: asString(asRecord.note) || undefined,
      }
    })
    .filter((value): value is ComplianceEvent => Boolean(value))
}

function asString(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined
  const text = value.trim()
  return text.length ? text : undefined
}

function asNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value
  if (typeof value === "string") {
    const parsed = Number.parseFloat(value)
    return Number.isFinite(parsed) ? parsed : null
  }
  return null
}

function asRate(value: unknown): number | null {
  if (value === undefined || value === null) return null
  const parsed = asNumber(value)
  if (parsed === null) return null
  return Math.min(Math.max(parsed, 0), 100)
}

function normalizeStatus(value: unknown): ActorStatus {
  const raw = String(value || "")
    .trim()
    .toLowerCase()
  if (raw === "warned" || raw === "paused" || raw === "disabled" || raw === "clean") return raw
  return "unknown"
}

function clamp(num: number, min: number, max: number) {
  return Math.min(Math.max(num, min), max)
}

function formatIso(iso: string | undefined | null) {
  if (!iso) return "—"
  try {
    return new Date(iso).toLocaleString()
  } catch {
    return iso
  }
}

function scoreBadge(score: number | null | undefined) {
  if (score === null || score === undefined) return "—"
  const normalized = clamp(Math.round(score * 10), 0, 100)
  if (normalized >= 80) return `🟥 ${normalized}`
  if (normalized >= 50) return `🟧 ${normalized}`
  return `🟩 ${normalized}`
}

async function copy(text: string) {
  try {
    await navigator.clipboard.writeText(text)
    toast.success("Copied.")
  } catch {
    toast.error("Clipboard copy failed on this device.")
  }
}

function actionLabel(action: ComplianceAction): string {
  if (action === "warn_actor") return "Warn"
  if (action === "pause_actor_egress") return "Pause 60m"
  if (action === "disable_actor_numbers") return "Disable"
  return "Unfreeze"
}

export function AdminCompliance() {
  const [loading, setLoading] = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)
  const [cursor, setCursor] = useState<string | null>(null)
  const [actors, setActors] = useState<ComplianceActor[]>([])
  const [query, setQuery] = useState("")
  const [statusFilter, setStatusFilter] = useState<ActorStatus | "all">("all")
  const [eventsLoading, setEventsLoading] = useState(false)
  const [eventsActorId, setEventsActorId] = useState<string | null>(null)
  const [events, setEvents] = useState<ComplianceEvent[]>([])
  const [acting, setActing] = useState<Record<string, boolean>>({})

  const loadActors = useCallback(
    async ({ reset }: { reset: boolean }) => {
      const limit = 50
      const q = new URLSearchParams()
      q.set("limit", String(limit))
      if (!reset && cursor) q.set("cursor", cursor)
      if (statusFilter !== "all") q.set("status", statusFilter)
      if (query.trim()) q.set("search", query.trim())

      try {
        if (reset) setLoading(true)
        else setLoadingMore(true)
        const res = await fetch(`/api/console/compliance/actors?${q.toString()}`, {
          method: "GET",
          cache: "no-store",
        })
        const data = (await res.json()) as
          | { ok: true; actors: unknown[]; cursor: string | null }
          | { ok: false; error: string }
        if (!data.ok) throw new Error(data.error)

        const nextActors = data.actors
          .map(normalizeActor)
          .filter((value): value is ComplianceActor => Boolean(value))
        setCursor(data.cursor ?? null)
        setActors((prev) => (reset ? nextActors : [...prev, ...nextActors]))
      } catch (error) {
        toast.error(error instanceof Error ? error.message : "Failed to load actors.")
      } finally {
        setLoading(false)
        setLoadingMore(false)
      }
    },
    [cursor, query, statusFilter],
  )

  const loadEvents = useCallback(async (actorId: string) => {
    setEventsLoading(true)
    setEventsActorId(actorId)
    try {
      const q = new URLSearchParams({ actor_id: actorId, limit: "50" })
      const res = await fetch(`/api/console/compliance/actors/events?${q.toString()}`, {
        method: "GET",
        cache: "no-store",
      })
      const data = (await res.json()) as
        | { ok: true; events: unknown[]; cursor: string | null }
        | { ok: false; error: string }
      if (!data.ok) throw new Error(data.error)
      setEvents(normalizeEvents(data.events))
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Failed to load actor events.")
      setEvents([])
    } finally {
      setEventsLoading(false)
    }
  }, [])

  useEffect(() => {
    void loadActors({ reset: true })
    setEvents([])
    setEventsActorId(null)
  }, [loadActors])

  const filteredActors = useMemo(() => {
    const search = query.trim().toLowerCase()
    return actors.filter((actor) => {
      if (statusFilter !== "all" && actor.status !== statusFilter) return false
      if (!search) return true
      return (
        actor.actorId.toLowerCase().includes(search) ||
        (actor.userId || "").toLowerCase().includes(search) ||
        (actor.ownerPhone || "").toLowerCase().includes(search) ||
        (actor.campaignId || "").toLowerCase().includes(search)
      )
    })
  }, [actors, query, statusFilter])

  const handleAction = useCallback(
    async (actor: ComplianceActor, action: ComplianceAction) => {
      const key = `${actor.actorId}:${action}`
      if (acting[key]) return

      let confirmedMessage = `Apply ${actionLabel(action)} to actor ${actor.actorId}?`
      if (action === "pause_actor_egress") {
        confirmedMessage = `Pause outbound traffic for actor ${actor.actorId} for 60 minutes?`
      }
      if (action === "disable_actor_numbers") {
        confirmedMessage = `Hard-disable actor ${actor.actorId} dedicated numbers now?`
      }
      if (action === "unfreeze_actor") {
        confirmedMessage = `Unfreeze actor ${actor.actorId} and resume dedicated number sending?`
      }
      if (!window.confirm(confirmedMessage)) return

      const reason = window.prompt("Why is this action needed?")
      if (reason === null) return
      const cleanedReason = reason.trim()
      if (!cleanedReason) {
        toast.error("Reason is required for this action.")
        return
      }

      setActing((prev) => ({ ...prev, [key]: true }))
      try {
        const body: {
          actorId: string
          action: ComplianceAction
          reason?: string
          durationMinutes?: number
        } = {
          actorId: actor.actorId,
          action,
          reason: cleanedReason,
        }

        if (action === "pause_actor_egress") {
          body.durationMinutes = 60
        }

        const res = await fetch("/api/console/compliance/actors/action", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(body),
        })
        const data = (await res.json()) as
          | {
              ok: true
              actor?: ComplianceActor | null
              action: ComplianceAction
              actionId?: string
            }
          | { ok: false; error: string }
        if (!data.ok) throw new Error(data.error)

        if (data.actor) {
          const nextActor = data.actor
          setActors((prev) =>
            prev.map((entry) => (entry.actorId === actor.actorId ? nextActor : entry)),
          )
        } else {
          await loadActors({ reset: true })
        }

        if (eventsActorId === actor.actorId) await loadEvents(actor.actorId)
        toast.success(`Action ${actionLabel(action).toLowerCase()} for ${actor.actorId}.`)
      } catch (error) {
        toast.error(error instanceof Error ? error.message : "Action failed.")
      } finally {
        setActing((prev) => ({ ...prev, [key]: false }))
      }
    },
    [acting, eventsActorId, loadActors, loadEvents],
  )

  return (
    <div className="space-y-8">
      <header className="space-y-3">
        <div className="inline-flex items-center rounded-full border border-border/70 bg-muted/30 px-3 py-1 font-mono text-[11px] text-muted-foreground">
          Anti-abuse
        </div>
        <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
          Compliance controls
        </h1>
        <p className="max-w-2xl text-sm leading-relaxed text-muted-foreground">
          Review actor risk telemetry, run reversible controls, and keep evidence-driven history.
        </p>
      </header>

      <section className="rounded-2xl border border-border/60 bg-card p-4 md:p-6">
        <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <div className="flex flex-1 items-center gap-2">
            <Input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search actor id, user id, phone, campaign"
            />
            <Select
              value={statusFilter}
              onValueChange={(v) => setStatusFilter(v as ActorStatus | "all")}
            >
              <SelectTrigger className="w-[170px]">
                <SelectValue placeholder="Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All</SelectItem>
                <SelectItem value="clean">Clean</SelectItem>
                <SelectItem value="warned">Warned</SelectItem>
                <SelectItem value="paused">Paused</SelectItem>
                <SelectItem value="disabled">Disabled</SelectItem>
                <SelectItem value="unknown">Unknown</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <Button
            variant="secondary"
            onClick={() => loadActors({ reset: true })}
            disabled={loading}
          >
            <RefreshCw className="mr-2 h-4 w-4" />
            Refresh
          </Button>
        </div>
        <Separator className="my-4" />

        {loading ? (
          <div className="py-8 text-sm text-muted-foreground">Loading actors…</div>
        ) : filteredActors.length === 0 ? (
          <div className="py-8 text-sm text-muted-foreground">No actors found.</div>
        ) : (
          <div className="space-y-3">
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Actor</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Risk score</TableHead>
                    <TableHead>Signals</TableHead>
                    <TableHead>Last action</TableHead>
                    <TableHead>Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredActors.map((actor) => (
                    <TableRow key={actor.actorId}>
                      <TableCell>
                        <div className="space-y-1">
                          <div className="font-mono text-xs font-semibold text-foreground">
                            {actor.actorId}
                          </div>
                          <div className="text-xs text-muted-foreground">
                            {actor.ownerPhone ? `${actor.ownerPhone} · ` : ""}
                            {actor.tier ? `${actor.tier} · ` : ""}
                            {actor.userId ? `user ${actor.userId}` : ""}
                          </div>
                        </div>
                      </TableCell>
                      <TableCell>
                        <span className="inline-flex items-center gap-2 text-xs">
                          {actor.status === "clean" && (
                            <>
                              <ShieldCheck className="h-3.5 w-3.5 text-emerald-600" />
                              clean
                            </>
                          )}
                          {actor.status === "warned" && (
                            <>
                              <TriangleAlert className="h-3.5 w-3.5 text-amber-600" />
                              warned
                            </>
                          )}
                          {actor.status === "paused" && (
                            <>
                              <ShieldAlert className="h-3.5 w-3.5 text-amber-600" />
                              paused
                            </>
                          )}
                          {actor.status === "disabled" && (
                            <>
                              <ShieldOff className="h-3.5 w-3.5 text-rose-600" />
                              disabled
                            </>
                          )}
                          {actor.status === "unknown" && "unknown"}
                        </span>
                      </TableCell>
                      <TableCell>
                        <div className="font-mono text-xs">1h: {scoreBadge(actor.riskScore1h)}</div>
                        <div className="font-mono text-xs">
                          24h: {scoreBadge(actor.riskScore24h)}
                        </div>
                        <div className="font-mono text-xs">7d: {scoreBadge(actor.riskScore7d)}</div>
                      </TableCell>
                      <TableCell>
                        <div className="text-xs text-muted-foreground">
                          STOP{" "}
                          {actor.stopRate === null || actor.stopRate === undefined
                            ? "—"
                            : `${actor.stopRate.toFixed(2)}%`}
                        </div>
                        <div className="text-xs text-muted-foreground">
                          Complaints{" "}
                          {actor.complaintRate === null || actor.complaintRate === undefined
                            ? "—"
                            : `${actor.complaintRate.toFixed(2)}%`}
                        </div>
                        <div className="text-xs text-muted-foreground">
                          Undelivered{" "}
                          {actor.undeliveredRate === null || actor.undeliveredRate === undefined
                            ? "—"
                            : `${actor.undeliveredRate.toFixed(2)}%`}
                        </div>
                      </TableCell>
                      <TableCell className="text-xs text-muted-foreground">
                        {formatIso(actor.lastActionAt)}
                      </TableCell>
                      <TableCell>
                        <div className="flex flex-wrap gap-2">
                          <Button
                            size="sm"
                            variant="secondary"
                            onClick={() => void loadEvents(actor.actorId)}
                            disabled={eventsLoading && eventsActorId === actor.actorId}
                          >
                            View events
                          </Button>
                          {actor.status !== "warned" ? (
                            <Button
                              size="sm"
                              variant="secondary"
                              onClick={() => handleAction(actor, "warn_actor")}
                              disabled={Boolean(acting[`${actor.actorId}:warn_actor`])}
                            >
                              {acting[`${actor.actorId}:warn_actor`]
                                ? "..."
                                : actionLabel("warn_actor")}
                            </Button>
                          ) : null}
                          {actor.status !== "paused" ? (
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => handleAction(actor, "pause_actor_egress")}
                              disabled={Boolean(acting[`${actor.actorId}:pause_actor_egress`])}
                            >
                              {acting[`${actor.actorId}:pause_actor_egress`]
                                ? "..."
                                : actionLabel("pause_actor_egress")}
                            </Button>
                          ) : null}
                          {actor.status !== "disabled" ? (
                            <Button
                              size="sm"
                              variant="destructive"
                              onClick={() => handleAction(actor, "disable_actor_numbers")}
                              disabled={Boolean(acting[`${actor.actorId}:disable_actor_numbers`])}
                            >
                              {acting[`${actor.actorId}:disable_actor_numbers`]
                                ? "..."
                                : actionLabel("disable_actor_numbers")}
                            </Button>
                          ) : null}
                          {actor.status === "disabled" ? (
                            <Button
                              size="sm"
                              variant="default"
                              onClick={() => handleAction(actor, "unfreeze_actor")}
                              disabled={Boolean(acting[`${actor.actorId}:unfreeze_actor`])}
                            >
                              {acting[`${actor.actorId}:unfreeze_actor`]
                                ? "..."
                                : actionLabel("unfreeze_actor")}
                            </Button>
                          ) : null}
                          <Button size="sm" variant="outline" onClick={() => copy(actor.actorId)}>
                            <Copy className="h-4 w-4" />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
            <div className="flex justify-end">
              {cursor ? (
                <Button
                  variant="secondary"
                  onClick={() => loadActors({ reset: false })}
                  disabled={loadingMore}
                >
                  {loadingMore ? "Loading…" : "Load more"}
                </Button>
              ) : null}
            </div>
          </div>
        )}
      </section>

      <section className="rounded-2xl border border-border/60 bg-card p-4 md:p-6">
        <h2 className="text-lg font-semibold text-foreground">Actor event log</h2>
        <p className="mt-2 text-sm text-muted-foreground">
          {eventsActorId
            ? `Latest events for ${eventsActorId}`
            : "Select an actor to view risk/correlation events."}
        </p>
        <Separator className="my-4" />

        {eventsLoading ? (
          <div className="py-6 text-sm text-muted-foreground">Loading events…</div>
        ) : events.length === 0 ? (
          <div className="py-6 text-sm text-muted-foreground">No events.</div>
        ) : (
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Time</TableHead>
                  <TableHead>Kind</TableHead>
                  <TableHead>Details</TableHead>
                  <TableHead>Trace</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Error</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {events.map((event) => (
                  <TableRow key={event.eventId}>
                    <TableCell className="font-mono text-xs text-muted-foreground">
                      {formatIso(event.occurredAt)}
                    </TableCell>
                    <TableCell className="font-mono text-xs">{event.kind}</TableCell>
                    <TableCell className="max-w-[320px] text-xs text-muted-foreground">
                      {event.note ||
                        `${event.phone || "—"} · ${event.toNumber || "—"} · ${event.campaignId || "—"}`}
                    </TableCell>
                    <TableCell className="font-mono text-xs">{event.traceId || "—"}</TableCell>
                    <TableCell className="font-mono text-xs">{event.status || "—"}</TableCell>
                    <TableCell className="font-mono text-xs text-muted-foreground">
                      {event.errorCode || "—"}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        )}
      </section>
    </div>
  )
}
