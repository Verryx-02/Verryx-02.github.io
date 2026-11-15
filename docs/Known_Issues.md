# Known issues

## Open

### KI-3: the mono font has no italic or bold file (2026-11-15, updated 2026-11-15)

Fragment Mono was replaced by Iosevka, and still only the roman (`iosevka-400.woff2`) is
self-hosted. Italic mono text (code comments in `syntax.css`, `.ge`) is slanted by the
browser, and bold mono (`.gs`, `.gh`, weight 700) is synthesized too. Decision needed:
accept the synthesized styles, or add `iosevka-400-italic.woff2` (and a 700) to
`static/fonts/`, subset with the docs/Maintaining.md command, with an `@font-face` each in `main.css`.

### KI-4: room and rack pages have no intro text yet (2026-11-15, updated 2026-11-15)

Since ADR 0003, the seven room files (`content/<room>/_index.md`) and the six rack files
(`content/<room>/<rack>/_index.md`) have no body, so every room page goes straight from the
band to its racks (or to the "Closed: no posts yet" notice) and every rack page straight to
its units. Decision needed: write an intro for each room and rack (the body of its
`_index.md`), and optionally a `description` for its meta description (today the site
description).

### KI-6: the home page has no `<h1>` (2026-11-15)

The home page has no band, so its first heading is the `<h2>` of the first floor (Mindset);
the console kicker "Start here" is a `<p>`. Screen-reader users navigating by headings find
no page title. This predates ADR 0003. Decision needed: a visually hidden `<h1>` with the
site title, or the console kicker as the `<h1>`.

### KI-8: the home switch and tray get cramped with many rooms (2026-11-15)

On screens 1120px and wider (the breakpoint where 8 ports of `--port-min`, 125px, fit between
the trays; the room container grows to 1180px) the switch keeps its ports in one row, every port (spares too)
one width across the hall between the two cable trays, which grow by one 8px lane per room
(`main.css`, `.server-hall` `--tray-l-w` and `--tray-r-w`). With 7 rooms (8 ports) a port is
125-132px wide, so "Software Engineering" wraps at its space, "Cybersecurity" fits whole, and
four 236px racks fit per row (992 of up to 1060px). With 12 rooms (16 ports) a port is about
64px, because the breakpoint is computed for 8 ports: a single word wider than
that ("Engineering", "Cybersecurity", about 95-110px as a label) is never broken, so it
overflows its label and overlaps the next port's. Below 1120px (ports as rows, the faceplate in the middle)
each label has half of the hall minus the strip: at 375px "Cybersecurity" fits one side, but on
a 320px phone a single long word overflows its side of the strip (no page scroll, the
label just reaches into the tray). Decision needed only if the site grows past about 12 rooms: a
two-row switch (a new cable geometry), a narrower lane, or a cap on rooms.

### KI-9: spare switch ports are aria-hidden items of the ports list (2026-11-15)

The spare ports (`layouts/_partials/switch.html`) are `<li aria-hidden="true">` inside the
`<ol>` of room ports, so they stay out of the accessibility tree; whether a screen reader
announces the list as "7 items" or "8 items" depends on how the browser computes the list
size from hidden items (not checked: no screen reader in this environment). Decision
needed if a test shows "8 items": move the spares out of the `<ol>` (for example a sibling
element placed in the same grid with `display: contents` on a wrapper), at the cost of a
more complex grid.

### KI-10: tag page units keep their natural height (2026-11-15)

Units are one fixed height inside racks (home floors, room pages, rack pages), but the tag
pages (`layouts/term.html`, `.unit-list`) list full units outside any rack, so a long title
or opening text still makes a unit taller there. Decision needed: apply the rack page's
fixed height and 2-line clamps to `.unit-list .unit` too, or keep tag lists free-height.

## Closed

### KI-1: `/series/` and `/posts/` have no inbound links (2026-11-14)

Since the Blog and Series nav tabs were removed, no generated page links to the series list
(`/series/`) or the post section (`/posts/`); they are reachable only by typing the URL or
via `sitemap.xml`. Posts link to their own series page through the series box, and the home
page lists every post and links to the featured series, so no content is unreachable.
Decision needed: keep these two pages as unlinked, link them from somewhere (for example the
footer, or a "See all series" link once there is more than one series), or stop building them.

Closed 2026-11-15 by ADR 0002 (racks content model): `/series/` and `/posts/` are no longer
built (the series taxonomy and the posts section are gone), and every rack page is linked
from the home page.

### KI-7: the home lead ends on a colon (2026-11-15)

The lead is the first two paragraphs of `content/_index.md` (the ADR 0003 default), and the
second one ends with "for a few reasons:"; the list it introduces is inside the collapsed
"More about this blog" disclosure. Decision needed (the author's words): move `<!--more-->`
after the list, or rewrite the lead's last sentence.

Closed 2026-11-15 by the author's rewrite of `content/_index.md`: the lead's second paragraph now
reads "I'm writing this blog to document my projects and what I learn along the way, ...", and
"I do it for a few reasons:" moved after `<!--more-->`, opening the list inside the disclosure.
`scripts/check.sh` asserts both.


### KI-5: the site description still says "homelab journey" (2026-11-15, updated 2026-11-15)

`params.description` in `hugo.toml` (the home meta description, the RSS channel description
and the fallback meta description of every room and rack page) describes a homelab
blog, while the server rooms now also cover Mindset, Software
Engineering, Cybersecurity, AI, 3D Printing and Future projects. Decision needed: the wording
of a broader description. The author chose to keep the current wording for now (2026-11-15);
the README no longer has a tagline (rewritten 2026-11-15).

Closed 2026-11-15 by the author: `params.description` now reads "I document my projects and what I learn along the way, from the homelab to software, security and AI." (first person, all themes).
