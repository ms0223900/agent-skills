---
name: find-component-render-path
description: 分析 UI 元素／組件的渲染邏輯（Vue SFC、Nuxt、Next.js JSX/TSX 等），說明如何觸發、注意事項與優化建議。適用於「這個元素怎麼渲染」、「如何叫出此區塊」等問題。
---

# 查找組件 / 元素渲染路徑

當使用者詢問 **某個元素/class 從哪裡來**、**在 template/JSX 如何渲染**、**如何在實際 App 觸發顯示** 時使用（例如：「`.bet97` 怎麼渲染？我要怎麼在 App 看到它？」）。

回答需 **簡短、有結構、實用**，依專案偵測到的技術棧套用對應慣例。

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

## 使用時機

- 使用者高亮某個 CSS class、DOM 元素或一小段 template/JSX 並詢問：
  - 「這個元素是怎麼渲染出來的？」
  - 「這個 class 在哪裡被用？」
  - 「我要怎麼在實際 App 把它叫出來？」
- 問題與 **可見性 / 渲染條件 / 互動流程** 相關，而非單純樣式調整。

---

## 輸出結構

一律以 **繁體中文** 回答，並保持以下結構：

1. **說明渲染邏輯**
2. **在實際 App 如何叫出，需要哪些步驟**
3. **需要注意的事項**
4. **可以優化的地方**

最終回答使用 `###` 標題（勿使用 `#`），符合本 repo 慣例。

---

## 逐步指引

### 1. 找出目標選擇器 / 元素的所有使用位置

根據選擇器或元素（例如 `.bet97`、某個 `id`、或一小段 template/JSX 片段）：

1. **搜尋程式碼**
   - 使用 `Grep` 搜尋 class/element 名稱，若有指定檔案則限定在該檔案內。
   - 若使用者提供檔案路徑與行數範圍，**優先從該檔案內搜尋**。
2. **確認 UI 標記用法**（依偵測到的棧）
   - Vue/Nuxt：`<template>`、`class=""`/`:class=""`、條件區塊（`v-if`、`v-show`、`v-for`、`v-else-if`）
   - React/Next：JSX/TSX return、`className`、條件渲染（`{cond && …}`、ternary、early return）
   - 同時檢查常見目錄：`src/components/`、`src/views/`、`pages/`、`app/`、`components/`
3. **確認主要渲染點**
   - 若有多個相符處，選擇最接近使用者提供位置、或涵蓋該行為之更高層級 block。

說明時引用程式碼請使用 **CODE REFERENCES** 格式 `startLine:endLine:filepath`，本 repo 規定不使用 language tags。

### 2. 說明渲染邏輯（區塊 1）

清楚描述 **元素如何被渲染**：

- **描述核心 UI block**：指出 class/element 掛在哪個主要容器或 component 上，標出重要的條件渲染與事件綁定。
- **將條件對應到組件狀態**：每個條件來自 local state、derived state（computed/hooks）、global store、父層 props、server props、`searchParams`，或常數/helper。
- **簡要追蹤依賴鏈**：若為 derived state 說明計算邏輯；若為 global store 說明讀取哪個 module/欄位。
- 本區塊需 **有據可依**，以實際找到的程式碼為準。

範例口吻：
- Vue：**「這個 `.xxx` 掛在某某 template 的 `div` 上，並由 `v-if="foo && bar"` 控制顯示。」**
- React/Next：**「這個 `.xxx` 在 `ComponentName` 的 JSX return 中，由 `{foo && bar && <div className="xxx">…</div>}` 控制顯示。」**

### 3. 說明如何在 App 觸發（區塊 2）

將渲染條件轉為 **使用者可執行的步驟**：

1. **將布林條件對應到 UI 狀態**：例如「加入至少 3 個項目到購物車」、「切到串關 tab」、「確認非結果模式」等。
2. **寫出編號的操作步驟**：用簡潔、可執行語言，例如「到 X 頁 → 選 Y → 點 Z」。若部分條件由後端或 config 控制（如 lock flags），需明確說明。
3. **說明展開 / 顯示所需的互動**：若需點擊或 hover 才出現（例如切換 `xxxMode`），說明要點哪個元素（標題列、icon、按鈕），以及預期視覺變化（面板展開、icon 翻轉等）。

目標：**QA 或 PM 依步驟操作即可看見該元素，無須看程式碼。**

### 4. 列出注意事項（區塊 3）

檢查並提及：

- **隱藏條件**：不易察覺的條件渲染、`isLock...`、`hasPermission`、錯誤狀態等 early-return。
- **狀態耦合**：在 lifecycle/effects 中被重置、導致元素意外隱藏的 flags；與其他組件設定的 global store 旗標互動。
- **模式或環境依賴**：桌機/手機 view、panel mode、feature flags、Server vs Client Component 邊界（Next.js）。
- **國際化**：確認可見文字皆使用專案 i18n 慣例，無硬編碼（依 `AGENTS.md` 或偵測到的 i18n 方案）。

本區塊簡短即可，聚焦 **影響最大** 的狀況。

### 5. 提出優化建議（區塊 4）

考量是否可提出 **輕量、高價值** 的優化，至少涵蓋一類：

- **渲染條件**：將複雜條件拆成 named computed/variable；將重複條件群組抽出為單一 derived state 或 helper。
- **邏輯 / 狀態**：確認 toggle（如 `xxxMode`）在父層 panel 切換時有適當 reset；建議用 enum/常數取代 magic literal；評估是否可用衍算取代多個平行 state field。
- **樣式**：將重複樣式抽成共用 class 或 SCSS/CSS module；降低過深巢狀 selector；確認使用專案 theme 變數，建議用 theme 變數取代硬編碼顏色。

提出建議時：明確標示為 **不破壞行為的 refactor** 或可能改變行為；與實際看到的程式碼連結。

---

## 風格與口吻

- **語言**：一律以 **繁體中文** 回答。
- **結構**：使用 `###` 標題、簡短段落，避免長篇文字。
- **程式碼引用**：引用現有程式碼用 repository 規定的 CODE REFERENCE 格式；新增/提案片段才用一般 fenced code block。
- **框架慣例**：依 Step 0 偵測結果套用對應 overlay，不預設單一框架。
- **精簡**：優先說明元素在程式中的來源、如何在 App 看見、可能導致不顯示的狀況、實作可如何更清晰。

若問題較窄（例如「只要告訴我怎麼顯示」），可將區塊 3、4 壓成簡短條列但仍需涵蓋。

---

## 回答範例（結構參考）

1. **說明渲染邏輯**  
   - 說明元素在哪個 template/JSX、掛在什麼容器或 component 上，以及用哪些條件渲染控制，並簡短說明這些條件各自從哪裡來（local state / derived state / store / props / server props 等）。

2. **在實際 App 如何叫出**  
   - 用 3–6 個步驟，描述使用者在畫面上要做哪些操作（到哪個頁面、點哪個 tab、加幾個 item、不能有什麼狀態），最後說明要點哪個區塊才能看到該元素展開。

3. **需要注意的事項**  
   - 列出 2–4 個可能導致看不到該元素的狀況（例如被 lock flag 擋住、有錯誤狀態、panel mode 不對等）。

4. **可以優化的地方**  
   - 提出 1–3 個跟渲染條件、判斷邏輯或樣式相關的優化建議。
