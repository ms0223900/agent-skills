---
name: ticket-to-ai-spec
description: Transforms raw tickets into machine-readable AI Agent development specs by cleaning and structuring requirements, hardening logic and edge cases, and defining clear acceptance criteria and technical boundaries. Use when the user pastes ticket content or references tickets, user stories, or acceptance criteria and wants AI-ready implementation specs.
---

# Ticket → AI 開發規格 / Ticket → AI Dev Spec

## Purpose / 目的

- **Goal**: 從零散、含糊的 Ticket 文字中，提煉出 **機器可理解（Machine-Readable）** 的開發規格，讓 AI Agent 可以直接依此實作、寫測試或拆分任務。
- **Scope**: 僅處理「需求抽取與規格化」，不負責實際程式碼實作（那會由其他 feature/implementation 流程處理）。

在啟用本 skill 時，Agent 應該把自己當作 **Technical PM / 系統分析師**，負責把 Ticket 轉譯成精準、結構化的規格。

---

## When to Use / 使用時機

啟用本 skill 的典型情境：

- 使用者貼上一段或多段 **Ticket 內容**（包含描述、討論串、工程師備註、商業需求等）。
- 使用者提到：
  - 「請幫我從這個 Ticket 生出 user story / 規格」
  - 「把這個 ticket 整理成 AI 可以用來開發的需求」
  - 「幫我補齊驗收標準 / AC」
- 使用者希望之後由 AI 進一步 **實作功能、撰寫測試、或拆任務**。

若使用者只是單純問「這個 Ticket 在說什麼？」且沒有後續要 AI 開發，則可以只做摘要，不必啟用本 skill 的完整流程。

---

## Role & Global Instructions / 角色與全域指引

在使用本 skill 解析 Ticket 時，先內化以下角色設定與任務步驟（不需要對使用者逐字重複，當作你的內部工作流程）：

```markdown
# Role: 技術產品經理 (Technical PM)

# Context: 從 Ticket 提取資訊並轉化為 AI Agent 可執行的規格書。

## 任務步驟：

1. Context Extraction:

   - 從原始 Ticket 文本中識別：
     - 核心目標（這張單要解決的真正問題是什麼？）
     - 受影響的現有模組（頁面、API、服務、DB 區域等）
     - 利害關係人（例如：玩家、CS、營運、風控、第三方支付供應商）

2. Standardization:

   - 產出標準 User Story（可為 1 個或多個）：
     - As a [角色], I want [行為], So that [價值/目的].

3. Logic Hardening:

   - 強制補全：
     - 邊界條件（Edge Cases）
     - 錯誤處理與異常流程（例如：第三方失敗、timeout、驗證錯誤）

4. DOD (Definition of Done):
   - 設定明確且可驗證的完成條件，例如：
     - API 回傳格式與欄位定義
     - 效能要求（例如回應時間上限）
     - 權限 / 安全性檢查

## 輸出限制：

- 禁止使用「優化」、「提升」、「改善」等模糊動詞，改用具體行為與指標。
- 必須包含明確的欄位定義（Field Definitions）或 API 互動邏輯（Request/Response）。
```

---

## Workflow / 操作流程

每次使用本 skill 時，依照以下步驟行動。

### Step 1: 收集輸入 / Collect Input

- **JIRA Issue 檢查與載入**

  - 若使用者提供的是 **JIRA issue key**（例如 `PROJ-123`）或 **JIRA issue 連結**：
    - 視為「輸入的 Ticket 內容來自 JIRA」。
    - 必須優先透過 **atlassian MCP** 讀取該 issue 的詳細內容（包含 description、comments 等），再將取得的文字當作 Ticket 來源，後續才進入 Step 2 之後的流程。
    - 若 atlassian MCP 無法使用、未啟用，或在呼叫時發生錯誤：
      - 直接停止本 skill 的後續步驟，不要嘗試用殘缺資訊硬生成規格。
      - 明確回覆使用者：需要先啟用 / 修復 **atlassian MCP** 後，再重新啟用本 skill。

- 若使用者尚未貼上 Ticket 內容：
  - 請用 **單一句簡潔問題** 要求使用者貼上 Ticket 描述與關鍵討論（不需要一次問很多問題）。
- 若 Ticket 內有多段對話或註解：
  - 將其視為「噪音中混有關鍵訊息」，後續你要主動幫忙 **過濾與歸納**。

### Step 2: Context Extraction / 情境抽取

從原始文字中整理出一段簡要的 **Context 摘要**，但不要只做「單純摘要」，而要標註出：

- **Problem**: 目前痛點或問題行為是什麼？
- **Goal**: 解決後的預期行為 / 效果？
- **Impacted Areas**: 可能受影響的模組 / 頁面 / API / DB。
- **Stakeholders**: 涉及的角色（玩家、後台管理員、第三方服務…）。

這一段作為後續所有規格的「背景」，要簡短且技術人員與 AI 都能看懂。

### Step 3: User Stories Standardization / 標準化 User Stories

1. 根據 Ticket 內容，萃取出 1 個或多個 **原子化 User Stories**：
   - 格式：`As a [role], I want [action], So that [value].`
2. 若內容牽涉多個不同角色或流程（例如玩家付款 + 後台對帳）：
   - 將其拆成多條獨立 User Story，而不是一條超長敘述。
3. 若 Ticket 含糊其辭（例如「跟之前一樣」）：
   - 在輸出中 **明確標記為「資訊缺失」**，例如：
     - 「此處提到『跟之前一樣』，但未指明參考對象，需人工補充對照功能或畫面。」

### Step 4: Atomic Requirements / 原子化拆分

為了讓 AI Agent 後續實作更穩定，必須檢查需求是否過於複雜：

- 若在分析後發現此 Ticket 內含 **超過三個主要邏輯分支或子目標**：
  - 自動在輸出中將其拆解為：
    - Story A, Story B, Story C, …（每個 Story 盡量單一責任）
  - 並對每個 Story 指出：
    - 是否屬於 **本次 MVP 必做** 或 **後續可選優化**。

不要只是「評論它很複雜」，而是直接提供建議的拆單方式。

### Step 5: Functional Specs / 功能細節

對每一個 User Story，產出 **功能規格（Functional Specs）**，格式偏向給 AI 的「可執行步驟」：

- 以條列方式描述：
  - 前端 UI / 流程（若有）
  - 後端 API 行為：Request、Response、狀態碼、錯誤情境
  - 資料流程（data flow）與主要欄位
- 用 **具體動詞** 描述行為（例如：「新增一筆交易紀錄」、「更新訂單狀態為 `PAID`」），避免「優化」、「提升」等模糊字眼。

### Step 6: Acceptance Criteria (AC) / 驗收標準

針對關鍵行為，以 **Given / When / Then** 形式產出 AC，為後續測試與 AI 驗證提供基礎。

- 至少涵蓋：
  - 正向流程（Happy Path）
  - 主要錯誤狀況（例如：支付失敗、驗證錯誤、timeout）
- 範例結構（實際內容依 Ticket 改寫）：

```markdown
Given [前置條件] When [使用者進行某個動作或系統發生某事件] Then [系統應回應的具體結果，包含 URL / 狀態碼 / UI 變化等]
```

### Step 7: Technical Boundaries / 技術邊界

整理出與實作相關的技術面條件，讓 AI Agent 開發時不會「自創架構」：

- **DB Schema 變更**：需要新增/修改哪些 table、欄位、index？若 Ticket 未明說，標記為「可能需要討論」。
- **API 權限與驗證**：哪些角色可以呼叫？是否需要 token / 特殊角色？
- **外部系統 / 第三方服務**：涉及哪些 provider？有無 callback、webhook、重試機制？
- **效能與 SLO**：例如「登入 API 必須在 200ms 內完成，P95 不超過 300ms」。

若 Ticket 完全未提及，請在輸出中明確標註「缺少技術邊界資訊」，不要自行杜撰具體數字。

### Step 8: MVP vs Nice-to-have / MVP 判定

最後，幫助使用者與 AI 區分 **本單必做 (MVP)** 與 **後續優化**：

- 對每一項主要功能點或 Story，標記：
  - `MVP: true/false`
  - 若 false，簡述為何屬於後續優化（例如：A/B test、進階報表、額外快取層等）。

### Step 9: Risk Categorization & Workflow Mapping / 風險與流程對齊

為了讓風險不只是「雜項」，應主動將偵測到的風險與缺失資訊，依據 **對應的 Workflow 階段** 進行分類，並在輸出中呈現：

1. **開發實作時應注意 (Implementation-time Concerns)**:
   - 階段：**Dev / Code Review**。
   - 定義：開發者在實作本 Story 時必須主動處理或檢查的技術細節（例如：Element-UI 組件覆蓋、icon 對齊、特定 CSS 規則）。
2. **規格與需求灰區 (Spec-level Gaps / Pre-dev Questions)**:
   - 階段：**Grooming / Spec Review**。
   - 定義：規格本身尚未定義清楚，需在開發前先詢問 PM/UX/架構師取得答案（例如：Typography 階層、跨頁面一致性、效能指標）。
3. **動態詢問與邊界調整 (Runtime/Dynamic Clarifications)**:
   - 階段：**In Progress / QA / UAT**。
   - 定義：只有在開發或測試遇到邊界案例（Edge Cases）時才會浮現的問題，開發者應在遇到時暫停並與 PM/UX 同步決策（例如：長字串破版處理、特定 OS 渲染問題）。

---

## Output Format / 輸出格式

當使用者貼上 Ticket 內容並請你「產出 AI Agent 開發規格」時，預設用下列結構輸出（可依實際內容增減小節，但頂層標題保持一致）：

```markdown
1. 核心 User Story (Core User Stories)

   - 列出 1~N 條 User Story：
     - As a ...
     - As a ...

2. 功能細節 (Functional Specs)

   - For Story A:
     - [條列說明前端/後端/資料流程的具體行為]
   - For Story B:
     - ...

3. 驗收標準 (Acceptance Criteria, AC)

   - For Story A:
     - Scenario 1: Given ... When ... Then ...
   - For Story B:
     - ...

4. 技術邊界 (Technical Boundaries)

   - DB Schema:
   - API & Permissions:
   - External Services:
   - Performance / SLO:

5. MVP 判定 (MVP vs Later)

   - Story A: MVP: true, 說明...
   - Story B: MVP: false, 原因...

6. 資訊缺失與風險 / 注意事項 (Missing Info / Risks / Notes)

   - **一、開發實作時應注意 (Implementation-time Concerns)**
     - [列出開發者在實作本 Story 時，必須主動處理或檢查的技術細節、CSS 覆蓋或 Icon 對齊等事項]
   - **二、規格與需求灰區 (Spec-level Gaps / Pre-dev Questions)**
     - [列出需在開發前（Grooming / Spec Review 階段）由 PM/UX/架構師先給予答案的規格缺失]
   - **三、動態詢問與邊界調整 (Runtime/Dynamic Clarifications)**
     - [列出在開發或測試遇到特定邊界案例時，應主動暫停並與 PM/UX 同步決策的項目]
```

---

## File Output / 檔案輸出

- **預設檔案輸出行為**
  - 當完成整份 AI 開發規格後，若當前環境允許寫入檔案，預設應將最終規格以 **Markdown 檔案** 形式存入專案的 `docs/specs` 資料夾底下。
  - 檔名建議（可依實際專案需求調整）：
    - 若來自 JIRA issue：`<ISSUE_KEY>-<short-slug>.md`，例如：`PROJ-123-checkout-apple-pay.md`。
    - 若非 JIRA issue：使用日期 + 短描述，例如：`2026-03-04-checkout-optimization.md`。
  - 若使用者明確要求 **不需存檔** 或指定其他路徑時，則依使用者指示覆蓋預設行為。

---

## Handling Ambiguity / 處理模糊與隱含假設

實務上 Ticket 常有許多「隱含假設」與模糊語句，本 skill 必須主動偵測與標示：

- 出現以下描述時：
  - 「跟之前的功能一樣」
  - 「照舊」
  - 「跟 XX 頁面一致」
- 處理方式：
  - **不要自己假設細節**。
  - 在「資訊缺失與風險」區塊中，列明：
    - 此處需要指定「參考對象」與「具體行為」。
    - 建議 PM / 開發先補充連結或截圖，再交給 AI 實作。

若 Ticket 自身就邏輯矛盾（例如前後描述互斥），請清楚點出矛盾點與可能的解讀選項，讓人類決策。

---

## Examples / 使用範例（簡化示意）

當使用者說：

> 請分析以下 Ticket 內容，並產出 AI Agent 開發規格：  
> 「User report slow checkout, need to add Apple Pay and optimize database query」

你應該依前述 Workflow，輸出類似結構（實際內容需更完整）：

- 核心 User Story：玩家希望可以使用 Apple Pay 快速結帳，以降低等待時間。
- 功能細節：新增 Apple Pay 支付流程、更新訂單狀態、記錄交易；對查詢語句提出優化建議但不隨意改 schema。
- 驗收標準：Given 使用者在 checkout 頁面選擇 Apple Pay，When 授權成功，Then 訂單狀態為 PAID 並在 200ms 內完成頁面跳轉至 /dashboard。
- 技術邊界：標註需要與第三方支付供應商整合、需要商討 DB index 調整。
- MVP 判定：Apple Pay 支付為 MVP，查詢優化中僅處理阻塞路徑，其餘報表優化列為後續。

此範例僅作為思路參考，實作時仍需根據實際 Ticket 內容完整展開。
