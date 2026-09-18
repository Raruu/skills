---
description: Buat log book magang (DOCX + PDF) dari todo & absensi Profile Plus, atau SETUP untuk menyiapkan workdir
---
Load the `pis-todo-to-tch` skill using the skill tool, then follow its workflow exactly.

Arguments: $ARGUMENTS

Mode detection: if the arguments are exactly `SETUP` (case-insensitive, possibly with surrounding whitespace), switch to **Setup mode** in the skill — run `build-logbook.py --setup`, walk the user through config/git/libs/MCP, and do **not** generate any document.

Parsing reminder (generate mode): segment 1 = periode (kosong = bulan berjalan; `September`, `September 2026`, `September/minggu 2`, `September/minggu 2->3`, atau `Tanggal 2026-09-01 -> 2026-09-15`), segment 2 = format (`word`/`pdf`, kosong = keduanya). Split by commas, be forgiving when commas are missing — detect the period pattern first, then treat a trailing `word`/`pdf` as the format. Never compute the period yourself; always resolve it with the bundled script's `--resolve-only`.
