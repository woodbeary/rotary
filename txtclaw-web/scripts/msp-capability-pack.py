from __future__ import annotations

from datetime import date
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "pdf" / "apple_msp_capability_pack.pdf"


def draw_wrapped(c: canvas.Canvas, text: str, x: float, y: float, max_w: float, font="Helvetica", size=10, leading=13):
    c.setFont(font, size)
    words = text.split(" ")
    line = ""
    for w in words:
        test = (line + " " + w).strip()
        if c.stringWidth(test, font, size) <= max_w:
            line = test
        else:
            c.drawString(x, y, line)
            y -= leading
            line = w
    if line:
        c.drawString(x, y, line)
        y -= leading
    return y


def header(c: canvas.Canvas, title: str):
    W, H = LETTER
    c.setFillColor(colors.black)
    c.setFont("Helvetica-Bold", 16)
    c.drawString(1 * inch, H - 0.9 * inch, "TXT CLAW / The Interpreting App, LLC")
    c.setFont("Helvetica", 10)
    c.setFillColor(colors.HexColor("#333333"))
    c.drawString(
        1 * inch,
        H - 1.12 * inch,
        "7130 Magnolia Ave STE L, Riverside, CA 92504, United States",
    )
    c.drawString(1 * inch, H - 1.28 * inch, "jacob@txtclaw.com | +1 949 529 0538 | https://txtclaw.com")
    c.setStrokeColor(colors.HexColor("#dddddd"))
    c.setLineWidth(1)
    c.line(1 * inch, H - 1.45 * inch, W - 1 * inch, H - 1.45 * inch)

    c.setFillColor(colors.black)
    c.setFont("Helvetica-Bold", 13)
    c.drawString(1 * inch, H - 1.75 * inch, title)
    c.setFont("Helvetica", 10)
    c.setFillColor(colors.HexColor("#444444"))
    c.drawString(1 * inch, H - 1.93 * inch, f"Date: {date.today().strftime('%B %d, %Y')}")

    return H - 2.25 * inch


def bullet(c: canvas.Canvas, label: str, y: float):
    x = 1 * inch
    c.setFont("Helvetica", 10)
    c.setFillColor(colors.black)
    c.drawString(x, y, f"- {label}")
    return y - 14


def table(c: canvas.Canvas, rows: list[tuple[str, str]], y: float):
    W, _ = LETTER
    x0 = 1 * inch
    x1 = W - 1 * inch
    col_mid = x0 + (x1 - x0) * 0.72
    row_h = 18

    # Header row
    c.setFillColor(colors.HexColor("#f3f4f6"))
    c.rect(x0, y - row_h, x1 - x0, row_h, stroke=0, fill=1)
    c.setFillColor(colors.black)
    c.setFont("Helvetica-Bold", 10)
    c.drawString(x0 + 6, y - 13, "Capability")
    c.drawString(col_mid + 6, y - 13, "Status")
    c.setStrokeColor(colors.HexColor("#d1d5db"))
    c.line(x0, y - row_h, x1, y - row_h)
    y -= row_h

    c.setFont("Helvetica", 9)
    for cap, status in rows:
        c.setFillColor(colors.white)
        c.rect(x0, y - row_h, x1 - x0, row_h, stroke=0, fill=1)
        c.setFillColor(colors.black)
        c.drawString(x0 + 6, y - 13, cap[:95])
        c.drawString(col_mid + 6, y - 13, status[:30])
        c.setStrokeColor(colors.HexColor("#e5e7eb"))
        c.line(x0, y - row_h, x1, y - row_h)
        y -= row_h

    # Vertical lines
    c.setStrokeColor(colors.HexColor("#d1d5db"))
    c.line(x0, y + row_h * len(rows), x0, y)
    c.line(col_mid, y + row_h * len(rows), col_mid, y)
    c.line(x1, y + row_h * len(rows), x1, y)

    return y - 10


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(OUT), pagesize=LETTER)
    W, H = LETTER
    max_w = W - 2 * inch

    # Page 1: Overview + Architecture
    y = header(c, "Apple Messages for Business MSP Capability Pack (Test Account / Beta)")

    c.setFont("Helvetica-Bold", 11)
    c.drawString(1 * inch, y, "Purpose")
    y -= 16
    y = draw_wrapped(
        c,
        "This document summarizes TXT CLAW's MSP capabilities and certification plan for Apple Messages for Business. "
        "It is intended to accompany our MSP Qualification Questionnaire and to accelerate technical review.",
        1 * inch,
        y,
        max_w,
    )
    y -= 6

    c.setFont("Helvetica-Bold", 11)
    c.drawString(1 * inch, y, "Platform Summary")
    y -= 16
    for line in [
        "Asynchronous conversations with persistence and context.",
        "Intent-based routing using entrypoint parameters (intentID/groupID) and business rules.",
        "Bot triage and handoff/escalation to live agents with full transcript and metadata.",
        "Web-based operator console (beta): inbox, assignment, templates, internal notes.",
        "Integration framework: APIs + webhooks; professional services for CRM/OMS/auth back-ends.",
    ]:
        y = bullet(c, line, y)
    y -= 6

    c.setFont("Helvetica-Bold", 11)
    c.drawString(1 * inch, y, "Reference Architecture (Typical)")
    y -= 18

    # Simple box diagram
    c.setStrokeColor(colors.HexColor("#111827"))
    c.setLineWidth(1)
    boxes = [
        ("Apple Messages for Business", 1.0, y - 30, 2.3, 0.55),
        ("TXT CLAW MFB Connector\\n(JWT, /message webhook, outbound API)", 3.55, y - 30, 2.95, 0.55),
        ("Router + Policy\\n(intentID/groupID, queues)", 6.75, y - 30, 1.75, 0.55),
        ("Bot / Flows", 3.55, y - 105, 2.1, 0.5),
        ("Operator Console\\n(live agents)", 5.9, y - 105, 2.6, 0.5),
        ("Brand Back-Ends\\n(CRM/OMS/Auth)", 3.55, y - 175, 4.95, 0.55),
    ]
    for txt, bx, by, bw, bh in boxes:
        x = bx * inch
        yy = by
        w = bw * inch
        h = bh * inch
        c.setFillColor(colors.HexColor("#f9fafb"))
        c.rect(x, yy, w, h, stroke=1, fill=1)
        c.setFillColor(colors.black)
        c.setFont("Helvetica", 8.8)
        # center-ish text
        lines = txt.split("\\n")
        ty = yy + h - 14
        for ln in lines:
            c.drawString(x + 8, ty, ln)
            ty -= 12

    # arrows
    def arrow(xa, ya, xb, yb):
        c.setStrokeColor(colors.HexColor("#111827"))
        c.line(xa, ya, xb, yb)

    arrow(3.3 * inch, y - 5, 3.55 * inch, y - 5)
    arrow(6.5 * inch, y - 5, 6.75 * inch, y - 5)
    arrow(4.6 * inch, y - 30 - 6, 4.6 * inch, y - 105 + 0.5 * inch)
    arrow(6.95 * inch, y - 30 - 6, 6.95 * inch, y - 105 + 0.5 * inch)
    arrow(5.8 * inch, y - 105 - 6, 5.8 * inch, y - 175 + 0.55 * inch)

    c.showPage()

    # Page 2: Feature coverage + demo plan
    y = header(c, "Feature Coverage and Certification Demo Plan")

    c.setFont("Helvetica-Bold", 11)
    c.drawString(1 * inch, y, "Feature Coverage (Summary)")
    y -= 16

    y = table(
        c,
        [
            ("Send/receive messages (text, international chars)", "Implemented"),
            ("Send/receive attachments up to 100MB", "In progress"),
            ("Tapback reactions detection", "In progress"),
            ("Closed conversation/opt-out handling", "Implemented"),
            ("Rich links for URLs", "Implemented"),
            ("Typing indicators (bi-directional)", "In progress"),
            ("Quick replies", "In progress"),
            ("List pickers", "In progress"),
            ("Time pickers", "In progress"),
            ("Form messages", "In progress"),
            ("Routing by entrypoint parameters (intentID/groupID)", "Implemented"),
            ("Channel settings + landing page + account linking", "In progress"),
            ("Authentication message (OAuth2 inline)", "Planned for certification"),
            ("Apple Pay message", "Planned for certification"),
            ("Construct payload API (App Clips RichLink)", "Planned for certification"),
        ],
        y,
    )

    c.setFont("Helvetica", 9)
    c.setFillColor(colors.HexColor("#4b5563"))
    y = draw_wrapped(
        c,
        "Note: Items marked 'Planned for certification' are committed scope for the certification demo and will be completed prior to connecting brands.",
        1 * inch,
        y,
        max_w,
        size=9,
        leading=12,
    )
    y -= 6

    c.setFillColor(colors.black)
    c.setFont("Helvetica-Bold", 11)
    c.drawString(1 * inch, y, "Certification Demo Journey (Live Review)")
    y -= 16
    for line in [
        "Entry point routes customer into correct intent (intentID/groupID) and queue.",
        "Bot triage: quick replies and a list picker to collect structured details.",
        "Handoff to live agent with full transcript, metadata, and customer context.",
        "Agent sends a form message; customer submits; back-end integration is invoked via webhook.",
        "Optional: Authentication (OAuth2 inline) and Apple Pay payment request, then confirmation.",
        "Closed conversation handling: opt-out/close signal prevents further sends.",
    ]:
        y = bullet(c, line, y)

    y -= 8
    c.setFont("Helvetica-Bold", 11)
    c.drawString(1 * inch, y, "Operational Commitments")
    y -= 16
    for line in [
        "Consent-based messaging only; no unsolicited outbound notifications.",
        "Audit logging and abuse controls (rate limits, idempotency, signature verification).",
        "Stay current with new Apple Messages for Business feature releases.",
    ]:
        y = bullet(c, line, y)

    c.showPage()
    c.save()


if __name__ == "__main__":
    main()

