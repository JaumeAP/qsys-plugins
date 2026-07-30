# Config export/import (cross-repo `.claude/` propagation)

This repo's `.claude/` tooling (`settings.json`, `hooks/`, two mandatory
bundled generic skills — `file-operations` and `github-rules` — plus a
third, `changelog-rules`, bundled the same way but optional per target repo
(step 2.5), all under `.claude/skills/`, plus this file) is meant to be portable
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
   + the two generic skills + `recommended-skills.txt` (which now
   includes `find-skills` itself as a fetch-on-demand entry, see step
   2.7) + every current additional pack (each
   pack keeps its own license, carried along on
   export) — NOT `CLAUDE.md`'s own
   "Project-specific rules" section (that's THIS repo's content, not
   portable — a new repo writes its own), NOT `PROJECT.md` (this repo's
   own project-specific documentation, conventions, and rules — the target
   repo writes its own), NOT any other repo-specific
   skill/plugin/component, NOT project-specific hooks (a hook whose only
   job is installing/configuring
   something for THIS repo's own tooling, e.g. a hook that installs a
   language runtime or interpreter only this repo's own test suites need —
   brings nothing to a repo without that same tooling), NOT `HANDOFF.md`'s
   content. Before
   handing it over, strip every project-specific mention (repo name, project
   terminology, paths) so the result is fully generalist — safe to drop
   unmodified into any project.
   **`settings.json` specifically is filtered, not blind-copied, before
   it goes into the bundle** (2026-07-28 fix — a plain `cp` was found to
   leak two kinds of project-specific content into an otherwise generic
   bundle): `export-config-skill.sh` strips (a) any hook registration
   whose command targets a hook NOT in that script's own bundled-hooks
   list (a project-specific hook like `ensure-lua53.sh` is excluded from
   that list on purpose, but its `settings.json` registration would
   otherwise still ship, pointing at a hook file the target repo never
   receives), and (b) any permission string listed in
   `.claude/local-only-permissions.txt` — this repo's own declared list
   of permissions (e.g. `Bash(lua5.3 *)`, `Bash(apt-get install *)`)
   that exist solely for its own tooling. Both filters are generic
   mechanisms driven by data the source repo declares (the hooks array,
   the permissions file), not hardcoded knowledge of any one repo's
   specifics, so they travel unchanged like the rest of the script.
   `local-only-permissions.txt` itself is NOT part of the bundle,
   consumed only at export time — same treatment as a project-specific
   hook. Always export the CURRENT state of these
   files, never a stale cached copy. **Final handoff: one packaged,
   generically-named `.skill` file** (2026-07-24, replacing the earlier
   plain-`.zip` delivery once verified byte-for-byte equivalent — a
   `.skill` is just a zip with that extension, one required entry at its
   root, `SKILL.md`): a top-level `SKILL.md` documents the bundle itself
   and is the one entry point; every other file — `CLAUDE.md`,
   `settings.json`, `hooks/*.sh`, this file, `recommended-skills.txt`,
   `00-START-HERE.md`, `removed-files.txt`, `skills-history.md` — lives
   under `references/`. (`skills-history.md` joined the bundle 2026-07-30,
   when the common CLAUDE.md's "Portable skills" section was cut down to
   pointers and the bundled/optional/removed reasoning moved into it;
   install it to the target's `.claude/skills-history.md`, or that
   pointer dangles there.)
   (`skills-lock.json` no longer travels here either, 2026-07-28: it
   existed specifically to carry `find-skills`' own installation
   provenance alongside its bundled copy, and `find-skills` isn't a
   bundled copy any more, see step 2.5.) A `.skill`
   package may
   contain only ONE `SKILL.md` (the claude.ai/Skills API upload path
   rejects more than one), so the three bundled skills' own `SKILL.md`
   files (`file-operations` and `github-rules`, mandatory blind-copies —
   see step 2.2; `changelog-rules`, bundled but optional per repo — see
   step 2.5) are renamed to
   `references/skills/<name>/<name>.md` inside the package — restore
   each one back to `SKILL.md` when actually installing it into a
   target repo's `.claude/skills/<name>/`, that rename is what makes
   it a real, loadable skill again. `caveman` and `karpathy-guidelines`
   are also mandatory (step 2.2) but fetch-on-demand remote only (listed
   in `recommended-skills.txt` for target repo to install via `npx skills add`).
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
        `github-rules` and `file-operations` (2026-07-27, explicit user
        request each time, both reverted the same day they were briefly
        moved into the optional group in 2.5 — `github-rules` first,
        `file-operations` later that same day): both blind-copied
        into
        `.claude/skills/<name>/`, same as the
        hooks above — always overwritten with whatever the bundle
        carries, even if the target already has its own copy, no
        ask/offer step. `changelog-rules` was here too, briefly, for part
        of 2026-07-30 (see the history note below) but is back in the
        optional group in 2.5, its current and settled state. `find-skills`
        joined this mandatory group here briefly at one
        point on 2026-07-28 (explicit user request), during the longest
        road of
        any skill in this file: optional (2026-07-27) → deleted entirely
        the same day → restored as optional 2026-07-28 → deleted again as
        fetch-on-demand-only later that day → made
        mandatory/always-present here → moved to the optional group in
        2.5 (explicit user request again) → and finally, later the same
        day (explicit user request once more), moved off the
        bundled-file path entirely, back to fetch-on-demand-only via
        `recommended-skills.txt` (see 2.7) — its final resting state, at
        least so far, landing back where its very first attempt at this
        left off.
        `changelog-rules` walked the longest road of any skill that
        stayed bundled: optional (2026-07-27) → deleted entirely the same
        day → restored from git history as optional (2026-07-28) →
        deleted from the bundle a second time, also 2026-07-28, also
        explicit user request → reinstated a THIRD time on 2026-07-30
        (explicit user request), straight into this mandatory blind-copy
        group → reverted back to optional a FOURTH time, later the same
        day (explicit user request again), this time into the 2.5 group
        rather than deleted — see 2.5 for its current state. Two things
        are new about this fourth turn, both explicit user requests: it
        stays a locally-bundled file forever (never demoted to
        fetch-on-demand-remote like `find-skills`, so "optional" here
        means "ask before installing," not "fetch it live"), and its full
        current `SKILL.md` content is now also embedded verbatim in this
        file's own appendix (see the end of this document) — so a repo
        that doesn't have it installed still has the complete skill
        definition on hand locally, no git-history recovery needed the
        way 2026-07-30's third reinstatement required.
        `.claude/skills-history.md` has the full
        timeline with reasoning at each turn.
        **Call this out explicitly while narrating this step (2026-07-28,
        explicit user request):** the bundled `github-rules` now defaults
        to full automation of the routine commit/push/PR/merge cycle —
        merging a clean, non-draft PR without pausing to ask first. This
        is a real behavior change for whoever installs the bundle, not
        just a doc tweak, so say so plainly rather than letting it pass
        as one more line in a bulk copy. It still excludes destructive/
        history-rewriting operations (those stay confirm-first) and still
        loses to any explicit merge policy the target repo's own
        `CLAUDE.md` states.
        `caveman` and `karpathy-guidelines` (2026-07-30, explicit user
        request): both added as mandatory skills (2026-07-30, second explicit
        user request): moved to fetch-on-demand remote only. Not bundled as
        files; target repos install via `npx skills add JuliusBrussee/caveman`
        and `npx skills add forrestchang/andrej-karpathy-skills`. Listed in
        `recommended-skills.txt` as mandatory fetch-on-demand entry. `caveman`
        provides compression/terseness rules (universally applicable);
        `karpathy-guidelines` provides thinking principles applicable to any
        project.
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
   2.4a. **`PROJECT.md` separation policy** (2026-07-30): check whether
        the target repo has a `PROJECT.md` file at its root. If it does,
        leave it untouched — it is repo-specific project documentation,
        equivalent to CLAUDE.md's own "Project-specific rules" section,
        and the target repo maintains it. If the target repo does NOT yet
        have a `PROJECT.md` but this very import is the first time its
        `CLAUDE.md` structure is being split out (common rules above
        "Project-specific rules", project-specific content below), offer
        to create one: extract the target's `CLAUDE.md` "Project-specific
        rules" section (everything from that heading onward, not the
        common part just installed by 2.4 above), write it as the new
        `PROJECT.md`, then trim the target's `CLAUDE.md` to end right
        before that heading — same split as 2.4 just did. This is a
        service on import: repos that haven't yet split this out get
        their rules separated in one step, without needing a separate
        manual edit. Report what was split and where (narrate each sub-step
        as 2.2 requires), and let the user know to add `PROJECT.md` to
        their commits once the import workflow is complete.
   2.4b. **Retire the old session-continuity and merge systems**
        (2026-07-30, explicit user request: the new system travels with
        the bundle and the import removes the old one). Two older
        systems predate what the common part now states, and a blind
        copy cannot remove either on its own — one lives in a root file
        the deletion list cannot even name, the other in prose:
        1. **`HANDOFF.md` → `docs/continuity-notes.md`.** The common
           section names `docs/continuity-notes.md`; a target repo
           still keeping a root `HANDOFF.md` is on the retired system.
           **Migrate, never just delete**: a live `HANDOFF.md` holds
           real state (standing work rules, open items, current-state
           notes), so move that content into
           `docs/continuity-notes.md` — creating it if absent, appending
           under a dated heading if present — and only then delete
           `HANDOFF.md`. Anything that is per-session narrative rather
           than standing state can be dropped in the move; git log and
           the changelog already hold it. The two hooks that mechanized
           the old system (`hooks/require-handoff-read.sh`,
           `hooks/check-handoff-pushed.sh`) are in
           `removed-files.txt`, so 2.2 already prunes them and their
           `settings.json` registrations — this step is only about the
           content and the root file itself.
        2. **Local-merge → pull request.** If the target's
           `CLAUDE.md` (including its own Project-specific section) tells
           a session to merge the working branch into the default branch
           with plain local git and no PR, replace that with the
           `github-rules` default the common part already carries: open a
           PR and merge it. Reason it matters beyond consistency: a
           calling environment can restrict pushes to the designated
           working branch, which makes a local merge impossible, while a
           PR merge lands the same work without pushing another branch.
           Record the tradeoff rather than dropping it — the GitHub merge
           API attributes the merge commit to the authenticated
           integration account, not the session's git identity, which is
           the reason the local-merge rule existed. The hooks for this
           one (`hooks/local-merge-reminder.sh`,
           `hooks/sync-command-reminder.sh`) are likewise already in
           `removed-files.txt`.
        Both sub-steps touch the target's own Project-specific section,
        which 2.4 otherwise leaves alone — that is deliberate and is the
        one sanctioned exception: these are retired systems, not repo
        preferences. Narrate what was migrated and what was deleted.
   2.5. **Bundled-file skills offered as an optional choice**: the
        category for a skill that ships as a file in the bundle (like
        2.2's mandatory ones) but isn't force-installed or silently
        overwritten — fold any such skill into the same
        2.6 offering (same individual-selection UI, same
        already-installed/update-check treatment — see 2.6 for exactly
        what that means when already in the target's
        `.claude/skills/`), rather than a separate step. Currently holds
        one member: `changelog-rules` (moved back here 2026-07-30, its
        fourth turn — see the history note below). Install it only where
        the target repo actually maintains a changelog (has, or will
        soon have, a file with a `## Changelog` section) — don't install
        it reflexively just because it's offered. If the target repo
        declines it, or the skill was never asked about at all (e.g. a
        contradiction-check-only pass), its full current `SKILL.md`
        content is still available locally: see this file's own appendix
        at the end, which travels with every import regardless of
        whether `changelog-rules` itself is installed. `file-operations`
        and `github-rules` are NOT in this group — both are mandatory
        blind-copies, see 2.2.
        (History: 2026-07-24 `find-skills` promoted from the then-optional
        group in 2.6 into the then-mandatory one — it was already always
        bundled by the export-side loop in what was then `export-config.sh`
        (now `export-config-skill.sh`), this closed the gap on the import
        side to match; 2026-07-25 `git-rules` retired from that group
        entirely by explicit user request, see `removed-files.txt`;
        2026-07-27 `github-rules` promoted into that group after being
        generalized from an earlier repo-specific skill into portable
        GitHub PR conventions, then the same day the whole group of four
        was switched from mandatory/blind-copy to optional/offered, then
        later the same day `github-rules` was moved back to mandatory,
        `changelog-rules`/`find-skills` were dropped from the bundle
        entirely, and `file-operations` was also moved back to
        mandatory, leaving this group empty; 2026-07-28
        `changelog-rules`/`find-skills` were restored from git history
        and put back here as optional, explicit user request, rather
        than staying deleted or becoming mandatory like the other two;
        later the same day `find-skills` was removed from the bundle
        again as a `recommended-skills.txt` fetch-on-demand entry
        instead, then, after weighing whether that fetch-on-demand
        arrangement was actually worth it, made mandatory/always-present
        again the same day, then moved back here to the optional group
        (explicit user request), and finally, later the same day
        (explicit user request once more), moved off the bundled-file
        path entirely, back to fetch-on-demand-only — its final resting
        state, at least so far, the same place its very first attempt at
        this left off. `changelog-rules` stayed
        here as optional for the rest of that earlier history, but was then
        removed from the bundle entirely, also 2026-07-28, also explicit
        user request — same treatment as `git-rules`. It stayed removed
        until 2026-07-30, when it was reinstated a third time (explicit
        user request) straight into the mandatory blind-copy group in
        2.2 — skipping this optional group entirely, unlike every earlier
        chapter of its history — then reverted a fourth time, later the
        same day (explicit user request again), back into this group,
        which is where it now lives. Unlike `find-skills`, it never became
        fetch-on-demand-remote at any point in its history — every state
        it's occupied kept it as a locally-bundled file, only the
        mandatory-vs-optional question ever changed. This group had zero
        members between the third and fourth turns.)
   2.6. **Additional packs actually bundled as files, always offer,
        optional to accept**: every skill beyond `file-operations` and
        `github-rules` (both bundled mandatory per 2.2; `caveman` and
        `karpathy-guidelines` are mandatory but fetch-on-demand, see 2.2)
        and beyond `changelog-rules` (bundled but optional, offered
        exactly like this step's own packs, per 2.5, its own step)
        that the bundle actually carries as files — the full list is
        open-ended and growing over time (see
        `.claude/scripts/export-config-skill.sh` for what it currently
        contains, not repeated here) — always ask the user which ones
        to load, presenting a list they can select from individually
        (not an all-or-nothing choice); only copy in the packs actually
        chosen. Before presenting this list, check what's already under
        the target repo's own `.claude/skills/`. For a skill already
        there, don't just filter it out silently — diff its installed
        `SKILL.md` (and any bundled resource files) against the
        bundle's version first (content compare, not a version number —
        neither side necessarily carries one). Identical: filter it out
        of the list as before, nothing to offer. Different: still leave
        it out of the main install-selection list (it's not a fresh
        install), but separately flag it as an available update and
        offer to sync it to the bundle's version — only apply if the
        user says yes. Don't rely on the user noticing a stale copy
        themselves; this check is what surfaces it. Selecting
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
        anything to offer — run it every time regardless. The
        already-installed check works differently here than 2.6
        (corrected 2026-07-28, explicit user request): these have no
        local bundle snapshot to diff against in the first place, only a
        live upstream source repo, so "is there a newer version" means
        checking that source online, not comparing two local files. For
        a recommended skill already installed in the target, check the
        source repo (e.g. its latest commit/release touching the skill's
        path, or just re-running the fetch and comparing the result) for
        a newer version before assuming the local copy is current —
        `npx skills add` always pulls whatever is current upstream
        regardless, so this check is really "would re-running it change
        anything," and only worth surfacing/offering if it would.
        (A same-day standing order briefly required installing
        `find-skills` first before anything else in this step — moot
        while `find-skills` was mandatory/always-present via 2.2, so it
        was already there by the time this step ran; removed rather than
        left as a dead instruction. `find-skills` went through a longer
        history after that (see 2.5) before settling, also 2026-07-28,
        as one of THIS step's own `recommended-skills.txt` lines
        (`find-skills -> vercel-labs/skills`) rather than a bundled file
        at all — no special-casing needed for it here: `npx skills add`
        is a standalone CLI, not dependent on the `find-skills` `SKILL.md`
        being installed first, so fetching `find-skills` itself through
        this same step works the same as fetching any other
        recommendation on the list.) If the user
        wants a pack, fetch EVERY line belonging to it, each live via
        `npx skills add <owner/repo> -s <skill>` — no version pin, always whatever is
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

## Appendix: `changelog-rules` full source (2026-07-30)

`changelog-rules` is bundled but optional (step 2.5) — a target repo may
not have it installed under `.claude/skills/changelog-rules/SKILL.md`.
Because this file itself is part of the mandatory bundle (point 3 above)
and travels to every repo regardless, its full current content is kept
here too, verbatim, so a repo without the skill installed still has the
complete definition on hand locally — no need to reinstall it just to read
it, and no need for git-history archaeology if it was ever removed (the
failure mode this appendix specifically exists to avoid, after exactly
that happened once already this same day). Keep this copy in sync with
`.claude/skills/changelog-rules/SKILL.md` whenever that file changes —
they're meant to be identical. To actually install the skill in a repo
that doesn't have it, copy the content below (everything between the
four-backtick fences, unchanged) into
`.claude/skills/changelog-rules/SKILL.md` in that repo.

````markdown
---
name: changelog-rules
description: MUST use whenever a file contains a "## Changelog" section or changelog work is requested. This is mandatory for all changelog work. Covers semantic versioning, entry format, the accumulate-in-memory-until-push workflow, retention/dedup rules, and which files are excluded (pure rule/prompt files defining behavior for other files, with no logic of their own).
---

# Changelog Rules

Standard for maintaining changelog entries across all projects.

## Scope

- Auto-activate if file contains `## Changelog`. New files: ask once, remember.
- Applies to all text files (`.md`, code comments, release notes, skill files).
- Applies: functional code libraries, skills, and any file with real content/logic.
- Excluded: files whose sole purpose is defining behavior/rules for OTHER files (e.g. project profile, prompts). No changelog there; history lives in version control.
- This skill file (changelog-rules) is self-exempted: it is the standard's own reference implementation, so it carries a changelog to demonstrate the format it defines.

## Format

```
## Changelog

- **v0.0.0** (YYYY-MM-DD) - Summary
  - type: Description
```

- **Version:** Semantic versioning `v0.0.0`
- **Date:** ISO 8601 `YYYY-MM-DD`
- **Summary:** One-line description of the release/set of changes
- **Types:** `bugfix`, `feature`, `refactor`, `docs`, `chore`, `perf`, `security`
- **Entries:** Short, action-focused descriptions per change type

### Version Increment Logic

Default: infer increment level (patch/minor/major) from number and importance of changes.

- **Patch (v0.0.X):** Bug fixes, small docs updates, security patches
- **Minor (v0.X.0):** New features, non-breaking refactors, performance improvements
- **Major (vX.0.0):** Breaking changes, major rearchitecture, API changes

Do not ask for increment level unless user specifies explicitly.

## Workflow

### Accumulation (In Memory)

- Do not write changelog entries to disk mid-session; write the accumulated
  entries just before each `git push` (push is autonomous — see the repo
  `CLAUDE.md` Git rules). The old "wait for a save/desa/guarda keyword" gate
  is removed (2026-07-14): the changelog is now written as part of the push
  flow, not on a manual keyword.
- Presenting file for verification does not count as writing it out
- Confirm accumulation silently after each change
- Keep entries in memory across multiple edits within a single session

### On Push

Just before each `git push`:

1. **Verify:** Changelog entry accumulated, version incremented per logic above, no conflicts
2. **Update file:** Add entry, maintain chronological order (newest first)
3. **Present:** Only if file is renderable (`.md`, `.html`) and not excessively long; no inline text
4. **Announce:** Version, date, entries added in active conversation language
5. **Summary:** One-line summary of all changes made; if no changes, announce nothing

### Maintenance

- **Retention:** Keep 10 most recent entries. Remove older entries silently on each push.
- **Deduplication:** Do not add duplicate entries for the same change.
- **Coherence:** Each entry must trace to a verifiable change; do not add placeholders or "TBD" entries.

## Placement

- **If `## Changelog` at top:** Move to end before any operation
- **If `## Changelog` at end or missing:** Append new entries at top of section, maintaining newest-first order
- **Filename:** Rename with version suffix only if filename already contains a version suffix (e.g., `SKILL.md` -> `SKILL-v1.0.0.md` only if original had version)

## Examples

### Good

```markdown
- **v2.1.0** (2026-06-30) - Added async I/O support
  - feature: Async file read/write via asyncio thread pool
  - perf: Reduced I/O latency by 40% on large files
  - docs: Updated README with streaming examples
```

### Avoid

```markdown
- **v2.0.999** (2026-06-30) - Various improvements  # Too vague
  - TBD                                              # No content
  - bugfix: Fixed stuff                              # Not specific
```

## Special Cases

### First Changelog Entry

If file has no existing `## Changelog` section:

1. Create section at end of file
2. Add initial entry with appropriate version (usually `v0.1.0` or `v1.0.0`)
3. Ask once if adding changelog to new file types; remember preference

### Breaking Changes

Always bump major version. Note breaking change explicitly:

```markdown
- **v3.0.0** (2026-06-30) - Breaking API changes
  - breaking: Removed deprecated `old_function()` -- use `new_function()` instead
  - feature: New modular architecture for extensibility
```

### Pre-release Versions

Optional; use only if explicitly requested:

```markdown
- **v2.0.0-beta.1** (2026-06-30) - Beta release for testing
- **v2.0.0-rc.1** (2026-06-30) - Release candidate
```

## Changelog

- **v1.1.1** (2026-07-30) - Lean editing pass (skill-creator review)
  - docs: Removed "Integration with Coding Rules" section -- referenced
    a "Critical Rules" doc that does not exist anywhere in the bundle,
    dangling since genericization; no other content lost

- **v1.1.0** (2026-07-06) - Converted standard to skill format
  - refactor: Repackaged CHANGELOG-RULES.md as SKILL.md with frontmatter for auto-discovery
  - docs: Merged "Scope of Applicability" into main Scope section
  - docs: Self-exemption note moved into Scope

- **v1.0.1** (2026-07-05) - Fixed self-contradiction in Scope of Applicability
  - docs: Excluded clause now scoped to files defining rules for OTHER files
  - docs: File explicitly self-exempted as the standard's own reference implementation

- **v1.0.0** (2026-06-30) - Initial standalone release
  - feature: Separated Changelog Rules from coding.md into dedicated file
  - feature: Added format, workflow, examples, special cases sections
  - docs: Clarified integration with Critical Rules; no contradiction
  - docs: Added version increment logic and breaking change guidance
````
