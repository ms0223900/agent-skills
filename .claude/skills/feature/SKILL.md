---
name: feature
description: Guides implementing product features by first assessing complexity and impact, optionally switching to planning mode, then following the user story's 測試策略（Test-First/Test-After/Exploratory，見 user-stories skill）before implementing according to project best practices. Works across Vue, Nuxt, Next.js, and other frontend stacks. Use when the user asks to add, change, or remove a feature, or when a change may have a wide impact.
---

# Feature Implementation Workflow

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

## Instructions

When the user 提出功能相關需求（新增、修改、重構某個 feature）時，遵循以下流程：

1. **確認需求與背景 / Understand requirements**

   - 從使用者輸入中整理出：目標、使用情境、主要使用者、預期行為（可視為 user stories 或 acceptance criteria）。
   - 若資訊不足，先用精簡問題補問，避免一次問太多細節。

2. **評估難易度與影響範圍 / Assess complexity and impact**

   - 依照以下指標粗分為 Small / Medium / Large：
     - Small：影響單一檔案或小範圍、無重要流程變更、幾步即可完成。
     - Medium：影響多個檔案或一整個子模組、需要調整部分流程或資料結構。
     - Large：牽涉多個子系統、跨頁面或跨端（PC / Mobile）、需討論架構與分工。
   - 當評估為 Medium 或 Large 時：
     - **優先切換到 Plan 模式**，先產出技術方案與實作步驟，而不是直接改碼。

3. **Plan 之後的分流 / After planning**

   - 若在 Plan 階段發現：
     - 單一回合內即可完成的範圍 → 可以直接進入實作。
     - 需求過大、牽涉多功能或多階段 → **暫停實作，請使用者協助切分需求**，例如：
       - 拆成多個 user stories / tickets。
       - 決定當前回合只處理其中一小部分（例如僅前端 UI、僅後端 API、僅重構某一層）。

4. **測試策略判斷 / Test Strategy**

   - 若對應的 user story / 任務檔案已有「測試策略」欄位（`/user-stories` 產出，見該 skill 的「測試策略判斷」）→ 直接依該欄位執行：
     - **Test-First**：先確認/撰寫對應的失敗測試（依測試對象呼叫 `/unit-test`、`/vue-integration-test`、`/react-integration-test` 或 `/e2e-test`），跑一次確認是紅燈、且紅燈原因確實是「功能尚未實作」而非測試本身寫錯，再進入 Step 5 實作到轉綠。
     - **Test-After**：先進入 Step 5 完成實作雛形，再依同樣的測試 skill 補測試。
     - **Exploratory**：可先不寫自動化測試，但需在 Step 7 的總結中說明原因。
   - 若任務檔案沒有這個欄位（沒有走 `/user-stories` 流程、或臨時交辦的需求）→ 自行判斷：新功能且邏輯明確可轉成具體 input/output（計算、驗證、狀態轉換）預設 Test-First；UI 排版/文案類預設 Test-After；規格仍不確定的探索性工作可 Exploratory——判準與 `/user-stories` 的「測試策略判斷」一致。
   - 若已有現成的失敗測試（TDD 情境），實作時把該測試當作 spec 的一部分：測試正確表達預期行為就修正實作，不要為了通過而改測試期望值；只有測試本身寫錯時才能改測試，且要說明理由（比照 `/fix` 對 Test 類型錯誤的判準）。

5. **實作階段 / Implementation**

   - 嚴格遵守專案的開發規範與 best practices，例如：
     - 依照 `AGENTS.md`、`.eslintrc.js` 等現有規範。
     - 依偵測到的技術棧，使用對應的元件結構、狀態管理與路由慣例（見 Step 0 對照表）。
     - 使用現有的 API 封裝、錯誤處理與樣式變數等。
   - 優先沿用現有 pattern：參考同類型功能的既有檔案結構與命名方式。
   - 變更範圍較大時，分批提交 patch，避免一次改動過多檔案而難以檢視。

6. **與使用者溝通 / Communication**

   - 在進入實作前，簡要說明：
     - 目前對需求的理解。
     - 預計採用的技術方案或主要修改點。
   - 實作過程中（尤其是有多次 tool call 時），保持簡短更新，說明目前進度與下一步。
   - 完成後，以精簡重點總結變更內容，不需要重貼大量程式碼。

7. **驗證與品質保證 / Validation**

   - 實作後，盡可能：
     - 執行 lint / 單元測試 / E2E 測試（若專案已有相關指令或工具）。
     - 至少在相關檔案上使用 linter 工具確認沒新增明顯錯誤。
   - 確認 Step 4 判定的測試策略確實有落實：Test-First 的測試已轉綠、Test-After 的測試已補上；若是 Exploratory 且最終沒有寫自動化測試，在總結中明確說明原因。
   - 檢查本次新增/修改的註解：只在 WHY 非顯而易見時才留，不解釋 WHAT，不引用當下任務/PR/呼叫端，不寫多段落說明；發現明顯贅述就直接精簡再收尾。
   - 簡述已做過的驗證步驟，以及是否還有需要人工檢查的部分。

8. **何時不要使用這個 skill / When not to use**
   - 純問答型問題（例如「什麼是狀態管理？」）不需要啟動此 skill 的完整流程。
   - 跟 feature 無關的單一小變更（例如修正描述文字 typo），可直接實作，不必進行完整 Plan。

## Examples

- 當使用者說：「請幫我在投注列表加一個新的篩選條件」時：
  - 先判斷可能影響的檔案數量與邏輯複雜度。
  - 若為小改動，可直接簡單說明方案後實作。
  - 若牽涉到多個列表、共同邏輯或跨裝置，就先進 Plan 模式整理方案，再視情況請使用者切分需求。

- 當使用者說：「我要重構整個下注流程，讓 mobile/PC 共用更多邏輯」時：
  - 判定為 Large，一定要先 Plan。
  - 在 Plan 中盤點現有架構、提出分階段調整方案，並請使用者決定第一階段聚焦範圍，再開始實作。

## 做完後

- 若使用者提供的是使用者故事的檔案，請針對使用者故事的檔案進行驗證，確認是否符合使用者故事的內容。若針對功能驗證沒問題，請在使用者故事內的驗證部分打勾。
- 完成後可視情況呼叫 `/refactor-scan`，評估這次改動（及前幾次相關改動）是否已達重構門檻；不會自動執行重構，只在你需要時使用。
- **交付（行動端可審閱）**：驗證通過後呼叫 `/change-report` 產出分層變更摘要。若為 Background／Cloud Agent，或使用者要求「開 PR／交付」，再呼叫 `/pr-delivery` 建立 draft PR（禁止直推 `main`／`master`）。本機互動且未要求開 PR 時，只產出報告並可提示「需要的話可呼叫 `/pr-delivery`」，不要自動 commit。
