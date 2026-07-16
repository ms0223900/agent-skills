---
name: refactor
description: Guides code refactoring (feature, style, architecture) by assessing scope, planning large changes, applying SOLID/Clean Code/Clean Architecture principles, and following the task's 測試策略（Test-First/Test-After/Exploratory，見 user-stories skill）when one is specified. Works across Vue, Nuxt, Next.js, and other frontend stacks. Use when refactoring features, restructuring code, reorganizing architecture, cleaning up styles, extracting components, or improving maintainability.
---

# Refactor Workflow

本 skill 引導功能重構、樣式重構、架構整理等常見 refactor 任務，並嚴格遵循 AGENTS.md、.cursor/rules 及 SOLID / Clean Code / Clean Architecture 原則。

---

## When to Use / 使用時機

- 使用者要求 **refactor**、**重構**、**重寫** 某段程式
- **功能重構**：拆分大組件、抽取共用邏輯、簡化複雜 handlers
- **樣式重構**：整理 SCSS/CSS、統一變數與 mixin、修正 BEM 或 scoped/module 問題
- **架構整理**：調整目錄、狀態模組拆分、API 與業務邏輯分層
- **可維護性改善**：消除重複程式碼、提升可讀性、降低耦合

**何時不套用本 skill**：純 bug fix、單行 typo、新增功能（應使用 feature skill）。

**還不確定要不要重構、只想先判斷時機**：用 `/refactor-scan` 先評估這次改動＋前幾次改動是否已達重構門檻；本 skill 假設範圍已經確定，直接進入執行。

---

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

---

## Instructions / 操作流程

### Step 1: 辨識重構類型與範圍 / Identify Type & Scope

先明確重構類型與影響範圍：

| 類型 | 典型目標 | 常影響範圍 |
|------|----------|------------|
| **Feature** | 拆分組件、抽取邏輯、簡化流程 | UI 元件檔、`store/`/`stores/`、`api/` |
| **Style** | 變數統一、BEM 調整、scoped/module 修正 | `*.scss`、`*.css`、元件內 `<style>`、`assets/` |
| **Architecture** | 模組邊界、依賴方向、分層 | 跨目錄、狀態模組、`api/`、`views/`/`pages/`/`app/` |

依以下標準粗分 **Small / Medium / Large**：

- **Small**：單一檔案或小範圍、不影響既有流程、幾步可完成
- **Medium**：多檔案或一整個子模組、需調整資料流或 props 傳遞
- **Large**：跨子系統、跨 PC/Mobile、需討論依賴與分層

### Step 2: 規劃分流 / Plan or Proceed

- **Small**：簡述方案後直接實作
- **Medium / Large**：優先切換到 **Plan 模式**，產出：
  1. 現況與問題
  2. 目標架構與分層
  3. 實作步驟與風險點
  4. 建議分批範圍（若有）

若範圍過大，請使用者協助 **切分為可獨立的小階段**，再分次執行。

### Step 3: 實作前檢查 / Pre-implementation

重構前必讀：

- `AGENTS.md` / `CLAUDE.md`（專案根目錄：技術棧、慣例、國際化）
- `.cursor/rules/` 下與偵測棧相關的 rules（若存在，如 `vue-best-practices.mdc`、`style-and-scss.mdc`）
- `.eslintrc.js` 或 `eslint.config.*`

確認專案目錄慣例：讀取同類型既有檔案所在目錄（如 `src/components/`、`pages/`、`app/`、`store/`、`stores/`）。

### Step 4: 依類型套用原則 / Apply by Type

#### Feature 重構

- **單一職責**：組件只做一件事；過大則拆成子組件，共用邏輯依棧抽取為 composable / hook / mixin
- **依賴方向**：View → Store/API，不反向；避免組件直接依賴其他組件內部實作
- **Props / Events / Callbacks**：明確型別；Vue 自訂事件用 kebab-case；React 用 callback props
- **避免**：條件渲染與列表遍歷寫在同一元素、lifecycle/effect 重複呼叫、模板/JSX 內複雜表達式
- 詳見 [reference.md](reference.md) 的 Feature 章節

#### Style 重構

- **作用域**：依專案慣例使用 scoped、CSS modules 或 styled 方案
- **變數**：複用專案既有 theme/SCSS 變數；顏色、間距具語意命名
- **BEM-like**：Block、Element（`__`）、Modifier（`--`）；避免過深巢狀
- **Magic numbers**：避免未解釋數字；必要時用註解說明
- 詳見 [reference.md](reference.md) 的 Style 章節

#### Architecture 重構

- **分層**：UI（View/Component）→ 業務邏輯（store actions、computed/hooks）→ 資料存取（API）
- **狀態模組**：依偵測棧套用慣例（Vuex：mutations 改 state；Pinia：actions；Zustand/Redux：依專案 pattern）
- **API**：透過專案既有 HTTP client；錯誤處理用 try/catch，考慮 observability 埋點
- 詳見 [reference.md](reference.md) 的 Architecture 章節

### Step 5: SOLID / Clean Code 速查

重構時持續自問：

- **S**ingle Responsibility：函式/模組只做一件事
- **O**pen/Closed：易擴充、少改既有程式碼
- **L**iskov Substitution：替換實作時行為一致
- **I**nterface Segregation：介面精簡、不強迫依賴多餘行為
- **D**ependency Inversion：依賴抽象/介面，不依賴具體實作

Clean Code：命名具語意、函式短小、避免巢狀過深、DRY。

### Step 6: 測試策略判斷 / Test Strategy

若對應的任務檔案已有「測試策略」欄位（`/user-stories` 產出，見該 skill 的「測試策略判斷」）→ 依該欄位執行：

- **Test-First**：若對應測試已存在且應為紅燈（例如 `/next-task` 分派時告知「對應測試已存在於 `{路徑}` 且目前應為紅燈」）→ 把該測試當作 spec 的一部分，重構/調整程式碼至該測試轉綠；測試正確表達預期行為就不要為了通過而修改測試期望值，只有測試本身寫錯時才能改，且需說明理由（比照 `/fix` 對 Test 類型錯誤的判準）。若測試尚未存在，先依測試對象呼叫 `/unit-test`／`/vue-integration-test`／`/react-integration-test`／`/e2e-test` 撰寫，確認紅燈後再重構到綠燈。
- **Test-After**：先完成 Step 4 的重構，再呼叫對應測試 skill 補測試。
- **Exploratory**：可不寫自動化測試，但需在 Step 7 的總結中說明原因。

若任務檔案沒有這個欄位（純重構、無對應 US 流程）→ 維持既有慣例：重構前後跑一次既有測試確認沒有引入回歸即可，不強制新增測試。

### Step 7: 驗證 / Validation

完成後必須：

1. 執行 `npm run lint` 或專案對應的 lint 指令
2. 使用 `ReadLints` 檢查修改過的檔案
3. 確認 Step 6 判定的測試策略確實有落實（Test-First 已轉綠、Test-After 已補測試，或 Exploratory 已說明原因）
4. 檢查本次新增/修改的註解：只在 WHY 非顯而易見時才留，不解釋 WHAT，不引用當下任務/PR/呼叫端，不寫多段落說明；發現明顯贅述就直接精簡
5. 簡述變更與驗證結果，標註需人工測試的部分
6. **交付（行動端可審閱）**：驗證通過後呼叫 `/change-report` 產出分層變更摘要。若為 Background／Cloud Agent，或使用者要求「開 PR／交付」，再呼叫 `/pr-delivery` 建立 draft PR（禁止直推 `main`／`master`）。本機互動且未要求開 PR 時，只產出報告並可提示「需要的話可呼叫 `/pr-delivery`」，不要自動 commit。

---

## Refactor Checklist / 重構檢查清單

實作時可依此檢查：

- [ ] 重構類型與範圍已評估（Small/Medium/Large）
- [ ] 若 Medium/Large，已產出 Plan 或與使用者確認切分
- [ ] 若任務有「測試策略」欄位，已依 Test-First/Test-After/Exploratory 執行；沒有的話已跑既有測試確認無回歸
- [ ] 符合偵測到的技術棧慣例與 `AGENTS.md`（樣式作用域、i18n、專案工具庫等）
- [ ] UI：列表有穩定 key、props 有型別、模板/JSX 無複雜表達式
- [ ] 狀態：依棧慣例更新 state（Vuex mutations / Pinia actions / Zustand set 等）
- [ ] Style：作用域正確、變數複用、BEM-like、無未解釋 magic numbers
- [ ] ESLint 通過、ReadLints 無新增錯誤
- [ ] 新增/修改的註解已精簡（只留 WHY，無 WHAT 說明、任務引用、多段落）

---

## Examples / 範例

**「幫我重構 GameCollapse 組件，拆成小一點的組件」**

→ 辨識為 Feature 重構、可能 Medium；先快速檢視檔案結構，若行數/職責過多，進 Plan 模式提出拆分方案與子組件清單，再分批實作。

**「把這個頁面的 style 整理成用專案變數」**

→ 辨識為 Style 重構、通常 Small；直接讀取專案 theme/SCSS 變數，替換 hardcode，並確認作用域與 BEM 是否符規。

**「Game 狀態模組太大，想拆成多個子模組」**

→ 辨識為 Architecture 重構、Large；必須先 Plan：分析 state/actions 邊界、命名空間、依賴關係，產出拆分步驟與風險，再請使用者確認第一階段範圍。

---

## Additional Resources

- 詳細重構模式與程式碼範例：[reference.md](reference.md)
