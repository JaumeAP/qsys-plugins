#!/usr/bin/env python3
# Classifier for file-operations-enforcement.sh -- extracted into its own
# module 2026-07-30 (was inline in the hook's heredoc) specifically so it
# can be unit-tested directly (see test_file_ops_classifier.py) instead of
# only ever exercised end-to-end through the hook's stdin/jq plumbing.
# That gap is exactly what let two real bugs ship in the first version of
# this quote-aware rewrite: a code-reviewer subagent caught them by
# actually executing constructed inputs, which the "16 hand-verified
# cases" claim in the original commit message turned out not to cover.
#
# Decides whether a Bash tool_input.command should be blocked because it
# runs cp/mv/rm/dd/tee/install (or sed -i) against a real repo path
# outside /tmp/. Returns a string starting with "BLOCK" or "OK" -- see
# classify() below. No I/O of its own; file-operations-enforcement.sh
# handles reading stdin and turning the verdict into a hook response.

import re
import shlex
import sys

DANGEROUS = {"cp", "mv", "rm", "dd", "tee", "install"}

# Shell keywords that can legitimately start a sub-command chunk after a
# ; split but are never themselves the command being run -- `do`/`then`/
# `else`/`elif` all introduce a real command that follows them on the
# same line (`for x in a b; do rm -rf x; done`, `if t; then rm -rf x; fi`).
# Bug found by code review 2026-07-30: the first version of this rewrite
# checked sub[0] directly, so `do rm -rf x` classified as head="do" and
# was never inspected -- exactly the shape (`for ...; do <cmd>; done`)
# the commit that introduced this file claimed to fix. `{` also starts a
# brace-group command list the same way. Skipping past any number of
# these in sequence (not just one) covers `do { rm -rf x` too.
LEADING_KEYWORDS = {"do", "then", "else", "elif", "{"}

# Characters inside a double-quoted string that a backslash actually
# escapes in real bash (POSIX 2.2.3): $ ` " \ and newline. Anything else
# after a backslash inside double quotes is a literal backslash followed
# by that character -- the backslash does NOT get consumed. Single quotes
# never honor backslash at all (handled separately below, unconditionally
# in DOUBLE_QUOTE_ESCAPABLE is not consulted for quote == "'").
DOUBLE_QUOTE_ESCAPABLE = set('$`"\\\n')


def is_scratch(path):
    return path.startswith("/tmp/")


def looks_like_path(tok):
    if tok.startswith("-"):
        return False
    if "/" in tok:
        return True
    # bare filename with a dotted extension, no flag prefix
    return bool(re.search(r"\.[A-Za-z0-9]{1,8}$", tok)) or tok not in {"", "|", "&&", "||", ";", "&"}


def split_subcommands(cmd):
    # Quote-aware scan of the RAW command string, splitting on ;, &&, ||,
    # a lone &, | and bare newlines wherever they occur -- INCLUDING glued
    # directly onto a word with no surrounding whitespace (2026-07-30
    # bugfix: the very first version of this rewrite split shlex.split()
    # tokens looking for these as an exact, standalone token; shlex only
    # splits on whitespace, so an operator with no space before it stayed
    # glued to the preceding word and was never recognized as a boundary
    # at all -- confirmed blind to almost every real multi-command script
    # this hook exists to catch). Scanning the raw string ourselves,
    # quote-aware, catches the glued form and the spaced form identically,
    # and a bare newline is treated the same as `;` since that's how
    # multi-line heredoc scripts separate commands.
    #
    # A lone `&` (background job, not part of `&&`) is a boundary too
    # (2026-07-30, second bugfix round, code review): `echo done & rm -rf
    # x` previously kept `rm -rf x` glued onto the `echo` chunk as trailing
    # args, so it was never inspected as its own command.
    #
    # Known, accepted limitations, NOT fixed here:
    # - Content inside `$(...)` or `` `...` `` (command substitution) is
    #   scanned as plain top-level text, not recursively parsed -- an
    #   operator inside a substitution can produce a garbled fragment and
    #   a confusing block message, but the tested failure direction is
    #   "blocks on nonsense" (safe), not "silently allows." Real nesting-
    #   aware parsing is a much bigger change for a rare shape.
    # - A heredoc body (`<<'EOF' ... EOF`) is not recognized as inert data
    #   -- it gets split line-by-line like any other text, same as before.
    #   A body line whose very first bare word happens to exactly match a
    #   DANGEROUS verb (e.g. a doc line literally starting "install ...")
    #   will false-positive block. This is a real, expected-to-occur
    #   nuisance for prose-heavy heredocs (git commit message bodies,
    #   documentation), not just a theoretical corner case -- accepted
    #   because the alternative (real heredoc-delimiter-aware parsing) is
    #   a much larger, riskier change, and the failure direction here is
    #   still "blocks something safe" rather than "misses something
    #   dangerous."
    # - A bare `#` comment is not stripped, so operator-looking characters
    #   or a dangerous-verb word inside a trailing comment can trigger a
    #   spurious (safe-direction) block.
    subs = []
    buf = []
    quote = None
    i, n = 0, len(cmd)
    while i < n:
        ch = cmd[i]
        if quote:
            if quote == '"' and ch == "\\" and i + 1 < n and cmd[i + 1] in DOUBLE_QUOTE_ESCAPABLE:
                # Real bash: backslash escapes only these characters
                # inside double quotes, and does not toggle quote state.
                # Getting this wrong (treating every \" as closing the
                # quote) was bug #5 from the 2026-07-30 code review --
                # e.g. tee "a\"; rm -rf /x" is ONE quoted argument in real
                # bash, not a quote that closes right after \".
                buf.append(ch)
                buf.append(cmd[i + 1])
                i += 2
                continue
            buf.append(ch)
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch in ("'", '"'):
            quote = ch
            buf.append(ch)
            i += 1
            continue
        if ch == "\\" and i + 1 < n:
            buf.append(ch)
            buf.append(cmd[i + 1])
            i += 2
            continue
        if cmd[i:i + 2] in ("&&", "||"):
            subs.append("".join(buf))
            buf = []
            i += 2
            continue
        if ch in (";", "|", "\n", "&"):
            subs.append("".join(buf))
            buf = []
            i += 1
            continue
        buf.append(ch)
        i += 1
    subs.append("".join(buf))
    return [s for s in subs if s.strip()]


def classify(cmd):
    try:
        raw_subs = split_subcommands(cmd)
        subcommands = [shlex.split(s) for s in raw_subs]
    except ValueError:
        # Unbalanced quotes or similar -- can't safely classify, block
        # rather than silently let something unparseable slip through.
        return "BLOCK: could not parse the command to check its file targets"

    for sub in subcommands:
        while sub and sub[0] in LEADING_KEYWORDS:
            sub = sub[1:]
        if not sub:
            continue
        head = sub[0]
        if head == "git":
            continue  # git's own allowlist governs this, not this hook
        is_sed_i = head == "sed" and any(
            a == "-i" or a.startswith("-i") or a in ("--in-place",) for a in sub[1:]
        )
        if head not in DANGEROUS and not is_sed_i:
            continue
        args = sub[1:]
        if is_sed_i:
            # sed's own script argument ('s/a/b/', an -e value, ...)
            # routinely contains '/' and would otherwise misclassify as a
            # path. Skip the first non-flag argument (the script) before
            # collecting real file targets -- an -e/-f script is still a
            # flag argument here and correctly never skipped as a
            # "target".
            skipped_script = False
            args_for_targets = []
            for a in args:
                if not skipped_script and not a.startswith("-"):
                    skipped_script = True
                    continue
                args_for_targets.append(a)
            args = args_for_targets
        targets = [a for a in args if looks_like_path(a)]
        outside_scratch = [t for t in targets if not is_scratch(t)]
        if outside_scratch:
            return "BLOCK: '%s' touches a repo path outside /tmp (%s)" % (
                " ".join(sub), ", ".join(outside_scratch))

    return "OK"


if __name__ == "__main__":
    print(classify(sys.argv[1] if len(sys.argv) > 1 else ""))
