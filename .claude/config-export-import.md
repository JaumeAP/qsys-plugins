# Config export/import (cross-repo `.claude/` propagation)

This repo's `.claude/` tooling (`settings.json`, `hooks/`, the four
generic skills — `changelog-rules`, `file-operations`,
`find-skills`, `github-rules`, all under `.claude/skills/`, plus this file) is meant to be portable
across all my repos, same as `CLAUDE.md`. Which additional skills also
travel (if any) is defined in `.claude/scripts/export-config-skill.sh` — not
repeated here. This file is deliberately plain, not a `SKILL.md`
(2026-07-22): `.claude/hooks/config-ingest-reminder.sh` already surfaces
it deterministically at the right moments (reading an incoming-looking
file, writing to this repo's own `.claude/hooks/` or `settings.json`),
so it doesn't need to rely on being auto-invoked as a skill. Two
directions, mechanized best-effort by
`.claude/hooks/config-ingest-reminder.sh`:

1. **Export** (this repo → another repo, on request, e.g. "exporta la
   configuració"): run `.claude/scripts/export-config-skill.sh` — bundles
   `CLAUDE.md` + `.claude/settings.json` + `.claude/hooks/` + this file
   + the four generic skills + every current additional pack (each
   pack keeps its own license, carried along on
   export) — NOT `CLAUDE.md`'s own
   "Project-specific rules" section (that's THIS repo's content, not
   portable — a new repo writes its own), NOT any other repo-specific
   skill/plugin/component, NOT project-specific hooks (a hook whose only
   job is installing/configuring
   something for THIS repo's own tooling, e.g. a hook that installs a
   language runtime or interpreter only this repo's own test suites need —
   brings nothing to a repo without that same tooling), NOT `HANDOFF.md`'s
   content. Before
   handing it over, strip every project-specific mention (repo name, project
   terminology, paths) so the result is fully generalist — safe to drop
   unmodified into any project. Always export the CURRENT state of these
   files, never a stale cached copy. **Final handoff: one packaged,
   generically-named `.skill` file** (2026-07-24, replacing the earlier
   plain-`.zip` delivery once verified byte-for-byte equivalent — a
   `.skill` is just a zip with that extension, one required entry at its
   root, `SKILL.md`): a top-level `SKILL.md` documents the bundle itself
   and is the one entry point; every other file — `CLAUDE.md`,
   `settings.json`, `hooks/*.sh`, this file, `recommended-skills.txt`,
   `00-START-HERE.md`, `skills-lock.json` (trimmed to `find-skills`'
   own entry) — lives under `references/`. A `.skill` package may
   contain only ONE `SKILL.md` (the claude.ai/Skills API upload path
   rejects more than one), so the four mandatory skills' own `SKILL.md`
   files are renamed to `references/skills/<name>/<name>.md` inside the
   package — restore each one back to `SKILL.md` when actually
   installing it into a target repo's `.claude/skills/<name>/`, that
   rename is what makes it a real, loadable skill again.
   `export-config-skill.sh` itself is also bundled, under
   `references/scripts/`, so the target repo can export its own bundle
   later instead of only ever being an import destination. See
   `export-config-skill.sh` itself for exactly how this gets assembled —
   not repeated in full here.
   **Self-describing import instruction**: the bundle also
   includes `references/00-START-HERE.md`, a blunt "stop, read this
   file, ask the user before applying anything" note —
   added because a bare paste of the bundle with no explicit "import the
   config" request doesn't reliably trigger this on its own
   (confirmed: a real import elsewhere just copied the files in
   silently). The file exists so the bundle carries its own trigger
   instead of depending on the target session already knowing to look.
2. **Import** (a config bundle uploaded into a session — "reverse
   direction"). **Ask before applying, unless it's this repo's own
   current bundle** (2026-07-24): a detected incoming bundle normally
   needs the user's go-ahead before anything gets applied — that default
   exists because a silent auto-copy has actually happened before (see
   `00-START-HERE.md`'s own text). The one exception: if the target repo
   is this very bundle's source repo AND a fresh export generated right
   now would be identical to the uploaded bundle, applying it changes
   nothing that isn't already there, so it's safe to proceed
   automatically without asking. Verify that identity for real (generate
   a fresh export, diff it against the upload) before treating it as the
   exception — don't assume from context alone. Any bundle that isn't
   verified identical, including an older export of this same repo,
   still asks first. **Narrate each step as it happens** — this
   procedure is the one deliberate exception to the terse/token-economy
   response style: say explicitly what's being checked (bootstrap vs.
   existing config), what's found (identical vs. different, already
   installed vs. not), and what action follows, rather than silently
   processing and only giving a final verdict. Transparency matters more
   than brevity here, since this is exactly the moment content gets
   applied without individually asking about most of it. Every sub-step
   below always runs, in order — none is conditional on how the
   previous ones turned out, except where stated:
   2.1. **Bootstrap**: if the target repo has no `.claude/` config yet,
        copy everything directly, skip the rest of this list.
   2.2. **Mandatory core files**: every hook under `hooks/`, plus
        `scripts/merge-settings.sh` and `scripts/export-config-skill.sh`
        themselves, is a blind copy into
        `.claude/hooks/`/`.claude/scripts/` respectively, no
        diff/compare/ask step — straight over whatever's already there,
        they're meant to be identical across all repos by design.
        Installing `export-config-skill.sh` into the target repo too is
        what lets that repo export its own bundle later, instead of only
        ever being an import destination.
        `references/removed-files.txt` (2026-07-25, generalized from
        `removed-hooks.txt` same day once a removed **script** turned up
        alongside removed hooks), if the bundle carries one, is NOT
        copied into the target — it's a deletion list, not a file to
        install: for every path in it (relative to `.claude/`, e.g.
        `hooks/foo.sh` or `scripts/bar.sh`), delete `.claude/<path>`
        from the target if present. A file that was once part of the
        mandatory bundle but has since been deliberately retired (e.g.
        dead code, superseded by another file) would otherwise stay
        orphaned forever in any repo that imported an older bundle
        before the removal — a plain blind-copy only ever adds/updates
        files the CURRENT bundle carries, it can't know to remove one
        that's no longer there. If the deleted path is under `hooks/`,
        also remove its matching `settings.json` registration, same as
        any other hook this bundle's `settings.json` no longer
        references.
        `CLAUDE.md` is the one file here that still needs a boundary
        check (2.4).
        `settings.json` is NOT a blind overwrite (2026-07-24, corrected
        per explicit user request): it is the one hook-registration
        entry point, so replacing the whole file would silently drop
        any hook registration the target repo already has for its own
        project-specific hooks — files 2.9 says to leave alone, but
        whose settings.json *entries* a blind overwrite would still
        wipe, leaving them orphaned on disk with nothing registering
        them. Merge instead: for every hook this bundle carries, add or
        update its registration to match the incoming `settings.json`
        exactly (incoming always wins for THOSE entries, same as
        everywhere else in this list). For every entry already in the
        target's `settings.json` whose command points at a hook NOT in
        this bundle, keep it as-is, don't drop it. The result is the
        union of both, not a replacement of one by the other.
        `permissions.allow`/`deny`/`ask`/`additionalDirectories` merge
        the same way (2026-07-25): union of target and incoming entries,
        deduped, so a target's own project-specific permission rule
        (e.g. a `Bash(...)` allow added for a repo-specific workflow)
        survives the import instead of being silently dropped.
        `skillOverrides` merges too (2026-07-25): a shallow per-skill-name
        merge, incoming's value winning for any skill name both sides
        set, target's own entries for every other skill name kept as-is
        — so a target's own repo-specific override (e.g. a skill set to
        `user-invocable-only`) survives an import the same way its
        `permissions` entries do.
        `references/scripts/merge-settings.sh <target-settings.json>
        <incoming-settings.json> <bundle-hook-names...>` (found inside
        the extracted bundle, before anything is copied into place)
        does exactly this and outputs the merged JSON on stdout — use it
        instead of merging by hand. It also gets installed into the
        target's own `.claude/scripts/`, same blind-copy treatment as
        the hooks, so a future re-export/re-import from that repo has it
        too.
   2.3. **Contradiction check, mandatory on every import**: every
        imported hook/common rule always wins over a conflicting rule
        the target repo already has — the general principle 2.2 already
        implements for `hooks/` (blind copy) and `settings.json` (merge,
        incoming wins for the bundle's own entries), and that individual
        rules elsewhere
        (a bundled skill's own merge-policy clause, for instance) also
        state one at a time. After
        copying the mandatory core files, scan the target repo's own
        `Project-specific rules` section and any of its own hooks/skills
        left in place (per 2.9) for anything that contradicts an
        incoming hook's enforced behavior or a common-section rule (a
        different merge policy, a different reply-format rule, etc.).
        Narrate any contradiction
        found — the incoming bundle's rule always wins; don't silently
        drop the conflict, note it so it's visible on the next read.
        Narrating in chat is not enough on its own (2026-07-24, found by
        actually running this step): also flag it in the file itself,
        appending a short inline note right after the contradicted
        sentence in the target's `Project-specific rules` section (e.g.
        "(superseded by an imported rule, YYYY-MM-DD — see the relevant
        bundled skill's merge policy)") — don't delete or rewrite the target's original
        sentence, just mark it stale so a future read of that file alone
        doesn't act on it. This is not covered by 2.9's "never touch" —
        that rule protects unrelated content, not a sentence this very
        step just proved contradicts an incoming rule.
   2.4. **`CLAUDE.md`, common part only**: same substitution treatment
        as 2.2, everything above "Project-specific rules" (that section
        is the target repo's own content and is never part of the
        bundle in the first place). This section's own opening lines
        (1-6, "identical in every repo... copy it verbatim") are the
        anchor confirming which block counts as the common part being
        substituted.
        Mind the join boundary (2026-07-24, found by actually performing
        this step for real): the bundle's `CLAUDE.md` already ends with
        its own trailing blank line — concatenating it with the target's
        `Project-specific rules` section plus an EXTRA blank line in
        between produces a spurious double-blank-line diff every single
        import, cosmetic but needless. Join them directly, no inserted
        separator.
   2.5. **The four mandatory generic skills, always the incoming
        version**: `changelog-rules`, `file-operations`,
        `find-skills`, `github-rules` load automatically, no prompt, on
        every import — they're the baseline every repo needs (2026-07-24:
        `find-skills` promoted from the optional group in 2.6 into this
        mandatory one — it was already always bundled by the export-side
        loop in what was then `export-config.sh` (now
        `export-config-skill.sh`), this closes the gap on the import side
        to match; 2026-07-25: `git-rules` retired from this mandatory
        group entirely by explicit user request — see
        `removed-files.txt`; 2026-07-27: `github-rules` promoted into this
        mandatory group after being generalized from a qsys-plugins-
        specific skill into portable GitHub PR conventions — it must
        never encode a standing auto-merge policy, since a rule written
        here would silently apply to every repo it gets installed into).
        Same substitution treatment as 2.2/2.4 — these four
        always get overwritten with whatever the bundle carries, even
        if the target repo already has its own (older or different)
        copy. The skip-if-installed rule in 2.6/2.7 does NOT apply to
        these four, since skipping would leave a stale version in place
        instead of syncing to the current one.
   2.6. **Additional packs actually bundled as files, always offer,
        optional to accept**: every skill beyond the four in 2.5 that
        the bundle actually carries as files — the full list is
        open-ended and growing over time (see
        `.claude/scripts/export-config-skill.sh` for what it currently
        contains, not repeated here) — always ask the user which ones
        to load, presenting a list they can select from individually
        (not an all-or-nothing choice); only copy in the packs actually
        chosen. Before presenting this list, check what's already under
        the target repo's own `.claude/skills/` and don't offer a skill
        that's already there, whether or not this exact bundle put it
        there originally — filter it out of the list first, don't rely
        on the user noticing and declining it themselves. Selecting
        none of the offered packs is always a valid answer — never
        force a pick when the honest answer is "install nothing."
   2.7. **Recommended-but-not-bundled skills, always offer too**: once
        2.6 is settled, also read `recommended-skills.txt`
        (`skill-name -> owner/repo` per line, ONE real fetchable skill
        per line, not one line per pack — verified 2026-07-24 that a
        pack-level line, e.g. `superpowers -> obra/superpowers`, breaks
        `npx skills add owner/repo -s <name>` outright when `<name>`
        isn't an actual skill in that repo, and silently fetches only
        one skill out of the pack when it happens to match one by
        coincidence) and ask the user whether to install any of those
        too — group the ask by source repo/pack so the user picks
        "firecrawl (10 skills)" as one choice rather than facing 26 raw
        lines, but fetch every line individually underneath. These
        aren't bundled as files at all, only their names and source
        repos are. This step is NOT conditional on 2.6 having found
        anything to offer — run it every time regardless. Same
        skip-if-installed rule as 2.6 applies here too. If the user
        wants a pack, fetch EVERY line belonging to it, each live via
        `npx skills add <owner/repo> -s <skill>` (`find-skills` is
        always available per 2.5) — no version pin, always whatever is
        current upstream at that moment, never the version this repo
        happened to have when the list was written. Loop this step
        (2026-07-24): right after installing whatever was picked,
        re-offer the remaining packs immediately, repeating until the
        user picks "install nothing" — don't wait to be asked again.
        **Pagination when more packs remain than fit one question**: the
        question tool caps at 4 options total, and "install nothing" is
        always one of them (2.6's zero-is-valid rule), leaving at most 3
        real pack choices per round. If more than 3 packs are still
        undecided, replace the 4th slot with "more options" instead of a
        3rd pack; picking it marks the packs shown this round as
        declined (not installed) and shows the next batch of undecided
        packs, same rules, until all have been offered at least once.
        **Batch the git side, don't sync per pick** (2026-07-24): each
        install inside the loop still gets its own commit (one commit
        per unit of work), but hold off on push,
        merge, and any "sincronitza"-style sync until the whole loop is
        over — only the final state, after the user is done picking,
        needs to actually land on the branch/main. Syncing after every
        single pick is wasted round-trips for state that might get
        immediately superseded by the next answer.
   2.8. **Old consolidated-folder format on the target repo**: if the
        target repo still has a skill nested in the old
        `.claude/skills/<pack>/<skill>/` shape (this repo's own
        convention before it switched to npx-skills' flat one), delete
        that nested copy and reinstall it flat instead — don't leave
        both layouts coexisting for the same skill.
   2.9. **Never touch the target repo's own other skills or hooks**: if
        the target repo has skills or hooks that aren't part of this
        bundle at all (its own repo-specific ones, unrelated to anything
        above), leave them alone — don't delete, rename, or modify them.
        They stay as that repo's own particular content. Only touch them
        if the user explicitly asks to.
3. **This file travels with itself.** `.claude/config-export-import.md`
   is part of the mandatory portable bundle (see point 1 above) —
   exporting or importing a repo's config exports/imports this very
   file too, automatically, with no special-casing needed.
