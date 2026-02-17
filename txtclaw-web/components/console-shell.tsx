"use client"

import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarInset,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarProvider,
  SidebarSeparator,
  SidebarTrigger,
} from "@/components/ui/sidebar"
import { cn } from "@/lib/utils"
import { SignedIn, UserButton } from "@clerk/nextjs"
import { Activity, BookOpen, CreditCard, KeyRound, Sparkles } from "lucide-react"
import Link from "next/link"
import { usePathname } from "next/navigation"
import type { ReactNode } from "react"

type NavItem = {
  href: string
  label: string
  icon: ReactNode
  adminOnly?: boolean
}

const NAV: NavItem[] = [
  { href: "/dashboard/api-keys", label: "API Keys", icon: <KeyRound className="h-4 w-4" /> },
  { href: "/dashboard/billing", label: "Billing", icon: <CreditCard className="h-4 w-4" /> },
  {
    href: "/admin/traces",
    label: "Traces",
    icon: <Activity className="h-4 w-4" />,
    adminOnly: true,
  },
  {
    href: "/admin/prompts",
    label: "Prompts",
    icon: <Sparkles className="h-4 w-4" />,
    adminOnly: true,
  },
]

export function ConsoleShell({
  children,
  isAdmin,
  title = "Developer Console",
}: {
  children: ReactNode
  isAdmin: boolean
  title?: string
}) {
  const pathname = usePathname()

  const items = NAV.filter((item) => (item.adminOnly ? isAdmin : true))

  return (
    <SidebarProvider defaultOpen>
      <Sidebar variant="inset" collapsible="icon">
        <SidebarHeader className="gap-1">
          <div className="px-2 py-1.5">
            <div className="text-sm font-semibold text-sidebar-foreground">TXT CLAW</div>
            <div className="text-xs text-sidebar-foreground/60">Console</div>
          </div>
        </SidebarHeader>
        <SidebarSeparator />
        <SidebarContent>
          <SidebarMenu>
            {items.map((item) => {
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

          <SidebarSeparator className="my-2" />

          <SidebarMenu>
            <SidebarMenuItem>
              <SidebarMenuButton asChild tooltip="Docs">
                <Link href="/developers">
                  <BookOpen className="h-4 w-4" />
                  <span>Docs</span>
                </Link>
              </SidebarMenuButton>
            </SidebarMenuItem>
          </SidebarMenu>
        </SidebarContent>
        <SidebarFooter className="px-2 py-2">
          <div className="rounded-md border border-sidebar-border bg-sidebar-accent/40 px-2 py-2 text-[11px] leading-relaxed text-sidebar-foreground/70">
            Pasteable docs:{" "}
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
            <SignedIn>
              <div className={cn("flex items-center gap-2")}>
                <UserButton afterSignOutUrl="/" />
              </div>
            </SignedIn>
          </div>
        </header>
        <main className="mx-auto w-full max-w-6xl px-4 py-8 md:px-6 md:py-10">{children}</main>
      </SidebarInset>
    </SidebarProvider>
  )
}
