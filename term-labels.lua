-- Terminal labels (nejcc.term-labels) keys. Load from ~/.config/hypr/bindings.lua:
--   pcall(dofile, os.getenv("HOME") .. "/.config/omarchy/plugins/nejcc.term-labels/term-labels.lua")

local DIR = debug.getinfo(1, "S").source:match("^@(.*)/") or "."

o.bind("SUPER + ALT + N", "Rename window label", DIR .. "/bin/tlabel --rename")
