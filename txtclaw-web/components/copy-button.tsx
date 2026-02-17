"use client"

import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"
import { Check, Copy } from "lucide-react"
import { useCallback, useState } from "react"

export function CopyButton({
  text,
  label = "Copy",
  variant = "secondary",
  size = "sm",
  className,
  onCopied,
}: {
  text: string
  label?: string
  variant?: "default" | "secondary" | "outline" | "ghost" | "destructive" | "link"
  size?: "default" | "sm" | "lg" | "icon"
  className?: string
  onCopied?: () => void
}) {
  const [copied, setCopied] = useState(false)

  const copy = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(text)
      setCopied(true)
      onCopied?.()
      window.setTimeout(() => setCopied(false), 1200)
    } catch {
      // Let callers toast if they want; here we just no-op.
    }
  }, [onCopied, text])

  return (
    <Button
      type="button"
      variant={variant}
      size={size}
      onClick={() => void copy()}
      className={cn("gap-2", className)}
      aria-label={label}
    >
      {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
      <span>{copied ? "Copied" : label}</span>
    </Button>
  )
}
