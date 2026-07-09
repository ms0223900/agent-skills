---
name: quick-debug
description: >-
  Guides rapid triage of bugs and unexpected behavior across frontend stacks
  (Vue, Nuxt, Next.js, React, etc.): pinpoints likely failure layers with code
  citations, lists operational risks, and suggests concrete optimizations. Use
  for general debugging (wrong state, API errors, flaky UI, performance). For
  questions that are only about where a class/element renders or how to reveal it
  in the app, use find-component-render-path.
---

# 快速除錯（通用）

當使用者要 **快速收斂問題層級**、**對應到程式或請求證據**、**指出潛在風險**、**給出可落地的優化** 時套用。若題目單純是「某個 class／元素怎麼渲染、如何在 App 叫出來」，請優先使用 `find-component-render-path`。

# Quick debug (general) — agent instructions

Follow this skill when the user wants to **narrow down where a bug lives**, **what could break next**, and **what to improve**, beyond pure render-path questions.

**Split with `find-component-render-path`:** that skill focuses on **visibility / render conditions / user steps to see UI**. This skill covers **behavior, data flow, API, routing, lifecycle, races, performance**, and similar issues.

## 技術棧偵測（Step 0）

套用本 skill 前，先判定目標專案技術棧：

1. 讀 `package.json` dependencies（`vue`、`nuxt`、`next`、`react`、狀態庫等）
2. 讀 `AGENTS.md` / `CLAUDE.md`（若存在）
3. 檢查框架設定：`nuxt.config.*`、`next.config.*`、`vite.config.*`、`vue.config.js`
4. 將結果記在內部上下文，再套用下方框架對照 overlay；**優先遵守專案既有規範與同目錄既有 pattern**，無文件時才用偵測到的框架預設慣例

| 抽象概念 | Vue 2 | Nuxt 3 | Next.js (App Router) |
|----------|-------|--------|----------------------|
| 元件狀態 | Options `data`/`computed`/`watch` | Composition `ref`/`computed`/`watch` | hooks / `useState` |
| 全域狀態 | Vuex | Pinia | Zustand / Redux / server state |
| 條件渲染 | `v-if` / `v-show` | 同左 | `{cond && …}` / early return |
| 路由與守衛 | vue-router | Nuxt routes / middleware | App Router / middleware |
| 共用邏輯 | mixins | composables | hooks / shared modules |
| 卸載清理 | `beforeDestroy` / `destroyed` | `onUnmounted` | `useEffect` cleanup |
| i18n | vue-i18n `$t` | `@nuxtjs/i18n` | `next-intl` 等（依專案） |

## When to use

- Wrong UI or flow, console/Network errors, flaky behavior, mobile-only vs desktop-only, regressions after changes.
- User provides **error text, HAR/screenshot hints, repro steps, or suspect files** (prioritize those signals).

## Answer shape (Traditional Chinese for the final reply)

Reply in **Traditional Chinese**, section titles with `###` only (no `#`), in this order:

1. **問題定位摘要** — 1–3 sentences: most likely layer (file/module/data path).
2. **根因或可疑點（附證據）** — tie to real code or requests; cite existing code as **CODE REFERENCES** `startLine:endLine:filepath` (no language tag), per repo rules.
3. **如何驗證／重現** — shortest steps for QA/dev; call out account flags, build modes, or env vars（如 `VUE_APP_*`、`NEXT_PUBLIC_*`）when relevant.
4. **潛在風險** — what could still break if shipped/extended as-is (use checklist below).
5. **優化建議** — actionable, phased items; label refactors that might change behavior.

If evidence is thin, start **問題定位摘要** with **「假設：…」** and list the **minimum extra info** needed (e.g., one Network response body, React DevTools / Vue DevTools state snapshot).

## Agent workflow (required)

### 1. Classify

| Type | Clues | Look first |
|------|-------|------------|
| Render / visibility | missing UI | template/JSX, conditional rendering, derived state; pure “where does it render?” → `find-component-render-path` |
| Interaction / events | no handler feedback | event bindings (`@click` / `onClick`), handlers, parent intercept, disabled state |
| Data / state | wrong numbers/lists | local state, derived state, global store/hooks, props flow, watchers/effects, clone pitfalls |
| Async / race | flaky, fast navigation | `async`/`await` order, in-flight requests, updates after unmount, debounce |
| API | 4xx/5xx, shape mismatch | API wrappers (`src/api`, `src/services`, route handlers), real URL/query vs backend contract |
| Routing | wrong screen, guards | router config, middleware, `beforeEach`, dynamic params, `searchParams` |
| Styles / RWD | one platform only | CSS modules / scoped styles, responsive breakpoints, mobile vs desktop entry |
| Performance | jank, memory | large lists, deep watchers, chart/third-party teardown (`AGENTS.md`) |

**Framework overlay（依 Step 0 結果套用）**

- Vue：`v-if`/`v-show`、`computed`、`$store`、vue-router
- Nuxt：composables、`useFetch`/`useAsyncData`、middleware、Pinia
- Next.js：Server/Client Components boundary、`useEffect`、`searchParams`、middleware、RSC cache

### 2. Gather evidence

1. Known symbol/string → `Grep` (handlers, store actions, API functions).
2. Behavioral description only → `SemanticSearch`.
3. Read surrounding files → `Read` on component/hook/store; trace **call chain** (UI → handler → api → state update).
4. If useful → recent `git diff` / blame context for regressions.

### 3. Repo guardrails (quick)

- Follow detected stack conventions; do not assume a specific framework API unless evidence supports it.
- User-visible copy should go through project i18n helpers; hardcoded strings may be spec gaps, not “logic bugs”.
- Money/math paths may need precision libs (e.g., `decimal.js`) where the module already uses them.
- Env-specific builds (`.env.*`, `--mode`) can explain divergent behavior.

### 4. Risks and optimizations (feed sections 4–5 of the user-facing answer)

**潛在風險** — pick items **relevant to this case**:

- Missing null/empty guards causing silent failure.
- Duplicate requests without cancel/loading → races.
- Timers/listeners/chart instances not cleared on unmount; global store vs localStorage/cache drift; stale UI after auth/expiry changes.
- Security: untrusted data into raw HTML (`v-html` / `dangerouslySetInnerHTML`), unsafe URL assembly (only if code suggests it).

**優化建議** — be **specific** (e.g., “extract this condition into `isXxxVisible` computed/variable”) not vague. Mark **behavior-changing** ideas. Reuse optimization themes from `find-component-render-path` (named derived state, single source of truth, shared styles) and extend with API retry/bounds, observability hooks when pertinent (`AGENTS.md`).

## Tone

- Short, structured: conclusion first, then proof.
- Every suspicion should anchor to a line/snippet or request; avoid pure speculation.
- Technical terms (props, hooks, store) may stay English; explanatory sentences in Traditional Chinese.

If the user only wants “which line is wrong”, still include **潛在風險** and **優化建議** as 2–4 bullets each.
