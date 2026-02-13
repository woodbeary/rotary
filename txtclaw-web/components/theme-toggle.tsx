"use client"

import { useTheme } from "next-themes"
import { useEffect, useMemo, useState } from "react"
import { Monitor, Moon, Sun } from "lucide-react"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"

type ThemeOption = "light" | "dark" | "system"

const isThemeOption = (value: string): value is ThemeOption =>
  value === "light" || value === "dark" || value === "system"

export function ThemeToggle() {
  const { theme, forcedTheme, resolvedTheme, setTheme } = useTheme()
  const [mounted, setMounted] = useState(false)

  useEffect(() => setMounted(true), [])

  const selectedTheme = useMemo<ThemeOption>(() => {
    const candidate = forcedTheme ?? theme
    return isThemeOption(candidate ?? "") ? candidate : "system"
  }, [forcedTheme, theme])

  const effectiveTheme = resolvedTheme === "dark" ? "dark" : "light"

  const icon =
    selectedTheme === "system" ? (
      <Monitor className="h-4 w-4" />
    ) : selectedTheme === "dark" ? (
      <Moon className="h-4 w-4" />
    ) : (
      <Sun className="h-4 w-4" />
    )

  if (!mounted) {
    return (
      <Button variant="ghost" size="icon" className="h-9 w-9" aria-label="Theme mode">
        <Monitor className="h-4 w-4" />
      </Button>
    )
  }

  if (forcedTheme) {
    return (
      <Button
        variant="ghost"
        size="icon"
        className="h-9 w-9"
        aria-label={`Theme locked to ${forcedTheme}`}
        disabled
      >
        {icon}
      </Button>
    )
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          variant="ghost"
          size="icon"
          className="h-9 w-9"
          aria-label={`Theme: ${selectedTheme}, effective: ${effectiveTheme}`}
        >
          {icon}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-36">
        <DropdownMenuRadioGroup
          value={selectedTheme}
          onValueChange={(value) => {
            if (isThemeOption(value)) {
              setTheme(value)
            }
          }}
        >
          <DropdownMenuRadioItem value="light">
            <Sun className="h-4 w-4" />
            Light
          </DropdownMenuRadioItem>
          <DropdownMenuRadioItem value="dark">
            <Moon className="h-4 w-4" />
            Dark
          </DropdownMenuRadioItem>
          <DropdownMenuRadioItem value="system">
            <Monitor className="h-4 w-4" />
            System
          </DropdownMenuRadioItem>
        </DropdownMenuRadioGroup>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
