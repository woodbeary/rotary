import type { Metadata } from "next"
import Link from "next/link"
import { ArrowLeft, ExternalLink } from "lucide-react"
import { fetchOpenClawChangelog } from "@/lib/changelog"

const OPENCLAW_RELEASES_URL = "https://github.com/openclaw/openclaw/releases"

export const metadata: Metadata = {
  title: "Changelog — TXT CLAW",
  description:
    "Track upstream OpenClaw release updates and what is rolling into TXT CLAW.",
}

export default async function ChangelogPage() {
  const { items, error } = await fetchOpenClawChangelog(20)

  return (
    <main className="min-h-screen bg-background">
      <div className="mx-auto max-w-4xl px-6 py-16 md:py-24">
        <Link
          href="/"
          className="mb-10 inline-flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" />
          Back to home
        </Link>

        <div className="rounded-2xl border border-border/60 bg-card p-8 md:p-10">
          <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            Changelog
          </h1>
          <p className="mt-4 text-base leading-relaxed text-muted-foreground">
            This feed mirrors upstream OpenClaw releases. Some updates may appear
            here before they are fully enabled in TXT CLAW.
          </p>

          <a
            href={OPENCLAW_RELEASES_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="mt-4 inline-flex items-center gap-2 rounded-md border border-border px-3 py-2 text-sm font-medium text-foreground transition-colors hover:bg-accent"
          >
            View OpenClaw Releases
            <ExternalLink className="h-4 w-4" />
          </a>

          {items.length > 0 ? (
            <div className="mt-8 space-y-4">
              {items.map((item) => (
                <article
                  key={item.id}
                  className="rounded-xl border border-border/60 bg-muted/20 p-5"
                >
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <h2 className="text-lg font-semibold text-foreground">
                        {item.title}
                      </h2>
                      <p className="mt-1 text-xs text-muted-foreground">
                        {item.tag} •{" "}
                        {new Date(item.publishedAt).toLocaleDateString("en-US", {
                          month: "short",
                          day: "numeric",
                          year: "numeric",
                        })}
                      </p>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      <span className="inline-flex items-center rounded-md border border-border px-2 py-1 text-[11px] text-muted-foreground">
                        Upstream (OpenClaw)
                      </span>
                      {item.prerelease && (
                        <span className="inline-flex items-center rounded-md border border-amber-500/40 bg-amber-500/10 px-2 py-1 text-[11px] font-medium text-amber-300">
                          Pre-release
                        </span>
                      )}
                    </div>
                  </div>

                  {item.excerpt && (
                    <p className="mt-3 whitespace-pre-wrap text-sm leading-relaxed text-muted-foreground">
                      {item.excerpt}
                    </p>
                  )}

                  <a
                    href={item.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="mt-4 inline-flex items-center gap-1.5 text-sm font-medium text-foreground underline underline-offset-4 transition-colors hover:text-muted-foreground"
                  >
                    Read full release notes
                    <ExternalLink className="h-3.5 w-3.5" />
                  </a>
                </article>
              ))}
            </div>
          ) : (
            <div className="mt-8 rounded-xl border border-border/60 bg-muted/20 p-5">
              <p className="text-sm font-medium text-foreground">
                Could not load releases right now.
              </p>
              <p className="mt-2 text-sm text-muted-foreground">
                {error || "Please check back shortly."}
              </p>
              <a
                href={OPENCLAW_RELEASES_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="mt-4 inline-flex items-center gap-2 text-sm font-medium text-foreground underline underline-offset-4"
              >
                Open releases on GitHub
                <ExternalLink className="h-3.5 w-3.5" />
              </a>
            </div>
          )}
        </div>
      </div>
    </main>
  )
}
