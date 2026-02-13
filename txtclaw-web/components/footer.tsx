import Image from "next/image"
import { Separator } from "@/components/ui/separator"

export function Footer() {
  return (
    <footer className="px-6 pb-8 pt-4">
      <Separator className="mb-8" />
      <div className="mx-auto flex max-w-6xl flex-col gap-6">
        <div className="rounded-2xl border border-border/60 bg-muted/20 p-5 md:p-6">
          <div className="grid gap-5 md:grid-cols-[220px_1fr] md:items-center">
            <a
              href="https://www.nvidia.com/en-us/startups/inception/"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex w-fit rounded-lg border border-border/60 bg-white p-2"
              aria-label="NVIDIA Inception Program"
            >
              <Image
                src="/inception_badges/for-screen/nvidia-inception-program-badge-rgb-for-screen.png"
                alt="NVIDIA Inception Program Member Badge"
                width={501}
                height={217}
                className="h-auto w-full max-w-[210px]"
              />
            </a>

            <div className="space-y-3">
              <h3 className="text-lg font-semibold text-foreground">
                NVIDIA Inception Program Member
              </h3>
              <p className="text-sm text-muted-foreground">
                TXT CLAW is a member of the NVIDIA Inception startup program.
              </p>
              <p className="text-sm text-muted-foreground">
                We also participate in Inception&apos;s Capital Connect ecosystem.
              </p>
            </div>
          </div>
        </div>

        <div className="flex flex-col items-center gap-5">
          <div className="flex w-full flex-col items-center gap-6 md:flex-row md:justify-between">
            <div className="flex flex-wrap items-center justify-center gap-x-4 gap-y-2 text-sm text-muted-foreground">
              <a href="/" aria-label="TXT CLAW home">
                <Image
                  src="/logo_horizontal_lightmode.webp"
                  alt="TXT CLAW"
                  width={1200}
                  height={295}
                  className="h-10 w-auto dark:hidden"
                />
                <Image
                  src="/logo_horizontal_darkmode.webp"
                  alt="TXT CLAW"
                  width={1200}
                  height={295}
                  className="hidden h-10 w-auto dark:block"
                />
              </a>
              <span className="hidden h-3.5 w-px bg-border md:block" />
              <span>
                Built on{" "}
                <a
                  href="https://openclaw.com"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-foreground underline underline-offset-4 transition-colors hover:text-muted-foreground"
                >
                  OpenClaw
                </a>
                {" & "}
                <a
                  href="https://cloudflare.com"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-foreground underline underline-offset-4 transition-colors hover:text-muted-foreground"
                >
                  Cloudflare
                </a>
              </span>
            </div>

            <div className="flex items-center gap-5 text-sm text-muted-foreground">
              <a
                href="/api-reference"
                className="transition-colors hover:text-foreground"
              >
                API Docs
              </a>
              <a
                href="/changelog"
                className="transition-colors hover:text-foreground"
              >
                Changelog
              </a>
              <a
                href="/privacy"
                className="transition-colors hover:text-foreground"
              >
                Privacy
              </a>
              <a
                href="/terms"
                className="transition-colors hover:text-foreground"
              >
                Terms
              </a>
              <a
                href="https://x.com/jacoblopez"
                target="_blank"
                rel="noopener noreferrer"
                className="transition-colors hover:text-foreground"
              >
                @jacoblopez
              </a>
            </div>
          </div>
          <p className="text-center text-[11px] text-muted-foreground/60">
            Independent project. TXT CLAW is not affiliated with Apple,
            Anthropic, or OpenClaw.
          </p>
          <p className="text-center text-xs text-muted-foreground">
            © {new Date().getFullYear()} TXT CLAW
          </p>
        </div>
      </div>
    </footer>
  )
}
