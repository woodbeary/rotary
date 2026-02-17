"use client"

import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Separator } from "@/components/ui/separator"
import { Textarea } from "@/components/ui/textarea"
import { Copy, RefreshCw, Sparkles } from "lucide-react"
import { useCallback, useEffect, useMemo, useState } from "react"
import { toast } from "sonner"

type PromptVersion = {
  id: string
  label?: string
  content: string
  createdAt: string
  createdBy?: string
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

export function AdminPrompts() {
  const [loading, setLoading] = useState(true)
  const [prompts, setPrompts] = useState<PromptVersion[]>([])
  const [activeId, setActiveId] = useState<string | null>(null)
  const [label, setLabel] = useState("")
  const [content, setContent] = useState("")
  const [saving, setSaving] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch("/api/console/prompts", { method: "GET", cache: "no-store" })
      const data = (await res.json()) as
        | { ok: true; promptVersions: PromptVersion[]; activePromptId: string | null }
        | { ok: false; error: string }
      if (!data.ok) throw new Error(data.error)
      setPrompts(data.promptVersions)
      setActiveId(data.activePromptId)
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Failed to load prompts.")
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  const activePrompt = useMemo(
    () => prompts.find((p) => p.id === activeId) || null,
    [activeId, prompts],
  )

  const handleCreate = useCallback(async () => {
    if (saving) return
    const trimmed = content.trim()
    if (!trimmed) {
      toast.error("Prompt content is required.")
      return
    }

    setSaving(true)
    try {
      const res = await fetch("/api/console/prompts", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          label: label.trim() || undefined,
          content: trimmed,
          activate: true,
        }),
      })
      const data = (await res.json()) as
        | { ok: true; promptVersion: PromptVersion; activePromptId: string | null }
        | { ok: false; error: string }
      if (!data.ok) throw new Error(data.error)
      toast.success("Created + activated.")
      setLabel("")
      setContent("")
      await load()
      if (data.activePromptId) setActiveId(data.activePromptId)
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Failed to create prompt.")
    } finally {
      setSaving(false)
    }
  }, [content, label, load, saving])

  const handleActivate = useCallback(
    async (id: string) => {
      if (saving) return
      setSaving(true)
      try {
        const res = await fetch("/api/console/prompts/activate", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ id }),
        })
        const data = (await res.json()) as
          | { ok: true; promptVersion: PromptVersion; activePromptId: string | null }
          | { ok: false; error: string }
        if (!data.ok) throw new Error(data.error)
        toast.success("Activated.")
        setActiveId(data.activePromptId)
        await load()
      } catch (error) {
        toast.error(error instanceof Error ? error.message : "Failed to activate prompt.")
      } finally {
        setSaving(false)
      }
    },
    [load, saving],
  )

  return (
    <div className="space-y-8">
      <header className="space-y-3">
        <div className="inline-flex items-center rounded-full border border-border/70 bg-muted/30 px-3 py-1 font-mono text-[11px] text-muted-foreground">
          Prompt versions
        </div>
        <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
          Prompts
        </h1>
        <p className="max-w-2xl text-sm leading-relaxed text-muted-foreground">
          Create a new prompt version, activate it, then re-run the E2E script to verify behavior.
          New agents use the active prompt by default.
        </p>
      </header>

      <section className="rounded-2xl border border-border/60 bg-card p-4 md:p-6">
        <div className="flex items-center justify-between gap-3">
          <div>
            <div className="text-sm font-medium text-foreground">Active prompt</div>
            <div className="mt-1 font-mono text-xs text-muted-foreground">{activeId || "—"}</div>
          </div>
          <div className="flex items-center gap-2">
            {activePrompt ? (
              <Button variant="secondary" onClick={() => void copy(activePrompt.content)}>
                <Copy className="mr-2 h-4 w-4" />
                Copy active
              </Button>
            ) : null}
            <Button variant="secondary" onClick={() => void load()} disabled={loading}>
              <RefreshCw className="mr-2 h-4 w-4" />
              Refresh
            </Button>
          </div>
        </div>

        {activePrompt ? (
          <div className="mt-4 rounded-xl border border-border/60 bg-muted/20 p-4">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div className="min-w-0">
                <div className="truncate text-sm font-medium text-foreground">
                  {activePrompt.label || "Untitled"}
                </div>
                <div className="mt-1 text-xs text-muted-foreground">
                  {formatIso(activePrompt.createdAt)}
                  {activePrompt.createdBy ? ` · ${activePrompt.createdBy}` : ""}
                </div>
              </div>
              <Button variant="secondary" size="sm" onClick={() => void copy(activePrompt.id)}>
                <Copy className="mr-2 h-4 w-4" />
                Copy id
              </Button>
            </div>
            <pre className="mt-3 max-h-64 overflow-auto whitespace-pre-wrap rounded-md border border-border/60 bg-background p-3 font-mono text-xs text-foreground">
              {activePrompt.content}
            </pre>
          </div>
        ) : null}
      </section>

      <section className="rounded-2xl border border-border/60 bg-card p-4 md:p-6">
        <div className="flex items-center gap-2">
          <Sparkles className="h-4 w-4 text-muted-foreground" />
          <h2 className="text-lg font-semibold text-foreground">Create + activate</h2>
        </div>
        <p className="mt-2 text-sm text-muted-foreground">
          This is an admin action. It changes defaults for newly created agents.
        </p>

        <div className="mt-4 grid gap-3">
          <Input
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            placeholder="Label (optional)"
          />
          <Textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            placeholder="Prompt content…"
            className="min-h-40"
          />
          <div className="flex items-center justify-between gap-3">
            <div className="text-xs text-muted-foreground">
              {content.trim().length} chars · max 8000
            </div>
            <Button onClick={() => void handleCreate()} disabled={saving}>
              {saving ? "Saving…" : "Create + activate"}
            </Button>
          </div>
        </div>
      </section>

      <section className="rounded-2xl border border-border/60 bg-card p-4 md:p-6">
        <div className="flex items-center justify-between gap-3">
          <h2 className="text-lg font-semibold text-foreground">All versions</h2>
          <div className="text-xs text-muted-foreground">
            {loading ? "Loading…" : `${prompts.length} total`}
          </div>
        </div>

        <Separator className="my-4" />

        {loading ? (
          <div className="py-6 text-sm text-muted-foreground">Loading…</div>
        ) : prompts.length === 0 ? (
          <div className="py-6 text-sm text-muted-foreground">No prompts yet.</div>
        ) : (
          <div className="grid gap-3 md:grid-cols-2">
            {prompts.map((p) => {
              const isActive = p.id === activeId
              return (
                <div key={p.id} className="rounded-xl border border-border/60 bg-background p-4">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="truncate text-sm font-medium text-foreground">
                        {p.label || "Untitled"}
                        {isActive ? (
                          <span className="ml-2 rounded-full border border-border/70 bg-muted/30 px-2 py-0.5 font-mono text-[10px] text-muted-foreground">
                            active
                          </span>
                        ) : null}
                      </div>
                      <div className="mt-1 font-mono text-xs text-muted-foreground">{p.id}</div>
                      <div className="mt-1 text-xs text-muted-foreground">
                        {formatIso(p.createdAt)}
                        {p.createdBy ? ` · ${p.createdBy}` : ""}
                      </div>
                    </div>
                    <div className="flex flex-col gap-2">
                      <Button variant="secondary" size="sm" onClick={() => void copy(p.content)}>
                        <Copy className="mr-2 h-4 w-4" />
                        Copy
                      </Button>
                      <Button
                        size="sm"
                        onClick={() => void handleActivate(p.id)}
                        disabled={saving || isActive}
                      >
                        {isActive ? "Active" : "Activate"}
                      </Button>
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </section>
    </div>
  )
}
