---
name: quick-debug
description: >-
  Guides rapid triage of bugs and unexpected behavior in this Vue 2 codebase:
  pinpoints likely failure layers with code citations, lists operational risks,
  and suggests concrete optimizations. Use for general debugging (wrong state,
  API errors, flaky UI, performance). For questions that are only about where a
  class/element renders or how to reveal it in the app, use find-component-render-path.
---

# 快速除錯（通用）

當使用者要 **快速收斂問題層級**、**對應到程式或請求證據**、**指出潛在風險**、**給出可落地的優化** 時套用。若題目單純是「某個 class／元素怎麼渲染、如何在 App 叫出來」，請優先使用 `find-component-render-path`。

# Quick debug (general) — agent instructions

Follow this skill when the user wants to **narrow down where a bug lives**, **what could break next**, and **what to improve**, beyond pure render-path questions.

Assume this repo: **Vue 2 options API, Vuex 3, Vue Router 3, Element-UI (desktop), SASS/SCSS, vue-i18n (`$t`), axios API layer** per `AGENTS.md`.

**Split with `find-component-render-path`:** that skill focuses on **visibility / render conditions / user steps to see UI**. This skill covers **behavior, data flow, API, routing, lifecycle, races, performance**, and similar issues.

## When to use

- Wrong UI or flow, console/Network errors, flaky behavior, mobile-only vs desktop-only, regressions after changes.
- User provides **error text, HAR/screenshot hints, repro steps, or suspect files** (prioritize those signals).

## Answer shape (Traditional Chinese for the final reply)

Reply in **Traditional Chinese**, section titles with `###` only (no `#`), in this order:

1. **問題定位摘要** — 1–3 sentences: most likely layer (file/module/data path).
2. **根因或可疑點（附證據）** — tie to real code or requests; cite existing code as **CODE REFERENCES** `startLine:endLine:filepath` (no language tag), per repo rules.
3. **如何驗證／重現** — shortest steps for QA/dev; call out account flags, `--mode mobile`, or `VUE_APP_*` when relevant.
4. **潛在風險** — what could still break if shipped/extended as-is (use checklist below).
5. **優化建議** — actionable, phased items; label refactors that might change behavior.

If evidence is thin, start **問題定位摘要** with **「假設：…」** and list the **minimum extra info** needed (e.g., one Network response body, Vue DevTools state snapshot).

## Agent workflow (required)

### 1. Classify

| Type | Clues | Look first |
|------|-------|------------|
| Render / visibility | missing UI | template, `v-if`/`v-show`, `computed`; pure “where does it render?” → `find-component-render-path` |
| Interaction / events | no handler feedback | `@` bindings, methods, parent intercept, disabled state |
| Data / state | wrong numbers/lists | `data`, `computed`, Vuex modules, props flow, `watch`, clone pitfalls |
| Async / race | flaky, fast navigation | `async`/`await` order, in-flight requests, updates after destroy, debounce |
| API | 4xx/5xx, shape mismatch | `src/api` wrappers, real URL/query vs backend contract |
| Routing | wrong screen, guards | `vue-router`, `beforeEach`, dynamic params |
| Styles / RWD | one platform only | scoped order, mobile vs desktop entry components |
| Performance | jank, memory | large lists, deep `watch`, ECharts/third-party teardown (`AGENTS.md`) |

### 2. Gather evidence

1. Known symbol/string → `Grep` (methods, Vuex actions, API functions).
2. Behavioral description only → `SemanticSearch`.
3. Read surrounding files → `Read` on component/mixin/store; trace **call chain** (template → method → api → commit).
4. If useful → recent `git diff` / blame context for regressions.

### 3. Repo guardrails (quick)

- Vue 2 only (no Composition API); lifecycle/reactivity limits matter.
- User-visible copy should go through `$t`; hardcoded strings may be spec gaps, not “logic bugs”.
- Money/math paths may need `decimal.js` where the module already uses it.
- Mobile build reads `.env.mobile`; env can explain divergent behavior.

### 4. Risks and optimizations (feed sections 4–5 of the user-facing answer)

**潛在風險** — pick items **relevant to this case**:

- Missing null/empty guards causing silent failure.
- Duplicate requests without cancel/loading → races.
- Timers/listeners/ECharts instances not cleared before `destroyed`; Vuex vs localStorage/cache drift; stale UI after auth/expiry changes.
- Security: untrusted data into `v-html`, unsafe URL assembly (only if code suggests it).

**優化建議** — be **specific** (e.g., “extract this `v-if` into `isXxxVisible` computed”) not vague. Mark **behavior-changing** ideas. Reuse optimization themes from `find-component-render-path` (named computeds, single source of truth, shared styles) and extend with API retry/bounds, Datadog RUM hooks when pertinent (`AGENTS.md`).

## Tone

- Short, structured: conclusion first, then proof.
- Every suspicion should anchor to a line/snippet or request; avoid pure speculation.
- Technical terms (Vuex, props) may stay English; explanatory sentences in Traditional Chinese.

If the user only wants “which line is wrong”, still include **潛在風險** and **優化建議** as 2–4 bullets each.
