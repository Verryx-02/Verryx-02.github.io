---
status: accepted
date: 2026-11-14
decision-makers: Francesco Verrengia
---

# Use Hugo as the static site generator

## Context and Problem Statement

The blog documents a long-running homelab series and is hosted for free on GitHub Pages as the
user site `verryx-02.github.io`. It needs a toolchain that turns Markdown posts (with images
next to them) into a static site with an RSS feed, taxonomies (series, tags) and a table of
contents per post, and that GitHub Actions can build and deploy on every push to `main`.
Which tool should generate the site?

## Decision Drivers

* Single binary: nothing to install beyond one executable, locally and in CI; no language
  runtime or dependency tree to keep up to date.
* Fast builds that stay fast as the series grows to many posts with images.
* Deployment through GitHub Actions with the official Pages actions.
* Built-in support for the needed features: page bundles, taxonomies, RSS, table of contents,
  syntax highlighting, permalinks by date.
* Full control over templates and CSS, so the design is original and owns no third-party theme.

## Considered Options

* Hugo
* Jekyll
* Astro
* Plain hand-written HTML

## Decision Outcome

Chosen option: **Hugo**, because it is the only option that meets every driver at once: one
static binary, builds in milliseconds, and every needed feature (bundles, taxonomies, RSS,
`.TableOfContents`, Chroma highlighting, permalink patterns) is built in. The version is pinned
in `.github/workflows/hugo.yml` (`HUGO_VERSION`) and the same version is used locally.

### Consequences

* Good, because local setup is `brew install hugo` and CI downloads a single `.deb`.
* Good, because templates and CSS live in this repository (`layouts/`, `assets/`), with no
  theme submodule to track.
* Bad, because Go templates are less familiar than JavaScript components, and Hugo's template
  lookup rules changed in v0.146; upgrades need the pinned version bumped deliberately and
  `scripts/check.sh` run before merging.
* Neutral: the standard (non-extended) edition is enough because the CSS is plain CSS.

### Confirmation

`scripts/check.sh` builds the site with Hugo and asserts on the generated output (post
permalink, table of contents, home listing, feed, allowed external hosts).

## Pros and Cons of the Options

### Hugo

* Good, because it is a single Go binary with no runtime dependencies.
* Good, because builds are very fast and scale to thousands of pages.
* Good, because page bundles keep each post's images next to its Markdown.
* Bad, because the Go template syntax has a learning curve.

### Jekyll

* Good, because GitHub Pages can build it natively without a workflow.
* Bad, because it needs a Ruby toolchain and gems locally, and the native Pages build allows
  only a fixed plugin set.
* Bad, because builds slow down noticeably as the number of posts grows.

### Astro

* Good, because components and islands allow rich interactivity.
* Bad, because it brings a Node.js toolchain and an `npm` dependency tree to maintain, which is
  more than a text-first blog needs.

### Plain hand-written HTML

* Good, because there is no build step at all.
* Bad, because navigation, feed, tag pages and the table of contents must be maintained by hand
  for every post, which does not scale to a long series.
