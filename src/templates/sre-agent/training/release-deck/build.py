#!/usr/bin/env python3
"""Build V8 deck via python-pptx end-to-end (no XML hand-crafting).

python-pptx uses the official OPC API and produces files PowerPoint accepts
without prompting for repair.

Pipeline:
  1. Load source.pptx (template) into a Presentation
  2. Resolve the 4 layouts I need by name
  3. Delete every existing slide
  4. For each V6 row, add_slide(layout) and populate placeholders + notes
  5. Save
"""
import json
import re
import sys
from pathlib import Path

from pptx import Presentation
from pptx.util import Pt, Inches, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from copy import deepcopy
from lxml import etree

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "source-template.pptx"
ASSETS = ROOT / "assets"
OUT = ROOT / "finops-toolkit-sre-agent-release-training.pptx"
V8 = ROOT / "deck-outline-v8.md"
CHARTS = ROOT / "charts" / "svg"

# ─── Layout names from the template ──────────────────────────
LAYOUT_TITLE   = "Title Slide"
LAYOUT_SECTION = "Section Title"
LAYOUT_CONTENT = "Title and Content"
LAYOUT_TWOCOL  = "Two Column Content with Subheads"
LAYOUT_QUOTE   = "Quote 1"
LAYOUT_CODE    = "Developer Code Layout"

# Map kind → layout name
KIND_LAYOUT = {
    "TITLE":            LAYOUT_TITLE,
    "WHEEL_STATS":      LAYOUT_CONTENT,
    "BULLETS":          LAYOUT_CONTENT,
    "MATRIX":           LAYOUT_CONTENT,
    "SECTION_TWOCOL":   LAYOUT_TWOCOL,
    "SECTION_HEADLINE": LAYOUT_SECTION,
    "TWOUP_IMAGES":     LAYOUT_TWOCOL,
    "TWOCOL_LISTS":     LAYOUT_TWOCOL,
    "CARDS_3":          LAYOUT_CONTENT,
    "CARDS_2":          LAYOUT_CONTENT,
    "CARDS_4":          LAYOUT_CONTENT,
    "TABLE":            LAYOUT_CONTENT,
    "WHEEL_LARGE":      LAYOUT_CONTENT,
    "THREE_BLOCK":      LAYOUT_CONTENT,
    "ASK_A":            LAYOUT_CONTENT,
    "ASK_B":            LAYOUT_CONTENT,
    "ASK_C":            LAYOUT_CONTENT,
    "INDEX":            LAYOUT_CONTENT,
}

# Verdict colors for footer chip
VERDICT_COLORS = {
    "green":  ("2E7D32", "E8F5E9"),   # dark green text, light green bg
    "yellow": ("F57F17", "FFF8E1"),   # dark amber text, light amber bg
    "red":    ("C62828", "FFEBEE"),   # dark red text, light red bg
}


# ─── V8 parser (handles 3 concatenated tables) ──────────────

def parse_table_cells(line):
    if not line.startswith("|") or not line.endswith("|"):
        return None
    # Handle escaped pipes (\|) within cells by temporarily replacing them
    line_clean = line.replace("\\|", "\x00PIPE\x00")
    cells = [c.strip().replace("\x00PIPE\x00", "|") for c in line_clean[1:-1].split("|")]
    return cells


def html_br_to_lines(s):
    parts = re.split(r"<br\s*/?>", s)
    return [p.strip() for p in parts if p.strip()]


def strip_md(s):
    s = re.sub(r"\[\[([^\]|]+)(?:\|[^\]]+)?\]\]", r"\1", s)
    s = re.sub(r"\*\*([^*]+)\*\*", r"\1", s)
    # Italic: only match *text* (no spaces around) — preserves cron asterisks like "30 6 * * *"
    s = re.sub(r"(?<![\*\s])\*(\S[^*]*?\S)\*(?![\*])", r"\1", s)
    s = re.sub(r"(?<![\*\s])\*(\S)\*(?![\*])", r"\1", s)
    s = re.sub(r"`([^`]+)`", r"\1", s)
    s = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1 (\2)", s)
    # Decode HTML entities
    s = s.replace("&gt;", ">").replace("&lt;", "<").replace("&amp;", "&")
    s = s.replace("&quot;", '"').replace("&#39;", "'")
    return s


def strip_bullet(s):
    return re.sub(r"^[•·\-\*]\s+", "", s.strip())


def parse_v8():
    text = V8.read_text(encoding="utf-8")
    lines = text.split("\n")

    # Find ALL table header lines (V8 has 3 tables)
    table_starts = []
    for i, ln in enumerate(lines):
        if ln.startswith("| # | Cluster | Title |") or ln.startswith("| # |Cluster|"):
            table_starts.append(i)

    if not table_starts:
        sys.exit("V8 slide-scaffold table not found")

    rows = []
    for table_start in table_starts:
        i = table_start + 2  # skip header + separator
        while i < len(lines):
            ln = lines[i]
            if not ln.startswith("|"):
                break
            cells = parse_table_cells(ln)
            if not cells or len(cells) < 7:
                i += 1
                continue
            num, stage, title, content, notes, layout, screens = cells[:7]
            # Strip markdown from num field (drafter output may use **P1.2.A** bold)
            num = strip_md(num).strip()
            # Accept slide IDs like 0.1, P1.1.A, P2.3.B, H.1, Z.1, 1.99, 2.99, 2.0.1
            if not re.match(r"^[\d.]+$|^P\d+\.\d+\.[ABC]$|^[HZ]\.\d+$", num) or "APPENDIX" in (stage or ""):
                i += 1
                continue
            bullets = [strip_md(strip_bullet(b)) for b in html_br_to_lines(content)]
            notes_paras = [strip_md(p) for p in html_br_to_lines(notes)] or [strip_md(notes)]
            m = re.match(r"kind=(\w+)\s*·?\s*(.*)", layout)
            kind = m.group(1) if m else "BULLETS"
            layout_desc = m.group(2) if m else strip_md(layout)

            # Parse addresses and verdict from layout directive
            addresses = []
            verdict = None
            addr_m = re.search(r"addresses=([\d,]+)", layout_desc)
            if addr_m:
                addresses = [int(x.strip()) for x in addr_m.group(1).split(",") if x.strip()]
            verd_m = re.search(r"verdict=(\w+)", layout_desc)
            if verd_m:
                verdict = verd_m.group(1).lower()

            # Parse assets directive in screens column
            screens_text = strip_md(screens)
            assets = {}
            am = re.search(r"assets:\s*(.+?)$", screens_text)
            if am:
                for kv in re.finditer(r"(\w+)\s*=\s*([^\s|]+)", am.group(1)):
                    assets[kv.group(1)] = kv.group(2)

            rows.append({
                "num": num, "stage": strip_md(stage), "title": strip_md(title),
                "bullets": bullets, "notes": notes_paras, "kind": kind,
                "layout": strip_md(layout_desc),
                "assets": assets,
                "addresses": addresses,
                "verdict": verdict,
            })
            i += 1
    return rows


# ─── Layout / placeholder helpers ────────────────────────────

def find_layout(prs, name):
    """Find a layout by name, preferring the first slide master (master 0)."""
    # First try master 0 (the branded master used by V6)
    master0 = list(prs.slide_masters)[0]
    for layout in master0.slide_layouts:
        if layout.name == name:
            return layout
    # Fallback: search all masters
    for master in prs.slide_masters:
        for layout in master.slide_layouts:
            if layout.name == name:
                return layout
    raise KeyError(f"Layout {name!r} not found")


def get_placeholder(slide, idx):
    for ph in slide.placeholders:
        if ph.placeholder_format.idx == idx:
            return ph
    return None


def set_text_frame(ph, paragraphs):
    """Populate a text-frame placeholder.

    paragraphs is a list of either strings or dicts with {text, size, bold, color}.
    """
    if ph is None:
        return
    tf = ph.text_frame
    tf.clear()
    for i, p in enumerate(paragraphs):
        if isinstance(p, str):
            text, attrs = p, {}
        else:
            text, attrs = p["text"], p

        if i == 0:
            para = tf.paragraphs[0]
        else:
            para = tf.add_paragraph()

        # Clear any inherited content
        for r in list(para.runs):
            r.text = ""

        run = para.add_run()
        run.text = text or ""

        font = run.font
        if attrs.get("size"):
            font.size = Pt(attrs["size"])
        if attrs.get("bold"):
            font.bold = True
        if attrs.get("color"):
            font.color.rgb = RGBColor.from_string(attrs["color"])


# ─── Content classifier helpers ──────────────────────────────

def split_label(bullet):
    """Split 'Label: rest' into (label, body). Label can contain parens, hyphens, spaces."""
    m = re.match(r"^([A-Z][\w\-\s\(\)\/]{0,40}?):\s+(.+)$", bullet)
    if m:
        return m.group(1).strip(), m.group(2)
    return None, bullet


def find_prefixed(bullets, prefixes):
    """Match bullets whose label STARTS WITH any of `prefixes` (case-insensitive).

    Examples that match prefix 'Capacity':
      'Capacity: ...'
      'Capacity output: ...'
      'Capacity (cadence): ...'
    """
    plow = [p.lower() for p in prefixes]
    for b in bullets:
        label, body = split_label(b)
        if label and any(label.lower().startswith(p) for p in plow):
            return body
    return None


def add_image_to_placeholder(slide, ph, asset_filename, sl_w_emu, sl_h_emu):
    """Insert an image inside the bounds of a placeholder, then clear the placeholder text.

    SVG assets are rasterized to PNG via rsvg-convert before insertion.
    Searches both ASSETS and CHARTS directories.
    """
    asset_path = ASSETS / asset_filename
    if not asset_path.exists():
        asset_path = CHARTS / asset_filename
    if not asset_path.exists():
        print(f"   ! asset missing: {asset_filename}")
        return

    if asset_path.suffix.lower() == ".svg":
        png_path = asset_path.with_suffix(".rasterized.png")
        if not png_path.exists():
            import subprocess
            subprocess.run(
                ["rsvg-convert", "-w", "1600", "-o", str(png_path), str(asset_path)],
                check=True,
            )
        asset_path = png_path

    left, top = ph.left, ph.top
    width, height = ph.width, ph.height
    slide.shapes.add_picture(str(asset_path), left, top, width=width, height=height)
    if ph.has_text_frame:
        ph.text_frame.clear()


# ─── Per-kind renderers (use python-pptx, not raw XML) ───────

def render_title(slide, row):
    from pptx.enum.shapes import MSO_SHAPE
    if slide.shapes.title is not None:
        title_ph = slide.shapes.title
        title_ph.text = row["title"]
        for p in title_ph.text_frame.paragraphs:
            p.alignment = PP_ALIGN.CENTER

    sub = find_prefixed(row["bullets"], ["Subtitle"]) or ""
    aud = find_prefixed(row["bullets"], ["Audience tag"]) or ""
    cob = find_prefixed(row["bullets"], ["Co-brand"]) or ""
    body = get_placeholder(slide, 12)
    set_text_frame(body, [
        {"text": sub, "size": 28},
        {"text": ""},
        {"text": aud, "size": 16, "color": "595959"},
    ])
    if body is not None:
        for p in body.text_frame.paragraphs:
            p.alignment = PP_ALIGN.CENTER

    # Co-brand strip across the bottom — split label "X + Y" into two anchors
    if cob:
        sl_w = slide.part.package.presentation_part.presentation.slide_width
        sl_h = slide.part.package.presentation_part.presentation.slide_height
        # Background strip
        strip_h = Inches(0.85)
        strip_top = sl_h - strip_h
        strip = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, strip_top, sl_w, strip_h)
        strip.fill.solid()
        strip.fill.fore_color.rgb = RGBColor.from_string("10183A")
        strip.line.fill.background()
        strip.shadow.inherit = False
        # Split "FinOps Toolkit + Azure SRE Agent product team" by " + "
        parts = re.split(r"\s*\+\s*", cob, maxsplit=1)
        left_text = parts[0].strip() if parts else ""
        right_text = parts[1].strip() if len(parts) > 1 else ""

        # Left mark
        ltb = slide.shapes.add_textbox(Inches(0.7), strip_top, sl_w // 2 - Inches(0.7), strip_h)
        ltf = ltb.text_frame
        ltf.margin_left = ltf.margin_right = ltf.margin_top = ltf.margin_bottom = 0
        lp = ltf.paragraphs[0]
        lp.alignment = PP_ALIGN.LEFT
        lp_lbl = lp.add_run()
        lp_lbl.text = "Built by  "
        lp_lbl.font.size = Pt(10)
        lp_lbl.font.color.rgb = RGBColor.from_string("8FA0CC")
        lp_run = lp.add_run()
        lp_run.text = left_text
        lp_run.font.size = Pt(15)
        lp_run.font.bold = True
        lp_run.font.color.rgb = RGBColor.from_string("FFFFFF")
        # Vertical center
        from pptx.enum.text import MSO_ANCHOR
        ltf.vertical_anchor = MSO_ANCHOR.MIDDLE

        # Right mark
        rtb = slide.shapes.add_textbox(sl_w // 2, strip_top, sl_w // 2 - Inches(0.7), strip_h)
        rtf = rtb.text_frame
        rtf.margin_left = rtf.margin_right = rtf.margin_top = rtf.margin_bottom = 0
        rp = rtf.paragraphs[0]
        rp.alignment = PP_ALIGN.RIGHT
        rp_lbl = rp.add_run()
        rp_lbl.text = "In partnership with  "
        rp_lbl.font.size = Pt(10)
        rp_lbl.font.color.rgb = RGBColor.from_string("8FA0CC")
        rp_run = rp.add_run()
        rp_run.text = right_text
        rp_run.font.size = Pt(15)
        rp_run.font.bold = True
        rp_run.font.color.rgb = RGBColor.from_string("FFFFFF")
        rtf.vertical_anchor = MSO_ANCHOR.MIDDLE


def render_bullets(slide, row):
    if slide.shapes.title is not None:
        slide.shapes.title.text = row["title"]
        # If title is long, shrink the title font to keep it on one line
        if len(row["title"]) > 50:
            for para in slide.shapes.title.text_frame.paragraphs:
                for run in para.runs:
                    run.font.size = Pt(24)
    body = get_placeholder(slide, 10)
    if body is not None:
        body.left = Inches(0.64)
        body.top = Inches(1.2)
        body.width = Inches(12.05)
        body.height = Inches(5.7)
    paras = [_format_bullet_with_tools(b, size=20) for b in row["bullets"]]
    _set_text_frame_with_runs(body, paras)


def _draw_wheel(slide, cx, cy, r, hub_label="Improve\nthe agent", highlight=None):
    """Draw the lifecycle wheel: outer ring + 6 stage dots + center hub."""
    import math
    from pptx.enum.shapes import MSO_SHAPE
    stages = ["Forecast", "Procure", "Allocate", "Deploy", "Operate", "Optimize"]

    # Outer ring (light tint)
    ring = slide.shapes.add_shape(MSO_SHAPE.OVAL, cx - r, cy - r, r * 2, r * 2)
    ring.fill.solid()
    ring.fill.fore_color.rgb = RGBColor.from_string("F4F6FB")
    ring.line.color.rgb = RGBColor.from_string("D2D2D7")
    ring.line.width = Pt(0.75)
    ring.shadow.inherit = False

    # Inner hub
    hr = int(r * 0.32)
    hub = slide.shapes.add_shape(MSO_SHAPE.OVAL, cx - hr, cy - hr, hr * 2, hr * 2)
    hub.fill.solid()
    hub.fill.fore_color.rgb = RGBColor.from_string("1E2761")
    hub.line.fill.background()
    hub.shadow.inherit = False
    # Hub label
    htb = slide.shapes.add_textbox(cx - hr + Inches(0.05), cy - hr + Inches(0.1),
                                    hr * 2 - Inches(0.1), hr * 2 - Inches(0.2))
    htf = htb.text_frame
    htf.word_wrap = True
    for i, line in enumerate(hub_label.split("\n")):
        p = htf.paragraphs[0] if i == 0 else htf.add_paragraph()
        p.alignment = PP_ALIGN.CENTER
        run = p.add_run()
        run.text = line
        run.font.size = Pt(11)
        run.font.bold = True
        run.font.color.rgb = RGBColor.from_string("FFFFFF")

    # Stage dots on perimeter
    dot_r = Inches(0.22)
    for i, stage in enumerate(stages):
        ang = -math.pi / 2 + i * 2 * math.pi / len(stages)
        px = cx + int(math.cos(ang) * (r * 0.72))
        py = cy + int(math.sin(ang) * (r * 0.72))
        is_hi = highlight and (i + 1) == highlight
        dot = slide.shapes.add_shape(MSO_SHAPE.OVAL, px - dot_r, py - dot_r, dot_r * 2, dot_r * 2)
        dot.fill.solid()
        dot.fill.fore_color.rgb = RGBColor.from_string("0078D4" if is_hi else "FFFFFF")
        dot.line.color.rgb = RGBColor.from_string("0F6CBD")
        dot.line.width = Pt(1.5)
        dot.shadow.inherit = False
        # Number inside dot
        ntb = slide.shapes.add_textbox(px - dot_r, py - dot_r, dot_r * 2, dot_r * 2)
        ntf = ntb.text_frame
        np_ = ntf.paragraphs[0]
        np_.alignment = PP_ALIGN.CENTER
        nr = np_.add_run()
        nr.text = str(i + 1)
        nr.font.size = Pt(14)
        nr.font.bold = True
        nr.font.color.rgb = RGBColor.from_string("FFFFFF" if is_hi else "0F6CBD")
        # Label below dot
        lw = Inches(1.6)
        ltb = slide.shapes.add_textbox(px - lw // 2, py + dot_r + Inches(0.02), lw, Inches(0.4))
        ltf = ltb.text_frame
        lp = ltf.paragraphs[0]
        lp.alignment = PP_ALIGN.CENTER
        lr = lp.add_run()
        lr.text = stage
        lr.font.size = Pt(11)
        lr.font.bold = bool(is_hi)
        lr.font.color.rgb = RGBColor.from_string("0078D4" if is_hi else "1B1B1F")


def render_wheel_stats(slide, row):
    """Title + horizontal lifecycle wheel on the LEFT, component-counter strip on the RIGHT."""
    if slide.shapes.title is not None:
        slide.shapes.title.text = row["title"]
    _hide_layout_body_placeholders(slide, [10, 11, 13, 16, 17])

    sl_w = slide.part.package.presentation_part.presentation.slide_width
    sl_h = slide.part.package.presentation_part.presentation.slide_height

    # Wheel on left half
    wheel_cx = sl_w // 4
    wheel_cy = sl_h // 2 + Inches(0.3)
    wheel_r = Inches(2.2)
    _draw_wheel(slide, wheel_cx, wheel_cy, wheel_r)

    # Counter strip on right half
    body = list(row["bullets"])
    stat = None
    if body and re.search(r"\d+\s*[·•]\s*\d+", body[-1]):
        stat = body.pop()

    from pptx.enum.shapes import MSO_SHAPE
    right_x = sl_w // 2 + Inches(0.3)
    right_w = sl_w - right_x - Inches(0.7)
    body_top = Inches(2.0)

    # Body bullets in upper-right
    tb = slide.shapes.add_textbox(right_x, body_top, right_w, Inches(2.0))
    tf = tb.text_frame
    tf.word_wrap = True
    for i, b in enumerate(body):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.space_after = Pt(8)
        run = p.add_run()
        run.text = b
        run.font.size = Pt(16)
        run.font.color.rgb = RGBColor.from_string("1B1B1F")

    # Stat strip — 4 separate count cards
    if stat:
        # Parse "5 specialist subagents · 3 skills · 33 tools · 18 scheduled tasks."
        stat_clean = stat.rstrip(".")
        items = [s.strip() for s in re.split(r"\s*[·•]\s*", stat_clean) if s.strip()]
        n = len(items)
        if n > 0:
            strip_top = sl_h - Inches(2.0)
            strip_w = right_w
            strip_h = Inches(1.2)
            gap = Inches(0.15)
            card_w = (strip_w - gap * (n - 1)) // n
            for i, item in enumerate(items):
                # Split number from rest
                m = re.match(r"^(\d+)\s+(.+)$", item)
                if m:
                    num, label = m.group(1), m.group(2)
                else:
                    num, label = item, ""
                cx = right_x + i * (card_w + gap)
                card = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, cx, strip_top, card_w, strip_h)
                card.fill.solid()
                card.fill.fore_color.rgb = RGBColor.from_string("F7F7F9")
                card.line.color.rgb = RGBColor.from_string("E5E5EA")
                card.line.width = Pt(0.5)
                card.shadow.inherit = False
                ctb = slide.shapes.add_textbox(cx + Inches(0.1), strip_top + Inches(0.1),
                                                card_w - Inches(0.2), strip_h - Inches(0.2))
                ctf = ctb.text_frame
                ctf.word_wrap = True
                p1 = ctf.paragraphs[0]
                p1.alignment = PP_ALIGN.CENTER
                r1 = p1.add_run()
                r1.text = num
                r1.font.size = Pt(28)
                r1.font.bold = True
                r1.font.color.rgb = RGBColor.from_string("1F3864")
                if label:
                    p2 = ctf.add_paragraph()
                    p2.alignment = PP_ALIGN.CENTER
                    r2 = p2.add_run()
                    r2.text = label
                    r2.font.size = Pt(10)
                    r2.font.color.rgb = RGBColor.from_string("595959")


def render_wheel_large(slide, row):
    """Large centered wheel filling most of the slide."""
    if slide.shapes.title is not None:
        slide.shapes.title.text = row["title"]
    _hide_layout_body_placeholders(slide, [10, 11, 13, 16, 17])

    sl_w = slide.part.package.presentation_part.presentation.slide_width
    sl_h = slide.part.package.presentation_part.presentation.slide_height

    # Big centered wheel — sized so bottom stage label has clearance above tagline
    cx = sl_w // 2
    avail_top = Inches(1.4)
    avail_bottom = sl_h - Inches(1.4)  # leave space for tagline
    avail_h = avail_bottom - avail_top
    cy = avail_top + avail_h // 2
    # Constraint: cy + r*0.72 + 0.5" (label height) <= avail_bottom
    max_r_from_height = (avail_bottom - cy - Inches(0.5)) / 0.72
    max_r_from_width = (sl_w - 2 * Inches(2.0)) / 2  # 2" labels left/right
    r = int(min(max_r_from_height, max_r_from_width, Inches(2.4)))
    _draw_wheel(slide, cx, cy, r)

    # Tagline at bottom from last bullet
    body = list(row["bullets"])
    if body:
        tag = body[-1]
        tb = slide.shapes.add_textbox(Inches(0.7), sl_h - Inches(1.0),
                                       sl_w - Inches(1.4), Inches(0.5))
        tf = tb.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        p.alignment = PP_ALIGN.CENTER
        run = p.add_run()
        run.text = tag
        run.font.size = Pt(18)
        run.font.bold = True
        run.font.color.rgb = RGBColor.from_string("1E2761")


def render_section_twocol(slide, row):
    """Section divider with blue background band, centered anchor card, tagline footer."""
    from pptx.enum.shapes import MSO_SHAPE
    if slide.shapes.title is not None:
        slide.shapes.title.text = row["title"]
        for p in slide.shapes.title.text_frame.paragraphs:
            for run in p.runs:
                run.font.color.rgb = RGBColor.from_string("FFFFFF")

    _hide_layout_body_placeholders(slide, [11, 13, 16, 17])

    cap = find_prefixed(row["bullets"], ["Capacity question"]) or ""
    cost = find_prefixed(row["bullets"], ["Cost question"]) or ""
    tag = find_prefixed(row["bullets"], ["Tagline"]) or ""

    sl_w = slide.part.package.presentation_part.presentation.slide_width
    sl_h = slide.part.package.presentation_part.presentation.slide_height

    # Top dark band
    band = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, sl_w, Inches(1.5))
    band.fill.solid()
    band.fill.fore_color.rgb = RGBColor.from_string("1E2761")
    band.line.fill.background()
    spTree = band._element.getparent()
    spTree.remove(band._element)
    spTree.insert(2, band._element)

    margin_x = Inches(0.7)
    card_top = Inches(2.3)
    card_h = Inches(3.0)
    gap = Inches(0.4)
    avail_w = sl_w - 2 * margin_x
    card_w = (avail_w - gap) // 2

    def anchor_card(x, label, body, accent_hex):
        card = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, x, card_top, card_w, card_h)
        card.fill.solid()
        card.fill.fore_color.rgb = RGBColor.from_string("FFFFFF")
        card.line.color.rgb = RGBColor.from_string("E5E5EA")
        card.line.width = Pt(0.5)
        card.shadow.inherit = False
        accent = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, x, card_top, card_w, Inches(0.1))
        accent.fill.solid()
        accent.fill.fore_color.rgb = RGBColor.from_string(accent_hex)
        accent.line.fill.background()
        tb = slide.shapes.add_textbox(x + Inches(0.3), card_top + Inches(0.3), card_w - Inches(0.6), card_h - Inches(0.5))
        tf = tb.text_frame
        tf.word_wrap = True
        p1 = tf.paragraphs[0]
        r1 = p1.add_run()
        r1.text = label.upper()
        r1.font.size = Pt(12)
        r1.font.bold = True
        r1.font.color.rgb = RGBColor.from_string(accent_hex)
        p1.space_after = Pt(8)
        p2 = tf.add_paragraph()
        r2 = p2.add_run()
        r2.text = body
        r2.font.size = Pt(20)
        r2.font.color.rgb = RGBColor.from_string("1B1B1F")

    anchor_card(margin_x, "Capacity", cap, "1F3864")
    anchor_card(margin_x + card_w + gap, "Cost", cost, "9E2A2B")

    # Bottom area: layout intent banner if present, else tagline
    layout_intent = row.get("layout", "")
    banner_text = None
    m = re.search(r'"([^"]+v\d[^"]*)"', layout_intent)
    if m:
        banner_text = m.group(1)

    if banner_text:
        # Bold full-width banner at the bottom (e.g., v1=read+recommend+report)
        ban_top = sl_h - Inches(0.95)
        bn = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, ban_top, sl_w, Inches(0.55))
        bn.fill.solid()
        bn.fill.fore_color.rgb = RGBColor.from_string("10183A")
        bn.line.fill.background()
        bn.shadow.inherit = False
        btb = slide.shapes.add_textbox(margin_x, ban_top, sl_w - 2 * margin_x, Inches(0.55))
        btf = btb.text_frame
        btp = btf.paragraphs[0]
        btp.alignment = PP_ALIGN.CENTER
        btr = btp.add_run()
        btr.text = banner_text
        btr.font.size = Pt(13)
        btr.font.bold = True
        btr.font.color.rgb = RGBColor.from_string("FFFFFF")
        # tagline still rendered above banner if present
        if tag:
            tag_top = card_top + card_h + Inches(0.2)
            tb = slide.shapes.add_textbox(margin_x, tag_top, avail_w, Inches(0.5))
            tf = tb.text_frame
            tf.word_wrap = True
            p = tf.paragraphs[0]
            p.alignment = PP_ALIGN.CENTER
            run = p.add_run()
            run.text = tag
            run.font.size = Pt(15)
            run.font.italic = True
            run.font.color.rgb = RGBColor.from_string("404040")
    elif tag:
        tag_top = card_top + card_h + Inches(0.3)
        tb = slide.shapes.add_textbox(margin_x, tag_top, avail_w, Inches(0.6))
        tf = tb.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        p.alignment = PP_ALIGN.CENTER
        run = p.add_run()
        run.text = tag
        run.font.size = Pt(15)
        run.font.italic = True
        run.font.color.rgb = RGBColor.from_string("404040")


def render_section_headline(slide, row):
    """Section divider with title + canonical headline phrase as a subtitle textbox."""
    if slide.shapes.title is not None:
        slide.shapes.title.text = row["title"]

    headline = None
    for b in row["bullets"]:
        if "," in b and b.endswith("."):
            headline = b
            break
    if not headline and len(row["bullets"]) > 1:
        headline = row["bullets"][1]
    elif not headline and row["bullets"]:
        headline = row["bullets"][0]

    if headline:
        from pptx.enum.shapes import MSO_SHAPE
        sl_w = slide.part.package.presentation_part.presentation.slide_width
        sl_h = slide.part.package.presentation_part.presentation.slide_height
        # Background panel behind the headline so it's not crossed by layout decorations
        panel_top = Inches(3.8)
        panel_h = Inches(2.2)
        panel = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, panel_top, sl_w, panel_h)
        panel.fill.solid()
        panel.fill.fore_color.rgb = RGBColor.from_string("1E2761")
        panel.line.fill.background()
        panel.shadow.inherit = False

        tb_left = Inches(0.7)
        tb_top = panel_top + Inches(0.4)
        tb_w = sl_w - Inches(1.4)
        tb_h = panel_h - Inches(0.8)
        tb = slide.shapes.add_textbox(tb_left, tb_top, tb_w, tb_h)
        tf = tb.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        p.alignment = PP_ALIGN.CENTER
        run = p.add_run()
        run.text = headline
        run.font.size = Pt(40)
        run.font.bold = True
        run.font.color.rgb = RGBColor.from_string("FFFFFF")


def render_twoup_images(slide, row):
    if slide.shapes.title is not None:
        slide.shapes.title.text = row["title"]

    ph_lhdr = get_placeholder(slide, 16)
    ph_lbody = get_placeholder(slide, 11)
    ph_rhdr = get_placeholder(slide, 17)
    ph_rbody = get_placeholder(slide, 13)

    cap = find_prefixed(row["bullets"], ["Capacity"]) or ""
    cost = find_prefixed(row["bullets"], ["Cost"]) or ""
    combined = find_prefixed(row["bullets"], ["Combined answer", "Combined"]) or ""
    has_prefixes = bool(cap or cost)

    assets = row.get("assets", {})

    if has_prefixes:
        set_text_frame(ph_lhdr, [{"text": "Capacity", "size": 24, "bold": True, "color": "1F3864"}])
        set_text_frame(ph_rhdr, [{"text": "Cost", "size": 24, "bold": True, "color": "9E2A2B"}])
    else:
        set_text_frame(ph_lhdr, [{"text": ""}])
        set_text_frame(ph_rhdr, [{"text": ""}])

    if assets.get("left") and ph_lbody is not None:
        add_image_to_placeholder(slide, ph_lbody, assets["left"], None, None)
    if assets.get("right") and ph_rbody is not None:
        add_image_to_placeholder(slide, ph_rbody, assets["right"], None, None)

    if has_prefixes:
        cap_paras = [{"text": cap, "size": 18}]
        cost_paras = [{"text": cost, "size": 18}]
    else:
        bullets = row["bullets"]
        mid = (len(bullets) + 1) // 2
        cap_paras = [{"text": b, "size": 18} for b in bullets[:mid]]
        cost_paras = [{"text": b, "size": 18} for b in bullets[mid:]]

    # When images are present, render the body text as small captions BELOW
    # the image area (since the image occupies the placeholder).
    if assets.get("left") or assets.get("right"):
        # Draw caption strips beneath each image
        sl_w = slide.part.package.presentation_part.presentation.slide_width
        sl_h = slide.part.package.presentation_part.presentation.slide_height
        margin_x = Inches(0.7)
        cap_strip_top = sl_h - Inches(1.4)
        cap_strip_h = Inches(0.55)
        col_w = (sl_w - 2 * margin_x - Inches(0.4)) // 2
        # Left caption
        if cap_paras:
            ltb = slide.shapes.add_textbox(margin_x, cap_strip_top, col_w, cap_strip_h)
            ltf = ltb.text_frame
            ltf.word_wrap = True
            for i, para in enumerate(cap_paras):
                p = ltf.paragraphs[0] if i == 0 else ltf.add_paragraph()
                run = p.add_run()
                run.text = para["text"]
                run.font.size = Pt(11)
                run.font.color.rgb = RGBColor.from_string("404040")
        # Right caption
        if cost_paras:
            rx = margin_x + col_w + Inches(0.4)
            rtb = slide.shapes.add_textbox(rx, cap_strip_top, col_w, cap_strip_h)
            rtf = rtb.text_frame
            rtf.word_wrap = True
            for i, para in enumerate(cost_paras):
                p = rtf.paragraphs[0] if i == 0 else rtf.add_paragraph()
                run = p.add_run()
                run.text = para["text"]
                run.font.size = Pt(11)
                run.font.color.rgb = RGBColor.from_string("404040")
    else:
        if not assets.get("left"):
            set_text_frame(ph_lbody, cap_paras)
        if not assets.get("right"):
            set_text_frame(ph_rbody, cost_paras)

    # Combined answer = full-width footer banner across both columns
    if combined and not (assets.get("left") or assets.get("right")):
        from pptx.enum.shapes import MSO_SHAPE
        sl_w = slide.part.package.presentation_part.presentation.slide_width
        sl_h = slide.part.package.presentation_part.presentation.slide_height
        margin_x = Inches(0.7)
        ban_top = sl_h - Inches(1.3)
        ban_h = Inches(0.85)
        ban = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, margin_x, ban_top, sl_w - 2 * margin_x, ban_h)
        ban.fill.solid()
        ban.fill.fore_color.rgb = RGBColor.from_string("EAF3FB")
        ban.line.color.rgb = RGBColor.from_string("0F6CBD")
        ban.line.width = Pt(0.75)
        ban.shadow.inherit = False
        btb = slide.shapes.add_textbox(margin_x + Inches(0.3), ban_top, sl_w - 2 * margin_x - Inches(0.6), ban_h)
        btf = btb.text_frame
        btf.word_wrap = True
        from pptx.enum.text import MSO_ANCHOR
        btf.vertical_anchor = MSO_ANCHOR.MIDDLE
        bp = btf.paragraphs[0]
        b_label = bp.add_run()
        b_label.text = "Combined answer:  "
        b_label.font.size = Pt(13)
        b_label.font.bold = True
        b_label.font.color.rgb = RGBColor.from_string("0F6CBD")
        b_run = bp.add_run()
        b_run.text = combined
        b_run.font.size = Pt(14)
        b_run.font.color.rgb = RGBColor.from_string("1B1B1F")


def _draw_task_with_chip(slide, x, y, w, h, task_name, cadence, accent_hex):
    """Draw 'task-name' on the left and a colored cadence pill on the right of the row."""
    from pptx.enum.shapes import MSO_SHAPE
    chip_w = Inches(0.45)
    chip_h = Inches(0.28)
    chip_x = x + w - chip_w
    chip_y = y + (h - chip_h) // 2
    # Cadence pill
    if cadence:
        chip = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, chip_x, chip_y, chip_w, chip_h)
        chip.fill.solid()
        chip.fill.fore_color.rgb = RGBColor.from_string(accent_hex)
        chip.line.fill.background()
        chip.shadow.inherit = False
        chtb = slide.shapes.add_textbox(chip_x, chip_y, chip_w, chip_h)
        chtf = chtb.text_frame
        chtf.margin_left = chtf.margin_right = chtf.margin_top = chtf.margin_bottom = 0
        chp = chtf.paragraphs[0]
        chp.alignment = PP_ALIGN.CENTER
        chr_ = chp.add_run()
        chr_.text = cadence
        chr_.font.size = Pt(11)
        chr_.font.bold = True
        chr_.font.color.rgb = RGBColor.from_string("FFFFFF")
    # Task name on the left
    name_w = w - chip_w - Inches(0.1)
    ntb = slide.shapes.add_textbox(x, y, name_w, h)
    ntf = ntb.text_frame
    ntf.word_wrap = True
    np = ntf.paragraphs[0]
    nr = np.add_run()
    nr.text = task_name
    nr.font.size = Pt(15)
    nr.font.color.rgb = RGBColor.from_string("1B1B1F")


def render_twocol_lists(slide, row):
    """Draw two columns of tasks, with each task as 'name' + cadence chip badge."""
    if slide.shapes.title is not None:
        slide.shapes.title.text = row["title"]
    _hide_layout_body_placeholders(slide, [11, 13, 16, 17])

    cap = None
    cost = None
    other = []
    for b in row["bullets"]:
        label, body = split_label(b)
        if label and label.lower().startswith("capacity"):
            cap = body
        elif label and label.lower().startswith("cost"):
            cost = body
        else:
            other.append(b)

    def split_tasks(s):
        if not s:
            return []
        s = s.rstrip(".")
        items = []
        depth = 0
        buf = ""
        for ch in s:
            if ch == "(":
                depth += 1
                buf += ch
            elif ch == ")":
                depth -= 1
                buf += ch
            elif ch == "," and depth == 0:
                if buf.strip():
                    items.append(buf.strip())
                buf = ""
            else:
                buf += ch
        if buf.strip():
            items.append(buf.strip())
        return items

    def parse_task(item):
        # 'task-name (cadence-letter[, more])' → ('task-name', 'cadence-letter')
        m = re.match(r"^(.+?)\s*\(([^)]+)\)\s*$", item)
        if m:
            cad_text = m.group(2).strip()
            # Take first token before comma if there are flags (e.g., "D, gate mode")
            cad_letter = cad_text.split(",")[0].strip().upper()
            # Only treat as cadence if it's D/W/M/Q
            if cad_letter in ("D", "W", "M", "Q"):
                return m.group(1).strip(), cad_letter
        return item.strip(), ""

    cap_tasks = [parse_task(t) for t in split_tasks(cap)]
    cost_tasks = [parse_task(t) for t in split_tasks(cost)]

    sl_w = slide.part.package.presentation_part.presentation.slide_width
    sl_h = slide.part.package.presentation_part.presentation.slide_height
    margin_x = Inches(0.7)
    col_top = Inches(1.6)
    col_h = sl_h - col_top - Inches(1.2)
    avail_w = sl_w - 2 * margin_x
    gap = Inches(0.4)
    col_w = (avail_w - gap) // 2

    # Column header text
    hdr_h = Inches(0.5)
    def col_header(x, label, color_hex):
        tb = slide.shapes.add_textbox(x, col_top, col_w, hdr_h)
        tf = tb.text_frame
        p = tf.paragraphs[0]
        run = p.add_run()
        run.text = label
        run.font.size = Pt(20)
        run.font.bold = True
        run.font.color.rgb = RGBColor.from_string(color_hex)

    col_header(margin_x, "Capacity tasks", "1F3864")
    col_header(margin_x + col_w + gap, "Cost tasks", "9E2A2B")

    row_h = Inches(0.45)
    row_gap = Inches(0.12)
    list_top = col_top + hdr_h + Inches(0.1)

    for i, (name, cad) in enumerate(cap_tasks):
        y = list_top + i * (row_h + row_gap)
        _draw_task_with_chip(slide, margin_x, y, col_w, row_h, name, cad, "1F3864")

    for i, (name, cad) in enumerate(cost_tasks):
        y = list_top + i * (row_h + row_gap)
        _draw_task_with_chip(slide, margin_x + col_w + gap, y, col_w, row_h, name, cad, "9E2A2B")

    # If left col was empty (e.g., gap row 3.3), show the gap callout in left
    if not cap_tasks and other:
        callout_y = list_top
        cb = slide.shapes.add_textbox(margin_x, callout_y, col_w, Inches(1.0))
        cbf = cb.text_frame
        cbf.word_wrap = True
        cp = cbf.paragraphs[0]
        crun = cp.add_run()
        crun.text = "(gap — see Stage 7)"
        crun.font.size = Pt(13)
        crun.font.italic = True
        crun.font.color.rgb = RGBColor.from_string("9E2A2B")

    # Right column gap-callout if missing
    if not cost_tasks:
        # Use the cost label body itself if present
        if cost:
            cb = slide.shapes.add_textbox(margin_x + col_w + gap, list_top, col_w, Inches(1.5))
            cbf = cb.text_frame
            cbf.word_wrap = True
            cp = cbf.paragraphs[0]
            crun = cp.add_run()
            crun.text = cost
            crun.font.size = Pt(14)
            crun.font.color.rgb = RGBColor.from_string("1B1B1F")

    # Footer (other lines) — full-width muted italic
    if other:
        ft_top = sl_h - Inches(1.05)
        ftb = slide.shapes.add_textbox(margin_x, ft_top, avail_w, Inches(0.6))
        ftf = ftb.text_frame
        ftf.word_wrap = True
        for i, o in enumerate(other):
            p = ftf.paragraphs[0] if i == 0 else ftf.add_paragraph()
            p.alignment = PP_ALIGN.CENTER
            run = p.add_run()
            run.text = o
            run.font.size = Pt(12)
            run.font.italic = True
            run.font.color.rgb = RGBColor.from_string("595959")


def _draw_card(slide, x, y, w, h, label, body, accent_color="1F3864"):
    """Draw a single card: rectangle with bold label header + body text inside."""
    from pptx.enum.shapes import MSO_SHAPE
    # Card body
    card = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, x, y, w, h)
    card.fill.solid()
    card.fill.fore_color.rgb = RGBColor.from_string("F7F7F9")
    card.line.color.rgb = RGBColor.from_string("E5E5EA")
    card.line.width = Pt(0.75)
    card.shadow.inherit = False
    # Top accent strip
    accent = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, x, y, w, Inches(0.08))
    accent.fill.solid()
    accent.fill.fore_color.rgb = RGBColor.from_string(accent_color)
    accent.line.fill.background()
    # Text inside the card
    tb = slide.shapes.add_textbox(x + Inches(0.2), y + Inches(0.18), w - Inches(0.4), h - Inches(0.3))
    tf = tb.text_frame
    tf.word_wrap = True
    if label:
        p1 = tf.paragraphs[0]
        run1 = p1.add_run()
        run1.text = label
        run1.font.size = Pt(15)
        run1.font.bold = True
        run1.font.color.rgb = RGBColor.from_string(accent_color)
        if body:
            p2 = tf.add_paragraph()
            p2.space_before = Pt(8)
            run2 = p2.add_run()
            run2.text = body
            run2.font.size = Pt(13)
            run2.font.color.rgb = RGBColor.from_string("1B1B1F")
    else:
        p1 = tf.paragraphs[0]
        run1 = p1.add_run()
        run1.text = body or ""
        run1.font.size = Pt(13)
        run1.font.color.rgb = RGBColor.from_string("1B1B1F")


def _hide_layout_body_placeholders(slide, placeholder_indices):
    """Clear text from layout placeholders we want to override with drawn shapes."""
    for idx in placeholder_indices:
        ph = get_placeholder(slide, idx)
        if ph is not None and ph.has_text_frame:
            ph.text_frame.clear()


def render_cards_n(slide, row, n):
    if slide.shapes.title is not None:
        slide.shapes.title.text = row["title"]

    # Hide any layout body placeholders so the drawn cards are the only body content
    _hide_layout_body_placeholders(slide, [10, 11, 13, 16, 17])

    cards = row["bullets"][:n]
    extras = row["bullets"][n:]

    # Card colors (capacity blue, cost terracotta, neutral gold)
    PALETTE = ["1F3864", "9E2A2B", "C58F00", "00606A"]

    # Slide canvas
    sl_w = slide.part.package.presentation_part.presentation.slide_width
    sl_h = slide.part.package.presentation_part.presentation.slide_height

    # Card grid math
    margin_x = Inches(0.7)
    top = Inches(2.0)
    bottom = sl_h - Inches(1.2)
    grid_w = sl_w - 2 * margin_x
    grid_h = bottom - top
    gap = Inches(0.25)

    if n <= 3:
        # single row of n cards
        rows, cols = 1, n
    else:
        # 2x2 for n==4
        rows, cols = 2, 2

    card_w = (grid_w - gap * (cols - 1)) // cols
    card_h = (grid_h - gap * (rows - 1)) // rows

    for i, c in enumerate(cards):
        label, body = split_label(c)
        if not label:
            label, body = "", c
        col = i % cols
        rw = i // cols
        x = margin_x + col * (card_w + gap)
        y = top + rw * (card_h + gap)
        accent = PALETTE[i % len(PALETTE)]
        _draw_card(slide, x, y, card_w, card_h, label, body, accent)

    # Extras → footer line below the cards
    if extras:
        footer_top = bottom + Inches(0.05)
        tb = slide.shapes.add_textbox(margin_x, footer_top, grid_w, Inches(0.5))
        tf = tb.text_frame
        tf.word_wrap = True
        for i, ex in enumerate(extras):
            p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
            p.alignment = PP_ALIGN.CENTER
            run = p.add_run()
            run.text = ex
            run.font.size = Pt(12)
            run.font.italic = True
            run.font.color.rgb = RGBColor.from_string("595959")


def _draw_table(slide, x, y, w, h, headers, rows, col_widths=None,
                tone_for_row=None, header_fill="1F3864", header_color="FFFFFF"):
    """Draw a table with styled header + alternating tone rows.

    headers: list of column header strings
    rows: list of row tuples (each tuple has len(headers) cells)
    col_widths: optional list of relative weights for column widths
    tone_for_row: optional callable (row_index, row_data) -> hex color | None
    """
    from pptx.util import Emu
    n_cols = len(headers)
    n_rows = len(rows) + 1  # +1 for header
    table_shape = slide.shapes.add_table(n_rows, n_cols, x, y, w, h)
    table = table_shape.table

    # Column widths
    if col_widths is not None and len(col_widths) == n_cols:
        total = sum(col_widths)
        for i, weight in enumerate(col_widths):
            table.columns[i].width = Emu(int(w * weight / total))

    # Header row
    for ci, hdr in enumerate(headers):
        cell = table.cell(0, ci)
        cell.text = ""
        cell.fill.solid()
        cell.fill.fore_color.rgb = RGBColor.from_string(header_fill)
        tf = cell.text_frame
        p = tf.paragraphs[0]
        run = p.add_run()
        run.text = hdr
        run.font.bold = True
        run.font.size = Pt(13)
        run.font.color.rgb = RGBColor.from_string(header_color)

    # Body rows
    for ri, row_data in enumerate(rows, start=1):
        tone = tone_for_row(ri - 1, row_data) if tone_for_row else None
        for ci, val in enumerate(row_data):
            cell = table.cell(ri, ci)
            cell.text = ""
            if tone:
                cell.fill.solid()
                cell.fill.fore_color.rgb = RGBColor.from_string(tone)
            tf = cell.text_frame
            p = tf.paragraphs[0]
            run = p.add_run()
            run.text = val
            run.font.size = Pt(11)
            run.font.color.rgb = RGBColor.from_string("1B1B1F")


def render_table(slide, row):
    if slide.shapes.title is not None:
        slide.shapes.title.text = row["title"]

    _hide_layout_body_placeholders(slide, [10, 11, 13, 16, 17])

    sl_w = slide.part.package.presentation_part.presentation.slide_width
    sl_h = slide.part.package.presentation_part.presentation.slide_height
    margin_x = Inches(0.7)
    table_x = margin_x
    table_y = Inches(1.7)
    table_w = sl_w - 2 * margin_x

    bullets = row["bullets"]
    num = row.get("num", "")

    if num == "4.2":
        # 8-check gate table — extract " (capacity)" / " (cost)" tone tag from each bullet
        headers = ["Check", "Side"]
        rows_data = []
        def parse_check(b):
            m = re.match(r"^(.+?)\s*\(((?:capacity|cost))\)\s*$", b)
            if m:
                return m.group(1).strip(), m.group(2).capitalize()
            return b, ""
        for b in bullets:
            rows_data.append(parse_check(b))
        def tone(ri, rd):
            if rd[1] == "Capacity":
                return "EAF3FB"
            elif rd[1] == "Cost":
                return "F8ECEA"
            return None
        _draw_table(slide, table_x, table_y, table_w, sl_h - table_y - Inches(0.8),
                    headers, rows_data, col_widths=[3, 1], tone_for_row=tone)

    elif num in ("A.2", "A.3", "A.4"):
        # bullets are rows; use first bullet as label / second-onward as cells (split by ":" or " · ")
        # Simpler: each bullet is one row, split into key/value at first colon
        rows_data = []
        for b in bullets:
            # Split on first colon → 2-column table
            parts = b.split(": ", 1)
            if len(parts) == 2:
                rows_data.append((parts[0], parts[1]))
            else:
                rows_data.append((b, ""))
        headers = ["Item", "Detail"]
        if num == "A.2":
            headers = ["Approach", "Detail"]
        elif num == "A.3":
            headers = ["Component", "Cost basis"]
        elif num == "A.4":
            headers = ["Estate band", "Annual cost & payback"]
        _draw_table(slide, table_x, table_y, table_w, sl_h - table_y - Inches(0.8),
                    headers, rows_data, col_widths=[2, 5])

    else:
        # Fallback: use add_table with 1 col
        rows_data = [(b,) for b in bullets]
        _draw_table(slide, table_x, table_y, table_w, sl_h - table_y - Inches(0.8),
                    ["Item"], rows_data)


def render_matrix(slide, row):
    """6×3 matrix: lifecycle stages (cols) × FinOps phases (rows). Shaded dominance cells."""
    if slide.shapes.title is not None:
        slide.shapes.title.text = row["title"]
    _hide_layout_body_placeholders(slide, [10, 11, 13, 16, 17])

    sl_w = slide.part.package.presentation_part.presentation.slide_width
    sl_h = slide.part.package.presentation_part.presentation.slide_height
    margin_x = Inches(0.7)

    stages = ["Forecast", "Procure", "Allocate", "Deploy", "Operate", "Optimize"]
    phases = ["Inform", "Optimize", "Operate"]
    dominance = {p: set() for p in phases}
    text_blob = " ".join(row["bullets"])
    for m in re.finditer(r"(\w+)\s+dominates\s+([^.]+?)\.", text_blob):
        phase = m.group(1)
        if phase not in phases:
            continue
        stage_text = m.group(2)
        for word in re.split(r"\s+and\s+|,\s*", stage_text):
            w = word.strip()
            if w in stages:
                dominance.setdefault(phase, set()).add(w)

    # Disambiguated phase row labels — clarify phases vs lifecycle stages
    phase_labels = {
        "Inform":   "FinOps Inform",
        "Optimize": "FinOps Optimize",
        "Operate":  "FinOps Operate",
    }
    headers = ["FinOps Framework phase →"] + stages
    rows_data = []
    dominance_marks = []
    for phase in phases:
        rd = [phase_labels[phase]]
        marks = [False]
        for stage in stages:
            is_dom = stage in dominance.get(phase, set())
            rd.append("Primary" if is_dom else "in scope")
            marks.append(is_dom)
        rows_data.append(tuple(rd))
        dominance_marks.append(marks)

    table_x = margin_x
    table_y = Inches(1.7)
    table_w = sl_w - 2 * margin_x
    table_h = Inches(3.6)

    _draw_table(slide, table_x, table_y, table_w, table_h,
                headers, rows_data,
                col_widths=[2.8, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5])

    # Find the table we just drew
    table_shape = None
    for sh in slide.shapes:
        if sh.has_table:
            table_shape = sh
    if table_shape is not None:
        tbl = table_shape.table
        # Force every body cell to white background (no zebra) and consistent text styling
        for ri in range(1, len(rows_data) + 1):
            for ci in range(len(headers)):
                cell = tbl.cell(ri, ci)
                cell.fill.solid()
                cell.fill.fore_color.rgb = RGBColor.from_string("FFFFFF")
        # Apply dominance shading + bold white text on top
        for ri, marks in enumerate(dominance_marks, start=1):
            for ci, is_dom in enumerate(marks):
                cell = tbl.cell(ri, ci)
                if is_dom:
                    cell.fill.solid()
                    cell.fill.fore_color.rgb = RGBColor.from_string("0078D4")
                    for p in cell.text_frame.paragraphs:
                        for run in p.runs:
                            run.font.color.rgb = RGBColor.from_string("FFFFFF")
                            run.font.bold = True
                            run.font.size = Pt(12)
                elif ci == 0:
                    # Phase label column — bold dark
                    for p in cell.text_frame.paragraphs:
                        for run in p.runs:
                            run.font.color.rgb = RGBColor.from_string("1B1B1F")
                            run.font.bold = True
                            run.font.size = Pt(13)
                else:
                    # "in scope" cells — quieter grey
                    for p in cell.text_frame.paragraphs:
                        for run in p.runs:
                            run.font.color.rgb = RGBColor.from_string("8E8E93")
                            run.font.italic = True
                            run.font.size = Pt(10)

    # Two-line legend explaining what Primary vs in scope mean
    leg_top = table_y + table_h + Inches(0.3)
    leg = slide.shapes.add_textbox(margin_x, leg_top, table_w, Inches(1.2))
    tf = leg.text_frame
    tf.word_wrap = True
    p1 = tf.paragraphs[0]
    p1.alignment = PP_ALIGN.CENTER
    r1a = p1.add_run()
    r1a.text = "Primary"
    r1a.font.size = Pt(13)
    r1a.font.bold = True
    r1a.font.color.rgb = RGBColor.from_string("0078D4")
    r1b = p1.add_run()
    r1b.text = " — the FinOps Framework phase that drives the work at this lifecycle stage."
    r1b.font.size = Pt(13)
    r1b.font.color.rgb = RGBColor.from_string("1B1B1F")

    p2 = tf.add_paragraph()
    p2.alignment = PP_ALIGN.CENTER
    p2.space_before = Pt(6)
    r2a = p2.add_run()
    r2a.text = "in scope"
    r2a.font.size = Pt(13)
    r2a.font.italic = True
    r2a.font.color.rgb = RGBColor.from_string("8E8E93")
    r2b = p2.add_run()
    r2b.text = " — phase still applies, but it isn't the primary lens at this stage. Every cell is in play."
    r2b.font.size = Pt(13)
    r2b.font.color.rgb = RGBColor.from_string("1B1B1F")


def render_three_block(slide, row):
    """Three horizontal rectangle blocks: Customer prompt → Agent → Data sources, plus RBAC sub-block + image."""
    from pptx.enum.shapes import MSO_SHAPE
    if slide.shapes.title is not None:
        slide.shapes.title.text = row["title"]
    _hide_layout_body_placeholders(slide, [10, 11, 13, 16, 17])

    sl_w = slide.part.package.presentation_part.presentation.slide_width
    sl_h = slide.part.package.presentation_part.presentation.slide_height
    margin_x = Inches(0.7)

    # Three blocks across the top
    blocks = [
        ("Customer prompt or schedule", "Teams · CLI · cron"),
        ("Agent in customer subscription", "5 specialists · 33 tools · 18 tasks"),
        ("Two data sources", "FinOps hub ADX · Azure control plane"),
    ]
    block_top = Inches(1.5)
    block_h = Inches(1.4)
    arrow_w = Inches(0.4)
    avail_w = sl_w - 2 * margin_x - arrow_w * (len(blocks) - 1)
    block_w = avail_w // len(blocks)

    for i, (label, body) in enumerate(blocks):
        x = margin_x + i * (block_w + arrow_w)
        rect = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, x, block_top, block_w, block_h)
        rect.fill.solid()
        rect.fill.fore_color.rgb = RGBColor.from_string("1E2761")
        rect.line.fill.background()
        rect.shadow.inherit = False
        tb = slide.shapes.add_textbox(x + Inches(0.2), block_top + Inches(0.2),
                                       block_w - Inches(0.4), block_h - Inches(0.4))
        tf = tb.text_frame
        tf.word_wrap = True
        p1 = tf.paragraphs[0]
        r1 = p1.add_run()
        r1.text = label
        r1.font.size = Pt(14)
        r1.font.bold = True
        r1.font.color.rgb = RGBColor.from_string("FFFFFF")
        p2 = tf.add_paragraph()
        p2.space_before = Pt(6)
        r2 = p2.add_run()
        r2.text = body
        r2.font.size = Pt(11)
        r2.font.color.rgb = RGBColor.from_string("BCC8E0")
        # Arrow between blocks
        if i < len(blocks) - 1:
            arr_x = x + block_w + Inches(0.05)
            arr_y = block_top + block_h // 2 - Inches(0.1)
            arr = slide.shapes.add_shape(MSO_SHAPE.RIGHT_ARROW, arr_x, arr_y, arrow_w - Inches(0.1), Inches(0.2))
            arr.fill.solid()
            arr.fill.fore_color.rgb = RGBColor.from_string("5C5C66")
            arr.line.fill.background()
            arr.shadow.inherit = False

    # RBAC sub-block beneath
    rbac_top = block_top + block_h + Inches(0.4)
    rbac = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, margin_x, rbac_top,
                                   sl_w - 2 * margin_x, Inches(2.0))
    rbac.fill.solid()
    rbac.fill.fore_color.rgb = RGBColor.from_string("F7F7F9")
    rbac.line.color.rgb = RGBColor.from_string("E5E5EA")
    rbac.line.width = Pt(0.5)
    rbac.shadow.inherit = False

    rtb = slide.shapes.add_textbox(margin_x + Inches(0.3), rbac_top + Inches(0.15),
                                    sl_w - 2 * margin_x - Inches(0.6), Inches(1.7))
    rtf = rtb.text_frame
    rtf.word_wrap = True
    rp = rtf.paragraphs[0]
    rr = rp.add_run()
    rr.text = "RBAC · v1 read-only"
    rr.font.size = Pt(13)
    rr.font.bold = True
    rr.font.color.rgb = RGBColor.from_string("1E2761")
    rp.space_after = Pt(6)
    for b in row["bullets"]:
        if "RBAC" in b or "managed identity" in b.lower():
            # use this as the body
            rp2 = rtf.add_paragraph()
            rr2 = rp2.add_run()
            rr2.text = b
            rr2.font.size = Pt(11)
            rr2.font.color.rgb = RGBColor.from_string("1B1B1F")
            break

    # Embed image if asset directive is present
    assets = row.get("assets", {})
    if assets.get("image"):
        img_path = ASSETS / assets["image"]
        if img_path.suffix.lower() == ".svg":
            png_path = img_path.with_suffix(".rasterized.png")
            if not png_path.exists():
                import subprocess
                subprocess.run(["rsvg-convert", "-w", "1600", "-o", str(png_path), str(img_path)], check=True)
            img_path = png_path
        img_w = Inches(4.5)
        img_h = Inches(2.5)
        img_left = sl_w - img_w - Inches(0.5)
        img_top = sl_h - img_h - Inches(0.7)
        try:
            slide.shapes.add_picture(str(img_path), img_left, img_top, width=img_w, height=img_h)
        except Exception as e:
            print(f"   ! image embed failed: {e}")


# ─── Footer chip: ask-coverage pill at slide bottom ──────────

def render_footer_chip(slide, row):
    """Render the ask-coverage footer chip at the bottom of a body slide."""
    addresses = row.get("addresses", [])
    verdict = row.get("verdict")
    if not addresses or not verdict:
        return

    from pptx.enum.shapes import MSO_SHAPE
    from pptx.enum.text import MSO_ANCHOR

    sl_w = slide.part.package.presentation_part.presentation.slide_width
    sl_h = slide.part.package.presentation_part.presentation.slide_height

    colors = VERDICT_COLORS.get(verdict, VERDICT_COLORS["green"])
    text_hex, bg_hex = colors

    ask_text = "Asks #" + ", #".join(str(a) for a in addresses)
    verdict_emoji = {"green": "🟢", "yellow": "🟡", "red": "🔴"}.get(verdict, "")
    chip_text = f"{verdict_emoji} {ask_text}"

    chip_w = Inches(3.5)
    chip_h = Inches(0.32)
    chip_x = sl_w - chip_w - Inches(0.4)
    chip_y = sl_h - chip_h - Inches(0.15)

    pill = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, chip_x, chip_y, chip_w, chip_h)
    pill.fill.solid()
    pill.fill.fore_color.rgb = RGBColor.from_string(bg_hex)
    pill.line.color.rgb = RGBColor.from_string(text_hex)
    pill.line.width = Pt(0.75)
    pill.shadow.inherit = False

    tb = slide.shapes.add_textbox(chip_x, chip_y, chip_w, chip_h)
    tf = tb.text_frame
    tf.margin_left = tf.margin_right = Inches(0.1)
    tf.margin_top = tf.margin_bottom = 0
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    p = tf.paragraphs[0]
    p.alignment = PP_ALIGN.CENTER
    run = p.add_run()
    run.text = chip_text
    run.font.size = Pt(10)
    run.font.bold = True
    run.font.color.rgb = RGBColor.from_string(text_hex)


def render_cluster_chyron(slide, row, top=Inches(1.05)):
    """Render the cluster name as an uppercase blue chyron above body content.

    Matches the editorial signature established by render_ask_a:
    - Cluster name in blue uppercase, small bold
    - Used on ASK_A, ASK_B, ASK_C for visual consistency across the cluster's 3 slides
    """
    cluster = row.get("stage", "").strip()
    if not cluster:
        return

    sl_w = slide.part.package.presentation_part.presentation.slide_width
    margin_x = Inches(0.7)

    label_tb = slide.shapes.add_textbox(margin_x, top, sl_w - 2 * margin_x, Inches(0.35))
    ltf = label_tb.text_frame
    ltf.word_wrap = True
    ltf.margin_left = ltf.margin_right = 0
    ltf.margin_top = ltf.margin_bottom = 0
    lp = ltf.paragraphs[0]
    lr = lp.add_run()
    lr.text = cluster.upper()
    lr.font.size = Pt(11)
    lr.font.bold = True
    lr.font.color.rgb = RGBColor.from_string("0F6CBD")


def render_accent_rule(slide, top=Inches(1.45), height=Inches(5.6)):
    """Render the vertical blue accent rule on the left edge of the body content."""
    from pptx.enum.shapes import MSO_SHAPE
    margin_x = Inches(0.7)
    rule = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE,
                                   margin_x, top,
                                   Inches(0.06), height)
    rule.fill.solid()
    rule.fill.fore_color.rgb = RGBColor.from_string("0F6CBD")
    rule.line.fill.background()
    rule.shadow.inherit = False


# ─── ASK_A renderer: editorial pull-quote treatment ──────────

def render_ask_a(slide, row):
    """ASK slide: professional MCAPS pull-quote design.

    Title at top. Large italic quote(s) centered vertically with a left blue
    accent rule. Cluster name as a small label above the quote (chyron style).
    Footer chip stays. Removes default body placeholder; uses custom textboxes
    for full layout control.
    """
    from pptx.enum.shapes import MSO_SHAPE
    from pptx.enum.text import MSO_ANCHOR

    if slide.shapes.title is not None:
        slide.shapes.title.text = row["title"]
        if len(row["title"]) > 50:
            for para in slide.shapes.title.text_frame.paragraphs:
                for run in para.runs:
                    run.font.size = Pt(24)

    # Hide the default body placeholder — we draw our own pull-quote layout
    body_ph = get_placeholder(slide, 10)
    if body_ph is not None:
        sp = body_ph._element
        sp.getparent().remove(sp)

    # Separate quotes from attribution
    quotes = []
    attrib = []
    for b in row["bullets"]:
        if b.startswith(">") or b.startswith('"') or b.startswith("\u201c"):
            clean = b.lstrip("> ").strip('" \u201c\u201d')
            quotes.append(clean)
        else:
            attrib.append(b)
    if not quotes:
        quotes = row["bullets"][:2]
        attrib = row["bullets"][2:]

    # Limit to top 2 quotes for visual focus
    quotes = quotes[:2]

    # Adaptive font size based on combined quote length
    total_chars = sum(len(q) for q in quotes)
    if total_chars < 80:
        qsize = 36
    elif total_chars < 160:
        qsize = 30
    elif total_chars < 280:
        qsize = 24
    else:
        qsize = 20

    sl_w = slide.part.package.presentation_part.presentation.slide_width
    sl_h = slide.part.package.presentation_part.presentation.slide_height

    # Layout geometry: pull-quote centered, left accent rule
    margin_x = Inches(1.2)
    quote_left = margin_x + Inches(0.5)
    quote_w = sl_w - quote_left - Inches(1.2)

    # Quote occupies the middle band — vertically centered
    quote_top = Inches(2.2)
    quote_h = Inches(3.5)

    # Left accent rule (vertical blue bar)
    rule = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE,
                                   margin_x, quote_top + Inches(0.2),
                                   Inches(0.06), quote_h - Inches(0.4))
    rule.fill.solid()
    rule.fill.fore_color.rgb = RGBColor.from_string("0F6CBD")
    rule.line.fill.background()
    rule.shadow.inherit = False

    # Cluster name label — small chyron above the quote (uppercase, light)
    cluster = row.get("stage", "").strip()
    if cluster:
        label_tb = slide.shapes.add_textbox(quote_left, Inches(1.7), quote_w, Inches(0.35))
        ltf = label_tb.text_frame
        ltf.word_wrap = True
        ltf.margin_left = ltf.margin_right = 0
        lp = ltf.paragraphs[0]
        lr = lp.add_run()
        lr.text = cluster.upper()
        lr.font.size = Pt(11)
        lr.font.bold = True
        lr.font.color.rgb = RGBColor.from_string("0F6CBD")

    # Quote text — italic, large, vertically centered in the band
    qtb = slide.shapes.add_textbox(quote_left, quote_top, quote_w, quote_h)
    qtf = qtb.text_frame
    qtf.word_wrap = True
    qtf.vertical_anchor = MSO_ANCHOR.MIDDLE
    qtf.margin_left = qtf.margin_right = Inches(0.1)
    qtf.margin_top = qtf.margin_bottom = 0

    for i, q in enumerate(quotes):
        p = qtf.paragraphs[0] if i == 0 else qtf.add_paragraph()
        p.space_after = Pt(qsize // 2)
        run = p.add_run()
        run.text = f"\u201c{q}\u201d"
        run.font.size = Pt(qsize)
        run.font.italic = True
        run.font.color.rgb = RGBColor.from_string("1B1B1F")

    # Attribution line below the quote (small, muted)
    if attrib:
        atb = slide.shapes.add_textbox(quote_left, quote_top + quote_h + Inches(0.1),
                                        quote_w, Inches(0.4))
        atf = atb.text_frame
        atf.word_wrap = True
        ap = atf.paragraphs[0]
        ar = ap.add_run()
        ar.text = f"— {attrib[0]}"
        ar.font.size = Pt(13)
        ar.font.color.rgb = RGBColor.from_string("595959")

    render_footer_chip(slide, row)


# ─── ASK_B renderer: editorial answer treatment ──────────────

def render_ask_b(slide, row):
    """SHOW slide: matches the editorial design language.

    Cluster chyron at top, blue accent rule on left, answer text (left ~40%)
    with bolded tool names, chart panel (right ~55%) with subtle border.
    """
    from pptx.enum.shapes import MSO_SHAPE
    from pptx.enum.text import MSO_ANCHOR

    if slide.shapes.title is not None:
        slide.shapes.title.text = row["title"]
        if len(row["title"]) > 50:
            for para in slide.shapes.title.text_frame.paragraphs:
                for run in para.runs:
                    run.font.size = Pt(24)

    # Remove default body placeholder — we draw a custom two-column layout
    body_ph = get_placeholder(slide, 10)
    if body_ph is not None:
        sp = body_ph._element
        sp.getparent().remove(sp)

    # Cluster chyron + accent rule (matches ASK_A and ASK_C signature)
    render_cluster_chyron(slide, row, top=Inches(1.05))
    render_accent_rule(slide, top=Inches(1.45), height=Inches(5.4))

    sl_w = slide.part.package.presentation_part.presentation.slide_width
    sl_h = slide.part.package.presentation_part.presentation.slide_height

    # Layout geometry: text left (~38%), chart right (~58%)
    content_top = Inches(1.45)
    content_h = Inches(5.4)

    text_left = Inches(1.0)
    text_w = Inches(4.6)

    chart_left = text_left + text_w + Inches(0.3)
    chart_w = sl_w - chart_left - Inches(0.7)

    # Answer text: bullets with tool-name bolding
    ttb = slide.shapes.add_textbox(text_left, content_top, text_w, content_h)
    ttf = ttb.text_frame
    ttf.word_wrap = True
    ttf.margin_left = ttf.margin_right = 0
    ttf.margin_top = Inches(0.1)

    bullets = row["bullets"][:5]
    for i, b in enumerate(bullets):
        p = ttf.paragraphs[0] if i == 0 else ttf.add_paragraph()
        p.space_after = Pt(8)
        para_data = _format_bullet_with_tools(b, size=14)
        for r in list(p.runs):
            r.text = ""
        for run_data in para_data["runs"]:
            run = p.add_run()
            run.text = run_data.get("text", "") or ""
            font = run.font
            if run_data.get("size"):
                font.size = Pt(run_data["size"])
            if run_data.get("bold"):
                font.bold = True
            if run_data.get("color"):
                font.color.rgb = RGBColor.from_string(run_data["color"])

    # Chart panel: subtle border around the image
    assets = row.get("assets", {})
    img_file = assets.get("image")
    has_chart = False

    if img_file:
        img_path = CHARTS / img_file
        if not img_path.exists():
            img_path = ASSETS / img_file
        if img_path.exists():
            if img_path.suffix.lower() == ".svg":
                png_path = img_path.with_suffix(".rasterized.png")
                if not png_path.exists():
                    import subprocess
                    subprocess.run(["rsvg-convert", "-w", "1600", "-o", str(png_path), str(img_path)], check=True)
                img_path = png_path

            # Read actual image dimensions and compute fitted size with aspect preservation
            try:
                from PIL import Image as PILImage
                with PILImage.open(str(img_path)) as pil_img:
                    img_w_px, img_h_px = pil_img.size
                img_aspect = img_w_px / img_h_px
                panel_aspect = chart_w / content_h

                if img_aspect > panel_aspect:
                    # Image is wider — fit to width
                    fit_w = chart_w
                    fit_h = int(chart_w / img_aspect)
                    fit_left = chart_left
                    fit_top = content_top + (content_h - fit_h) // 2
                else:
                    # Image is taller — fit to height
                    fit_h = content_h
                    fit_w = int(content_h * img_aspect)
                    fit_top = content_top
                    fit_left = chart_left + (chart_w - fit_w) // 2

                # Tight frame matching the actual fitted image (Tier 1B fix)
                # This eliminates the oversized empty panel around small charts
                frame_pad = Inches(0.05)
                frame = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE,
                                                fit_left - frame_pad,
                                                fit_top - frame_pad,
                                                fit_w + 2 * frame_pad,
                                                fit_h + 2 * frame_pad)
                frame.fill.solid()
                frame.fill.fore_color.rgb = RGBColor.from_string("FAFAFA")
                frame.line.color.rgb = RGBColor.from_string("E5E5EA")
                frame.line.width = Pt(0.5)
                frame.shadow.inherit = False

                slide.shapes.add_picture(str(img_path), fit_left, fit_top,
                                         width=fit_w, height=fit_h)
                has_chart = True
            except Exception as e:
                print(f"   ! ASK_B image embed failed: {e}")
        else:
            print(f"   ! ASK_B chart missing: {img_file}")

    # If no chart, fill the right panel with overflow bullets in a styled card
    if not has_chart:
        # Find owner-attribution bullets (specific to honest/boundary slides)
        owner_pattern = re.compile(r"(owns|owner|stays with|out of scope|not in this release|this release does not)", re.IGNORECASE)
        owner_bullets = [b for b in row["bullets"] if owner_pattern.search(b)]

        # Only render the right panel if there are distinct owner bullets
        # (otherwise we'd duplicate the left content — Tier 1G fix)
        if owner_bullets and any(b not in row["bullets"][:5] for b in owner_bullets):
            display_bullets = [b for b in owner_bullets if b not in row["bullets"][:5]][:6]
        elif owner_bullets:
            display_bullets = owner_bullets[:6]
        else:
            display_bullets = []

        if display_bullets:
            # Card background
            card = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE,
                                           chart_left - Inches(0.1),
                                           content_top - Inches(0.05),
                                           chart_w + Inches(0.2),
                                           content_h + Inches(0.1))
            card.fill.solid()
            card.fill.fore_color.rgb = RGBColor.from_string("F4F6FB")
            card.line.color.rgb = RGBColor.from_string("D2D2D7")
            card.line.width = Pt(0.5)
            card.shadow.inherit = False

            # Label
            ltb = slide.shapes.add_textbox(chart_left + Inches(0.2),
                                            content_top + Inches(0.2),
                                            chart_w - Inches(0.4), Inches(0.4))
            ltf = ltb.text_frame
            ltf.margin_left = ltf.margin_right = 0
            lp = ltf.paragraphs[0]
            lr = lp.add_run()
            lr.text = "WHO OWNS THIS"
            lr.font.size = Pt(11)
            lr.font.bold = True
            lr.font.color.rgb = RGBColor.from_string("0F6CBD")

            otb = slide.shapes.add_textbox(chart_left + Inches(0.2),
                                            content_top + Inches(0.7),
                                            chart_w - Inches(0.4), content_h - Inches(0.9))
            otf = otb.text_frame
            otf.word_wrap = True
            for i, b in enumerate(display_bullets):
                p = otf.paragraphs[0] if i == 0 else otf.add_paragraph()
                p.space_after = Pt(8)
                para_data = _format_bullet_with_tools(b, size=13)
                for r in list(p.runs):
                    r.text = ""
                for run_data in para_data["runs"]:
                    run = p.add_run()
                    run.text = run_data.get("text", "") or ""
                    font = run.font
                    if run_data.get("size"):
                        font.size = Pt(run_data["size"])
                    if run_data.get("bold"):
                        font.bold = True
                    if run_data.get("color"):
                        font.color.rgb = RGBColor.from_string(run_data["color"])
        else:
            # No useful content for right panel — let left text use full width
            # Re-render left text spanning the full content area
            ttb_full = slide.shapes.add_textbox(text_left, content_top,
                                                 sl_w - text_left - Inches(0.7), content_h)
            tf2 = ttb_full.text_frame
            tf2.word_wrap = True
            tf2.margin_left = tf2.margin_right = 0
            tf2.margin_top = Inches(0.1)
            for i, b in enumerate(row["bullets"][:8]):
                p = tf2.paragraphs[0] if i == 0 else tf2.add_paragraph()
                p.space_after = Pt(8)
                para_data = _format_bullet_with_tools(b, size=14)
                for r in list(p.runs):
                    r.text = ""
                for run_data in para_data["runs"]:
                    run = p.add_run()
                    run.text = run_data.get("text", "") or ""
                    font = run.font
                    if run_data.get("size"):
                        font.size = Pt(run_data["size"])
                    if run_data.get("bold"):
                        font.bold = True
                    if run_data.get("color"):
                        font.color.rgb = RGBColor.from_string(run_data["color"])
                if run_data.get("size"):
                    font.size = Pt(run_data["size"])
                if run_data.get("bold"):
                    font.bold = True
                if run_data.get("color"):
                    font.color.rgb = RGBColor.from_string(run_data["color"])

    render_footer_chip(slide, row)


def _format_bullet_with_tools(text, size=14):
    """Format a bullet by detecting tool/task names and bolding them.

    Tool/task pattern: lowercase identifiers with hyphens (e.g., 'capacity-daily-monitor',
    'deploy-budget', 'vm-quota-usage'). Returns a paragraph dict with multiple runs.
    """
    # Pattern matches identifiers with at least one hyphen, lowercase letters
    pattern = re.compile(r"\b([a-z][a-z0-9]*(?:-[a-z0-9]+){1,})\b")
    runs = []
    pos = 0
    for m in pattern.finditer(text):
        if m.start() > pos:
            runs.append({"text": text[pos:m.start()], "size": size, "color": "1B1B1F"})
        runs.append({"text": m.group(0), "size": size, "color": "0F6CBD", "bold": True})
        pos = m.end()
    if pos < len(text):
        runs.append({"text": text[pos:], "size": size, "color": "1B1B1F"})
    if not runs:
        runs = [{"text": text, "size": size, "color": "1B1B1F"}]
    return {"runs": runs, "space_after": 6}


def _set_text_frame_with_runs(ph, paragraphs):
    """Set text frame from paragraphs that may contain multiple styled runs."""
    if ph is None:
        return
    tf = ph.text_frame
    tf.clear()
    tf.word_wrap = True
    for i, p in enumerate(paragraphs):
        if i == 0:
            para = tf.paragraphs[0]
        else:
            para = tf.add_paragraph()
        for r in list(para.runs):
            r.text = ""
        if p.get("space_after"):
            para.space_after = Pt(p["space_after"])
        runs_data = p.get("runs", [{"text": p.get("text", "")}])
        for run_data in runs_data:
            run = para.add_run()
            run.text = run_data.get("text", "") or ""
            font = run.font
            if run_data.get("size"):
                font.size = Pt(run_data["size"])
            if run_data.get("bold"):
                font.bold = True
            if run_data.get("color"):
                font.color.rgb = RGBColor.from_string(run_data["color"])


# ─── ASK_C renderer: editorial details treatment ─────────────

def render_ask_c(slide, row):
    """TELL slide: matches the editorial pull-quote design language.

    Cluster chyron at top (uppercase blue), blue accent rule on left,
    technical content in clean hierarchy:
      - Prose lines: serif body
      - Code lines (between ``` markers): dark monospace blocks
      - Monday move: highlighted blue callout panel at the bottom
    """
    from pptx.enum.shapes import MSO_SHAPE
    from pptx.enum.text import MSO_ANCHOR

    if slide.shapes.title is not None:
        slide.shapes.title.text = row["title"]
        if len(row["title"]) > 50:
            for para in slide.shapes.title.text_frame.paragraphs:
                for run in para.runs:
                    run.font.size = Pt(24)

    # Remove default body placeholder — we draw a custom layout
    body_ph = get_placeholder(slide, 10)
    if body_ph is not None:
        sp = body_ph._element
        sp.getparent().remove(sp)

    # Cluster chyron at top (matches ASK_A signature)
    render_cluster_chyron(slide, row, top=Inches(1.05))
    # Note: accent rule is drawn AT END to match actual content height

    sl_w = slide.part.package.presentation_part.presentation.slide_width
    sl_h = slide.part.package.presentation_part.presentation.slide_height
    content_left = Inches(1.0)
    content_w = sl_w - content_left - Inches(0.7)

    # Group bullets into segments: prose, code (monospace block), monday
    segments = []
    in_code = False
    code_buf = []
    for b in row["bullets"]:
        if b.strip() == "```":
            if in_code:
                if code_buf:
                    segments.append({"type": "code", "lines": code_buf})
                code_buf = []
                in_code = False
            else:
                in_code = True
            continue
        if in_code:
            code_buf.append(b)
            continue
        is_monday = "monday move" in b.lower() or b.strip().startswith("srectl")
        if is_monday:
            segments.append({"type": "monday", "text": b})
        else:
            segments.append({"type": "prose", "text": b})
    if in_code and code_buf:
        segments.append({"type": "code", "lines": code_buf})

    # Lay out segments top-to-bottom with proper spacing
    y = Inches(1.45)
    bottom_limit = sl_h - Inches(0.8)
    gap = Inches(0.12)

    for seg in segments:
        if y >= bottom_limit:
            break

        if seg["type"] == "code":
            # Dark code block — fixed-width monospace, preserves alignment
            n_lines = len(seg["lines"])
            line_h = Inches(0.22)
            block_h = line_h * n_lines + Inches(0.25)
            if y + block_h > bottom_limit:
                block_h = bottom_limit - y

            bg = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE,
                                         content_left, y, content_w, block_h)
            bg.fill.solid()
            bg.fill.fore_color.rgb = RGBColor.from_string("1E1E2E")
            bg.line.color.rgb = RGBColor.from_string("3A3A4A")
            bg.line.width = Pt(0.5)
            bg.shadow.inherit = False

            tb = slide.shapes.add_textbox(content_left + Inches(0.2),
                                           y + Inches(0.12),
                                           content_w - Inches(0.4),
                                           block_h - Inches(0.24))
            tf = tb.text_frame
            tf.word_wrap = False
            tf.margin_left = tf.margin_right = 0
            tf.margin_top = tf.margin_bottom = 0

            for i, line in enumerate(seg["lines"]):
                p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
                p.space_after = Pt(2)
                run = p.add_run()
                run.text = line
                run.font.size = Pt(11)
                run.font.name = "Consolas"
                run.font.color.rgb = RGBColor.from_string("D4D4D4")

            y += block_h + gap

        elif seg["type"] == "monday":
            # Highlighted Monday-move callout — sized to fit single line
            callout_h = Inches(0.45)
            if y + callout_h > bottom_limit:
                callout_h = bottom_limit - y

            bg = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE,
                                         content_left, y, content_w, callout_h)
            bg.fill.solid()
            bg.fill.fore_color.rgb = RGBColor.from_string("EAF3FB")
            bg.line.color.rgb = RGBColor.from_string("0F6CBD")
            bg.line.width = Pt(1.0)
            bg.shadow.inherit = False

            tb = slide.shapes.add_textbox(content_left + Inches(0.25),
                                           y + Inches(0.05),
                                           content_w - Inches(0.5),
                                           callout_h - Inches(0.1))
            tf = tb.text_frame
            tf.word_wrap = True
            tf.vertical_anchor = MSO_ANCHOR.MIDDLE
            p = tf.paragraphs[0]
            run = p.add_run()
            run.text = seg["text"]
            run.font.size = Pt(12)
            run.font.bold = True
            run.font.color.rgb = RGBColor.from_string("0F6CBD")

            y += callout_h + gap

        else:  # prose
            # Estimate prose height: ~0.30" per ~80 chars
            n_visual_lines = max(1, (len(seg["text"]) // 90) + 1)
            prose_h = Inches(0.30) * n_visual_lines
            if y + prose_h > bottom_limit:
                prose_h = bottom_limit - y

            tb = slide.shapes.add_textbox(content_left, y, content_w, prose_h)
            tf = tb.text_frame
            tf.word_wrap = True
            tf.margin_left = tf.margin_right = 0
            tf.margin_top = tf.margin_bottom = 0

            # Format prose with tool-name bolding
            para_data = _format_bullet_with_tools(seg["text"], size=14)
            p = tf.paragraphs[0]
            for r in list(p.runs):
                r.text = ""
            for run_data in para_data["runs"]:
                run = p.add_run()
                run.text = run_data.get("text", "") or ""
                font = run.font
                if run_data.get("size"):
                    font.size = Pt(run_data["size"])
                if run_data.get("bold"):
                    font.bold = True
                if run_data.get("color"):
                    font.color.rgb = RGBColor.from_string(run_data["color"])

            y += prose_h + Inches(0.05)

    # Draw accent rule sized to actual content height (Tier 1A fix)
    actual_content_h = y - Inches(1.45)
    rule_h = max(Inches(1.0), min(actual_content_h, Inches(5.4)))
    render_accent_rule(slide, top=Inches(1.45), height=rule_h)

    render_footer_chip(slide, row)


def _set_text_frame_with_mono(ph, paragraphs):
    """Like set_text_frame but supports `mono: True` for monospace font."""
    if ph is None:
        return
    tf = ph.text_frame
    tf.clear()
    tf.word_wrap = True
    for i, p in enumerate(paragraphs):
        if i == 0:
            para = tf.paragraphs[0]
        else:
            para = tf.add_paragraph()

        for r in list(para.runs):
            r.text = ""

        run = para.add_run()
        run.text = p.get("text", "") or ""

        font = run.font
        if p.get("size"):
            font.size = Pt(p["size"])
        if p.get("bold"):
            font.bold = True
        if p.get("mono"):
            font.name = "Consolas"
        if p.get("color"):
            font.color.rgb = RGBColor.from_string(p["color"])


# ─── INDEX slide renderer: ask map for the deck ──────────────

def render_index(slide, row):
    """Index slide: clean two-column list of clusters with ask numbers + verdicts.

    Reads bullets from the outline directly. Each bullet is parsed as:
      "<cluster_id> · <verdict> · <name> · <comma,asks>"
    e.g. "P1.1 · green · Quota ≠ Capacity · 8,13,14,23,24"
    """
    from pptx.enum.shapes import MSO_SHAPE
    from pptx.enum.text import MSO_ANCHOR

    if slide.shapes.title is not None:
        slide.shapes.title.text = row["title"]

    # Remove default body placeholder — custom layout
    body_ph = get_placeholder(slide, 10)
    if body_ph is not None:
        sp = body_ph._element
        sp.getparent().remove(sp)

    sl_w = slide.part.package.presentation_part.presentation.slide_width
    sl_h = slide.part.package.presentation_part.presentation.slide_height
    margin_x = Inches(0.7)
    list_top = Inches(1.3)

    # Parse bullets into entries
    entries = []
    for b in row.get("bullets", []):
        parts = [p.strip() for p in b.split("·")]
        if len(parts) < 4:
            continue
        cluster_id, verdict, name, asks_str = parts[0], parts[1], parts[2], parts[3]
        asks = [int(a.strip()) for a in asks_str.split(",") if a.strip().isdigit()]
        entries.append({
            "cluster_id": cluster_id,
            "verdict": verdict.lower(),
            "name": name,
            "asks": asks,
        })

    n = len(entries)
    if n == 0:
        return

    # Two columns side-by-side, split entries roughly evenly
    col_w = (sl_w - 2 * margin_x - Inches(0.3)) // 2
    col_left_x = margin_x
    col_right_x = margin_x + col_w + Inches(0.3)

    half = (n + 1) // 2
    left_entries = entries[:half]
    right_entries = entries[half:]

    list_h = sl_h - list_top - Inches(0.8)
    row_h = list_h // max(half, 1)

    verdict_dot = {"green": "🟢", "yellow": "🟡", "red": "🔴"}

    def draw_entry(x, y, w, h, entry):
        v = entry.get("verdict", "green")
        vdot = verdict_dot.get(v, "")
        cid = entry.get("cluster_id", "")
        name = entry.get("name", "")
        asks = entry.get("asks", [])
        ask_str = " · ".join(f"#{a}" for a in asks)

        tb = slide.shapes.add_textbox(x, y, w, h)
        tf = tb.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_right = 0
        tf.margin_top = Inches(0.04)

        p1 = tf.paragraphs[0]
        p1.space_after = Pt(0)
        r_dot = p1.add_run()
        r_dot.text = f"{vdot}  "
        r_dot.font.size = Pt(11)

        r_cid = p1.add_run()
        r_cid.text = f"{cid}  "
        r_cid.font.size = Pt(11)
        r_cid.font.bold = True
        r_cid.font.color.rgb = RGBColor.from_string("0F6CBD")

        r_name = p1.add_run()
        r_name.text = name
        r_name.font.size = Pt(13)
        r_name.font.color.rgb = RGBColor.from_string("1B1B1F")

        p2 = tf.add_paragraph()
        p2.space_before = Pt(0)
        p2.space_after = Pt(0)
        r_asks = p2.add_run()
        r_asks.text = f"   Asks {ask_str}"
        r_asks.font.size = Pt(10)
        r_asks.font.color.rgb = RGBColor.from_string("595959")

    for i, e in enumerate(left_entries):
        draw_entry(col_left_x, list_top + i * row_h, col_w, row_h, e)
    for i, e in enumerate(right_entries):
        draw_entry(col_right_x, list_top + i * row_h, col_w, row_h, e)


RENDERERS = {
    "TITLE": render_title,
    "BULLETS": render_bullets,
    "WHEEL_STATS": render_wheel_stats,
    "MATRIX": render_matrix,
    "SECTION_TWOCOL": render_section_twocol,
    "SECTION_HEADLINE": render_section_headline,
    "TWOUP_IMAGES": render_twoup_images,
    "TWOCOL_LISTS": render_twocol_lists,
    "CARDS_3": lambda s, r: render_cards_n(s, r, 3),
    "CARDS_2": lambda s, r: render_cards_n(s, r, 2),
    "CARDS_4": lambda s, r: render_cards_n(s, r, 4),
    "TABLE": render_table,
    "WHEEL_LARGE": render_wheel_large,
    "THREE_BLOCK": render_three_block,
    "ASK_A": render_ask_a,
    "ASK_B": render_ask_b,
    "ASK_C": render_ask_c,
    "INDEX": render_index,
}


# ─── Slide deletion ──────────────────────────────────────────

def delete_all_slides(prs):
    """Delete every slide from the presentation cleanly."""
    sldIdLst = prs.slides._sldIdLst
    rIds = [sldId.rId for sldId in list(sldIdLst)]
    for sldId in list(sldIdLst):
        sldIdLst.remove(sldId)
    # Drop the relationships and parts
    for rId in rIds:
        try:
            prs.part.drop_rel(rId)
        except Exception:
            pass


# ─── Main pipeline ───────────────────────────────────────────

def main():
    rows = parse_v8()
    print(f"Parsed {len(rows)} V8 rows\n")

    prs = Presentation(str(SOURCE))

    # Validate layouts exist before doing anything destructive
    for kind in {r["kind"] for r in rows}:
        find_layout(prs, KIND_LAYOUT[kind])

    delete_all_slides(prs)
    print(f"Cleared all original slides.\n")

    for row in rows:
        kind = row["kind"]
        layout = find_layout(prs, KIND_LAYOUT[kind])
        slide = prs.slides.add_slide(layout)

        # Render content
        RENDERERS[kind](slide, row)

        # Speaker notes
        if row["notes"] and any(n.strip() for n in row["notes"]):
            tf = slide.notes_slide.notes_text_frame
            tf.clear()
            tf.paragraphs[0].text = row["notes"][0]
            for note_para in row["notes"][1:]:
                p = tf.add_paragraph()
                p.text = note_para

        print(f"  {row['num']:5s}  [{kind:18s}]  {layout.name:40s}  {row['title'][:55]}")

    # Scrub author metadata via core_props
    prs.core_properties.author = "FinOps Toolkit community"
    prs.core_properties.last_modified_by = "FinOps Toolkit community"

    prs.save(str(OUT))
    print(f"\nWrote {OUT}")
    print(f"Slides: {len(prs.slides)}")


if __name__ == "__main__":
    main()
