---
title: "{{ replace .File.ContentBaseName "-" " " | strings.FirstUpper }}"
date: {{ .Date }}
draft: true
# A post sits in its rack: content/<room>/<rack>/<post folder>/index.md. Its position in the
# rack (1, 2, 3, ...) is the panel number "U01", "U02", ... Required. If the rack's _index.md
# lists this unit under `planned`, delete that entry when publishing the post.
unit:
tags: []
# The rack page, the meta description and the RSS item show the post's opening text; uncomment to override.
# summary: ""
---
