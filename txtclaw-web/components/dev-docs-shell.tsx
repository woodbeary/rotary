"use client"

import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarInset,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarProvider,
  SidebarSeparator,
  SidebarTrigger,
} from "@/components/ui/sidebar"
import { CLERK_ENABLED } from "@/lib/clerk-config"
import { DEV_DOCS, getRenderedDevDocHref } from "@/lib/dev-docs"
import { SignInButton, SignUpButton, SignedIn, SignedOut, UserButton } from "@clerk/nextjs"
import {
  BookOpen,
  CreditCard,
  KeyRound,
  Rocket,
  Route,
  ScrollText,
  Shield,
  Terminal,
} from "lucide-react"
import Link from "next/link"
import { usePathname } from "next/navigation"
import type { ReactNode } from "react"

type NavItem = {
  href: string
  label: string
  icon: ReactNode
}

const DOCS_NAV: NavItem[] = [
  { href: "/developers", label: "Overview", icon: <BookOpen className="h-4 w-4" /> },
  { href: "/api-reference", label: "API Reference", icon: <ScrollText className="h-4 w-4" /> },
  { href: "/openclaw-router", label: "Router", icon: <Route className="h-4 w-4" /> },
  { href: "/byok", label: "BYOK", icon: <Shield className="h-4 w-4" /> },
  { href: "/openclaw-mcp", label: "MCP", icon: <Terminal className="h-4 w-4" /> },
  { href: "/openclaw-sdk", label: "SDK", icon: <Terminal className="h-4 w-4" /> },
] as const

const CONSOLE_NAV: NavItem[] = [
  { href: "/dashboard/api-keys", label: "API Keys", icon: <KeyRound className="h-4 w-4" /> },
  { href: "/dashboard/billing", label: "Billing", icon: <CreditCard className="h-4 w-4" /> },
] as const

const PASTEABLE_NAV: NavItem[] = DEV_DOCS.map((doc) => {
  const href = getRenderedDevDocHref(doc.slug)
  const icon =
    doc.slug === "quickstart" ? (
      <Rocket className="h-4 w-4" />
    ) : doc.slug === "api-keys" ? (
      <KeyRound className="h-4 w-4" />
    ) : doc.slug === "security" ? (
      <Shield className="h-4 w-4" />
    ) : (
      <Terminal className="h-4 w-4" />
    )

  return { href, label: doc.title, icon }
})

export function DevDocsShell({
  title = "Developers",
  children,
}: {
  title?: string
  children: ReactNode
}) {
  const pathname = usePathname()

  return (
    <SidebarProvider defaultOpen>
      <Sidebar variant="inset" collapsible="offcanvas">
        <SidebarHeader className="gap-1">
          <div className="px-2 py-1.5">
            <div className="text-sm font-semibold text-sidebar-foreground">TXT CLAW</div>
            <div className="text-xs text-sidebar-foreground/60">Developers</div>
          </div>
        </SidebarHeader>
        <SidebarSeparator />
        <SidebarContent>
          <SidebarGroup>
            <SidebarGroupLabel>Docs</SidebarGroupLabel>
            <SidebarGroupContent>
              <SidebarMenu>
                {DOCS_NAV.map((item) => {
                  const active = pathname === item.href
                  return (
                    <SidebarMenuItem key={item.href}>
                      <SidebarMenuButton asChild isActive={active} tooltip={item.label}>
                        <Link href={item.href}>
                          {item.icon}
                          <span>{item.label}</span>
                        </Link>
                      </SidebarMenuButton>
                    </SidebarMenuItem>
                  )
                })}
              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>

          <SidebarSeparator className="my-2" />

          <SidebarGroup>
            <SidebarGroupLabel>Console</SidebarGroupLabel>
            <SidebarGroupContent>
              <SidebarMenu>
                {CONSOLE_NAV.map((item) => (
                  <SidebarMenuItem key={item.href}>
                    <SidebarMenuButton asChild tooltip={item.label}>
                      <Link href={item.href}>
                        {item.icon}
                        <span>{item.label}</span>
                      </Link>
                    </SidebarMenuButton>
                  </SidebarMenuItem>
                ))}
              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>

          <SidebarSeparator className="my-2" />

          <SidebarGroup>
            <SidebarGroupLabel>Pasteable Docs</SidebarGroupLabel>
            <SidebarGroupContent>
              <SidebarMenu>
                {PASTEABLE_NAV.map((item) => {
                  const active = pathname === item.href
                  return (
                    <SidebarMenuItem key={item.href}>
                      <SidebarMenuButton asChild isActive={active} tooltip={item.label}>
                        <Link href={item.href}>
                          {item.icon}
                          <span>{item.label}</span>
                        </Link>
                      </SidebarMenuButton>
                    </SidebarMenuItem>
                  )
                })}
              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>
        </SidebarContent>
        <SidebarFooter className="px-2 py-2">
          <div className="rounded-md border border-sidebar-border bg-sidebar-accent/40 px-2 py-2 text-[11px] leading-relaxed text-sidebar-foreground/70">
            Paste into bots:{" "}
            <a className="underline underline-offset-4" href="/quickstart.md">
              /quickstart.md
            </a>
          </div>
        </SidebarFooter>
      </Sidebar>

      <SidebarInset>
        <header className="sticky top-0 z-40 border-b border-border/60 bg-background/80 backdrop-blur-xl">
          <div className="mx-auto flex h-14 max-w-6xl items-center gap-3 px-4 md:px-6">
            <SidebarTrigger className="-ml-1" />
            <div className="min-w-0 flex-1">
              <div className="truncate text-sm font-medium text-foreground">{title}</div>
            </div>

            {CLERK_ENABLED ? (
              <>
                <SignedOut>
                  <div className="flex items-center gap-2">
                    <SignInButton mode="modal">
                      <button
                        type="button"
                        className="inline-flex items-center rounded-md border border-border bg-background px-3 py-1.5 text-sm text-foreground hover:bg-accent"
                      >
                        Sign in
                      </button>
                    </SignInButton>
                    <SignUpButton mode="modal">
                      <button
                        type="button"
                        className="hidden items-center rounded-md border border-border bg-foreground px-3 py-1.5 text-sm text-background hover:bg-foreground/90 sm:inline-flex"
                      >
                        Sign up
                      </button>
                    </SignUpButton>
                  </div>
                </SignedOut>
                <SignedIn>
                  <div className="flex items-center gap-2">
                    <Link
                      href="/dashboard/api-keys"
                      className="hidden sm:inline-flex items-center rounded-md border border-border bg-background px-3 py-1.5 text-sm text-foreground hover:bg-accent"
                    >
                      Dashboard
                    </Link>
                    <UserButton afterSignOutUrl="/" />
                  </div>
                </SignedIn>
              </>
            ) : null}
          </div>
        </header>
        <main className="mx-auto w-full max-w-6xl px-4 py-8 md:px-6 md:py-10">{children}</main>
      </SidebarInset>
    </SidebarProvider>
  )
}
