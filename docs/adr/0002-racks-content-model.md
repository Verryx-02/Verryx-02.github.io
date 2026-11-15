---
status: "superseded by ADR-0003"
date: 2026-11-15
decision-makers: Francesco Verrengia
---

# Replace series with racks: one Hugo section per rack inside a server room, planned units in the rack's front matter

## Context and Problem Statement

The blog has one content grouping today, the `series` taxonomy (`hugo.toml:46-48`), with a
single term, *Homelab journey* (`content/series/homelab-journey/_index.md`). Posts join it
with `series:` and `part:` (`content/posts/*/index.md`, `archetypes/posts.md:5-9`). The
series drives the post page box "Part N of M" and the prev/next links
(`layouts/page.html:7-8,19-33,51-63`, `layouts/_partials/series-info.html`,
`layouts/_partials/series-parts.html`), the "Start here" card
(`layouts/_partials/start-here.html`, `params.featuredSeries` at `hugo.toml:19`), the
card kicker and unit label (`layouts/_partials/post-card.html:15-26`) and the series page
(`layouts/term.html:9-16`). The home page is one chronological list of every post
(`layouts/home.html:3-18`) drawn as a single server rack: the frame (top cap with a fixed
label plate "verryx-02 · homelab rack · 42u", rails, plinth) is painted on `.main` itself
(`assets/css/main.css:228-302`, plate text at `:249`), so every page is that one rack.

The author has decided to drop series and organize the blog as **racks** in a **server
room**:

1. A rack is a macro-topic *and* an ordered sequence of chapters (units). Each post belongs
   to exactly one rack and has a position in it.
2. Racks, in order: Mindset; Homelab; Software Engineering; Cybersecurity; AI;
   3D Printing (plate subtitle "Voron Trident"); Future projects.
3. Empty racks are shown. A position without a published chapter is a **blanking panel**:
   a unit with no body text, a red status LED (published units keep the green one), not
   clickable. A blank shows its planned chapter title; an untitled blank shows no text.
4. Every rack shows at least 3 units.
5. URLs have the form `/server-room-1/racks/<rack>/<chapter>/`, e.g.
   `/server-room-1/racks/homelab/proxmox/`; more server rooms may follow.
6. The design language stays: dark, ice-blue accent, D-DIN / Iosevka, the rack metaphor.

Nothing is published yet, so URLs may change freely. Comments (giscus) are configured with
`mapping = "pathname"` (`hugo.toml:29`) but not enabled yet (`repoId`/`categoryId` empty,
`hugo.toml:26,28`): once they are, a URL change orphans that page's discussion.

Questions decided here: (A) how a rack is modelled in Hugo, (B) how blanking panels are
represented, (C) how the home, rack and post pages present racks, (D) what the change
means for `scripts/check.sh` and the docs.

## Decision Drivers

* **Faithful model.** "Exactly one rack per post" and "a rack is ordered" should hold by
  construction, or be checked by the build, not left to discipline.
* **No leaks.** A blanking panel must never become a URL, an RSS item, a sitemap entry, a
  tag-page entry or a card counted as a post.
* **Author workflow.** Planning a chapter, drafting it, and publishing it should be few,
  obvious steps; a draft must not make its planned blank disappear from the live site.
* **Testability.** Every rule is assertable on the built output by `scripts/check.sh`, the
  site's only test suite, which CI runs before deploying (README "Deploy").
* **Constraints kept.** No JavaScript beyond giscus (README "Pages and speed"), no About
  page (`scripts/check.sh:66,553-560`), dark only, no fixed width >= 400px
  (`scripts/check.sh` section 6), no WARN in the build log (`scripts/check.sh:54-59`).
* **URL durability** once giscus is switched on (pathname mapping).
* **Room for more server rooms** without restructuring server room 1.
* **Migration cost** in templates, CSS and the ~320 existing checks.

## Considered Options

**A. Rack model**

* A1. A `racks` taxonomy: term pages `content/racks/<slug>/_index.md`, posts stay in
  `content/posts/` with `racks: homelab` and a unit number.
* A2. One nested Hugo section per rack: `content/<room>/racks/<rack>/_index.md` plus
  chapter bundles `content/<room>/racks/<rack>/<chapter>/index.md`.
* A3. A data file `data/racks.yaml` defining the racks; posts carry a plain `rack:` param.

**B. Blanking panels**

* B1. Blank content files: a chapter bundle with `title`, `unit`, `blank: true` and
  `build: {render: never, list: local}`, no body.
* B2. A `planned:` list in the rack's own `_index.md` front matter
  (`- {unit: 2, title: "Networking"}`), merged with the published chapters by unit number.
* B3. A central data file `data/racks.yaml` listing the planned units of every rack.
* B4. A fixed capacity per rack (`capacity: 6`), positions without a chapter auto-filled
  with anonymous blanks.

**B'. Where the 3-unit minimum lives**

* B'1. Template-level padding: `rack-units.html` pads every rack with untitled blanks up to
  3 positions.
* B'2. Explicit untitled entries in `planned` (`- {unit: 3}`) in every rack that needs them.

**C. Presentation**

* C1. Stacked racks: the home page shows the seven racks one under another in today's
  740px column, each unit a full card with summary.
* C2. Server-room row: on wide screens the home page is a row of narrow racks side by side
  (compact units: label, LED, title); each rack has its own page drawn as today's single
  full-width rack with intro and full cards; stacked on narrow screens.
* C3. Rack directory: the home page lists seven rack cards (name, plate, unit count), and
  units appear only on the rack pages.

## Decision Outcome

Chosen options: **A2** (one section per rack, inside a server-room section), **B2**
(planned units in the rack's front matter), **B'1** (padding to 3 in the template), **C2**
(server-room row on the home page, full rack per rack page).

* **A2**, because the content tree then *is* the information architecture: a chapter
  folder can sit in only one rack folder, so "exactly one rack" holds by construction, and
  the rack's definition (title, order, plate, intro, plan) lives next to its chapters. The
  required URLs `/server-room-1/racks/<rack>/<chapter>/` are Hugo's default path-based URLs
  for that tree, so no permalink configuration is needed. A taxonomy (A1) is Hugo's
  many-to-many classifier, the right tool for tags, and would need a check to forbid a
  second rack. A3 builds no rack pages at all without a content adapter.
* **B2**, because blanks are then not pages at all, which removes the leak risk at the
  root, and the workflow keeps the blank visible while its chapter is a draft (B1 cannot:
  turning the blank file into a draft removes it from production). The rack's roadmap is
  readable in one file. B3 separates the plan from the rack it belongs to; B4 cannot name a
  planned chapter.
* **B'1**, because the minimum is a presentation rule of the whole site, so it belongs in
  one place: changing it is a one-line edit, and `planned` keeps listing only real plans.
  B'2 would put 15 meaningless entries into five racks on day one, each to be deleted or
  renumbered when a real unit takes its place.
* **C2**, because it is the only layout that shows all seven racks, including the empty
  ones the author wants visible, in one screen on desktop while keeping today's readable
  full-width rack for reading. C1 pushes most racks below the fold; C3 drops the rack
  metaphor from the home page.

### Concrete shape of the decision

**Content tree and URLs**

```text
content/
  _index.md                         home: the site intro; aliases for the two hidden pages
  server-room-1/
    _index.md                       server room 1 (title, weight); not rendered
    racks/
      _index.md                     anchor only; not rendered
      mindset/_index.md             rack (title, weight, plate, description, planned; body = intro)
      mindset/if-it-works-find-out/index.md      chapter, unit 1
      homelab/_index.md
      homelab/my-relationship-with-operating-systems/index.md   chapter, unit 1
      software-engineering/_index.md
      cybersecurity/_index.md
      ai/_index.md
      3d-printing/_index.md
      future-projects/_index.md
```

* Chapter URL = `/server-room-1/racks/<rack>/<folder>/`, rack page =
  `/server-room-1/racks/<rack>/`. The URL follows the folder name, so editing a title no
  longer changes the URL (today it does: `:slug` falls back to the title, README:49-50).
  The `[permalinks.page] posts` entry (`hugo.toml:43-44`) is removed and none is added.
* **The home `/` renders server room 1.** `/server-room-1/` and `/server-room-1/racks/`
  would otherwise be list pages duplicating it. Both `_index.md` files carry
  `build: {render: never, list: never}`, so Hugo builds no page and no sitemap entry for
  them, and the home's `content/_index.md` lists both paths under `aliases`, so Hugo writes
  a redirect to `/` at each (an `<meta http-equiv="refresh">` page with a canonical link to
  `/`). A visitor who trims a chapter URL lands on the home page instead of a 404, and no
  content exists at two URLs.
* The home page finds its room through `params.homeServerRoom = "server-room-1"` in
  `hugo.toml`. A parameter is needed because a section with `list: never` is absent from
  `site.Sections` (observed); the template uses `site.GetPage` and fails the build
  (`errorf`) if the name matches no server room.
* Chapters have `.Section` = `server-room-1` (the top-level section); the rack is the
  chapter's `.CurrentSection`, the room is the rack's `.Parent.Parent`. Templates that
  today test `eq .Section "posts"` (`layouts/page.html:6`, `layouts/home.rss.xml:3`) test
  for a regular page instead: every regular page is a chapter (enforced by a fitness
  function below), and the site feed lists the chapters of every server room.

**Future server rooms.** A second room is a sibling tree,
`content/server-room-2/{_index.md, racks/_index.md, racks/<rack>/...}`, with its own rack
folders: rack slugs are scoped to their room, so a `homelab` rack can exist in both.
Nothing in server room 1 moves, so its URLs (and comment threads) survive. What changes
then is the home: either `/` keeps rendering the room named by `params.homeServerRoom`
and each other room gets a real, rendered `/server-room-N/` page (its `render: never` and
the home alias for it go away), or `/` becomes an index of rooms and every room renders
at `/server-room-N/`; the header would need a way to move between rooms. That choice, the
navigation between rooms and the feed per room are left to a new ADR when a second room
is planned.

**Rack and chapter front matter**

* Rack (`<room>/racks/<rack>/_index.md`): `title`, `weight` (rack order, unique within the
  room), `plate` (optional subtitle on the label plate), `description` (optional, meta
  description and teaser), `planned` (optional list of `{unit, title}`; `title` optional).
  The body is the rack's intro, shown on the rack page.
* Chapter (`<room>/racks/<rack>/<folder>/index.md`): `title`, `date`, `draft`, `unit`
  (integer >= 1, required), `tags`, optional `summary`. The field is renamed from `part` to
  **`unit`**: it is the number on the panel ("U01") and series vocabulary is gone. `weight`
  stays unused for ordering (README "Posts in a series" explains why).
* `archetypes/posts.md` is replaced by `archetypes/default.md` holding the chapter front
  matter, so `hugo new content server-room-1/racks/<rack>/<folder>/index.md` works in any
  room (Hugo picks an archetype by top-level section, which would otherwise need one file
  per room). Rack `_index.md` files are rare and written by hand.

**Initial content**

| Rack (folder) | weight | plate | Units |
|---|---|---|---|
| Mindset (`mindset`) | 1 | | U01 "If it works and you don't know why, find out" (published); U02 planned "Working in a team"; U03 untitled blank (padding) |
| Homelab (`homelab`) | 2 | | U01 "My relationship with operating systems" (published); U02 planned "Networking"; U03 planned "Proxmox configuration" (folder `proxmox` once written); U04 planned "Geo-distribution and high availability" |
| Software Engineering (`software-engineering`) | 3 | | U01-U03 untitled blanks (padding) |
| Cybersecurity (`cybersecurity`) | 4 | | U01-U03 untitled blanks (padding) |
| AI (`ai`) | 5 | | U01-U03 untitled blanks (padding) |
| 3D Printing (`3d-printing`) | 6 | Voron Trident | U01-U03 untitled blanks (padding) |
| Future projects (`future-projects`) | 7 | | U01-U03 untitled blanks (padding) |

Homelab will get one chapter per hosted service between "Proxmox configuration" and
"Geo-distribution and high availability": the author renumbers the later `planned` units
(and chapters, if any) when inserting them. Unit numbers are not in URLs, so nothing breaks.
Padding is not written in any `planned` list.

**Other configuration**

* `[outputs] section = ["html"]`: no per-rack or per-room feeds (see Consequences). The
  site feed (`layouts/home.rss.xml`) lists chapters as above.
* The `[[cascade]]` that turns off `publishResources` (`hugo.toml:37-41`) targets
  `{/server-room-*/racks/**}` instead of `/posts`.
* Removed: the `series` taxonomy (`hugo.toml:47`), `params.featuredSeries` (`hugo.toml:19`),
  the `posts` permalink (`hugo.toml:44`), `content/series/`, `content/posts/`,
  `archetypes/posts.md`.

**Templates**

* `_partials/rack-units.html` (replaces `series-parts.html`), called through
  `partialCached` keyed by the rack: returns the rack's units in order as dicts
  `{unit, title, page}` where `page` is the published chapter or `false` for a blank, and
  `title` is empty for an untitled blank. Merge rule: chapters and `planned` entries by
  `unit`; a chapter wins over a planned entry at the same unit; positions 1..max with
  neither become untitled blanks; then the list is **padded with untitled blanks up to 3
  positions** (the minimum is one constant in this partial, or a site param
  `rackMinUnits = 3`). Errors (`errorf`, build fails): a chapter without `unit`, a `unit` < 1
  or not an integer, two chapters with the same `unit`. Warning (`warnf`, fails
  `check.sh`): a non-draft chapter and a planned entry share a unit, meaning the planned
  entry was not removed on publishing.
* `_partials/rack-info.html` (replaces `series-info.html`): for a chapter returns
  `{rack, units, number, total, prev, next}`; `total` is the number of positions including
  blanks and padding ("U01 of 3" for Mindset, "U01 of 4" for Homelab); `prev`/`next` are the
  nearest *published* chapters in the same rack, skipping blanks; no link crosses racks.
* `_partials/unit.html` (replaces `post-card.html`): one 1U panel. Published: unit label,
  green LED, linked title, and on the rack page the date and summary. Blank: unit label in
  the ear, red steady LED (no activity animation, no hover slide), no `<a>`. A titled blank
  shows its planned title and, on the rack page, "Planned" where the date would be; an
  **untitled blank shows no text in the panel body**. Each blank carries a visually hidden
  text for screen readers ("planned, not yet published" or "empty position"), so status is
  not conveyed by colour alone (WCAG 2.x SC 1.4.1) and no list item is announced as just
  "U03".
* `_partials/rack.html`: a rack frame (cap with label plate from the rack's title and
  plate, rails, plinth) around an `<ol>` of units; `compact` mode for the home page.
* The rack frame moves from `.main::before/::after` (`assets/css/main.css:230-302`) to a
  `.rack` component, so a page can hold several racks; the plate text comes from markup
  (`content: attr(data-plate)` or a real element) instead of the hard-coded string at
  `main.css:249`. New colour token for the blank LED (not named `--led-off`, which
  `scripts/check.sh:381` forbids).
* `home.html`: first the console unit (today's `.start-here` styling,
  `main.css:585-690`) with the site intro: the body of the former
  `content/series/homelab-journey/_index.md`, moved to `content/_index.md` and reworded
  from "this series" to "this blog", plus a "Start reading" link to the first published unit
  of the first rack by weight (Mindset U01). Then the server-room row of the seven compact
  racks of `params.homeServerRoom` in `weight` order, each showing **all** its units
  (titles only), the rack title linking to the rack page. Grid columns use
  `minmax(<400px, 1fr)` so no fixed width >= 400px appears; below 1000px the racks stack.
  Racks in one grid row stretch to equal height, like real racks of the same size.
* `section.html` becomes the rack page: band with "Rack" kicker and the rack title, intro
  card, then one full-width rack with every unit (published with date and summary, blanks
  as above).
* `page.html`: the series box becomes a rack box: "U01 of 3 · Mindset" (rack linked),
  then the patch-panel list of every unit, the current one lit, published ones linked,
  blanks unlinked with the red port and their title (none if untitled). Prev/next labels
  become "Previous unit" / "Next unit" and appear only when a published neighbour exists.
* Removed: `start-here.html`, `series-info.html`, `series-parts.html`, the series branches
  in `term.html:2,9-16` and `taxonomy.html:13-17` (tags keep both templates).

**Author workflow**

1. Plan a chapter: add `- {unit: 2, title: "Networking"}` under `planned:` in
   `content/server-room-1/racks/homelab/_index.md`. The red blank with its title appears on
   the next build.
2. Draft it: `hugo new content server-room-1/racks/homelab/networking/index.md`, set
   `unit: 2`. The live site still shows the blank (drafts are not built);
   `hugo server -D` shows the chapter in its place.
3. Publish it: set `draft: false` and delete the planned entry. If the entry is left
   behind, the chapter still wins, but the build warns and `check.sh` fails.
4. Reorder or insert: renumber `unit` in chapters and planned entries; URLs do not contain
   the unit, so nothing breaks.

### Consequences

* Good, because "one rack per chapter" and "units in order" are enforced: by the folder
  tree and by build errors on a missing or duplicate `unit`.
* Good, because a blank is not a page: no URL, no RSS item, no sitemap entry, no tag-page
  entry, no `hugo list` row, by construction. The existing post counting in
  `scripts/check.sh:152-157` (`hugo list published`) keeps counting real chapters only,
  once its `,page,posts` filter matches the new section.
* Good, because `/series/` and `/posts/` stop existing, which closes KI-1
  (`docs/Known_Issues.md`), every rack page is linked from the home page, and the two
  hidden room pages redirect to `/` rather than duplicating it.
* Good, because URLs follow folder names, stable under title edits, and a second server
  room adds a sibling tree without touching room 1's URLs.
* Bad, because URLs are long (`/server-room-1/racks/homelab/proxmox/`), the price of
  the room level the author wants.
* Bad, because moving a chapter to another rack changes its URL. Before giscus is enabled
  this is free; afterwards it needs an `aliases` entry and orphans the comment thread
  (pathname mapping). Settle the rack of existing chapters before enabling comments.
* Bad, because publishing touches two files (the chapter and the rack's `planned` list);
  the build warning makes a forgotten entry visible.
* Bad, because the hidden sections, the home aliases and `params.homeServerRoom` are three
  coupled configuration details; each gets a comment in place and a check.
* Bad, because the rack frame CSS must be refactored from a page-level decoration into a
  component, and the home page needs a wider container than the 740px measure
  (`main.css:95,220-226`); the header inner already allows 1120px (`main.css:344`).
* Bad, because a compact home unit has room for a title only; summaries move to the rack
  page.
* Neutral: no per-rack RSS. Hugo would build one per section by default; it is switched off
  to keep a single checked feed. Tag feeds stay as today.
* Neutral: at launch the home page shows 22 units, 2 of them published, and five racks of
  untitled red blanks; that is the author's stated intent.

### Confirmation

Test-first: `scripts/check.sh` is changed before the templates, and the new assertions
fail on the current build. CI already runs it before every deploy.

Assertions replaced or added:

* **Pages (section 2):** every rack page `/server-room-1/racks/<rack>/` exists (7);
  `/server-room-1/` and `/server-room-1/racks/` are redirects to `/` (meta refresh,
  canonical `/`) and are absent from `sitemap.xml`; `/posts/` and `/series/` are not built;
  the chapter paths become `/server-room-1/racks/mindset/if-it-works-find-out/` and
  `/server-room-1/racks/homelab/my-relationship-with-operating-systems/` (`P1_PATH`,
  `P2_PATH`, `SERIES_PATH` at `scripts/check.sh:10-16`).
* **Post pages (section 3):** rack box says "U01 of 3" and links Mindset on P1, "U01 of 4"
  and links Homelab on P2; the current unit is `aria-current`; blanks in the box have no
  `<a>`; P1's box lists "Working in a team"; neither post has prev/next (no published
  neighbour). Replaces `scripts/check.sh:185-204`.
* **Home (section 4):** the console unit comes first, contains the intro (e.g. "This is my
  story"), says "this blog" and not "this series", and its "Start reading" link points to
  P1; seven racks in weight order (Mindset first, Future projects last); 3D Printing plate
  shows "Voron Trident"; every rack title links to its page; unit counts per rack are 3, 4,
  3, 3, 3, 3, 3; units in unit order with labels U01..; published units link to their
  chapter and carry the green-LED class; blanks carry the blank class and no `<a>`; titled
  blanks show their planned title ("Working in a team", "Networking", "Proxmox
  configuration", "Geo-distribution and high availability"); untitled blanks have an empty
  visible body; the number of linked units equals the number of published chapters.
  Replaces `scripts/check.sh:228-255`; the `featuredSeries` loop (`:284-296`) and the series
  list checks (`:219-227`) are deleted. A scratch build with `HUGO_PARAMS_HOMESERVERROOM`
  set to an unknown room fails.
* **Rack page:** band title, intro before units, full cards with date and summary, titled
  blanks with "Planned", meta description falls back to the site description when the rack
  has no `description` (as `scripts/check.sh:211-212` does today).
* **Scratch-content fixtures** (the pattern of `scripts/check.sh:383-409`), acting as the
  contract tests of `rack-units.html`: (a) units 1 and 3 published, 2 planned: order
  U01..U03, U01 "Next unit" goes to U03; (b) a gap at unit 2 with nothing planned: an
  untitled blank appears; (c) a rack with one published unit and nothing planned: padded
  to U01..U03; a rack with 5 units: not padded, not truncated; (d) a published chapter and
  a planned entry at the same unit: build log has a WARN; (e) the same with a draft chapter
  in a `--buildDrafts` build: no WARN, chapter shown; (f) a chapter without `unit`: build
  fails; (g) two chapters with the same `unit`: build fails.
* **Feed and sitemap:** `index.xml` items are exactly the published chapters; no planned
  title appears in `index.xml` or `sitemap.xml`; no `index.xml` under `public/server-room-1/`.
* **Header loop** (`scripts/check.sh:327`) runs over the home, a chapter and a rack page.
* **Page bundles** (section 4e) keep working with the cascade path moved to
  `/server-room-*/racks/**`.

Fitness functions (all in `scripts/check.sh`):

* Every regular page reported by `hugo list all` has a path
  `content/server-room-<n>/racks/<rack>/<folder>/index.md` (exactly one rack, no stray
  content, so "regular page" and "chapter" mean the same thing).
* No `series:` or `part:` key in any content front matter; no `series` taxonomy in
  `hugo.toml`; no `series` in `layouts/` file names or template code.
* Every `server-room-<n>/_index.md` and `server-room-<n>/racks/_index.md` has
  `render: never`.
* Rack `weight` values are present and unique within a room.
* No `<a>` inside a blank unit anywhere in `public/`.
* Unit labels come from markup, never a CSS counter (keeps `scripts/check.sh:381`).
* Existing guards stay: no WARN/ERROR, no JavaScript, no fixed width >= 400px, allowed
  hosts only.

## Pros and Cons of the Options

### A1. `racks` taxonomy

* Good, because it is the smallest change: the series code paths (`series-info.html`,
  `series-parts.html`, `term.html`) carry over almost one for one.
* Good, because posts keep living in one flat `content/posts/` and moving a post between
  racks is a one-line front matter edit.
* Bad, because a taxonomy is many-to-many: `racks: [mindset, homelab]` is valid Hugo, so
  "exactly one rack" needs its own check.
* Bad, because empty racks are easy to lose: a term with an `_index.md` and no posts is
  built, but it is missing from `site.Taxonomies.racks`; only
  `(site.GetPage "/racks").Pages` lists it (observed on Hugo 0.170.0).
* Bad, because it does not combine with blank content files (B1): a page with
  `build.list: local` is not in its term's `.Pages` (observed).
* Bad, because the URL form `/server-room-1/racks/<rack>/<chapter>/` would need permalink
  patterns built from a taxonomy value, and a second server room has no natural place.

### A2. One section per rack inside a server-room section (chosen)

* Good, because one folder = one rack enforces membership and co-locates the rack's
  definition, plan and chapters.
* Good, because the required URLs are Hugo's default for the tree, and a new server room
  is a sibling folder.
* Good, because empty sections with an `_index.md` are built and listed by `.Sections`
  (observed), and `weight` orders them.
* Bad, because the room and `racks` pages must be hidden and redirected to `/` to avoid
  duplicating the home page.
* Bad, because a chapter's URL depends on its rack (see Consequences).
* Neutral: Hugo's built-in `.PrevInSection`/`.NextInSection` sort by weight and date, not
  `unit`, and are not used; `rack-info.html` computes neighbours.

### A3. Data file plus `rack:` param

* Good, because all racks, their order and plates are in one file.
* Bad, because there are no rack pages unless a content adapter generates them, and the
  rack intro becomes Markdown inside YAML.
* Bad, because nothing ties `rack:` values to the file except a custom check, and it
  reimplements what sections and taxonomies give for free.

### B1. Blank content files with build options

* Good, because each unit, blank or not, is one folder; the folder listing shows the rack.
* Good, because publishing edits a single file (remove `blank` and `build`, write the body).
* Bad, because the draft step breaks it: while the chapter is being written it is either
  still a blank (and `hugo server -D` cannot preview it, `render: never`) or a draft (and
  the blank disappears from production).
* Bad, because a blank is still a page that every collection must exclude: with
  `render: never, list: local` it is out of `site.RegularPages`, the sitemap and
  `hugo list`, but it **is** in the default section RSS feed and in `.PrevInSection`
  (both observed on Hugo 0.170.0). Each new template is a new chance to leak.

### B2. `planned` list in the rack's front matter (chosen)

* Good, because blanks are data, not pages: nothing can leak.
* Good, because the draft workflow works unchanged (see Author workflow).
* Good, because a rack's plan is readable in its own `_index.md`, next to its intro.
* Bad, because publishing is a two-file edit, mitigated by the build warning.
* Neutral: explicit unit numbers allow writing chapters out of order (e.g. Proxmox before
  Networking), at the cost of renumbering when a chapter is inserted.

### B3. Central `data/racks.yaml`

* Good, because the whole roadmap of the site is one file.
* Bad, because a rack's data is split between its `_index.md` and the data file, keyed by
  slug strings that can drift apart silently.

### B4. Fixed capacity with anonymous blanks

* Good, because it is the least data: one number per rack.
* Bad, because planned chapters cannot be named, and the capacity is arbitrary. (Gap
  filling and the 3-unit minimum are kept inside B2/B'1.)

### B'1. Padding to 3 in the template (chosen)

* Good, because the rule lives in one place and changes with one edit.
* Good, because `planned` stays meaningful: every entry is a real plan or an intentional
  gap.
* Good, because padding disappears by itself when a rack reaches 3 real units.
* Bad, because the source files do not show the padded positions; the README must say so.

### B'2. Explicit untitled entries in `planned`

* Good, because what you see in the file is exactly what the rack shows.
* Bad, because five racks need three placeholder entries each today, which must be removed
  or renumbered as real units arrive, and a forgotten placeholder collides with a chapter.
* Bad, because the minimum is not enforced: a new rack without placeholders silently shows
  fewer than 3 units.

### C1. Stacked racks

* Good, because it is the smallest CSS change and keeps summaries on the home page.
* Bad, because seven caps and plinths make a long page; the lower racks, most of them
  empty, sit far below the fold, which defeats "empty racks are shown".

### C2. Server-room row plus full rack pages (chosen)

* Good, because the whole room is visible at once on desktop, and the rack page keeps
  today's look for reading.
* Bad, because the rack frame CSS needs refactoring into a component and a wider home
  container.
* Bad, because home units show titles only.

### C3. Rack directory

* Good, because it is simple and scales to many units.
* Bad, because the home page loses units, LEDs and blanks, the core of the metaphor.

## More Information

### Author's answers (2026-11-15)

1. Blank label: the planned title; an untitled blank shows no text. Every rack shows at
   least 3 units, padded with untitled blanks (B'1).
2. The old series intro moves to the home page, reworded from "this series" to "this blog".
3. URLs: `/server-room-1/racks/<rack>/<chapter>/`; more server rooms may follow.
4. The last rack is "Future projects".

### Docs to update with the implementation

* `README.md`: "Write a new post" (new path and archetype, `unit`), replace "Posts in a
  series" and "The 'Start here' card" with "Server rooms, racks and units" (rack front
  matter, `planned`, the 3-unit padding, the four-step workflow, `homeServerRoom`), the
  repository table, "Pages and speed" (home shows racks).
* `docs/Known_Issues.md`: close KI-1 (pages no longer built).
* `hugo.toml` comments (`featuredSeries`, the `titleCaseStyle` comment that cites
  "Homelab journey"; comments explaining `homeServerRoom` and the hidden sections).
* ADR 0001 stays as is (accepted; its mention of series is historical).

### Evidence

Hugo behaviour cited as "observed" was checked on Hugo 0.170.0 (the pinned version) in
throwaway sites outside the repository: a `content/server-room-1/racks/<rack>/<chapter>/`
tree builds at `/server-room-1/racks/<rack>/<chapter>/` with no permalink configuration;
chapters report `.Section` = `server-room-1` and the rack as `.CurrentSection`;
`server-room-1/_index.md` and `racks/_index.md` with `build: {render: never, list: never}`
produce no page and no sitemap entry while `site.GetPage` still returns them and their
`.Sections`; such a section is absent from `site.Sections`; `aliases` on the home write
meta-refresh redirects to `/` at both paths with no WARN; `render: never, list: local`
pages are present in the section's `.Pages`, absent from `site.RegularPages`, the sitemap
and `hugo list`, but present in the default section RSS and in `.PrevInSection`; such pages
are absent from their taxonomy term's `.Pages`; empty terms are missing from
`site.Taxonomies` but present in the taxonomy page's `.Pages`.
