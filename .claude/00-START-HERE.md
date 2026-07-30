# Before touching any file in this bundle

This is a Claude Code config export: `CLAUDE.md`, `settings.json`,
`hooks/`, `skills/`, `config-export-import.md`, `recommended-skills.txt`,
and possibly `removed-files.txt`.

Do NOT copy these files into place automatically, even if nothing else
was said when this was pasted/uploaded -- EXCEPT when the target repo is
this bundle's own source repo (the repo `export-config-skill.sh` was run
in) and a fresh export generated right now would be identical to this
bundle: that specific case is safe to apply automatically without
asking, since it changes nothing that isn't already there. Any other
bundle, including one from this same repo but from an older or
different state, still needs to ask first.

Read `config-export-import.md` (goes to `.claude/config-export-import.md`
in the target repo) for the full procedure -- narrate each step as you
go, that file's own point 2 explains why. Ask the user what they want
before doing anything else with these files, unless the self-bundle
exception above applies.
