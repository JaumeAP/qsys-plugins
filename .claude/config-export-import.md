# Config export/import (cross-repo `.claude/` propagation)

This repo's `.claude/` tooling (`settings.json`, `hooks/`, three mandatory
bundled generic skills — `file-operations`, `github-rules`, and
`changelog-rules` — all under `.claude/skills/`, plus this file) is meant
to be portable across all my repos, same as `CLAUDE.md`. Which additional
skills also travel (if any) is defined in
`.claude/scripts/export-config-skill.sh` — not repeated here. This file is
deliberately plain, not a `SKILL.md`: `.claude/hooks/config-ingest-reminder.sh`
already surfaces it deterministically at the right moments (reading an
incoming-looking file, writing to this repo's own `.claude/hooks/` or
`settings.json`), so it doesn't need to rely on being auto-invoked as a
skill. Two directions, mechanized best-effort by
`.claude/hooks/config-ingest-reminder.sh`. Full history and reasoning for
every rule below (why a skill is mandatory/optional/removed, past
reversals): `.claude/skills-history.md` — pointers only here, current
state only, never summaries or backstory.

**Standing rule: removing an installed skill from a repo is NOT the same
action as removing its catalog entry.** "Treu/desinstal·la `<skill>`", said
on its own, means uninstall it from the CURRENT repo only — delete
`.claude/skills/<name>`/`.agents/skills/<name>` and its
`skills-lock.json` entry. It does NOT mean touching
`recommended-skills.txt`, `programming-optional-skills.txt`,
`investigacio-optional-skills.txt`, or any other catalog file — those stay
as they are, the skill just becomes "catalogued, not installed" (the same
state `swift`/`cpp`/`swiftui-specialist` are already in, deliberately).
Only remove a catalog entry when the user's instruction names the list
explicitly ("treu-la de la llista", "elimina l'entrada de
programming-optional-skills.txt") — and even then, confirm before doing it
rather than inferring it from an uninstall request. The one exception: a
catalog entry that's independently proven wrong on its own merits (dead
pointer, structurally broken without a missing dependency, no real source)
can be corrected/removed as part of that specific fix — that's a
correctness edit to the catalog, not a side effect of an unrelated
uninstall.

1. **Export** (this repo → another repo, on request, e.g. "exporta la
   configuració"): run `.claude/scripts/export-config-skill.sh` — bundles
   `CLAUDE.md` + `.claude/settings.json` + `.claude/hooks/` + this file
   + the three generic skills + `recommended-skills.txt` (includes
   `find-skills` itself as a fetch-on-demand entry, see step 2.7) + every
   current additional pack (each pack keeps its own license, carried along
   on export) — NOT `CLAUDE.md`'s own "Project-specific rules" section
   (that's THIS repo's content, not portable — a new repo writes its own),
   NOT `PROJECT.md` (this repo's own project-specific documentation — the
   target repo writes its own), NOT any other repo-specific
   skill/plugin/component, NOT project-specific hooks (a hook whose only
   job is installing/configuring something for THIS repo's own tooling,
   e.g. a hook that installs a language runtime or interpreter only this
   repo's own test suites need — brings nothing to a repo without that
   same tooling), NOT `HANDOFF.md`'s content. Before handing it over,
   strip every project-specific mention (repo name, project terminology,
   paths) so the result is fully generalist — safe to drop unmodified
   into any project.
   **`settings.json` specifically is filtered, not blind-copied, before it
   goes into the bundle**: `export-config-skill.sh` strips (a) any hook
   registration whose command targets a hook NOT in that script's own
   bundled-hooks list (a project-specific hook like `ensure-lua53.sh` is
   excluded from that list on purpose, but its `settings.json`
   registration would otherwise still ship, pointing at a hook file the
   target repo never receives), and (b) any permission string listed in
   `.claude/local-only-permissions.txt` — this repo's own declared list of
   permissions (e.g. `Bash(lua5.3 *)`, `Bash(apt-get install *)`) that
   exist solely for its own tooling. Both filters are generic mechanisms
   driven by data the source repo declares (the hooks array, the
   permissions file), not hardcoded knowledge of any one repo's specifics,
   so they travel unchanged like the rest of the script.
   `local-only-permissions.txt` itself is NOT part of the bundle, consumed
   only at export time — same treatment as a project-specific hook. Always
   export the CURRENT state of these files, never a stale cached copy.
   **Final handoff: one packaged, generically-named `.skill` file**: a
   top-level `SKILL.md` documents the bundle itself and is the one entry
   point; every other file — `CLAUDE.md`, `settings.json`, `hooks/*.sh`,
   this file, `recommended-skills.txt`, `00-START-HERE.md`,
   `removed-files.txt`, `skills-history.md` — lives under `references/`
   (`skills-history.md` is in the bundle so its pointer from the common
   `CLAUDE.md` doesn't dangle in the target repo; `skills-lock.json` does
   NOT travel — it exists only to carry a fetch-on-demand skill's own
   installation provenance, and no bundled-file skill needs that). A
   `.skill` package may contain only ONE `SKILL.md` (the claude.ai/Skills
   API upload path rejects more than one), so the three bundled skills'
   own `SKILL.md` files (`file-operations`, `github-rules`, and
   `changelog-rules`, all mandatory blind-copies — see step 2.2) are
   renamed to `references/skills/<name>/<name>.md` inside the package —
   restore each one back to `SKILL.md` when actually installing it into a
   target repo's `.claude/skills/<name>/`, that rename is what makes it a
   real, loadable skill again. `caveman` is also mandatory (step 2.2) but
   fetch-on-demand remote only (listed in `recommended-skills.txt` for the
   target repo to install via `npx skills add`).
   `export-config-skill.sh` itself is also bundled, under
   `references/scripts/`, so the target repo can export its own bundle
   later instead of only ever being an import destination. See
   `export-config-skill.sh` itself for exactly how this gets assembled —
   not repeated in full here.
   **Self-describing import instruction**: the bundle also includes
   `references/00-START-HERE.md`, a blunt "stop, read this file, ask the
   user before applying anything" note — added because a bare paste of the
   bundle with no explicit "import the config" request doesn't reliably
   trigger this on its own. The file exists so the bundle carries its own
   trigger instead of depending on the target session already knowing to
   look.
2. **Import** (a config bundle uploaded into a session — "reverse
   direction"). **Ask before applying, unless it's this repo's own
   current bundle**: a detected incoming bundle normally needs the user's
   go-ahead before anything gets applied — that default exists because a
   silent auto-copy has actually happened before (see `00-START-HERE.md`'s
   own text). The one exception: if the target repo is this very bundle's
   source repo AND a fresh export generated right now would be identical
   to the uploaded bundle, applying it changes nothing that isn't already
   there, so it's safe to proceed automatically without asking. Verify
   that identity for real (generate a fresh export, diff it against the
   upload) before treating it as the exception — don't assume from
   context alone. Any bundle that isn't verified identical, including an
   older export of this same repo, still asks first. **Narrate each step
   as it happens** — this procedure is the one deliberate exception to the
   terse/token-economy response style: say explicitly what's being
   checked (bootstrap vs. existing config), what's found (identical vs.
   different, already installed vs. not), and what action follows, rather
   than silently processing and only giving a final verdict. Transparency
   matters more than brevity here, since this is exactly the moment
   content gets applied without individually asking about most of it.
   Every sub-step below always runs, in order — none is conditional on how
   the previous ones turned out, except where stated:
   2.1. **Bootstrap**: if the target repo has no `.claude/` config yet,
        copy everything directly, skip the rest of this list.
   2.2. **Mandatory core files**: every hook under `hooks/`, plus
        `hooks/lib/` (`file-operations-enforcement.sh`'s classifier and
        its regression test — a runtime dependency of that hook, not
        optional, copied recursively), plus `scripts/merge-settings.sh`
        and `scripts/export-config-skill.sh` themselves, plus every file
        under `references/rules/` (portable always-loaded rule files,
        e.g. `session-close.md` — an explicit allowlist on the export
        side, so everything that arrives here is portable by
        construction, safe to blind-copy), is a blind copy into
        `.claude/hooks/`/`.claude/scripts/`/`.claude/rules/` respectively,
        no diff/compare/ask step — straight over whatever's already
        there, they're meant to be identical across all repos by design.
        Installing `export-config-skill.sh` into the target repo too is
        what lets that repo export its own bundle later, instead of only
        ever being an import destination.
        `references/removed-files.txt`, if the bundle carries one, is NOT
        copied into the target — it's a deletion list, not a file to
        install: for every path in it (relative to `.claude/`, e.g.
        `hooks/foo.sh` or `scripts/bar.sh`), delete `.claude/<path>` from
        the target if present. A file that was once part of the mandatory
        bundle but has since been deliberately retired (e.g. dead code,
        superseded by another file) would otherwise stay orphaned forever
        in any repo that imported an older bundle before the removal — a
        plain blind-copy only ever adds/updates files the CURRENT bundle
        carries, it can't know to remove one that's no longer there. If
        the deleted path is under `hooks/`, also remove its matching
        `settings.json` registration, same as any other hook this
        bundle's `settings.json` no longer references.
        `CLAUDE.md` is the one file here that still needs a boundary
        check (2.4).
        `settings.json` is NOT a blind overwrite: it is the one
        hook-registration entry point, so replacing the whole file would
        silently drop any hook registration the target repo already has
        for its own project-specific hooks — files 2.9 says to leave
        alone, but whose settings.json *entries* a blind overwrite would
        still wipe, leaving them orphaned on disk with nothing
        registering them. Merge instead: for every hook this bundle
        carries, add or update its registration to match the incoming
        `settings.json` exactly (incoming always wins for THOSE entries,
        same as everywhere else in this list). For every entry already in
        the target's `settings.json` whose command points at a hook NOT
        in this bundle, keep it as-is, don't drop it. The result is the
        union of both, not a replacement of one by the other.
        `permissions.allow`/`deny`/`ask`/`additionalDirectories` merge the
        same way: union of target and incoming entries, deduped, so a
        target's own project-specific permission rule (e.g. a `Bash(...)`
        allow added for a repo-specific workflow) survives the import
        instead of being silently dropped.
        `skillOverrides` merges too: a shallow per-skill-name merge,
        incoming's value winning for any skill name both sides set,
        target's own entries for every other skill name kept as-is — so a
        target's own repo-specific override (e.g. a skill set to
        `user-invocable-only`) survives an import the same way its
        `permissions` entries do.
        `references/scripts/merge-settings.sh <target-settings.json>
        <incoming-settings.json> <bundle-hook-names...>` (found inside the
        extracted bundle, before anything is copied into place) does
        exactly this and outputs the merged JSON on stdout — use it
        instead of merging by hand. It also gets installed into the
        target's own `.claude/scripts/`, same blind-copy treatment as the
        hooks, so a future re-export/re-import from that repo has it too.
        `github-rules`, `file-operations`, and `changelog-rules` are all
        blind-copied into `.claude/skills/<name>/`, same as the hooks
        above — always overwritten with whatever the bundle carries, even
        if the target already has its own copy, no ask/offer step. The
        2.5 optional group is currently empty.
        **Call this out explicitly while narrating this step:** the
        bundled `github-rules` defaults to full automation of the routine
        commit/push/PR/merge cycle — merging a clean, non-draft PR without
        pausing to ask first. This is a real behavior change for whoever
        installs the bundle, not just a doc tweak, so say so plainly
        rather than letting it pass as one more line in a bulk copy. It
        still excludes destructive/history-rewriting operations (those
        stay confirm-first) and still loses to any explicit merge policy
        the target repo's own `CLAUDE.md` states.
        `caveman` is mandatory but fetch-on-demand remote only. Not
        bundled as a file; target repos install via `npx skills add
        JuliusBrussee/caveman`. Listed in `recommended-skills.txt` as a
        mandatory fetch-on-demand entry — provides compression/terseness
        rules, universally applicable.
   2.3. **Contradiction check, mandatory on every import**: every
        imported hook/common rule always wins over a conflicting rule the
        target repo already has — the general principle 2.2 already
        implements for `hooks/` (blind copy) and `settings.json` (merge,
        incoming wins for the bundle's own entries), and that individual
        rules elsewhere (a bundled skill's own merge-policy clause, for
        instance) also state one at a time. After copying the mandatory
        core files, scan the target repo's own `Project-specific rules`
        section and any of its own hooks/skills left in place (per 2.9)
        for anything that contradicts an incoming hook's enforced
        behavior or a common-section rule (a different merge policy, a
        different reply-format rule, etc.). Narrate any contradiction
        found — the incoming bundle's rule always wins; don't silently
        drop the conflict, note it so it's visible on the next read.
        Narrating in chat is not enough on its own — also flag it in the
        file itself, appending a short inline note right after the
        contradicted sentence in the target's `Project-specific rules`
        section (e.g. "(superseded by an imported rule, YYYY-MM-DD — see
        the relevant bundled skill's merge policy)") — don't delete or
        rewrite the target's original sentence, just mark it stale so a
        future read of that file alone doesn't act on it. This is not
        covered by 2.9's "never touch" — that rule protects unrelated
        content, not a sentence this very step just proved contradicts an
        incoming rule.
   2.4. **`CLAUDE.md`, common part only**: same substitution treatment as
        2.2, everything above "Project-specific rules" (that section is
        the target repo's own content and is never part of the bundle in
        the first place). This section's own opening lines (1-6,
        "identical in every repo... copy it verbatim") are the anchor
        confirming which block counts as the common part being
        substituted.
        Mind the join boundary: the bundle's `CLAUDE.md` already ends
        with its own trailing blank line — concatenating it with the
        target's `Project-specific rules` section plus an EXTRA blank
        line in between produces a spurious double-blank-line diff every
        single import, cosmetic but needless. Join them directly, no
        inserted separator.
   2.4a. **`PROJECT.md` separation policy**: check whether the target
        repo has a `PROJECT.md` file at its root. If it does, leave it
        untouched — it is repo-specific project documentation, equivalent
        to CLAUDE.md's own "Project-specific rules" section, and the
        target repo maintains it. If the target repo does NOT yet have a
        `PROJECT.md` but this very import is the first time its
        `CLAUDE.md` structure is being split out (common rules above
        "Project-specific rules", project-specific content below), offer
        to create one: extract the target's `CLAUDE.md` "Project-specific
        rules" section (everything from that heading onward, not the
        common part just installed by 2.4 above), write it as the new
        `PROJECT.md`, then trim the target's `CLAUDE.md` to end right
        before that heading — same split as 2.4 just did. This is a
        service on import: repos that haven't yet split this out get
        their rules separated in one step, without needing a separate
        manual edit. Report what was split and where (narrate each
        sub-step as 2.2 requires), and let the user know to add
        `PROJECT.md` to their commits once the import workflow is
        complete.
   2.4b. **Retire the old session-continuity and merge systems.** Two
        older systems predate what the common part now states, and a
        blind copy cannot remove either on its own — one lives in a root
        file the deletion list cannot even name, the other in prose:
        1. **`HANDOFF.md` → `docs/continuity-notes.md`.** The common
           section names `docs/continuity-notes.md`; a target repo still
           keeping a root `HANDOFF.md` is on the retired system.
           **Migrate, never just delete**: a live `HANDOFF.md` holds real
           state (standing work rules, open items, current-state notes),
           so move that content into `docs/continuity-notes.md` —
           creating it if absent, appending under a dated heading if
           present — and only then delete `HANDOFF.md`. Anything that is
           per-session narrative rather than standing state can be
           dropped in the move; git log and the changelog already hold
           it. The two hooks that mechanized the old system
           (`hooks/require-handoff-read.sh`, `hooks/check-handoff-pushed.sh`)
           are in `removed-files.txt`, so 2.2 already prunes them and
           their `settings.json` registrations — this step is only about
           the content and the root file itself.
        2. **`github-rules` is the sole, official mechanism for PR/merge
           behavior, always, with total priority (2026-07-31, explicit
           user call).** Broader than a "retire the old system" migration:
           remove ANY target-repo restatement of PR/merge/commit-automation
           behavior — in `CLAUDE.md`'s Project-specific section,
           `PROJECT.md`, or any other repo-specific rules file — whether it
           conflicts with `github-rules` or merely agrees with it. The
           bundled skill's own file is the only place this behavior may be
           stated; not even an agreeing pointer is left standing elsewhere.
           This supersedes and subsumes the narrower "local-merge → PR"
           case from before 2026-07-31:
           - The old plain-local-merge convention (a `CLAUDE.md` telling a
             session to merge the working branch into the default branch
             with plain local git, no PR): removed outright, no
             replacement text — 2.2 already installs the real behavior via
             the bundled skill. Reason it mattered beyond consistency: a
             calling environment can restrict pushes to the designated
             working branch, which makes a local merge impossible, while a
             PR merge lands the same work without pushing another branch.
             The hooks for this case (`hooks/local-merge-reminder.sh`,
             `hooks/sync-command-reminder.sh`) are likewise already in
             `removed-files.txt`.
           - A target's own dated, explicit-user-authorized override that
             already agrees with `github-rules` (e.g. a "the PR always
             wins" style rule): removed too — its own prior authorization
             does not exempt it from this rule.
           In both cases, record what was found and removed in the
           target's own continuity notes (dated) rather than silently
           erasing the reasoning — the GitHub merge API attributing merge
           commits to the authenticated integration account rather than
           the session's own git identity is one such tradeoff worth
           keeping on record wherever it was the original stated reason
           for a now-removed local-merge rule.
        Both sub-steps touch the target's own Project-specific section,
        which 2.4 otherwise leaves alone — that is deliberate and is the
        one sanctioned exception: these are retired systems, not repo
        preferences. Narrate what was migrated and what was deleted.
   2.5. **Bundled-file skills offered as an optional choice**: the
        category for a skill that ships as a file in the bundle (like
        2.2's mandatory ones) but isn't force-installed or silently
        overwritten — fold any such skill into the same 2.6 offering
        (same individual-selection UI, same already-installed/
        update-check treatment — see 2.6 for exactly what that means
        when already in the target's `.claude/skills/`), rather than a
        separate step. **Currently empty**: `file-operations`,
        `github-rules`, and `changelog-rules` are all mandatory
        blind-copies (see 2.2) — none of them are in this group. Full
        history of what has occupied this group in the past and why:
        `.claude/skills-history.md`.
   2.6. **Additional packs actually bundled as files, always offer,
        optional to accept**: every skill beyond the three mandatory ones
        in 2.2 and empty in 2.5 that the bundle actually carries as files
        — the full list is open-ended and growing over time (see
        `.claude/scripts/export-config-skill.sh` for what it currently
        contains, not repeated here) — always ask the user which ones to
        load, presenting a list they can select from individually (not an
        all-or-nothing choice); only copy in the packs actually chosen.
        Before presenting this list, check what's already under the
        target repo's own `.claude/skills/`. For a skill already there,
        don't just filter it out silently — diff its installed `SKILL.md`
        (and any bundled resource files) against the bundle's version
        first (content compare, not a version number — neither side
        necessarily carries one). Identical: filter it out of the list as
        before, nothing to offer. Different: still leave it out of the
        main install-selection list (it's not a fresh install), but
        separately flag it as an available update and offer to sync it to
        the bundle's version — only apply if the user says yes. Don't
        rely on the user noticing a stale copy themselves; this check is
        what surfaces it. Selecting none of the offered packs is always a
        valid answer — never force a pick when the honest answer is
        "install nothing."
   2.7. **Recommended-but-not-bundled skills, always offer too**: once
        2.6 is settled, also read `recommended-skills.txt`
        (`skill-name -> owner/repo` per line, ONE real fetchable skill
        per line, not one line per pack — a pack-level line breaks `npx
        skills add owner/repo -s <name>` outright when `<name>` isn't an
        actual skill in that repo) and ask the user whether to install
        any of those too — group the ask by source repo/pack so the user
        picks "firecrawl (10 skills)" as one choice rather than facing 26
        raw lines, but fetch every line individually underneath. These
        aren't bundled as files at all, only their names and source repos
        are. This step is NOT conditional on 2.6 having found anything to
        offer — run it every time regardless. The already-installed check
        works differently here than 2.6: these have no local bundle
        snapshot to diff against in the first place, only a live upstream
        source repo, so "is there a newer version" means checking that
        source online, not comparing two local files. For a recommended
        skill already installed in the target, check the source repo
        (e.g. its latest commit/release touching the skill's path, or
        just re-running the fetch and comparing the result) for a newer
        version before assuming the local copy is current — `npx skills
        add` always pulls whatever is current upstream regardless, so
        this check is really "would re-running it change anything," and
        only worth surfacing/offering if it would. If the user wants a
        pack, fetch EVERY line belonging to it, each live via `npx skills
        add <owner/repo> -s <skill>` — no version pin, always whatever is
        current upstream at that moment, never the version this repo
        happened to have when the list was written. Loop this step: right
        after installing whatever was picked, re-offer the remaining
        packs immediately, repeating until the user picks "install
        nothing" — don't wait to be asked again.
        **Pagination when more packs remain than fit one question**: the
        question tool caps at 4 options total, and "install nothing" is
        always one of them (2.6's zero-is-valid rule), leaving at most 3
        real pack choices per round. If more than 3 packs are still
        undecided, replace the 4th slot with "more options" instead of a
        3rd pack; picking it marks the packs shown this round as declined
        (not installed) and shows the next batch of undecided packs, same
        rules, until all have been offered at least once.
        **Batch the git side, don't sync per pick**: each install inside
        the loop still gets its own commit (one commit per unit of work),
        but hold off on push, merge, and any "sincronitza"-style sync
        until the whole loop is over — only the final state, after the
        user is done picking, needs to actually land on the
        branch/main. Syncing after every single pick is wasted
        round-trips for state that might get immediately superseded by
        the next answer.
   2.8. **Old consolidated-folder format on the target repo**: if the
        target repo still has a skill nested in the old
        `.claude/skills/<pack>/<skill>/` shape (this repo's own
        convention before it switched to npx-skills' flat one), delete
        that nested copy and reinstall it flat instead — don't leave both
        layouts coexisting for the same skill.
   2.9. **Never touch the target repo's own other skills or hooks**: if
        the target repo has skills or hooks that aren't part of this
        bundle at all (its own repo-specific ones, unrelated to anything
        above), leave them alone — don't delete, rename, or modify them.
        They stay as that repo's own particular content. Only touch them
        if the user explicitly asks to.
3. **This file travels with itself.** `.claude/config-export-import.md` is
   part of the mandatory portable bundle (see point 1 above) — exporting
   or importing a repo's config exports/imports this very file too,
   automatically, with no special-casing needed.
