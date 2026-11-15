---
status: accepted
date: 2026-11-15
decision-makers: Francesco Verrengia
supersedes: ADR-0002
---

# Themed server rooms of topic racks, and a home page switch with one cable per room

## Context and Problem Statement

ADR 0002 (just implemented) made the blog one server room with seven racks, each rack a
macro-topic whose units are chapters: `content/server-room-1/racks/<rack>/<chapter>/index.md`,
planned chapters in the rack's `planned:` front matter (`content/server-room-1/racks/homelab/_index.md:4-7`),
blanks with a red LED and no text when untitled (`layouts/_partials/unit.html:30-43`), every
rack padded to 3 units in the template (`layouts/_partials/rack-units.html:15,18,55`), and a
home page that renders the room named by `params.homeServerRoom` (`hugo.toml:22`,
`layouts/home.html:2-9`) after a console with the whole intro (`layouts/home.html:18-28`,
`content/_index.md:10-24`). The two room-level pages build nothing and redirect to `/`
(`content/server-room-1/_index.md:6-8`, `content/_index.md:5-7`).

The author has replaced that model (final answers, 2026-11-15):

1. **Server rooms are themes**, in this order: Mindset, Homelab, Software Engineering,
   Cybersecurity, AI, 3D Printing (plate subtitle "Voron Trident"), Future projects.
2. **Racks are topics inside a room; units are the individual posts on that topic** (U01,
   U02, ...). Initial racks: Mindset → "If it works and you don't know why, find out" (U01 =
   the existing post), "Working in a team" (no posts). Homelab → "My relationship with
   operating systems" (U01 = the existing post), "Networking", "Proxmox configuration", later
   one rack per hosted service, "Geo-distribution and high availability". Other rooms: no
   racks yet.
3. **URLs** `/<room>/<rack>/<post>/` (e.g. `/homelab/networking/cgnat/`); rooms and racks
   have their own pages (`/homelab/`, `/homelab/networking/`). No "server room N" in URLs.
4. **Home**: a clean intro (not a wall of text; not narrow and left-aligned), then a
   **network switch** with one ethernet cable per room plugged into its ports, each cable
   carrying a label with the room name; below it, every room with its racks in miniature (the
   "server view"). A cable label (or room) opens the room page.
5. **A room with no published post**: its cable and label are there, but the port LED is off
   and the room is not clickable (closed).
6. Blank units keep the red LED / no-text-when-untitled behaviour of ADR 0002.
7. No JavaScript beyond lazy giscus: the switch and cables are pure HTML/CSS/SVG.

Nothing is published and giscus is off (`hugo.toml:26,28` empty ids), so URLs may change
freely now; once comments are on, a URL change orphans its thread (`mapping = "pathname"`,
`hugo.toml:29`).

Questions decided here: (A) content tree, (B) where planned racks and units live, (C) how
"closed" is represented, (D) what the home server view shows of closed rooms and empty racks,
(E) the 3-unit padding, (F) ordering, (G) post navigation, (H) the switch, (I) the home intro,
(J) room and rack pages, (K) redirects, (L) RSS, (M) the test impact.

## Decision Drivers

* **Faithful model by construction**: one room per rack, one rack per post, enforced by the
  folder tree and build errors, not discipline (as in ADR 0002).
* **No leaks**: a blank unit never becomes a URL, feed item, sitemap entry or tag entry; a
  closed room or rack is never linked and never indexed.
* **One source of truth for derived state**: "open" means "holds a published post"; a
  stored copy of that fact can drift.
* **Author workflow**: planning, drafting and publishing stay few, obvious steps; `hugo
  server -D` previews a draft in its real place.
* **Readability on a phone**: seven cable labels, the longest "Software Engineering", must
  be readable and tappable at 360 CSS px.
* **Constraints kept**: no JS except giscus, no About page (`scripts/check.sh:82`), dark
  only, no fixed width >= 400px (`scripts/check.sh:848-856`), no WARN in the build log
  (`scripts/check.sh:71-76`), no CSS counters and no `--led-off` for units
  (`scripts/check.sh:559-560`), blank LED red and steady (`scripts/check.sh:562-569`).
* **Testability**: every rule assertable on `public/` by `scripts/check.sh`, the site's
  only test suite, run by CI before deploy.
* **Migration cost** in templates, CSS and the ~430 assertions.

## Considered Options

**A. Content tree**

* A1. Three nested sections: `content/<room>/_index.md`, `content/<room>/<rack>/_index.md`,
  `content/<room>/<rack>/<post>/index.md`.
* A2. Keep a `server-room-1/` wrapper folder (rooms below it) and strip it from URLs with
  `[permalinks]` patterns.
* A3. Rooms as a taxonomy (or data file) over a flat rack tree.

**B. Where planned items live**

* B1. Planned **racks** are real rack folders with an `_index.md` and no posts; planned
  **units** stay in the rack's `planned:` list (ADR 0002 B2, unchanged).
* B2. Planned racks as a `planned:` list in the room's `_index.md`
  (`- {weight: 20, title: "Networking", units: [...]}`), turned into a folder at the first
  post.

**C. Representing "closed" (no published post inside)**

* C1. **Derived**: every room and rack page is built; one partial computes
  `open = len .RegularPagesRecursive > 0`; closed rooms and racks are never linked, carry
  `<meta name="robots" content="noindex">` and are left out of a site `sitemap.xml`
  template.
* C2. **Stored**: closed rooms and racks carry `build: {render: never, list: local}`,
  removed by hand on the first publish; a template `warnf` flags a mismatch.
* C3. **No closed state for racks**: only rooms close; every rack in an open room is linked,
  even with no post.

**D. Home server view**

* D1. Only open rooms get a floor below the switch; closed rooms appear only as their cable
  (unlit port, unlinked label). Inside an open room every rack is shown, empty racks as a
  rack of blanks with an unlinked name.
* D2. Every room gets a floor; closed rooms as a dimmed, empty floor with a "closed" plate.
* D3. Only open racks are shown inside open rooms.

**E. Minimum units per rack**

* E1. Keep the 3-unit padding for every rack, empty ones included (ADR 0002 B'1).
* E2. Pad only racks with a published post; an empty rack shows its planned units or one
  untitled blank.

**G. Post navigation**

* G1. "U01 of N" and prev/next within the rack only, plus a room › rack breadcrumb.
* G2. Prev/next falls through to the first/last published post of the neighbouring rack in
  the same room.

**H. Switch layout**

* H1. Horizontal switch, vertical cables at every width; labels rotated
  (`writing-mode: vertical-rl`) on narrow screens.
* H2. One markup, two CSS layouts: horizontal switch with vertical cables on wide screens;
  below a breakpoint the switch stands vertical on the left and each cable runs horizontally
  to a horizontal label (one row per room).
* H3. Two-row switch (ports 1-4 and 5-8), cables leaving up and down.

**I. Home intro**

* I1. The whole intro, centered in a wider block.
* I2. A short lead (the text before `<!--more-->` in `content/_index.md`), centered; the rest
  inside a native `<details>` disclosure ("Why this blog"); the "Start reading" button.
* I3. The lead only; the rest of the text is deleted.

## Decision Outcome

Chosen: **A1, B1, C1, D1, E1, G1, H2, I2**; F, J, K, L as specified below.

* **A1**, because the tree *is* the information architecture again (the structure "screams"
  the domain, *Clean Architecture*, Ch. 21 "The Theme of an Architecture", p. 197): a post
  folder can sit in one rack, a rack folder in one room, and the required URLs are Hugo's
  default path URLs with no permalink configuration (observed on 0.170.0, see Evidence). A2
  keeps a folder level whose only purpose is a name the author dropped, plus permalink
  patterns for three kinds. A3 repeats what ADR 0002 rejected for racks (many-to-many,
  empty terms missing from `site.Taxonomies`).
* **B1**, because a rack then has one definition in one file (title, weight, plate, intro,
  `planned`) from the day it is planned to the day it fills up, and creating the first post
  is a single new folder. B2 moves the rack definition between two files at the first post,
  nests unit plans inside room front matter, and cannot hold a rack intro written ahead.
* **C1**, because "open" is derived, computed in one partial, and therefore cannot disagree
  with the content: the first published post opens its rack and its room on the next build,
  with no flag to flip, and `hugo server -D` previews the draft's room and rack opened
  (drafts are pages there). C2 stores the same fact in up to two `_index.md` files per post;
  forgetting to remove the flag hides a published post's rack page, and while the flag is on
  the rack page cannot be previewed (the ADR 0002 B1 problem again). C3 contradicts the
  author's rule for rooms one level down: a rack of red blanks would be a clickable page
  with nothing to read. The price of C1 is that a closed page exists at a guessable URL
  (unlinked, noindex, out of the sitemap): it shows only the room or rack and a "closed"
  notice, which is harmless, and its URL is stable before its first post.
* **D1**, because at launch five of seven rooms are closed: five empty floors (D2) would put
  more nothing than content on the home page, and the switch already shows every room and
  its state once. Inside an open room, empty racks stay visible as racks of blanks (the
  roadmap the author wanted in ADR 0002), with their name unlinked; D3 would hide "Working
  in a team" and three Homelab racks.
* **E1**, because racks in one grid row stretch to equal height anyway (`assets/css/main.css:510-518`),
  one constant keeps every rack recognisably a rack, and `rack-units.html` and its
  fixtures stay unchanged. E2 adds a second rule for a cosmetic difference.
* **G1**, because a rack is the ordered sequence the author defined; the order between racks
  is a shelf order, not a reading order, and the breadcrumb puts the room one click away.
  G2 would silently invent a reading path across topics.
* **H2**, because it is the only layout whose labels stay horizontal and full-size on a
  phone, where each room becomes a full-width row (a large tap target, WCAG 2.2 SC 2.5.8),
  and the switch scales to any port count by wrapping rows on desktop and adding rows on a
  phone. H1 makes seven labels of about 50 px columns readable only sideways; H3 doubles
  the drawing work and still squeezes labels on a phone.
* **I2**, because it answers "not a wall of text" without deleting the author's words and
  without JavaScript (`<details>` is native HTML); centering a short lead reads well,
  centering eight paragraphs does not. I1 is still a wall; I3 discards content, a call that
  belongs to the author (see Open questions).

### Concrete shape of the decision

**Content tree and URLs**

```text
content/
  _index.md                                  home: lead <!--more--> rest of the intro; no aliases
  mindset/_index.md                          room (title, weight, plate?, description?; body = intro)
  mindset/find-out/_index.md                 rack "If it works and you don't know why, find out"
  mindset/find-out/if-it-works-find-out/index.md        post, unit 1 (+ cpu-sticker.jpg)
  mindset/teamwork/_index.md                 rack "Working in a team" (no posts)
  homelab/_index.md
  homelab/operating-systems/_index.md        rack "My relationship with operating systems"
  homelab/operating-systems/my-relationship-with-operating-systems/index.md   post, unit 1
  homelab/networking/_index.md               rack (no posts)
  homelab/proxmox/_index.md                  rack "Proxmox configuration" (no posts)
  homelab/high-availability/_index.md        rack "Geo-distribution and high availability" (no posts)
  software-engineering/_index.md             room, no racks (closed)
  cybersecurity/_index.md                    room, no racks (closed)
  ai/_index.md                               room, no racks (closed)
  3d-printing/_index.md                      room, plate "Voron Trident", no racks (closed)
  future-projects/_index.md                  room, no racks (closed)
```

* Post URL `/<room>/<rack>/<folder>/`, rack page `/<room>/<rack>/`, room page `/<room>/`.
  The post `.Section` is the room; `.CurrentSection` is the rack; the rack's `.Parent` is the
  room (observed). `server-room-1/` and its `racks/` level are deleted, with the two hidden
  `_index.md` files, the home `aliases` and `params.homeServerRoom` (`hugo.toml:18-22`).
* Depth is enforced: `page.html` fails the build (`errorf`) when a post's
  `.CurrentSection.Parent` is not a room (a post directly in a room, or a rack folder
  without `_index.md`, both of which Hugo would otherwise accept).
* The `[[cascade]]` turning off `publishResources` (`hugo.toml:37-41`) targets
  `kind = "page"` instead of a path glob (observed: bundle files stay unpublished).
* Room slugs must not collide with `tags` (the taxonomy URL); a fitness function checks it.

**Front matter**

* Room `_index.md`: `title`, `weight` (required, unique), `plate` (optional subtitle, "Voron
  Trident" on 3D Printing), `description` (optional meta description). Body: the room intro.
* Rack `_index.md`: unchanged from ADR 0002 (`title`, `weight` unique within the room,
  `plate`, `description`, `planned`), one level up. "Working in a team", "Networking",
  "Proxmox configuration" and "Geo-distribution and high availability" stop being planned
  units and become racks, so no `planned` entry exists at launch.
* Post: unchanged (`title`, `date`, `draft`, `unit` required, `tags`, `summary`).
  `archetypes/default.md` comments say "post" and "rack" instead of "chapter".

**F. Ordering.** Rooms by `weight` (Mindset 1 ... Future projects 7). Racks by `weight`
within their room, in steps of 10 (operating-systems 10, networking 20, proxmox 30,
high-availability 90), so a rack per hosted service slots in at 40-80 without renumbering.
Posts by `unit` inside the rack, as before.

**C1 in templates.** A partial `is-open.html` returns `gt (len .RegularPagesRecursive) 0`
for a room or rack (cached per section). It is the only place the rule lives; callers:

* the switch (port LED lit or unlit, label link or plain text),
* the home server view (floor or no floor),
* `rack.html` (rack name linked or not),
* `head.html` (`<meta name="robots" content="noindex">` on a closed room or rack page),
* a site `layouts/sitemap.xml` (Hugo's sitemap fields, skipping closed sections; observed
  that the override is picked up on 0.170.0),
* `section.html` (a closed room or rack page shows a "Closed: no posts yet" notice).

**H. The switch** (`_partials/switch.html`, on the home page only)

* Markup: `<nav aria-label="Server rooms"><ol class="switch">`, one `<li>` per room in weight
  order: the port (RJ45 socket and its LED), the cable and plug (`aria-hidden`, CSS borders
  and gradients; inline SVG allowed for the plug), and the label tag. Open room: the label
  is `<a href="/<room>/">`, LED lit (`--led`). Closed room: the label is a `<span>` with
  visually hidden "closed, no posts yet", LED unlit (no glow), so state is not carried by
  colour alone (WCAG 2.x SC 1.4.1).
* The unlit port uses its own token (`--port-unlit`); the `--led-off` ban
  (`scripts/check.sh:559`) stays, protecting units, and blank units never use the port token.
* Port count = number of rooms (7 now), generated from the room list, never hard-coded.
* Wide screens: the switch is a 1U faceplate across the container (1120px, `main.css:492-494`),
  ports in a row (`grid-template-columns: repeat(N, minmax(0, 1fr))` via an inline custom
  property, or `auto-fit`), cables drop vertically to label tags under each port.
  Narrow screens (below 600px, the existing breakpoint): the same `<li>`s become rows: the
  port at the left on a vertical faceplate strip, the cable runs right, the label is
  horizontal. No fixed width >= 400px; labels wrap rather than truncate.
* Clicking a label opens the room page. The home floors are not anchors of the switch.

**D1. Home server view** (`_partials/floor.html`, shared with the room page): for each open
room in weight order, a section with the room heading (linked to the room page, plate if
any) and its racks in miniature, i.e. ADR 0002's compact racks (`rack.html` compact: label,
LED, post title), every rack of the room including empty ones; an empty rack's name is not a
link. At launch: Mindset (2 racks, 6 units, 1 live) and Homelab (4 racks, 12 units, 1 live).

**I2. Home intro.** The console keeps its look (`main.css:734-807`) but is centered in the
room container: the lead (`.Summary` up to `<!--more-->`, author-written, 2-3 sentences)
centered, a `<details><summary>Why this blog</summary>` holding `.ContentWithoutSummary`
(observed on 0.170.0) left-aligned at the 740px measure, then "Start reading" (first
published unit of the first open rack of the first open room). Order on the page: console,
switch, server view.

**J. Room and rack pages**

* Room page (`/<room>/`, `section.html` when the section's parent is home): band with kicker
  "Server room", the room title and plate; the room intro; the floor (`floor.html`, its racks
  compact, every rack name linked when open). No feed, no pagination.
* Rack page (`/<room>/<rack>/`): ADR 0002's rack page with the band kicker becoming a
  breadcrumb "<Room> · Rack" (room linked); intro; the full rack (cards with date and
  summary, "Planned" on titled blanks).
* Post page: ADR 0002's page plus the breadcrumb kicker "<Room> · <Rack>" in the band (both
  linked); the rack box "U01 of 3 · <rack>" and prev/next "Previous unit" / "Next unit"
  within the rack (G1).
* Tag pages: the unit kicker (`layouts/term.html:12-13`) names "<Room> · <Rack>".

**K. Redirects.** None. Nothing has been published under `/server-room-1/...` (giscus ids
empty, no deploy of ADR 0002 URLs to keep), so `/server-room-1/` must simply not exist;
a check asserts `public/server-room-1` is absent and no `aliases` remain.

**L. RSS.** One site feed, unchanged (`layouts/home.rss.xml`: every regular page is a post);
`[outputs] section = ["html"]` keeps rooms and racks feedless. Per-room feeds are deferred
(see Open questions).

### Consequences

* Good, because membership and depth are enforced by the tree and `errorf`, and "open" is
  computed once: the first published post opens its rack and room everywhere at once.
* Good, because URLs are short and thematic (`/homelab/networking/cgnat/`) and contain no
  ordering number, so racks and units can be reordered freely.
* Good, because publishing stays a one-file edit when the unit was not planned, two files
  when it was (the ADR 0002 warning still catches a leftover `planned` entry).
* Good, because the switch is generated from the rooms, so an eighth room adds a port with no
  template change.
* Bad, because closed room and rack pages exist at guessable URLs (unlinked, noindex, out of
  the sitemap) and the site now owns a sitemap template.
* Bad, because moving a rack to another room, or a post to another rack, changes URLs;
  after giscus is enabled that needs `aliases` and orphans threads. Settle slugs first.
* Bad, because the home page is longer: console, switch, two floors with 18 units (2 live).
* Bad, because the switch is a new responsive component with two layouts to keep working
  (CSS only; no fixed widths allowed).
* Neutral: `section.html` branches on depth (room vs rack); the body class
  `section-<room>` (`layouts/baseof.html:6`) now names the room.

### Confirmation

Test-first: `scripts/check.sh` changes before the templates and the new assertions fail on
the current build.

* **Constants** (`scripts/check.sh:10-33`): a `ROOM_TABLE` (slug|title|plate|open) and a
  `RACK_TABLE` (room|slug|title|units|open) replace `ROOM`, `RACKS_PATH`, `RACK_TABLE`;
  `P1_PATH=/mindset/find-out/if-it-works-find-out/`,
  `P2_PATH=/homelab/operating-systems/my-relationship-with-operating-systems/`;
  `PLANNED_TITLES` becomes the titles of the four empty racks (no feed or sitemap may name
  them).
* **Pages (section 2):** 7 room pages and 6 rack pages exist; `public/server-room-1` absent;
  the alias-redirect checks (`:90-97`) are deleted; open rooms/racks are in `sitemap.xml`,
  closed ones absent and carrying `robots noindex`.
* **Posts (section 3):** rack boxes "U01 of 3 · If it works and you don't know why, find out"
  and "U01 of 3 · My relationship with operating systems" with two untitled blanks each
  (replacing `:299-316`); breadcrumb links room and rack; no prev/next.
* **Home (section 4):** console first, lead centered, the rest inside `<details>`, "Start
  reading" to P1; a `switch_dump` (port order, state lit/unlit, label text, href or none,
  screen-reader text): 7 ports in weight order, Mindset and Homelab lit and linked, the five
  others unlit, unlinked, "closed"; number of ports = number of rooms; floors = exactly the
  open rooms in order; `rack_dump` per floor (6 racks, units 3 each); empty racks' names
  unlinked; the `homeServerRoom` checks (`:425-433`) are deleted.
* **Room pages:** band "Server room" + title (+ plate), intro, floor; closed room shows the
  notice.
* **Fitness functions (section 4a):** every regular page is
  `content/<room>/<rack>/<folder>/index.md` (replacing `:274-276`); every room and rack
  folder has `_index.md`; room weights present and unique; rack weights unique per room
  (`:491-500`, new path; `:501` becomes the room and rack folder list); no `server-room` in `content/`, `layouts/`, `hugo.toml` or `public/`
  paths; no `homeServerRoom`, no `aliases` in `content/_index.md`; no room slug `tags`; the
  switch markup contains no `<script>`; `--led-off` and CSS counters stay banned; blank
  units never use `--port-unlit`. The hidden-section checks (`:480-490`) are deleted.
* **Contract fixtures (section 4f)**, extending the rack fixtures (`:572-...`) to rooms:
  (a) a new room with one rack and no post: unlit port, unlinked label, no floor, noindex,
  not in the sitemap; (b) the same with a published post: lit, linked, floor, sitemap;
  (c) a room whose only post is a draft: closed in a production build, open with
  `--buildDrafts`; (d) a post directly in a room, and a post in a rack folder without
  `_index.md`: the build fails naming the file; (e) duplicate room weights: the fitness
  check fails; (f) a 12-room fixture: 12 ports, no fixed width >= 400px. The existing
  rack-merge fixtures move to the new paths unchanged.
* Unchanged: fonts, giscus, speculation rules, hosts, dark-only, header checks (the header
  loop runs over home, a room, a rack and a post page).

Rough impact: sections 2, 3, 4, 4a and 4f are rewritten (well over a third of the checks);
the rest only changes paths.

## Pros and Cons of the Options

### A1. Three nested sections (chosen)

* Good, because the tree, the URLs and the model coincide, with no permalink config.
* Good, because rack slugs are scoped to their room.
* Bad, because a misplaced post folder is accepted by Hugo; needs the `errorf` and a check.

### A2. `server-room-1/` wrapper with permalink stripping

* Good, because a future "server room 2" grouping would have a place.
* Bad, because it keeps a folder level the author dropped, and URL patterns for rooms, racks
  and posts must be kept in sync with the tree.

### A3. Rooms as a taxonomy or data file

* Bad, for the reasons ADR 0002 gave against A1/A3 there: many-to-many, missing empty terms,
  no pages without a content adapter.

### B1. Planned racks as rack folders (chosen)

* Good, because one rack, one file, for its whole life; the intro can be written ahead.
* Bad, because an empty rack is a real section with a page (handled by C1).

### B2. Planned racks in the room's front matter

* Good, because a planned rack has no page by construction.
* Bad, because the rack definition moves files at the first post, unit plans nest inside
  room front matter, and two sources of racks must be merged and deduplicated.

### C1. Derived open state (chosen)

* Good, because nothing to flip and nothing to drift; drafts preview correctly.
* Bad, because closed pages exist (unlinked, noindex, no sitemap entry) and a sitemap
  template is added.

### C2. Stored build flags

* Good, because a closed room or rack has no URL at all.
* Bad, because a derived fact is stored per section, flipped by hand, and a closed rack page
  cannot be previewed with its draft.

### C3. No closed racks

* Good, because simplest.
* Bad, because it breaks the author's closed rule one level down and links pages of blanks.

### D1. Floors for open rooms only, empty racks shown (chosen)

* Good, because the switch shows every room once and the floors show only what can be
  entered; the roadmap of an open room stays visible.
* Bad, because a closed room's planned racks are not visible from the home page.

### D2. Floors for every room

* Good, because every room's roadmap is on the home page.
* Bad, because five empty floors at launch; closed state shown twice.

### D3. Open racks only

* Bad, because the roadmap inside open rooms disappears.

### E1. Padding to 3 everywhere (chosen) / E2. Padding only in racks with a post

* E1 good: one rule, uniform racks, unchanged partial. Bad: 12 of 18 home units are blanks.
* E2 good: fewer red blanks. Bad: two rules and new fixtures for a cosmetic gain.

### G1. Within the rack (chosen) / G2. Across racks of the room

* G1 good: follows the author's ordering exactly. Bad: the last post of a rack has no "next".
* G2 good: continuous reading. Bad: invents an order between topics.

### H1. Vertical cables everywhere

* Good, because one layout. Bad, because labels are sideways on a phone.

### H2. Same markup, two CSS layouts (chosen)

* Good, because labels stay horizontal and tappable on a phone, and it scales by rows.
* Bad, because two layouts to draw and test.

### H3. Two-row switch

* Bad, because more drawing, still cramped labels on a phone.

### I1 / I2 (chosen) / I3

* I1 keeps every word visible but is still a wall. I2 keeps every word, shows a short
  centered lead, costs one `<!--more-->`. I3 is cleanest but deletes content.

## Open questions (with the default the implementation uses)

1. **Rack and post slugs.** Default: rack slugs `mindset/find-out`, `mindset/teamwork`,
   `homelab/operating-systems`, `homelab/networking`, `homelab/proxmox`,
   `homelab/high-availability`; post folders keep their names. The author may prefer other
   slugs (e.g. renaming the Mindset post folder to `cpu-sticker` to avoid
   `/find-out/if-it-works-find-out/`); decide before giscus is enabled.
2. **Home intro.** Default: I2, with the lead being the first two paragraphs of
   `content/_index.md` and the rest in `<details>`; the author rewrites the lead freely.
3. **Spare switch ports.** Default: ports = rooms (7), no spare ports. Alternative: round up
   to 8 like a real switch, the spare port empty.
4. **3D Printing plate on the cable tag.** Default: the plate shows on the room floor heading
   and room page band, not on the cable tag.
5. **Per-room RSS.** Default: none. Adding it later is `outputs: [html, rss]` in a room's
   `_index.md` plus feed checks.

## More Information

* Supersedes ADR 0002 (status line updated). Kept from it unchanged: `planned` units in the
  rack front matter, the merge rules and errors of `rack-units.html`, the 3-unit padding,
  red steady blank LED, untitled blanks with no text, `unit` on posts, a single site feed.
* Docs to update with the implementation: README "Server rooms, racks and units", "Write a
  new chapter" (path `hugo new content <room>/<rack>/<post>/index.md`), the repository table
  and "Pages and speed"; `docs/Known_Issues.md` KI-4 (room and rack intros, paths) and KI-5;
  `hugo.toml` comments.
* Diagrams: a content-model diagram (room → rack → post, planned units) and a state diagram
  of a room/rack (closed → open on first published post).

### Evidence

Checked on Hugo 0.170.0 in a throwaway site outside the repository:
`content/homelab/operating-systems/my-os/index.md` builds at
`/homelab/operating-systems/my-os/` with no permalinks; the post reports `.Section` =
`homelab`, `.CurrentSection` = the rack, whose `.Parent` is the room; room and rack sections
with `_index.md` and no posts are built and listed by `.Sections`; `.RegularPagesRecursive`
of a room counts its posts (0 for an empty room); a `layouts/sitemap.xml` replaces the
embedded sitemap; `.Summary` and `.ContentWithoutSummary` split the home body at
`<!--more-->`; `[cascade.target] kind = "page"` keeps bundle files unpublished.
