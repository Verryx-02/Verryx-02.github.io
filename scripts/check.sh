#!/usr/bin/env bash
# Build the site and assert on the generated output in public/.
# Usage: scripts/check.sh        (run from anywhere; exits non-zero on any failure)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SITE="https://verryx-02.github.io"
# Themed server rooms of topic racks (docs/adr/0003-themed-rooms-switch.md). A room or rack
# is open when it holds a published post, closed otherwise.
# ROOM_TABLE: the rooms in weight order, "slug|title|plate|open or closed".
ROOM_TABLE="mindset|Mindset||open
homelab|Homelab||open
software-engineering|Software Engineering||closed
cybersecurity|Cybersecurity||closed
ai|AI||closed
3d-printing|3D Printing||closed
future-projects|Future projects||closed"
# RACK_TABLE: the racks, room by room in room order, then in weight order,
# "room|slug|title|units shown|open or closed".
RACK_TABLE="mindset|find-out|Curiosity|3|open
mindset|teamwork|Working in a team|3|closed
homelab|operating-systems|Operating systems|3|open
homelab|networking|Networking|3|closed
homelab|proxmox|Proxmox configuration|3|closed
homelab|high-availability|Geo-distribution and high availability|3|closed"
# The two published posts: unit 1 of the first rack of Mindset and of Homelab.
P1_TITLE="If it works and you don't know why, find out"
P2_TITLE="My relationship with operating systems"
# Their racks: named apart from the posts they hold (a rack is a topic, a post one story on it).
R1_TITLE="Curiosity"
R2_TITLE="Operating systems"
FINDOUT_PATH="/mindset/find-out/"
OS_PATH="/homelab/operating-systems/"
P1_PATH="${FINDOUT_PATH}cpu-sticker/"
P2_PATH="${OS_PATH}windows-to-proxmox/"
P1_OUT="public${P1_PATH}index.html"
P2_OUT="public${P2_PATH}index.html"
FINDOUT_OUT="public${FINDOUT_PATH}index.html"
OS_OUT="public${OS_PATH}index.html"
MINDSET_OUT="public/mindset/index.html"
# The titles of the four racks without posts: shown as rack names, never in a feed or sitemap.
PLANNED_TITLES="Working in a team
Networking
Proxmox configuration
Geo-distribution and high availability"
WORKFLOW=".github/workflows/hugo.yml"

failures=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; failures=$((failures + 1)); }
check() { # check "description" command...
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi
}
check_none() { # check_none "description" LIST: pass when LIST is empty, else print it.
  if [ -z "$2" ]; then pass "$1"; else fail "$1"; printf '%s\n' "$2" | sed 's/^/        /'; fi
}

# --- 0. Tooling ---------------------------------------------------------------
if ! command -v hugo >/dev/null 2>&1; then
  echo "ERROR: hugo is not installed or not on PATH." >&2
  echo "       Install it with 'brew install hugo' (see docs/Maintaining.md), then re-run." >&2
  exit 2
fi
if ! command -v perl >/dev/null 2>&1; then
  echo "ERROR: perl is required by this script and was not found." >&2
  exit 2
fi

pinned="$(sed -n 's/^ *HUGO_VERSION: *\([0-9.]*\).*/\1/p' "$WORKFLOW" 2>/dev/null | head -n1 || true)"
local_ver="$(hugo version | sed -n 's/^hugo v\([0-9.]*\).*/\1/p')"
if [ -n "$pinned" ] && [ "$pinned" != "$local_ver" ]; then
  echo "WARN: local hugo $local_ver differs from the version pinned in $WORKFLOW ($pinned)."
fi

# --- 1. Build -----------------------------------------------------------------
echo "Building with hugo $local_ver ..."
log="$(mktemp "${TMPDIR:-/tmp}/hugo-check.XXXXXX")"
trap 'rm -f "$log"' EXIT
if ! hugo --minify --gc --cleanDestinationDir >"$log" 2>&1; then
  cat "$log"
  echo "ERROR: hugo build failed." >&2
  exit 1
fi
echo "Assertions:"
if grep -Eq '^(WARN|ERROR)' "$log"; then
  fail "build log has no WARN/ERROR lines"
  grep -E '^(WARN|ERROR)' "$log" | sed 's/^/        /'
else
  pass "build log has no WARN/ERROR lines"
fi

# --- 2. Pages exist -----------------------------------------------------------
check "Mindset U01 page exists at $P1_PATH" test -f "$P1_OUT"
check "Homelab U01 page exists at $P2_PATH" test -f "$P2_OUT"
check "home page exists" test -f public/index.html
check "no about page is built (public/about/ absent)" test ! -e public/about
check "RSS feed exists (public/index.xml)" test -f public/index.xml
check "tags taxonomy page exists" test -f public/tags/index.html
check "sitemap exists (public/sitemap.xml)" test -f public/sitemap.xml
# Every room and every rack has its page, open or closed; no room has a feed.
while IFS='|' read -r slug name plate state; do
  check "room page exists at /${slug}/ ($state)" test -f "public/${slug}/index.html"
  check "no feed under /${slug}/ (no per-room or per-rack RSS)" test -z "$(find "public/${slug}" -name '*.xml' 2>/dev/null)"
done <<EOF
$ROOM_TABLE
EOF
while IFS='|' read -r room slug name units state; do
  check "rack page exists at /${room}/${slug}/ ($state)" test -f "public/${room}/${slug}/index.html"
done <<EOF
$RACK_TABLE
EOF
# Server room 1 and its racks level are gone: no page, no redirect, no alias left.
check "no /server-room-1/ is built (public/server-room-1 absent)" test ! -e public/server-room-1
check_none "no page is a meta-refresh redirect (no aliases)" "$(find public -type f -name '*.html' -print0 | xargs -0 grep -lE '<meta http-equiv="?refresh' || true)"
check "no /posts/ section is built (public/posts/ absent)" test ! -e public/posts
check "no /series/ taxonomy is built (public/series/ absent)" test ! -e public/series

css_src="assets/css/main.css"

# Helpers on generated HTML.
# href_re PATH: regex matching an href to PATH, relative or absolute.
href_re() { printf 'href="?(%s)?%s"?' "${SITE//./\\.}" "$1"; }
# block FILE REGEX: print the first match of a Perl regex (with /s) in FILE.
block() { perl -0777 -ne "print \$1 if /($2)/s" "$1"; }
# in_order FILE A B: regex A matches, and regex B first matches after A's first match.
in_order() {
  A="$2" B="$3" perl -0777 -ne '
    my $i = /$ENV{A}/ ? $-[0] : -1;
    my $j = /$ENV{B}/ ? $-[0] : -1;
    exit($i >= 0 && $j > $i ? 0 : 1)' "$1"
}

# nav_link TEXT PATH REL LABEL: TEXT has an <a> to PATH with rel=REL whose content includes LABEL.
nav_link() {
  printf '%s' "$1" | H="$(href_re "$2")" R="$3" L="$4" perl -0777 -ne '
    exit(/<a\b(?=[^>]*$ENV{H})(?=[^>]*rel="?$ENV{R}\b)[^>]*>(?:(?!<\/a>).)*?\Q$ENV{L}\E/s ? 0 : 1)'
}

# link_to TEXT PATH LABEL: TEXT has an <a> to PATH whose content includes LABEL.
link_to() {
  printf '%s' "$1" | H="$(href_re "$2")" L="$3" perl -0777 -ne '
    exit(/<a\b(?=[^>]*$ENV{H})[^>]*>(?:(?!<\/a>).)*?\Q$ENV{L}\E/s ? 0 : 1)'
}
# meta_desc FILE: print the content of the page's <meta name=description>.
meta_desc() { perl -0777 -ne 'print $2 if /<meta name="?description"? content=(["\x27]?)(.*?)\1[\s\/>]/s' "$1"; }
# Racks and units in generated HTML. Text fields are tag-stripped, entity-decoded and
# whitespace-collapsed; hrefs are site-relative.
# rack_dump FILE: one line per rack and per unit, in page order:
#   RACK|<name>|<plate>|<href of the name link, or empty>
#   <label>|<live|blank>|<href>|<title>|<line>|<screen-reader text>|<number of <a>>|<visible text>
# "visible text" is the whole unit minus its label and its visually hidden text.
RACK_PERL='
  my $site = $ENV{SITE_URL};
  sub dec { my $s = shift; $s =~ s/&#(\d+);/chr($1)/ge; $s =~ s/&#x([0-9a-f]+);/chr(hex $1)/gie;
    my %e = (amp => "&", lt => "<", gt => ">", quot => "\"", apos => "\x27", nbsp => " ");
    $s =~ s/&(\w+);/exists $e{$1} ? $e{$1} : "&$1;"/ge; $s }
  sub txt { my $s = shift // ""; $s =~ s/<[^>]*>/ /g; $s = dec($s); $s =~ s/\s+/ /g; $s =~ s/^ | $//g; $s =~ s/ (?=[,.;:!?])//g; $s }
  sub href { my $s = shift // ""; return "" unless $s =~ /<a\b[^>]*\shref=["\x27]?([^"\x27\s>]+)/; my $h = $1; $h =~ s/^\Q$site\E//; $h }
  sub hidden { join " ", map { txt($_) } $_[0] =~ /<span class="?visually-hidden"?>(.*?)<\/span>/sg }
  sub unhide { (my $s = shift) =~ s/<span class="?visually-hidden"?>.*?<\/span>//sg; $s }
  # racks HTML: the RACK and unit lines of every rack in HTML (see rack_dump).
  sub racks {
    my $h = shift; my $out = "";
    while ($h =~ /<section class="?rack\b[^>]*>(.*?)<\/section>/sg) {
      my $r = $1;
      my ($cap) = $r =~ /<div class="?rack__cap"?[^>]*>(.*?)<\/div>/s;
      my ($name) = ($cap // "") =~ /class="?rack__name"?[^>]*>(.*?)<\/(?:h\d|p)>/s;
      my ($plate) = ($cap // "") =~ /class="?rack__plate"?[^>]*>(.*?)<\/p>/s;
      $out .= join("|", "RACK", txt($name), txt($plate), href($name)) . "\n";
      while ($r =~ /<li class="?card unit\b([^"\x27>]*)["\x27]?[^>]*>(.*?)<\/li>/sg) {
        my ($cls, $u) = ($1, $2);
        my $state = $cls =~ /\bunit--live\b/ ? "live" : $cls =~ /\bunit--blank\b/ ? "blank" : "?";
        my ($label) = $u =~ /<span class="?unit__label"?[^>]*>(.*?)<\/span>/s;
        my $vis = unhide($u);
        $vis =~ s/<span class="?unit__label"?[^>]*>.*?<\/span>//s;
        my ($title) = $vis =~ /class="?unit__title"?[^>]*>(.*?)<\/(?:h\d|p)>/s;
        my ($line) = $vis =~ /class="?unit__line"?[^>]*>(.*?)<\/p>/s;
        my $links = () = $u =~ /<a\b/g;
        $out .= join("|", txt($label), $state, href($u), txt($title), txt($line), hidden($u), $links, txt($vis)) . "\n";
      }
    }
    $out }
'
rack_dump() { SITE_URL="$SITE" perl -0777 -ne "$RACK_PERL"'print racks($_)' "$1"; }
# floor_dump FILE: the floors of the home server view, in page order: one line
#   FLOOR|<room name>|<plate>|<href of the name link, or empty>|<screen-reader text of the name>|<patch>|<side>|<trays>|<decor>
# per floor, followed by the rack_dump lines of the racks on that floor. <patch> is the state
# of the patch port in the floor heading (lit, unlit, or none); <side> is the
# tray its cable comes from (left or right: floor--left/--right, the patch panel on that side);
# <trays> is "<left tray>/<right tray>", each the cables in the floor's stretch of that tray, in
# lane order, as <exit|pass>:<lit|unlit> joined by commas (empty when the tray carries none);
# <decor> is "hidden" when the patch panel, its cable and both trays are all aria-hidden.
floor_dump() {
  SITE_URL="$SITE" perl -0777 -ne "$RACK_PERL"'
    my @floors = split /(?=<section class="?floor\b)/; shift @floors;
    for my $f (@floors) {
      my ($fcls) = $f =~ /^<section class="?(floor\b[^"\x27>]*)/;
      my $side = $fcls =~ /\bfloor--left\b/ ? "left" : $fcls =~ /\bfloor--right\b/ ? "right" : "?";
      my ($head) = $f =~ /<div class="?floor__head"?[^>]*>(.*?)<\/div>/s; $head //= "";
      my ($name) = $head =~ /<h\d class="?floor__name"?[^>]*>(.*?)<\/h\d>/s; $name //= "";
      my ($plate) = $head =~ /<p class="?floor__plate"?[^>]*>(.*?)<\/p>/s;
      my ($pcls, $pattrs) = $head =~ /<span class="?(patch\b[^"\x27>]*)["\x27]?([^>]*)>/s;
      my $patch = !defined $pcls ? "none" : $pcls =~ /\bpatch--up\b/ ? "lit" : $pcls =~ /\bpatch--down\b/ ? "unlit" : "?";
      my (%tray, $trays_hidden); $trays_hidden = 1;
      for my $t (qw(left right)) {
        my ($tattrs, $tray) = $f =~ /<div class="?tray tray--$t"?([^>]*)>(.*?)<\/div>/s;
        $trays_hidden = 0 unless ($tattrs // "") =~ /\saria-hidden="?true/;
        my @cables;
        while (($tray // "") =~ /<span class="?(tray__cable\b[^"\x27>]*)/g) { my $c = $1;
          push @cables, ($c =~ /\btray__cable--exit\b/ ? "exit" : "pass") . ":" . ($c =~ /\btray__cable--up\b/ ? "lit" : $c =~ /\btray__cable--down\b/ ? "unlit" : "?") }
        $tray{$t} = join ",", @cables;
      }
      my $hid = qr/\saria-hidden="?true/;
      my $decor = defined $pcls && $pattrs =~ $hid && $head =~ /<span class="?floor__cable"?[^>]*$hid/ && $trays_hidden ? "hidden" : "visible";
      print join("|", "FLOOR", txt(unhide($name)), txt($plate), href($name), hidden($name), $patch, $side, "$tray{left}/$tray{right}", $decor), "\n", racks($f);
    }' "$1"
}
# bay_dump FILE: one line per rack in FILE, in page order:
#   <name>|<number of units>|<on|off>|<hidden|shown>|<bay>|<aria-label of the bay>
# where off is a powered-off rack (rack--off), hidden an aria-hidden rack, and <bay> is
# "scroll" when the bay is a scrolling one (class rack__bay--scroll, tabindex="0" and an
# aria-label), "fixed" when it has none of the three, "bad" otherwise.
bay_dump() {
  SITE_URL="$SITE" perl -0777 -ne "$RACK_PERL"'
    while (/<section class="?(rack\b[^"\x27>]*)["\x27]?([^>]*)>(.*?)<\/section>/sg) {
      my ($cls, $attrs, $r) = ($1, $2, $3);
      my ($cap) = $r =~ /<div class="?rack__cap"?[^>]*>(.*?)<\/div>/s;
      my ($name) = ($cap // "") =~ /class="?rack__name"?[^>]*>(.*?)<\/(?:h\d|p)>/s;
      my $n = () = $r =~ /<li class="?card unit\b/g;
      my ($bcls, $battrs) = $r =~ /<ol class="?(rack__bay\b[^"\x27>]*)["\x27]?([^>]*)>/s;
      $bcls //= ""; $battrs //= "";
      my @l = $battrs =~ /\saria-label=(?:"([^"]*)"|\x27([^\x27]*)\x27|([^\s>]+))/; my ($label) = grep { defined } @l; $label = dec($label // "");
      my $scroll = $bcls =~ /\brack__bay--scroll\b/ ? 1 : 0;
      my $tab = $battrs =~ /\stabindex=["\x27]?0["\x27\s>]?/ ? 1 : 0;
      my $bay = $scroll && $tab && $label ne "" ? "scroll" : !$scroll && !$tab && $label eq "" ? "fixed" : "bad";
      print join("|", txt($name), $n, ($cls =~ /\brack--off\b/ ? "off" : "on"), ($attrs =~ /\saria-hidden="?true/ ? "hidden" : "shown"), $bay, $label), "\n";
    }' "$1"
}
# port_vars FILE: the --rooms value of the server hall, its --ports value, its --left value (the rooms
# cabled to the left tray), then the --i value of
# every room port in page order, space-separated (the inline custom properties the cable
# geometry uses).
port_vars() {
  perl -0777 -ne '
    my @v; push @v, /<div class="?server-hall"?[^>]*\sstyle=["\x27]?--rooms:\s*(\d+)/ ? $1 : "none";
    push @v, /<div class="?server-hall"?[^>]*\sstyle=["\x27]?[^"\x27>]*--ports:\s*(\d+)/ ? $1 : "none";
    push @v, /<div class="?server-hall"?[^>]*\sstyle=["\x27]?[^"\x27>]*--left:\s*(\d+)/ ? $1 : "none";
    my ($s) = /<nav class="?switch\b[^>]*>(.*?)<\/nav>/s;
    push @v, $1 while ($s // "") =~ /<li class="?switch__port\b[^>]*\sstyle=["\x27]?--i:\s*(\d+)/g;
    print join(" ", @v)' "$1"
}
# switch_dump FILE: one line per switch port, in page order:
#   <n>|<lit|unlit>|<label text>|<href, or empty>|<screen-reader text>|<a|span>|<aria-disabled value>|<decor>
# where decor is "hidden" when the jack, the cable and the cable run to the tray are all aria-hidden.
switch_dump() {
  SITE_URL="$SITE" perl -0777 -ne "$RACK_PERL"'
    my ($s) = /<nav class="?switch\b[^>]*>(.*?)<\/nav>/s or exit;
    my $n = 0;
    while ($s =~ /<li class="?switch__port\b([^"\x27>]*)["\x27]?[^>]*>(.*?)<\/li>/sg) {
      my ($cls, $p) = ($1, $2); next if $cls =~ /\bswitch__port--spare\b/; $n++;
      my $state = $cls =~ /\bswitch__port--up\b/ ? "lit" : $cls =~ /\bswitch__port--down\b/ ? "unlit" : "?";
      (my $q = $p) =~ s/\s*<span class="?switch__run"?[^>]*><\/span>\s*\z//;
      my ($el, $attrs, $tag) = $q =~ /<(a|span)\b([^>]*\bswitch__tag\b[^>]*)>(.*)<\/\1>\s*$/s;
      my ($dis) = ($attrs // "") =~ /\saria-disabled=["\x27]?(\w+)/;
      my $decor = $p =~ /<span class="?switch__jack"?[^>]*\saria-hidden="?true/ && $p =~ /<span class="?switch__cable"?[^>]*\saria-hidden="?true/ && $p =~ /<span class="?switch__run"?[^>]*\saria-hidden="?true/ ? "hidden" : "visible";
      print join("|", $n, $state, txt(unhide($tag // "")), href("<a" . ($attrs // "") . ">"), hidden($tag // ""), $el // "", $dis // "", $decor), "\n";
    }' "$1"
}
# port_sides FILE: the tray side of every room port of the switch, in page order (left or
# right, from switch__port--left/--right), space-separated.
port_sides() {
  perl -0777 -ne '
    my ($s) = /<nav class="?switch\b[^>]*>(.*?)<\/nav>/s or exit; my @v;
    while ($s =~ /<li class="?(switch__port\b[^"\x27>]*)/g) { my $c = $1; next if $c =~ /\bswitch__port--spare\b/;
      push @v, $c =~ /\bswitch__port--left\b/ ? "left" : $c =~ /\bswitch__port--right\b/ ? "right" : "?" }
    print join(" ", @v)' "$1"
}
# side_expect ROOMS: the port_sides expected for ROOMS rooms: the rooms on the first half of
# the switch ports (min(ROOMS, ports / 2)) go to the left tray, the others to the right one.
side_expect() {
  local p=$(( ($1 + 7) / 8 * 8 )) l i out=""
  l=$(( p / 2 )); if [ "$l" -gt "$1" ]; then l=$1; fi
  for i in $(seq 1 "$1"); do if [ "$i" -le "$l" ]; then out="$out left"; else out="$out right"; fi; done
  printf '%s' "${out# }"
}
# spare_dump FILE: one line per switch port in page order, "room" for a room port, else the
# spare port's "spare|<aria-hidden>|<capped>|<parts>": aria-hidden "hidden" or "shown",
# capped "capped" when its jack carries a dust cap (switch__jack--capped), parts the
# cable/tag/run/LED-state classes found in it (empty for a bare capped port with an unlit LED).
spare_dump() {
  perl -0777 -ne '
    my ($s) = /<nav class="?switch\b[^>]*>(.*?)<\/nav>/s or exit;
    while ($s =~ /<li class="?(switch__port\b[^"\x27>]*)["\x27]?([^>]*)>(.*?)<\/li>/sg) {
      my ($cls, $attrs, $p) = ($1, $2, $3);
      if ($cls !~ /\bswitch__port--spare\b/) { print "room\n"; next }
      my @parts = grep { $p =~ /\b$_\b/ } qw(switch__cable switch__tag switch__run tray__cable);
      push @parts, "lit" if $cls =~ /\bswitch__port--up\b/;
      push @parts, "style" if $attrs =~ /\sstyle=/;
      print join("|", "spare", ($attrs =~ /\saria-hidden="?true/ ? "hidden" : "shown"), ($p =~ /<span class="?switch__jack switch__jack--capped"?/ ? "capped" : "open"), join(",", @parts)), "\n";
    }' "$1"
}
# spare_expect ROOMS: the spare_dump expected for ROOMS rooms: the room ports, then spares up
# to the next multiple of 8 ports (7 rooms: 8 ports, 1 spare; 8: none; 9: 16 ports).
spare_expect() {
  local p=$(( ($1 + 7) / 8 * 8 )) i
  for i in $(seq 1 "$p"); do if [ "$i" -le "$1" ]; then echo room; else echo 'spare|hidden|capped|'; fi; done
}
# crumb_dump FILE: the band kicker of FILE, one "<text>|<href, or empty>" line per part.
crumb_dump() {
  SITE_URL="$SITE" perl -0777 -ne "$RACK_PERL"'
    my ($k) = /<p class="?band__kicker"?[^>]*>(.*?)<\/p>/s or exit;
    print txt($_), "|", href($_), "\n" for split /<span class="?sep"?[^>]*>.*?<\/span>/s, $k;' "$1"
}
# rack_brief DUMP: the dump reduced to FLOOR and RACK lines and "<label>|<state>|<href>|<title>|<sr text>".
rack_brief() { printf '%s\n' "$1" | awk -F'|' 'NF == 0 { next } $1 == "RACK" || $1 == "FLOOR" { print; next } { print $1 "|" $2 "|" $3 "|" $4 "|" $6 }'; }
# css_rule SELECTOR: print the declarations of the first rule for SELECTOR starting at column 0
# (a top-level rule) in main.css.
css_rule() { S="$1" perl -0777 -ne 'print $1 if /(?:\A|\n)\Q$ENV{S}\E\s*\{([^}]*)\}/s' "$css_src"; }
# noindex FILE: the page carries <meta name="robots" content="noindex">.
noindex() { perl -0777 -ne 'exit(/<meta name="?robots"? content=["\x27]?noindex\b/ ? 0 : 1)' "$1"; }
# in_sitemap PATH: sitemap.xml lists the page at PATH (site-relative). SITEMAP overrides the file.
in_sitemap() { grep -Fq "<loc>${SITE}$1</loc>" "${SITEMAP:-public/sitemap.xml}"; }
# not COMMAND...: succeed when COMMAND fails (for check, which runs its command directly).
not() { if "$@"; then return 1; else return 0; fi; }
# band_title FILE: the text of the band's <h1>, entity-decoded.
band_title() { SITE_URL="$SITE" perl -0777 -ne "$RACK_PERL"'print txt($1) if /<h1 class="?band__title"?>(.*?)<\/h1>/s' "$1"; }
# link_audit DIR PATHS: print "page: path" for every <a href> in DIR's HTML to one of PATHS
# (site-relative, one per line).
link_audit() {
  find "$1" -type f -name '*.html' -print0 | SITE_URL="$SITE" P="$2" xargs -0 perl -ne '
    BEGIN { %p = map { $_ => 1 } grep { length } split /\n/, $ENV{P} }
    while (/<a\b[^>]*?\shref=["\x27]?([^"\x27\s>]+)/g) { my $h = $1; $h =~ s/^\Q$ENV{SITE_URL}\E//; print "$ARGV: $h\n" if $p{$h} }' | sort -u || true
}
# tree_problems DIR: print every folder of the content tree DIR that is not a room or a rack
# with its _index.md: folders directly under DIR are rooms, folders inside a room are racks
# (posts are the folders inside a rack).
tree_problems() {
  local d
  for d in "$1"/*/; do
    if [ ! -f "${d}_index.md" ]; then printf '%s: room folder without _index.md\n' "${d%/}"; fi
  done
  for d in "$1"/*/*/; do
    if [ -d "$d" ] && [ ! -f "${d}_index.md" ]; then printf '%s: rack folder without _index.md\n' "${d%/}"; fi
  done
}
# weight_problems DIR: print every room (folder of DIR) and rack (folder of a room) without an
# integer weight, and every weight used twice among siblings.
weight_problems() {
  local parent f w
  for parent in "$1" "$1"/*; do
    [ -d "$parent" ] || continue
    for f in "$parent"/*/_index.md; do
      [ -f "$f" ] || continue
      w="$(perl -0777 -ne 'print $1 if /\A---\n(.*?)\n---/s && $1 =~ /^weight:[ \t]*(\d+)[ \t]*$/m' "$f")"
      if [ -z "$w" ]; then printf '%s: no integer weight\n' "$f"; fi
    done
    for f in "$parent"/*/_index.md; do
      [ -f "$f" ] || continue
      w="$(perl -0777 -ne 'print $1 if /\A---\n(.*?)\n---/s && $1 =~ /^weight:[ \t]*(\d+)[ \t]*$/m' "$f")"
      if [ -n "$w" ]; then printf '%s weight %s\n' "$parent" "$w"; fi
    done | sort | uniq -d | sed 's/$/: duplicate weight/'
  done
}
# room_slug_problems DIR: print every room folder of DIR named like a taxonomy (its URL).
room_slug_problems() {
  local t
  for t in $(hugo config --format json 2>/dev/null | perl -MJSON::PP -0777 -ne 'print "$_\n" for values %{ decode_json($_)->{taxonomies} // {} }'); do
    if [ -e "$1/$t" ]; then printf '%s/%s: a room named like the %s taxonomy\n' "$1" "$t" "$t"; fi
  done
}
# rack_units DUMP NAME: the unit lines of rack NAME in DUMP.
rack_units() { printf '%s\n' "$1" | N="$2" perl -ne 'if (/^FLOOR\|/) { $in = 0; next } if (/^RACK\|([^|]*)\|/) { $in = $1 eq $ENV{N}; next } print if $in'; }
# unit_problems DUMP: print every unit breaking the unit rules: labels U01, U02, ... in order
# within each rack; a live unit links once to its post; a blank has no link, an untitled
# blank no visible text and "Empty slot" for screen readers, a titled blank "Planned: <title>".
unit_problems() {
  printf '%s\n' "$1" | perl -ne '
    chomp; next if $_ eq ""; my @f = split /\|/, $_, -1;
    next if $f[0] eq "FLOOR";
    if ($f[0] eq "RACK") { $rack = $f[1]; $n = 0; next }
    my ($label, $state, $href, $title, $line, $sr, $links, $vis) = @f; $n++;
    my $want = sprintf "U%02d", $n;
    print "$rack $label: label should be $want\n" unless $label eq $want;
    if ($state eq "live") {
      print "$rack $label: live unit should have exactly one link\n" unless $links == 1 && $href ne "";
      print "$rack $label: live unit has no title\n" if $title eq "";
    } elsif ($state eq "blank") {
      print "$rack $label: blank unit has a link\n" if $links != 0 || $href ne "";
      if ($title eq "") {
        print "$rack $label: untitled blank shows text \"$vis\"\n" if $vis ne "";
        print "$rack $label: untitled blank screen-reader text should be \"Empty slot\" (is \"$sr\")\n" unless $sr eq "Empty slot";
      } else {
        print "$rack $label: titled blank screen-reader text should be \"Planned: $title\" (is \"$sr\")\n" unless $sr eq "Planned: $title";
      }
    } else { print "$rack $label: unit is neither live nor blank\n" }'
}
# box_dump FILE: the rack box of a post page: "HEAD|<text before the rack link>|<rack>|<href>",
# then one line per unit "<port>|<current|live|blank>|<href>|<title>|<sr text>|<number of <a>>".
box_dump() {
  SITE_URL="$SITE" perl -0777 -ne "$RACK_PERL"'
    my ($b) = /<nav class="?rack-box\b[^>]*>(.*?)<\/nav>/s or exit;
    my ($h) = $b =~ /<p class="?rack-box__head"?[^>]*>(.*?)<\/p>/s;
    my ($pre, $a) = ($h // "") =~ /^(.*?)(<a\b.*<\/a>)/s;
    $pre =~ s/<span class="?sep"?[^>]*>.*?<\/span>//s;
    print join("|", "HEAD", txt($pre), txt($a), href($a)), "\n";
    while ($b =~ /<li class="?rack-box__item\b([^"\x27>]*)["\x27]?([^>]*)>(.*?)<\/li>/sg) {
      my ($cls, $attrs, $u) = ($1, $2, $3);
      my $state = $cls =~ /\bis-blank\b/ ? "blank" : $attrs =~ /aria-current="?page/ ? "current" : "live";
      my ($port) = $u =~ /<span class="?rack-box__port"?[^>]*>(.*?)<\/span>/s;
      my $vis = unhide($u); $vis =~ s/<span class="?rack-box__port"?[^>]*>.*?<\/span>//s;
      my $links = () = $u =~ /<a\b/g;
      print join("|", txt($port), $state, href($u), txt($vis), hidden($u), $links), "\n";
    }' "$1"
}
# check_eq "description" GOT WANT: pass when equal, else print both as a diff.
check_eq() {
  if [ "$2" = "$3" ]; then pass "$1"; else
    fail "$1"
    local w g; w="$(mktemp "${TMPDIR:-/tmp}/check-want.XXXXXX")"; g="$(mktemp "${TMPDIR:-/tmp}/check-got.XXXXXX")"
    printf '%s\n' "$3" >"$w"; printf '%s\n' "$2" >"$g"
    diff "$w" "$g" | sed -e 's/^</        want/' -e 's/^>/        got /' -e '/^[0-9]/d' -e '/^---/d' || true
    rm -f "$w" "$g"
  fi
}
# starts_with TEXT REGEX: TEXT, with tags removed and whitespace trimmed, starts with REGEX.
starts_with() { printf '%s' "$1" | R="$2" perl -0777 -ne 's/<[^>]*>//g; s/^\s+//; exit(/^$ENV{R}/ ? 0 : 1)'; }
# has_front_matter FILE KEY: KEY is set to a non-empty value in FILE's YAML front matter.
has_front_matter() {
  K="$2" perl -0777 -ne 'exit(/\A---\n(.*?)\n---/s && $1 =~ /^$ENV{K}:[ \t]*(?!""|\x27\x27)\S/m ? 0 : 1)' "$1"
}
# header_has TEXT REGEX: TEXT matches the Perl regex (with /s).
header_has() { printf '%s' "$1" | R="$2" perl -0777 -ne 'exit(/$ENV{R}/s ? 0 : 1)'; }
# only_wordmark_and_icons TEXT: every <a> in TEXT has class wordmark or icon-link.
only_wordmark_and_icons() {
  printf '%s' "$1" | perl -0777 -ne '
    while (/<a\b([^>]*)>/g) { exit 1 unless $1 =~ /class="?(?:wordmark|icon-link)\b/ }
    exit 0'
}

# External hosts: the site itself and the hosts posts link to in their Markdown; giscus.app
# only on post pages and only when giscus is on.
site_host="$(sed -n 's|^baseURL *= *"https\{0,1\}://\([^/"]*\).*|\1|p' hugo.toml 2>/dev/null | head -n1 || true)"
post_hosts="$(find content -name '*.md' -print0 | xargs -0 perl -ne 'print lc("$1\n") while /\]\(https?:\/\/([^\/)\s:?#]+)/g' | sort -u)"
allowed="$(printf '%s\n%s\n' "$site_host" "$post_hosts" | sed '/^$/d' | sort -u)"
# host_audit DIR on|off: print "page: host" for every host outside the allowed list.
host_audit() {
  local dir="$1" mode="$2" pf f h
  pf="$(post_files "$dir")"
  find "$dir" -type f -name '*.html' -print0 |
    xargs -0 perl -ne 'while (/\b(?:href|src|srcset|content|action|poster)="?((?:https?:)?\/\/[^\s"\/?#>:]+)/g) { my $h = lc $1; $h =~ s#^(?:https?:)?//##; print "$ARGV $h\n" }' |
    sort -u | while read -r f h; do
      printf '%s\n' "$allowed" | grep -qxF "$h" && continue
      [ "$mode" = on ] && [ "$h" = giscus.app ] && printf '%s\n' "$pf" | grep -qxF "$f" && continue
      printf '%s: %s\n' "${f#"$dir"}" "$h"
    done
}

# --- 3. Post pages ------------------------------------------------------------
# Every regular page is a post (fitness function below). Source -> output mapping comes from
# `hugo list published` (path,...,permalink,kind,section); a post's section is its room.
posts="$(hugo list published 2>/dev/null | perl -ne 'print "$1 $2\n" if /^([^,]+),.*,https?:\/\/[^\/,]+(\/[^,]*),page,[^,]+\s*$/')"
if [ -n "$posts" ]; then pass "hugo list reports published posts"; else fail "hugo list reports published posts"; fi
post_count=0
while read -r src path; do
  [ -n "$src" ] || continue
  post_count=$((post_count + 1))
  out="public${path}index.html"
  [ -f "$out" ] || { fail "post $path is built"; continue; }
  check "$path renders no table of contents" sh -c '! grep -Eqi "TableOfContents|data-toc|class=[\"\x27]?toc" "$1"' _ "$out"
  check "$path is in sitemap.xml" in_sitemap "$path"
  check "$path is indexable (no robots meta)" not grep -Eq '<meta name="?robots' "$out"
done <<EOF
$posts
EOF
# Fitness: every regular page (drafts included) is content/<room>/<rack>/<folder>/index.md.
stray="$(hugo list all 2>/dev/null | perl -ne 'my @f = split /,/; next unless /,page,[^,]*\s*$/; print "$f[0]\n" unless $f[0] =~ m{^content/[^/]+/[^/]+/[^/]+/index\.md$}')"
check_none "every regular page is a post at content/<room>/<rack>/<folder>/index.md" "$stray"

if [ -f "$P1_OUT" ]; then
  check "Mindset U01 has canonical URL" grep -Eq "<link rel=\"?canonical\"? href=\"?${SITE//./\\.}${P1_PATH}\"?" "$P1_OUT"
  check "Mindset U01 meta description is the post's opening text" starts_with "$(meta_desc "$P1_OUT")" 'It all started around 2018'
  check "Mindset U01 has Open Graph title" grep -Eq '<meta property="?og:title"?' "$P1_OUT"
  check "Mindset U01 is an Open Graph article" grep -Eq '<meta property="?og:type"? content="?article' "$P1_OUT"
  check "Mindset U01 shows reading time" grep -q 'min read' "$P1_OUT"
  check "Mindset U01 renders the figure" grep -q '<figure' "$P1_OUT"
  # The site figure shortcode: a responsive, lazily loaded image with fixed dimensions.
  img="$(block "$P1_OUT" '<figure\b.*?<img\b[^>]*>')"
  img="${img##*<img}"
  check "Mindset U01 figure img has a srcset with 400w and 800w" header_has "$img" 'srcset="?[^">]*\s400w[^">]*\s800w'
  check "Mindset U01 figure img keeps the 400px display width" header_has "$img" '\swidth="?400"?[\s>]'
  check "Mindset U01 figure img has a height (no layout shift)" header_has "$img" '\sheight="?[0-9]+"?[\s>]'
  check "Mindset U01 figure img has loading=\"lazy\"" header_has "$img" '\sloading="?lazy"?[\s>]'
  check "Mindset U01 figure img has decoding=\"async\"" header_has "$img" '\sdecoding="?async"?[\s>]'
  check "Mindset U01 figure img has a sizes attribute" header_has "$img" '\ssizes="?[^">]'
  check "Mindset U01 figure img keeps its alt text" header_has "$img" 'alt="?The underside of the CPU'
  check "Mindset U01 figure img is WebP" sh -c 'printf %s "$1" | perl -ne "exit(/srcset=\"?([^\">]*)/ && \$1 !~ /\\.(?:jpe?g|png)\\b/i && \$1 =~ /\\.webp\\b/ ? 0 : 1)"' _ "$img"
  srcset_missing="$(printf '%s' "$img" | perl -ne 'if (/srcset="?([^">]*)/) { for (split /,\s*/, $1) { my ($u) = split /\s+/; $u =~ s#^https?://[^/]+##; print "$u\n" unless -f "public$u" } }')"
  check "Mindset U01 figure srcset files exist in public/" test -z "$srcset_missing"
  check "Mindset U01 page has the band with the post title" test "$(band_title "$P1_OUT")" = "$P1_TITLE"
  check_eq "Mindset U01 band breadcrumb: \"Mindset · <rack>\", both linked" "$(crumb_dump "$P1_OUT")" "Mindset|/mindset/
${R1_TITLE}|${FINDOUT_PATH}"
  # Rack box: "U01 of 3 · <rack>", every unit listed, the current one marked, blanks unlinked.
  check_eq "Mindset U01 rack box: \"U01 of 3 · $R1_TITLE\", the current unit and two empty blanks" "$(box_dump "$P1_OUT")" "HEAD|U01 of 3|${R1_TITLE}|${FINDOUT_PATH}
01|current||${P1_TITLE}||0
02|blank|||Empty slot|0
03|blank|||Empty slot|0"
  check "Mindset U01 rack box does not link to the page itself" sh -c '! printf %s "$1" | grep -Eq "$2"' _ "$(block "$P1_OUT" '<nav class="?rack-box.*?<\/nav>')" "$(href_re "$P1_PATH")"
  check "Mindset U01 has no previous/next unit (no published neighbour)" sh -c '! grep -Eq "<nav class=\"?post-nav|rel=\"?(prev|next)" "$1"' _ "$P1_OUT"
fi

if [ -f "$P2_OUT" ]; then
  check "Homelab U01 has canonical URL" grep -Eq "<link rel=\"?canonical\"? href=\"?${SITE//./\\.}${P2_PATH}\"?" "$P2_OUT"
  check "Homelab U01 meta description is the post's opening text" starts_with "$(meta_desc "$P2_OUT")" 'When I built my first PC'
  check "Homelab U01 page has the band with the post title" test "$(band_title "$P2_OUT")" = "$P2_TITLE"
  check_eq "Homelab U01 band breadcrumb: \"Homelab · <rack>\", both linked" "$(crumb_dump "$P2_OUT")" "Homelab|/homelab/
${R2_TITLE}|${OS_PATH}"
  check_eq "Homelab U01 rack box: \"U01 of 3 · $R2_TITLE\", the current unit and two empty blanks" "$(box_dump "$P2_OUT")" "HEAD|U01 of 3|${R2_TITLE}|${OS_PATH}
01|current||${P2_TITLE}||0
02|blank|||Empty slot|0
03|blank|||Empty slot|0"
  check "Homelab U01 has no previous/next unit (no published neighbour)" sh -c '! grep -Eq "<nav class=\"?post-nav|rel=\"?(prev|next)" "$1"' _ "$P2_OUT"
fi

# --- 4. Home, room and rack pages, feed -------------------------------------------
# rack_expect ROOM: the rack_brief lines expected for the compact racks of ROOM (its home floor
# and its room page): every rack in weight order, its name linked only when open, every unit.
rack_expect() {
  local room slug title units state href n label
  while IFS='|' read -r room slug title units state; do
    [ "$room" = "$1" ] || continue
    href=""
    if [ "$state" = open ]; then href="/${room}/${slug}/"; fi
    printf 'RACK|%s||%s\n' "$title" "$href"
    for n in $(seq 1 "$units"); do
      label="$(printf 'U%02d' "$n")"
      case "$room/$slug:$n" in
        mindset/find-out:1) printf '%s|live|%s|%s|\n' "$label" "$P1_PATH" "$P1_TITLE" ;;
        homelab/operating-systems:1) printf '%s|live|%s|%s|\n' "$label" "$P2_PATH" "$P2_TITLE" ;;
        *) printf '%s|blank|||Empty slot\n' "$label" ;;
      esac
    done
  done <<EOF
$RACK_TABLE
EOF
}
# The switch: one port per room in weight order, lit and linked when open; unlit, unlinked
# (a disabled link with a "closed" text for screen readers) when closed. The server view:
# one floor per room, open or closed, in the same order. Each floor's heading holds a patch
# panel whose port matches the room's switch port, and the floor's stretch of cable tray
# carries the cables of this room and of every room after it (room k of N: N-k+1 cables);
# this room's cable exits the tray into the patch panel. A closed room's floor names the room
# unlinked ("closed" for screen readers) above one powered-off rack: no name, three blanks.
# tray_expect TABLE K: the <trays> field of floor K for a ROOM_TABLE-like TABLE: the left tray
# carries the rooms on the first half of the switch ports (rooms 1..L, L = min(N, ports / 2)),
# the right tray the others; at floor K each tray carries its rooms from K on, room K exiting.
tray_expect() {
  printf '%s\n' "$1" | awk -F'|' -v k="$2" 'NF { n++; s[n] = ($4 == "open") ? "lit" : "unlit" }
    END { p = int((n + 7) / 8) * 8; l = p / 2; if (l > n) l = n
      for (i = 1; i <= n; i++) { if (i < k) continue; c = (i == k ? "exit:" : "pass:") s[i]
        if (i <= l) left = left (left == "" ? "" : ",") c; else right = right (right == "" ? "" : ",") c }
      print left "/" right }'
}
# side_of TABLE K: the tray side (left or right) of room K of a ROOM_TABLE-like TABLE.
side_of() { printf '%s\n' "$1" | awk -v k="$2" 'NF { n++ } END { p = int((n + 7) / 8) * 8; l = p / 2; if (l > n) l = n; print (k <= l ? "left" : "right") }'; }
OFF_RACK="RACK|||
U01|blank|||Empty slot
U02|blank|||Empty slot
U03|blank|||Empty slot"
# bay_expect ROOM: the bay_dump lines expected for the compact racks of ROOM (3 units: a fixed
# bay or more: every bay shows all its units, none scrolls).
bay_expect() {
  local room slug title units state
  while IFS='|' read -r room slug title units state; do
    [ "$room" = "$1" ] || continue
    printf '%s|%s|on|shown|fixed|\n' "$title" "$units"
  done <<EOF
$RACK_TABLE
EOF
}
expected_switch=""
expected_floors=""
expected_bays=""
n=0
while IFS='|' read -r slug name plate state; do
  n=$((n + 1))
  tray="$(tray_expect "$ROOM_TABLE" "$n")"
  side="$(side_of "$ROOM_TABLE" "$n")"
  if [ "$state" = open ]; then
    expected_switch="${expected_switch}${n}|lit|${name}|/${slug}/||a||hidden
"
    expected_floors="${expected_floors}FLOOR|${name}|${plate}|/${slug}/||lit|${side}|${tray}|hidden
$(rack_expect "$slug")
"
    expected_bays="${expected_bays}$(bay_expect "$slug")
"
  else
    expected_switch="${expected_switch}${n}|unlit|${name}||(closed, no posts yet)|span|true|hidden
"
    expected_floors="${expected_floors}FLOOR|${name}|${plate}||(closed, no posts yet)|unlit|${side}|${tray}|hidden
${OFF_RACK}
"
    expected_bays="${expected_bays}|3|off|hidden|fixed|
"
  fi
done <<EOF
$ROOM_TABLE
EOF
expected_switch="${expected_switch%
}"
expected_floors="${expected_floors%
}"
expected_bays="${expected_bays%
}"
room_count="$(find content -mindepth 2 -maxdepth 2 -name _index.md | wc -l | tr -d ' ')"
if [ -f public/index.html ]; then
  console="$(block public/index.html '<section class="?card console.*?<\/section>')"
  check "home page opens with the console unit in the full-width room container, right after the header" perl -0777 -ne 'exit(/<\/header>\s*<main\b[^>]*>\s*<div class="?container container--room"?>\s*<section class="?card console/ ? 0 : 1)' public/index.html
  lead="$(printf '%s' "$console" | perl -0777 -ne 'print $1 if /<div class="?console__lead\b[^>]*>(.*?)<\/div>/s')"
  check "console lead is the intro's first two paragraphs" sh -c 'test "$(printf %s "$1" | perl -0777 -ne "print scalar(() = /<p\\b/g)")" = 2 && printf %s "$1" | grep -q "Hi, my name is Francesco Verrengia" && printf %s "$1" | grep -q "what I learn along the way"' _ "$lead"
  check "console lead stops before the rest of the intro" sh -c 'test -n "$1" && ! printf %s "$1" | grep -Eq "To remember everything|This is my story"' _ "$lead"
  more="$(printf '%s' "$console" | perl -0777 -ne 'print $& if /<details\b.*?<\/details>/s')"
  check "the rest of the intro is in a closed <details> with the summary \"More about this blog\"" header_has "$more" '^<details class="?console__more"?>\s*<summary class="?console__summary"?>More about this blog</summary>'
  check "the <details> holds the rest of the intro (the list to \"This is my story\"), not the lead" sh -c 'printf %s "$1" | grep -q "To remember everything I did" && printf %s "$1" | grep -q "This is my story" && ! printf %s "$1" | grep -q "Hi, my name is"' _ "$more"
  check "\"I do it for a few reasons\" opens the list inside the <details>, not the lead" sh -c 'printf %s "$1" | perl -0777 -ne "exit(/I do it for a few reasons:<\\/p>\\s*<ul\\b/ ? 0 : 1)" && ! printf %s "$2" | grep -q "for a few reasons"' _ "$more" "$lead"
  check "console intro says \"this blog\"" sh -c 'printf %s "$1" | grep -q "this blog"' _ "$console"
  check "console intro no longer says \"this series\"" sh -c '! printf %s "$1" | grep -qi "this series"' _ "$console"
  check "console lead comes before the <details>" in_order public/index.html 'class="?console__lead' '<details class="?console__more'
  check "console \"Start reading\" links to Mindset U01 (first post of the first open rack of the first open room)" link_to "$console" "$P1_PATH" "Start reading"
  check "console \"Start reading\" comes after the <details>" in_order public/index.html '</details>' 'class="?console__cta'
  # Order on the page: console, switch, server view.
  check "the console comes before the switch" in_order public/index.html 'class="?card console' '<nav class="?switch\b'
  check "the switch comes before the first floor" in_order public/index.html '<nav class="?switch\b' '<section class="?floor\b'
  sw_html="$(block public/index.html '<nav class="?switch\b.*?<\/nav>')"
  check "switch: a nav labelled \"Server rooms\" holding only the ports list (no visible plate text)" header_has "$sw_html" '^<nav class="?switch"? aria-label="?Server rooms"?>\s*<ol class="?switch__ports"?>'
  check_none "no page shows the texts \"Core switch\" or \"Start here\" (no switch plate, no console kicker)" "$(find public -name '*.html' -print0 | xargs -0 perl -0777 -ne 's/<[^>]*>/ /g; print "$ARGV\n" if /Core switch|Start here/i' || true)"
  check "the console keeps its accessible name (aria-label \"Start here\")" perl -0777 -ne 'exit(/<section class="?card console"?[^>]*\saria-label=["\x27]?Start here["\x27]?[\s>]/ ? 0 : 1)' public/index.html
  sw="$(switch_dump public/index.html)"
  check_eq "switch: one port per room in weight order (n, LED, label, link, screen-reader text, element, aria-disabled, jack and cable aria-hidden)" "$sw" "$expected_switch"
  check "switch has one room port per room ($room_count)" test "$(printf '%s\n' "$sw" | grep -c .)" = "$room_count"
  check_eq "switch: ports = rooms rounded up to a multiple of 8, the spares last, each aria-hidden with a dust cap, unlit, no cable, tag or run" "$(spare_dump public/index.html)" "$(spare_expect "$room_count")"
  check "switch markup has no <script>" sh -c 'test -n "$1" && ! printf %s "$1" | grep -qi "<script"' _ "$sw_html"
  check_none "the switch is on the home page only" "$(find public -name '*.html' ! -path public/index.html -print0 | xargs -0 grep -lE '<nav class="?switch\b' || true)"
  home_floors="$(floor_dump public/index.html)"
  check_eq "home server view: a floor per room (open and closed) in weight order: name, patch port, tray, every rack of an open room (empty racks unlinked), one powered-off rack for a closed room" "$(rack_brief "$home_floors")" "$expected_floors"
  floor_lines="$(printf '%s\n' "$home_floors" | grep '^FLOOR|' || true)"
  check "home has one floor per room ($room_count)" test "$(printf '%s\n' "$floor_lines" | grep -c '^FLOOR|')" = "$room_count"
  check_eq "every floor's patch port matches its room's switch port (lit/unlit, in order)" "$(printf '%s\n' "$floor_lines" | cut -d'|' -f6)" "$(printf '%s\n' "$sw" | cut -d'|' -f2)"
  check_none "two trays: the left carries the rooms on the first half of the switch ports, the right the others; at floor k each carries its rooms from k on (room k exiting from its own tray), each cable matching its switch port" "$(printf '%s\n' "$floor_lines" | SW="$sw" SIDES="$(port_sides public/index.html)" perl -ne '
    BEGIN { @s = map { (split /\|/)[1] } grep { length } split /\n/, $ENV{SW}; $n = @s; @side = split / /, $ENV{SIDES}; $l = grep { $_ eq "left" } @side }
    chomp; my @f = split /\|/, $_, -1; $k++;
    my $c = sub { my $i = shift; ($i == $k ? "exit:" : "pass:") . $s[$i - 1] };
    my $want = join(",", map { $c->($_) } grep { $_ <= $l } $k .. $n) . "/" . join(",", map { $c->($_) } grep { $_ > $l } $k .. $n);
    print "floor $k ($f[1]): trays \"$f[7]\", want \"$want\"\n" unless $f[7] eq $want;
    print "floor $k ($f[1]): patch on the $f[6] side, its cable comes from the $side[$k - 1] tray\n" unless $f[6] eq ($side[$k - 1] // "")')"
  check_eq "switch: the rooms on the first half of the ports (min(rooms, ports / 2)) are cabled to the left tray, the others to the right" "$(port_sides public/index.html)" "$(side_expect "$room_count")"
  check_none "closed floors name the room unlinked, \"(closed, no posts yet)\" for screen readers" "$(printf '%s\n' "$floor_lines" | awk -F'|' '$6 == "unlit" && ($4 != "" || $5 != "(closed, no posts yet)")')"
  check_none "open floors link the room name and say nothing extra to screen readers" "$(printf '%s\n' "$floor_lines" | awk -F'|' '$6 == "lit" && ($4 == "" || $5 != "")')"
  check_none "floor patch panels, their cables and the trays are aria-hidden" "$(printf '%s\n' "$floor_lines" | awk -F'|' '$9 != "hidden"')"
  home_bays="$(bay_dump public/index.html)"
  check_eq "home racks: open rooms' racks shown, every unit in view (no bay scrolls); closed rooms one unnamed, powered-off, aria-hidden 3U rack" "$home_bays" "$expected_bays"
  check "home racks: as many powered-off racks as closed rooms" test "$(printf '%s\n' "$home_bays" | grep -c '|off|')" = "$(printf '%s\n' "$ROOM_TABLE" | grep -c '|closed$')"
  check "home: the server hall sets --rooms to the room count, --ports to the port count, --left to the left-tray rooms, and room port k sets --i: k" test "$(port_vars public/index.html)" = "$room_count $(( (room_count + 7) / 8 * 8 )) $(side_expect "$room_count" | tr ' ' '\n' | grep -c left) $(seq 1 "$room_count" | paste -sd " " -)"
  check "home: the switch and the server view share the server hall (the tray runs beside both)" perl -0777 -ne 'exit(/<div class="?server-hall"?[^>]*>\s*<nav class="?switch\b.*?<\/nav>\s*<div class="?server-view"?>/s ? 0 : 1)' public/index.html
  check "home racks are all compact (rack--compact)" test "$(grep -Eo '<section class="?rack rack--compact' public/index.html | wc -l | tr -d ' ')" = "$(printf '%s\n' "$home_floors" | grep -c '^RACK|')"
  check "home has no rack outside a floor" test "$(grep -Eo '<section class="?rack\b' public/index.html | wc -l | tr -d ' ')" = "$(printf '%s\n' "$home_floors" | grep -c '^RACK|')"
  check_none "home units follow the unit rules (labels, links, blank text)" "$(unit_problems "$home_floors")"
  check "home units have no date or summary (compact)" sh -c 'test -z "$(printf "%s\n" "$1" | awk -F"|" "\$1 != \"RACK\" && \$1 != \"FLOOR\" && \$5 != \"\"")"' _ "$home_floors"
  live="$(printf '%s\n' "$home_floors" | awk -F'|' '$2 == "live"' | wc -l | tr -d ' ')"
  check "home links as many units as there are published posts ($post_count, found $live)" test "$live" = "$post_count"
  check "home page renders no band" sh -c '! grep -Eq "class=[\"\x27]?band([\"\x27 >_-]|$)" "$1"' _ public/index.html
  check "hugo.toml sets no params.motto" sh -c '! grep -Eq "^[[:space:]]*motto[[:space:]]*=" hugo.toml'
  check "home page has no pagination nav" sh -c '! grep -Eq "class=[\"\x27]?pagination" "$1"' _ public/index.html
fi
check "main.css centers the console lead" sh -c 'printf %s "$1" | grep -Eq "text-align:[[:space:]]*center"' _ "$(css_rule .console__lead)"
check "main.css lets the console lead run wider than the 740px article measure" sh -c 'w="$(printf %s "$1" | sed -n "s/.*max-width:[[:space:]]*\([0-9]*\)px.*/\1/p")"; test -n "$w" && test "$w" -gt 740' _ "$(css_rule .console__lead | tr '\n' ' ')"
check "main.css keeps the <details> text left-aligned at the article measure" sh -c 'printf %s "$1" | grep -Eq "max-width:[[:space:]]*var\(--measure\)" && printf %s "$1" | grep -Eq "text-align:[[:space:]]*left"' _ "$(css_rule .console__rest)"
check "main.css centers the \"Start reading\" foot" sh -c 'printf %s "$1" | grep -Eq "text-align:[[:space:]]*center"' _ "$(css_rule .console__foot)"
check "no /page/N/ pages are built (public/page/ absent)" test ! -e public/page
page_dirs="$(find public -type d -name page | sort || true)"
check "no paginated pages anywhere in public/" test -z "$page_dirs"
check "pagination partial is gone" test ! -e layouts/_partials/pagination.html

# Room pages: band "Server room" + title (+ plate), the intro, the room's racks compact (names
# linked when open); a closed room says so, carries noindex and is out of the sitemap.
while IFS='|' read -r slug name plate state; do
  out="public/${slug}/index.html"
  [ -f "$out" ] || continue
  check_eq "room page /$slug/: band kicker \"Server room\"" "$(crumb_dump "$out")" "Server room|"
  check "room page /$slug/: band title \"$name\"" test "$(band_title "$out")" = "$name"
  if [ -n "$plate" ]; then
    check "room page /$slug/: band plate \"$plate\"" env P="$plate" perl -0777 -ne 'exit(/<p class="?band__plate"?>\Q$ENV{P}\E<\/p>/ ? 0 : 1)' "$out"
  else
    check "room page /$slug/: no band plate" not grep -Eq '<p class="?band__plate' "$out"
  fi
  check_eq "room page /$slug/: the room's racks, compact, names linked when open" "$(rack_brief "$(rack_dump "$out")")" "$(rack_expect "$slug")"
  check_eq "room page /$slug/: every rack shows all its units (no bay scrolls), none powered off" "$(bay_dump "$out")" "$(bay_expect "$slug")"
  if [ "$state" = open ]; then
    check "open room /$slug/ is in sitemap.xml" in_sitemap "/${slug}/"
    check "open room /$slug/ is indexable (no robots meta)" not grep -Eq '<meta name="?robots' "$out"
    check "open room /$slug/ has no closed notice" not grep -Eq '<p class="?notice' "$out"
  else
    check "closed room /$slug/ is not in sitemap.xml" not in_sitemap "/${slug}/"
    check "closed room /$slug/ carries robots noindex" noindex "$out"
    check "closed room /$slug/ says \"Closed: no posts yet\"" grep -Eq '<p class="?notice"?>Closed: no posts yet\.</p>' "$out"
  fi
  if ! has_front_matter "content/${slug}/_index.md" description; then
    check "room page /$slug/ meta description falls back to the site description" sh -c 'test -n "$1" && test "$1" = "$2"' _ "$(meta_desc "$out")" "$(meta_desc public/index.html)"
  fi
done <<EOF
$ROOM_TABLE
EOF

# Rack pages: band "<Room> · Rack" (the room linked when open) + title, the intro (if any)
# before the units, the full rack with date and opening text on published units and
# "Planned" on titled blanks; a closed rack says so, carries noindex and is out of the sitemap.
while IFS='|' read -r room slug name units state; do
  out="public/${room}/${slug}/index.html"
  [ -f "$out" ] || continue
  rname="$(printf '%s\n' "$ROOM_TABLE" | awk -F'|' -v s="$room" '$1 == s { print $2 }')"
  rhref=""
  if [ "$(printf '%s\n' "$ROOM_TABLE" | awk -F'|' -v s="$room" '$1 == s { print $4 }')" = open ]; then rhref="/${room}/"; fi
  d="$(rack_dump "$out")"
  label="rack page /$room/$slug/"
  check_eq "$label: band kicker \"$rname · Rack\" (the room linked when open)" "$(crumb_dump "$out")" "${rname}|${rhref}
Rack|"
  check "$label: band title \"$name\"" test "$(band_title "$out")" = "$name"
  check "$label: one full rack (not compact)" sh -c 'test "$(grep -Eo "<section class=\"?rack\b[^>]*>" "$1" | wc -l | tr -d " ")" = 1 && ! grep -Eq "<section class=\"?rack rack--compact" "$1"' _ "$out"
  check "$label: label plate \"$name\", unlinked" sh -c 'printf "%s\n" "$1" | grep -qxF "$2"' _ "$d" "RACK|$name||"
  check "$label shows $units units" test "$(printf '%s\n' "$d" | grep -vc '^RACK|')" = "$units"
  check_none "$label: units follow the unit rules" "$(unit_problems "$d")"
  check_none "$label: titled blanks say \"Planned\"" "$(printf '%s\n' "$d" | awk -F'|' '$2 == "blank" && $4 != "" && $5 != "Planned"')"
  check_none "$label: untitled blanks have no line" "$(printf '%s\n' "$d" | awk -F'|' '$2 == "blank" && $4 == "" && $5 != ""')"
  check_none "$label: published units show [date] and opening text" "$(printf '%s\n' "$d" | awk -F'|' '$2 == "live" && $5 !~ /^\[[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\] ./')"
  if [ "$state" = open ]; then
    check "open rack /$room/$slug/ is in sitemap.xml" in_sitemap "/${room}/${slug}/"
    check "open rack /$room/$slug/ is indexable (no robots meta)" not grep -Eq '<meta name="?robots' "$out"
    check "open rack /$room/$slug/ has no closed notice" not grep -Eq '<p class="?notice' "$out"
  else
    check "closed rack /$room/$slug/ is not in sitemap.xml" not in_sitemap "/${room}/${slug}/"
    check "closed rack /$room/$slug/ carries robots noindex" noindex "$out"
    check "closed rack /$room/$slug/ says \"Closed: no posts yet\"" grep -Eq '<p class="?notice"?>Closed: no posts yet\.</p>' "$out"
  fi
  # No rack `description`: the meta description falls back to the site description.
  if ! has_front_matter "content/${room}/${slug}/_index.md" description; then
    check "$label meta description falls back to the site description" sh -c 'test -n "$1" && test "$1" = "$2"' _ "$(meta_desc "$out")" "$(meta_desc public/index.html)"
  fi
done <<EOF
$RACK_TABLE
EOF
if [ -f "$FINDOUT_OUT" ]; then
  d="$(rack_units "$(rack_dump "$FINDOUT_OUT")" "$R1_TITLE")"
  check "Find-out rack page: U01 links to the post and shows its opening text" sh -c 'printf "%s\n" "$1" | grep -Eq "^U01[|]live[|]$2[|]If it works[^|]*[|]\[2026-11-14\] It all started around 2018"' _ "$d" "$P1_PATH"
fi
if [ -f "$OS_OUT" ]; then
  d="$(rack_units "$(rack_dump "$OS_OUT")" "$R2_TITLE")"
  check "Operating-systems rack page: U01 links to the post and shows its opening text" sh -c 'printf "%s\n" "$1" | grep -Eq "^U01[|]live[|]$2[|]My relationship[^|]*[|]\[2026-11-14\] When I built my first PC"' _ "$d" "$P2_PATH"
fi
# A closed room or rack is never linked, from any page.
closed_paths="$(printf '%s\n' "$ROOM_TABLE" | awk -F'|' '$4 == "closed" { print "/" $1 "/" }'; printf '%s\n' "$RACK_TABLE" | awk -F'|' '$5 == "closed" { print "/" $1 "/" $2 "/" }')"
check_none "no page links to a closed room or rack" "$(link_audit public "$closed_paths")"

# Tag pages: each unit names its room and rack.
if [ -f public/tags/hardware/index.html ]; then
  check "tag page /tags/hardware/: the unit kicker is \"Mindset · $R1_TITLE\"" test "$(SITE_URL="$SITE" perl -0777 -ne "$RACK_PERL"'print txt($1) if /<p class="?unit__kicker"?>(.*?)<\/p>/s' public/tags/hardware/index.html)" = "Mindset · $R1_TITLE"
fi
check "tags page counts posts (\"1 post\")" grep -Eq '<p class="?term-card__count"?>1 post</p>' public/tags/index.html

# Blanks never link, on any page.
blank_links="$(find public -type f -name '*.html' -print0 | xargs -0 perl -0777 -ne '
  while (/<li class="?(?:card unit\b[^"\x27>]*\bunit--blank|rack-box__item\b[^"\x27>]*\bis-blank)\b.*?<\/li>/sg) { print "$ARGV\n" if $& =~ /<a\b/ }' | sort -u || true)"
check_none "no blank unit anywhere in public/ contains a link" "$blank_links"

# The same with drafts too: every post is a linked unit on one home page, no paginated
# section or taxonomy pages, no table of contents.
alt="$(mktemp -d "${TMPDIR:-/tmp}/hugo-check-alt.XXXXXX")"
if hugo --minify --buildDrafts --buildFuture --destination "$alt" >"$log" 2>&1 && ! grep -Eq '^(WARN|ERROR)' "$log"; then
  pass "build with drafts has no WARN/ERROR"
else
  fail "build with drafts has no WARN/ERROR"; sed 's/^/        /' "$log"
fi
all_count="$(hugo list all 2>/dev/null | perl -ne '$n++ if /,page,[^,]+\s*$/; END { print $n + 0 }')"
live="$( { floor_dump "$alt/index.html" 2>/dev/null || true; } | awk -F'|' '$2 == "live"' | wc -l | tr -d ' ')"
check "home page with drafts links all $all_count posts on one page (found $live)" test "$live" = "$all_count"
check "build with drafts has no paginated pages" sh -c 'test -z "$(find "$1" -type d -name page)"' _ "$alt"
toc_pages="$(find "$alt" -type f -name '*.html' -print0 | xargs -0 grep -ElI 'TableOfContents|data-toc|class="?toc' || true)"
check "build with drafts renders no table of contents on any page" test -z "$toc_pages"
rm -rf "$alt"

# RSS: well-formed XML (only XML's own named entities), items = the published posts, each
# described by the post's opening text; no rack title without posts in a feed or sitemap.
if [ -f public/index.xml ]; then
  check "RSS feed uses no entities undefined in XML (e.g. &rsquo;)" perl -ne 'exit 1 if /&(?!(?:amp|lt|gt|quot|apos|#[0-9]+|#x[0-9a-fA-F]+);)/' public/index.xml
  # xmllint is optional locally (macOS ships it); CI installs it and must not skip the check.
  if command -v xmllint >/dev/null 2>&1; then
    check "RSS feed is well-formed XML (xmllint)" xmllint --noout public/index.xml
    check "sitemap is well-formed XML (xmllint)" xmllint --noout public/sitemap.xml
  elif [ -n "${CI:-}" ]; then
    fail "RSS feed is well-formed XML (xmllint is not installed on CI)"
  fi
  rss_item() { # rss_item PATH: print the <description> of the item linking to PATH.
    L="${SITE}$1" perl -0777 -ne 'while (/<item>(.*?)<\/item>/sg) { my $i = $1; print $1 if $i =~ /<link>\Q$ENV{L}\E<\/link>/ && $i =~ /<description>(.*?)<\/description>/s }' public/index.xml
  }
  check "RSS item of Mindset U01 is described by its opening text" starts_with "$(rss_item "$P1_PATH")" 'It all started around 2018'
  check "RSS item of Homelab U01 is described by its opening text" starts_with "$(rss_item "$P2_PATH")" 'When I built my first PC'
  rss_links="$(perl -0777 -ne 'print "$1\n" while /<item>.*?<link>(.*?)<\/link>/sg' public/index.xml | sort)"
  want_links="$(printf '%s\n' "$posts" | while read -r src path; do if [ -n "$path" ]; then printf '%s%s\n' "$SITE" "$path"; fi; done | sort)"
  check_eq "RSS items are exactly the published posts" "$rss_links" "$want_links"
fi
planned_leaks="$(printf '%s\n' "$PLANNED_TITLES" | while read -r t; do
  for f in $(find public -name '*.xml'); do grep -Fq "$t" "$f" && printf '%s: %s\n' "${f#public}" "$t"; done
done || true)"
check_none "no title of a rack without posts appears in any feed or sitemap" "$planned_leaks"
# The sitemap: the home, the open rooms and racks, the posts and the tag pages; nothing closed.
sitemap_want="$( { printf '/\n/tags/\n'; printf '%s\n' "$ROOM_TABLE" | awk -F'|' '$4 == "open" { print "/" $1 "/" }'
  printf '%s\n' "$RACK_TABLE" | awk -F'|' '$5 == "open" { print "/" $1 "/" $2 "/" }'
  printf '%s\n' "$posts" | awk 'NF { print $2 }'
  find public/tags -mindepth 2 -name index.html | sed 's|^public||; s|index\.html$||'; } | sort)"
check_eq "sitemap.xml lists exactly the home, the open rooms and racks, the posts and the tag pages" "$(S="$SITE" perl -0777 -ne 'while (/<loc>(.*?)<\/loc>/g) { my $l = $1; $l =~ s/^\Q$ENV{S}\E//; print "$l\n" }' public/sitemap.xml 2>/dev/null | sort)" "$sitemap_want"

# Every page has a non-empty meta description.
empty_desc="$(find public -type f -name '*.html' -print0 |
  xargs -0 perl -0777 -ne 'next if /<meta http-equiv="?refresh/; print "$ARGV\n" unless /<meta name="?description"? content=(["\x27]?)\s*[^\s"\x27>]/' | sort -u || true)"
check_none "every HTML page has a non-empty meta description" "$empty_desc"

# --- 4a. Content model (fitness functions) ------------------------------------
fm_bad="$(find content -name '*.md' -print0 | xargs -0 perl -0777 -ne 'print "$ARGV\n" if /\A---\n(.*?)\n---/s && $1 =~ /^(?:series|part):/m' | sort -u || true)"
check_none "no content front matter has a series: or part: key" "$fm_bad"
check "hugo.toml has no series taxonomy" sh -c 'hugo config --format json 2>/dev/null | perl -MJSON::PP -0777 -ne "my \$t = decode_json(\$_)->{taxonomies} // {}; exit(exists \$t->{series} || grep({ \$_ eq q(series) } values %\$t) ? 1 : 0)"'
check "hugo.toml has no featuredSeries and no posts permalink" sh -c '! grep -Eq "featuredSeries|^[[:space:]]*posts[[:space:]]*=" hugo.toml'
series_code="$( { find layouts archetypes -iname '*series*'; grep -rli 'series' layouts archetypes; } 2>/dev/null | sort -u || true)"
check_none "no \"series\" in layouts/ or archetypes/ (file names or template code)" "$series_code"
for f in layouts/_partials/start-here.html layouts/_partials/series-info.html layouts/_partials/series-parts.html layouts/_partials/post-card.html archetypes/posts.md content/posts content/series; do
  check "$f is gone" test ! -e "$f"
done
check "archetypes/default.md asks for the post's unit" grep -Eq '^unit:' archetypes/default.md
check "archetypes/default.md speaks of posts and racks, not chapters" not grep -qi 'chapter' archetypes/default.md
# The tree: content/<room>/_index.md, content/<room>/<rack>/_index.md, posts one level below.
# The user: a rack is a topic, a post one story on it; they never share a title.
rack_post_titles() { # rack_post_titles DIR: print every post of DIR titled like its rack.
  local f p rt
  for f in "$1"/*/*/_index.md; do
    [ -f "$f" ] || continue
    rt="$(fm_title "$f")"
    for p in "$(dirname "$f")"/*/index.md; do
      if [ -f "$p" ] && [ "$(fm_title "$p")" = "$rt" ]; then printf '%s: titled like its rack (%s)\n' "$p" "$rt"; fi
    done
  done
}
fm_title() { perl -0777 -ne 'print $2 if /\A---\n(.*?)\n---/s && $1 =~ /^title:[ \t]*(["\x27]?)(.*?)\1[ \t]*$/m' "$1"; }
check_none "no rack has the title of one of its posts" "$(rack_post_titles content)"
check_none "every room folder and every rack folder has an _index.md" "$(tree_problems content || true)"
check_none "every room and rack has an integer weight, unique among its siblings" "$(weight_problems content || true)"
check "room folders are the seven rooms" test "$(find content -mindepth 1 -maxdepth 1 -type d | sed 's|^content/||' | sort | tr '\n' ' ')" = "$(printf '%s\n' "$ROOM_TABLE" | cut -d'|' -f1 | sort | tr '\n' ' ')"
check "rack folders are the six racks" test "$(find content -mindepth 3 -maxdepth 3 -name _index.md | sed 's|^content/||; s|/_index\.md$||' | sort | tr '\n' ' ')" = "$(printf '%s\n' "$RACK_TABLE" | awk -F'|' '{ print $1 "/" $2 }' | sort | tr '\n' ' ')"
check_none "no room slug is a taxonomy URL (tags)" "$(room_slug_problems content || true)"
check_none "no \"server-room\" in content/, layouts/ or hugo.toml (names or text)" "$( { find content layouts -iname '*server-room*'; grep -rli 'server-room' content layouts hugo.toml; } 2>/dev/null | sort -u || true)"
check_none "no \"server-room\" in any public/ path" "$(find public -path '*server-room*' || true)"
check_none "no homeServerRoom left in hugo.toml or layouts/" "$(grep -rli 'homeServerRoom' hugo.toml layouts 2>/dev/null || true)"
check_none "no content front matter has aliases" "$(find content -name '*.md' -print0 | xargs -0 perl -0777 -ne 'print "$ARGV\n" if /\A---\n(.*?)\n---/s && $1 =~ /^aliases:/m' | sort -u || true)"
check "content/_index.md splits the lead from the rest of the intro with <!--more-->" grep -q '^<!--more-->$' content/_index.md
check "the publishResources cascade targets posts by kind, not by path" perl -0777 -ne 'exit(/\[cascade\.target\]\s*\n\s*kind\s*=\s*"page"/ && !/\[cascade\.target\]\s*\n\s*path\s*=/ ? 0 : 1)' hugo.toml

# --- 4b. Header ---------------------------------------------------------------
# Wordmark home on the left, icons on the right, no text nav links.
for out in public/index.html "$MINDSET_OUT" "$FINDOUT_OUT" "$P1_OUT" public/tags/index.html; do
  [ -f "$out" ] || continue
  hdr="$(block "$out" '<header class="?site-header.*?<\/header>')"
  label="header of ${out#public}"
  check "$label has the wordmark linking home" header_has "$hdr" '<a\b(?=[^>]*class="?wordmark)(?=[^>]*href="?(?:https?://[^/"]+)?/"?[\s>])[^>]*>Verryx</a>'
  check "$label has no \"Blog\" link" sh -c '! printf %s "$1" | grep -Eq ">[[:space:]]*Blog[[:space:]]*</a>"' _ "$hdr"
  check "$label has no link to /series/ or /posts/" sh -c '! printf %s "$1" | grep -Eq "$2|$3"' _ "$hdr" "$(href_re /series/)" "$(href_re /posts/)"
  check "$label has no text nav (every link is the wordmark or an icon)" only_wordmark_and_icons "$hdr"
  check "$label keeps the GitHub and RSS icons" sh -c 'printf %s "$1" | grep -q "GitHub profile" && printf %s "$1" | grep -q "RSS feed"' _ "$hdr"
  # Footer: the copyright line only, no text links.
  ftr="$(block "$out" '<footer class="?site-footer.*?<\/footer>')"
  check "footer of ${out#public} has the copyright line" sh -c 'printf %s "$1" | grep -q "site-footer__copy"' _ "$ftr"
  check "footer of ${out#public} has no links (no GitHub/RSS text links)" sh -c 'test -n "$1" && ! printf %s "$1" | grep -Eq "<a[[:space:]>]|>GitHub<|>RSS<"' _ "$ftr"
  check "head of ${out#public} keeps the RSS alternate link" grep -Eq '<link rel="?alternate"? type="?application/rss\+xml' "$out"
done

# The header never moves: fixed to the top, no rubber-band bounce, constant height.
check "main.css: .site-header is position: fixed at top 0, full width" sh -c 'printf %s "$1" | grep -Eq "position:[[:space:]]*fixed" && printf %s "$1" | grep -Eq "top:[[:space:]]*0" && printf %s "$1" | grep -Eq "(left:[[:space:]]*0.*right:[[:space:]]*0|inset:[[:space:]]*0 0 auto|width:[[:space:]]*100%)"' _ "$(css_rule .site-header | tr '\n' ' ')"
check "main.css: .site-header has a fixed height (var(--header-height))" sh -c 'printf %s "$1" | grep -Eq "(^|[^-])height:[[:space:]]*var\(--header-height\)"' _ "$(css_rule .site-header)"
check "main.css: html has overscroll-behavior: none" sh -c 'printf %s "$1" | grep -Eq "overscroll-behavior:[[:space:]]*none"' _ "$(css_rule html)"
check "main.css: body has overscroll-behavior: none" sh -c 'printf %s "$1" | grep -Eq "overscroll-behavior:[[:space:]]*none"' _ "$(css_rule body)"
check "main.css: body is offset by the header height" sh -c 'printf %s "$1" | grep -Eq "padding-top:[[:space:]]*var\(--header-height\)"' _ "$(css_rule body)"
check "main.css: scroll-padding-top equals the header height" sh -c 'printf %s "$1" | grep -Eq "scroll-padding-top:[[:space:]]*var\(--header-height\)[[:space:]]*;"' _ "$(css_rule html)"
check "main.css: header inner height is fixed, not min-height" sh -c 'printf %s "$1" | grep -Eq "(^|[^-])height:[[:space:]]*100%" && ! printf %s "$1" | grep -q "min-height"' _ "$(css_rule .site-header__inner)"

# Removed features leave no CSS, JS or templates behind.
check "main.css has no table-of-contents rules" sh -c 'perl -ne "exit 1 if /\\.toc\\b|toc__|container--wide|article--toc|--toc-width/" "$1"' _ "$css_src"
check "main.css has no pagination rules" sh -c '! grep -q "pagination" "$1"' _ "$css_src"
check "main.css has no footer link rules" sh -c '! grep -q "site-footer__links" "$1"' _ "$css_src"
check "no assets/js/main.js (no JavaScript left)" test ! -e assets/js/main.js
check "no scripts partial" test ! -e layouts/_partials/scripts.html
check "page.html has no TOC logic" sh -c '! grep -Eqi "TableOfContents|toc" "$1"' _ layouts/page.html

# --- 4c. Dark only -------------------------------------------------------------
# No theme toggle, no stored theme, a single dark colour scheme.
theme_bad="$(find public -type f \( -name '*.html' -o -name '*.js' \) -print0 |
  xargs -0 perl -0777 -ne 's/<script\b[^>]*\ssrc=["\x27]?https:\/\/giscus\.app\/client\.js[^>]*>//g; print "$ARGV\n" if /data-theme|localStorage|theme-toggle/' | sort -u || true)"
if [ -z "$theme_bad" ]; then
  pass "no theme toggle, data-theme or localStorage in generated HTML/JS"
else
  fail "no theme toggle, data-theme or localStorage in generated HTML/JS"; printf '%s\n' "$theme_bad" | sed 's/^/        /'
fi
scheme_bad="$(find public -type f -name '*.html' -print0 |
  xargs -0 perl -0777 -ne 'next if /<meta http-equiv="?refresh/; print "$ARGV\n" unless /<meta name="?color-scheme"? content=(["\x27]?)dark\1[\s\/>]/' | sort -u || true)"
if [ -z "$scheme_bad" ]; then
  pass "every HTML page (redirects aside) declares color-scheme \"dark\""
else
  fail "every HTML page (redirects aside) declares color-scheme \"dark\""; printf '%s\n' "$scheme_bad" | sed 's/^/        /'
fi
check "main.css has no light theme or theme switch (prefers-color-scheme, data-theme, .theme-toggle)" sh -c '! grep -Eq "prefers-color-scheme|data-theme|theme-toggle" "$1"' _ "$css_src"
check "main.css has no motto band styles" sh -c '! grep -q "band--motto" "$1"' _ "$css_src"
check "main.css has no unit counter and no dimmed LED" sh -c '! grep -Eq "counter\(unit|--led-off" "$1"' _ "$css_src"
check "main.css draws unit and port labels from markup (no CSS counter at all)" sh -c '! grep -Eq "counter\(|counter-(reset|increment)" "$1"' _ "$css_src"
check "main.css has no series, Start here or post-card rules" sh -c '! grep -Eqi "series|start-here|post-card" "$1"' _ "$css_src"
# Blanking panels: a steady red LED (no activity animation, no hover slide).
check "main.css defines the blank LED colour (--led-blank, a red)" perl -0777 -ne 'exit(/--led-blank:\s*#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2});/ && hex($1) >= 0xe0 && hex($2) < 0x80 && hex($3) < 0x80 ? 0 : 1)' "$css_src"
check "blank LED contrasts at least 3:1 with the panel (WCAG 1.4.11)" perl -0777 -ne '
  sub lum { my @c = map { my $v = hex($_) / 255; $v <= 0.03928 ? $v / 12.92 : (($v + 0.055) / 1.055) ** 2.4 } $_[0] =~ /(..)(..)(..)/; 0.2126 * $c[0] + 0.7152 * $c[1] + 0.0722 * $c[2] }
  my ($r) = /--led-blank:\s*#([0-9a-fA-F]{6});/; my ($p) = /--panel:\s*#([0-9a-fA-F]{6});/; exit 1 unless $r && $p;
  my ($a, $b) = sort { $b <=> $a } (lum($r), lum($p)); exit((($a + 0.05) / ($b + 0.05)) >= 3 ? 0 : 1)' "$css_src"
check "blank units use the red LED, steady (no animation)" sh -c 'printf %s "$1" | grep -Eq "background:[[:space:]]*var\(--led-blank\)" && printf %s "$1" | grep -Eq "animation:[[:space:]]*none"' _ "$(css_rule '.unit--blank::after')"
check "only live units slide out on hover" sh -c 'test -n "$1" && test -z "$2" && test -z "$3"' _ "$(css_rule .unit--live:hover)" "$(css_rule .unit:hover)" "$(css_rule .unit--blank:hover)"
check "main.css has a visually-hidden utility (clip, 1px)" sh -c 'printf %s "$1" | grep -q "clip" && printf %s "$1" | grep -Eq "(^|[^-])width:[[:space:]]*1px"' _ "$(css_rule .visually-hidden)"
# The switch: lit ports green and steady, unlit ports their own token (never a unit's),
# ice-blue cables for open rooms, dark grey for closed ones, rows on a phone.
check "main.css defines the unlit port LED token (--port-unlit)" grep -Eq -- '--port-unlit:[[:space:]]*#[0-9a-fA-F]{6};' "$css_src"
check_none "no unit or rack-box rule uses --port-unlit (blanks keep the red LED)" "$(perl -0777 -ne 'while (/([^{}]+)\{([^{}]*)\}/g) { my ($s, $b) = ($1, $2); $s =~ s/^\s+|\s+$//g; print "$s\n" if $s =~ /\.(?:unit|rack-box)/ && $b =~ /--port-unlit/ }' "$css_src")"
check "lit port LED is green (var(--led))" sh -c 'printf %s "$1" | grep -Eq "background:[[:space:]]*var\(--led\)"' _ "$(css_rule '.switch__port--up .switch__led')"
check_none "switch ports and LEDs are never animated (steady)" "$(perl -0777 -ne 'while (/([^{}]+)\{([^{}]*)\}/g) { my ($s, $b) = ($1, $2); $s =~ s/^\s+|\s+$//g; print "$s\n" if $s =~ /switch__(?:led|jack|port)/ && $b =~ /animation(?:-name)?:\s*(?!none)/ }' "$css_src")"
check "unlit port LED uses --port-unlit with no glow" sh -c 'printf %s "$1" | grep -Eq "background:[[:space:]]*var\(--port-unlit\)" && printf %s "$1" | grep -Eq "box-shadow:[[:space:]]*none"' _ "$(css_rule '.switch__port--down .switch__led')"
check "open-room cables are ice blue (--cable: var(--ice))" sh -c 'printf %s "$1" | grep -Eq -- "--cable:[[:space:]]*var\(--ice\)"' _ "$(css_rule .switch__port--up)"
check "closed-room cables are dark grey (--cable: var(--cable-unlit), a neutral dark grey)" sh -c 'printf %s "$1" | grep -Eq -- "--cable:[[:space:]]*var\(--cable-unlit\)" && perl -0777 -ne "exit 1 unless /--cable-unlit:\\s*#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2});/; my @c = map { hex } (\$1, \$2, \$3); my (\$mx) = sort { \$b <=> \$a } @c; my (\$mn) = sort { \$a <=> \$b } @c; exit(\$mx - \$mn <= 0x18 && \$mx <= 0x60 ? 0 : 1)" "$2"' _ "$(css_rule .switch__port--down)" "$css_src"
check "the switch stands vertical below its one-row breakpoint (ports as rows, so every cable reaches the tray)" perl -0777 -ne 'exit(/\@media\s*\(max-width:\s*\d+px\)\s*\{(?:[^{}]*\{[^}]*\})*?[^{}]*\.switch__port\b[^{}]*\{[^}]*grid-template-columns/ ? 0 : 1)' "$css_src"
# One-row switch (1000px and wider): the ports, spares included, share the faceplate evenly
# (no plate column), so the row is centred between the two trays; the labels are horizontal
# and wrap only at spaces, never hyphenated or broken mid-word.
check "one-row switch: every port one width, the row spanning the faceplate (repeat(var(--ports), minmax(0, 1fr)), no plate, no narrow spares)" sh -c 'printf %s "$1" | grep -Eq "grid-template-columns:[[:space:]]*repeat\(var\(--ports\),[[:space:]]*minmax\(0,[[:space:]]*1fr\)\)" && ! printf %s "$1" | grep -q "grid-auto-columns" && ! grep -Eq "switch__plate|--plate-w|--spare-w" "$2" layouts/_partials/switch.html' _ "$(css_rule .switch__ports)" "$css_src"
check_none "switch labels are horizontal and may wrap at spaces (no vertical writing-mode, no nowrap in any .switch__tag rule)" "$(perl -0777 -ne 'while (/([^{}]+)\{([^{}]*)\}/g) { my ($s, $b) = ($1, $2); $s =~ s{/\*.*?\*/}{}gs; $s =~ s/^\s+|\s+$//g; print "$s\n" if $s =~ /\.switch__tag\b/ && $b =~ /writing-mode:\s*vertical|white-space:\s*nowrap/ }' "$css_src")"
# CSS comments are closed before the next one opens (an unclosed comment silently swallows
# the rules after it), and the room container's width survives into the inlined CSS.
check_none "main.css has no comment that contains another comment opener (an unclosed /* swallows rules)" "$(perl -0777 -ne 'my $n = 0; while (/\/\*(.*?)\*\//sg) { $n++; print "comment $n: ", substr($1, 0, 60) =~ s/\n/ /gr, "\n" if $1 =~ /\/\*/ }' "$css_src")"
check "the room container's max-width is live in the inlined CSS (not commented out)" perl -0777 -ne 'my ($c) = /<style>(.*?)<\/style>/s; exit($c =~ /\.container--room\{[^}]*max-width:/ ? 0 : 1)' public/index.html
# Switch labels: whole words only. body sets overflow-wrap: break-word, which a label would
# inherit (breaking "ENGINEERI-NG"), so the label resets it explicitly.
check "switch labels reset word breaking (overflow-wrap: normal, word-break: normal, hyphens: manual)" sh -c 'printf %s "$1" | grep -Eq "overflow-wrap:[[:space:]]*normal" && printf %s "$1" | grep -Eq "word-break:[[:space:]]*normal" && printf %s "$1" | grep -Eq "hyphens:[[:space:]]*manual"' _ "$(css_rule .switch__tag)"
check_none "no .switch__tag rule breaks words, and every inherited word breaking is reset by .switch__tag" "$(perl -0777 -ne 's{/\*.*?\*/}{}gs; my ($reset, @bad, @inh);
  while (/([^{}]+)\{([^{}]*)\}/g) { my ($s, $b) = ($1, $2); $s =~ s/^\s+|\s+$//g;
    if ($s =~ /\.switch__tag\b/) { push @bad, "$s: $1" while $b =~ /((?:overflow-wrap|word-wrap|word-break|hyphens)\s*:\s*+(?!normal|manual)[^;]+)/g; $reset = 1 if $s eq ".switch__tag" && $b =~ /overflow-wrap:\s*normal/ && $b =~ /word-break:\s*normal/ }
    elsif ($b =~ /(?:overflow-wrap|word-wrap):\s*(?:anywhere|break-word)|word-break:\s*break-(?:all|word)/) { push @inh, $s } }
  print "$_\n" for @bad; print "inherited by the labels, not reset: $_\n" for ($reset ? () : @inh)' "$css_src")"
# Wide ports: the one-row switch is used only where every port gets --port-min. Media queries
# cannot read custom properties, so the breakpoint is written out; it must equal
# ports x --port-min + both trays (4 x --tray-pad + rooms x --lane) + 2 x --gutter.
port_min="$(perl -0777 -ne 's{/\*.*?\*/}{}gs; print $1 if /--port-min:\s*(\d+)px/' "$css_src")"
row_bp="$(perl -0777 -ne 's{/\*.*?\*/}{}gs; print $1 + 1 if /\@media\s*\(max-width:\s*(\d+)px\)\s*\{\s*\.switch\s*\{/' "$css_src")"
want_bp="$(P="$(( (room_count + 7) / 8 * 8 ))" M="${port_min:-0}" R="$room_count" perl -0777 -ne 's{/\*.*?\*/}{}gs; my ($pad) = /\.server-hall\s*\{[^}]*--tray-pad:\s*(\d+)px/; my ($lane) = /\.server-hall\s*\{[^}]*--lane:\s*(\d+)px/; my ($g) = /--gutter:\s*(\d+)px/;
  print $ENV{P} * $ENV{M} + 4 * $pad + $ENV{R} * $lane + 2 * $g' "$css_src")"
check "main.css defines the switch port minimum (--port-min, found ${port_min:-none}px) of at least 125px" sh -c 'test -n "$1" && test "$1" -ge 125' _ "$port_min"
check "the one-row switch starts at ${row_bp:-?}px = ports x --port-min + both trays + gutters (${want_bp:-?}px), so no port is narrower than --port-min" sh -c 'test -n "$1" && test "$1" = "$2"' _ "$row_bp" "$want_bp"
check "the room container is wide enough for the one-row switch at its breakpoint (max-width >= ${want_bp:-?}px)" sh -c 'w="$(M="$3" perl -0777 -ne "s{/\\*.*?\\*/}{}gs; if (/\\.container--room\\s*\\{[^}]*max-width:\\s*([^;]+);/) { my \$v = \$1; if (\$v =~ /^(\\d+)px\$/) { print \$1 } elsif (\$v =~ /^calc\\((\\d+) \\* var\\(--port-min\\) \\+ (\\d+)px\\)\$/) { print \$1 * \$ENV{M} + \$2 } }" "$2")"; test -n "$w" && test "$w" -ge "$1"' _ "${want_bp:-99999}" "$css_src" "${port_min:-0}"
# Fixed, standard rack sizes: every slot one height, the label plate one height, racks one
# width. A compact rack shows all its units (at least 3): one with more grows by whole units;
# no bay ever scrolls (a scrolling bay captured the wheel and blocked the page scroll).
check "compact rack bays never scroll: units in rows of var(--unit-h), no fixed bay height, no overflow" sh -c 'printf %s "$1" | grep -Eq "grid-auto-rows:[[:space:]]*var\(--unit-h\)" && ! printf %s "$1" | grep -Eq "(^|[^-])height:|overflow"' _ "$(css_rule '.rack--compact .rack__bay')"
check_none "no rack bay rule scrolls (overflow auto or scroll, scrollbar styles) and rack.html adds no scroll affordance (tabindex)" "$( { perl -0777 -ne 'while (/([^{}]+)\{([^{}]*)\}/g) { my ($s, $b) = ($1, $2); $s =~ s{/\*.*?\*/}{}gs; $s =~ s/^\s+|\s+$//g; print "$s\n" if $s =~ /rack__bay/ && ($b =~ /overflow(?:-[xy])?:\s*(?:auto|scroll)|scrollbar-/ || $s =~ /scrollbar/) }' "$css_src"; grep -n 'tabindex\|rack__bay--scroll' layouts/_partials/rack.html; } || true)"
check "compact units have one fixed height (height: var(--unit-h), no min-height)" sh -c 'printf %s "$1" | grep -Eq "(^|[^-])height:[[:space:]]*var\(--unit-h\)" && ! printf %s "$1" | grep -q "min-height"' _ "$(css_rule '.rack--compact .unit')"
check "compact unit titles clamp to 2 lines" sh -c 'printf %s "$1" | grep -Eq -- "-webkit-line-clamp:[[:space:]]*2" && printf %s "$1" | grep -Eq "overflow:[[:space:]]*hidden"' _ "$(css_rule '.rack--compact .unit__title')"
check "the rack label plate has a fixed height (height: var(--cap-h), no min-height)" sh -c 'printf %s "$1" | grep -Eq "(^|[^-])height:[[:space:]]*var\(--cap-h\)" && ! printf %s "$1" | grep -q "min-height"' _ "$(css_rule .rack__cap)"
check "rack names clamp to 2 lines on the plate" sh -c 'printf %s "$1" | grep -Eq -- "-webkit-line-clamp:[[:space:]]*2" && printf %s "$1" | grep -Eq "overflow:[[:space:]]*hidden"' _ "$(css_rule .rack__name)"
check "floor racks: one fixed width each (flex: 0 0 var(--rack-w)), rows wrapped and centred, racks top-aligned" sh -c 'printf %s "$1" | grep -Eq "display:[[:space:]]*flex" && printf %s "$1" | grep -Eq "flex-wrap:[[:space:]]*wrap" && printf %s "$1" | grep -Eq "justify-content:[[:space:]]*center" && printf %s "$1" | grep -Eq "align-items:[[:space:]]*flex-start" && printf %s "$2" | grep -Eq "flex:[[:space:]]*0 0 var\(--rack-w\)"' _ "$(css_rule .floor__racks)" "$(css_rule '.floor__racks > .rack')"
check "full rack units have one fixed height (height: var(--unit-full-h))" sh -c 'printf %s "$1" | grep -Eq "(^|[^-])height:[[:space:]]*var\(--unit-full-h\)"' _ "$(css_rule '.rack--full .unit')"
check "full rack unit titles and opening text clamp to 2 lines" sh -c 'printf %s "$1" | grep -Eq -- "-webkit-line-clamp:[[:space:]]*2" && printf %s "$2" | grep -Eq -- "-webkit-line-clamp:[[:space:]]*2"' _ "$(css_rule '.rack--full .unit__title')" "$(css_rule '.rack--full .unit__line')"
# A powered-off rack (a closed room's floor): unlit unit LEDs, their own token, nowhere else.
check "main.css defines the unpowered LED token (--led-unpowered)" grep -Eq -- '--led-unpowered:[[:space:]]*#[0-9a-fA-F]{6};' "$css_src"
check "powered-off racks have unlit LEDs: --led-unpowered, no glow, steady" sh -c 'printf %s "$1" | grep -Eq "background:[[:space:]]*var\(--led-unpowered\)" && printf %s "$1" | grep -Eq "box-shadow:[[:space:]]*none" && printf %s "$1" | grep -Eq "animation:[[:space:]]*none"' _ "$(css_rule '.rack--off .unit::after')"
check_none "only powered-off racks use --led-unpowered (blanks elsewhere keep the red LED)" "$(perl -0777 -ne 'while (/([^{}]+)\{([^{}]*)\}/g) { my ($s, $b) = ($1, $2); $s =~ s{/\*.*?\*/}{}gs; $s =~ s/^\s+|\s+$//g; next if $s =~ /^:root$/; print "$s\n" if $b =~ /var\(--led-unpowered\)/ && $s !~ /^\.rack--off\b/ }' "$css_src")"
# Cables to the floors: the same colours as on the switch.
check "open-room cables in the floors and the tray are ice blue" sh -c 'printf %s "$1" | grep -Eq -- "--cable:[[:space:]]*var\(--ice\)" && printf %s "$2" | grep -Eq -- "--cable:[[:space:]]*var\(--ice\)"' _ "$(css_rule .floor--up)" "$(css_rule .tray__cable--up)"
check "closed-room cables in the floors and the tray are dark grey" sh -c 'printf %s "$1" | grep -Eq -- "--cable:[[:space:]]*var\(--cable-unlit\)" && printf %s "$2" | grep -Eq -- "--cable:[[:space:]]*var\(--cable-unlit\)"' _ "$(css_rule .floor--down)" "$(css_rule .tray__cable--down)"
check "patch port LEDs: lit green like the switch, unlit --port-unlit with no glow" sh -c 'printf %s "$1" | grep -Eq "background:[[:space:]]*var\(--led\)" && printf %s "$2" | grep -Eq "background:[[:space:]]*var\(--port-unlit\)" && printf %s "$2" | grep -Eq "box-shadow:[[:space:]]*none"' _ "$(css_rule '.patch--up .patch__led')" "$(css_rule '.patch--down .patch__led')"
check_none "patch ports and the tray are never animated" "$(perl -0777 -ne 'while (/([^{}]+)\{([^{}]*)\}/g) { my ($s, $b) = ($1, $2); $s =~ s/^\s+|\s+$//g; print "$s\n" if $s =~ /\b(?:patch|tray)/ && $b =~ /animation(?:-name)?:\s*(?!none)/ }' "$css_src")"
check "spare switch ports: unlit LED (--port-unlit, no glow) and a dust cap in the jack" sh -c 'printf %s "$1" | grep -Eq "background:[[:space:]]*var\(--port-unlit\)" && printf %s "$1" | grep -Eq "box-shadow:[[:space:]]*none" && printf %s "$2" | grep -Eq "background:[[:space:]]*var\(--dust-cap\)"' _ "$(css_rule '.switch__port--spare .switch__led')" "$(css_rule '.switch__jack--capped::after')"
check "the server hall isolates its cable stacking (isolation: isolate) and reserves both tray widths" sh -c 'printf %s "$1" | grep -Eq "isolation:[[:space:]]*isolate" && printf %s "$1" | grep -Eq "padding-left:[[:space:]]*var\(--tray-l-w\)" && printf %s "$1" | grep -Eq "padding-right:[[:space:]]*var\(--tray-r-w\)"' _ "$(css_rule .server-hall)"
check "the left tray hangs outside the floor's left edge, the right tray outside its right edge" sh -c 'printf %s "$1" | grep -Eq "(^|[^-])right:[[:space:]]*100%" && printf %s "$2" | grep -Eq "(^|[^-])left:[[:space:]]*100%"' _ "$(css_rule .tray--left)" "$(css_rule .tray--right)"
# Floor headings: the patch panel and the room name form one group centred in the floor (a
# grid whose first and last columns are equal flexible tracks); the cable from the tray fills
# the outer column on its tray's side, from the tray edge to the patch jack.
check "floor headings centre the patch + name group (grid, equal flexible first and last columns)" sh -c 'printf %s "$1" | grep -Eq "display:[[:space:]]*grid" && printf %s "$1" | perl -0777 -ne "exit(/grid-template-columns:\\s*minmax\\(([^,]+),\\s*1fr\\)\\s+(?:\\S+\\([^)]*\\)\\s+|\\S+\\s+)*?minmax\\(\\1,\\s*1fr\\)\\s*;/ ? 0 : 1)"' _ "$(css_rule .floor__head)"
check "the floor cable stretches across its outer column (justify-self: stretch, no fixed width or flex basis)" sh -c 'printf %s "$1" | grep -Eq "justify-self:[[:space:]]*stretch" && ! printf %s "$1" | grep -Eq "(^|[^-])(width|flex):"' _ "$(css_rule .floor__cable)"
check "a right-tray floor: name, patch panel, then the cable in the last column to the right tray edge" sh -c 'printf %s "$1" | grep -Eq "grid-column:[[:space:]]*5" && printf %s "$2" | grep -Eq "grid-column:[[:space:]]*4" && printf %s "$3" | grep -Eq "grid-column:[[:space:]]*2"' _ "$(css_rule '.floor--right .floor__cable')" "$(css_rule '.floor--right .patch')" "$(css_rule '.floor--right .floor__name')"
check "a left-tray floor: the cable in the first column from the left tray edge, the patch panel (mirrored), then the name" sh -c 'printf %s "$1" | grep -Eq "grid-column:[[:space:]]*1" && printf %s "$2" | grep -Eq "grid-column:[[:space:]]*2" && printf %s "$2" | grep -Eq "flex-direction:[[:space:]]*row-reverse" && printf %s "$3" | grep -Eq "grid-column:[[:space:]]*3"' _ "$(css_rule '.floor--left .floor__cable')" "$(css_rule '.floor--left .patch')" "$(css_rule '.floor--left .floor__name')"
check "a cable leaving the left tray lifts over the cables still in it (z-index above the passing lanes)" sh -c 'printf %s "$1" | grep -Eq "z-index:[[:space:]]*[1-9]"' _ "$(css_rule '.tray--left .tray__cable--exit::before')"

# --- 4f. Rack and room contract (scratch-content fixtures) ---------------------
# Copies of content/ with an extra room of racks ($FXROOM), built into temp dirs: the merge rules of
# rack-units.html (order, gaps, planned titles, padding to 3, no truncation), prev/next
# across blanks, the warning for a planned entry left behind, and the build errors.
fixture_dir() { # fixture_dir: print a new temp dir holding a copy of content/ and an empty public/.
  local d; d="$(mktemp -d "${TMPDIR:-/tmp}/hugo-check-rack.XXXXXX")"
  mkdir -p "$d/content" "$d/public"; cp -R content/. "$d/content/"; printf '%s' "$d"
}
# fx_room DIR SLUG WEIGHT [FRONT_MATTER]: write a room _index.md in fixture DIR.
fx_room() {
  mkdir -p "$1/content/$2"
  printf -- '---\ntitle: "Room %s"\nweight: %s\n%b---\n' "$2" "$3" "${4:-}" >"$1/content/$2/_index.md"
}
# fx_path SLUG: SLUG as a path under content/: ROOM/RACK as given, a bare RACK in room $FXROOM.
fx_path() { case "$1" in */*) printf '%s' "$1" ;; *) printf '%s/%s' "$FXROOM" "$1" ;; esac; }
# fx_rack DIR SLUG WEIGHT FRONT_MATTER [BODY]: write a rack _index.md in fixture DIR (SLUG: see fx_path).
fx_rack() {
  local p; p="$(fx_path "$2")"
  mkdir -p "$1/content/$p"
  printf -- '---\ntitle: "%s"\nweight: %s\n%b---\n\n%s\n' "Fixture ${p##*/}" "$3" "$4" "${5:-}" >"$1/content/$p/_index.md"
}
# fx_chapter DIR RACK FOLDER FRONT_MATTER: write a post in rack RACK (see fx_path), published unless FRONT_MATTER says otherwise.
fx_chapter() {
  local p; p="$(fx_path "$2")"
  mkdir -p "$1/content/$p/$3"
  printf -- '---\ntitle: "Chapter %s %s"\ndate: 2026-11-10\n%b---\n\nOpening text of %s.\n' "${p##*/}" "$3" "$4" "$3" >"$1/content/$p/$3/index.md"
}
fx_build() { # fx_build DIR [hugo flags]: build fixture DIR into DIR/public, log in $log.
  local d="$1"; shift
  hugo --minify --contentDir "$d/content" --destination "$d/public" "$@" >"$log" 2>&1
}
FXROOM="zz-fx"
FX="/${FXROOM}/"
fx="$(fixture_dir)"
fx_room "$fx" "$FXROOM" 90
# a: units 1 and 3 published, 2 planned (its post still a draft), with an intro and a description.
fx_rack "$fx" zz-a 91 'description: "Fixture A description."\nplanned:\n  - {unit: 2, title: "Planned two"}\n' 'Fixture A intro text.'
fx_chapter "$fx" zz-a one 'unit: 1\n'
fx_chapter "$fx" zz-a three 'unit: 3\n'
fx_chapter "$fx" zz-a two 'unit: 2\ndraft: true\n'
# The post at unit 1 also holds an SVG figure and a bundle file no template uses.
printf '\n{{< figure src="diagram.svg" alt="Diagram" >}}\n' >>"$fx/content/${FXROOM}/zz-a/one/index.md"
printf '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"/>\n' >"$fx/content/${FXROOM}/zz-a/one/diagram.svg"
printf 'not linked\n' >"$fx/content/${FXROOM}/zz-a/one/unused.txt"
# b: a gap at unit 2 with nothing planned.
fx_rack "$fx" zz-b 92 ''
fx_chapter "$fx" zz-b one 'unit: 1\n'
fx_chapter "$fx" zz-b three 'unit: 3\n'
# c: one published unit, nothing planned (padded to 3).
fx_rack "$fx" zz-c 93 ''
fx_chapter "$fx" zz-c one 'unit: 1\n'
# d: five positions (posts 1 and 5, planned 3, an untitled planned 4): not padded, not truncated.
fx_rack "$fx" zz-d 94 'planned:\n  - {unit: 3, title: "Planned three"}\n  - {unit: 4}\n'
fx_chapter "$fx" zz-d one 'unit: 1\n'
fx_chapter "$fx" zz-d five 'unit: 5\n'
if fx_build "$fx" && ! grep -Eq '^(WARN|ERROR)' "$log"; then
  pass "fixture build (racks a-d, a draft over a planned unit) has no WARN/ERROR"
else
  fail "fixture build (racks a-d, a draft over a planned unit) has no WARN/ERROR"; sed 's/^/        /' "$log"
fi
fxd="$(rack_dump "$fx/public/index.html" 2>/dev/null || true)"
check_eq "fixture a: U01..U03 in order, the planned U02 still a blank while its post is a draft" "$(rack_brief "$(rack_units "$fxd" "Fixture zz-a")")" "U01|live|${FX}zz-a/one/|Chapter zz-a one|
U02|blank||Planned two|Planned: Planned two
U03|live|${FX}zz-a/three/|Chapter zz-a three|"
check_eq "fixture b: a gap with nothing planned is an untitled blank" "$(rack_brief "$(rack_units "$fxd" "Fixture zz-b")")" "U01|live|${FX}zz-b/one/|Chapter zz-b one|
U02|blank|||Empty slot
U03|live|${FX}zz-b/three/|Chapter zz-b three|"
check_eq "fixture c: one published unit is padded to U01..U03" "$(rack_brief "$(rack_units "$fxd" "Fixture zz-c")")" "U01|live|${FX}zz-c/one/|Chapter zz-c one|
U02|blank|||Empty slot
U03|blank|||Empty slot"
check_eq "fixture d: five positions are neither padded nor truncated" "$(rack_brief "$(rack_units "$fxd" "Fixture zz-d")")" "U01|live|${FX}zz-d/one/|Chapter zz-d one|
U02|blank|||Empty slot
U03|blank||Planned three|Planned: Planned three
U04|blank|||Empty slot
U05|live|${FX}zz-d/five/|Chapter zz-d five|"
check_none "fixture units follow the unit rules" "$(unit_problems "$fxd")"
check "fixture d: a rack of five units grows to five units, no scrolling bay (home)" sh -c 'printf "%s\n" "$1" | grep -qxF "Fixture zz-d|5|on|shown|fixed|"' _ "$(bay_dump "$fx/public/index.html" 2>/dev/null || true)"
check "fixture d: the same on the room page" sh -c 'printf "%s\n" "$1" | grep -qxF "Fixture zz-d|5|on|shown|fixed|"' _ "$(bay_dump "$fx/public${FX}index.html" 2>/dev/null || true)"
check_none "fixture: racks of three units have fixed bays" "$(bay_dump "$fx/public${FX}index.html" 2>/dev/null | awk -F"|" '$2 == 3 && $5 != "fixed"')"
check "fixture d: the full rack page shows all five units, no scrolling bay" sh -c 'test "$(printf "%s\n" "$1" | cut -d"|" -f2,5)" = "5|fixed"' _ "$(bay_dump "$fx/public${FX}zz-d/index.html" 2>/dev/null || true)"
fa1="$fx/public${FX}zz-a/one/index.html"
fa3="$fx/public${FX}zz-a/three/index.html"
nav="$(block "$fa1" '<nav class="?post-nav.*?<\/nav>' 2>/dev/null || true)"
check "fixture a U01: \"Next unit\" skips the blank and goes to U03" nav_link "$nav" "${FX}zz-a/three/" next "Next unit"
check "fixture a U01: no previous unit" sh -c '! printf %s "$1" | grep -Eq "rel=\"?prev|Previous"' _ "$nav"
nav="$(block "$fa3" '<nav class="?post-nav.*?<\/nav>' 2>/dev/null || true)"
check "fixture a U03: \"Previous unit\" skips the blank and goes to U01" nav_link "$nav" "${FX}zz-a/one/" prev "Previous unit"
check "fixture a U03: no next unit (never crosses into another rack)" sh -c '! printf %s "$1" | grep -Eq "rel=\"?next|Next"' _ "$nav"
check "fixture a U03: rack box says \"U03 of 3\"" test "$(box_dump "$fa3" 2>/dev/null | head -n1)" = "HEAD|U03 of 3|Fixture zz-a|${FX}zz-a/"
fra="$fx/public${FX}zz-a/index.html"
check "fixture a rack page: the intro comes before the units" in_order "$fra" 'Fixture A intro text' '<li class="?card unit\b'
check "fixture a rack page: meta description is the rack description" test "$(meta_desc "$fra" 2>/dev/null)" = "Fixture A description."
check "fixture c rack page: meta description falls back to the site description" sh -c 'test -n "$1" && test "$1" = "$2"' _ "$(meta_desc "$fx/public${FX}zz-c/index.html" 2>/dev/null)" "$(meta_desc public/index.html)"
check "fixture: no draft post is built" test ! -e "$fx/public${FX}zz-a/two/index.html"
check "fixture: planned titles stay out of the feed and sitemap" sh -c '! grep -q "Planned two" "$1/index.xml" "$1/sitemap.xml"' _ "$fx/public"
# Bundle files are published only when a template asks for them (see 4e): the SVG figure
# is, through its RelPermalink; the unused file is not.
sa="$fx/public${FX}zz-a/one"
check "an SVG figure in a post bundle is published" test -s "$sa/diagram.svg"
check "an SVG figure's img src is its published URL" env P="${FX}zz-a/one/diagram.svg" perl -0777 -ne 'exit(/<figure>\s*<img\b[^>]*\ssrc=["\x27]?(?:https?:\/\/[^\/"\x27]+)?\Q$ENV{P}\E["\x27\s>]/ ? 0 : 1)' "$sa/index.html"
check "a bundle file no template uses is not published" test ! -e "$sa/unused.txt"
# e: with drafts, the draft post takes the place of its planned blank, without a warning.
rm -rf "$fx/public"; mkdir -p "$fx/public"
if fx_build "$fx" --buildDrafts && ! grep -Eq '^(WARN|ERROR)' "$log"; then
  pass "fixture e: a draft post over a planned unit builds with drafts without WARN/ERROR"
else
  fail "fixture e: a draft post over a planned unit builds with drafts without WARN/ERROR"; sed 's/^/        /' "$log"
fi
check "fixture e: with drafts, U02 is the draft post" sh -c 'printf "%s\n" "$1" | grep -q "^U02|live|$2|Chapter zz-a two|"' _ "$(rack_units "$(rack_dump "$fx/public/index.html" 2>/dev/null || true)" "Fixture zz-a")" "${FX}zz-a/two/"
rm -rf "$fx"
# d': a published post and a planned entry at the same unit: the post wins, the build warns.
fx="$(fixture_dir)"
fx_room "$fx" "$FXROOM" 90
fx_rack "$fx" zz-w 95 'planned:\n  - {unit: 1, title: "Left behind"}\n'
fx_chapter "$fx" zz-w one 'unit: 1\n'
fx_build "$fx" || true
check "fixture: a planned entry left behind by a published post is a WARN" grep -Eq '^WARN.*zz-w' "$log"
check "fixture: the published post wins over the planned entry" sh -c 'printf "%s\n" "$1" | grep -q "^U01|live|$2|Chapter zz-w one|"' _ "$(rack_units "$(rack_dump "$fx/public/index.html" 2>/dev/null || true)" "Fixture zz-w")" "${FX}zz-w/one/"
rm -rf "$fx"
# f, g and more: invalid units fail the build, naming the post.
while IFS='|' read -r label one two; do
  fx="$(fixture_dir)"
  fx_room "$fx" "$FXROOM" 90
  fx_rack "$fx" zz-x 96 ''
  fx_chapter "$fx" zz-x first "$one"
  [ -n "$two" ] && fx_chapter "$fx" zz-x second "$two"
  if fx_build "$fx"; then
    fail "fixture: $label fails the build"
  else
    check "fixture: $label fails the build, naming the post" grep -q 'zz-x' "$log"
  fi
  rm -rf "$fx"
done <<'EOF'
a post without unit|tags: []\n|
two posts with the same unit|unit: 2\n|unit: 2\n
a unit of 0|unit: 0\n|
a non-integer unit ("two")|unit: "two"\n|
a fractional unit (1.5)|unit: 1.5\n|
EOF

# Rooms. One fixture build: (a) a room with a rack and no post is closed; (b) the same with a
# published post is open; (c) a room whose only post is a draft is closed, then open in a build
# with drafts; (f) with two more empty rooms the site has twelve rooms: twelve ports.
# wide_widths DIR: print every `width: NNNpx` >= 400px (not min-/max-width) in DIR's CSS and HTML.
wide_widths() {
  find "$1" -type f \( -name '*.css' -o -name '*.html' \) -print0 |
    xargs -0 perl -ne 'while (/(?<![-\w])width\s*:\s*(\d+)px/g) { print "$ARGV: width:$1px\n" if $1 >= 400 }' || true
}
fx="$(fixture_dir)"
fx_room "$fx" zz-closed 81
fx_rack "$fx" zz-closed/r1 10 ''
fx_room "$fx" zz-open 82
fx_rack "$fx" zz-open/r1 10 ''
fx_chapter "$fx" zz-open/r1 one 'unit: 1\n'
fx_room "$fx" zz-draft 83
fx_rack "$fx" zz-draft/r1 10 ''
fx_chapter "$fx" zz-draft/r1 one 'unit: 1\ndraft: true\n'
fx_room "$fx" zz-empty-1 84
fx_room "$fx" zz-empty-2 85
check "room fixture has twelve rooms" test "$(find "$fx/content" -mindepth 2 -maxdepth 2 -name _index.md | wc -l | tr -d ' ')" = 12
if fx_build "$fx" && ! grep -Eq '^(WARN|ERROR)' "$log"; then
  pass "room fixture build (closed, open, draft-only and empty rooms) has no WARN/ERROR"
else
  fail "room fixture build (closed, open, draft-only and empty rooms) has no WARN/ERROR"; sed 's/^/        /' "$log"
fi
fp="$fx/public"
fsw="$(switch_dump "$fp/index.html" 2>/dev/null || true)"
ffl="$(floor_dump "$fp/index.html" 2>/dev/null || true)"
SITEMAP="$fp/sitemap.xml"
check "fixture (f): twelve rooms make twelve room ports" test "$(printf '%s\n' "$fsw" | grep -c .)" = 12
check_eq "fixture: the five new ports follow the room weights" "$(printf '%s\n' "$fsw" | tail -n 5 | cut -d'|' -f1,3)" "8|Room zz-closed
9|Room zz-open
10|Room zz-draft
11|Room zz-empty-1
12|Room zz-empty-2"
check_none "fixture (f): no fixed width >= 400px with twelve rooms" "$(wide_widths "$fp")"
check_eq "fixture: every room has a floor, open or closed, in weight order, its patch port matching its switch port" "$(printf '%s\n' "$ffl" | awk -F'|' '$1 == "FLOOR" { print $2 "|" $4 "|" $6 }')" "Mindset|/mindset/|lit
Homelab|/homelab/|lit
Software Engineering||unlit
Cybersecurity||unlit
AI||unlit
3D Printing||unlit
Future projects||unlit
Room zz-closed||unlit
Room zz-open|/zz-open/|lit
Room zz-draft||unlit
Room zz-empty-1||unlit
Room zz-empty-2||unlit"
fx_table="$(printf '%s\n' "$fsw" | awk -F'|' '{ print "r" $1 "|" $3 "||" ($2 == "lit" ? "open" : "closed") }')"
check_eq "fixture (f): with twelve rooms the tray at floor k carries the remaining cables of each tray, rooms 1-8 left and 9-12 right (no template change)" "$(printf '%s\n' "$ffl" | awk -F'|' '$1 == "FLOOR" { print $8 }')" "$(for k in $(seq 1 12); do tray_expect "$fx_table" "$k"; done)"
check_eq "fixture (f): twelve rooms make sixteen ports, four of them capped spares" "$(spare_dump "$fp/index.html" 2>/dev/null || true)" "$(spare_expect 12)"
check_eq "fixture (f): twelve rooms on sixteen ports: rooms 1-8 cabled left, 9-12 right (switch ports and floor patch panels)" "$(port_sides "$fp/index.html" 2>/dev/null || true)
$(printf '%s\n' "$ffl" | awk -F'|' '$1 == "FLOOR" { print $7 }' | paste -sd ' ' -)" "$(side_expect 12)
$(side_expect 12)"
check "fixture (f): the server hall sets --rooms: 12, --ports: 16 and --left: 8" sh -c 'case "$1" in "12 16 8 1 2 3 4 5 6 7 8 9 10 11 12") exit 0 ;; *) exit 1 ;; esac' _ "$(port_vars "$fp/index.html" 2>/dev/null || true)"
check "fixture (a): the closed room's floor holds one unnamed powered-off rack, not its own racks" sh -c 'test "$(printf "%s\n" "$1" | awk "/^FLOOR\\|Room zz-closed\\|/ { on = 1; next } /^FLOOR\\|/ { on = 0 } on")" = "$2"' _ "$(rack_brief "$ffl")" "$OFF_RACK"
check_eq "fixture (a): the closed room's port is unlit, its label unlinked and disabled" "$(printf '%s\n' "$fsw" | sed -n 8p)" "8|unlit|Room zz-closed||(closed, no posts yet)|span|true|hidden"
check "fixture (a): the closed room page carries robots noindex" noindex "$fp/zz-closed/index.html"
check "fixture (a): the closed rack page carries robots noindex" noindex "$fp/zz-closed/r1/index.html"
check "fixture (a): the closed room page says \"Closed: no posts yet\"" grep -Eq '<p class="?notice"?>Closed: no posts yet\.</p>' "$fp/zz-closed/index.html"
check "fixture (a): the closed room is not in the sitemap" not in_sitemap /zz-closed/
check "fixture (a): the closed rack is not in the sitemap" not in_sitemap /zz-closed/r1/
check_eq "fixture (a): the closed rack page names its room unlinked (closed)" "$(crumb_dump "$fp/zz-closed/r1/index.html")" "Room zz-closed|
Rack|"
check_eq "fixture (a): the closed room page shows its rack, name unlinked" "$(rack_brief "$(rack_dump "$fp/zz-closed/index.html")" | head -n1)" "RACK|Fixture r1||"
check_eq "fixture (b): the room with a published post has a lit port and a linked label" "$(printf '%s\n' "$fsw" | sed -n 9p)" "9|lit|Room zz-open|/zz-open/||a||hidden"
check "fixture (b): the open room and rack pages are indexable" sh -c '! grep -Eq "<meta name=\"?robots" "$1" "$2"' _ "$fp/zz-open/index.html" "$fp/zz-open/r1/index.html"
check "fixture (b): the open room is in the sitemap" in_sitemap /zz-open/
check "fixture (b): the open rack is in the sitemap" in_sitemap /zz-open/r1/
check "fixture (b): the open room's floor links its rack" sh -c 'printf "%s\n" "$1" | grep -qxF "RACK|Fixture r1||/zz-open/r1/"' _ "$ffl"
check_eq "fixture (c): a room whose only post is a draft is closed" "$(printf '%s\n' "$fsw" | sed -n 10p)" "10|unlit|Room zz-draft||(closed, no posts yet)|span|true|hidden"
check "fixture (c): the draft-only room is noindex and not in the sitemap" sh -c 'grep -Eq "<meta name=\"?robots\"? content=\"?noindex" "$1" && ! grep -Fq "/zz-draft/" "$2"' _ "$fp/zz-draft/index.html" "$SITEMAP"
check "fixture (c): the draft is not built" test ! -e "$fp/zz-draft/r1/one/index.html"
check_none "fixture: no page links to a closed room or rack" "$(link_audit "$fp" "/zz-closed/
/zz-closed/r1/
/zz-draft/
/zz-draft/r1/
/zz-empty-1/
/zz-empty-2/")"
rm -rf "$fp"; mkdir -p "$fp"
if fx_build "$fx" --buildDrafts && ! grep -Eq '^(WARN|ERROR)' "$log"; then
  pass "room fixture build with drafts has no WARN/ERROR"
else
  fail "room fixture build with drafts has no WARN/ERROR"; sed 's/^/        /' "$log"
fi
fsw="$(switch_dump "$fp/index.html" 2>/dev/null || true)"
check_eq "fixture (c): with drafts, the draft-only room has a lit port and a linked label" "$(printf '%s\n' "$fsw" | sed -n 10p)" "10|lit|Room zz-draft|/zz-draft/||a||hidden"
check "fixture (c): with drafts, the draft-only room's floor is open (name linked, patch port lit)" sh -c 'printf "%s\n" "$1" | grep -q "^FLOOR|Room zz-draft||/zz-draft/||lit|"' _ "$(floor_dump "$fp/index.html" 2>/dev/null || true)"
check "fixture (c): with drafts, the draft-only room is indexable" not noindex "$fp/zz-draft/index.html"
unset SITEMAP
rm -rf "$fx"
# (d) A post outside a rack fails the build, naming the file, and the tree check flags it.
while IFS='|' read -r label file flagged; do
  fx="$(fixture_dir)"
  mkdir -p "$fx/content/$(dirname "$file")"
  printf -- '---\ntitle: "Misplaced"\ndate: 2026-11-10\nunit: 1\n---\n\nMisplaced post.\n' >"$fx/content/$file"
  if fx_build "$fx"; then
    fail "fixture (d): $label fails the build"
  else
    check "fixture (d): $label fails the build, naming the file" grep -qF "$file" "$log"
  fi
  check "fixture (d): the tree check flags $label" sh -c 'printf "%s\n" "$1" | grep -qF "$2"' _ "$(tree_problems "$fx/content" || true)" "/content/$flagged: rack folder without _index.md"
  rm -rf "$fx"
done <<'EOF'
a post directly in a room|mindset/zz-stray/index.md|mindset/zz-stray
a post in a rack folder without _index.md|mindset/zz-norack/post/index.md|mindset/zz-norack
EOF
# (e) Room weights: a duplicate and a missing weight fail the weight check, naming them.
fx="$(fixture_dir)"
fx_room "$fx" zz-dup 1
fx_room "$fx" zz-noweight ''
fx_rack "$fx" mindset/zz-dup-rack 10 ''
wp="$(weight_problems "$fx/content" || true)"
check "fixture (e): a room with Mindset's weight fails the weight check" sh -c 'printf "%s\n" "$1" | grep -q "/content weight 1: duplicate weight"' _ "$wp"
check "fixture (e): a room without an integer weight fails the weight check" sh -c 'printf "%s\n" "$1" | grep -q "zz-noweight/_index.md: no integer weight"' _ "$wp"
check "fixture (e): a rack with the weight of a sibling rack fails the weight check" sh -c 'printf "%s\n" "$1" | grep -q "/content/mindset weight 10: duplicate weight"' _ "$wp"
rm -rf "$fx"
# A room named like the tags taxonomy is flagged.
fx="$(fixture_dir)"
fx_room "$fx" tags 99
check "fixture: a room named \"tags\" fails the room slug check" sh -c 'test -n "$1"' _ "$(room_slug_problems "$fx/content" || true)"
rm -rf "$fx"
# Spare ports: rooms filling the switch exactly leave no spare (8 rooms: 8 ports); one room more
# takes the next 8 ports (9 rooms: 16).
full=$(( (room_count + 7) / 8 * 8 ))
for rooms in "$full" "$((full + 1))"; do
  extra=$((rooms - room_count))
  fx="$(fixture_dir)"
  i=0; while [ "$i" -lt "$extra" ]; do i=$((i + 1)); fx_room "$fx" "zz-port-$i" "$((80 + i))"; done
  fx_build "$fx" || true
  check_eq "fixture: $rooms rooms make $(( (rooms + 7) / 8 * 8 )) ports, $(( (rooms + 7) / 8 * 8 - rooms )) of them capped spares" "$(spare_dump "$fx/public/index.html" 2>/dev/null || true)" "$(spare_expect "$rooms")"
  rm -rf "$fx"
done
# A rack titled like one of its posts is flagged.
fx="$(fixture_dir)"
fx_rack "$fx" mindset/zz-same 90 ''
fx_chapter "$fx" mindset/zz-same one 'unit: 1\n'
perl -pi -e 's/^title: .*/title: "Fixture zz-same"/' "$fx/content/mindset/zz-same/one/index.md"
check "fixture: a rack titled like its post fails the rack/post title check" sh -c 'printf "%s\n" "$1" | grep -q "zz-same/one/index.md: titled like its rack"' _ "$(rack_post_titles "$fx/content" || true)"
rm -rf "$fx"

# --- 4d. Comments (giscus) -------------------------------------------------------
# giscus renders only when params.giscus.repoId and categoryId are both set (hugo.toml, or
# HUGO_PARAMS_GISCUS_* in the environment), only on post pages, in a ".card comments" panel
# after the article and the post nav. Otherwise the build has no trace of it (no JS).
GISCUS_SRC="https://giscus.app/client.js"
# giscus_state: "on" when the current configuration sets both ids, else "off".
giscus_state() {
  hugo config --format json 2>/dev/null | perl -MJSON::PP -0777 -ne '
    my $g = ((decode_json($_)->{params} // {})->{giscus}) // {};
    print(($g->{repoid} // "") ne "" && ($g->{categoryid} // "") ne "" ? "on" : "off")' || echo off
}
giscus_on="$(giscus_state)"
# post_files DIR: the post pages (one per line) of a build in DIR.
post_files() {
  printf '%s\n' "$posts" | while read -r src path; do if [ -n "$path" ]; then printf '%s%sindex.html\n' "$1" "$path"; fi; done
}
# giscus_tag FILE: print the first giscus <script> tag of FILE.
giscus_tag() { perl -0777 -ne 'print $& if /<script\b[^>]*\ssrc=["\x27]?https:\/\/giscus\.app\/client\.js[^>]*>/s' "$1"; }
# attr TAG NAME: print the value of attribute NAME in TAG ("" when it has none); exit 1 if absent.
attr() {
  printf '%s' "$1" | N="$2" perl -0777 -ne '
    exit 1 unless /\s\Q$ENV{N}\E(?:=(?:"([^"]*)"|\x27([^\x27]*)\x27|([^\s>]*)))?(?=[\s>\/])/;
    print $1 // $2 // $3 // ""'
}
# script_audit DIR on|off: print the pages of DIR that load a <script src>, the giscus client
# on a post page aside when giscus is on.
script_audit() {
  find "$1" -type f -name '*.html' -print0 | P="$(post_files "$1")" M="$2" xargs -0 perl -0777 -ne '
    BEGIN { %post = map { $_ => 1 } split /\n/, $ENV{P} }
    next if /<meta http-equiv="?refresh/;
    s/<script\b[^>]*\ssrc=["\x27]?https:\/\/giscus\.app\/client\.js["\x27]?[\s>][^>]*>\s*<\/script>//g if $ENV{M} eq "on" && $post{$ARGV};
    print "$ARGV\n" if /<script\b[^>]*\ssrc=/' | sort -u || true
}
# giscus_audit DIR on|off LABEL [REPO_ID CATEGORY_ID]: assert on the build in DIR.
giscus_audit() {
  local dir="$1" mode="$2" label="$3" pf traces f p tag
  pf="$(post_files "$dir")"
  # Pages (HTML and XML) mentioning giscus or carrying the comments panel; post pages too when off.
  traces="$(find "$dir" -type f \( -name '*.html' -o -name '*.xml' \) -print0 | P="$pf" M="$mode" xargs -0 perl -0777 -ne '
    BEGIN { %post = map { $_ => 1 } split /\n/, $ENV{P} }
    next if $ENV{M} eq "on" && $post{$ARGV};
    print "$ARGV\n" if /giscus|class=["\x27]?card comments/i' | sort -u || true)"
  if [ "$mode" = off ]; then
    check_none "$label: no page has giscus markup or a giscus.app reference" "$traces"
    return
  fi
  check_none "$label: no page other than a post has giscus markup or a comments panel" "$traces"
  for f in $pf; do
    p="${f#"$dir"}"
    tag="$(giscus_tag "$f")"
    check "$label $p: has the giscus script" test -n "$tag"
    check "$label $p: exactly one giscus script" test "$(perl -0777 -ne 'my $n = () = /giscus\.app\/client\.js/g; print $n' "$f")" = 1
    check "$label $p: the script is inside the .card comments panel" perl -0777 -ne 'exit(/<section class="?card comments"?[^>]*>(?:(?!<\/section>).)*<script\b[^>]*giscus\.app\/client\.js/s ? 0 : 1)' "$f"
    check "$label $p: the panel opens with the \"Comments\" kicker" perl -0777 -ne 'exit(/<section class="?card comments"?[^>]*>\s*<h2 class="?comments__kicker"?[^>]*>Comments<\/h2>/s ? 0 : 1)' "$f"
    check "$label $p: the panel comes after the article" in_order "$f" '</article>' 'class="?card comments'
    if grep -Eq '<nav class="?post-nav' "$f"; then
      check "$label $p: the panel comes after the post nav" in_order "$f" '<nav class="?post-nav' 'class="?card comments'
    fi
    check "$label $p: the panel is inside <main>" in_order "$f" 'class="?card comments' '</main>'
    while IFS='|' read -r name want; do
      check "$label $p: $name=\"$want\"" test "$(attr "$tag" "$name")" = "$want"
    done <<EOF3
src|$GISCUS_SRC
data-repo|Verryx-02/Verryx-02.github.io
data-repo-id|$4
data-category|Comments
data-category-id|$5
data-mapping|pathname
data-strict|1
data-reactions-enabled|1
data-emit-metadata|0
data-input-position|top
data-lang|en
data-loading|lazy
EOF3
    check "$label $p: crossorigin is anonymous" sh -c 'v="$(printf %s "$1" | N=crossorigin perl -0777 -ne "exit 1 unless /\\scrossorigin(?:=[\"\\x27]?([^\"\\x27\\s>]*))?/; print \$1 // q()")" && { test "$v" = anonymous || test -z "$v"; }' _ "$tag"
    check "$label $p: the script is async" attr "$tag" async
    check "$label $p: data-theme is an absolute https URL ending /css/giscus-rack.css" sh -c 'printf %s "$1" | grep -Eq "^https://[^/]+/(.*/)?css/giscus-rack\.css$"' _ "$(attr "$tag" data-theme)"
  done
  check "$label: the giscus theme is published (css/giscus-rack.css)" test -s "$dir/css/giscus-rack.css"
  check_none "$label: no page loads a script other than giscus on post pages" "$(script_audit "$dir" on)"
  check_none "$label: hosts outside the allowed list (giscus.app on post pages only)" "$(host_audit "$dir" on)"
}

check "hugo.toml sets params.giscus (repo, category Comments, mapping pathname, reactions, input top, lang en)" sh -c 'hugo config --format json 2>/dev/null | perl -MJSON::PP -0777 -ne "
  my \$g = decode_json(\$_)->{params}{giscus} or exit 1;
  exit(\$g->{repo} eq q(Verryx-02/Verryx-02.github.io) && \$g->{category} eq q(Comments) && \$g->{mapping} eq q(pathname)
    && \$g->{reactionsenabled} && \$g->{inputposition} eq q(top) && \$g->{lang} eq q(en) ? 0 : 1)"'
echo "  ..    giscus in hugo.toml: $giscus_on"
if [ "$giscus_on" = on ]; then
  ids="$(hugo config --format json 2>/dev/null | perl -MJSON::PP -0777 -ne 'my $g = decode_json($_)->{params}{giscus}; print "$g->{repoid} $g->{categoryid}"')"
  giscus_audit public on "public/" ${ids% *} ${ids#* }
else
  giscus_audit public off "public/ (ids empty)"
fi
# Scratch builds with the ids forced: both set, both empty, one missing.
giscus_build() { # giscus_build REPO_ID CATEGORY_ID: build into a new temp dir and print its path.
  local d; d="$(mktemp -d "${TMPDIR:-/tmp}/hugo-check-giscus.XXXXXX")"
  if HUGO_PARAMS_GISCUS_REPOID="$1" HUGO_PARAMS_GISCUS_CATEGORYID="$2" hugo --minify --destination "$d" >"$log" 2>&1 &&
    ! grep -Eq '^(WARN|ERROR)' "$log"; then :; else sed 's/^/        /' "$log" >&2; fi
  printf '%s' "$d"
}
alt="$(giscus_build R_checkRepo DIC_checkCategory)"
check "build with dummy giscus ids has a home page" test -f "$alt/index.html"
giscus_audit "$alt" on "giscus ids set" R_checkRepo DIC_checkCategory
rm -rf "$alt"
alt="$(giscus_build "" "")"
giscus_audit "$alt" off "giscus ids empty"
rm -rf "$alt"
alt="$(giscus_build R_checkRepo "")"
giscus_audit "$alt" off "giscus categoryId empty"
rm -rf "$alt"

# The custom giscus theme: dark, the site's tokens, ice-blue accent.
gtheme="static/css/giscus-rack.css"
check "$gtheme exists" test -s "$gtheme"
for v in --color-canvas-default --color-canvas-subtle --color-fg-default --color-fg-muted --color-border-default --color-accent-fg --color-btn-primary-bg --color-btn-bg; do
  check "$gtheme sets $v" grep -Eq -- "$v:" "$gtheme"
done
check "$gtheme accent is ice blue (--color-accent-fg: #9fc4ff)" grep -Eq -- '--color-accent-fg:[[:space:]]*#9fc4ff;' "$gtheme"
check "$gtheme is dark only (color-scheme: dark, no prefers-color-scheme)" sh -c 'grep -Eq "color-scheme:[[:space:]]*dark" "$1" && ! grep -q "prefers-color-scheme" "$1"' _ "$gtheme"

# --- 4e. Page-bundle files -------------------------------------------------------
# Posts publish only the bundle files a template uses (hugo.toml cascade,
# build.publishResources = false): the resized WebP copies, never the original photos.
check "the original photo cpu-sticker.jpg is not published" test -z "$(find public -name cpu-sticker.jpg)"
bundle_published=""
bundle_linked=""
while read -r src path; do
  [ -n "$src" ] || continue
  dir="$(dirname "$src")"
  for file in "$dir"/*; do
    name="$(basename "$file")"
    [ "$name" = index.md ] && continue
    [ -e "public${path}${name}" ] && bundle_published="$bundle_published public${path}${name}"
    # A plain Markdown link/image to a bundle file would now point to an unpublished file.
    N="$name" perl -0777 -ne 'exit(/\]\(\s*(?:\.\/)?\Q$ENV{N}\E[\s)#?]/ ? 0 : 1)' "$src" && bundle_linked="$bundle_linked $src:$name"
  done
done <<EOF
$posts
EOF
check_none "no post publishes its original bundle files" "$bundle_published"
check_none "no post links a bundle file by plain Markdown (use the figure shortcode)" "$bundle_linked"

# --- 5. No About page links --------------------------------------------------
about_links="$(find public -type f -name '*.html' -print0 |
  H="$(href_re /about/)" xargs -0 perl -ne 'print "$ARGV\n" if /$ENV{H}/' | sort -u || true)"
if [ -z "$about_links" ]; then
  pass "no generated HTML links to /about/"
else
  fail "no generated HTML links to /about/"; printf '%s\n' "$about_links" | sed 's/^/        /'
fi

# --- 6. No fixed widths prone to horizontal overflow -------------------------
# Flags `width: NNNpx` (>= 400px, not min-/max-width) in CSS and inline styles.
wide="$(find public -type f \( -name '*.css' -o -name '*.html' \) -print0 |
  xargs -0 perl -ne 'while (/(?<![-\w])width\s*:\s*(\d+)px/g) { print "$ARGV: width:$1px\n" if $1 >= 400 }' || true)"
if [ -z "$wide" ]; then
  pass "no fixed width >= 400px in CSS or inline styles"
else
  fail "no fixed width >= 400px in CSS or inline styles"; printf '%s\n' "$wide" | sed 's/^/        /'
fi

# --- 7. External hosts --------------------------------------------------------
check_none "HTML references only allowed hosts ($(printf '%s' "$allowed" | tr '\n' ' ')$([ "$giscus_on" = on ] && printf '+ giscus.app on posts'))" "$(host_audit public "$giscus_on")"

# --- 8. Performance -------------------------------------------------------------
# Every generated page (redirects aside), production build.
html_pages="$(find public -type f -name '*.html' -print0 | xargs -0 perl -0777 -ne 'print "$ARGV\n" unless /<meta http-equiv="?refresh/' | sort)"
# pages_without REGEX: print the pages whose HTML does not match the Perl regex (with /s).
pages_without() { printf '%s\n' "$html_pages" | R="$1" xargs perl -0777 -ne 'print "$ARGV\n" unless /$ENV{R}/s' || true; }
# pages_with REGEX: print the pages whose HTML matches the Perl regex (with /s).
pages_with() { printf '%s\n' "$html_pages" | R="$1" xargs perl -0777 -ne 'print "$ARGV\n" if /$ENV{R}/s' || true; }
# a. Self-hosted fonts.
google="$( { find public -type f \( -name '*.html' -o -name '*.css' -o -name '*.xml' \) -print0 | xargs -0 grep -lE 'fonts\.(googleapis|gstatic)\.com'; grep -lE 'fonts\.(googleapis|gstatic)\.com' assets/css/*.css layouts/*.html layouts/_partials/*.html; } 2>/dev/null | sort -u || true)"
check_none "no generated HTML/CSS (or template) references fonts.googleapis.com or fonts.gstatic.com" "$google"
# Font files: every file main.css references exists (source and published), the replaced
# families and their files are gone.
css_fonts="$(perl -ne 'print "$1\n" while /url\(["\x27]?\{\{\s*"fonts\/([^"]+)"/g' "$css_src" | sort -u)"
check "main.css references self-hosted font files" test -n "$css_fonts"
for f in $css_fonts; do
  check "font $f (referenced by main.css) is in static/fonts/ and public/fonts/" sh -c 'test -s "static/fonts/$1" && test -s "public/fonts/$1"' _ "$f"
done
for f in d-din-400 d-din-700 d-din-condensed-400 d-din-condensed-700 iosevka-etoile-400 iosevka-etoile-400-italic iosevka-etoile-700 iosevka-400; do
  check "main.css loads $f.woff2" sh -c 'printf "%s\n" "$1" | grep -qxF "$2"' _ "$css_fonts" "$f.woff2"
done
for f in OFL-d-din OFL-iosevka; do
  check "font licence $f.txt is published" test -s "public/fonts/$f.txt"
done
for f in hubot-sans-var.woff2 newsreader-var.woff2 newsreader-italic-var.woff2 fragment-mono-400.woff2 OFL-hubotsans.txt OFL-newsreader.txt OFL-fragmentmono.txt; do
  check "old font file $f is gone (static/ and public/)" sh -c 'test ! -e "static/fonts/$1" && test ! -e "public/fonts/$1"' _ "$f"
done
old_names="$( { find public -type f \( -name '*.html' -o -name '*.css' \) -print0 | xargs -0 grep -lE 'Hubot|Newsreader|Fragment Mono'; grep -lE 'Hubot|Newsreader|Fragment Mono' assets/css/*.css layouts/*.html layouts/_partials/*.html; } 2>/dev/null | sort -u || true)"
check_none "no generated HTML/CSS (or template) names Hubot, Newsreader or Fragment Mono" "$old_names"
# font_face FAMILY STYLE WEIGHT: print the @font-face block for FAMILY with font-style STYLE and
# font-weight WEIGHT, from the CSS inlined in the production home page, normalised (no spaces
# around : ; , and a final ;).
font_face() {
  F="$1" T="$2" W="$3" perl -0777 -ne '
    my ($css) = /<style>(.*?)<\/style>/s or exit;
    while ($css =~ /\@font-face\s*\{([^}]*)\}/g) { my $b = $1;
      $b =~ s/\s+/ /g; $b =~ s/\s*([:;,])\s*/$1/g; $b =~ s/^\s+|\s+$//g; $b =~ s/;?$/;/;
      next unless $b =~ /(?:^|;)font-family:["\x27]?\Q$ENV{F}\E["\x27]?;/i;
      my $st = $b =~ /font-style:(\w+)/ ? $1 : "normal"; next unless $st eq $ENV{T};
      my $wt = $b =~ /font-weight:([^;]+);/ ? $1 : ""; next unless $wt eq $ENV{W}; print $b; last }' public/index.html
}
# same_unicode_range BLOCK EXPECTED: BLOCK's unicode-range equals EXPECTED, compared as code
# point ranges (the minifier writes U+0000-00FF as U+?? and drops leading zeros).
same_unicode_range() {
  printf '%s' "$1" | E="$2" perl -0777 -ne '
    sub norm { join ",", map { my $r = uc; $r =~ s/\s+//g; $r =~ s/^U\+//;
      my ($a, $b) = $r =~ /\?/ ? (($r =~ tr/?/0/r), ($r =~ tr/?/F/r)) : split /-/, $r; $b //= $a;
      sprintf "%X-%X", hex $a, hex $b } split /,/, $_[0] }
    my ($got) = /unicode-range:([^;]*);/ or exit 1;
    exit(norm($got) eq norm($ENV{E}) ? 0 : 1)'
}
# The Iosevka files are subset to this range (docs/Maintaining.md, pyftsubset); D-DIN is full Latin.
unicode_range='U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2190-2193,U+2212,U+2215,U+25AA,U+25B8,U+25C2,U+25CF,U+FEFF,U+FFFD'
while IFS='|' read -r family style weight file subset; do
  face="$(font_face "$family" "$style" "$weight")"
  label="@font-face $family $style $weight"
  check "$label exists in the inlined CSS" test -n "$face"
  check "$label loads /fonts/$file" sh -c 'printf %s "$1" | grep -Eq "src:url\([\"\x27]?/fonts/$2[\"\x27]?\) ?format\([\"\x27]?woff2[\"\x27]?\);"' _ "$face" "$file"
  check "$label has font-display: swap" sh -c 'printf %s "$1" | grep -q "font-display:swap;"' _ "$face"
  check "$label has no font-stretch" sh -c 'test -n "$1" && ! printf %s "$1" | grep -q "font-stretch"' _ "$face"
  if [ "$subset" = subset ]; then
    check "$label has the Latin + symbols unicode-range" same_unicode_range "$face" "$unicode_range"
  else
    check "$label has no unicode-range (full Latin file)" sh -c 'test -n "$1" && ! printf %s "$1" | grep -q "unicode-range"' _ "$face"
  fi
done <<EOF2
D-DIN|normal|400|d-din-400.woff2|
D-DIN|normal|700|d-din-700.woff2|
D-DIN Condensed|normal|400|d-din-condensed-400.woff2|
D-DIN Condensed|normal|700|d-din-condensed-700.woff2|
Iosevka Etoile|normal|400|iosevka-etoile-400.woff2|subset
Iosevka Etoile|italic|400|iosevka-etoile-400-italic.woff2|subset
Iosevka Etoile|normal|700|iosevka-etoile-700.woff2|subset
Iosevka|normal|400|iosevka-400.woff2|subset
EOF2
faces="$(perl -0777 -ne 'my ($css) = /<style>(.*?)<\/style>/s; my $n = () = $css =~ /\@font-face/g; print $n' public/index.html)"
check "inlined CSS has exactly eight @font-face rules (found $faces)" test "$faces" = 8
# Type tokens: the first family of each stack.
token_first() { T="$1" perl -0777 -ne 'print $1 if /--\Q$ENV{T}\E:\s*"([^"]+)"/' "$css_src"; }
check "--display starts with \"D-DIN\"" test "$(token_first display)" = "D-DIN"
check "--label starts with \"D-DIN Condensed\"" test "$(token_first label)" = "D-DIN Condensed"
check "--serif starts with \"Iosevka Etoile\"" test "$(token_first serif)" = "Iosevka Etoile"
check "--mono starts with \"Iosevka\"" test "$(token_first mono)" = "Iosevka"
check "CSS has no font-stretch (D-DIN has no width axis)" sh -c '! grep -q "font-stretch" assets/css/main.css assets/css/syntax.css'
bad_weights="$(perl -ne 'while (/font-weight:\s*([^;}]+)/g) { my $w = $1; $w =~ s/\s+$//; print "$ARGV: font-weight $w\n" unless $w =~ /^(?:400|700)$/ }' assets/css/main.css assets/css/syntax.css || true)"
check_none "CSS uses font weights 400 and 700 only" "$bad_weights"
preload_re() { printf '<link\\b(?=[^>]*rel="?preload)(?=[^>]*as="?font)(?=[^>]*type="?font/woff2)(?=[^>]*\\scrossorigin)(?=[^>]*href="?[^">]*/fonts/%s"?[\\s>])[^>]*>' "$1"; }
check_none "every page preloads d-din-700.woff2 (as=font, type=font/woff2, crossorigin)" "$(pages_without "$(preload_re d-din-700.woff2)")"
check_none "every page preloads iosevka-etoile-400.woff2 (as=font, type=font/woff2, crossorigin)" "$(pages_without "$(preload_re iosevka-etoile-400.woff2)")"
preloads="$(perl -0777 -ne 'my $n = () = /<link\b[^>]*rel="?preload/g; print $n' public/index.html)"
check "home page preloads exactly two resources (found $preloads)" test "$preloads" = 2
check_none "no page has a preconnect" "$(pages_with '<link\b[^>]*rel="?preconnect')"

# Accent: ice blue. No amber, yellow or orange left in any CSS.
amber="$(grep -EHni '#(ffb547|ffd6a5|f4d38a|9a5400)\b|--amber' assets/css/*.css static/css/*.css 2>/dev/null || true)"
check_none "CSS has no amber hex values (#ffb547, #ffd6a5, #f4d38a, #9a5400) and no --amber token" "$amber"
accents="$(perl -ne 'print "$1\n" while /--accent:\s*([^;]+);/g' "$css_src" | sort -u)"
check "every --accent declaration in main.css is #9fc4ff (found: $(printf '%s' "$accents" | tr '\n' ' '))" test "$accents" = "#9fc4ff"
check "main.css defines --ice: #9fc4ff" grep -Eq -- '--ice:[[:space:]]*#9fc4ff;' "$css_src"
check "main.css sets --accent-soft to rgba(159, 196, 255, 0.14)" grep -Eq -- '--accent-soft:[[:space:]]*rgba\(159, *196, *255, *0?\.14\);' "$css_src"
# warm_colours FILE...: print every colour whose hue is yellow/amber/orange (15-70 degrees)
# with a chroma of at least 0.25 (pale warm greys such as #e6dccb stay allowed).
warm="$(perl -ne '
  my @c;
  while (/#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b/g) { my $h = $1; $h =~ s/(.)/$1$1/g if length $h == 3; push @c, ["#$1", map { hex } $h =~ /(..)/g] }
  while (/rgba?\(\s*(\d+)[\s,]+(\d+)[\s,]+(\d+)/g) { push @c, ["rgb($1,$2,$3)", $1, $2, $3] }
  while (/hsla?\(\s*([\d.]+)(?:deg)?[\s,]+([\d.]+)%/g) { print "$ARGV: hsl($1, $2%)\n" if $1 >= 15 && $1 <= 70 && $2 >= 25 }
  for (@c) { my ($s, $r, $g, $b) = @$_; my ($mx) = sort { $b <=> $a } ($r, $g, $b); my ($mn) = sort { $a <=> $b } ($r, $g, $b);
    my $d = $mx - $mn; next if $d / 255 < 0.25;
    my $hue = $mx == $r ? 60 * (($g - $b) / $d) : $mx == $g ? 60 * (($b - $r) / $d + 2) : 60 * (($r - $g) / $d + 4);
    $hue += 360 if $hue < 0;
    print "$ARGV: $s (hue ", int($hue), ")\n" if $hue >= 15 && $hue <= 70 }' assets/css/main.css assets/css/syntax.css static/css/*.css 2>/dev/null || true)"
check_none "CSS (site and giscus theme) has no yellow, amber or orange colours" "$warm"
check "selection is ice blue with dark text" sh -c 'printf %s "$1" | grep -Eq "background:[[:space:]]*(var\(--accent\)|var\(--ice\)|#9fc4ff)" && printf %s "$1" | grep -Eq "color:[[:space:]]*#05080e"' _ "$(css_rule ::selection)"
check "status LEDs stay green (--led: #3ee08a)" grep -Eq -- '--led:[[:space:]]*#3ee08a;' "$css_src"

# b. CSS inlined in production: one <style> in head, no stylesheet request.
check_none "every page inlines its CSS in a <style> inside <head>" "$(pages_without '<head>(?:(?!</head>).)*<style>(?:(?!</style>).)*\.site-header')"
check_none "no page links a stylesheet" "$(pages_with '<link\b[^>]*rel="?stylesheet')"
check "no site CSS file is published (public/css/ holds only the giscus theme)" sh -c 'test -z "$(find public/css -type f ! -name giscus-rack.css 2>/dev/null)"'
check "inline CSS carries the self-hosted @font-face rules" grep -q '@font-face' public/index.html

# d. Instant navigation: speculation rules (declarative) and cross-document view transitions.
spec="$(block public/index.html '<script type="?speculationrules"?>.*?<\/script>')"
check_none "every page has a speculationrules script" "$(pages_without '<script type="?speculationrules"?>')"
check "speculation rules prerender same-origin links with moderate eagerness" sh -c 'printf %s "$1" | grep -q "\"prerender\"" && printf %s "$1" | grep -q "\"eagerness\":[[:space:]]*\"moderate\"" && printf %s "$1" | grep -q "\"href_matches\":[[:space:]]*\"/\*\""' _ "$spec"
check "speculation rules are valid JSON" sh -c 'printf %s "$1" | perl -0777 -pe "s/^<script[^>]*>//; s/<\/script>\$//" | python3 -I -c "import json,sys; json.load(sys.stdin)"' _ "$spec"
check_none "no page loads an external script (no <script src>; the giscus client on posts only when configured)" "$(script_audit public "$giscus_on")"
check "no JavaScript files are published (public/js/ absent)" test ! -e public/js
check "main.css enables cross-document view transitions" perl -0777 -ne 'exit(/\@view-transition\s*\{\s*navigation:\s*auto\s*;?\s*\}/ ? 0 : 1)' "$css_src"
check "main.css gives the header its own view-transition-name" sh -c 'printf %s "$1" | grep -Eq "view-transition-name:[[:space:]]*[a-z-]+"' _ "$(css_rule .site-header)"
check "main.css keeps the page fade at 200ms or less" perl -0777 -ne '
  my @d = /::view-transition-(?:old|new)\(root\)[^{]*\{[^}]*animation-duration:\s*(\d+)ms/g;
  my $ok = @d && !(grep { $_ > 200 } @d); exit($ok ? 0 : 1)' "$css_src"
check "main.css turns view transitions off under prefers-reduced-motion" perl -0777 -ne '
  exit(/\@media\s*\(prefers-reduced-motion:\s*reduce\)\s*\{\s*\@view-transition\s*\{\s*navigation:\s*none/ ? 0 : 1)' "$css_src"

# e. Compositor-only animation: transitions and keyframes touch only opacity/transform.
bad_anim="$(perl -0777 -ne '
  while (/(?<![-\w])transition(?:-property)?:\s*([^;}]+)/g) { my $v = $1; next if $v =~ /^\s*none\b/;
    $v =~ s/\([^()]*\)//g;   # drop cubic-bezier(...) and similar before splitting on commas
    for my $part (split /,/, $v) { my ($p) = $part =~ /^\s*([-\w]+)/; print "transition $p\n" unless $p =~ /^(?:opacity|transform)$/ } }
  while (/\@keyframes\s+([-\w]+)\s*\{((?:[^{}]*\{[^}]*\})*)\s*\}/g) { my ($k, $b) = ($1, $2);
    while ($b =~ /([-\w]+)\s*:/g) { print "keyframes $k: $1\n" unless $1 =~ /^(?:opacity|transform)$/ } }' "$css_src" assets/css/syntax.css | sort -u || true)"
check_none "CSS animates only opacity and transform" "$bad_anim"

# f. Production HTML is minified (CI and this script build with --minify).
check "workflow builds with --minify" grep -Eq '^[[:space:]]*hugo\b.*--minify' "$WORKFLOW"

# --- 9. CI runs these checks ------------------------------------------------------
# The build job runs this script after installing Hugo and before the Pages artifact is
# uploaded; a failing check fails the job and the deploy job (needs: build) never runs.
CHECK_STEP='(?m)^\s*run:\s*\./scripts/check\.sh\s*$'
check "workflow has a step running ./scripts/check.sh" env R="$CHECK_STEP" perl -0777 -ne 'exit(/$ENV{R}/ ? 0 : 1)' "$WORKFLOW"
check "workflow runs ./scripts/check.sh after installing Hugo" in_order "$WORKFLOW" 'dpkg -i' "$CHECK_STEP"
check "workflow runs ./scripts/check.sh after the checkout" in_order "$WORKFLOW" 'uses:\s*actions/checkout@' "$CHECK_STEP"
check "workflow runs ./scripts/check.sh before upload-pages-artifact" in_order "$WORKFLOW" "$CHECK_STEP" 'uses:\s*actions/upload-pages-artifact@'
check "workflow runs ./scripts/check.sh in the build job (before the deploy job)" in_order "$WORKFLOW" "$CHECK_STEP" '(?m)^  deploy:'
check "workflow deploy job needs the build job" perl -0777 -ne 'exit(/(?m)^  deploy:\s*\n\s+needs:\s*build\s*$/ ? 0 : 1)' "$WORKFLOW"
check "workflow installs xmllint (libxml2-utils) for the RSS check" in_order "$WORKFLOW" 'libxml2-utils' "$CHECK_STEP"
check "workflow still builds the artifact with --gc --minify and the Pages base URL" grep -Eq 'hugo --gc --minify --baseURL "\$\{\{ steps\.pages\.outputs\.base_url \}\}/"' "$WORKFLOW"

# --- Result -------------------------------------------------------------------
echo
if [ "$failures" -eq 0 ]; then
  echo "All checks passed."
else
  echo "$failures check(s) failed."
  exit 1
fi
