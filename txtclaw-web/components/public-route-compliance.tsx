"use client"

import { StickyComplianceStrip } from "@/components/sticky-compliance-strip"
import { usePathname } from "next/navigation"
import type { ReactNode } from "react"

type PublicRouteComplianceProps = {
  children: ReactNode
  footer: ReactNode
}

function shouldHideCompliance(pathname: string): boolean {
  return (
    pathname === "/admin" ||
    pathname.startsWith("/admin/") ||
    pathname === "/dashboard" ||
    pathname.startsWith("/dashboard/")
  )
}

export function PublicRouteCompliance({ children, footer }: PublicRouteComplianceProps) {
  const pathname = usePathname() || "/"
  const hideCompliance = shouldHideCompliance(pathname)

  if (hideCompliance) {
    return <>{children}</>
  }

  return (
    <>
      <div className="pb-16 md:pb-[4.5rem]">{children}</div>
      <StickyComplianceStrip />
      {footer}
    </>
  )
}
