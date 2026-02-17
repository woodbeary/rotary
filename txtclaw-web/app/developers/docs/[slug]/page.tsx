import fs from "node:fs/promises"
import path from "node:path"
import { CodeBlock } from "@/components/code-block"
import { CopyButton } from "@/components/copy-button"
import { DevDocsMarkdown } from "@/components/dev-docs-markdown"
import { DevDocsShell } from "@/components/dev-docs-shell"
import { Button } from "@/components/ui/button"
import { DEV_DOCS, DEV_DOCS_BY_SLUG } from "@/lib/dev-docs"
import { getPublicAppUrl, joinUrl } from "@/lib/txtclaw-urls"
import type { Metadata } from "next"
import { notFound } from "next/navigation"

export const dynamicParams = false

export function generateStaticParams() {
  return DEV_DOCS.map((doc) => ({ slug: doc.slug }))
}

export function generateMetadata({ params }: { params: { slug: string } }): Metadata {
  const doc = DEV_DOCS_BY_SLUG[params.slug]
  if (!doc) return {}
  return {
    title: `${doc.title} — Developers — TXT CLAW`,
    description: `TXT CLAW developer docs: ${doc.title}.`,
  }
}

async function readPublicFile(rawPath: string): Promise<string> {
  const filename = String(rawPath || "").replace(/^\/+/, "")
  const abs = path.join(process.cwd(), "public", filename)
  return await fs.readFile(abs, "utf8")
}

export default async function DeveloperDocPage({ params }: { params: { slug: string } }) {
  const doc = DEV_DOCS_BY_SLUG[params.slug]
  if (!doc) notFound()

  const content = await readPublicFile(doc.rawPath)
  const rawUrl = joinUrl(getPublicAppUrl(), doc.rawPath)

  return (
    <DevDocsShell title={doc.title}>
      <div className="space-y-6">
        <header className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div className="min-w-0">
            <h1 className="text-balance font-mono text-2xl font-bold tracking-tight text-foreground md:text-3xl">
              {doc.title}
            </h1>
            <p className="mt-2 text-sm text-muted-foreground">
              Rendered for humans. Raw endpoint stays available for bots and copy/paste.
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <Button variant="outline" asChild>
              <a href={doc.rawPath}>Raw</a>
            </Button>
            <CopyButton text={rawUrl} label="Copy raw URL" variant="secondary" />
          </div>
        </header>

        {doc.kind === "markdown" ? <DevDocsMarkdown content={content} /> : null}

        {doc.kind === "yaml" ? (
          <div className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
            <CodeBlock className="border-0" language="yaml" code={content} copyLabel="Copy YAML" />
          </div>
        ) : null}

        {doc.kind === "text" ? (
          <div className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
            <CodeBlock className="border-0" language="text" code={content} copyLabel="Copy text" />
          </div>
        ) : null}
      </div>
    </DevDocsShell>
  )
}
