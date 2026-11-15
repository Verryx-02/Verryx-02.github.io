# Fixed 3U racks, a floor for every room, and cables routed into each room

* Status: Accepted (2026-11-15)
* Supersedes: decision D1 and the cable layout of decision H in
  [ADR-0003](0003-themed-rooms-switch.md); the rest of ADR-0003 stands.

## Context

With ADR-0003 in place, three problems showed on the home page:

1. A rack name long enough to wrap onto two lines pushed that rack's units below the units
   of the racks next to it, and a long unit title made its slot taller.
2. Two racks had the same name as their only post ("My relationship with operating
   systems", "If it works and you don't know why, find out").
3. Each switch cable ended at its label. A real cable ends in a port, so a cable that ends
   in mid-air looks wrong.

## Decision

* **Fixed sizes.** Every compact rack (home floors and room pages) has the same width and
  shows at least 3U. Every slot has the same height, blanking panels included. The label
  plate has a fixed height, and long titles are clamped instead of growing their slot. A
  rack with more than three units grows by whole units and shows all of them; no rack bay
  scrolls, because a scrolling bay captured the mouse wheel and blocked the page scroll.
  Racks in a row are top-aligned, and the rows are centred between the trays. On the
  rack page every unit card also has the same fixed height, and all units are shown.
* **A floor for every room.** Every room gets a floor below the switch, in weight order.
  A closed room shows its name with no link, and one empty rack with no name and three
  blanking panels with unlit LEDs, because the room is powered off.
* **Routed cables.** Each cable leaves its switch port with its tag and drops into one of
  two vertical cable trays along the server view: the rooms on the first half of the switch
  ports go to the left tray, the others to the right. It runs down the tray past the floors above its room,
  then leaves the tray and runs across to the patch-panel port in its room's floor heading,
  entering the jack from the side of its tray. The patch panel and the room name are centred
  in the floor, above the centred rack rows. A cable leaving the left tray crosses over the cables still in
  it: the port order is reversed there, so a flat drawing cannot avoid it.
  The patch port's LED matches the switch port's LED: lit green for an open room, unlit
  for a closed one. Open cables are ice blue and closed cables dark grey. The switch has
  8 ports: the room count rounded up to a multiple of 8. A spare port has a dust cap, an
  unlit LED, and no cable or tag. On wide screens all ports have one width across the
  faceplate, and the cable labels are horizontal, wrapping only at spaces, never
  mid-word. The switch faceplate and the home console carry no visible title ("Core
  switch", "Start here"); screen readers still get "Server rooms" and "Start here". The
  layout is
  HTML and CSS only, works for any number of rooms, and still works at 375px.
* **Rack names describe the topic, not the first post.** The two racks are renamed
  "Operating systems" and "Curiosity".

## Consequences

* Good, because racks in a row line up exactly, and the page reads as one wired room.
* Good, because every cable ends in a port, so you can follow it to its room.
* Bad, because the home page is longer: five closed floors show an empty rack each.
* Bad, because a rack with more than three posts is taller than its neighbours, so a row
  of racks no longer has one height.
* Bad, because long titles are clamped on compact racks. Screen readers and the link
  text still get the full title.
