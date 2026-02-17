export type ChangelogItem = {
  id: number
  title: string
  tag: string
  url: string
  publishedAt: string
  prerelease: boolean
  excerpt: string | null
}

type GitHubRelease = {
  id: number
  name: string | null
  tag_name: string
  html_url: string
  body: string | null
  prerelease: boolean
  draft: boolean
  published_at: string | null
  created_at: string
}

const OPENCLAW_RELEASES_API = "https://api.github.com/repos/openclaw/openclaw/releases"

function toExcerpt(body: string | null, maxChars = 420) {
  if (!body) return null
  const clean = body.replace(/\r/g, "").trim()
  if (!clean) return null
  if (clean.length <= maxChars) return clean
  return `${clean.slice(0, maxChars).trimEnd()}...`
}

function mapRelease(release: GitHubRelease): ChangelogItem {
  return {
    id: release.id,
    title: release.name?.trim() || release.tag_name,
    tag: release.tag_name,
    url: release.html_url,
    publishedAt: release.published_at || release.created_at,
    prerelease: release.prerelease,
    excerpt: toExcerpt(release.body),
  }
}

export async function fetchOpenClawChangelog(limit = 12) {
  try {
    const res = await fetch(`${OPENCLAW_RELEASES_API}?per_page=${limit}`, {
      headers: {
        Accept: "application/vnd.github+json",
      },
      next: { revalidate: 60 * 60 },
    })

    if (!res.ok) {
      return {
        items: [] as ChangelogItem[],
        error: `GitHub API returned ${res.status}`,
      }
    }

    const data: unknown = await res.json()
    if (!Array.isArray(data)) {
      return {
        items: [] as ChangelogItem[],
        error: "Unexpected GitHub API response shape",
      }
    }

    const items = (data as GitHubRelease[]).filter((release) => !release.draft).map(mapRelease)

    return { items, error: null as string | null }
  } catch (error) {
    return {
      items: [] as ChangelogItem[],
      error: error instanceof Error ? error.message : "Failed to fetch releases",
    }
  }
}
