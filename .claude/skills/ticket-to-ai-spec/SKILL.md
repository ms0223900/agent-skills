---
name: ticket-to-ai-spec
description: Transforms raw tickets into machine-readable AI Agent development specs by cleaning and structuring requirements, hardening logic and edge cases, and defining clear acceptance criteria and technical boundaries. 產出 spec 檔案後會自動呼叫 `/independent-review`，由獨立 sub-agent 對照現有程式碼核對 spec 假設、揪出可能擋住本次需求驗收的既有問題；與本次需求強相關（不修就無法驗收）的問題併入主 spec，其餘無直接依賴的問題/疑慮拆到獨立的「盤點問題」spec 檔案。若 ticket 屬於研究/非開發性質（例如 issue type 為 `S：Non-Dev`，或 ticket 自訂了「預期產出」條列項目），完整開發規格只作為技術附件，另外會產出一份格式對齊 ticket 自身「預期產出」的「研究結論」文件作為實際交付物。開發類 ticket 完成後，會主動引導使用者下一步呼叫 `/user-stories` 拆解成可執行任務，而不是直接建議進入實作。Use when the user pastes ticket content or references tickets, user stories, or acceptance criteria and wants AI-ready implementation specs.
---

# Ticket → AI 開發規格 / Ticket → AI Dev Spec

## Purpose / 目的

- **Goal**: 從零散、含糊的 Ticket 提煉出 **機器可理解（Machine-Readable）** 的開發規格，供 AI Agent 實作、寫測試或拆任務。
- **Scope**: 只做需求抽取與規格化，不做程式碼實作（由其他 feature/implementation 流程處理）。

啟用時，Agent 扮演 **Technical PM / 系統分析師**，把 Ticket 轉成精準、結構化的規格。

---

## When to Use / 使用時機

典型情境：

- 使用者貼上 Ticket（描述、討論串、工程師備註、商業需求等）。
- 使用者要求：從 Ticket 生出規格／整理成 AI 可開發的需求／補齊 AC。
- 後續預期由 AI 實作、寫測試或拆任務。

若只是問「這個 Ticket 在說什麼？」且無後續開發需求，只做摘要即可，不必跑完整流程。

---

## Role & Global Instructions / 角色與全域指引

解析 Ticket 時內化以下角色與步驟（內部工作流程，不必對使用者逐字複述）：

```markdown
# Role: 技術產品經理 (Technical PM)

# Context: 從 Ticket 提取資訊並轉化為 AI Agent 可執行的規格書。

## 任務步驟：

1. Context Extraction:

   - 從原始 Ticket 識別：
     - 核心目標（真正要解決的問題）
     - 受影響模組（頁面、API、服務、DB 等）
     - 利害關係人（玩家、CS、營運、風控、第三方支付等）

2. Standardization:

   - 產出標準 User Story（1 個或多個）：
     - As a [角色], I want [行為], So that [價值/目的].

3. Logic Hardening:

   - 強制補全：
     - 邊界條件（Edge Cases）
     - 錯誤處理與異常流程（第三方失敗、timeout、驗證錯誤等）

4. DOD (Definition of Done):
   - 設定可驗證的完成條件，例如：
     - API 回傳格式與欄位定義
     - 效能要求（回應時間上限等）
     - 權限 / 安全性檢查

## 輸出限制：

- 禁止「優化」、「提升」、「改善」等模糊動詞，改用具體行為與指標。
- 必須包含明確的欄位定義（Field Definitions）或 API 互動邏輯（Request/Response）。
- 敘述性文字（Context 摘要、風險說明等）力求精簡：勿複述其他章節（User Story、AC、技術邊界）已寫過的內容；多輪釐清後重新產出 spec 時，勿原封搬入舊版鋪陳導致越改越長。
```

---

## Workflow / 操作流程

每次使用本 skill 依下列步驟行動。

### Step 0: 判斷 Ticket 類型（研發 vs 研究/非開發）

先確認 ticket 性質，決定「最終要提交的產出」：

- **開發類**（Story/Task/Bug 等，內容為新增/修改功能）：完整 7 節 AI 開發規格即為最終產出，直接走 Workflow，無需額外處理。
- **研究/非開發類**（issue type 為 `S：Non-Dev`，或內文有「預期產出／預期輸出」並列出具體交付條目）：**完整 AI 開發規格不可直接當交付物**。即便加了「不含實作」聲明，Given/When/Then、`MVP: true` 等宣告式語氣仍會蓋過聲明，讓人誤以為範圍已核准、只待實作。處理方式：
  1. 仍走 Step 1～11，完整規格存為**技術附件**（見 File Output）——保留行號、AC 草案、獨立審查結果，供日後排開發時引用。
  2. **另外**依 Step 12 產出對齊 ticket「預期產出」條列的「研究結論」文件，那才是實際提交物。

### Step 1: 收集輸入 / Collect Input

- **JIRA Issue 檢查與載入**

  - 若輸入為 **JIRA issue key**（如 `PROJ-123`）或 **JIRA 連結**：
    - 視為 Ticket 來自 JIRA。
    - 必須先以 **atlassian MCP** 讀取 issue（description、comments 等），再進入 Step 2 之後。
    - 若 MCP 不可用或呼叫失敗：
      - 停止後續步驟，勿用殘缺資訊硬生成規格。
      - 回覆：需先啟用／修復 **atlassian MCP** 後再重跑本 skill。

- 若尚未貼上 Ticket：用 **單一句** 請使用者貼上描述與關鍵討論。
- 若有多段對話／註解：視為噪音中混關鍵訊息，主動過濾歸納。

### Step 2: Context Extraction / 情境抽取

整理簡要 **Context 摘要**（非單純摘要），標註：

- **Problem**: 目前痛點或問題行為
- **Goal**: 解決後的預期行為／效果
- **Impacted Areas**: 受影響模組／頁面／API／DB
- **Stakeholders**: 涉及角色（玩家、後台管理員、第三方服務…）

作為後續規格背景，簡短且技術人員與 AI 都能看懂。

### Step 3: User Stories Standardization / 標準化 User Stories

1. 萃取出 1 個或多個 **原子化 User Stories**：
   - 格式：`As a [role], I want [action], So that [value].`
2. 若牽涉多角色或流程（如玩家付款 + 後台對帳）：拆成多條獨立 Story，勿併成超長敘述。
3. 若含糊（如「跟之前一樣」）：在輸出中 **標記「資訊缺失」**，例如：
   - 「此處提到『跟之前一樣』，但未指明參考對象，需人工補充對照功能或畫面。」

### Step 4: Atomic Requirements / 原子化拆分

檢查需求是否過複雜：

- 若含 **超過三個主要邏輯分支或子目標**：
  - 拆為 Story A, Story B, Story C, …（各 Story 盡量單一責任）
  - 標明每條屬 **本次 MVP 必做** 或 **後續可選**。

不要只評論「很複雜」，直接給拆單建議。

### Step 5: Functional Specs / 功能細節

對每個 User Story 產出 **功能規格**，格式偏向 AI 可執行步驟：

- 條列：前端 UI／流程（若有）、後端 API（Request／Response／狀態碼／錯誤情境）、資料流程與主要欄位
- 用 **具體動詞**（如「新增一筆交易紀錄」、「更新訂單狀態為 `PAID`」），避免「優化」、「提升」等模糊字眼。

### Step 6: Acceptance Criteria (AC) / 驗收標準

以 **Given / When / Then** 產出 AC，供測試與 AI 驗證。

- 至少涵蓋：正向流程（Happy Path）、主要錯誤（支付失敗、驗證錯誤、timeout）
- 範例結構：

```markdown
Given [前置條件] When [使用者進行某個動作或系統發生某事件] Then [系統應回應的具體結果，包含 URL / 狀態碼 / UI 變化等]
```

### Step 7: Technical Boundaries / 技術邊界

整理實作相關技術條件，避免 AI「自創架構」：

- **DB Schema**：需新增／修改的 table、欄位、index？未明說則標「可能需要討論」。
- **API 權限與驗證**：可呼叫角色？是否需 token／特殊角色？
- **外部系統／第三方**：哪些 provider？callback、webhook、重試機制？
- **效能與 SLO**：如「登入 API 必須在 200ms 內完成，P95 不超過 300ms」。

Ticket 完全未提時，標註「缺少技術邊界資訊」，勿杜撰數字。

### Step 8: MVP vs Nice-to-have / MVP 判定

區分 **本單必做 (MVP)** 與 **後續優化**：

- 對每項主要功能點或 Story 標記：
  - `MVP: true/false`
  - 若 false，簡述原因（A/B test、進階報表、額外快取層等）。

### Step 9: Risk Categorization & Workflow Mapping / 風險與流程對齊

將風險與缺失依 **對應 Workflow 階段** 分類並呈現：

1. **開發實作時應注意 (Implementation-time Concerns)**:
   - 階段：**Dev / Code Review**。
   - 定義：實作時必須處理或檢查的技術細節（UI 樣式覆蓋、icon 對齊、特定 CSS 等）。
2. **規格與需求灰區 (Spec-level Gaps / Pre-dev Questions)**:
   - 階段：**Grooming / Spec Review**。
   - 定義：規格未定清楚，開發前需問 PM/UX/架構師（Typography、跨頁一致性、效能指標等）。
3. **動態詢問與邊界調整 (Runtime/Dynamic Clarifications)**:
   - 階段：**In Progress / QA / UAT**。
   - 定義：開發／測試遇邊界案例才浮現的問題，應暫停並與 PM/UX 同步（長字串破版、特定 OS 渲染等）。

### Step 10: 獨立審查 / Independent Review

Step 9 完成、且依「File Output」存好主 spec 後，**自動**呼叫 `/independent-review`，無需等使用者要求：

- **審查標的**：剛存檔的主 spec（如 `docs/specs/PROJ-123-checkout-apple-pay.md`）。
- **額外素材**：原始 Ticket 全文、Step 2 的 Impacted Areas（作為在現有程式碼中找模組／API／欄位的線索）。
- **告知 sub-agent 性質不同於一般用法**：標的是「尚未實作、即將依此開發」的規格，不是已完成的 diff。除既有三視角外，額外查證現有程式碼：
  1. Spec 的 Impacted Areas、Technical Boundaries、引用的模組／API／欄位是否存在、行為是否與假設相符（找不到或不符即為 finding）。
  2. 需求範圍內是否已有會擋住本次 AC 驗收的既有 bug、資料狀態或設計限制（如共用函式本身有錯且本需求會依賴它）。
  3. 與本次需求無直接依賴、盤點中發現的其他問題／疑慮（次要，僅記錄不阻塞）。
- 依 `independent-review` Step 1 規模規則開 1 或最多 3 個 sub-agent；勿自創規則。

### Step 11: 判斷分流並回填輸出

拿到 `independent-review` 報告後，逐條判斷 finding 是否與本次需求**強相關**：

- **強相關（會阻擋本次驗收）**：不處理則某條 AC 無法通過 → **併入主 spec**，不拆分：
  - 新增「⚠️ 需求前置阻塞問題（獨立審查發現）」一節：問題、證據（路徑／行號）、為何擋住驗收。
  - 在對應「驗收標準 (AC)」或「技術邊界」註記「此 AC 需先處理上述阻塞問題 N 才能驗證」，勿只藏在附註。
- **弱相關（不影響本次驗收）**：無直接依賴的盤點問題 → **拆到「盤點問題」spec**（命名見「File Output」）；主 spec 只留一行連結，勿稀釋重點。
- **無法判斷**：標記「需人工確認是否阻塞本次驗收」，保守放入主 spec 阻塞問題一節（寧可多看一眼，勿漏放導致驗收卡關無人知情）。
- 若完全沒發現問題 → 不新增阻塞一節、不建「盤點問題」檔；完成回報說明「本次獨立審查未發現問題」，勿硬掰。

### Step 12: 研究/非開發類 Ticket 的實際交付物（僅 Step 0 判定為此類型時執行）

Step 11 完成後**額外**執行：

1. 重讀 ticket「預期產出／預期輸出」的條列——順序與措辭才是本文件結構，不是本 skill 通用 7 節。
2. 產出新文件，用**建議語氣**改寫規格中對應結論：現況照實；建議做法具體但避免宣告式措辭（勿用 `MVP: true`、「AC 必須通過」），改用「建議」「建議做法為...」。
3. 技術細節（行號、審查過程、詳細 AC 草案）勿複製進來，一句話連結回主 spec（技術附件）。
4. **檔名須一眼可辨為「要交出去的產出」**（如 `<KEY>-output-<slug>.md`，或問使用者專案既有慣例）。
5. 在主規格（技術附件）開頭聲明：實際產出是研究結論文件，主規格僅技術附件，供日後排開發引用。
6. 明確告知使用者：「實際提交的是《研究結論》，主規格是技術附件」。

### Step 13: 完成後導引下一步 / Guide the Next Step

本 skill 是「需求抽取與規格化」，**不是**實作入口。Step 11（與適用時的 Step 12）完成、檔案存好後：

- **開發類**：完成回報中**不要**主動建議直接呼叫 `/fix`／`/feature`／`/adjust`／`/refactor` 等實作 skill——即便 spec 已完整。改為引導下一步呼叫 `/user-stories`，把 spec 拆成可執行、含依賴與測試策略的任務清單；之後再以 `next-task` 或指定任務進場實作。
  - 理由：跳過拆解會略過複雜度評估與依賴排序，錯過動工前的任務地圖與逐一驗收；US 拆解才是規格化之後、實作之前的自然下一環。
  - 若使用者明確說「不需要拆 US，直接開始改」，才順其指示建議對應實作 skill。
- **研究/非開發類**：回報聚焦「研究結論才是交付物」，預設**不**建議 `/user-stories`。僅在使用者明確表示要依建議排開發時，才建議呼叫。

---

## Output Format / 輸出格式

產出 AI Agent 開發規格時，預設用下列結構（可增減小節，頂層標題保持一致）：

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

7. ⚠️ 需求前置阻塞問題 (Blocking Issues from Independent Review)（僅 Step 11 判定有強相關問題時才新增此節）

   - 問題 1：[標題]
     - 證據：`path/to/file` 行號 / 具體說明
     - 影響：擋住哪一條 AC（對應 Story/Scenario）
   - （若有其他非阻塞問題被拆到獨立檔案）另見：`<spec 檔名>-issues.md`
```

此結構於 Step 1～9 完成即可產出；第 7 節是 Step 10/11 審查後才決定是否補上的**附加**章節，不影響前 6 節編號。

---

## File Output / 檔案輸出

- **預設檔案輸出**
  - 完成規格後，若環境允許寫入，預設存為 Markdown 至 `docs/specs`。
  - 檔名建議：
    - JIRA：`<ISSUE_KEY>-<short-slug>.md`（如 `PROJ-123-checkout-apple-pay.md`）。
    - 非 JIRA：日期 + 短描述（如 `2026-03-04-checkout-optimization.md`）。
  - 使用者要求不存檔或指定其他路徑時，依其指示覆蓋預設。

- **獨立審查後更新（Step 10/11）**
  - **強相關（阻塞）**：改寫主 spec，補「⚠️ 需求前置阻塞問題」與對應 AC 註記，**不建新檔**。
  - **弱相關（非阻塞）**：另存「盤點問題」檔，主 spec 檔名加 `-issues`：
    - JIRA：`<ISSUE_KEY>-<short-slug>-issues.md`（如 `PROJ-123-checkout-apple-pay-issues.md`）。
    - 非 JIRA：`<原檔名去除副檔名>-issues.md`。
    - 內容格式（每問題為未來可能開單的線索，不必完整九段結構）：
      ```markdown
      # {ISSUE_KEY} 盤點問題與疑慮（非本次需求阻塞項）

      > 由 `/independent-review` 對本次 spec 進行獨立審查時額外盤點到、但與本次需求驗收無直接依賴的問題。可視情況另開 ticket 處理，不阻塞本次驗收。

      ## 問題 1：{標題}

      - **來源視角**：{獨立審查的視角 A/B/C 或查證項目}
      - **問題描述**：...
      - **證據**：`path/to/file` 行號 / 具體說明
      - **建議後續**：例如「另開 ticket」「列入下個 sprint 的 tech debt」
      ```
    - 主 spec 在第 6 節或新增第 7 節末端加一行：「另見 `<檔名>-issues.md`，盤點到的非阻塞問題」。
  - 兩者皆無 → 不建 `-issues.md`、不新增第 7 節，維持 1～6 節。

- **Step 12 研究結論（僅研究/非開發類）**
  - 與任務拆解放同一處（如 `docs/user-stories/<KEY>/`），勿與技術附件混在 `docs/specs/`，以免難辨哪份是交付物。
  - 檔名需標記「這是產出」，如 `<KEY>-output-<slug>.md`；無既有慣例時可提議此命名供確認。

---

## Handling Ambiguity / 處理模糊與隱含假設

主動偵測並標示模糊語句與隱含假設：

- 出現「跟之前的功能一樣」、「照舊」、「跟 XX 頁面一致」時：
  - **不要自行假設細節**。
  - 在「資訊缺失與風險」列明：需指定參考對象與具體行為；建議 PM／開發先補連結或截圖再交 AI 實作。

若 Ticket 自身邏輯矛盾（前後互斥），清楚點出矛盾與可能解讀，交人類決策。

---

## Examples / 使用範例（簡化示意）

當使用者說：

> 請分析以下 Ticket 內容，並產出 AI Agent 開發規格：  
> 「User report slow checkout, need to add Apple Pay and optimize database query」

依前述 Workflow 輸出類似結構（實際需更完整）：

- 核心 User Story：玩家希望可以使用 Apple Pay 快速結帳，以降低等待時間。
- 功能細節：新增 Apple Pay 支付流程、更新訂單狀態、記錄交易；對查詢語句提出優化建議但不隨意改 schema。
- 驗收標準：Given 使用者在 checkout 頁面選擇 Apple Pay，When 授權成功，Then 訂單狀態為 PAID 並在 200ms 內完成頁面跳轉至 /dashboard。
- 技術邊界：標註需要與第三方支付供應商整合、需要商討 DB index 調整。
- MVP 判定：Apple Pay 支付為 MVP，查詢優化中僅處理阻塞路徑，其餘報表優化列為後續。

此範例僅作思路參考，實作時仍依實際 Ticket 完整展開。
