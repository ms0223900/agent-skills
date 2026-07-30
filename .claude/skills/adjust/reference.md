# GENERATED — do not edit the body by hand.
# Source: dev/shared/stack-detect.source.md
# Regenerate: ./scripts/sync-shared-refs.sh

# 技術棧偵測

套用依賴本參考的 skill 前，先判定目標專案技術棧：

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
