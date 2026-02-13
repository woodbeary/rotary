"use client"

import type { CSSProperties } from "react"
import { cn } from "@/lib/utils"

type StreamTextProps = {
  text: string
  className?: string
  active?: boolean
}

export function StreamText({ text, className, active = true }: StreamTextProps) {
  const words = text.split(" ")

  return (
    <p className={cn(className, active && "stream-active")}>
      <span className="sr-only">{text}</span>
      <span aria-hidden>
        {words.map((word, index) => (
          <span
            key={`${word}-${index}`}
            className="stream-word"
            style={{ ["--stream-index" as "--stream-index"]: index } as CSSProperties}
          >
            {word}
            {index < words.length - 1 ? "\u00A0" : ""}
          </span>
        ))}
      </span>
    </p>
  )
}
