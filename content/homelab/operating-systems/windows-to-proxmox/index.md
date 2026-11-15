---
title: "My relationship with operating systems"
date: 2026-11-14
draft: false
unit: 1
tags: ["linux", "macos", "proxmox"]
---

When I built my first PC, I had no doubts about which operating system to install: I didn't know any other than Windows 10.
It always worked well enough for me. I was used to a computer that ran pretty badly, but to me that was normal: I didn't know there were affordable alternatives, or that things could be any better.

Towards the end of 2020, before starting university, I realized I needed a laptop. I had worked for several months as a seasonal bartender at a 4-star restaurant and had saved up some money, so my first idea was to buy a fully loaded gaming laptop.
After some research, though, I realized that all that power would be wasted at university, and that what I knew about desktops didn't fully apply to laptops. A top-tier processor that runs as hot as a furnace, shut inside a laptop, can easily perform worse than a lower-tier one in a well-cooled desktop. What I needed was something light, with decent performance and a battery that would last all day.

That's when I came across the MacBook Air M1. Until then I had stayed well away from Apple laptops: the Intel-based Airs ran hot, performed poorly and cost far more than any Windows laptop with the same performance. But on YouTube my favourite reviewers had gone crazy over the new M1 SoC, especially its efficiency. A company that until recently hadn't designed chips for computers had made Intel and AMD look ridiculous on performance per watt.
I bought one, and it's one of the best purchases I've ever made: it still holds up against much newer laptops today.

The operating system, on the other hand, didn't win me over. I had never used macOS before, and I still find it far from perfect.

Things changed when I started using the terminal at university, while taking my Operating Systems course. I discovered a new way of using a computer, discovered the distributions based on the Linux kernel, and decided to try a few.
So I installed Linux on my MacBook thanks to the Asahi Linux project. Back then it was still very immature: lots of features weren't supported, and the speakers were disabled because, without macOS's software protections, you could literally burn them out. (This was before the Asahi team wrote audio drivers that sound better than macOS's own.)
I had fun using it for a few days, then dropped it. I came back to it later to see how much it had changed, but in the end I went back to macOS again. I still hate the way it handles multiple desktops, but the rest is acceptable. After all, it's a Unix system, so there's some good in it, and in several ways I consider it far better than Windows. I think that if Apple made the whole system open source, it would probably become the best consumer operating system out there.

My real introduction to Linux came from the project I worked on for my IoT course, which later became the thesis for my bachelor's degree in computer science: [RAM-USB](https://github.com/Verryx-02/RAM-USB), a distributed, zero-trust backup service.

Long story short, I needed a system to run several virtual machines on and, thanks to [Morrolinux](https://www.youtube.com/@morrolinux)'s videos, I discovered the Proxmox VE hypervisor.
I installed Proxmox on my desktop, created the virtual machines and set up GPU passthrough, which is no small feat with a GTX 1050 Ti and a Ryzen 2700, a CPU with no integrated graphics.

Most of the time I had no idea what I was doing: I hadn't taken my computer networks course yet and knew nothing about IP addresses, DNS, ARP and the like. But I wanted to get it done quickly, because I needed to test RAM-USB.

In the end, once everything was set up, it worked on the local network. From the outside, though, I couldn't reach anything. I had set up port forwarding correctly, but something didn't add up.

Soon after, I ran into my great nemesis: CGNAT.
