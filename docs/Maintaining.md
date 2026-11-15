# Maintaining the site

How this blog is built, written, checked and deployed. The site is built with
[Hugo](https://gohugo.io) (see [ADR 0001](adr/0001-static-site-generator.md)) and deployed
to GitHub Pages by GitHub Actions. Templates and CSS are original and live in this
repository; there is no theme.

## Run it locally

```bash
brew install hugo        # standard edition is enough (plain CSS)
hugo version             # CI uses 0.170.0, see .github/workflows/hugo.yml
hugo server              # http://localhost:1313, reloads on save
hugo server -D           # same, including drafts
```

Before pushing, run the checks:

```bash
scripts/check.sh         # builds with --minify --gc and asserts on public/
```

## Server rooms, racks and units

The blog is a set of themed **server rooms** ([ADR 0003](adr/0003-themed-rooms-switch.md)):
Mindset, Homelab, Software Engineering, Cybersecurity, AI, 3D Printing and Future projects.
A room holds **racks**, one per topic; a rack holds **units**, one per post ("U01", "U02",
...). A position with no published post is a **blanking panel**: a red LED, no link, its
planned title if it has one, no text at all if it has none.

```text
content/
  _index.md                                    home page: the intro (lead <!--more--> the rest)
  mindset/_index.md                            a room: title, weight, plate; body = room intro
  mindset/find-out/_index.md                   a rack: title, weight, plate, planned units; body = rack intro
  mindset/find-out/cpu-sticker/index.md        a post (unit 1), with its images in the same folder
  mindset/teamwork/_index.md                   a rack with no post yet
  homelab/_index.md
  homelab/operating-systems/windows-to-proxmox/index.md
  ...
```

URLs follow the folders: a room is `/<room>/`, a rack `/<room>/<rack>/`, a post
`/<room>/<rack>/<post folder>/` (for example `/mindset/find-out/cpu-sticker/`). Changing a
title does not change a URL; renaming a folder, or moving a post to another rack or a rack to
another room, does. Settle these names before comments are switched on, because giscus files
each discussion under the page's URL (see "Comments").

**Open and closed.** A room or a rack is **open** when it holds at least one published post,
and **closed** otherwise. Nothing is stored: the first published post opens its rack and its
room on the next build (`layouts/_partials/is-open.html` is the only place the rule lives).
A closed room or rack still has its page, which says "Closed: no posts yet", but no page links
to it, it carries `<meta name="robots" content="noindex">` and it is left out of
`sitemap.xml` (`layouts/sitemap.xml`). With `hugo server -D` a draft counts, so a draft is
previewed in its open room and rack.

**A room** is a folder directly under `content/` with an `_index.md`:

```yaml
---
title: "3D Printing"        # the room name, on its switch port and its floor
weight: 6                   # room order (1 = first), unique among the rooms
plate: "Voron Trident"      # optional subtitle, on the room page and its home floor
description: ""             # optional: meta description of the room page (default: the site's)
---

The room's intro, shown on the room page above its racks.
```

**A rack** is a folder inside a room with an `_index.md`:

```yaml
---
title: "Networking"         # the name on the rack's label plate
weight: 20                  # rack order in the room, unique within the room (steps of 10 leave room to insert)
plate: ""                   # optional subtitle on the label plate
description: ""             # optional: meta description of the rack page (default: the site's)
planned:                    # optional: posts not written yet, as blanking panels
  - {unit: 1, title: "CGNAT"}
  - {unit: 2}               # a reserved position without a title
---

The rack's intro, shown on the rack page above its units.
```

Every rack shows at least 3 units: positions 1 to the highest `unit` used (by a post or a
planned entry) are filled in, gaps become untitled blanks, and racks with fewer than 3
positions are padded with untitled blanks (`layouts/_partials/rack-units.html`). The padding
is not written in `planned`, and it disappears by itself as real units arrive.

Every rack is one standard size, whatever its content. In miniature (home floors and room
pages) every rack has the same width and shows all its units, at least 3 (3U); a rack with
more units grows by whole units (nothing scrolls inside a rack). Racks in a row are
top-aligned and every row is centred. Every unit, live or blank, has the same height: a long title is cut to 2
lines with an ellipsis (the link and screen readers keep it whole), and so is a long rack
name on its label plate, which has a fixed height too, so racks side by side line up. On a
rack page every unit has the same height as well: title and opening text 2 lines each, all
units shown.

**The home page** opens with the console (no visible title): the intro's lead (the text before `<!--more-->` in
`content/_index.md`) centered, the rest inside a "More about this blog" disclosure, and a
"Start reading" button to the first published post of the first open rack of the first open
room. Below it is the **server hall**. At the top, the **core switch** (no title on its faceplate): one
port per room, in room order, each with a patch cable and a label with the room name (on
wide screens all ports share the faceplate evenly, and a long name wraps at its spaces,
never mid-word); ports come in eights like
a real switch, so after the rooms come spare ports up to the next multiple of 8 (7 rooms: 8
ports, 1 spare), each closed with a dust cap, unlit, with no cable. An open room has a green
LED, an ice-blue cable and a label that opens the room page; a closed room has an unlit LED,
a dark grey cable and a label that is not a link. Every cable runs from its label into one
of two vertical **cable trays** down the sides of the hall, one lane per room: the rooms on
the first half of the switch ports go to the left tray (rooms 1-4 of an 8-port switch, 1-8
of a 16-port one), the others to the right tray. A cable leaves its tray at its own room's
floor and runs across to the patch panel on that side of the room name (before the name for
a left-tray room, after it for a right-tray room; name and patch panel are centred in the
floor, above its centred rack rows), its LED lit like the switch port. The
switch-side runs never cross; a cable leaving the left tray lifts over the ones still in it,
because the left tray has to reverse the port order (port 1 is nearest it, room 1 leaves
first). Below the switch, the **server view** shows every room as a floor,
in room order. An open room's floor has all its racks in miniature (unit number, LED and
title), the room name links to the room page and a rack name to its rack page when the rack
is open. A closed room's floor names the room (no link; screen readers hear it is closed)
above one empty, powered-off rack: no name, three blanking panels with unlit LEDs. Pure HTML
and CSS: the cable geometry comes from inline custom properties: `--rooms`, `--ports` and
`--left` on the hall and `--i` on each port, so a new room needs no template change.

**A room page** shows the room's intro and all its racks in miniature. **A rack page** ("<Room>
· Rack" above the title) shows the rack's intro and its full units with date and opening text
("Planned" on titled blanks). **A post page** shows "<Room> · <Rack>" above the title, the
rack box "U01 of 3 · <rack>" with all the rack's units, and "Previous unit" / "Next unit"
links to the nearest published posts of the same rack, skipping blanks (never across racks).

## Write a new post

Every post is a *page bundle*: a folder inside its rack holding `index.md` and the images it
uses.

1. **Plan it** (optional): add it under `planned:` in the rack's `_index.md`, for example
   `- {unit: 2, title: "CGNAT"}`. The blanking panel with that title appears on the next
   build.
2. **Draft it**:

   ```bash
   hugo new content homelab/networking/cgnat/index.md
   ```

   This creates the folder from `archetypes/default.md` with `draft: true`. Fill in `title`,
   `tags` and **`unit`** (its position in the rack: 1, 2, 3, ...; required). While it is a
   draft the live site keeps showing the blank (and the rack and room stay closed if it is
   their first post); `hugo server -D` shows the post in its place.
3. Write in Markdown. `##` and `###` headings structure the post; there is no table of
   contents. The rack page, the meta description and the RSS item show the post's opening
   text; an optional `summary` field overrides it.
4. Put images in the same folder and reference them by file name with the site's `figure`
   shortcode (`layouts/_shortcodes/figure.html`, which replaces Hugo's built-in one):
   `{{</* figure src="photo.jpg" alt="What the photo shows" caption="Caption" width="400" */>}}`.
   It accepts `src`, `alt`, `caption` (Markdown) and `width` (display width in pixels,
   default the photo's own width). Hugo turns the photo into WebP copies at 400, 800, the
   display width and twice it (never larger than the original) and writes a `srcset`,
   explicit `width`/`height` and `loading="lazy"`, so the page does not jump while it loads.
5. **Publish it**: set `draft: false` **and delete its entry from `planned`**. If the entry is
   left behind, the post still takes the position, but the build warns and
   `scripts/check.sh` fails. A first post opens its rack and its room by itself.

To reorder or insert posts, renumber `unit` in the posts and the `planned` entries (unit
numbers are not in URLs). A post without `unit`, a `unit` that is not a whole number from 1
up, or two posts with the same `unit` in one rack fail the build with a message naming the
file. A post directly in a room folder, or in a folder without its own `_index.md`, fails the
build too. Do not use `weight` on posts: it is only the room and rack order.

**A new rack** is a new folder in its room with an `_index.md` (copy an existing one, pick a
`weight` between its neighbours). **A new room** is a new folder under `content/` with an
`_index.md` and the next `weight`: the switch gets a port for it on the next build, closed
until its first post. Do not name a room `tags` (that is the tag pages' URL).
`scripts/check.sh` keeps a table of the rooms and racks (`ROOM_TABLE`, `RACK_TABLE` at the
top): update it when you add, rename or open one.

## Layout of the repository

| Path | Content |
|---|---|
| `hugo.toml` | Site configuration: title, params, outputs, taxonomies, highlighting |
| `content/` | The home intro (`_index.md`) and the server rooms: `<room>/_index.md`, `<room>/<rack>/_index.md` and `<room>/<rack>/<post>/index.md` |
| `archetypes/default.md` | Front matter of a new post (`hugo new content ...`) |
| `layouts/` | Templates: `baseof.html`, `home.html` (console; the server hall: switch, server view, two cable trays), `section.html` (room and rack pages), `page.html` (post), `taxonomy.html`, `term.html` (tags), `sitemap.xml` (closed rooms and racks left out), `_partials/` (`is-open.html`, the open/closed rule; `switch.html`; `floor.html`; `rack-units.html` merges posts, planned units and padding; `rack-info.html`, `rack.html`, `unit.html`) |
| `assets/css/` | `main.css` (fonts, layout and the single dark colour scheme) and `syntax.css` (code colours) |
| `layouts/_shortcodes/figure.html` | Responsive images for posts (see "Write a new post") |
| `static/` | Files copied as-is: favicon, `fonts/` with the self-hosted fonts and their licences, and `css/giscus-rack.css` (the comments theme) |
| `scripts/check.sh` | Build and output assertions |

## Pages and speed

- **One home page for every room.** The home page shows the switch and every room, with
  every rack and unit of the open ones: there is no pagination and no `/page/N/` pages. Room, rack and tag
  pages are not paginated either. The only feed is the site's (`/index.xml`, the published
  posts); rooms and racks have none.
- **Fonts are self-hosted** in `static/fonts/` as WOFF2 files (see "Fonts" below). The
  `@font-face` rules are at the top of `main.css`; `head.html` preloads only the two faces
  used above the fold, `d-din-700.woff2` and `iosevka-etoile-400.woff2`. No request goes to
  Google Fonts or any other font host.
- **No stylesheet request, no JavaScript.** Production builds inline the minified CSS in
  every page's `<head>`; `hugo server` links it as a file so it reloads on save. The site
  ships no JavaScript: a `speculationrules` block in `head.html` (declarative JSON) lets
  supporting browsers prerender a page when its link is hovered, and CSS view transitions
  fade between pages while the header stays still (off under "reduce motion").
  The one exception is the giscus comments script on post pages, once comments are set up
  (see "Comments").
- **The header is fixed** to the top and the page does not bounce past either end
  (`overscroll-behavior: none`).

## Fonts

| Role (CSS token) | Family | Files in `static/fonts/` |
|---|---|---|
| Titles, wordmark (`--display`) | D-DIN | `d-din-400.woff2`, `d-din-700.woff2` |
| Kickers, meta lines, tags, footer (`--label`) | D-DIN Condensed | `d-din-condensed-400.woff2`, `d-din-condensed-700.woff2` |
| Reading text (`--serif`) | Iosevka Etoile | `iosevka-etoile-400.woff2`, `iosevka-etoile-400-italic.woff2`, `iosevka-etoile-700.woff2` |
| Code, dates, port numbers (`--mono`) | Iosevka | `iosevka-400.woff2` |

- **D-DIN** and **D-DIN Condensed** are by Datto, under the SIL Open Font License 1.1 with
  the Reserved Font Names "D-DIN" and "D-DIN Condensed" (`OFL-d-din.txt`). The files are
  shipped **unmodified** (full Latin, not subset): a modified copy could not keep the name.
  They have no width axis, so the CSS uses no `font-stretch`, and only weights 400 and 700.
- **Iosevka** and **Iosevka Etoile** are by Renzhi Li (Belleve Invis), under the SIL Open
  Font License 1.1 (`OFL-iosevka.txt`, no Reserved Font Name). The source files are the
  latin subsets of the `@fontsource/iosevka` and `@fontsource/iosevka-etoile` npm packages,
  subset again to Latin plus the arrows and the `▪ ▸ ◂ ●` symbols the design uses:

  ```bash
  pyftsubset IN.woff2 --unicodes="U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2190-2193,U+2212,U+2215,U+25AA,U+25B8,U+25C2,U+25CF,U+FEFF,U+FFFD" --flavor=woff2 --no-hinting --desubroutinize --layout-features='kern,liga,calt,ccmp,locl,mark,mkmk' --output-file=OUT.woff2
  ```

  `pyftsubset` comes with fontTools (`brew install fonttools`). The Iosevka `@font-face`
  rules carry the same `unicode-range`; `scripts/check.sh` asserts it.

## Comments

Each post ends with a comments panel by [giscus](https://giscus.app): comments are stored in
this repository's GitHub Discussions, and readers sign in with GitHub to write one. Until
`repoId` and `categoryId` are set in `hugo.toml`, nothing is rendered (no panel, no script).
One-time setup:

1. The repository must be **public**.
2. In *Settings → General → Features*, enable **Discussions**.
3. In the Discussions tab, create a category named **Comments** of type **Announcements**
   (only maintainers and giscus can open discussions in it).
4. Install the [giscus app](https://github.com/apps/giscus) on this repository.
5. On [giscus.app](https://giscus.app), enter the repository and choose the "Comments"
   category, then copy `data-repo-id` and `data-category-id` into `hugo.toml`:

   ```toml
   [params.giscus]
     repoId = "R_..."        # data-repo-id
     categoryId = "DIC_..."  # data-category-id
   ```

The other `[params.giscus]` values (discussion per page path, reactions, comment box on top,
English) are already set. The widget's colours come from `static/css/giscus-rack.css`, which
giscus loads from the published site; under `hugo server` it cannot reach `localhost`, so the
widget shows giscus's default theme there.

## Deploy

Every push to `main` runs `.github/workflows/hugo.yml`: it installs the pinned Hugo release
and `xmllint` (`libxml2-utils`), runs `scripts/check.sh`, builds the site with the base URL
GitHub Pages reports, uploads `public/` as a Pages artifact and deploys it. A failing check
fails the build job, so nothing is deployed. It can also be started by hand from the Actions tab (`workflow_dispatch`).

**One-time setting:** in the GitHub repository, open *Settings → Pages → Build and
deployment* and set **Source** to **GitHub Actions**.

To upgrade Hugo, change `HUGO_VERSION` in the workflow, upgrade the local binary to the same
version, and run `scripts/check.sh`.
