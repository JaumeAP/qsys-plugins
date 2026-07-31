# Portable skills/config history

<!-- Split out of CLAUDE.md's "Portable skills" section 2026-07-30 (explicit
user request) to bring the main memory file under the ~200-line guidance.
Lives inside .claude/ so it travels with the portable bundle on export, but
is NOT auto-loaded (only CLAUDE.md and .claude/rules/*.md are). Read it when
you need the reasoning behind a skill's bundled/optional/removed status. -->

<!-- Cross-references in this file that say "above"/"below" may now point at
a sibling file after the 2026-07-30 split: CLAUDE.md (operative rules),
.claude/rules/repo-layout.md (directory tree),
.claude/rules/qsys-plugin-development.md (plugin/build reference), or
docs/continuity-notes.md (dated history). -->

## Portable skills (installed with the config)

These generic skills travel with this file and the rest of the `.claude/`
config (see `.claude/config-export-import.md`). `file-operations` and
`github-rules` are mandatory/blind-copy on import into
another repo — the only two skills still bundled as files at all.
`find-skills` moved to fetch-on-demand only 2026-07-28 (explicit user
request), after its own longer mandatory/optional/bundled history
below: no longer bundled as a file, listed instead in
`.claude/recommended-skills.txt` (`find-skills -> vercel-labs/skills`)
like any other unbundled recommendation, fetched live via
`npx skills add vercel-labs/skills -s find-skills` by whoever wants it —
a state it had already passed through once before this same day,
reverted at the time, now the settled choice (see the history note
below). This repo's own local copy of `find-skills` was deleted
outright 2026-07-29 (explicit user request) — `.claude/skills/
find-skills/` removed from disk, repo-local only, deliberately NOT
added to `.claude/removed-files.txt` (that would mechanize pruning it
from every other repo importing this bundle in the future, which
wasn't asked for and isn't warranted here — `find-skills` already
isn't shipped as a bundled file per the paragraph above, so there's
nothing export-side this deletion needed to affect). It had been meant
to stay on disk but disabled via a `skillOverrides: {"find-skills":
"off"}` entry in `.claude/settings.local.json` (gitignored) — but that
settings file was never actually present in this checkout, so the
local copy was live (not disabled) the whole time until this deletion.
Pointers
only, not summaries — same
drift-safety reason as above; each skill is the authority on its own topic,
invoke it when the task calls for it:

1. `github-rules` (`.claude/skills/github-rules/SKILL.md`) — portable GitHub
   PR conventions (workflow shape, reading `pull_request_read` results,
   merge mechanics); generalized 2026-07-27 from an earlier repo-specific
   skill of the same name. Originally: must never encode a standing
   auto-merge policy, since a portable file installs into every repo it's
   imported into, so a rule like that written here would silently apply
   everywhere, not just where someone actually agreed to it. Relaxed
   2026-07-29, explicit user request, after being shown that exact
   consequence and choosing it anyway: the skill now carries a dated,
   attributed standing authorization to open a PR at session close when
   the branch has unmerged commits and none exists, then merge it once
   clean. The reasoning behind the original prohibition is unchanged and
   still applies to anything BEYOND that one authorization — a policy
   written there without a named source and date, or one covering more
   than the routine open/merge cycle, is still the thing to refuse. What
   made this case different is that the authorization is recorded rather
   than self-granted, which is also what lets it satisfy (not bypass) a
   calling environment's own PR-creation gate.

(`git-rules` removed from the portable bundle 2026-07-25, explicit user
request — deleted from `.claude/skills/`, its `skillOverrides` entry
dropped from `settings.json`, and its path added to
`.claude/removed-files.txt` so future imports of an older bundle prune it
from target repos too. Git workflow now follows plain judgement +
the rest of this file's rules, not a dedicated skill.)

(`changelog-rules` and `find-skills` briefly removed from the portable
bundle 2026-07-27, explicit user request, then restored from git history
2026-07-28, also explicit user request. `changelog-rules` stayed optional
from there on, disabled locally alongside `find-skills` once that one
also went optional later 2026-07-28 — until `changelog-rules` was
deleted from the portable bundle entirely a second and final time, also
2026-07-28, also explicit user request: same treatment as `git-rules`
above (`.claude/skills/changelog-rules/` deleted, its now-moot
`skillOverrides` entry dropped from `settings.local.json`, its path
added to `.claude/removed-files.txt`). Changelog work now follows the
repo-wide conventions stated directly where needed, not a dedicated
skill — see the version-history/breaking-change note under "Plugin
structure/naming convention" below.
`find-skills` took a longer road of its own — removed from the
bundle again the same day as a `recommended-skills.txt` fetch-on-demand
entry, then, after weighing whether that was actually worth it, made
mandatory/always-present again the same day, then superseded later the
same day, also explicit user request: moved to optional (still a
bundled file at that point) instead. Superseded once more, also
2026-07-28, also explicit user request: moved off the bundled-file path
entirely, back to fetch-on-demand-only via `recommended-skills.txt` —
ending up back where its first fetch-on-demand attempt left off. Its
local copy went one step further 2026-07-29, also explicit user
request: deleted outright rather than kept disk-side and disabled, see
above.)

**`changelog-rules` reinstated, third time, now mandatory (2026-07-30,
explicit user request).** Everything in the paragraph above stayed true
of its own history up to that point — this is a new chapter, not a
correction. Recovered from git history (`qsys-plugins` commit `3d66272`'s
own parent, and confirmed byte-identical to the copy CPSeries still had
under `b988959`'s parent before that repo's own bundle-cleanup deleted it
the same day this session started) — the exact same 151-line `SKILL.md`
that was removed in 2026-07-28's second and final deletion, unmodified,
since the removal was a preference change, not a functional problem with
the skill itself. This time it went straight into the mandatory
blind-copy group (alongside `file-operations` and `github-rules`) rather
than back through the optional group it occupied for part of its earlier
history — the user's own framing was "recover as mandatory", not "make
available again". `.claude/removed-files.txt`'s
`skills/changelog-rules` entry removed accordingly (a target repo
importing the current bundle should install it, not prune it).
`rule-check-reminder.sh` (see the mandatory-skills entry two paragraphs
below the "Portable skills" pointer in `CLAUDE.md`) now names it
alongside the other mandatory skills. Verified operative before
committing: frontmatter and body checked against the skill discovery
mechanism (picked up and listed as available immediately after being
written to `.claude/skills/changelog-rules/`), content re-read in full
for stale references to anything since removed (none found — the skill
is self-contained, its only external references are to "the repo
`CLAUDE.md` Git rules" and "Critical Rules", both generic pointers every
repo satisfies in some form), and a real bundle was rebuilt and unzipped
to confirm the skill travels correctly as
`references/skills/changelog-rules/changelog-rules.md` inside the
package.

**Find Skills**: `find-skills`, imported from `vercel-labs/skills`
(`skills/find-skills/SKILL.md`) — discovers and installs third-party
skills via the `npx skills` CLI, #1 by install count on skills.sh at
import time. Note its own workflow can
install other skills straight from that ecosystem, bypassing this
repo's own skill-creator/config-ingest governance — worth keeping in
mind wherever it ends up. Fetch-on-demand only now (see above), not a
bundled file — no longer tracked in `skills-lock.json` in the export
either, since that file existed specifically to carry `find-skills`'
own installation provenance along with the bundled copy; a target repo
fetching it fresh via `npx skills add` generates its own lock entry
instead.

(`file-operations` needs no pointer here beyond the numbered list above
— its own description triggers it by context when there's file I/O to
do.)

**`changelog-rules` reverted a fourth time, back to optional (2026-07-30,
same session, explicit user request).** Barely settled as mandatory (see
the entry above) before this reversal — the user's own framing this time:
"opcional, però sempre local; quan no estigui instal·lat, seguirà vivint
dintre del fitxer d'importació/exportació." Three concrete decisions:
1. **Mandatory → optional.** Moved from `config-export-import.md` step
   2.2 (mandatory blind-copy) to step 2.5 (bundled-file, offered as an
   individual choice, same UI as step 2.6's packs) — its fourth distinct
   home in this file's own history, after 2.5 → deleted → 2.5 (from git
   history) → deleted → 2.2 → 2.5 again.
2. **Always local, never fetch-on-demand.** Explicit user instruction:
   unlike `find-skills`, this skill never becomes a `recommended-skills.txt`
   remote-fetch entry. Every state it has occupied — mandatory or
   optional — kept it as a file physically bundled in the export; only
   whether installation is forced or offered has ever changed.
3. **Survives non-installation.** New this turn, explicit user request:
   the skill's full current `SKILL.md` content is now embedded verbatim
   in `config-export-import.md`'s own appendix (added 2026-07-30). Since
   that file is itself part of the mandatory bundle and travels
   everywhere regardless of whether `changelog-rules` is installed, a
   repo without the skill installed still has the complete definition
   sitting locally on disk. This directly answers the failure mode from
   the third reinstatement earlier the same day, which needed a specific
   commit's parent from `qsys-plugins`' own git history to recover the
   skill's exact prior content — that recovery path only worked because
   the reinstating session happened to have GitHub access to search commit
   history; a repo without it, or a session further removed from the
   deletion, would not have been able to reconstruct it. The appendix
   removes that dependency going forward.

Applied per-repo on this same turn: `CPSeries` keeps it installed (real,
active use — a 236-entry `CHANGELOG.md`, called out explicitly in that
repo's own `PROJECT.md` as an override of this skill's default retention
policy). `qsys-plugins` keeps its own copy too, as the bundle's canonical
source (needed for both step 2.2's neighbors and step 2.5's offering
mechanism, regardless of whether this repo itself keeps a `CHANGELOG.md`
— it doesn't). `Eines` had it uninstalled (explicit user request,
weighed against "no file in that repo has ever needed a `## Changelog`
section" — confirmed earlier the same session) — its
`.claude/skills/changelog-rules/` directory removed; if a tool under
`tools/` in that repo ever grows real changelog needs, it installs cleanly
from `config-export-import.md`'s appendix, no git archaeology required.
Removal from `Eines` did NOT add an entry to that repo's
`removed-files.txt` — that file's semantics are "prune this and keep
pruning it on every future import," which is wrong for an optional skill
a repo has simply chosen not to install this time; a future import there
still offers it fresh via step 2.5, same as any repo that never had it.

`rule-check-reminder.sh`'s named mandatory-skill exception (see the
"'Mandatory' wasn't actually enforced" entry below) dropped
`changelog-rules` from its list again, back to the original four
(`file-operations`, `github-rules`, `caveman`, `karpathy-guidelines`) —
an optional skill has no place in a list whose whole point is nagging
about skills CLAUDE.md calls mandatory.

**Which additional skills travel on export is defined in
`.claude/scripts/export-config-skill.sh`** — not repeated here, to avoid
two places that can drift out of sync. Anything installed here but not in
that script's copy list stays local; its name/source is kept in
`.claude/recommended-skills.txt` (plain list, one name per line,
updated by hand) for a target repo to fetch itself if wanted — that
file itself always travels on export.

**Skill creation/extension.** Any skill creation or extension (a new
`SKILL.md`, or a content/frontmatter change to an existing one — this
applies regardless of whether the skill itself is repo-specific or
portable) goes through the `skill-creator` skill's process, not a plain
manual edit (2026-07-20 standing rule). Mechanized best-effort by
`.claude/hooks/skill-creation-reminder.sh` — a non-blocking reminder on
every `Write`/`Edit` to a `SKILL.md`; it can't verify skill-creator was
actually invoked, so it can't hard-block, same honest limitation as
`config-ingest-reminder.sh`. The `writing-skills` skill (from the
`obra/superpowers` bundle) was installed 2026-07-30 alongside the rest
of that bundle, then removed the same day (explicit user request) once
it turned out to prescribe a competing TDD-based process for this same
action, conflicting with `skill-creator`; also dropped from
`recommended-skills.txt`. `skill-creator` remains the sole mandated
process here.

**"Mandatory" wasn't actually enforced, and a full-session audit caught
it (2026-07-30).** `CLAUDE.md` has called `file-operations`,
`github-rules`, `caveman`, and `karpathy-guidelines` mandatory for a
while; none of the four had ever been invoked via the `Skill` tool in a
session that touched their trigger conditions dozens of times over
(rebuilding/writing `.qplug`/`.qplugx` files with raw shell commands
instead of `file-operations`, dispatching GitHub Actions and merging
PRs without ever loading `github-rules`' own content, no reply-
compression or behavioral-principles pass from `caveman`/
`karpathy-guidelines`). Skills load their real content only on an
explicit `Skill` call; `CLAUDE.md`'s own text and the always-loaded
`.claude/rules/*.md` files are a completely separate, passive mechanism
(auto-injected as context) that was never a substitute for that call —
conflating the two is exactly what let this go unnoticed for an entire
session.

Fix, same day: `file-operations` gets an actual mechanical gate,
`.claude/hooks/file-operations-enforcement.sh` (`PreToolUse`/`Bash`,
hard block, same `permissionDecision: deny` pattern `no-commit-on-main.sh`
already used successfully) — narrower than the skill's full "MUST" scope
by design (covers `cp`/`mv`/`rm`/`dd`/`tee`/`sed -i` against a repo path
outside `/tmp/`; does NOT try to catch e.g. a `python3 -c` file write,
since detecting that reliably risks blocking legitimate reads instead).
The other three have no equivalent tool-level chokepoint to gate on (no
single command means "wrote a reply without compressing it" or "merged a
PR without consulting conventions"), so `rule-check-reminder.sh` instead
names all four explicitly on every firing (first call + every 15th) — a
narrow, deliberate exception to that hook's own 2026-07-30 decision to
stop enumerating skills, scoped to just these four mandatory ones, not
reverted for the 25 merely-recommended ones. `CLAUDE.md`'s own "Portable
skills" section points here rather than restating this.

## `changelog-rules` — mandatory/optional status, full timeline

Bundled as a file (never fetch-on-demand remote) throughout its whole
history — only the mandatory-vs-optional question ever changed.
2026-07-30: optional → deleted entirely the same day → restored from git
history as optional → deleted from the bundle a second time, same day →
reinstated a THIRD time, straight into the mandatory blind-copy group →
reverted a FOURTH time, later the same day, back to optional (2.5 group in
`config-export-import.md`), its state through most of that day. 2026-07-31:
reinstalled again after being briefly removed for having no real target
(no repo had a `## Changelog` section at the time) — `qsys-plugins` then
got its own `CHANGELOG.md` created and the skill wired into the
commit flow (CLAUDE.md's "Changelog-before-commit" exception), giving it
a real target for the first time. Its full current `SKILL.md` content also
lives verbatim in `config-export-import.md`'s own appendix, so a repo
without it installed still has the complete definition on hand — no
git-history archaeology needed, the failure mode that appendix exists to
avoid after it happened once already.

## `karpathy-guidelines` — moved out of the mandatory set (2026-07-31)

Was mandatory fetch-on-demand alongside `caveman` since 2026-07-30.
Explicit user request 2026-07-31 moved it to
`programming-optional-skills.txt` instead — optional, programming-specific
now, no longer obligatory for every project regardless of domain. Required
touching 4 places to stay consistent: `recommended-skills.txt` (entry
removed), `programming-optional-skills.txt` (entry added, under "Core
development & architecture" alongside `superpowers`), `CLAUDE.md`'s
"Portable skills" section (mandatory list trimmed to just `caveman`), and
`rule-check-reminder.sh`'s job 1 reminder text (no longer names
`karpathy-guidelines` among the enforced-mandatory four — see the
2026-07-30 entry above for why that hook names them explicitly at all).

## `github-rules` — push-cadence rule added (2026-07-31)

Explicit user request, given directly: batch several commits locally
before pushing, don't push after every single one -- except when a single
change is very large/significant, push right after that one. Added as a
new "Push cadence (direct-to-default workflow)" section, right after
"Choosing a workflow" and before "Branch+PR workflow", mirroring the
principle that section's own "Batch related edits into one PR cycle" line
already applies to the branch+PR path -- this just extends the same idea
to the direct-push default. Edited directly rather than through
skill-creator's full eval loop (test prompts, subagent runs, benchmarking)
per that skill's own stated flexibility ("if the user is like 'I don't
need to run a bunch of evaluations, just vibe with me', you can do that
instead") -- this is a small, unambiguous, directly-dictated policy change
to an existing rules file, not a new skill or an ambiguous behavior worth
eval-testing. Still invoked via the `Skill` tool (skill-creator) rather
than a bare manual edit, per the standing rule that any SKILL.md content
change goes through that process.
Only applied here in qsys-plugins so far -- not yet propagated to
CPSeries/Eines via the export/import bundle mechanism; do that on request,
same as any other portable-skill change.

## CLAUDE.md response-style rules — full history moved here (2026-07-31)

Trimmed out of `CLAUDE.md`'s "Response style" and "Portable skills"
sections (2026-07-31, explicit user request: "treu tot lo que puguis del
fitxer principal de configuracio i posa-ho a l'export o habilitat
corresponent") -- CLAUDE.md keeps only the operative rule + a pointer here
now; this section holds the dated reasoning that used to sit inline.

**Caveman deferral (2026-07-30).** Reply language/compression/formatting
deferring to `caveman` reverses that same day's earlier "this section
[CLAUDE.md] wins" note -- explicit user request. The hooks that used to
enforce the pre-caveman format rules (`check-reply-format.sh`,
`reply-format-preflight.sh`) were unregistered from `settings.json` the
same day. **Correction (2026-07-31, found during a cross-repo audit):**
those two scripts were only ever created in `qsys-plugins` -- they stay on
disk there, dead, with this same retirement note in their own headers.
`CPSeries` and `Eines` never had them at all; CLAUDE.md's old wording ("the
scripts stay on disk, dead") was being copied verbatim into those two
repos' CLAUDE.md as if it were true there too, which it wasn't. Don't
recreate them in CPSeries/Eines to "match" the sentence -- the sentence was
the thing that was wrong, not the missing files.

**Multi-step tool sequence announcements (2026-07-30, explicit user
request).** For git commit/push, multi-file edits, and test runs: announce
each step as a bare 1-3 word action -- "Commit.", "Push.", "Tests." -- no
sentences, no explaining mechanism/internals, before or after but not
both. This briefly deferred to caveman's "no tool-call narration" the same
day as the caveman deferral above, then was carved back out as a second
named exception once that loss turned out not to be wanted -- same pattern
as the numbered-lists exception, not a reversal of the broader deferral
itself. **Git-absent repos** (2026-07-31, explicit user request,
auto-detected not assumed): if the working directory has no git at all,
"Commit."/"Push." never apply. Detect once per session (`git rev-parse
--is-inside-work-tree`); if absent, skip straight to saving/writing files
with no bare label for that non-step. Multi-file-edit and test-run
announcements are unaffected, they don't depend on git.

**Collapse a skill suite to one line (2026-07-31, explicit user request,
asked repeatedly before being made permanent).** When a skill is a suite
(several sub-skills fetched from one `owner/repo`, e.g. `caveman`,
`superpowers`, `remotion`) and it comes up in a reply -- a skill list, an
install summary, anything -- give the suite's own name plus its sub-skill
names as one line/entry, never one numbered list item per sub-skill.
Applies wherever a suite is mentioned, not just
`recommended-skills.txt`/`programming-optional-skills.txt` (which already
used this format before the rule was generalized).

## Skill creation/extension -- mandatory skill-creator process retired (2026-07-31)

From 2026-07-20 through 2026-07-31, CLAUDE.md required every `SKILL.md`
create/edit to go through `skill-creator`'s full interview/eval/benchmark
process, never a plain manual edit. Reversed the same day it was tightened
into a "no shortcuts, ever" clause: tested once for real on a content edit
to `github-rules` (a reference-doc skill, no subjective/behavioral
triggering to evaluate) -- 4 subagents, ~210k tokens, a real bug in the
eval-viewer tooling itself (`generate_review.py`'s `build_run()` only
checked `eval_metadata.json` at a run's immediate parent, missing it
whenever an extra config-name directory sat in between -- fixed directly
in the tool since it's a shared script, not something to route through its
own eval process to fix), and a measured **0% behavioral difference**
between the old and new skill content. The user's own verdict, directly:
not spending that cost on something that doesn't work. Plain manual edits
to any `SKILL.md` are fine again, repo-specific and portable alike.
`skill-creator` itself is still available and still useful for what it's
actually suited to -- a new skill, or a change to one where trigger
accuracy or behavioral output is the question -- invoke it by choice when
that's the situation, not by default. `writing-skills` (obra/superpowers)
remains removed regardless (2026-07-30, unrelated reason -- a competing
TDD-based process for the same action).
`.claude/hooks/skill-creation-reminder.sh` mechanized the retired mandate
and is unregistered from `settings.json` as of this same reversal -- left
on disk, dead, with its own retirement note in its header (present in all
three repos, unlike the check-reply-format.sh pair above).

An immediate follow-up finding, same session: the user asked to try the
retired process ONE more time for real ("Refes-la ara pel procediment
estandard") before accepting the retirement, specifically on the
`github-rules` multi-repo-sessions edit -- that run is what produced the
4-subagent/~210k-token/0%-difference/real-bug result documented above, and
the retirement itself only became permanent after seeing that result
("Definitiu no gastarem mes... elimina tot aquesta funcionalitat").

## "Rebut: <order in English>" leading line reactivated (2026-07-31, explicit user request)

Dropped 2026-07-30 as part of the caveman deferral (see the entry above --
that deferral also killed the whole `check-reply-format.sh` mechanical
enforcement bundle: Catalan-only, no bold/em-dash/ellipsis/headers/tables,
numbered-lists-only). The user asked specifically for this one piece back
("quan et donava una ordre immediatament me la repetides posar-la en
angles"), not the rest of that bundle -- reactivated as a plain CLAUDE.md
rule only, followed by judgment, not re-wired into
`check-reply-format.sh`/`reply-format-preflight.sh` (still retired, still
dead on disk in qsys-plugins per that entry -- those two scripts also
enforced the Catalan-only/no-bold/etc rules the user has NOT asked back,
so mechanically re-enabling them would over-apply this request).

## Bundled-skill group history (find-skills / git-rules / github-rules / changelog-rules) — moved here from `config-export-import.md` (2026-07-31)

The step-by-step version of this history used to live inline in
`config-export-import.md` (steps 2.2/2.5/2.7), spelled out turn by turn
with exact dates -- moved here when that file was trimmed to
operative-only content, same treatment CLAUDE.md got the same day. Nothing
below is new; it's the same record, relocated.

**`find-skills`** had the longest road of any skill in the bundle: optional
(2026-07-27) -> deleted entirely the same day -> restored as optional
(2026-07-28) -> deleted again as fetch-on-demand-only later that day ->
made mandatory/always-present (briefly) -> moved to the then-existing
optional group (2.5) -> and finally, later the same day, moved off the
bundled-file path entirely, back to fetch-on-demand-only via
`recommended-skills.txt` (`find-skills -> vercel-labs/skills`) -- its
final resting state, landing back where its very first attempt at this
left off. A same-day standing order that briefly required installing
`find-skills` first before anything else in the "recommended skills" step
was removed once it went fetch-on-demand-only: `npx skills add` is a
standalone CLI, not dependent on `find-skills` being installed first.

**`git-rules`** was retired from the bundle entirely on 2026-07-25,
explicit user request -- see `removed-files.txt`. Never revisited after
that.

**`github-rules`** was promoted into the bundle 2026-07-27 after being
generalized from an earlier repo-specific skill into portable GitHub PR
conventions. The same day, the whole four-skill group was briefly switched
from mandatory/blind-copy to optional/offered, then later the same day
moved back to mandatory (explicit user request each time) -- its settled
state since.

**`changelog-rules`** walked the longest road of any skill that stayed
bundled (as opposed to going fetch-on-demand like `find-skills`): optional
(2026-07-27) -> deleted entirely the same day -> restored from git history
as optional (2026-07-28) -> deleted from the bundle a second time, also
2026-07-28 -> reinstated a THIRD time on 2026-07-30, straight into the
mandatory blind-copy group -> reverted back to optional a FOURTH time,
later the same day, into the then-existing 2.5 group rather than deleted
(unlike `find-skills`, it never went fetch-on-demand-remote at any point --
every state it occupied kept it as a locally-bundled file, only the
mandatory-vs-optional question ever changed). It used to also embed its
full current `SKILL.md` content verbatim in `config-export-import.md`'s
own appendix, so a repo without it installed still had the complete
definition on hand -- removed 2026-07-31 (the user held their own
extracted copy outside this repo at the time). **Fifth turn, same day,
later: back to mandatory, this time for good** -- installed as a real file
in all three repos and moved into the mandatory blind-copy group for
good, following an audit that also fixed two real bugs in the skill
itself (see the `changelog-rules` entry above). The 2.5 optional group has
been empty ever since.
