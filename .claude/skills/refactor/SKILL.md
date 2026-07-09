---
name: refactor
description: Guides code refactoring (feature, style, architecture) by assessing scope, planning large changes, and applying SOLID, Clean Code, and Clean Architecture principles. Use when refactoring features, restructuring code, reorganizing architecture, cleaning up styles, extracting components, or improving maintainability.
---

# Refactor Workflow

本 skill 引導功能重構、樣式重構、架構整理等常見 refactor 任務，並嚴格遵循 AGENTS.md、.cursor/rules 及 SOLID / Clean Code / Clean Architecture 原則。

---

## When to Use / 使用時機

- 使用者要求 **refactor**、**重構**、**重寫** 某段程式
- **功能重構**：拆分大組件、抽取共用邏輯、簡化複雜 methods
- **樣式重構**：整理 SCSS、統一變數與 mixin、修正 BEM 或 scoped 問題
- **架構整理**：調整目錄、Vuex 模組拆分、API 與業務邏輯分層
- **可維護性改善**：消除重複程式碼、提升可讀性、降低耦合

**何時不套用本 skill**：純 bug fix、單行 typo、新增功能（應使用 feature skill）。

---

## Instructions / 操作流程

### Step 1: 辨識重構類型與範圍 / Identify Type & Scope

先明確重構類型與影響範圍：

| 類型 | 典型目標 | 常影響範圍 |
|------|----------|------------|
| **Feature** | 拆分組件、抽取邏輯、簡化流程 | `.vue`、`store/`、`api/` |
| **Style** | 變數統一、BEM 調整、scoped 修正 | `*.scss`、`*.vue` 內 `<style>`、`assets/sass/` |
| **Architecture** | 模組邊界、依賴方向、分層 | 跨目錄、`store/`、`api/`、`views/` |

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

- `AGENTS.md`（專案根目錄：技術棧、Vue 2 Options API、Vuex、國際化）
- `.cursor/rules/vue-best-practices.mdc`
- `.cursor/rules/style-and-scss.mdc`
- `.eslintrc.js`

確認專案目錄慣例：`src/views/`、`src/components/`、`src/store/`、`src/assets/`。

### Step 4: 依類型套用原則 / Apply by Type

#### Feature 重構

- **單一職責**：組件只做一件事；過大則拆成子組件或使用 mixins，維持 Vue 2 Options API
- **依賴方向**：View → Store/API，不反向；避免組件直接依賴其他組件內部實作
- **Props / Events**：明確型別、validator；自訂事件用 kebab-case
- **避免**：`v-if`+`v-for` 同元素、在 `created` 與 `watch` 重複呼叫、模板內複雜表達式
- 詳見 [reference.md](reference.md) 的 Feature 章節

#### Style 重構

- **scoped**：組件 `<style>` 必須 `scoped`，`lang="scss"`
- **變數**：複用 `@/assets/sass` 變數；顏色、間距具語意命名
- **BEM-like**：Block、Element（`__`）、Modifier（`--`）；避免過深巢狀
- **Magic numbers**：避免未解釋數字；必要時用註解說明
- 詳見 [reference.md](reference.md) 的 Style 章節

#### Architecture 重構

- **分層**：UI（View/Component）→ 業務邏輯（Store action、computed）→ 資料存取（API）
- **Vuex**：僅用 mutations 改 state；組件只 dispatch actions；非同步只放 actions
- **API**：透過 axios 實例；錯誤處理用 try/catch，考慮 Datadog RUM 埋點
- 詳見 [reference.md](reference.md) 的 Architecture 章節

### Step 5: SOLID / Clean Code 速查

重構時持續自問：

- **S**ingle Responsibility：函式/模組只做一件事
- **O**pen/Closed：易擴充、少改既有程式碼
- **L**iskov Substitution：替換實作時行為一致
- **I**nterface Segregation：介面精簡、不強迫依賴多餘行為
- **D**ependency Inversion：依賴抽象/介面，不依賴具體實作

Clean Code：命名具語意、函式短小、避免巢狀過深、DRY。

### Step 6: 驗證 / Validation

完成後必須：

1. 執行 `npm run lint` 或專案對應的 lint 指令
2. 使用 `ReadLints` 檢查修改過的檔案
3. 簡述變更與驗證結果，標註需人工測試的部分

---

## Refactor Checklist / 重構檢查清單

實作時可依此檢查：

- [ ] 重構類型與範圍已評估（Small/Medium/Large）
- [ ] 若 Medium/Large，已產出 Plan 或與使用者確認切分
- [ ] 符合 AGENTS.md：Vue 2 Options API、scoped、vue-i18n、decimal.js/papaparse 等
- [ ] Vue：`v-for` 有穩定 `:key`、props 有型別/validator、模板無複雜表達式
- [ ] Vuex：只透過 mutations 更新 state、組件只 dispatch actions
- [ ] Style：scoped、SCSS 變數複用、BEM-like、無未解釋 magic numbers
- [ ] ESLint 通過、ReadLints 無新增錯誤

---

## Examples / 範例

**「幫我重構 GameCollapse.vue，拆成小一點的組件」**

→ 辨識為 Feature 重構、可能 Medium；先快速檢視檔案結構，若行數/職責過多，進 Plan 模式提出拆分方案與子組件清單，再分批實作。

**「把這個頁面的 style 整理成用專案變數」**

→ 辨識為 Style 重構、通常 Small；直接讀取 `assets/sass` 變數，替換 hardcode，並明確 scoped、BEM 是否符規。

**「Vuex Game 模組太大，想拆成多個子模組」**

→ 辨識為 Architecture 重構、Large；必須先 Plan：分析 state/actions/mutations 邊界、命名空間、依賴關係，產出拆分步驟與風險，再請使用者確認第一階段範圍。

---

## Additional Resources

- 詳細重構模式與程式碼範例：[reference.md](reference.md)
