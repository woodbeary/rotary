"use client"

import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
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
import { Copy, Eye, RefreshCw, Search } from "lucide-react"
import { useCallback, useEffect, useMemo, useState } from "react"
import { toast } from "sonner"

type TraceGrade = "good" | "bad" | "needs_prompt" | "bug" | "unknown"

type TraceRecord = {
  traceId: string
  startedAt: string
  endedAt?: string
  method: string
  pathname: string
  status: number
  elapsedMs: number
  ray?: string
  ipHash?: string | null
  apiKeyId?: string
  apiKeyUserId?: string
  apiKeyAuthKind?: string
  agentId?: string
  llmMode?: string
  llmTier?: string
  modelUsed?: string
  promptVersionId?: string
  error?: string
  grade?: TraceGrade
  gradeNote?: string
  gradedAt?: string
}

function formatIso(iso: string | undefined) {
  if (!iso) return "—"
  try {
    return new Date(iso).toLocaleString()
  } catch {
    return iso
  }
}

async function copy(text: string) {
  try {
    await navigator.clipboard.writeText(text)
    toast.success("Copied.")
  } catch {
    toast.error("Clipboard copy failed on this device.")
  }
}

function normalizeGrade(value: unknown): TraceGrade {
  const raw = String(value || "")
    .trim()
    .toLowerCase()
  if (raw === "good" || raw === "bad" || raw === "needs_prompt" || raw === "bug") return raw
  return "unknown"
}

export function AdminTraces() {
  const [loading, setLoading] = useState(true)
  const [loadingMore, setLoadingMore] = useState(false)
  const [cursor, setCursor] = useState<string | null>(null)
  const [traces, setTraces] = useState<TraceRecord[]>([])
  const [q, setQ] = useState("")
  const [gradeFilter, setGradeFilter] = useState<TraceGrade | "all">("all")
  const [grading, setGrading] = useState<Record<string, boolean>>({})

  const load = useCallback(
    async ({ reset }: { reset: boolean }) => {
      const limit = 50
      const url = new URL("/api/console/traces", window.location.origin)
      url.searchParams.set("limit", String(limit))
      if (!reset && cursor) url.searchParams.set("cursor", cursor)

      try {
        if (reset) setLoading(true)
        else setLoadingMore(true)

        const res = await fetch(url.toString(), { method: "GET", cache: "no-store" })
        const data = (await res.json()) as
          | { ok: true; traces: TraceRecord[]; cursor: string | null }
          | { ok: false; error: string }
        if (!data.ok) throw new Error(data.error)

        setCursor(data.cursor ?? null)
        setTraces((prev) => (reset ? data.traces : [...prev, ...data.traces]))
      } catch (error) {
        toast.error(error instanceof Error ? error.message : "Failed to load traces.")
      } finally {
        setLoading(false)
        setLoadingMore(false)
      }
    },
    [cursor],
  )

  useEffect(() => {
    void load({ reset: true })
  }, [load])

  const filtered = useMemo(() => {
    const query = q.trim().toLowerCase()
    return traces.filter((t) => {
      if (gradeFilter !== "all" && normalizeGrade(t.grade) !== gradeFilter) return false
      if (!query) return true
      return (
        t.traceId.toLowerCase().includes(query) ||
        t.pathname.toLowerCase().includes(query) ||
        (t.apiKeyId || "").toLowerCase().includes(query) ||
        (t.apiKeyUserId || "").toLowerCase().includes(query)
      )
    })
  }, [gradeFilter, q, traces])

  const handleGrade = useCallback(async (traceId: string, grade: TraceGrade) => {
    setGrading((prev) => ({ ...prev, [traceId]: true }))
    try {
      const res = await fetch("/api/console/traces/grade", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ traceId, grade }),
      })
      const data = (await res.json()) as
        | { ok: true; trace: TraceRecord }
        | { ok: false; error: string }
      if (!data.ok) throw new Error(data.error)
      setTraces((prev) => prev.map((t) => (t.traceId === traceId ? data.trace : t)))
      toast.success("Saved.")
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Failed to grade trace.")
    } finally {
      setGrading((prev) => ({ ...prev, [traceId]: false }))
    }
  }, [])

  return (
    <div className="space-y-8">
      <header className="space-y-3">
        <div className="inline-flex items-center rounded-full border border-border/70 bg-muted/30 px-3 py-1 font-mono text-[11px] text-muted-foreground">
          Observability
        </div>
        <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
          Traces
        </h1>
        <p className="max-w-2xl text-sm leading-relaxed text-muted-foreground">
          Every request gets a <span className="font-mono text-foreground">trace_id</span>. Use this
          page to spot failures early and grade behavior in bulk.
        </p>
      </header>

      <section className="rounded-2xl border border-border/60 bg-card p-4 md:p-6">
        <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <div className="flex flex-1 items-center gap-2">
            <div className="relative flex-1">
              <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
              <Input
                value={q}
                onChange={(e) => setQ(e.target.value)}
                placeholder="Search trace id, path, key id, user id…"
                className="pl-9"
              />
            </div>
            <Select value={gradeFilter} onValueChange={(v) => setGradeFilter(v as any)}>
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder="Grade" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All grades</SelectItem>
                <SelectItem value="unknown">Unreviewed</SelectItem>
                <SelectItem value="good">Good</SelectItem>
                <SelectItem value="bad">Bad</SelectItem>
                <SelectItem value="needs_prompt">Needs prompt</SelectItem>
                <SelectItem value="bug">Bug</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="flex items-center gap-2">
            <Button
              variant="secondary"
              onClick={() => load({ reset: true })}
              disabled={loading || loadingMore}
            >
              <RefreshCw className="mr-2 h-4 w-4" />
              Refresh
            </Button>
          </div>
        </div>

        <Separator className="my-4" />

        {loading ? (
          <div className="py-8 text-sm text-muted-foreground">Loading…</div>
        ) : filtered.length === 0 ? (
          <div className="py-8 text-sm text-muted-foreground">No traces found.</div>
        ) : (
          <>
            {/* Mobile cards */}
            <div className="space-y-3 md:hidden">
              {filtered.map((t) => (
                <div
                  key={t.traceId}
                  className="rounded-xl border border-border/60 bg-background p-4"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="truncate font-mono text-xs text-foreground">{t.traceId}</div>
                      <div className="mt-1 text-sm text-foreground">
                        <span className="font-mono text-xs text-muted-foreground">{t.method}</span>{" "}
                        <span className="break-all">{t.pathname}</span>
                      </div>
                      <div className="mt-2 text-xs text-muted-foreground">
                        {t.status} · {t.elapsedMs}ms · {formatIso(t.startedAt)}
                      </div>
                    </div>
                    <Button
                      size="icon"
                      variant="ghost"
                      onClick={() => copy(t.traceId)}
                      aria-label="Copy trace id"
                    >
                      <Copy className="h-4 w-4" />
                    </Button>
                  </div>

                  <div className="mt-3 flex items-center gap-2">
                    <Select
                      value={normalizeGrade(t.grade)}
                      onValueChange={(v) => void handleGrade(t.traceId, v as TraceGrade)}
                      disabled={Boolean(grading[t.traceId])}
                    >
                      <SelectTrigger className="h-9 flex-1">
                        <SelectValue placeholder="Grade" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="unknown">Unreviewed</SelectItem>
                        <SelectItem value="good">Good</SelectItem>
                        <SelectItem value="bad">Bad</SelectItem>
                        <SelectItem value="needs_prompt">Needs prompt</SelectItem>
                        <SelectItem value="bug">Bug</SelectItem>
                      </SelectContent>
                    </Select>

                    <Dialog>
                      <DialogTrigger asChild>
                        <Button size="icon" variant="secondary" aria-label="View trace JSON">
                          <Eye className="h-4 w-4" />
                        </Button>
                      </DialogTrigger>
                      <DialogContent className="max-w-2xl">
                        <DialogHeader>
                          <DialogTitle className="font-mono text-sm">Trace {t.traceId}</DialogTitle>
                        </DialogHeader>
                        <pre className="max-h-[60vh] overflow-auto rounded-md border border-border/60 bg-muted/20 p-3 text-xs">
                          {JSON.stringify(t, null, 2)}
                        </pre>
                      </DialogContent>
                    </Dialog>
                  </div>
                </div>
              ))}
            </div>

            {/* Desktop table */}
            <div className="hidden overflow-hidden rounded-xl border border-border/60 md:block">
              <Table>
                <TableHeader>
                  <TableRow className="bg-muted/30">
                    <TableHead>Trace</TableHead>
                    <TableHead>Path</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>LLM</TableHead>
                    <TableHead>Prompt</TableHead>
                    <TableHead>Grade</TableHead>
                    <TableHead className="text-right">Action</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filtered.map((t) => (
                    <TableRow key={t.traceId}>
                      <TableCell className="align-top">
                        <div className="flex items-start gap-2">
                          <div className="min-w-0">
                            <div className="truncate font-mono text-xs text-foreground">
                              {t.traceId}
                            </div>
                            <div className="mt-1 text-xs text-muted-foreground">
                              {formatIso(t.startedAt)}
                            </div>
                          </div>
                          <Button
                            size="icon"
                            variant="ghost"
                            onClick={() => copy(t.traceId)}
                            aria-label="Copy trace id"
                          >
                            <Copy className="h-4 w-4" />
                          </Button>
                        </div>
                      </TableCell>
                      <TableCell className="align-top">
                        <div className="text-xs text-muted-foreground">
                          <span className="font-mono">{t.method}</span>
                        </div>
                        <div className="mt-1 break-all text-sm text-foreground">{t.pathname}</div>
                        {t.apiKeyId || t.apiKeyUserId ? (
                          <div className="mt-2 text-[11px] text-muted-foreground">
                            <span className="font-mono">{t.apiKeyId || "—"}</span>
                            {" · "}
                            <span className="font-mono">{t.apiKeyUserId || "—"}</span>
                          </div>
                        ) : null}
                      </TableCell>
                      <TableCell className="align-top">
                        <div className="font-mono text-sm text-foreground">{t.status}</div>
                        <div className="mt-1 text-xs text-muted-foreground">{t.elapsedMs}ms</div>
                        {t.error ? (
                          <div className="mt-2 max-w-[220px] truncate text-xs text-destructive">
                            {t.error}
                          </div>
                        ) : null}
                      </TableCell>
                      <TableCell className="align-top">
                        <div className="text-xs text-muted-foreground">
                          {t.llmMode || "—"} {t.llmTier ? `(${t.llmTier})` : ""}
                        </div>
                        <div className="mt-1 max-w-[220px] truncate font-mono text-xs text-foreground">
                          {t.modelUsed || "—"}
                        </div>
                      </TableCell>
                      <TableCell className="align-top">
                        <div className="max-w-[220px] truncate font-mono text-xs text-foreground">
                          {t.promptVersionId || "—"}
                        </div>
                      </TableCell>
                      <TableCell className="align-top">
                        <Select
                          value={normalizeGrade(t.grade)}
                          onValueChange={(v) => void handleGrade(t.traceId, v as TraceGrade)}
                          disabled={Boolean(grading[t.traceId])}
                        >
                          <SelectTrigger className="h-9 w-[180px]">
                            <SelectValue placeholder="Grade" />
                          </SelectTrigger>
                          <SelectContent>
                            <SelectItem value="unknown">Unreviewed</SelectItem>
                            <SelectItem value="good">Good</SelectItem>
                            <SelectItem value="bad">Bad</SelectItem>
                            <SelectItem value="needs_prompt">Needs prompt</SelectItem>
                            <SelectItem value="bug">Bug</SelectItem>
                          </SelectContent>
                        </Select>
                      </TableCell>
                      <TableCell className="align-top text-right">
                        <Dialog>
                          <DialogTrigger asChild>
                            <Button variant="secondary" size="sm">
                              <Eye className="mr-2 h-4 w-4" />
                              View
                            </Button>
                          </DialogTrigger>
                          <DialogContent className="max-w-3xl">
                            <DialogHeader>
                              <DialogTitle className="font-mono text-sm">
                                Trace {t.traceId}
                              </DialogTitle>
                            </DialogHeader>
                            <pre className="max-h-[70vh] overflow-auto rounded-md border border-border/60 bg-muted/20 p-3 text-xs">
                              {JSON.stringify(t, null, 2)}
                            </pre>
                          </DialogContent>
                        </Dialog>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          </>
        )}

        <div className="mt-5 flex items-center justify-between">
          <div className="text-xs text-muted-foreground">
            Showing <span className="font-mono text-foreground">{filtered.length}</span> traces
          </div>
          <Button
            variant="secondary"
            onClick={() => load({ reset: false })}
            disabled={!cursor || loadingMore || loading}
          >
            {loadingMore ? "Loading…" : cursor ? "Load older" : "No more"}
          </Button>
        </div>
      </section>
    </div>
  )
}
