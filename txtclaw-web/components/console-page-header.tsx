import { cn } from "@/lib/utils"
import type { ReactNode } from "react"

export function ConsolePageHeader({
  badge,
  title,
  subtitle,
  right,
  className,
}: {
  badge?: ReactNode
  title: string
  subtitle?: ReactNode
  right?: ReactNode
  className?: string
}) {
  return (
    <header
      className={cn("flex flex-col gap-4 md:flex-row md:items-end md:justify-between", className)}
    >
      <div className="space-y-3">
        {badge ? <div>{badge}</div> : null}
        <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
          {title}
        </h1>
        {subtitle ? (
          <div className="max-w-2xl text-sm leading-relaxed text-muted-foreground">{subtitle}</div>
        ) : null}
      </div>
      {right ? <div className="shrink-0">{right}</div> : null}
    </header>
  )
}
