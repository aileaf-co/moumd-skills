#!/usr/bin/env bash
# =============================================================================
# check-no-invented-verbs.sh — 문서에 적힌 `moumd …` 명령이 **실제로 존재**하는가.
# =============================================================================
# 왜: 이 저장소는 moumd 사용법을 가르치지만 **명령의 존재에 대한 권위는 아니다**.
#   권위는 `moumd catalog --format json` 이고, 그것은 바이너리에서 나온다. 문서에 verb 를
#   적는 순간 그것은 두 번째 출처가 되고, 다음 릴리스에서 조용히 틀려진다. 이 가드는
#   "적지 마라"를 강제하지 못한다 — 대신 **적은 것이 틀리면 붉어지게** 한다.
#
# 판정: 마크다운의 코드 안에서 `moumd <경로>` 를 추출해 카탈로그의 verb 집합과 대조한다.
#   · 카탈로그에 없는 경로 → RED (오타이거나 발명이다)
#   · 카탈로그가 없으면 → exit 2 **판정 불가** (통과가 아니다)
#
# ⚠️ 증명하지 못하는 것:
#   1. 플래그의 정확성 — 경로만 본다. `--help` 가 그 층의 권위다.
#   2. 예시의 **의미**가 맞는지 — 존재하는 verb 로 틀린 이야기를 할 수 있다.
#   이 가드를 "문서가 정확하다"로 읽지 말 것.
#
# exit: 0 통과 · 1 위반 · 2 판정 불가(moumd 부재/카탈로그 파싱 실패)
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MOUMD="${MOUMD_BIN:-$(command -v moumd || true)}"
if [ -z "$MOUMD" ] || [ ! -x "$MOUMD" ]; then
  echo "::error::moumd 를 찾지 못했다 — 판정 불가(통과 아님). MOUMD_BIN=<경로> 로 지정하라." >&2
  exit 2
fi

# ★ 카탈로그를 **파일로** 넘긴다. 히어독(`<<PY`)과 herestring(`<<<`)을 겹치면 stdin 이
#   하나뿐이라 뒤엣것이 이기고, 파이썬이 **카탈로그를 스크립트로 읽는다**(실측: NameError).
CATALOG_FILE="$(mktemp)"
trap 'rm -f "$CATALOG_FILE"' EXIT
if ! "$MOUMD" catalog --format json > "$CATALOG_FILE" 2>/dev/null || [ ! -s "$CATALOG_FILE" ]; then
  echo "::error::카탈로그를 얻지 못했다 ($MOUMD catalog --format json) — 판정 불가." >&2
  exit 2
fi

# 문서에서 인용된 명령 경로 vs 카탈로그. 파싱은 python 이 한다 — 셸 정규식으로 마크다운을
# 훑으면 코드펜스/인라인코드 경계를 매번 틀린다.
python3 - "$ROOT" "$CATALOG_FILE" <<'PY' || exit $?
import json, re, sys, pathlib

root = pathlib.Path(sys.argv[1])
catalog = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"))
verbs = {v["path"] for v in catalog.get("verbs", [])}
# 그룹(runnable=false)은 서브커맨드를 요구한다 — 아래 판정의 구분자다.
runnable = {v["path"] for v in catalog.get("verbs", []) if v.get("runnable")}

# floor: 카탈로그가 비면 "위반 0"이 아니라 판정 불가다. 조용한 초록이 가장 위험하다.
if len(verbs) < 20:
    print(f"::error::카탈로그에서 verb 를 {len(verbs)}개만 얻었다(<20) — 판정 불가.", file=sys.stderr)
    raise SystemExit(2)

# `moumd <word> <word> …` 를 코드 안에서만 뽑는다(산문 속 언급은 대상이 아니다).
CODE = re.compile(r"```.*?```|`[^`\n]+`", re.S)
# ★ `moumd` 앞이 경로 문자면 호출이 아니다 — `MOUMD_BIN=/path/to/moumd scripts/x.sh` 의
#   끝 토큰을 명령으로 읽어 거짓 양성을 냈다(실측: 이 저장소 README 에서). 명령 위치는
#   ⚠ 반대로 조이면 백틱 뒤 인라인 예시(`` `moumd catalog …` ``)까지 탈락한다 —
#     실측으로 14→11 로 줄었다. 그래서 **앞 문자 제외**만 하고 위치는 요구하지 않는다.
#     RC 만 보면 이 과잉교정을 놓친다. 매칭 **건수**를 함께 봐야 한다.
CMD = re.compile(r"(?<![/\-\w])moumd\s+((?:[a-z][a-z0-9-]*)(?:\s+[a-z][a-z0-9-]*)*)")
# 경로가 아닌 것들: 전역 플래그·환경변수 대입 등은 첫 토큰에서 걸러진다.
NOT_A_VERB = {"catalog"}  # `catalog` 는 존재하지만 아래에서 일반 규칙으로 확인된다

bad = []
checked = 0
for md in sorted(root.rglob("*.md")):
    if ".git" in md.parts:
        continue
    text = md.read_text(encoding="utf-8")
    for block in CODE.findall(text):
        for m in CMD.finditer(block):
            words = m.group(1).split()
            # ★ 최장 접두 매칭만으로는 **이빨이 없다**(실측: `moumd fleet frobnicate` 가
            #   `fleet` 에 매칭돼 통과했다 — 이 저장소 밖 `check-doc-cli-drift.sh` 가
            #   똑같이 걸렸던 결함이다). 구분자는 **runnable** 이다:
            #     · 매칭된 접두가 runnable 이고 남은 단어가 있으면 → 그건 **인자**다(정상).
            #       예: `moumd pkg install age` 에서 `age`
            #     · 매칭된 접두가 **그룹**(runnable=false)인데 남은 단어가 있으면 →
            #       그 단어는 존재하지 않는 **서브커맨드**다(발명/오타).
            for n in range(len(words), 0, -1):
                cand = " ".join(words[:n])
                if cand not in verbs:
                    continue
                leftover = words[n:]
                if leftover and cand not in runnable:
                    bad.append((md.relative_to(root),
                                f"{cand} {leftover[0]}",
                                f"`{cand}` 는 그룹인데 `{leftover[0]}` 라는 하위 명령이 없다"))
                else:
                    checked += 1
                break
            else:
                bad.append((md.relative_to(root), " ".join(words), "카탈로그에 없는 경로"))

if bad:
    print("::error::카탈로그에 없는 moumd 명령이 문서에 있다 — 오타이거나 발명이다:", file=sys.stderr)
    for path, cmd, why in sorted(set(bad)):
        print(f"   {path}: `moumd {cmd}` — {why}", file=sys.stderr)
    print("   존재의 권위는 `moumd catalog --format json` 이다. 가드를 끄지 말고 예시를 고쳐라.",
          file=sys.stderr)
    raise SystemExit(1)

# 0-매칭 바닥 — 문서를 스캔했는데 확인된 명령이 하나도 없으면 정규식이 깨진 것이다.
if checked == 0:
    print("::error::문서에서 moumd 명령을 하나도 찾지 못했다 — 추출이 깨졌다고 본다(판정 불가).",
          file=sys.stderr)
    raise SystemExit(2)

print(f"OK: 문서의 moumd 명령 {checked}건이 모두 카탈로그에 존재한다 (카탈로그 verb {len(verbs)}개)")
PY
