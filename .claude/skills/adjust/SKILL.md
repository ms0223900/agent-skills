---
name: adjust
description: 用於補充調整既有功能：先更新 US、評估測試策略（Test-First / Test-After / 不寫測試需說明原因）、再實作、跑測試直到全過、最後驗收 US。不強制測試先行，但一定要交代測試何時補、補在哪裡，若不寫測試也要說明原因。適用 Vue、Nuxt、Next.js 等前端專案。使用時機：使用者提出補充需求或功能調整，例如「補一下 XXX」、「調整 XXX 的行為」、「這邊需要多支援 YYY」。
---

# 補充調整工作流程（Adjust Workflow）

## 目標

當使用者提出補充需求或功能調整時，依序完成：**US 更新 → 測試補充 → 功能實作 → 測試通過 → 驗收 US**。

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

## 執行流程

### Step 1：找出對應 US 目錄

1. 讀取目前的 git branch 名稱（`git branch --show-current`）。
2. 從 branch 名稱中擷取 ticket ID，例如 `feature/SPRD-965` → `SPRD-965`。
3. **US 目錄慣例不只一種**，依 `next-task`／`us-acceptance-check` 的預設，優先檢查 `docs/user-stories/{TICKET_ID}*/`；若不存在才檢查 `docs/specs/{TICKET_ID}/us/`。兩者都不存在時，看專案內既有的其他 ticket 目錄實際用哪一種慣例，沿用該慣例；都沒有既有慣例可循時，預設用 `docs/user-stories/{TICKET_ID}/`（與 `next-task`／`us-acceptance-check` 的預設一致）。列出找到的目錄下所有 US 檔案。
4. 根據使用者描述的調整內容，判斷：
   - 哪些既有 US 需要修改（調整驗收條件或描述）
   - 是否需要新增一份 US（若調整範圍超出現有 US 涵蓋）

---

### Step 2：更新或新增 US

依照以下原則調整 US，與 `/user-stories` skill 保持一致：

- **調整既有 US**：只補充或修改受影響的驗收條件，不大改未受影響的部分。
- **精簡原則**：US 常會歷經多次 `/adjust` 迭代，每次修改容易在既有敘述上疊加新的鋪陳，而不是取代舊的講法。調整時檢查受影響段落有沒有因此變得重複/囉唆，順手精簡措辭（但不要因此動到本次沒有調整到的其他段落）；不確定是否要大動既有措辭時，優先用 `/doc-trim` 事後統一處理，本步驟只需確保自己新增/修改的部分本身精簡。
- **新增 US**：若需求超出現有 US，依照 `US-0X` 序號新增一份，格式如下：

```markdown
### US-0X：{標題}

**作為** {角色}
**我想要** {功能}
**以便** {目的}

---

**輸入格式**：...

**輸出格式**：...

**驗收條件**：
- [ ] ...

**依賴關係**：...

**優先級**：P0 / P1 / P2
**相關功能**：...
```

- 存檔路徑：`docs/specs/{TICKET_ID}/us/US-0X-{slug}.md`
- 命名序號接續現有最大編號。

---

### Step 3：評估測試策略（不強制測試先行，但一定要交代清楚）

**不再無條件「先補測試、再實作」**——依 `/user-stories` 的「測試策略判斷」準則決定：

| 情境 | 策略 |
|---|---|
| 調整的是新增邏輯或修改既有邏輯（計算、驗證規則、狀態轉換），且行為可轉成具體 input/output | **Test-First** |
| 純 UI 排版/樣式/文案調整 | **Test-After**（或評估後不寫自動化測試） |
| 規格仍在確認、調整方向可能還會變 | 可先不寫測試（**Exploratory**） |

若對應 US 檔案已有「測試策略」欄位，直接採用該欄位的判定，不用重新評估。

**規則：不論選哪一種，都要在調整說明/回覆中交代「測試何時補、補在哪裡」；若判定不寫自動化測試，必須明確說明原因（例如純樣式調整、範圍太小、規格仍在確認等），不能省略不談。**

- **若判定 Test-First**：
  1. 搜尋與被修改功能相關的既有測試檔（`*.test.*`/`*.spec.*`）；存在則補充 test case，不存在則依專案慣例新建。
  2. 撰寫會反映本次調整行為的測試，跑一次確認是紅燈，且紅燈原因確實是「行為尚未調整」而非測試本身寫錯。
  3. 進入 Step 4，實作至該測試轉綠。
- **若判定 Test-After**：先進入 Step 4 完成調整，再回頭依上述搜尋/命名原則補測試，安排在 Step 5 跑測試之前完成。
- **若判定不寫自動化測試**：直接進入 Step 4，在 Step 6 驗收前的回報中清楚寫明原因；不要因為省事就默默跳過、也不要事後才臨時決定不寫。

測試範圍原則（不論何時補測試都適用）：只測試本次調整涉及的功能邏輯；以「正向行為」為主，不要過度測試錯誤邊界或各種極端情境（除非 US 驗收條件明確要求）；測試命名清楚反映 US 驗收條件。

---

### Step 4：實作功能

依照 `/feature` skill 的實作原則進行：

- Small 變更：直接說明方案後實作。
- Medium / Large：先盤點影響範圍，必要時切換 Plan 模式。
- 嚴格遵守專案規範（依 Step 0 偵測到的技術棧慣例、現有 API 封裝、樣式變數等）。
- 優先沿用現有 pattern，不引入新的抽象。
- 若 Step 3 判定 Test-First 且已有失敗測試：把該測試當作 spec 的一部分，測試正確表達預期行為就修正實作；只有測試本身寫錯時才能改測試，且要說明理由（比照 `/fix` 對 Test 類型錯誤的判準）。

---

### Step 5：跑測試直到全部通過

若 Step 3 判定為 Test-After，先在此步驟前補齊測試。若判定不寫測試，本步驟只需確認既有測試無新增失敗（迴歸檢查），不需要新增測試。

先偵測專案測試 runner（`package.json` scripts 或設定檔）：

| Runner | 常見指令 |
|--------|----------|
| Jest | `npx jest {測試檔路徑} --no-coverage` |
| Vitest | `npx vitest run {測試檔路徑}` |
| Playwright | 依 `/e2e-test` skill 撰寫與執行（僅當 US 明確要求 E2E） |

- 若有失敗，診斷原因並修正（程式碼或測試），直到全部通過。
- 不要為了讓測試通過而降低測試覆蓋範圍或跳過斷言。
- 檢查本次新增/修改的註解：只在 WHY 非顯而易見時才留，不解釋 WHAT，不引用當下任務/PR/呼叫端，不寫多段落說明；發現明顯贅述就直接精簡。

---

### Step 6：驗收 US

執行 `/us-acceptance-check`，對 Step 1 中判定受影響的所有 US 進行驗收，確認驗收條件清單與驗收說明皆已更新。

---

## 注意事項

- US 目錄慣例依專案而定：優先 `docs/user-stories/{TICKET_ID}*/`，其次 `docs/specs/{TICKET_ID}/us/`（見 Step 1）；同一個專案內找到既有慣例後就沿用，不要混用兩種路徑。
- 測試只確保功能範圍內的行為正確，不做「防禦性全面覆蓋」。
- 測試先或後由 Step 3 判定，不再無條件先寫測試；但「不寫測試」永遠要附理由，不可以悄悄跳過不提。
- 若評估後發現調整幅度過大，暫停實作，先與使用者確認切分範圍。
- 完成後可視情況呼叫 `/refactor-scan`，評估這次調整（及前幾次相關改動）是否已達重構門檻；不會自動執行重構，只在你需要時使用。
- **交付（行動端可審閱）**：Step 6 驗收通過後呼叫 `/change-report` 產出分層變更摘要。若為 Background／Cloud Agent，或使用者要求「開 PR／交付」，再呼叫 `/pr-delivery` 建立 draft PR（禁止直推 `main`／`master`）。本機互動且未要求開 PR 時，只產出報告並可提示「需要的話可呼叫 `/pr-delivery`」，不要自動 commit。
