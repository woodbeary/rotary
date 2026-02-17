"use client"

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Separator } from "@/components/ui/separator"
import { BookOpen, Copy, KeyRound, Terminal } from "lucide-react"
import Link from "next/link"
import { useCallback, useEffect, useMemo, useState } from "react"
import { toast } from "sonner"

type ApiKeyRecord = {
  keyId: string
  prefix: string
  label?: string
  createdAt: string
  revokedAt?: string
  lastUsedAt?: string
  byokConfigured?: boolean
  byokProvider?: string
  byokUpdatedAt?: string
  byokFingerprint?: string
}

type ListResponse = { ok: true; apiKeys: ApiKeyRecord[] } | { ok: false; error: string }

type CreateResponse =
  | { ok: true; apiKey: string; record: ApiKeyRecord }
  | { ok: false; error: string }

type RevokeResponse = { ok: true; record: ApiKeyRecord } | { ok: false; error: string }

function formatIso(iso: string | undefined) {
  if (!iso) return "—"
  try {
    return new Date(iso).toLocaleString()
  } catch {
    return iso
  }
}

function maskKey(key: string): string {
  const trimmed = String(key || "").trim()
  if (!trimmed) return ""
  if (trimmed.length <= 16) return `${trimmed.slice(0, 4)}…${trimmed.slice(-2)}`
  return `${trimmed.slice(0, 12)}…${trimmed.slice(-4)}`
}

export function ApiKeysDashboard() {
  const [loading, setLoading] = useState(true)
  const [keys, setKeys] = useState<ApiKeyRecord[]>([])
  const [label, setLabel] = useState("")
  const [creating, setCreating] = useState(false)
  const [revoking, setRevoking] = useState<string | null>(null)
  const [newKey, setNewKey] = useState<string | null>(null)
  const [revealKey, setRevealKey] = useState(false)
  const [byokOpenKeyId, setByokOpenKeyId] = useState<string | null>(null)
  const [byokProvider, setByokProvider] = useState<"openai_compat" | "openai" | "anthropic">(
    "openai_compat",
  )
  const [byokApiKey, setByokApiKey] = useState("")
  const [byokBaseUrl, setByokBaseUrl] = useState("")
  const [byokModel, setByokModel] = useState("")
  const [byokLabel, setByokLabel] = useState("")
  const [byokSaving, setByokSaving] = useState(false)

  const activeCount = useMemo(() => keys.filter((k) => !k.revokedAt).length, [keys])

  const loadKeys = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch("/api/console/api-keys", { method: "GET" })
      const data = (await res.json()) as ListResponse
      if (!data.ok) {
        throw new Error(data.error)
      }
      setKeys(data.apiKeys)
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Failed to load keys.")
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void loadKeys()
  }, [loadKeys])

  async function copy(text: string) {
    try {
      await navigator.clipboard.writeText(text)
      toast.success("Copied.")
    } catch {
      toast.error("Clipboard copy failed on this device.")
    }
  }

  const handleCreate = useCallback(async () => {
    if (creating) return
    setCreating(true)
    setNewKey(null)
    setRevealKey(false)
    try {
      const res = await fetch("/api/console/api-keys", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ label: label.trim() || undefined }),
      })
      const data = (await res.json()) as CreateResponse
      if (!data.ok) {
        throw new Error(data.error)
      }
      setNewKey(data.apiKey)
      setLabel("")
      await loadKeys()
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Failed to create key.")
    } finally {
      setCreating(false)
    }
  }, [creating, label, loadKeys])

  const handleRevoke = useCallback(
    async (keyId: string) => {
      if (revoking) return
      setRevoking(keyId)
      try {
        const res = await fetch("/api/console/api-keys/revoke", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ keyId }),
        })
        const data = (await res.json()) as RevokeResponse
        if (!data.ok) {
          throw new Error(data.error)
        }
        toast.success("Key revoked.")
        await loadKeys()
      } catch (error) {
        toast.error(error instanceof Error ? error.message : "Failed to revoke key.")
      } finally {
        setRevoking(null)
      }
    },
    [loadKeys, revoking],
  )

  const envSnippet = useMemo(() => {
    if (!newKey) return null
    const baseUrl =
      String(process.env.NEXT_PUBLIC_TXTCLAW_API_BASE_URL || "").trim() ||
      "https://txtclaw-sms-e2e.lopez731.workers.dev"
    return `export TXTCLAW_API_BASE_URL="${baseUrl}"\nexport TXTCLAW_API_KEY="${newKey}"`
  }, [newKey])

  const envSnippetDisplay = useMemo(() => {
    if (!envSnippet) return null
    if (revealKey) return envSnippet
    if (!newKey) return envSnippet
    return envSnippet.replaceAll(newKey, maskKey(newKey))
  }, [envSnippet, newKey, revealKey])

  const quickstartUrl = useMemo(() => {
    const origin =
      typeof window !== "undefined" ? window.location.origin : "https://www.txtclaw.com"
    return `${origin}/quickstart.md`
  }, [])

  const doctorCommands = useMemo(() => {
    return `pnpm dlx txtclaw@latest init\npnpm dlx txtclaw@latest doctor`
  }, [])

  const openByokForKey = useCallback((key: ApiKeyRecord) => {
    setByokOpenKeyId((prev) => (prev === key.keyId ? null : key.keyId))
    const provider = String(key.byokProvider || "").trim()
    if (provider === "openai" || provider === "anthropic" || provider === "openai_compat") {
      setByokProvider(provider)
    } else {
      setByokProvider("openai_compat")
    }
    setByokApiKey("")
    setByokBaseUrl("")
    setByokModel("")
    setByokLabel("")
  }, [])

  const handleByokSave = useCallback(async () => {
    if (!byokOpenKeyId) return
    if (byokSaving) return
    setByokSaving(true)
    try {
      const res = await fetch("/api/console/api-keys/byok", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          keyId: byokOpenKeyId,
          provider: byokProvider,
          apiKey: byokApiKey,
          baseUrl: byokBaseUrl || undefined,
          model: byokModel || undefined,
          label: byokLabel || undefined,
        }),
      })
      const data = (await res.json()) as
        | { ok: true; record: ApiKeyRecord }
        | { ok: false; error: string }
      if (!data.ok) {
        throw new Error(data.error)
      }
      toast.success("BYOK saved.")
      setByokApiKey("")
      await loadKeys()
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Failed to save BYOK.")
    } finally {
      setByokSaving(false)
    }
  }, [
    byokApiKey,
    byokBaseUrl,
    byokLabel,
    byokModel,
    byokOpenKeyId,
    byokProvider,
    byokSaving,
    loadKeys,
  ])

  const handleByokClear = useCallback(async () => {
    if (!byokOpenKeyId) return
    if (byokSaving) return
    setByokSaving(true)
    try {
      const res = await fetch("/api/console/api-keys/byok/clear", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ keyId: byokOpenKeyId }),
      })
      const data = (await res.json()) as
        | { ok: true; record: ApiKeyRecord }
        | { ok: false; error: string }
      if (!data.ok) {
        throw new Error(data.error)
      }
      toast.success("BYOK cleared.")
      setByokApiKey("")
      setByokBaseUrl("")
      setByokModel("")
      setByokLabel("")
      await loadKeys()
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Failed to clear BYOK.")
    } finally {
      setByokSaving(false)
    }
  }, [byokOpenKeyId, byokSaving, loadKeys])

  return (
    <div className="space-y-8">
      <header className="space-y-3">
        <div className="inline-flex items-center rounded-full border border-border/70 bg-muted/30 px-3 py-1 font-mono text-[11px] text-muted-foreground">
          Developer Console
        </div>
        <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
          API Keys
        </h1>
        <p className="max-w-2xl text-sm leading-relaxed text-muted-foreground">
          Generate an API key, copy it once, and you’re ready to call{" "}
          <span className="font-mono text-foreground">/v1/*</span>.
        </p>
      </header>

      <section className="grid gap-4 md:grid-cols-3">
        <Card className="rounded-2xl border-border/60">
          <CardHeader className="pb-3">
            <div className="flex items-center justify-between">
              <div className="font-mono text-[11px] text-muted-foreground">Step 1</div>
              <KeyRound className="h-4 w-4 text-muted-foreground" />
            </div>
            <CardTitle className="text-base">Generate a key</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <Input
              value={label}
              onChange={(e) => setLabel(e.target.value)}
              placeholder="Label (optional)"
            />
            <Button onClick={handleCreate} disabled={creating} className="w-full">
              {creating ? "Generating…" : "Generate key"}
            </Button>
            <div className="text-xs text-muted-foreground">
              Active keys: <span className="font-mono text-foreground">{activeCount}</span>
            </div>
          </CardContent>
        </Card>

        <Card className="rounded-2xl border-border/60">
          <CardHeader className="pb-3">
            <div className="flex items-center justify-between">
              <div className="font-mono text-[11px] text-muted-foreground">Step 2</div>
              <Copy className="h-4 w-4 text-muted-foreground" />
            </div>
            <CardTitle className="text-base">Copy env snippet</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {newKey ? (
              <div className="rounded-xl border border-border/60 bg-muted/20 p-3">
                <div className="text-xs font-medium text-foreground">Key (shown once)</div>
                <div className="mt-2 break-all font-mono text-xs text-foreground">
                  {revealKey ? newKey : maskKey(newKey)}
                </div>
                <div className="mt-3 flex flex-wrap gap-2">
                  <Button variant="secondary" size="sm" onClick={() => copy(newKey)}>
                    <Copy className="mr-2 h-4 w-4" />
                    Copy key
                  </Button>
                  <Button variant="outline" size="sm" onClick={() => setRevealKey((prev) => !prev)}>
                    {revealKey ? "Hide" : "Reveal"}
                  </Button>
                </div>
              </div>
            ) : (
              <div className="rounded-xl border border-border/60 bg-muted/10 p-3 text-xs text-muted-foreground">
                Generate a key to reveal it once.
              </div>
            )}

            <div className="rounded-xl border border-border/60 bg-background p-3">
              <div className="text-xs font-medium text-foreground">Environment</div>
              <pre className="mt-2 overflow-x-auto text-xs text-foreground">
                {envSnippetDisplay ||
                  `export TXTCLAW_API_BASE_URL="https://txtclaw-sms-e2e.lopez731.workers.dev"\nexport TXTCLAW_API_KEY="vck_REPLACE_ME"`}
              </pre>
              {envSnippet ? (
                <div className="mt-3">
                  <Button variant="secondary" size="sm" onClick={() => copy(envSnippet)}>
                    <Copy className="mr-2 h-4 w-4" />
                    Copy snippet
                  </Button>
                </div>
              ) : null}
            </div>
          </CardContent>
        </Card>

        <Card className="rounded-2xl border-border/60">
          <CardHeader className="pb-3">
            <div className="flex items-center justify-between">
              <div className="font-mono text-[11px] text-muted-foreground">Step 3</div>
              <Terminal className="h-4 w-4 text-muted-foreground" />
            </div>
            <CardTitle className="text-base">Verify end-to-end</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="rounded-xl border border-border/60 bg-background p-3">
              <pre className="overflow-x-auto text-xs text-foreground">{doctorCommands}</pre>
              <div className="mt-3 flex flex-wrap gap-2">
                <Button variant="secondary" size="sm" onClick={() => copy(doctorCommands)}>
                  <Copy className="mr-2 h-4 w-4" />
                  Copy commands
                </Button>
                <Button variant="secondary" size="sm" onClick={() => copy(quickstartUrl)}>
                  <BookOpen className="mr-2 h-4 w-4" />
                  Copy docs URL
                </Button>
              </div>
            </div>
            <div className="text-xs text-muted-foreground">
              Paste{" "}
              <a className="font-mono underline underline-offset-4" href="/quickstart.md">
                /quickstart.md
              </a>{" "}
              into Cursor/Codex.
            </div>
          </CardContent>
        </Card>
      </section>

      <section className="rounded-2xl border border-border/60 bg-card p-6 md:p-8">
        <div className="flex items-center justify-between gap-4">
          <h2 className="text-lg font-semibold text-foreground">Your keys</h2>
          <Button variant="secondary" onClick={loadKeys} disabled={loading}>
            {loading ? "Refreshing…" : "Refresh"}
          </Button>
        </div>
        <div className="mt-5 overflow-hidden rounded-xl border border-border/60">
          <div className="grid grid-cols-12 gap-3 bg-muted/30 px-4 py-3 text-[11px] font-medium uppercase tracking-wide text-muted-foreground">
            <div className="col-span-4">Key</div>
            <div className="col-span-3">Created</div>
            <div className="col-span-3">Last used</div>
            <div className="col-span-2 text-right">Action</div>
          </div>
          {keys.length === 0 ? (
            <div className="px-4 py-6 text-sm text-muted-foreground">
              No keys yet. Generate one above.
            </div>
          ) : (
            <div className="divide-y divide-border/60">
              {keys.map((k) => (
                <div key={k.keyId}>
                  <div className="grid grid-cols-12 gap-3 px-4 py-3 text-sm">
                    <div className="col-span-12 md:col-span-4">
                      <div className="font-mono text-xs text-foreground">
                        {k.prefix}
                        <span className="text-muted-foreground">…</span>
                      </div>
                      {k.label ? (
                        <div className="mt-1 text-xs text-muted-foreground">{k.label}</div>
                      ) : null}
                      {k.byokConfigured ? (
                        <div className="mt-1 text-xs text-muted-foreground">
                          BYOK:{" "}
                          <span className="font-mono text-foreground">
                            {k.byokProvider || "configured"}
                          </span>
                          {k.byokFingerprint ? (
                            <>
                              {" · "}
                              <span className="font-mono">{k.byokFingerprint}</span>
                            </>
                          ) : null}
                        </div>
                      ) : (
                        <div className="mt-1 text-xs text-muted-foreground">
                          BYOK: not configured
                        </div>
                      )}
                      {k.revokedAt ? (
                        <div className="mt-1 text-xs text-muted-foreground">
                          Revoked: {formatIso(k.revokedAt)}
                        </div>
                      ) : null}
                    </div>
                    <div className="col-span-6 md:col-span-3 text-xs text-muted-foreground">
                      {formatIso(k.createdAt)}
                    </div>
                    <div className="col-span-6 md:col-span-3 text-xs text-muted-foreground">
                      {formatIso(k.lastUsedAt)}
                    </div>
                    <div className="col-span-12 md:col-span-2 flex flex-wrap justify-end gap-2">
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={() => openByokForKey(k)}
                        disabled={Boolean(k.revokedAt)}
                      >
                        {byokOpenKeyId === k.keyId ? "Close BYOK" : "BYOK"}
                      </Button>
                      <Button
                        variant="destructive"
                        size="sm"
                        onClick={() => handleRevoke(k.keyId)}
                        disabled={Boolean(k.revokedAt) || revoking === k.keyId}
                      >
                        {revoking === k.keyId ? "Revoking…" : "Revoke"}
                      </Button>
                    </div>
                  </div>

                  {byokOpenKeyId === k.keyId ? (
                    <div className="border-t border-border/60 bg-muted/10 px-4 py-4">
                      <div className="grid gap-3 md:grid-cols-2">
                        <div className="space-y-1.5">
                          <p className="text-xs font-medium text-foreground">Provider</p>
                          <Select
                            value={byokProvider}
                            onValueChange={(v) =>
                              setByokProvider(
                                v === "openai" || v === "anthropic" ? v : "openai_compat",
                              )
                            }
                          >
                            <SelectTrigger>
                              <SelectValue placeholder="Select provider" />
                            </SelectTrigger>
                            <SelectContent>
                              <SelectItem value="openai_compat">
                                openai_compat (recommended)
                              </SelectItem>
                              <SelectItem value="openai">openai</SelectItem>
                              <SelectItem value="anthropic">anthropic</SelectItem>
                            </SelectContent>
                          </Select>
                        </div>

                        <div className="space-y-1.5">
                          <p className="text-xs font-medium text-foreground">Provider API key</p>
                          <Input
                            value={byokApiKey}
                            onChange={(e) => setByokApiKey(e.target.value)}
                            placeholder="sk-…"
                            type="password"
                            autoComplete="off"
                          />
                        </div>

                        <div className="space-y-1.5">
                          <p className="text-xs font-medium text-foreground">Base URL (optional)</p>
                          <Input
                            value={byokBaseUrl}
                            onChange={(e) => setByokBaseUrl(e.target.value)}
                            placeholder="https://gateway.ai.cloudflare.com/v1/.../compat"
                            autoComplete="off"
                          />
                        </div>

                        <div className="space-y-1.5">
                          <p className="text-xs font-medium text-foreground">Model (optional)</p>
                          <Input
                            value={byokModel}
                            onChange={(e) => setByokModel(e.target.value)}
                            placeholder="openai/amazon/nova-lite"
                            autoComplete="off"
                          />
                        </div>

                        <div className="space-y-1.5 md:col-span-2">
                          <p className="text-xs font-medium text-foreground">Label (optional)</p>
                          <Input
                            value={byokLabel}
                            onChange={(e) => setByokLabel(e.target.value)}
                            placeholder="e.g. work key"
                            autoComplete="off"
                          />
                        </div>
                      </div>

                      <div className="mt-4 flex flex-wrap gap-2">
                        <Button
                          onClick={handleByokSave}
                          disabled={byokSaving || !byokApiKey.trim()}
                        >
                          {byokSaving ? "Saving…" : "Save BYOK"}
                        </Button>
                        <Button
                          variant="secondary"
                          onClick={handleByokClear}
                          disabled={byokSaving || !k.byokConfigured}
                        >
                          Clear BYOK
                        </Button>
                      </div>

                      <p className="mt-3 text-xs text-muted-foreground">
                        BYOK keys are stored encrypted and are never shown again after saving.
                      </p>
                    </div>
                  ) : null}
                </div>
              ))}
            </div>
          )}
        </div>

        <p className="mt-4 text-xs text-muted-foreground">
          Docs:{" "}
          <Link
            href="/api-reference"
            className="font-mono text-foreground underline underline-offset-4"
          >
            /api-reference
          </Link>
          {" · "}
          <a className="font-mono text-foreground underline underline-offset-4" href="/agents.md">
            /agents.md
          </a>
          {" · "}
          <a
            className="font-mono text-foreground underline underline-offset-4"
            href="/openapi.yaml"
          >
            /openapi.yaml
          </a>
        </p>
      </section>
    </div>
  )
}
