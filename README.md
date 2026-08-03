# moumd-skills

**moumd CLI 사용법 스킬 문서 + 프로젝트 템플릿 카탈로그.**

| 디렉토리 | 내용 |
|---|---|
| [`skills/moumd-cli/SKILL.md`](skills/moumd-cli/SKILL.md) | 에이전트가 `moumd` 를 쓰는 법 |
| [`templates/catalog.yaml`](templates/catalog.yaml) | 프로젝트 템플릿 목록 (주소만; 콘텐츠는 각자의 저장소에) |
| [`AGENTS.md`](AGENTS.md) | 이 저장소를 편집하는 에이전트를 위한 지침 |

## 설계에서 가장 중요한 한 가지

**명령이 무엇인지에 대한 권위는 이 저장소가 아니라 `moumd catalog --format json` 이다.**

그래서 스킬 문서는 *"어떤 verb 가 있는지"* 를 나열하지 않고 *"어떻게 찾는지"* 를 가르친다.
verb 목록을 여기 복제하면 그것은 두 번째 출처가 되고, 다음 릴리스에서 조용히 틀려진다 —
그리고 틀린 문서는 없는 문서보다 나쁘다.

가드가 이 규칙을 지킨다:

```bash
scripts/check-no-invented-verbs.sh
# OK: 문서의 moumd 명령 14건이 모두 카탈로그에 존재한다 (카탈로그 verb 262개)
```

문서에 카탈로그에 없는 명령이 등장하면 **실패**한다. `moumd` 가 없으면 통과가 아니라
**exit 2(판정 불가)** 다 — 도구가 없다는 이유로 초록이 되지 않는다.

## 개발

```bash
MOUMD_BIN=/path/to/moumd scripts/check-no-invented-verbs.sh
```

## 라이선스

Apache-2.0
