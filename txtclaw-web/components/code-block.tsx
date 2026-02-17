"use client"

import { CopyButton } from "@/components/copy-button"
import { cn } from "@/lib/utils"
import { toast } from "sonner"

export function CodeBlock({
  code,
  language,
  title,
  className,
  copyLabel = "Copy",
  wrap = false,
}: {
  code: string
  language?: string
  title?: string
  className?: string
  copyLabel?: string
  wrap?: boolean
}) {
  return (
    <div
      className={cn("min-w-0 w-full rounded-xl border border-border/60 bg-background", className)}
    >
      <div className="flex items-center justify-between gap-3 border-b border-border/60 px-3 py-2">
        <div className="min-w-0">
          {title ? (
            <div className="truncate text-xs font-medium text-foreground">{title}</div>
          ) : null}
          {language ? <div className="text-[11px] text-muted-foreground">{language}</div> : null}
        </div>
        <CopyButton
          text={code}
          label={copyLabel}
          variant="ghost"
          size="sm"
          className="h-8 px-2"
          onCopied={() => toast.success("Copied.")}
        />
      </div>
      <pre
        className={cn(
          "max-w-full overflow-x-auto p-3 text-xs text-foreground",
          wrap ? "whitespace-pre-wrap break-all" : "whitespace-pre",
        )}
      >
        {code}
      </pre>
    </div>
  )
}
