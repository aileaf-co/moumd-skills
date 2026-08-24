---
name: moumd-cli
description: moumd 데몬 CLI 사용법 — verb 발견(카탈로그가 권위) · 에이전트 모드 계약 · 파괴적 verb 이중 opt-in · 격리 실측 · exit code 계약. moumd 명령을 실행·설명·수정할 때, 그리고 fleet/mesh/pkg/gitops/secrets 작업을 moumd 로 몰 때 사용. 파괴적 표면이나 격리(config-dir, MOUMD_HOME, MOUMD_SERVICE_NAME)가 얽히면 특히. 데스크톱 앱 CLI moum 은 별개다.
---

# moumd CLI — 에이전트가 쓰는 법

`moumd` 는 moum-ops 의 **데몬**이자 그 데몬을 조작하는 CLI 다.

표면이 **셋**이다. 어느 쪽을 말하는지 항상 밝혀라.

| 표면 | 무엇 |
|---|---|
| `moumd` | 데몬 + 데몬 CLI — **이 문서** |
| `moum` | 데스크톱 앱의 CLI. **일부 verb 가 같은 이름으로 양쪽에 있고 같은 fleet 상태를 바꾼다** |
| `moum-ops.com/api/v1/**` | 플랫폼 API. 데몬이 로컬에 여는 `/v1/**` 과 **다른 것**이다 |

---

## 이 스킬로 하는 일

**어디서 시작할지 모르면 물어봐라.** 이 verb 가 여정의 어느 칸인지와 **다음 명령 한 줄**을 준다.

```bash
MOUMD_AGENT_MODE=1 moumd onboard    # steps[] = 지금까지 · next = 다음 한 줄
```

여정은 **mesh 가입 → fleet 등록 → Active → reconcile** 이다. `onboard` 는 그중 어디서
멈췄는지와 다음 명령을 `next` 필드로 돌려준다 — 여정을 진행시키는 작업이라면 여기서 시작하는
것이 항상 가장 짧다.

찾는 것이 "막힌 곳"이 아니라 **"이 작업은 어느 그룹인가"** 라면 아래에서 고르고, 그 **안쪽은
카탈로그로 좁혀라**(§1). 아래는 **그룹 지도**이지 verb 목록이 아니다 — 어떤 verb 가 있는지는
언제나 카탈로그가 권위다.

```bash
moumd status | moumd doctor | moumd paths              # 이 노드는 지금 어떤 상태인가
moumd onboard | moumd mesh onboard                     # 여정 조회 / 그룹+fleet 프로비저닝 ⚠ 다른 verb 다
moumd mesh                                             # MeshVPN — 연결·피어·그룹·setup key·라우트·DNS
moumd node | moumd fleet                               # 노드 등록 · fleet 가입/승인/서명
moumd fleet repo | moumd fleet policy                  # 어느 fleet repo 를 쓰나 · 정책
moumd fleet role | moumd fleet fit                     # 배포 타겟팅(labels) · 노드 적합 게이트
moumd fleet secret | moumd secrets                     # 시크릿 쓰기(단수) / 어디 사는지 읽기(복수)
moumd gitops | moumd pkg | moumd dsc                   # 선언을 현행화하고 수렴시키는 레인
moumd advisory | moumd fleet advisory | moumd proxy    # 어느 모델이 이 호스트/fleet 에 맞나 · 모델 라우팅
moumd login | moumd auth | moumd oidc | moumd zitadel  # 신원 — 플랫폼 · 조직 IdP · M2M
moumd authority | moumd operator                       # Fleet PKI — CA·마스터키 · 운영자 신원
moumd forge                                            # Gitea 설치 (호스트 직접 또는 k0s)
moumd start | moumd stop | moumd restart               # 설치된 서비스 조작 (⚠ §5 — 격리 없이 만지지 마라)
moumd update | moumd config | moumd log | moumd trace  # 자체 업데이트 · 설정 · 로그 · 관측
```

⚠ 이 지도는 **전부가 아니다.** 최상위 그룹은 37개이고 전량은 카탈로그가 준다:
`moumd catalog --format json --verb <그룹>` 으로 그 안을 열어라.

그리고 **작업을 시작하기 전에 §0 을 켜고**, 파괴적 표면·격리가 얽히면 **§2·§3 을 먼저 읽어라.**
그 두 절은 이 문서에서 다른 데 없는 실측을 담고 있다.

---

## 배포는 verb 가 아니라 **선언**이다 — fleet repo 루프

카탈로그에 `install-agent` 같은 verb 는 **없다.** 그건 능력의 부재가 아니라 **설계**다 —
무엇을 설치·설정할지는 **fleet repo 의 파일**이 정하고, moumd 는 그 SoR 을 *찾아 주고 ·
현행화하고 · 검사하고 · 수렴시킨다.* 카탈로그만 뒤지면 *"그 기능은 없다"* 는 **틀린 결론**에 닿는다.

```bash
# ① fleet 이 설정돼 있나 — 전부 읽기 전용
moumd fleet repo current      # 활성 프로필 이름 (없으면 프로필 목록을 본다)
moumd gitops status           # repoUrl · branch · head vs last · verdict. sync 를 유발하지 않는다
moumd paths                   # computed.gitops_repo = 로컬 클론 경로 (§3)

# ② 현행화 — authority 쪽 변경(sign·approve·secret-set)은 temp clone 으로 push 되므로
#    이 노드의 클론은 낡아 있다
moumd gitops sync

# ③ 설정 확인
moumd fleet repo show         # 프로필 상세
moumd fleet repo verify       # Triage preflight

# ④ 선언 편집 — 여기서부터는 verb 가 아니라 **파일**이다
#      fleet/global/software.yaml               패키지 카스케이드 — fleet 전체
#      fleet/global/roles/<role>/software.yaml  역할별 — 개별 타겟팅
#      fleet/global/dsc/*.dsc.yaml              DSC 레인 — AI agent · ollama · 메신저가 여기
#      fleet/daemons/<short_id>/daemon.yaml     이 노드 하나
#    ⚠ 없으면 만든다. 갓 만든 fleet 의 global 엔 ca-chain.pem 뿐이다(실측).
#    ⚠ 경로의 권위는 이 문서가 아니라 위 verb 들의 --help 다.

# ⑤ 커밋 전 검사 — 전부 오프라인
moumd pkg validate            # software 카스케이드 오타·파싱
moumd fleet dsc validate      # dsc 문서 + engine 선언이 실제 구현과 맞나
moumd fleet validate-tree     # 예약 이름 가드 — FAIL-CLOSED

# ⑥ 적용과 확인
moumd pkg reconcile
moumd gitops status           # 수렴했나
moumd fleet role match        # 이 선언이 어느 노드에 붙나 (labels 축)
```

⚠ **전체 배포와 개별 배포의 차이는 verb 가 아니라 파일 위치다** — `fleet/global/` 은 전체,
`roles/<role>/` 은 역할, `daemons/<short_id>/` 은 그 노드 하나. 타겟이 맞는지는
`moumd fleet role match` 가 답한다.

⚠ **`moumd onboard` 와 `moumd mesh onboard` 는 다른 verb 다.** 앞은 *이 노드가 여정의 어디쯤인가*
(읽기 전용), 뒤는 *그룹 + 선택적 GitOps fleet 을 프로비저닝하고 mesh 에 가입*(생성)이다.

### 끝을 확인하기 — 에이전트가 로컬 LLM 과 **실제로** 통신하는가

moumd 는 여기까지 답한다. **질의를 보내는 verb 는 없다** — 왕복은 에이전트나 앱이 만든다.
그러니 갈 수 있는 데까지 좁히고, **나머지는 사용자에게 확인을 요청하라.**

```bash
moumd proxy status            # enabled · configuredProviders · effectiveRoutes · provider health
moumd proxy resolve           # 그 모델 이름이 실제로 라우트에 걸리나 (모델명을 인자로)
moumd trace list              # 사후 흔적 — 요청이 실제로 흘렀나
```

| 어디서 끊겼나 | 신호 (실측) |
|---|---|
| 프록시가 꺼져 있음 | `proxy status` → `enabled: false` · `configuredProviders: 0` · `effectiveRoutes: []` |
| 모델 이름이 라우트에 없음 | `proxy resolve <모델>` → **exit 4** · `model_not_found` — *"no route matches model 'X'"* |
| 라우트는 있는데 백엔드가 죽음 | `proxy status` 의 provider health |
| 여기까지 다 초록인데 답이 안 옴 | **moumd 밖이다** — 사용자에게 확인을 요청하라 |

🔴 **`trace list` 가 `[]` 인 것을 "통신 안 됨"으로 읽지 마라.** `proxy status` 의
`observability.enabled` 가 `false` 면 애초에 **기록을 하지 않는다** — 빈 배열은 *"흔적이 없다"* 이지
*"트래픽이 없었다"* 가 아니다(실측: 이 호스트가 정확히 그 상태였다). 관측을 켜기 전의
`trace list` 는 증거가 아니다. §2 의 *"`false` 를 안전으로 읽지 마라"* 와 같은 클래스다.

**확인을 요청할 때는 위 표에서 어디까지 초록이었는지를 함께 말하라.** *"연결이 안 됩니다"* 로는
사용자가 할 수 있는 게 없다. *"라우트는 잡히고 provider 도 healthy 인데 제가 왕복을 만들 수
없습니다 — 에이전트에서 한 번 질의해 주시겠습니까"* 는 다음 행동이 하나로 좁혀진다.

⚠ 이 사다리는 **막혔을 때만의 것이 아니다.** 배포 직후 "됐다"고 보고하기 전에 여기까지
내려와라 — `pkg reconcile` 이 초록인 것은 *선언이 적용됐다*는 뜻이지 *에이전트가 모델과 말한다*는
뜻이 아니다.

### 정보가 없으면 — **묻기 전에 moumd 에게 먼저 물어라**

*"AI API 가 등록돼 있나" · "메신저 설정이 있나"* 같은 질문에 moumd 는 **무엇이 필요한지 ·
어디 사는지 · 어떻게 넣는지**를 스스로 답한다. 그 목록을 이 문서에 적지 마라 — 물어라.

```bash
moumd secrets list     # 카탈로그 전량 — 항목마다 what · location · rotation 을 들고 있다
moumd secrets where    # 하나만 (이름을 인자로): 무엇이고 · 어디 살고 · 어떻게 교체하나
moumd secrets get      # 값 없이 **등록 여부만** — status = present | absent (--reveal 불필요)
moumd secrets doctor   # 이 머신에서 무엇이 host 비밀을 지키고 있나
```

실측 — `secrets get` 은 값을 안 보여주고 상태만 답한다:
`{"name":"llm_key","status":"absent","redacted":true,"value":null}`

그리고 `secrets where` 가 **등록 명령을 그대로 준다**:
`rotation: "moumd fleet secret set --global --name llm_key --from env|file|stdin"`
`location: "secrets.d cascade; referenced from proxy.outbound_providers token_ref"`

**그래서 순서는 이렇다:**

```
① `secrets get <이름>` 으로 status 를 본다 — absent 인가 present 인가
② absent 면 `secrets where <이름>` 의 what · location 을 그대로 인용해 사용자에게 설명한다
③ 값을 **요청**한다. 값은 사용자만 갖고 있다 — 추측하거나 만들어내지 마라
④ 등록은 `rotation` 필드가 준 명령으로 한다. 이 문서가 아니라 그 필드가 권위다
```

⚠ **비밀 값을 명령줄에 붙여넣지 마라.** `rotation` 이 `--from env|file|stdin` 을 주는 이유가
그것이다 — argv 는 프로세스 목록·셸 히스토리·로그에 남는다. 사용자에게 안내할 때도 그렇게 하라.

🔴 **`fleet secret set` 에는 `--yes` 게이트가 없다**(§2 의 17개에 들어 있지 않다). 이미
`present` 인 것을 덮어쓰면 **말없이 덮인다.** ①의 status 확인을 건너뛰지 마라.

⚠ 카탈로그에 없는 설정(예: 메신저 DSC 파라미터)은 비밀이 아니라 **선언**이다 — 위 루프 ④의
파일로 간다. 그 경우에도 순서는 같다: 무엇이 필요한지는 문서가 아니라 `fleet dsc validate` 가
말하게 하고, 값은 사용자에게 요청하라.

### 이 스킬이 다루지 않는 표면

| 작업 | 어디 |
|---|---|
| 모델 등록·다운로드·서빙 설정 | 앱 CLI `moum model` / `moum serve` — 별도 스킬 `moum-ai-model-cli` |
| AI agent 런타임 제어 | 데몬 HTTP `/v1/agent/*` · `/v1/hosted/*` — CLI 에서 **의도적으로 제거**됐다(2026-06-15, 구현은 남아 있다) |

즉 **카탈로그는 CLI verb 의 권위이지 데몬 능력의 권위가 아니다.** 위 두 줄이 그 반례다.

🔴 그렇다고 HTTP 를 직접 부르지 마라 — §2 의 동의 게이트는 **CLI 층에 있어서** 우회된다.
그리고 moumd 는 OpenAPI 스펙을 내지 않는다(실측: `/openapi.json` · `/swagger.json` · `/docs`
전부 404). 엔드포인트를 손으로 목록화하지 마라 — SoR 은 `src-tauri/moumd/src/server/` 소스다.

## 0. 먼저 이것부터

```bash
export MOUMD_AGENT_MODE=1
```

- 값은 **정확히 `1`** 이다(앞뒤 공백만 허용). `true`·`yes`·`0`·`12` 는 **조용히 꺼진다** —
  오타가 켜진 것처럼 보이지 않게 만든 엄격 규약이다.
- **출력이 기계가독으로 강제된다** — 사람용 표(table) 기본값이 JSON 이 된다.
  명시한 `--format json|yaml` 은 존중되고, 명시한 `--format table` 은 **덮인다**
  (하네스가 플래그를 잘못 조합해도 파싱 불가능한 표가 나가지 않는 fail-safe).
- **파괴적 verb 에 게이트가 걸린다** — 확인 프롬프트 앞에서 **멈추지 않고 에러**를 낸다.
  에이전트는 `[y/N]` 에 답할 수 없으므로, 멈추는 대신 실패하는 쪽이 옳다.

### 에이전트가 **스스로 켜면 안 되는** 환경변수

| 변수 | 무엇을 여는가 |
|---|---|
| `MOUMD_AGENT_ALLOW_DESTRUCTIVE=1` | agent mode 에서 파괴적 verb 의 **실행**. `--yes` 와 **함께** 있어야 열린다(이중 opt-in) |
| `MOUMD_AGENT_ALLOW_REVEAL=1` | `secrets get --reveal` 이 **터미널이 아닌 곳**(파이프·파일·에이전트 트랜스크립트)으로 값을 뱉는 것 |

둘 다 **사용자가 켜는 스위치**다. 축이 나뉜 이유가 그것이다 — 하나는 **파괴**, 하나는 **노출**이고,
하나를 켠다고 다른 하나가 열려선 안 된다.

⚠ agent mode 에서는 **터미널도 터미널로 치지 않는다**(판정이 `is_terminal() && !agent_mode`).
즉 `MOUMD_AGENT_MODE=1` 인 동안 `--reveal` 은 **언제나** 위 스위치를 요구한다.

---

## 1. 명령의 존재는 **카탈로그**가 권위다

문서가 아니다. 이 문서도 아니다.

```bash
moumd catalog --format json
```

**카탈로그에 없는 명령을 발명하지 마라.** 이것이 이 스킬의 유일하게 중요한 규칙이다.

카탈로그는 크다 — 실측 2026-08-24 (moumd 2026.8.0): **verb 276개 · 최상위 그룹 37개 · JSON 약 280 KB**.

⚠ 이 숫자는 **드리프트한다**. 2026-08-04 엔 263개·33그룹이었다.
⚠ 그리고 verb 는 **개명되며 별칭을 남기지 않는다** — `daemon` 은 2026-08-17 `moumd run` 이 됐고
  별칭이 없다(옛 이름은 clap exit 2 로 죽는다). 기억으로 부르지 말고 카탈로그를 봐라.

매 턴 통째로 읽지 말고 **좁혀라**:

```bash
moumd catalog --format json --verb "fleet keys"   # 그 하위만
moumd fleet keys --help                            # 상세는 --help 가 낫다
```

`--verb` 는 **경로 경계**로 매칭한다 — `fleet key` 는 `fleet keys` 에 매칭되지 **않는다**.
없는 경로를 주면 **빈 목록이 아니라 에러(exit 1)** 다(조용한 0-매칭을 막는 설계).

### 카탈로그가 알려주는 것

봉투(envelope):

| 필드 | 의미 |
|---|---|
| `schemaVersion` | 와이어 계약 버전(현재 `1`). 바이너리 버전과 **별개**다 |
| `generatedFrom` | 이 카탈로그를 낸 바이너리 (예: `moumd 2026.8.0`) |
| `agentMode` | 위 §0 의 env 이름을 **프로그램이 읽을 수 있게** 실어 준다 |
| `contractText` | `moumd --help` 의 계약 텍스트와 **같은 문자열**. 이 문서보다 그쪽이 최신이다 |
| `globalFlags` | 모든 verb 에 공통인 플래그(현재 `--format` 하나) |

verb 하나:

| 필드 | 의미 |
|---|---|
| `path` | verb 경로 (예: `fleet keys init`) |
| `summary` | 한 줄 설명 |
| `longSummary` | **운전 지식** — 누가 실행하는가·순서·비가역성·양쪽 바이너리 쌍둥이. `summary` 와 다를 때만 실린다(실측: 276개 중 73개) |
| `runnable` | 바로 실행 가능한가. `false` = 서브커맨드를 요구하는 그룹 |
| `requiresConfirmation` | **`--yes` 플래그가 있다**는 뜻 — §2 를 읽어라 |
| `supportsDryRun` | `--dry-run` 이 **선언돼 있다** |
| `args` | 인자·플래그 |

⚠ 카탈로그는 **clap 선언의 반영이지 런타임 행동의 계약이 아니다.** verb 가 `--dry-run` 을
선언해 놓고 무시할 수 있다. `supportsDryRun: true` 를 "이 명령은 안 쓴다"의 증거로 쓰지 마라.
⚠ **숨은 서브트리는 빠져 있다**(기계가 부르는 내부 verb). 사람·에이전트가 부를 표면은 전부 실려 있다.

```bash
# 재현: 위 숫자의 근거
moumd catalog --format json | python3 -c "import json,sys; d=json.load(sys.stdin); v=d['verbs']; \
print('verbs', len(v), 'groups', len({x['path'].split()[0] for x in v}), \
      'yes', sum(1 for x in v if x['requiresConfirmation']), \
      'longSummary', sum(1 for x in v if x.get('longSummary')))"
moumd catalog --format json | wc -c
```

---

## 2. `requiresConfirmation: false` 는 **"안전"이 아니다**

이 오해가 이 도구에서 가장 비싼 실수다.

> `requiresConfirmation: false` = **"이 verb 에 `--yes` 플래그가 없다"**
> ≠ "이 verb 는 안전하다"

실측(2026-08-24): 전체 276개 중 `--yes` 를 가진 verb 는 **17개**다.
나머지 259개가 안전하다는 뜻이 아니다 — 그저 그 플래그가 없다는 뜻이다.

**게이트는 호출 지점마다 배선**돼 있어 커버리지가 **부분적**이다. 그리고 그 17개가 각각
어떻게 처분됐는지는 **추측할 필요가 없다** — moum-ops 레포에 원장이 있다:

```bash
cat ci/destructive-gate-ledger.txt        # <verb>\t<gated|exempt|todo>\t<근거>
scripts/check-destructive-gate-ledger.sh  # 처분 없는 --yes verb 가 생기면 RED
```

원장이 SoR 이다. 새 `--yes` verb 가 생기면 **처분을 쓸 때까지 가드가 붉어지므로**, 이
문서에 목록을 복제할 이유가 없다. 실측(2026-08-24): **gated 15 · exempt 2 · todo 0**.

🔴 그 **exempt 2개는 `MOUMD_AGENT_ALLOW_DESTRUCTIVE` 를 보지 않는다** — `--yes` 하나로
실행된다. `moumd fleet init` 과 `moumd fleet authority unrevoke-intermediate` 다.
(둘 다 `--yes` 가 없으면 프롬프트 대신 **실패**하므로 "agent mode 는 절대 멈추지 않는다"는
계약은 지켜진다. 빠지는 것은 **환경 차원의 opt-in** 이다.)

🔴 그리고 `moumd fleet init` 에서 **위험한 플래그는 `--yes` 가 아니라 `--force`** 다 —
원장이 그렇게 적어 뒀다("게이트 축과 파괴 축이 어긋난 사례"). `--yes` 는 요약 뒤의 y/N 을
건너뛸 뿐이고, 선행 가드(Initialized·AlreadyMember)를 무효화하는 것은 `--force` 다.
**플래그 이름으로 위험도를 추정하지 마라.**

⚠ 게이트가 있는 verb 도 **경로에 따라** 게이트를 지난다:
`moumd fleet keys init` 은 **`--force` 회전**일 때만, `config set` 은 **보안 키**일 때만,
`forge uninstall` 은 **`--dry-run` 이 아닐 때만** 게이트를 탄다.

⚠ 반대로 게이트가 **없는데 파괴적인** verb 가 있다 — 원장은 `--yes` 를 **가진** verb 만
다루므로 그 집합 밖이다. 예: `moumd fleet secret rm` 은 값을 지우지만 git 이 추적하므로
`git revert` 로 되돌아온다 — 그래서 일부러 비게이트이고 `false` 로 정직하게 표시된다.
**`false` 를 허가로 읽지 마라.**

### 그래서 에이전트가 지킬 것

1. **파괴적 명령은 사용자 승인 없이 실행하지 마라.**
2. **우회 환경변수를 스스로 설정하지 마라**(§0 표).
3. **"게이트가 막아줄 것"에 기대지 마라.** 위 커버리지가 그 기대를 배신한다.

### 이 규칙이 왜 있는가 (실제 사고)

2026-08-02, 한 에이전트가 **검증을 목적으로** `moumd fleet keys init --force --yes` 를
실행했고 **실제 daemon age 키가 회전**했다. 그 자리의 게이트는 *"이 키에 봉인된 값이 있는가"* 를
재는 **영향도 게이트**여서 `--yes` 하나로 통과했고 agent mode 를 보지 않았다.

그 **한 자리**는 같은 날 닫혔다(이제 영향도 판정 **앞에** 이중 opt-in 게이트가 선다).
교훈이 남는 이유는 게이트가 여전히 **호출 지점마다** 배선되기 때문이다 — 배선되지 않은 자리가
**지금도 둘 남아 있다**(위 🔴). 그래서 규칙은 "게이트를 믿어라"가 아니라
**"파괴적 표면을 시험하려면 격리를 먼저 실측하라"** 다.

---

## 3. 격리는 **부분적**이다 — 무엇이 따라오는지 실측하고 시작하라

경로는 **10축**이고, 격리 스위치마다 따라오는 축이 다르다. 실측(2026-08-24, macOS):

| 스위치 | 따라오는 축 | 안 따라오는 축 |
|---|---|---|
| `--config-dir` / `MOUM_DAEMON_CONFIG_DIR` | **4** — `config_dir` `daemon_yaml` `gitops_repo` `socket` | 6 |
| `MOUMD_HOME` | **7** — 위 4 + `log_dir` `sync_root` `workspace_root` | 3 |
| (어느 스위치로도 안 옮겨진다) | — | `data_dir` `secrets_dir` `fleet_pki_dir` |

`secrets_dir`·`fleet_pki_dir` 는 **공유 keystore** 라 의도적으로 제외돼 있다(출력에서
`reference_only: true`). 즉 **"격리했으니 안전하다"가 성립하지 않는다** — 무엇을 건드릴
verb 인지 보고, 그 축이 실제로 옮겨졌는지 재라.

🔵 **격리는 환경변수로 걸어라, 플래그가 아니라.** `moumd paths` 는 `--config-dir` 를
**받지 않는다**(실측: exit 2). 그래서 플래그로 건 격리는 별도 프로세스인 `paths` 로 **잴 수
없다** — 환경변수는 상속되므로 잴 수 있다. `--config-dir` 는 그 호출 한 번에만 적용되고,
옮기는 축은 환경변수와 같다(넷 다 `config_dir` 에서 파생되는 경로다).

### 측정 도구는 `moumd paths` 다

읽기 전용이고, **이 셸이 쓸 경로(`computed`)** 와 **실제 데몬이 쓰는 경로(`daemon`)** 를
나란히 준다. 둘이 다르면 `warnings[]` 에 `mismatch[축]` 로 이름이 붙어 나온다.

```bash
MOUMD_AGENT_MODE=1 moumd paths     # computed / daemon / daemon_status / warnings
```

각 축에는 `mutable_by_agent` 도 붙는다. **`true` 는 3축뿐이다** —
`log_dir`·`sync_root`·`workspace_root`. 나머지 **7축은 `false`** 이고, 그중
`config_dir`·`secrets_dir`·`fleet_pki_dir` 는 자격증명 금고다 — **폴더에 직접 쓰지 말고**
verb 를 통해 바꾸라는 뜻이다.

`paths` 는 **데몬이 없어도 죽지 않는다**: exit 0 으로 `daemon_status: "unreachable"` 과
`warnings[daemon_unreachable]` 을 주고 `computed` 는 그대로 채운다. 온라인 verb 처럼
exit 3 으로 끝나지 않으므로, 데몬 상태를 모를 때 **첫 진단으로 안전하다**.

**그러므로 순서는 이렇다**:

```
① 격리를 **환경변수로** 걸고 `moumd paths` 로 어느 축이 실제로 옮겨졌는지 본다.
② 건드릴 축이 그 안에 있는가? 없으면 여기서 멈춰라.
③ 그 다음에야 파괴적 verb 를 시험한다.
```

```bash
# 재현: 어느 축이 따라오는가
MOUMD_AGENT_MODE=1 moumd paths > /tmp/a.json
MOUM_DAEMON_CONFIG_DIR=/tmp/x MOUMD_AGENT_MODE=1 moumd paths > /tmp/b.json
python3 -c "import json; a=json.load(open('/tmp/a.json'))['computed']; b=json.load(open('/tmp/b.json'))['computed']; \
print('moved :', [k for k in a if a[k]['path'] != b[k]['path']]); \
print('stayed:', [k for k in a if a[k]['path'] == b[k]['path']])"
```

⚠ **플래그 위치가 까다롭다 — `--config-dir` 는 그룹 레벨이다.**

```bash
moumd fleet keys --config-dir /tmp/x init     # ✅
moumd fleet keys init --config-dir /tmp/x     # ❌ exit 2 — clap 이 거부한다
```

⚠ **틀린 환경변수 이름은 조용히 무시되고 실제 config dir 로 폴백한다.** 위 사고의 직접
원인이 그것이었다(존재하지 않는 이름을 썼다). 이름을 기억으로 쓰지 말고 `--help` 의
`[env: …]` 표기를 보고 써라.

⚠ **경로만 축이 아니다.** 서비스 조작(`moumd start`·`stop`·`restart`)의 격리축은
config dir 이 아니라 **서비스 이름**(`MOUMD_SERVICE_NAME`)이다 — §5 를 봐라.

⚠ **`fleet keys path` 를 격리 확인용으로 쓰지 마라.** 키가 없는 새 디렉토리에서는 경로 대신
*"no age key found"* 에러(exit 1)를 낸다 — 격리가 걸렸는지 아닌지를 구분해 주지 못한다.
그 역할은 `moumd paths` 가 맡는다.

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

이 표의 SoR 은 카탈로그 봉투의 `contractText`(= `moumd --help` 꼬리말)다. 갈리면 그쪽이 맞다.

⚠ **파이프는 exit code 를 가린다.** `moumd … | tail` 의 `$?` 는 `tail` 의 것이다.
판정하려면 파이프 없이 돌리고 `$?` 를 잡아라.

---

## 5. 온라인 / 오프라인 — 그리고 `run` 의 함정

일부 verb 는 **실행 중인 데몬**에 붙고(gRPC/HTTP), 일부는 로컬 파일만 읽는다.
데몬이 없으면 온라인 verb 는 **exit 3** 이다. 어느 쪽인지는 `--help` 가 말해준다.

🔴 **`moumd run` 은 이 프로세스를 데몬으로 만들고 SIGTERM 까지 블록한다.** 서비스 매니저가
exec 하는 바로 그 프로세스다 — 무심코 부르면 턴이 거기서 멈춘다. 서비스 조작은 따로 있다:
`moumd start` · `moumd stop` · `moumd restart` (설치된 서비스에 요청하고 즉시 반환).

🔴 **그런데 그 셋은 호스트의 진짜 서비스 매니저**(systemd·launchd·SCM)**를 부른다.**
격리 없이 시험하면 **사용자의 실제 데몬을 멈춘다.** 여기서 격리축은 경로가 아니라
**서비스 이름**이다:

```bash
MOUMD_SERVICE_NAME=com.moum.moumd.verbtest moumd stop   # 실험 레이블만 건드린다
```

플랫폼 기본값(systemd `moumd` · launchd `com.moum.moumd` · SCM `moumd`)을 이 하나가 덮는다.
⚠ **빈 값·공백은 무시되고 기본값으로 떨어진다** — 오타가 격리를 조용히 해제한다(§3 의
"틀린 env 이름은 조용히 폴백한다"와 같은 함정이다).

§3 과 같은 규율이 적용된다 — **격리를 가정하지 말고 증명하라.** 갓 만든 실험 레이블에는
아직 아무것도 등록돼 있지 않으므로 `moumd stop` 이 *"no moumd service is registered"* 를
내야 한다. 진짜 서비스가 응답한다면 그건 **프로덕션 레이블을 보고 있다는 뜻**이니 즉시 멈춰라.

**행동 전에 상태부터 읽어라** — 아래는 전부 읽기 전용이다:

| | |
|---|---|
| `moumd status` | 데몬이 살아 있는가 |
| `moumd doctor` | 채널·바인드·mesh·fleet·weakeners 다축 진단 + 다음 행동 |
| `moumd onboard` | 여정의 어느 단계인가 + `next` 에 다음 한 줄 — **진입점은 맨 위 절** |
| `moumd paths` | 이 셸과 데몬이 **같은 경로**를 보고 있는가 (§3) |
| `moumd secrets where` | 어떤 비밀이 어디 살고 누가 읽는가 (읽기 전용) |

⚠ `moumd secrets` (복수)는 **읽기만** 한다. 값을 **쓰는** 것은 `moumd fleet secret` (단수)다.

**행동하기 전에 인식하라** — 한 번의 읽기로 상태를 통째로 주는 verb 가 있다:

```bash
moumd node snapshot     # 이 호스트: 하드웨어·mesh·reconcile + 섹션별 신선도
moumd fleet snapshot    # fleet 전체: ACTIVE 멤버의 membership·도달성·용량
```

---

## 6. 하지 말 것 — 요약

| | |
|---|---|
| 카탈로그에 없는 verb 를 발명 | 존재의 권위는 카탈로그다 |
| 카탈로그에 없으니 **그 기능이 없다**고 결론 | 카탈로그는 **CLI verb** 의 권위다 — 배포는 선언이고, `/v1/agent/*` 는 CLI 밖이다 |
| 배포할 verb 를 찾아 헤맴 | 배포는 **fleet repo 의 파일**이다. verb 는 찾고·현행화하고·검사하고·수렴시킨다 |
| HTTP 를 직접 호출 | 동의 게이트가 **CLI 층**에 있어 그대로 우회된다 |
| `trace list` 가 비었다고 "트래픽 없음" 판정 | 관측이 꺼져 있으면 **기록 자체를 안 한다** |
| 왕복을 확인 못 했는데 "됐다"고 보고 | 확인 못 하는 칸은 **사용자에게 요청**하라 — 어디까지 초록인지와 함께 |
| 필요한 설정을 문서/기억에서 answer | `moumd secrets where` 가 what·location·rotation 을 준다 |
| 비밀 값을 명령줄 인자로 전달 | argv 는 프로세스 목록·히스토리·로그에 남는다 — `--from env\|file\|stdin` |
| status 확인 없이 `moumd fleet secret set` | `--yes` 게이트가 없어 **말없이 덮는다** |
| 기억한 verb 이름을 재사용 | 개명에 별칭이 없다 (`daemon` → `moumd run`) |
| `requiresConfirmation:false` 를 "안전"으로 해석 | `--yes` 가 없다는 뜻일 뿐이다 |
| `supportsDryRun:true` 를 "안 쓴다"의 증거로 사용 | 카탈로그는 **선언**의 반영이다 |
| `MOUMD_AGENT_ALLOW_DESTRUCTIVE=1` / `MOUMD_AGENT_ALLOW_REVEAL=1` 을 스스로 설정 | 사용자가 켜는 스위치다 |
| 환경 스위치를 안 켰으니 안전하다고 가정 | 17개 중 2개는 `--yes` 하나로 실행된다 (§2) |
| 격리 실측 없이 파괴적 verb 시험 | 격리는 **부분적**이다 — 10축 중 4~7축만 옮겨진다 |
| `--config-dir` 로 격리하고 `moumd paths` 로 확인 | `paths` 는 그 플래그를 안 받는다 — 환경변수로 걸어라 (§3) |
| 에이전트 턴에서 `moumd run` 호출 | 데몬이 되어 블록한다. 서비스 조작은 `moumd start` 다 |
| `MOUMD_SERVICE_NAME` 없이 `moumd stop` 시험 | 사용자의 **실제 데몬**을 멈춘다 (§5) |
| 파이프 뒤의 `$?` 로 성공 판정 | 앞 명령이 아니라 뒤 명령의 코드다 |
| 이 문서를 카탈로그보다 신뢰 | 이 문서는 낡을 수 있다. 카탈로그는 바이너리에서 나온다 |
