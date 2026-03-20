# /autoresearch — Autonomous Experiment Loop for Claude Code

[한글 README](./README-KR.md)

> Inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch) (43.7k stars). Adapted for **any project type** — not just ML.

An autonomous experiment loop that modifies a single file, runs experiments, and keeps improvements. It never stops until you tell it to.

## How It Works

```
LOOP FOREVER:
  1. Analyze current project state
  2. Generate an improvement idea
  3. Modify the target file
  4. Run the experiment (build / test / train)
  5. Parse the metric from output
  6. Improved? → keep. Same or worse? → discard (git reset).
  7. Log to results.tsv + JSONL
  8. Next idea → repeat
```

## Supported Project Types

Auto-detected from project files — no manual configuration needed.

| Type | Detection | Default Target | Default Metric | Direction |
|------|-----------|---------------|----------------|-----------|
| **ML** | `train.py` + `prepare.py` | `train.py` | val_bpb | lower is better |
| **Web (Node.js)** | `package.json` | auto-detected main file | bundle size (KB) | lower is better |
| **Flutter** | `pubspec.yaml` | `lib/main.dart` | APK size (MB) | lower is better |
| **Java/Kotlin** | `pom.xml` / `build.gradle` | auto-detected main | build time (s) | lower is better |
| **Custom** | `CLAUDE.md` autoresearch config | user-defined | user-defined | user-defined |

## Usage

```bash
/autoresearch              # Start autonomous experiment loop
/autoresearch setup        # Initialize environment only (create branch, results.tsv)
/autoresearch results      # View experiment results
/autoresearch train.py     # Use specific file as target
```

## Custom Configuration

Override defaults by adding an `autoresearch` section to your project's `CLAUDE.md`:

```markdown
## autoresearch
- target_file: src/model.py
- run_command: python train.py --epochs 5
- metric_name: accuracy
- metric_parse: grep "accuracy:" run.log | tail -1 | awk '{print $2}'
- metric_direction: higher_is_better
- time_budget: 600
- readonly_files: data/dataset.py, config.yaml
```

| Setting | Description | Default |
|---------|-------------|---------|
| `target_file` | The single file to modify | Auto-detected |
| `run_command` | Command to run each experiment | Based on project type |
| `metric_name` | Name of the metric to track | Based on project type |
| `metric_parse` | Shell command to extract metric value | Based on project type |
| `metric_direction` | `lower_is_better` or `higher_is_better` | `lower_is_better` |
| `time_budget` | Max seconds per experiment | `300` |
| `readonly_files` | Comma-separated files that must not be modified | None |

## How It Compares

| | karpathy/autoresearch | /autoresearch (this) |
|---|---|---|
| **Scope** | ML model training only | Any project type (ML, Web, Flutter, Java, custom) |
| **Setup** | Manual Python environment | Auto-detect from project files |
| **Configuration** | Hardcoded in source | CLAUDE.md-based, fully customizable |
| **Logging** | TSV only | TSV + JSONL (includes prev, delta, memory_gb, timestamp) |
| **Git integration** | Manual | Auto-creates `autoresearch/$TAG` branch |
| **Hardware** | NVIDIA GPU required | No hardware requirements (runs in Claude Code) |
| **Metric type** | Fixed (val_bpb) | Any metric you can parse from stdout/log |

See the [full comparison](https://claude-code-site-sable.vercel.app/autoresearch-comparison.html) for a detailed analysis.

## Logging

Every experiment is recorded in two formats:

### results.tsv (human-readable)
```
commit    metric     value      status    description
a1b2c3d   val_bpb    0.997900   keep      baseline
b2c3d4e   val_bpb    0.993200   keep      increase LR to 0.04
c3d4e5f   val_bpb    1.005000   discard   switch to GeLU activation
d4e5f6g   val_bpb    0.000000   crash     double model width (OOM)
```

### JSONL (machine-readable)
Stored at `.claude/logs/autoresearch.jsonl` with additional fields: `prev`, `delta`, `memory_gb`, `tag`, `timestamp`.

### Querying Logs
```bash
# Recent 10 experiments
grep experiment_done .claude/logs/autoresearch.jsonl | tail -10 | jq .

# Successful improvements only
jq 'select(.details.status == "keep")' .claude/logs/autoresearch.jsonl

# Metric trend (TSV output)
grep experiment_done .claude/logs/autoresearch.jsonl | \
  jq -r '[.local_time[:19], .details.status, .details.value] | @tsv'
```

## Core Rules

1. **NEVER STOP** — Runs until manually interrupted
2. **Single file only** — Only modifies `target_file`; all other files are read-only
3. **Keep or discard** — Improved metric → keep. Same or worse → `git reset --hard HEAD~1`
4. **Log everything** — Every experiment is recorded, including crashes
5. **Simpler wins** — Same metric improvement with less code → keep
6. **Deletion is best** — Removing code while maintaining performance is the ideal outcome

## Install

### As a Claude Code Plugin
```bash
/plugin marketplace add https://github.com/jung-wan-kim/autoresearch-builder
/plugin install autoresearch-builder
/reload-plugins
```

### Manual (copy the command file)
```bash
cp autoresearch.md ~/.claude/commands/autoresearch.md
```

## Files

| File | Description |
|------|-------------|
| `autoresearch.md` | The slash command definition |
| `autoresearch-dashboard.sh` | Terminal dashboard for viewing experiment results |

## License

MIT
