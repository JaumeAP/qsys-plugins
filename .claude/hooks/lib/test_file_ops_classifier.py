#!/usr/bin/env python3
# Regression suite for file_ops_classifier.py. Added 2026-07-30 alongside
# extracting the classifier out of file-operations-enforcement.sh's
# heredoc, specifically because the first rewrite of this classifier
# shipped with two real false negatives despite a commit message claiming
# "verified against 16 cases" -- the verification was manual, ad hoc, and
# didn't actually cover the shapes that mattered. A code-reviewer
# subagent found both by executing constructed inputs instead of reading
# the diff. This file exists so that check is automatic and repeatable
# instead of depending on someone remembering to re-run it by hand.
#
# stdlib unittest only, no pytest dependency -- matches this bundle's
# other hook-adjacent tooling. Run directly:
#   python3 .claude/hooks/lib/test_file_ops_classifier.py
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from file_ops_classifier import classify, split_subcommands


class ClassifyBlocksRealFileOps(unittest.TestCase):
    def test_simple_cp(self):
        self.assertTrue(classify(
            "cp /home/user/qsys-plugins/CLAUDE.md /home/user/CPSeries/CLAUDE.md"
        ).startswith("BLOCK"))

    def test_spaced_semicolon(self):
        self.assertTrue(classify(
            "echo hi ; cp /home/user/a /home/user/b"
        ).startswith("BLOCK"))

    def test_glued_semicolon(self):
        # The original bug: shlex.split() never sees "hi;" as an operator
        # token, only as part of the word "hi;".
        self.assertTrue(classify(
            "echo hi; cp /home/user/a /home/user/b"
        ).startswith("BLOCK"))

    def test_multiline_for_loop_cp_on_its_own_line(self):
        cmd = (
            'for r in CPSeries Eines; do\n'
            '  d="/home/user/$r"\n'
            '  cp /home/user/qsys-plugins/.claude/skills/file-operations/SKILL.md '
            '"$d/.claude/skills/file-operations/SKILL.md"\n'
            'done'
        )
        self.assertTrue(classify(cmd).startswith("BLOCK"))

    def test_multiline_for_loop_with_rm(self):
        cmd = (
            'for r in qsys-plugins CPSeries Eines; do\n'
            '  rm -f /home/user/$r/stale.txt\n'
            'done'
        )
        self.assertTrue(classify(cmd).startswith("BLOCK"))

    def test_scratch_to_repo_still_blocked(self):
        self.assertTrue(classify(
            "cp /tmp/claude-0/foo /home/user/qsys-plugins/CLAUDE.md"
        ).startswith("BLOCK"))

    def test_piped_tee(self):
        self.assertTrue(classify(
            "echo x | tee /home/user/qsys-plugins/CLAUDE.md"
        ).startswith("BLOCK"))

    def test_piped_tee_glued(self):
        self.assertTrue(classify(
            "echo x|tee /home/user/qsys-plugins/CLAUDE.md"
        ).startswith("BLOCK"))

    def test_sed_dash_i_real_repo_file(self):
        self.assertTrue(classify(
            "sed -i 's/a/b/' /home/user/qsys-plugins/CLAUDE.md"
        ).startswith("BLOCK"))

    # --- Found by code review 2026-07-30, both were silent false
    # negatives in the first version of the quote-aware rewrite ---

    def test_single_line_for_do_done(self):
        self.assertTrue(classify(
            'for r in CPSeries Eines; do rm -rf "/home/user/$r/build"; done'
        ).startswith("BLOCK"), "for...; do <danger>; done on one line must block")

    def test_single_line_if_then_fi(self):
        self.assertTrue(classify(
            "if true; then rm -rf /home/user/qsys-plugins/CLAUDE.md; fi"
        ).startswith("BLOCK"), "if...; then <danger>; fi on one line must block")

    def test_single_line_while_do_done(self):
        self.assertTrue(classify(
            "while true; do cp a.txt /home/user/qsys-plugins/CLAUDE.md; break; done"
        ).startswith("BLOCK"), "while...; do <danger>; done on one line must block")

    def test_lone_ampersand_backgrounding(self):
        self.assertTrue(classify(
            "echo done & rm -rf /home/user/qsys-plugins/CLAUDE.md"
        ).startswith("BLOCK"), "a backgrounded dangerous command must still be seen")


class ClassifyAllowsSafeCommands(unittest.TestCase):
    def test_git_mv_exempt(self):
        self.assertEqual(classify("git mv old.txt new.txt"), "OK")

    def test_git_rm_exempt(self):
        self.assertEqual(classify("git rm -f old.txt"), "OK")

    def test_scratch_cp_exempt(self):
        self.assertEqual(classify("cp /tmp/claude-0/foo /tmp/claude-0/bar"), "OK")

    def test_sed_no_dash_i_is_read_only(self):
        self.assertEqual(
            classify("sed -n '1,5p' /home/user/qsys-plugins/CLAUDE.md"), "OK"
        )

    def test_plain_read_only_commands(self):
        self.assertEqual(
            classify("ls -la /home/user/qsys-plugins && grep foo /home/user/qsys-plugins/CLAUDE.md"),
            "OK",
        )

    def test_heredoc_with_semicolons_in_quoted_script_not_real_ops(self):
        cmd = "python3 - <<'PYEOF'\nprint('a; b; c')\nPYEOF"
        self.assertEqual(classify(cmd), "OK")

    def test_multiline_git_commit_heredoc_no_dangerous_verbs(self):
        cmd = (
            "git commit -q -F - <<'EOF' && git log --oneline -1\n"
            "Some message\n"
            "with several; lines\n"
            "EOF"
        )
        self.assertEqual(classify(cmd), "OK")

    def test_var_assignment_with_glued_semicolon_is_not_a_verb(self):
        self.assertEqual(classify("d=/home/user/CPSeries; echo $d"), "OK")

    # --- Found and fixed in a second code-review pass, 2026-07-30 ---

    def test_fd_duplication_redirect_not_treated_as_backgrounding(self):
        # 2>&1 is a file-descriptor duplication, not `&` backgrounding --
        # found while fixing the lone-& case above: this exact shape
        # (`cmd 2>&1 | tail`) is used constantly in this repo's own
        # sessions and was getting mis-split at the &.
        self.assertEqual(
            classify("./Developer/tests/run.sh 2>&1 | tail -3"), "OK"
        )

    def test_stdout_stderr_dup_before_dangerous_verb_still_blocks(self):
        # Same redirect shape, but this time piped into something that
        # DOES touch a real repo path -- must still block.
        self.assertTrue(classify(
            "cat build.log 2>&1 | tee /home/user/qsys-plugins/CLAUDE.md"
        ).startswith("BLOCK"))

    def test_heredoc_body_prose_no_longer_false_positives(self):
        # A heredoc body line starting with a bare word that happens to
        # match a DANGEROUS verb ("install ...") used to trigger a false
        # block -- heredoc bodies are data, not commands.
        cmd = "cat <<EOF\ninstall the required packages first\nEOF"
        self.assertEqual(classify(cmd), "OK")

    def test_heredoc_with_trailing_command_on_opening_line(self):
        # The exact pattern used throughout this session's own commits:
        # a heredoc redirect followed by `&& <command>` on the SAME line
        # as the opening `<<'EOF'`. Must still split on the && correctly,
        # and the heredoc body itself must still be skipped as data.
        cmd = (
            "git commit -q -F - <<'EOF' && git log --oneline -1\n"
            "Some message\n"
            "install notes here\n"
            "EOF"
        )
        self.assertEqual(classify(cmd), "OK")

    def test_real_danger_before_a_heredoc_still_blocks(self):
        cmd = (
            "cp /home/user/qsys-plugins/CLAUDE.md /home/user/CPSeries/CLAUDE.md\n"
            "cat <<EOF\nbody\nEOF"
        )
        self.assertTrue(classify(cmd).startswith("BLOCK"))

    def test_command_substitution_no_longer_fragments_into_garbage(self):
        # $(...) is now scanned as an opaque span rather than split on at
        # the top level -- this no longer produces a nonsense fragment
        # like "cp $(echo a" as its own mis-parsed sub-command. (Full
        # recursive parsing of the substitution's own contents is a
        # documented, separate residual limitation -- not what this test
        # checks.)
        subs = split_subcommands("cp $(echo a; echo b) /tmp/dest")
        self.assertEqual(len(subs), 1, subs)

    def test_trailing_comment_with_inert_text_does_not_block(self):
        self.assertEqual(
            classify("echo hi # ; rm -rf /home/user/qsys-plugins/CLAUDE.md"), "OK"
        )

    def test_comment_does_not_swallow_a_real_command_on_the_next_line(self):
        self.assertTrue(classify(
            "echo hi # comment\ncp /home/user/qsys-plugins/CLAUDE.md /home/user/CPSeries/CLAUDE.md"
        ).startswith("BLOCK"))

    def test_hash_inside_a_word_is_not_a_comment(self):
        self.assertEqual(classify("echo foo#bar"), "OK")


class SplitSubcommandsQuoteHandling(unittest.TestCase):
    def test_backslash_escaped_quote_inside_double_quotes_does_not_split(self):
        # Bug #5 from the 2026-07-30 code review: a literal backslash-
        # escaped double-quote inside a double-quoted argument used to
        # close the quote early, fragmenting one legitimate argument into
        # pieces at the semicolon that was actually still inside the
        # string. In real bash, tee "a\"; rm -rf /x" passes ONE argument
        # to tee -- the escaped quote does not end the string.
        subs = split_subcommands('tee "a\\"; rm -rf /important"')
        self.assertEqual(len(subs), 1, subs)

    def test_single_quotes_never_honor_backslash(self):
        # Contrast case: inside single quotes, backslash is never special
        # in real bash either -- this was already correct before the
        # double-quote fix, kept here so a future change can't silently
        # start treating single and double quotes the same.
        subs = split_subcommands("echo 'a\\'; rm -rf /important'")
        # The first ' opens a quote; \\ is a literal backslash character,
        # not an escape, so the very next ' closes the quote -- meaning
        # the ; after it IS a real boundary here, unlike the double-quote
        # case above. Two chunks expected.
        self.assertEqual(len(subs), 2, subs)


if __name__ == "__main__":
    unittest.main()
