---
name: autoresearch
description: autoresearch 스타일 자율 실험 루프 실행. 단일 메트릭 기반 keep/discard 자동 판정.
---

# /autoresearch - 자율 실험 루프

karpathy/autoresearch 방식의 자율 실험 루프를 현재 프로젝트에서 실행합니다.
단일 파일을 수정하고, 실험을 돌리고, 메트릭이 개선되면 keep, 아니면 discard. 무한 반복.

## 사용법

```
/autoresearch                    # 현재 프로젝트에서 실험 시작
/autoresearch setup              # 실험 환경 초기화만
/autoresearch results            # results.tsv 결과 조회
```

## 실행 순서

### 1. 실험 대상 감지

현재 프로젝트 구조를 분석하여 실험 대상을 자동 감지:

```
프로젝트 타입 감지:
- train.py + prepare.py 존재 → ML 학습 실험 (autoresearch 원본 모드)
- package.json 존재 → 웹 성능 최적화 (Lighthouse score, bundle size)
- pubspec.yaml 존재 → Flutter 성능 최적화 (빌드 시간, 앱 크기)
- pom.xml / build.gradle 존재 → Java/Kotlin 빌드 최적화
- CLAUDE.md에 "autoresearch" 설정 존재 → 커스텀 실험
```

`$ARGUMENTS`가 "setup"이면 Step 2까지만 실행하고 멈춤.
`$ARGUMENTS`가 "results"이면 results.tsv만 출력.
`$ARGUMENTS`가 있고 위 키워드가 아니면 실험 대상 파일로 간주.

### 2. 실험 환경 설정

```bash
LOG="~/.claude/scripts/action-log.sh"

# 날짜 기반 태그
TAG=$(date +%b%d | tr '[:upper:]' '[:lower:]')  # e.g. mar17

$LOG autoresearch session_start in_progress '{"tag":"'"$TAG"'","trigger":"manual"}'

# 브랜치 생성
git checkout -b autoresearch/$TAG

# results.tsv 초기화
echo -e "commit\tmetric\tvalue\tstatus\tdescription" > results.tsv

# 프로젝트 컨텍스트 읽기
# - CLAUDE.md (빌드/테스트 명령어)
# - 실험 대상 파일
# - 메트릭 수집 방법
```

### 3. 실험 설정 파싱

프로젝트 `CLAUDE.md`에 아래 설정이 있으면 사용:

```markdown
## autoresearch 설정
- target_file: train.py              # 수정할 파일 (1개만)
- run_command: uv run train.py       # 실험 실행 명령
- metric_name: val_bpb               # 추적할 메트릭 이름
- metric_parse: grep "^val_bpb:" run.log | awk '{print $2}'  # 메트릭 파싱
- metric_direction: lower_is_better  # lower_is_better | higher_is_better
- time_budget: 300                   # 실험 시간 제한 (초)
- readonly_files: prepare.py         # 수정 금지 파일
```

없으면 프로젝트 타입에 따라 기본값 자동 설정:

| 타입 | target_file | run_command | metric | direction |
|------|------------|-------------|--------|-----------|
| ML | train.py | `uv run train.py` | val_bpb | lower |
| Web | 감지된 주요 파일 | `npm run build` | bundle size (KB) | lower |
| Flutter | lib/main.dart | `flutter build apk --release` | APK size (MB) | lower |
| 커스텀 | CLAUDE.md 참조 | CLAUDE.md 참조 | CLAUDE.md 참조 | CLAUDE.md 참조 |

### 4. 실험 루프 (NEVER STOP)

```
LOG="~/.claude/scripts/action-log.sh"

LOOP FOREVER:
  1. 현재 git 상태 확인
  2. 아이디어를 구상하여 target_file 수정
  3. git commit -m "experiment: {설명}"
     $LOG autoresearch experiment_start in_progress '{"idea":"{설명}","commit":"'$(git rev-parse --short HEAD)'"}'
  4. 실험 실행: $run_command > run.log 2>&1
  5. 메트릭 파싱: $metric_parse
  6. 결과 판정 + results.tsv + JSONL 동시 기록:
     - 개선됨 → keep (브랜치 유지)
       $LOG autoresearch experiment_done success '{"status":"keep","metric":"{name}","value":{value},"prev":{prev},"delta":{delta},"commit":"{hash}","description":"{설명}","memory_gb":{mem},"tag":"{TAG}"}'
     - 동일/악화 → discard (git reset --hard HEAD~1)
       $LOG autoresearch experiment_done success '{"status":"discard","metric":"{name}","value":{value},"prev":{prev},"delta":{delta},"commit":"{hash}","description":"{설명}","memory_gb":{mem},"tag":"{TAG}"}'
     - 크래시 → crash 기록, 복원, 다음 아이디어
       $LOG autoresearch experiment_done fail '{"status":"crash","metric":"{name}","value":0,"commit":"{hash}","description":"{설명}","error":"{에러 요약}","tag":"{TAG}"}'
     - results.tsv에도 동일 내용 append
  7. 다음 아이디어로 반복
```

**크래시 처리:**
- 간단한 오류 (타이포, import 누락) → 수정 후 재실행
- 근본적 문제 (OOM, 아키텍처 오류) → skip, results.tsv에 crash 기록

**타임아웃:**
- 실험이 time_budget × 2를 초과하면 kill → crash 처리

### 5. 결과 기록 (TSV + JSONL 동시)

**results.tsv** (탭 구분, 사람이 읽기 편함):

```
commit	metric	value	status	description
a1b2c3d	val_bpb	0.997900	keep	baseline
b2c3d4e	val_bpb	0.993200	keep	increase LR to 0.04
c3d4e5f	val_bpb	1.005000	discard	switch to GeLU activation
d4e5f6g	val_bpb	0.000000	crash	double model width (OOM)
```

**JSONL** (`.claude/logs/autoresearch.jsonl`, 프로그래밍 가능):

```jsonl
{"tool":"autoresearch","action":"experiment_done","status":"success","details":{"status":"keep","metric":"val_bpb","value":0.9979,"prev":null,"delta":null,"commit":"a1b2c3d","description":"baseline","memory_gb":44.0,"tag":"mar17"},"local_time":"2026-03-17T14:30:00"}
{"tool":"autoresearch","action":"experiment_done","status":"success","details":{"status":"keep","metric":"val_bpb","value":0.9932,"prev":0.9979,"delta":-0.0047,"commit":"b2c3d4e","description":"increase LR to 0.04","memory_gb":44.2,"tag":"mar17"},"local_time":"2026-03-17T14:35:00"}
{"tool":"autoresearch","action":"experiment_done","status":"success","details":{"status":"discard","metric":"val_bpb","value":1.005,"prev":0.9932,"delta":0.0118,"commit":"c3d4e5f","description":"switch to GeLU","memory_gb":44.0,"tag":"mar17"},"local_time":"2026-03-17T14:40:00"}
{"tool":"autoresearch","action":"experiment_done","status":"fail","details":{"status":"crash","metric":"val_bpb","value":0,"commit":"d4e5f6g","description":"double model width","error":"OOM","tag":"mar17"},"local_time":"2026-03-17T14:45:00"}
```

JSONL은 TSV에 없는 추가 정보 포함: `prev`(이전 값), `delta`(변화량), `memory_gb`, `tag`, `timestamp`

## 로그 조회

```bash
# 전체 로그
cat .claude/logs/autoresearch.jsonl | jq .

# 최근 실험 10개
grep experiment_done .claude/logs/autoresearch.jsonl | tail -10 | jq .

# keep만 필터
grep experiment_done .claude/logs/autoresearch.jsonl | jq 'select(.details.status == "keep")'

# crash만 필터
grep experiment_done .claude/logs/autoresearch.jsonl | jq 'select(.details.status == "crash")'

# 메트릭 추이
grep experiment_done .claude/logs/autoresearch.jsonl | jq -r '[.local_time[:19], .details.status, .details.value] | @tsv'
```

## 핵심 규칙

- **NEVER STOP** — 사용자가 수동으로 멈출 때까지 무한 반복
- **단일 파일만 수정** — target_file 외 수정 금지
- **readonly 파일 수정 금지** — readonly_files에 명시된 파일
- **개선 시 keep, 악화 시 discard** — 단순 명쾌한 판정
- **모든 실험 기록** — results.tsv에 빠짐없이
- **단순 > 복잡** — 같은 개선이면 더 간단한 코드가 승리
- **삭제로 개선 = 최고의 결과** — 코드를 줄이고 성능이 같거나 좋으면 keep
