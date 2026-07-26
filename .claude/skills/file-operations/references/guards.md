# Write Guards

All guards are opt-in (disabled unless the matching env var is set),
apply to the same `_GUARDED_WRITERS` set, and compose: a write must
pass every enabled guard. Order of application in `fileops.py` (each
wraps whatever the previous guard already produced):

1. Allowlist (`FILEOPS_ALLOWED_ROOTS`)
2. Destructive-op confirm (`secure_delete` only, always on)
3. Blocklist (`FILEOPS_BLOCKED_PATHS`)
4. Protected-root confirm (`FILEOPS_PROTECTED_ROOTS`)
5. Operation logging (`FILEOPS_LOG_OPS=1`)

`move_file` is registered into `_GUARDED_WRITERS` and wrapped by the
allowlist guard right after its own definition, but since the
blocklist/protected/logging guard loops already ran earlier in file
order, `move_file` does **not** get those three unless the module is
reloaded after import. This mirrors the original skill's documented
behavior; if you need `move_file` covered by all guards, move its
definition above the guard loops, or re-run the loops after defining
it.

## Allowlist -- `FILEOPS_ALLOWED_ROOTS`

`os.pathsep`-separated directory roots. A write whose destination
resolves (via `os.path.realpath`) outside every root raises
`PermissionError`. Empty/unset = no restriction (default, preserves
existing behavior and keeps the self-tests green with no env
configured). Uses `os.path.commonpath`, not string-prefix matching, so
`/data` does not authorize `/data-evil`.

## Blocklist -- `FILEOPS_BLOCKED_PATHS`

Same shape and boundary logic as the allowlist, inverted: writes under
a blocked root raise `PermissionError`. Applied after the allowlist,
so a write must be inside allowed roots (if set) **and** outside
blocked roots (if set).

## Protected-root confirm -- `FILEOPS_PROTECTED_ROOTS`

Writes under a protected root require `confirm=True`; without it,
raises `PermissionError` before the write happens. `confirm` is
forwarded to the wrapped function when it accepts the parameter (e.g.
`secure_delete`), swallowed otherwise via a `TypeError` fallback, so
functions without a `confirm` parameter are unaffected.

## Destructive-op confirm (always on)

`secure_delete` requires `confirm=True` unconditionally, independent
of any env var -- it is the one operation that is irreversible by
construction.

## Operation logging -- `FILEOPS_LOG_OPS=1` / `FILEOPS_LOG_PATH`

Logs only `op` (function name) and `path` (destination) via
`log_operation` -- never file content, so the log line has nothing to
redact. Fires only on success: a write blocked by an earlier guard
raises before this wrapper runs, so blocked attempts are never logged
as operations.

## `str_replace` misuse guards (not env-gated, always available)

- `guard_str_replace` -- call it yourself around a pair of
  `str_replace`-style edits to catch a delete-then-reinsert move.
- `verify_targeted_edit` -- call it after an edit to prove the change
  didn't touch anything outside the intended span.
- `ensure_writable_copy` -- call before editing a file that might be
  read-only or outside your working directory.

These three are plain functions, not writer-wrapping guards, because
`str_replace`/`view`/editor tools are not part of `fileops.py` itself.
