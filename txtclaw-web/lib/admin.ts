function parseList(raw: string | undefined): string[] {
  if (!raw?.trim()) return []
  return raw
    .split(",")
    .map((part) => part.trim())
    .filter((part) => part.length > 0)
}

export function getAdminUserIds(): string[] {
  const explicit = parseList(process.env.TXTCLAW_ADMIN_USER_IDS)
  if (explicit.length > 0) return explicit
  // Back-compat: existing deployments already configure promo admins.
  return parseList(process.env.PROMO_ADMIN_USER_IDS)
}

export function isAdminUserId(userId: string | null | undefined): boolean {
  if (!userId) return false
  const allowlist = getAdminUserIds()
  if (allowlist.length === 0) return false
  return allowlist.includes(userId)
}
