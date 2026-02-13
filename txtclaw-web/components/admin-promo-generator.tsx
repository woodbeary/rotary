"use client"

import { type FormEvent, useMemo, useState } from "react"
import { Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"

type AdminPromoGeneratorProps = {
  campaignId: string
  grantCents: number
}

type PromoGenerateResponse = {
  ok?: boolean
  count?: number
  codes?: string[]
  error?: string
}

function toUsd(cents: number) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(cents / 100)
}

export function AdminPromoGenerator({
  campaignId,
  grantCents,
}: AdminPromoGeneratorProps) {
  const [generateCountInput, setGenerateCountInput] = useState("10")
  const [generatingCodes, setGeneratingCodes] = useState(false)
  const [generatedCodes, setGeneratedCodes] = useState<string[]>([])
  const [generateError, setGenerateError] = useState<string | null>(null)
  const [generateNotice, setGenerateNotice] = useState<string | null>(null)
  const [copyNotice, setCopyNotice] = useState<string | null>(null)

  const grantLabel = useMemo(() => toUsd(grantCents), [grantCents])

  const generatePromoCodes = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (generatingCodes) return

    const parsed = Number(generateCountInput)
    const count = Number.isFinite(parsed) ? Math.max(1, Math.min(200, Math.floor(parsed))) : 10

    setGeneratingCodes(true)
    setGenerateError(null)
    setGenerateNotice(null)
    setCopyNotice(null)

    try {
      const response = await fetch("/api/promo/generate", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ count }),
      })

      const payload = (await response.json().catch(() => null)) as
        | PromoGenerateResponse
        | null

      if (!response.ok || !payload?.ok || !Array.isArray(payload.codes)) {
        throw new Error(payload?.error || "Unable to generate codes.")
      }

      setGeneratedCodes(payload.codes)
      setGenerateCountInput(String(payload.count ?? payload.codes.length))
      setGenerateNotice(`Generated ${payload.codes.length} code(s).`)
    } catch (error) {
      setGeneratedCodes([])
      setGenerateError(
        error instanceof Error ? error.message : "Unable to generate codes."
      )
    } finally {
      setGeneratingCodes(false)
    }
  }

  const copyGeneratedCodes = async () => {
    if (generatedCodes.length === 0) return
    setCopyNotice(null)

    try {
      await navigator.clipboard.writeText(generatedCodes.join("\n"))
      setCopyNotice("Copied codes to clipboard.")
    } catch {
      setCopyNotice(
        "Clipboard copy failed on this device. You can still copy from the list below."
      )
    }
  }

  return (
    <Card className="border-foreground/15">
      <CardHeader>
        <CardTitle className="text-xl">Promo code generator (admin)</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <p className="text-xs text-muted-foreground">
          Campaign: <span className="text-foreground">{campaignId}</span>
          {" · "}
          Per-code credit: <span className="text-foreground">{grantLabel}</span>
        </p>

        <form className="flex flex-col gap-3 sm:flex-row sm:items-center" onSubmit={generatePromoCodes}>
          <Input
            type="number"
            min={1}
            max={200}
            value={generateCountInput}
            onChange={(event) => setGenerateCountInput(event.target.value)}
            className="sm:w-40"
          />
          <Button type="submit" variant="outline" disabled={generatingCodes}>
            {generatingCodes ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Generating...
              </>
            ) : (
              "Generate codes"
            )}
          </Button>
        </form>

        {generatedCodes.length > 0 ? (
          <div className="space-y-3">
            <Button
              type="button"
              variant="secondary"
              className="w-full sm:w-auto"
              onClick={copyGeneratedCodes}
            >
              Copy all codes
            </Button>
            <div className="max-h-64 overflow-auto rounded-md border border-border/60 bg-muted/20 p-3">
              <pre className="whitespace-pre-wrap break-all font-mono text-xs text-foreground">
                {generatedCodes.join("\n")}
              </pre>
            </div>
          </div>
        ) : null}

        {generateNotice ? (
          <p className="text-sm text-emerald-300">{generateNotice}</p>
        ) : null}
        {copyNotice ? <p className="text-sm text-emerald-300">{copyNotice}</p> : null}
        {generateError ? <p className="text-sm text-red-400">{generateError}</p> : null}
      </CardContent>
    </Card>
  )
}
