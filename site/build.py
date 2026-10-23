#!/usr/bin/env python3
"""Build the tutorial site into site/_build/.

Renders site/chapters/*.md (front matter, ::: box directives, ```zig
listings) and the Comet 64 reference card into one page with a view per
chapter, builds every checkpoint's browser build, and copies the images.

    python3 site/build.py            # needs: pip install markdown pygments
    python3 site/build.py --no-wasm  # reuse existing web/game.wasm files

Author tooling: nothing here is reader-facing except its output.
"""

import html
import re
import shutil
import subprocess
import sys
from pathlib import Path

import markdown
from pygments import highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import get_lexer_by_name
from pygments.util import ClassNotFound

SITE = Path(__file__).resolve().parent
import os
OUT = Path(os.environ["SITE_OUT"]) if os.environ.get("SITE_OUT") else SITE / "_build"
CODE = SITE / "code"
REPO_TREE = "https://github.com/alecf/dr-creep-in-zig/tree/claude/zig-game-tutorial-outline-inc3pd/site/code/"
REPO_BLOB = "https://github.com/alecf/dr-creep-in-zig/blob/claude/zig-game-tutorial-outline-inc3pd/site/code/"

BOXES = {
    "mission-briefing": "Mission Briefing",
    "power-up": "Power-Up!",
    "byte-budget": "Byte Budget",
    "pro-tip": "Pro Tip",
    "under-the-hood": "Under the Hood",
    "secret-passage": "Secret Passage",
    "game-over": "Game Over?",
    "warp-zone": "Warp Zone",
    "boss-battle": "Boss Battle",
    "bonus-stage": "Bonus Stage",
    "inside-the-disk": "Inside the Disk",
    "type-in": "Type-In Listing",
    "side-quest": "Side Quest",
    "widget": "Try it",
}

FORMATTER = HtmlFormatter(nowrap=True)


def front_matter(text):
    meta = {}
    if text.startswith("---\n"):
        end = text.index("\n---\n", 4)
        for line in text[4:end].splitlines():
            if ":" in line:
                k, v = line.split(":", 1)
                meta[k.strip()] = v.strip().strip('"')
        text = text[end + 5 :]
    return meta, text


def render_code(lang, body):
    snippet = lang.endswith(" snippet")
    lang = lang.replace(" snippet", "").strip() or "text"
    try:
        lexer = get_lexer_by_name(lang)
    except ClassNotFound:
        lexer = get_lexer_by_name("text")
    inner = highlight(body, lexer, FORMATTER)
    cls = "code snippet" if snippet else "code"
    tag = f'<span class="lang">{html.escape(lang)}{" · snippet" if snippet else ""}</span>' if lang != "text" else ""
    return f'<div class="{cls}">{tag}<pre><code>{inner}</code></pre></div>'


def fix_links(md, chapter_files):
    def link(m):
        target = m.group(2)
        if target.startswith("downloads/"):
            name = target[len("downloads/") :].removesuffix(".zip")
            folders = "starter" if name == "starter" else name
            return f"[{m.group(1)}]({REPO_TREE}{folders})"
        if target.endswith("REFERENCE.md"):
            return f"[{m.group(1)}](#reference)"
        if target.startswith("../code/"):
            rest = target[len("../code/") :]
            base = REPO_TREE if rest.endswith("/") or "." not in rest.split("/")[-1] else REPO_BLOB
            return f"[{m.group(1)}]({base}{rest})"
        if target in chapter_files:
            return f"[{m.group(1)}](#{chapter_files[target]})"
        return m.group(0)

    return re.sub(r"\[([^\]]*)\]\(([^)\s]+)\)", link, md)


def render(md, view, chapter_files):
    md = fix_links(md, chapter_files)
    slots = {}

    def stash(htmltext):
        key = f"ZZSLOT{len(slots)}ZZ"
        slots[key] = htmltext
        return f"\n\n{key}\n\n"

    # 1. pull out code fences so nothing inside them is parsed
    out, lines, i = [], md.split("\n"), 0
    while i < len(lines):
        m = re.match(r"^(\s*)```(.*)$", lines[i])
        if m:
            lang, body, i = m.group(2).strip(), [], i + 1
            while i < len(lines) and not re.match(r"^\s*```\s*$", lines[i]):
                body.append(lines[i])
                i += 1
            out.append(stash(render_code(lang, "\n".join(body) + "\n")))
        else:
            out.append(lines[i])
        i += 1
    md = "\n".join(out)

    def to_html(text):
        h = markdown.markdown(text, extensions=["tables", "sane_lists", "attr_list"])
        # restore slots (may be nested one level)
        for _ in range(3):
            for k, v in slots.items():
                h = h.replace(f"<p>{k}</p>", v).replace(k, v)
        return h

    def inline(text):
        h = markdown.markdown(text)
        return h.removeprefix("<p>").removesuffix("</p>")

    # 2. ::: directives (not nested)
    def box(kind, title, inner):
        label = BOXES.get(kind, kind.replace("-", " ").title())
        body = to_html(inner)
        if kind in ("type-in", "side-quest"):
            return stash(
                f'<details class="box box-{kind}"><summary><span class="box-label">{label}</span>'
                f'<span class="box-title">{html.escape(title)}</span></summary><div class="box-body">{body}</div></details>'
            )
        if kind == "widget":
            return ""  # author placeholder for a future interactive widget
        if kind == "diagram":
            # :::diagram NAME  (body = caption, markdown). The picture itself
            # is site/page/diagrams/NAME.html: hand-made HTML/SVG/CSS.
            name = title.split()[0]
            src = SITE / "page" / "diagrams" / f"{name}.html"
            if not src.exists():
                raise SystemExit(f"missing diagram {src}")
            cap = f'<figcaption>{inline(inner.strip())}</figcaption>' if inner.strip() else ""
            return stash(f'<figure class="diagram" data-diagram="{name}">{src.read_text()}{cap}</figure>')
        t = f'<span class="box-title">{inline(title)}</span>' if title else ""
        return stash(
            f'<aside class="box box-{kind}"><div class="box-head"><span class="box-label">{label}</span>{t}</div>'
            f'<div class="box-body">{body}</div></aside>'
        )

    out, lines, i = [], md.split("\n"), 0
    while i < len(lines):
        m = re.match(r"^:::([a-z-]+)\s*(.*)$", lines[i])
        if m:
            kind, title, inner, i = m.group(1), m.group(2).strip(), [], i + 1
            while i < len(lines) and lines[i].strip() != ":::":
                inner.append(lines[i])
                i += 1
            out.append(box(kind, title, "\n".join(inner)))
        else:
            out.append(lines[i])
        i += 1
    md = "\n".join(out)

    h = to_html(md)
    # heading ids, unique per view
    seen = {}

    def hid(m):
        level, text = m.group(1), m.group(2)
        slug = re.sub(r"[^a-z0-9]+", "-", re.sub(r"<[^>]+>", "", text).lower()).strip("-") or "s"
        slug = f"{view}-{slug}"
        n = seen.get(slug, 0)
        seen[slug] = n + 1
        if n:
            slug += f"-{n}"
        return f'<h{level} id="{slug}">{text}</h{level}>'

    h = re.sub(r"<h([2-4])>(.*?)</h\1>", hid, h)
    h = h.replace('<a href="http', '<a target="_blank" rel="noopener" href="http')
    h = re.sub(r"<img ", '<img loading="lazy" ', h)
    return h


def headings(h):
    return re.findall(r'<h2 id="([^"]+)">(.*?)</h2>', h)


def build_wasm(name):
    d = CODE / name
    if "--no-wasm" not in sys.argv:
        subprocess.run(["zig", "build", "wasm"], cwd=d, check=True)
    wasm = d / "web" / "game.wasm"
    (OUT / "play").mkdir(parents=True, exist_ok=True)
    shutil.copy(wasm, OUT / "play" / f"{name}.wasm")


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    (OUT / "images").mkdir(parents=True)
    for img in (SITE / "chapters" / "images").glob("*.png"):
        shutil.copy(img, OUT / "images" / img.name)
    shutil.copy(CODE / "machine" / "web" / "shell.js", OUT / "shell.js")

    files = sorted((SITE / "chapters").glob("[0-9][0-9]-*.md"))
    chapter_files = {}
    metas = []
    for f in files:
        meta, _ = front_matter(f.read_text())
        num = int(meta.get("chapter", 0))
        view = "prologue" if num == 0 else f"ch{num:02d}"
        chapter_files[f.name] = view
        metas.append((f, meta, view, num))

    views = []
    for f, meta, view, num in metas:
        _, text = front_matter(f.read_text())
        body = render(text, view, chapter_files)
        cp = meta.get("checkpoint", "starter")
        build_wasm(cp)
        views.append(dict(view=view, num=num, title=meta.get("title", f.stem), body=body, checkpoint=cp))

    ref_meta, ref_text = front_matter((CODE / "machine" / "REFERENCE.md").read_text())
    ref_text = re.sub(r"\A# .*\n", "", ref_text)
    ref_body = render(ref_text, "reference", chapter_files)

    template = (SITE / "page" / "template.html").read_text()
    nav, sections = [], []
    for i, v in enumerate(views):
        label = "Prologue" if v["num"] == 0 else f"Chapter {v['num']}"
        nav.append(
            f'<a class="toc-item" href="#{v["view"]}" data-view="{v["view"]}">'
            f'<span class="toc-num">{label}</span><span class="toc-title">{html.escape(v["title"])}</span></a>'
        )
        local = "".join(f'<a href="#{i_}" data-jump="{i_}">{t}</a>' for i_, t in headings(v["body"]))
        prev_v = views[i - 1] if i > 0 else None
        next_v = views[i + 1] if i + 1 < len(views) else None
        pager = '<nav class="pager">'
        if prev_v:
            pager += f'<a href="#{prev_v["view"]}" class="prev">← {html.escape(prev_v["title"])}</a>'
        if next_v:
            pager += f'<a href="#{next_v["view"]}" class="next">{html.escape(next_v["title"])} →</a>'
        pager += "</nav>"
        play_title = "The starter kit" if v["checkpoint"] == "starter" else f"Checkpoint {v['checkpoint']}"
        play = (
            f'<section class="play" aria-label="Playable checkpoint">'
            f'<div class="play-head"><span class="play-eyebrow">Plug in and play</span>'
            f'<h2 class="play-title">{play_title}</h2>'
            f'<p class="play-note">The game exactly as it stands at the end of this chapter. Click the screen, then use the arrow keys or WASD and Space. IJKL and Return drive joystick 2.</p></div>'
            f'<div class="crt"><canvas data-wasm="play/{v["checkpoint"]}.wasm" width="384" height="272" tabindex="0" aria-label="Comet 64 screen"></canvas>'
            f'<button class="power" type="button">Power on</button></div>'
            f'<p class="play-status" data-status>Off</p></section>'
        )
        kicker = "Prologue" if v["num"] == 0 else f"Chapter {v['num']}"
        sections.append(
            f'<article class="view" id="view-{v["view"]}" data-view="{v["view"]}" hidden>'
            f'<header class="chapter-head"><p class="kicker">{kicker}</p><h1>{html.escape(v["title"])}</h1>'
            f'<nav class="local" aria-label="In this chapter">{local}</nav></header>'
            f'<div class="prose">{v["body"]}</div>{play}{pager}</article>'
        )
    sections.append(
        '<article class="view" id="view-reference" data-view="reference" hidden>'
        '<header class="chapter-head"><p class="kicker">Comet 64</p><h1>Programmer\'s Reference Card</h1>'
        f'<nav class="local">{"".join(f"<a href=#{i_} data-jump={i_}>{t}</a>" for i_, t in headings(ref_body))}</nav></header>'
        f'<div class="prose">{ref_body}</div></article>'
    )
    nav.append('<a class="toc-item ref" href="#reference" data-view="reference"><span class="toc-num">Manual</span><span class="toc-title">Comet 64 Reference Card</span></a>')

    page = (
        template.replace("{{NAV}}", "\n".join(nav))
        .replace("{{VIEWS}}", "\n".join(sections))
        .replace("{{PYGMENTS}}", "")
        .replace("{{DIAGRAM_CSS}}", (SITE / "page" / "diagrams.css").read_text())
    )
    (OUT / "index.html").write_text(page)
    size = sum(p.stat().st_size for p in OUT.rglob("*") if p.is_file())
    print(f"built {OUT} ({size / 1024:.0f} KB, {len(views)} chapters)")


if __name__ == "__main__":
    main()
