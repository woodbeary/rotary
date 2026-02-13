import { ImageResponse } from "next/og"

export const runtime = "edge"

export const size = {
  width: 1200,
  height: 630,
}

export const contentType = "image/png"

export default async function OpenGraphImage() {
  const logo = await fetch(
    new URL("../public/logo_horizontal_darkmode.png", import.meta.url)
  ).then((res) => res.arrayBuffer())

  const geistPixelSquare = await fetch(
    new URL("../public/fonts/GeistPixel-Square.otf", import.meta.url)
  ).then((res) => res.arrayBuffer())

  const geistPixelGrid = await fetch(
    new URL("../public/fonts/GeistPixel-Grid.otf", import.meta.url)
  ).then((res) => res.arrayBuffer())

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          padding: 72,
          backgroundColor: "#070707",
          backgroundImage:
            "radial-gradient(900px 420px at 20% 20%, rgba(255,255,255,0.08), transparent 60%), radial-gradient(820px 380px at 85% 70%, rgba(255,255,255,0.06), transparent 60%)",
          color: "#ffffff",
          fontFamily: "GeistPixelSquare",
        }}
      >
        <div style={{ display: "flex", alignItems: "center" }}>
          <img
            src={logo}
            width={560}
            height={138}
            alt="TXT CLAW"
            style={{
              width: 540,
              height: 132,
              objectFit: "contain",
            }}
          />
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              fontSize: 94,
              fontWeight: 800,
              lineHeight: 1.05,
              letterSpacing: -0.4,
            }}
          >
            <span>Your own AI.</span>
            <span>One text away.</span>
          </div>
          <div
            style={{
              fontSize: 36,
              color: "rgba(255,255,255,0.74)",
            }}
          >
            AI agent on a real phone number
          </div>
        </div>

        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "flex-end",
            gap: 16,
            fontSize: 18,
            color: "rgba(255,255,255,0.65)",
          }}
        >
          <div
            style={{
              display: "flex",
              gap: 10,
              alignItems: "center",
              fontFamily: "GeistPixelGrid",
            }}
          >
            <div
              style={{
                width: 10,
                height: 10,
                borderRadius: 999,
                background: "#34d399",
                boxShadow: "0 0 0 6px rgba(52,211,153,0.14)",
              }}
            />
            Text-first. Fast. Private by default.
          </div>
          <div style={{ fontWeight: 600, fontFamily: "GeistPixelGrid" }}>
            txtclaw.com
          </div>
        </div>
      </div>
    ),
    {
      width: size.width,
      height: size.height,
      fonts: [
        {
          name: "GeistPixelSquare",
          data: geistPixelSquare,
          style: "normal",
          weight: 400,
        },
        {
          name: "GeistPixelGrid",
          data: geistPixelGrid,
          style: "normal",
          weight: 400,
        },
      ],
    }
  )
}
