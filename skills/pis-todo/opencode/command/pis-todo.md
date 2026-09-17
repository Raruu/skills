---
description: Buat todo "versi manusia" di Profile Plus dari riwayat git commit, opsional langsung ditandai selesai
---
Load the `pis-todo` skill using the skill tool, then follow its workflow exactly.

Arguments: $ARGUMENTS

Parsing reminder: split by commas → [1] module name (required, may contain spaces), [2] git range (optional: `A -> B`, `A`, or `A..B`), [3] date `yyyy-MM-dd` (optional, default today), [4] mark-complete keyword (optional: done/complete/selesai/mark-complete, may appear in any position). Be forgiving when commas are missing — detect the date, range, and mark-complete keyword patterns, strip the keyword before assigning positions, and treat the rest as the module name.
