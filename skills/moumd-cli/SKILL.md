# moumd CLI — 에이전트가 쓰는 법

`moumd` 는 moum-ops 의 **데몬**이자 그 데몬을 조작하는 CLI 다.
데스크톱 앱의 CLI 는 `moum` 으로 **따로 있다** — 일부 명령은 **같은 이름으로 양쪽에 존재하고
같은 fleet 상태를 바꾼다**. 어느 쪽을 말하는지 항상 밝혀라.

---

## 0. 먼저 이것부터

```bash
export MOUMD_AGENT_MODE=1
```

두 가지가 바뀐다.

1. **출력이 기계가독으로 강제된다** — 사람용 표(table) 기본값이 JSON 이 된다.
   (`--format json|yaml` 을 명시하면 그쪽이 존중된다.)
2. **파괴적 verb 에 게이트가 걸린다** — 확인 프롬프트 앞에서 **멈추지 않고 에러**를 낸다.
   에이전트는 `[y/N]` 에 답할 수 없으므로, 멈추는 대신 실패하는 쪽이 옳다.

---

## 1. 명령의 존재는 **카탈로그**가 권위다

문서가 아니다. 이 문서도 아니다.

```bash
moumd catalog --format json
```

**카탈로그에 없는 명령을 발명하지 마라.** 이것이 이 스킬의 유일하게 중요한 규칙이다.

카탈로그는 크다(실측 2026-08-04: **verb 263개 · 최상위 그룹 33개**).
⚠ 이 숫자는 **드리프트한다** — 실제로 하루 만에 262→263 이 됐다. 아래 재현 명령이
  이 문서보다 항상 최신이고, 숫자가 안 맞으면 **카탈로그가 맞다**.
매 턴 통째로 읽지 말고 **좁혀라**:

```bash
moumd catalog --format json --verb "fleet keys"   # 그 하위만
moumd fleet keys --help                            # 상세는 --help 가 낫다
```

`--verb` 는 **경로 경계**로 매칭한다 — `fleet key` 는 `fleet keys` 에 매칭되지 **않는다**.
없는 경로를 주면 **빈 목록이 아니라 에러**다(조용한 0-매칭을 막는 설계).

### 카탈로그가 알려주는 것

| 필드 | 의미 |
|---|---|
| `path` | verb 경로 (예: `fleet keys init`) |
| `summary` | 한 줄 설명 |
| `runnable` | 실행 가능한 잎인가, 그룹인가 |
| `requiresConfirmation` | **`--yes` 플래그가 있다**는 뜻 |
| `supportsDryRun` | `--dry-run` 이 있다 |
| `args` | 인자·플래그 |

봉투에는 `schemaVersion`(현재 `1`)과 `contractText` 도 있다. `contractText` 는
`moumd --help` 의 계약 텍스트와 **같은 문자열**이다 — 이 문서보다 그쪽이 최신이다.

```bash
# 재현: 위 숫자의 근거
moumd catalog --format json | python3 -c "import json,sys; d=json.load(sys.stdin); \
v=d['verbs']; print(len(v), len({x['path'].split()[0] for x in v}))"
```

---

## 2. `requiresConfirmation: false` 는 **"안전"이 아니다**

이 오해가 이 도구에서 가장 비싼 실수다.

> `requiresConfirmation: false` = **"이 verb 에 `--yes` 플래그가 없다"**
> ≠ "이 verb 는 안전하다"

파괴적 게이트는 **호출 지점마다 배선**돼 있다. 즉 커버리지가 **부분적**이고, 게이트가 없다는
것은 허가가 아니라 **아직 아무도 결정하지 않았다**는 뜻일 수 있다.

실측(2026-08-04): 전체 263개 중 `--yes` 를 가진 verb 는 **17개**다.
나머지 246개가 안전하다는 뜻이 아니다 — 그저 그 플래그가 없다는 뜻이다.

### 그래서 에이전트가 지킬 것

1. **파괴적 명령은 사용자 승인 없이 실행하지 마라.**
2. **우회 환경변수를 스스로 설정하지 마라.** `MOUMD_AGENT_ALLOW_DESTRUCTIVE=1` 은
   사용자가 켜는 것이지 에이전트가 켜는 것이 아니다.
3. **"게이트가 막아줄 것"에 기대지 마라.** 위 커버리지가 그 기대를 배신한다.

### 이 규칙이 왜 있는가 (실제 사고)

2026-08-02, 한 에이전트가 **검증을 목적으로** `moumd fleet keys init --force --yes` 를
실행했고 **실제 daemon age 키가 회전**했다. 그 자리의 게이트는 *"이 키에 봉인된 값이 있는가"* 를
재는 **영향도 게이트**여서 `--yes` 하나로 통과했고 agent mode 를 보지 않았다.

교훈은 "게이트를 믿지 마라"가 아니라 **"파괴적 표면을 시험하려면 격리를 먼저 실측하라"** 다.

---

## 3. 파괴적 verb 를 시험해야 한다면 — 격리를 **실측**하고 시작하라

`moumd fleet keys` 는 격리가 **가능하다**. 다만 문법이 까다롭다.

```bash
moumd fleet keys --config-dir /tmp/x init --force     # ✅ 플래그는 **그룹 레벨**
MOUM_DAEMON_CONFIG_DIR=/tmp/x moumd fleet keys path   # ✅ 환경변수도 동작
moumd fleet keys init --config-dir /tmp/x             # ❌ 서브커맨드 뒤 → clap 이 거부
```

⚠ **틀린 환경변수 이름은 조용히 무시되고 실제 config dir 로 폴백한다.** 위 사고의 직접
원인이 그것이었다(존재하지 않는 이름을 썼다).

**그러므로 순서는 이렇다**:

```bash
# ① 읽기 전용 verb 로 격리가 실제로 걸렸는지 먼저 확인한다
moumd fleet keys --config-dir /tmp/x path
#    출력 경로가 /tmp/x 를 가리키는가? 아니라면 여기서 멈춰라.
# ② 그 다음에야 파괴적 verb 를 시험한다
```

---

## 4. exit code 는 계약이다

| code | 뜻 |
|---|---|
| 0 | 성공 |
| 1 | 일반 오류 |
| 2 | 사용법/파싱 오류 (clap) |
| 3 | **moumd 에 도달 불가** |
| 4 | 클라이언트 오류 (4xx, 예: 인증) |
| 5 | 서버 오류 (5xx) |
| 6 | fleet wait: 차단 — fleet 인덱스 손상 (오프라인 verb, 기다려도 안 풀린다) |

`3` 을 `1` 로 뭉뚱그리지 마라 — *"데몬이 안 뜬 것"* 과 *"명령이 실패한 것"* 은 다음 행동이 다르다.

⚠ **파이프는 exit code 를 가린다.** `moumd … | tail` 의 `$?` 는 `tail` 의 것이다.
판정하려면 파이프 없이 돌리고 `$?` 를 잡아라.

---

## 5. 온라인 / 오프라인

일부 verb 는 **실행 중인 데몬**에 붙고(gRPC/HTTP), 일부는 로컬 파일만 읽는다.
데몬이 없으면 온라인 verb 는 **exit 3** 이다. 어느 쪽인지는 `--help` 가 말해준다.

막혔을 때 먼저 이것부터:

```bash
moumd status      # 데몬이 살아 있는가
moumd doctor      # 채널·바인드·mesh·fleet 다축 진단 + 다음 행동
moumd onboard     # 이 노드가 온보딩 여정의 어느 단계인가
```

---

## 6. 하지 말 것 — 요약

| | |
|---|---|
| 카탈로그에 없는 verb 를 발명 | 존재의 권위는 카탈로그다 |
| `requiresConfirmation:false` 를 "안전"으로 해석 | `--yes` 가 없다는 뜻일 뿐이다 |
| `MOUMD_AGENT_ALLOW_DESTRUCTIVE=1` 을 스스로 설정 | 사용자가 켜는 스위치다 |
| 격리 실측 없이 파괴적 verb 시험 | 2026-08-02 사고가 그렇게 났다 |
| 파이프 뒤의 `$?` 로 성공 판정 | 앞 명령이 아니라 뒤 명령의 코드다 |
| 이 문서를 카탈로그보다 신뢰 | 이 문서는 낡을 수 있다. 카탈로그는 바이너리에서 나온다 |
