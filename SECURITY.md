# Secret Scanning

This repository uses a local `pre-push` hook to run `gitleaks` before code is pushed.

## One-time setup

1. Install gitleaks:

```bash
brew install gitleaks
```

2. Enable repo hooks:

```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-push
```

## What is scanned

- The hook scans the commit range being pushed (not the entire history).
- If leaks are found, push is blocked.

## Manual scan

```bash
gitleaks git --no-banner --redact --log-level warn
```

## False positives

If a finding is a false positive, allowlist it with:

- `.gitleaks.toml` (rule-based allowlist), or
- `.gitleaksignore` (fingerprint-based ignore list).
