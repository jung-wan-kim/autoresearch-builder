# /autoresearch — Claude Code용 자율 실험 루프

[English README](./README.md)

> [karpathy/autoresearch](https://github.com/karpathy/autoresearch) (43.7k stars)에서 영감을 받아, **모든 프로젝트 타입**에 적용할 수 있도록 확장했습니다.

단일 파일을 수정하고, 실험을 돌리고, 메트릭이 개선되면 유지(keep), 아니면 폐기(discard). 사용자가 멈출 때까지 무한 반복합니다.

## 동작 방식

```
무한 반복:
  1. 현재 프로젝트 상태 분석
  2. 개선 아이디어 생성
  3. target_file 수정
  4. 실험 실행 (빌드 / 테스트 / 학습)
  5. 출력에서 메트릭 추출
  6. 개선됨? → keep. 동일/악화? → discard (git reset)
  7. results.tsv + JSONL에 기록
  8. 다음 아이디어 → 반복
```

## 지원 프로젝트 타입

프로젝트 파일을 자동 감지합니다. 수동 설정이 필요 없습니다.

| 타입 | 감지 조건 | 기본 타겟 | 기본 메트릭 | 방향 |
|------|----------|----------|-----------|------|
| **ML** | `train.py` + `prepare.py` | `train.py` | val_bpb | 낮을수록 좋음 |
| **Web (Node.js)** | `package.json` | 자동 감지 | 번들 크기 (KB) | 낮을수록 좋음 |
| **Flutter** | `pubspec.yaml` | `lib/main.dart` | APK 크기 (MB) | 낮을수록 좋음 |
| **Java/Kotlin** | `pom.xml` / `build.gradle` | 자동 감지 | 빌드 시간 (초) | 낮을수록 좋음 |
| **커스텀** | `CLAUDE.md` 설정 | 사용자 정의 | 사용자 정의 | 사용자 정의 |

## 사용법

```bash
/autoresearch              # 자율 실험 루프 시작
/autoresearch setup        # 환경 초기화만 (브랜치 생성, results.tsv 초기화)
/autoresearch results      # 실험 결과 조회
/autoresearch train.py     # 특정 파일을 타겟으로 지정
```

## 커스텀 설정

프로젝트 `CLAUDE.md`에 `autoresearch` 섹션을 추가하면 기본값을 덮어씁니다:

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

| 설정 | 설명 | 기본값 |
|-----|------|-------|
| `target_file` | 수정할 단일 파일 | 자동 감지 |
| `run_command` | 실험 실행 명령 | 프로젝트 타입 기반 |
| `metric_name` | 추적할 메트릭 이름 | 프로젝트 타입 기반 |
| `metric_parse` | 메트릭 값 추출 셸 명령 | 프로젝트 타입 기반 |
| `metric_direction` | `lower_is_better` 또는 `higher_is_better` | `lower_is_better` |
| `time_budget` | 실험당 최대 시간 (초) | `300` |
| `readonly_files` | 수정 금지 파일 (쉼표 구분) | 없음 |

## karpathy/autoresearch와 비교

| | karpathy/autoresearch | /autoresearch (이것) |
|---|---|---|
| **범위** | ML 모델 학습 전용 | 모든 프로젝트 타입 (ML, Web, Flutter, Java, 커스텀) |
| **설정** | 수동 Python 환경 | 프로젝트 파일에서 자동 감지 |
| **구성** | 소스 코드에 하드코딩 | CLAUDE.md 기반, 완전 커스터마이즈 가능 |
| **로깅** | TSV만 | TSV + JSONL (prev, delta, memory_gb, timestamp 포함) |
| **Git 통합** | 수동 | `autoresearch/$TAG` 브랜치 자동 생성 |
| **하드웨어** | NVIDIA GPU 필수 | 하드웨어 불필요 (Claude Code 환경에서 실행) |
| **메트릭 타입** | 고정 (val_bpb) | stdout/log에서 파싱 가능한 모든 메트릭 |

[상세 비교 분석](https://claude-code-site-sable.vercel.app/autoresearch-comparison.html)에서 전체 비교를 확인하세요.

## 로깅

모든 실험은 두 가지 형식으로 기록됩니다:

### results.tsv (사람이 읽기 편함)
```
commit    metric     value      status    description
a1b2c3d   val_bpb    0.997900   keep      baseline
b2c3d4e   val_bpb    0.993200   keep      LR을 0.04로 증가
c3d4e5f   val_bpb    1.005000   discard   GeLU 활성화 함수로 전환
d4e5f6g   val_bpb    0.000000   crash     모델 너비 2배 (OOM)
```

### JSONL (프로그래밍용)
`.claude/logs/autoresearch.jsonl`에 저장. 추가 필드: `prev`, `delta`, `memory_gb`, `tag`, `timestamp`.

### 로그 조회
```bash
# 최근 10개 실험
grep experiment_done .claude/logs/autoresearch.jsonl | tail -10 | jq .

# 성공한 개선만
jq 'select(.details.status == "keep")' .claude/logs/autoresearch.jsonl

# 메트릭 추이 (TSV 출력)
grep experiment_done .claude/logs/autoresearch.jsonl | \
  jq -r '[.local_time[:19], .details.status, .details.value] | @tsv'
```

## 핵심 규칙

1. **절대 멈추지 않는다** — 수동으로 중단할 때까지 무한 반복
2. **단일 파일만 수정** — `target_file` 외 모든 파일은 읽기 전용
3. **유지 또는 폐기** — 메트릭 개선 → keep. 동일/악화 → `git reset --hard HEAD~1`
4. **모든 것을 기록** — 크래시를 포함한 모든 실험을 기록
5. **단순한 것이 승리** — 같은 메트릭 개선이면 코드가 적은 쪽이 승리
6. **삭제가 최고** — 코드를 줄이면서 성능이 유지되면 최상의 결과

## 설치

### Claude Code 플러그인으로 설치
```bash
/plugin marketplace add https://github.com/jung-wan-kim/autoresearch-builder
/plugin install autoresearch-builder
/reload-plugins
```

### 수동 설치 (커맨드 파일 복사)
```bash
cp autoresearch.md ~/.claude/commands/autoresearch.md
```

## 파일 구성

| 파일 | 설명 |
|------|------|
| `autoresearch.md` | 슬래시 커맨드 정의 |
| `autoresearch-dashboard.sh` | 실험 결과 터미널 대시보드 |

## 라이선스

MIT
