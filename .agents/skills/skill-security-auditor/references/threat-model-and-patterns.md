# Threat Model & Scanning Patterns

Read this when deciding what to scan for: the attack-vector threat model, trust boundaries, the full regex pattern sets for code-execution and prompt-injection detection, and known evasion techniques.

## Threat Model

### Attack Vectors Against AI Skills

| Vector | How It Works | Risk Level |
|--------|-------------|------------|
| **Code execution in scripts** | Skill includes Python/Bash scripts with `eval()`, `os.system()`, or `subprocess` that execute arbitrary commands | CRITICAL |
| **Prompt injection in SKILL.md** | Markdown contains hidden instructions that override the AI assistant's behavior when the skill is loaded | CRITICAL |
| **Network exfiltration** | Scripts send local data (code, credentials, env vars) to external servers | CRITICAL |
| **Credential harvesting** | Scripts read SSH keys, AWS credentials, or API tokens from well-known paths | CRITICAL |
| **Dependency poisoning** | `requirements.txt` includes typosquatted or backdoored packages | HIGH |
| **File system escape** | Scripts write to `~/.bashrc`, `/etc/`, or other system locations | HIGH |
| **Obfuscated payloads** | Malicious code hidden via base64 encoding, hex strings, or `chr()` construction | HIGH |
| **Binary payloads** | Pre-compiled executables bypass code review | HIGH |
| **Symlink attacks** | Symbolic links redirect file operations to sensitive locations | MEDIUM |
| **Information disclosure** | Excessive logging or error output reveals system information | LOW |

### Trust Boundaries

```
TRUSTED ZONE:
  ├── Skill markdown files (SKILL.md, references/)
  │   └── Should contain ONLY documentation and templates
  ├── Configuration files (YAML, JSON, TOML)
  │   └── Should contain ONLY settings, no executable code
  └── Template files (assets/)
      └── Should contain ONLY user-facing templates

INSPECTION REQUIRED:
  ├── Python scripts (scripts/*.py)
  │   └── May contain legitimate automation — inspect each function
  ├── Shell scripts (scripts/*.sh)
  │   └── Check for pipes to external servers, eval, sudo
  └── JavaScript/TypeScript (scripts/*.js, *.ts)
      └── Check for eval, Function constructor, network calls

REJECT BY DEFAULT:
  ├── Binary files (.exe, .so, .dll, .pyc)
  ├── Hidden directories (.hidden/)
  ├── Environment files (.env, .env.local)
  └── Credential files (*.pem, *.key, *.p12)
```

## Scanning Patterns

### Code Execution Risks

```python
# Patterns to detect in .py, .sh, .js, .ts files

CRITICAL_PATTERNS = {
    "command_injection": [
        r"os\.system\(",
        r"os\.popen\(",
        r"subprocess\.call\(.*shell\s*=\s*True",
        r"subprocess\.Popen\(.*shell\s*=\s*True",
        r"`[^`]+`",  # backtick execution in shell
    ],
    "code_execution": [
        r"\beval\(",
        r"\bexec\(",
        r"\bcompile\(",
        r"__import__\(",
        r"importlib\.import_module\(",
        r"new\s+Function\(",  # JavaScript
    ],
    "obfuscation": [
        r"base64\.b64decode\(",
        r"codecs\.decode\(",
        r"bytes\.fromhex\(",
        r"chr\(\d+\)\s*\+\s*chr\(",  # chr() chains
        r"\\x[0-9a-f]{2}.*\\x[0-9a-f]{2}.*\\x[0-9a-f]{2}",  # hex strings
    ],
    "network_exfiltration": [
        r"requests\.post\(",
        r"requests\.put\(",
        r"urllib\.request\.urlopen\(",
        r"httpx\.(post|put)\(",
        r"aiohttp\.ClientSession\(",
        r"socket\.connect\(",
        r"fetch\(['\"]https?://",  # JavaScript
    ],
    "credential_harvesting": [
        r"~/.ssh",
        r"~/.aws",
        r"~/.config",
        r"~/.gnupg",
        r"os\.environ\[",  # reading env vars
        r"open\(.*\.pem",
        r"open\(.*\.key",
    ],
    "privilege_escalation": [
        r"\bsudo\b",
        r"chmod\s+777",
        r"chmod\s+\+s",
        r"crontab",
        r"setuid",
    ],
}

HIGH_PATTERNS = {
    "unsafe_deserialization": [
        r"pickle\.loads?\(",
        r"yaml\.load\([^)]*\)",  # without SafeLoader
        r"marshal\.loads?\(",
        r"shelve\.open\(",
    ],
    "file_system_abuse": [
        r"open\(.*/etc/",
        r"open\(.*~/.bashrc",
        r"open\(.*~/.profile",
        r"open\(.*~/.zshrc",
        r"os\.symlink\(",
        r"shutil\.(rmtree|move)\(",
    ],
}
```

### Prompt Injection Detection

```python
# Patterns to detect in .md files

PROMPT_INJECTION_PATTERNS = {
    "system_override": [
        r"ignore\s+(all\s+)?previous\s+instructions",
        r"ignore\s+(all\s+)?prior\s+instructions",
        r"disregard\s+(all\s+)?previous",
        r"you\s+are\s+now\s+(a|an)\s+",
        r"from\s+now\s+on\s+(you|your)\s+",
        r"new\s+system\s+prompt",
        r"override\s+system",
    ],
    "role_hijacking": [
        r"act\s+as\s+(root|admin|superuser)",
        r"pretend\s+you\s+(have\s+no|don't\s+have)\s+restrictions",
        r"you\s+have\s+no\s+limitations",
        r"unrestricted\s+mode",
        r"developer\s+mode\s+enabled",
        r"jailbreak",
    ],
    "safety_bypass": [
        r"skip\s+safety\s+checks",
        r"disable\s+content\s+filter",
        r"bypass\s+security",
        r"remove\s+(all\s+)?guardrails",
        r"no\s+restrictions\s+apply",
    ],
    "data_extraction": [
        r"send\s+(the\s+)?contents?\s+of",
        r"upload\s+file\s+to",
        r"POST\s+to\s+https?://",
        r"exfiltrate",
        r"transmit\s+data\s+to",
    ],
    "hidden_instructions": [
        r"\u200b",          # zero-width space
        r"\u200c",          # zero-width non-joiner
        r"\u200d",          # zero-width joiner
        r"\ufeff",          # byte order mark
        r"<!--\s*(?:system|instruction|command)",  # HTML comments with directives
    ],
}
```

## Known Evasion Techniques

Attackers may try to bypass detection. Be aware of:

| Technique | Example | Detection Difficulty |
|-----------|---------|---------------------|
| String concatenation | `e` + `v` + `a` + `l` | Medium — check for dynamic function construction |
| `getattr` dispatch | `getattr(os, 'sys' + 'tem')('cmd')` | Hard — requires control flow analysis |
| Import aliasing | `from os import system as helper` | Medium — track import aliases |
| Encoded payloads | `exec(base64.b64decode('...'))` | Easy — flag any base64 decode + exec |
| Time-delayed triggers | Executes only after specific date | Hard — requires dynamic analysis |
| Conditional activation | Triggers only on specific hostnames | Hard — requires dynamic analysis |
| Unicode homoglyphs | Using Cyrillic characters that look like Latin | Medium — normalize Unicode before scanning |
