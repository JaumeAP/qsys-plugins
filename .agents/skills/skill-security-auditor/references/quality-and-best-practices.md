# Quality, Limitations & Best Practices

Read this before shipping or relying on an audit: the static-analysis limitations, common pitfalls, best practices, troubleshooting matrix, and success criteria.

## Limitations

- **Static analysis only** — does not execute code; cannot detect runtime-only behavior
- **Pattern-based detection** — sufficiently creative obfuscation may bypass detection
- **No live CVE database** — dependency checks use local patterns, not real-time vulnerability feeds
- **Cannot detect logic bombs** — time-delayed or conditional payloads require dynamic analysis
- **Limited to known patterns** — novel attack techniques may not be covered

**When in doubt after an audit, do not install.** Ask the skill author for clarification on any flagged patterns.

## Common Pitfalls

- **Trusting skills from "official" sources without auditing** — supply chain attacks target popular packages
- **Skipping audit for "small" skills** — a single `eval()` in a 10-line script is enough
- **Auditing only code, not markdown** — prompt injection in SKILL.md is a real attack vector
- **Ignoring INFO findings** — they accumulate and indicate poor security hygiene
- **No re-audit after skill updates** — each version needs independent verification

## Best Practices

1. **Audit before install, always** — treat every skill as untrusted until verified
2. **Use strict mode in CI** — any HIGH finding blocks the merge
3. **Pin all dependencies** — unpinned versions are a supply chain risk
4. **Verify package names** — typosquatting is common and effective
5. **Check file boundaries** — skills should never access paths outside their directory
6. **Re-audit on updates** — each new version may introduce new risks
7. **Maintain an approved skill list** — pre-audited skills that the team trusts
8. **Report suspicious skills** — notify the skill repository maintainer and community

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| False positive on `subprocess.run()` with list arguments | Pattern matches any `subprocess` usage regardless of shell parameter | Verify the call uses a list (not a string) and `shell=True` is absent; mark as INFO, not CRITICAL |
| Prompt injection flagged in legitimate SKILL.md documentation | Phrases like "ignore previous" appear in educational or example text | Wrap examples in fenced code blocks; the scanner should skip content inside triple-backtick blocks |
| Audit reports zero findings on a skill with known issues | Skill uses an unsupported language or evasion technique not in the pattern set | Supplement with the Manual Audit Checklist and inspect files line-by-line for the known issue |
| Large binary file triggers FAIL but the file is a required dataset | Any binary over 1 MB defaults to HIGH severity | Verify the file contents independently (e.g., `file` command, hex dump) and document an explicit exception in the audit report |
| Dependency typosquatting check produces false negatives | Levenshtein distance threshold is too lenient for short package names | Cross-reference every dependency against the official PyPI or npm registry manually before approving |
| CI pipeline audit step times out on monorepo PRs | Scanner processes every changed skill sequentially | Limit the scan to only the skills modified in the PR using the `git diff` path filter shown in the CI/CD section |
| Audit verdict is WARN but team policy requires PASS | Default mode allows HIGH findings to produce WARN instead of FAIL | Enable `--strict` mode so any HIGH finding escalates the verdict to FAIL |

## Success Criteria

- **Zero CRITICAL findings on install**: Every skill deployed to production passes the audit with zero CRITICAL-severity findings.
- **Audit coverage >= 100% of new skills**: No skill is installed or merged without a completed security audit report on file.
- **False positive rate < 15%**: Fewer than 15% of flagged findings are confirmed false positives after manual review.
- **Mean time to audit < 5 minutes per skill**: A standard skill package (under 20 files) completes the full scan in under 5 minutes.
- **Remediation turnaround < 24 hours**: CRITICAL and HIGH findings are resolved or explicitly risk-accepted within one business day.
- **CI gate adoption = 100% of skill repositories**: Every repository that hosts skills runs the audit workflow on every pull request.
- **Re-audit compliance >= 95%**: At least 95% of skills are re-audited within one release cycle after any version update.
