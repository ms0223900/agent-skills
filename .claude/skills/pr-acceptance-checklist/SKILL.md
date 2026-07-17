---
name: pr-acceptance-checklist
description: 依 user stories 與 git 變更產出 PR／MR 驗收清單。支援兩種模式：for-review（審閱者完整 checklist，預設）與 for-pr-body（作者交付用的精簡驗證／風險區塊，供 change-report／PR 描述嵌入）。使用時機：檢查 PR 有無超出 scope、生驗收清單、或為 PR 摘要補「驗證方式」區塊。
---

# PR / MR 驗收清單 Skill

## Purpose / 目的

- **Goal**: 針對一個 PR / MR 或 feature branch，依據「使用者故事 / 規格」與「git 變更」產出系統化的驗收清單，並初步判斷：
  - 是否「該做的都有做」。
  - 是否「有動到不該動的地方」。
- **Scope**: 著重在 **程式層面的靜態檢查與 checklist 生成**（檔案範圍、API 呼叫、DOM/事件、樣式、config 等），不代替實際人工或自動化測試，但會協助明確列出需要測的項目。
- **不負責**開 PR 或寫 30 秒導讀 → 那些是 `/pr-delivery`／`/change-report`。

---

## 輸出模式 / Modes

執行前先選定模式（可在使用者指令中寫 `for-review`／`for-pr-body`，或依呼叫情境推斷）：

| 模式 | 何時用 | 輸出形態 |
|------|--------|----------|
| **`for-review`**（**預設**） | Reviewer／QA 要核對「該做／不該做」；「幫我看這個 PR」「生驗收清單」 | 完整可勾選 Acceptance Checklist + 風險與建議測試 |
| **`for-pr-body`** | 作者交付：`/change-report` 需要「驗證結果／風險」素材；「幫我補 PR 描述的驗證區塊」 | **精簡**區塊（見 Step 4b），可直接嵌入 PR body／change-report，**不要**輸出完整 reviewer checklist |

推斷規則：

- 由 `/change-report` 呼叫、或使用者說「給 PR 描述／摘要用」→ `for-pr-body`。
- 其餘未指明 → `for-review`。
- 兩種模式共用 Step 1～3 的蒐集與對應；差在 Step 4／5 的輸出長度與對象。

---

## When to Use / 使用時機

在下列情境啟用本 skill：

- 使用者已經完成一個 feature branch / PR / MR，希望：
  - 檢查實作是否符合 user stories / spec。
  - 檢查是否有「超出範圍」的變更。
  - 產出一份可以貼在 PR 描述或 review comment 裡的「驗收 checklist」（`for-review`）。
  - 或只要精簡的驗證／風險文字給 PR 摘要用（`for-pr-body`）。
- 使用者問類似：
  - 「幫我看這個 PR 有沒有動到不該動的地方？」
  - 「這幾個 user stories 有沒有都實作到了？」
  - 「幫我生一份這個 PR 的驗收清單。」

不需要啟用本 skill 的情境：

- 純描述型問題（例如「這支 function 在做什麼？」）沒有明確與 PR / MR 驗收相關。
- 單一極小改動（例如只修一個文案 typo）且使用者沒有要求 checklist。
- 只要「作者視角」的分層變更摘要（30 秒摘要／檔案清單／Mermaid）且**不需**補驗證對照 → 只用 `/change-report`；要開 PR → `/pr-delivery`。若 change-report 需要更完整的「驗證方式」對照 US，再以 `for-pr-body` 呼叫本 skill。

---

## High-level Workflow / 高層級流程

> 下列步驟是 Agent 的內部工作流程，不需要逐字回覆給使用者，但輸出內容要反映這些步驟的結果。

0. **選定模式**（`for-review` 或 `for-pr-body`）
1. **收集上下文 / Collect Context**
2. **盤點變更範圍 / Inventory Changes**
3. **對應 user stories 與變更 / Map Stories ↔ Changes**
4. **依模式產出**：`for-review` → Step 4a 完整 checklist；`for-pr-body` → Step 4b 精簡驗證區塊
5. **風險與建議測試**（`for-review` 寫完整；`for-pr-body` 併入 4b 的短列表，不另開長篇）

以下詳述每個步驟。

---

## Step 1: 收集上下文 / Collect Context

在開始分析前，須盡量掌握以下資訊（若使用者已提供，則不重複詢問，只是內部整理）：

- **Branch / PR / MR 資訊**
  - 目前所在分支名稱（例如 `feature/SPRD-662`）。
  - 基準分支（通常是 `develop` / `main` / `master` 等）。
- **需求來源**
  - user stories / spec 檔案路徑（例如 `docs/user-stories/...`、`docs/specs/...`）。
  - 這些檔案內的 **目標、驗收條件 (AC)**。

在 Cursor 內，優先使用以下工具與資訊來源：

- `Shell`:
  - `git status -sb`
  - `git diff --name-status <base>...HEAD`
- `Read`:
  - user stories / spec 檔案。
  - 變更中的關鍵檔案（component、API、views、config 等）。

> 若基準分支不明，預設優先使用 `origin/develop` 或專案慣用的 base 分支；無法存取 remote 時，使用本地 `develop` 作為 base。

---

## Step 2: 盤點變更範圍 / Inventory Changes

目標：**清楚知道這次 PR / MR 動了哪些檔案，類型為何，是否合理落在預期範圍內。**

操作要點：

1. 使用 `git diff --name-status <base>...HEAD` 取得變更檔案列表。
2. 將檔案分類，例如：
   - **Domain / Feature Code**：`src/views/**/*`, `src/components/**/*`, `src/store/**/*`, `src/api/**/*`, `src/config/**/*`。
   - **Documentation / Specs**：`docs/specs/**/*`, `docs/user-stories/**/*`。
   - **Tooling / AI / Config**：`.cursor/**/*`, `AGENTS.md`, lint 設定等。
3. 判斷是否有 **不在需求上下文內** 的檔案被修改：
   - 例如：和該 feature 無關的 service、其它產品線的頁面等。

輸出時，請用簡短條列方式總結：

- 哪些檔案類型被修改（component / API / view / config / docs / AI skill 等）。
- 是否有「看起來不該包含在此 ticket 內」的變更（如果有，要點名並標示為 ❓ / needs review）。

---

## Step 3: 對應 user stories 與變更 / Map Stories ↔ Changes

目標：**針對每一個 user story / 子任務，對應到實際程式碼變更，判斷「有做到 / 可能沒做到 / 無法從 code 判斷」。**

具體作法：

1. **從 user stories / spec 中抽出核心點**，至少包含：
   - 功能目標（例如「移除按鈕」、「移除 API」、「調整排版」、「驗證其它功能仍正常」）。
   - 驗收條件 (Acceptance Criteria, AC)。
2. 針對每個 story，檢查對應檔案與變更：
   - **UI / DOM / Template 相關**：
     - 檢查按鈕 / 元件 DOM 是否有被刪除或新增。
     - 檢查事件綁定 (`@click`, `v-on:click`) 是否對應修改或清除。
   - **JS / TS / 邏輯相關**：
     - 檢查 methods / computed / data 中與該功能相關的函數或 state 是否被加入 / 移除 / 調整。
   - **API 相關**：
     - 檢查 `src/api/**/*` 是否有新增 / 移除與該功能對應的 API wrapper。
     - 檢查 view/component 中對這些 API 的呼叫是否一致地更新或移除。
   - **樣式 / 排版相關**：
     - 檢查 `.scss` / `.css` 中是否有與該區塊相關的 class 被新增 / 調整 / 移除。
   - **Config / 版本號 / Flag**：
     - 若需求有版本或 feature flag，確認是否有相應更新。
3. 對每個 story，產出簡短結論：
   - ✅ 明確有對應變更，且看起來符合描述。
   - ⚠️ 變更部分符合，但有尚未覆蓋的情境（簡述）。
   - ❓ 從程式碼無法判斷（通常是純測試或營運流程）。

> 重點是「story ↔ code」對應關係的清晰度，而不是重貼大段 code。

---

## Step 4a: `for-review` — 完整驗收清單

目標：**產出一份可以直接貼在 review comment（或 PR 討論）的「可勾選驗收清單」。**  
此模式面向**審閱者**，預設不要塞進 PR 描述的最上方（會排擠 30 秒摘要）；若要附在 PR，建議當 comment 或摺疊區塊。

輸出格式建議（Markdown）：

```markdown
### PR / MR Acceptance Checklist

- **Scope & Files**
  - [ ] 變更檔案皆落在預期模組範圍內（無明顯超出 scope 的修改）。
  - [ ] docs/spec（若有）已與實作一致更新。

- **User Story Alignment**
  - **US-XXX / Story A** – [短描述]
    - [ ] 對應的 UI / template 變更存在且合理。
    - [ ] 對應的事件處理 / methods 已更新或移除。
    - [ ] 對應的 API 呼叫 / wrapper 已更新或移除。
  - **US-YYY / Story B** – [短描述]
    - [ ] ...

- **API & Data Flow**
  - [ ] 所有與此功能相關的 API wrapper（`src/api/**/*`）都有對應的使用方更新。
  - [ ] 不再使用的 API wrapper 已被移除，且無殘留呼叫點。

- **UI / Layout / Styling**
  - [ ] 受影響區塊的 DOM 結構與 class 命名符合專案慣例。
  - [ ] 關鍵區塊（例如投注項目）在 PC / Mobile 下皆不會跑版（字過長時能正常換行或截斷）。
  - [ ] 不再使用的樣式（class / keyframes 等）已清理。

- **Regression & Side Effects**
  - [ ] 舊有核心流程（例如下注、登入、開關購物車）未被非必要改動。
  - [ ] 若有版本號 / config 更新，其值與本次 release 計畫對齊。

- **Tests & Verification (to be run manually/CI)**
  - [ ] 基本 lint / 單元測試 / E2E（若有）通過。
  - [ ] 根據 user stories 的 AC，已在測試環境手動驗證關鍵情境。
```

實際輸出時，請：

- **用專案實際 story 編號與簡述替換 `US-XXX` / `Story A`**。
- 將已由靜態分析「幾乎可以確定已滿足」的項目，附上說明（例如「從 `ListCardItem` 元件的 diff 可見按鈕 DOM 與事件皆已刪除」）。

---

## Step 4b: `for-pr-body` — 精簡驗證區塊（給作者／change-report）

目標：**產出可直接嵌進 `/change-report`「驗證結果」「風險與待確認」的短區塊**，方便行動端先掃讀。不要輸出完整 Scope／UI／API 長 checklist。

輸出格式（Markdown）：

```markdown
### 驗證方式（對照 US）

- **US-XXX** – {一句：靜態分析結論 ✅／⚠️／❓}；建議驗證：{一句或「已由單元測試覆蓋」}
- **US-YYY** – …

### 超出範圍？

- {無／列出可疑檔案或變更}

### 風險與待確認（精簡）

- {最多 3～5 點；無則寫「無」}
```

約束：

- 每個 US 一行結論，不要展開成多層 checkbox。
- 已跑過的指令（lint／test）用一行帶過，細節留給 change-report 的「驗證結果」。
- 無法從 code 判斷的 AC 標 ❓，並寫「需實測／日誌」。

---

## Step 5: 風險與建議測試項目 / Risks & Test Suggestions

**`for-review`**：對 reviewer／QA 提供完整「哪裡需要特別測」與「可能的風險點」。

- **Potential Risks / 可能風險**
  - 例如：「`OddsHistory` 頁面雖然入口已被移除，但若有人直接敲 URL 仍會進入空圖表頁面，產品需決定是否接受。」
  - 例如：「此變更移除了 `/GameInfo/GameInfoLog` API 呼叫，若後端仍被其它入口使用，需再確認是否完全停用。」
- **Recommended Manual Test Scenarios / 建議手動測試情境**
  - 以 Given/When/Then 或簡短條列，直接從 user stories 的 AC 衍生，用實際頁面名稱／按鈕名描述。
  - 明確標示 PC／Mobile 是否都要測。

**`for-pr-body`**：不要另開本節長文；風險已含在 Step 4b。若呼叫端是 `/change-report`，把 4b 全文交回即可。

---

## Implementation Notes / 實作注意事項

在 Cursor 內實作本 skill 時，請特別注意：

- 優先使用工具而非猜測：
  - 用 `Shell` 的 `git diff` 查變更範圍。
  - 用 `Read` 檢視關鍵檔案（component、API、view、config、docs）。
  - 必要時用 `Grep` 搜尋 API 名稱、class 名稱，確認是否仍有殘留。
- 回覆給使用者時：
  - **不要貼過長的 code 區塊**，只需用簡短 code reference 或文字描述指出關鍵變更位置。
  - `for-review`：以 **checklist 為主體**，並附上一段簡短 summary（例如「所有程式變更皆落在購物車與水位歷程模組內，無其它模組被動到。」）。
  - `for-pr-body`：只交 Step 4b 短區塊，開頭標明模式，方便 `/change-report` 合併。
- 若從程式碼角度無法驗證某些 AC（例如「後端 log 是否正確記錄」、「GA 事件是否上報」），要明確標註為「需實際測試 / 日誌驗證」，不要假設已完成。
- 與 `/change-report`／`/pr-delivery`：`for-pr-body` 餵摘要；`for-review` 適合 PR 開完後當 review comment。

---

## Example: 基於 SPRD-662 的通用化示意

以下是一個基於「移除某功能及相關 API / UI / 排版調整」的通用化示例（實際使用時請改成當次 PR 的實際名稱與內容）：

```markdown
### PR / MR Acceptance Checklist (Example)

- **Scope & Files**
  - [x] 變更集中在購物車相關 component（`ListCardItem` / `.scss`）、對應 API (`api/game.js`) 與相關 view (`OddsHistory`)、版本號設定 (`config/index.js`)。
  - [x] 無修改到與購物車無關的其它頁面或服務。

- **User Story Alignment**
  - **US-001 – 移除某功能按鈕**
    - [x] 按鈕 DOM 與點擊區域已從 template 中刪除。
    - [x] 按鈕專用樣式（class、keyframes 等）已從樣式檔中移除。
  - **US-002 – 移除點擊事件與彈窗邏輯**
    - [x] 對應的 `@click` 綁定與 methods 已從 component 中移除。
    - [x] 不再需要的 helper import 已刪除。
  - **US-003 – 移除相關 API 呼叫**
    - [x] API wrapper 已從 `api` 模組移除。
    - [x] 所有對該 API 的呼叫點皆已刪除，程式中不再出現該 API 名稱或 URL。
  - **US-004 – 調整排版**
    - [x] 文字區塊改為允許換行與自動斷行，避免跑版。
    - [x] 關鍵資訊區塊在 PC / Mobile 下皆採用左對齊、間距一致。
  - **US-005 – 回歸測試（購物車核心功能正常）**
    - [ ] 需人工 / 自動化實測：輸入金額、切換單項/過關、確認下注、購物車開關、刪除投注項目。

- **API & Data Flow**
  - [x] 不再使用的水位歷程 API 已停止呼叫。
  - [x] 其它 API（下注、查詢等）未被誤改。

- **UI / Layout / Styling**
  - [x] 相關 SCSS 變更僅影響目標區塊，未波及全局樣式。

- **Regression & Side Effects**
  - [x] 除版本號外無修改 config 中其它行為設定。

- **Tests & Verification**
  - [ ] 在測試環境完成 PC / Mobile 的手動驗證（依 user stories AC）。
```

此示例僅作為風格與結構的參考；實際使用時，請根據當次 PR / MR 的 user stories 與變更內容動態調整勾選項與說明。

