# /autoresearch — Autonomous Experiment Loop for Claude Code

> Inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch). Adapted for **any project type**.

Autonomous experiment loop that modifies a single file, runs experiments, and keeps improvements — forever.

## What it does

```
LOOP FOREVER:
  1. Analyze current state
  2. Generate improvement idea
  3. Modify target_file
  4. Run experiment (build/test/train)
  5. Parse metric
  6. Improved? → keep. Same/worse? → discard.
  7. Log to results.tsv + JSONL
  8. Repeat
```

## Supported Project Types

| Type | Detection | Target | Metric | Direction |
|------|-----------|--------|--------|-----------|
| **ML** | `train.py` + `prepare.py` | train.py | val_bpb | lower |
| **Web** | `package.json` | detected main file | bundle size (KB) | lower |
| **Flutter** | `pubspec.yaml` | lib/main.dart | APK size (MB) | lower |
| **Java/Kotlin** | `pom.xml` / `build.gradle` | detected main | build time | lower |
| **Custom** | `CLAUDE.md` config | user-defined | user-defined | user-defined |

## Usage

```bash
/autoresearch              # Start experiment loop (auto-detect project)
/autoresearch setup        # Initialize experiment environment only
/autoresearch results      # View results.tsv
```

## Custom Configuration

Add to your project's `CLAUDE.md`:

```markdown
## autoresearch 설정
- target_file: train.py
- run_command: uv run train.py
- metric_name: val_bpb
- metric_parse: grep "^val_bpb:" run.log | awk '{print $2}'
- metric_direction: lower_is_better
- time_budget: 300
- readonly_files: prepare.py
```

## Key Differences from karpathy/autoresearch

| Feature | karpathy/autoresearch | This (/autoresearch) |
|---------|----------------------|---------------------|
| **Scope** | ML training only | Any project type |
| **Detection** | Manual setup | Auto-detect from project files |
| **Configuration** | Hardcoded | CLAUDE.md-based |
| **Logging** | TSV only | **TSV + JSONL** (with delta, prev, memory_gb) |
| **Git** | Manual | Auto branch (`autoresearch/$TAG`) |
| **Hardware** | GPU required | None (Claude Code environment) |

## Logging

### results.tsv
```
commit	metric	value	status	description
a1b2c3d	val_bpb	0.997900	keep	baseline
b2c3d4e	val_bpb	0.993200	keep	increase LR to 0.04
c3d4e5f	val_bpb	1.005000	discard	switch to GeLU activation
```

### JSONL (`.claude/logs/autoresearch.jsonl`)
```jsonl
{"tool":"autoresearch","action":"experiment_done","status":"success","details":{"status":"keep","metric":"val_bpb","value":0.9932,"prev":0.9979,"delta":-0.0047,"commit":"b2c3d4e","description":"increase LR","memory_gb":44.2,"tag":"mar17"}}
```

### Query logs
```bash
# All experiments
cat .claude/logs/autoresearch.jsonl | jq .

# Keep only
grep experiment_done .claude/logs/autoresearch.jsonl | jq 'select(.details.status == "keep")'

# Metric trend
grep experiment_done .claude/logs/autoresearch.jsonl | jq -r '[.local_time[:19], .details.status, .details.value] | @tsv'
```

## Core Rules

- **NEVER STOP** — runs until manually stopped
- **Single file only** — only modifies `target_file`
- **Keep or discard** — improved → keep, same/worse → discard
- **Log everything** — every experiment recorded in results.tsv
- **Simpler wins** — same improvement with less code → keep
- **Deletion is best** — less code, same performance → keep

## Install as Claude Code Plugin

```bash
/plugin marketplace add https://github.com/jung-wan-kim/autoresearch-builder
/plugin install autoresearch-builder
/reload-plugins
```

## License

MIT
