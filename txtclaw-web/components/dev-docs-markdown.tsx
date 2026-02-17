import { CodeBlock } from "@/components/code-block"
import { maybeRewriteDevDocHref } from "@/lib/dev-docs"
import { cn } from "@/lib/utils"
import Link from "next/link"
import ReactMarkdown from "react-markdown"
import remarkGfm from "remark-gfm"

export function DevDocsMarkdown({ content }: { content: string }) {
  return (
    <div className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
      <article className="prose prose-neutral max-w-none dark:prose-invert">
        <ReactMarkdown
          remarkPlugins={[remarkGfm]}
          components={{
            a: ({ node: _node, href, className, title, children, ...props }) => {
              const rewritten = maybeRewriteDevDocHref(href)
              const finalHref = rewritten || href || ""
              const isHashLink = finalHref.startsWith("#")
              const isInternalPath = finalHref.startsWith("/")
              const isExternalHttp =
                finalHref.startsWith("http://") || finalHref.startsWith("https://")

              if (isHashLink) {
                return (
                  <a href={finalHref} className={className} title={title} {...props}>
                    {children}
                  </a>
                )
              }

              if (isInternalPath) {
                return (
                  <Link href={finalHref} className={className} title={title}>
                    {children}
                  </Link>
                )
              }

              return (
                <a
                  href={finalHref}
                  className={className}
                  title={title}
                  target={isExternalHttp ? "_blank" : undefined}
                  rel={isExternalHttp ? "noreferrer" : undefined}
                  {...props}
                >
                  {children}
                </a>
              )
            },
            pre: ({ node: _node, children }) => <>{children}</>,
            // react-markdown keeps element props generic; we destructure the markdown-specific
            // fields we care about and pass the rest through.
            code: (allProps: any) => {
              const {
                inline,
                className,
                children,
                node: _node,
                ...rest
              } = allProps as {
                inline?: boolean
                className?: string
                children?: unknown
                node?: unknown
              }

              const text = String(children ?? "")
              const match = /language-([a-z0-9_-]+)/i.exec(String(className || ""))
              const language = match?.[1]

              // Inline code: keep it lightweight and readable inside prose.
              if (inline) {
                return (
                  <code
                    className={cn(
                      "rounded bg-muted px-1.5 py-0.5 font-mono text-[0.9em] text-foreground",
                      className,
                    )}
                    {...rest}
                  >
                    {text}
                  </code>
                )
              }

              // Block code: render via our shadcn-style CodeBlock so copy works consistently.
              return (
                <CodeBlock className="my-4" language={language} code={text.replace(/\n$/, "")} />
              )
            },
          }}
        >
          {content}
        </ReactMarkdown>
      </article>
    </div>
  )
}
