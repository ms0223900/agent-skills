---
name: ticket-to-ai-spec
description: Transforms raw tickets into machine-readable AI Agent development specs by cleaning and structuring requirements, hardening logic and edge cases, and defining clear acceptance criteria and technical boundaries. 產出 spec 檔案後會自動呼叫 `/independent-review`，由獨立 sub-agent 對照現有程式碼核對 spec 假設、揪出可能擋住本次需求驗收的既有問題；與本次需求強相關（不修就無法驗收）的問題併入主 spec，其餘無直接依賴的問題/疑慮拆到獨立的「盤點問題」spec 檔案。若 ticket 屬於研究/非開發性質（以 issue type 如 `S：Non-Dev` 為主；僅有「預期產出」條列不足以判定），完整開發規格只作為技術附件，另外會產出一份格式對齊 ticket 自身「預期產出」的「研究結論」文件作為實際交付物。開發類 ticket 完成後，會主動引導使用者下一步呼叫 `/user-stories` 拆解成可執行任務，而不是直接建議進入實作。Use when the user pastes ticket content or references tickets, user stories, or acceptance criteria and wants AI-ready implementation specs.
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

解析 Ticket 時內化以下設定（內部工作流程；步驟細節見下方 Workflow，不必對使用者逐字複述）：

```markdown
# Role: 技術產品經理 (Technical PM)

# Context: 從 Ticket 提取資訊並轉化為 AI Agent 可執行的規格書。

## 任務步驟大綱（細節見下方 Workflow，勿在此重複展開）：

1. 收集輸入 → 判定類型（開發 / 研究·非開發）
2. 規格化
   ├─ Context（Problem / Goal / Impacted Areas / Stakeholders）
   ├─ User Stories（依角色）→ 複雜度再拆
   ├─ Functional Specs → AC（含錯誤＋邊界）→ Technical Boundaries
   ├─ MVP 判定 → 風險分類
   └─ 存檔主 spec
3. 獨立審查 → 阻塞併入主 spec / 弱相關拆 -issues
4. （僅研究·非開發）產出「研究結論」交付物
5. 導引下一步：開發類 → /user-stories；研究類 → 交研究結論

## 輸出限制：

- 禁止「優化」、「提升」、「改善」等模糊動詞，改用具體行為與指標。
- 必須分析資料／API 層並給出明確結論：要嘛寫出欄位定義或 Request/Response，要嘛明確寫「本次無資料層／API 變動，理由：…」。禁止用「不適用」靜默跳過，也禁止杜撰不存在的欄位。
- 敘述性文字（Context 摘要、風險說明等）力求精簡：勿複述其他章節（User Story、AC、技術邊界）已寫過的內容；多輪釐清後重新產出 spec 時，勿原封搬入舊版鋪陳導致越改越長。
```

---

## Workflow / 操作流程

每次使用本 skill 依下列步驟行動。

### Step 0: 判斷 Ticket 類型（研發 vs 研究/非開發）

**取得 Ticket 內容後才執行**（尚無內容時先做 Step 1）。本步驟決定「最終要提交的產出」。

- **開發類**（issue type 為 Story/Task/Bug 等，或內容明確為新增/修改功能）：主規格（見 Output Format：第 0～6 節，視審查結果可附加第 7 節）即為最終產出，直接走 Workflow。
- **研究/非開發類**：
  - **主判準**：issue type 明確為 `S：Non-Dev`（或專案等同的研究/非開發類型）。
  - **輔助訊號**（不足以單獨判定）：內文有「預期產出／預期輸出」條列——許多開發單也會這樣寫，**不可**僅憑此判為研究類。
  - **模糊時**：用 **單一句** 問使用者「這張是開發實作單，還是研究／非開發交付？」，確認前不要自行選分支。
  - 判定為研究／非開發後：**完整 AI 開發規格不可直接當交付物**（Given/When/Then、`MVP: true` 等宣告式語氣易讓人誤以為已核准待實作）。處理方式：
    1. 仍走 Step 1～11，完整規格存為**技術附件**（見 File Output）。
    2. **另外**依 Step 12 產出對齊 ticket「預期產出」條列的「研究結論」，那才是實際提交物。

### Step 1: 收集輸入 / Collect Input

- **JIRA Issue 檢查與載入**

  - 若輸入為 **JIRA issue key**（如 `PROJ-123`）或 **JIRA 連結**：
    - 視為 Ticket 來自 JIRA。
    - 必須先以 **atlassian MCP** 讀取 issue（description、comments 等），再進入後續步驟。
    - 若 MCP 不可用或呼叫失敗：
      - **使用者未貼任何 Ticket 正文** → 停止後續步驟；回覆需先啟用／修復 **atlassian MCP**，或改貼完整 Ticket（含關鍵討論）。
      - **使用者已貼 Ticket 正文** → 可繼續，但必須在 Context（第 0 節）與完成回報中**明示**：「atlassian MCP 無法讀取，本次僅依使用者貼文生成，可能遺漏 JIRA comments／後續澄清」。若貼文看起來只有摘要、不像含討論串，用單一句請使用者確認「是否已含關鍵留言／結論」後再繼續。

- 若尚未貼上 Ticket（且非走 JIRA key 路徑）：用 **單一句** 請使用者貼上描述與關鍵討論。
- 若有多段對話／註解：視為噪音中混關鍵訊息，主動過濾歸納。

### Step 2: Context Extraction / 情境抽取

整理簡要 **Context 摘要**，寫入最終 spec 的**第 0 節**（勿只留在對話裡）：

- **Problem**: 目前痛點或問題行為
- **Goal**: 解決後的預期行為／效果
- **Impacted Areas**: 受影響模組／頁面／API／DB（獨立審查會依此查程式碼；只列線索，勿複述 Functional Specs 細節）
- **Stakeholders**: 涉及角色（玩家、後台管理員、第三方服務…）

簡短且技術人員與 AI 都能看懂。

### Step 3: User Stories Standardization / 標準化 User Stories

依**角色／流程**拆出原子化 User Stories：

1. 格式：`As a [role], I want [action], So that [value].`
2. 多角色或流程（如玩家付款 + 後台對帳）→ 拆成多條，勿併成超長敘述。
3. 含糊（如「跟之前一樣」）→ 標記「資訊缺失」，例如未指明參考對象需人工補充。

### Step 4: Atomic Requirements / 原子化拆分

在 **Step 3 已產出的每條 Story 之上**再檢查複雜度（兩軸不同：Step 3＝誰；Step 4＝單一角色下範圍多大）：

- 若某條含 **超過三個主要邏輯分支或子目標** → 再拆成子 Story（命名保留角色歸屬，如「Story 2a／2b」或「管理員-折扣規則／管理員-優惠碼」），勿只評論「很複雜」。
- **不要**在此步驟做 MVP 標記——統一留到 Step 8，避免兩次判定不一致。

### Step 5: Functional Specs / 功能細節

對每個 User Story 產出 **功能規格**，格式偏向 AI 可執行步驟：

- 條列：前端 UI／流程（若有）、後端 API（Request／Response／狀態碼／錯誤情境）、資料流程與主要欄位
- 用 **具體動詞**（如「新增一筆交易紀錄」、「更新訂單狀態為 `PAID`」），避免「優化」、「提升」等模糊字眼。

### Step 6: Acceptance Criteria (AC) / 驗收標準

以 **Given / When / Then** 產出 AC，供測試與 AI 驗證。**Logic Hardening（強制）**：

- 正向流程（Happy Path）
- 主要錯誤（支付失敗、驗證錯誤、timeout 等）
- **邊界條件**（空值／極值、重複提交、金額為 0 等——不只「錯誤」，凡可能破壞流程的 edge case 都要補）

範例結構：

```markdown
Given [前置條件] When [使用者進行某個動作或系統發生某事件] Then [系統應回應的具體結果，包含 URL / 狀態碼 / UI 變化等]
```

### Step 7: Technical Boundaries / 技術邊界

整理實作相關技術條件，避免 AI「自創架構」：

- **DB Schema**：需新增／修改的 table、欄位、index？未明說則標「可能需要討論」。
- **API 權限與驗證**：可呼叫角色？是否需 token／特殊角色？
- **外部系統／第三方**：哪些 provider？callback、webhook、重試機制？
- **效能與 SLO**：僅在 Ticket 有給指標時寫入具體數字；未提則標「缺少效能指標」，**勿杜撰**。

與輸出限制一致：涉及資料／API 則給定義；確認無變動則寫明理由。Ticket 完全未提時標「缺少技術邊界資訊」，勿杜撰。

### Step 8: MVP vs Nice-to-have / MVP 判定

區分 **本單必做 (MVP)** 與 **後續可選**（本 skill 內唯一做 MVP 標記的步驟）：

- 對每項主要功能點或 Story 標記 `MVP: true/false`
- 若 false，簡述原因（A/B test、進階報表、額外快取層等）

### Step 9: Risk Categorization & Workflow Mapping / 風險與流程對齊

將風險與缺失依 **對應 Workflow 階段** 分類，寫入 Output Format 第 6 節（三類標題見該節模板；此處只規定何時分類）：

1. **開發實作時應注意** — 階段 Dev / Code Review（實作時必須處理的技術細節）
2. **規格與需求灰區** — 階段 Grooming / Spec Review（開發前需問 PM/UX/架構師）
3. **動態詢問與邊界調整** — 階段 In Progress / QA / UAT（遇邊界案例才浮現，應暫停同步）

### Step 10: 獨立審查 / Independent Review

Step 9 完成、且依「File Output」存好主 spec 後，**預設自動**呼叫 `/independent-review`，無需等使用者要求。

**僅允許的窄條件可略過或降級**（不可因「看起來簡單／信心高」跳過）：

- **無程式碼環境可查**（無 repo／無法讀取專案原始碼）→ 不做對照程式碼的 IR；在完成回報註明「環境限制，未執行對照程式碼的獨立審查」。若仍能做，可只做規格自洽檢查，並標明涵蓋率折扣。
- **重跑且 Ticket／需求結論無實質變更**（僅排版、措辭精簡、路徑微調等）→ 可不重跑 IR；保留既有第 7 節／`-issues.md`，並在回報說明「內容無實質變更，沿用既有審查結果」。有實質變更 → 必須重跑 IR 並更新阻塞／盤點結果。

其餘情況一律執行：

- **審查標的**：剛存檔的主 spec（如 `docs/specs/PROJ-123-checkout-apple-pay.md`）。
- **額外素材**：原始 Ticket 全文；並指示 sub-agent 以 spec **第 0 節 Impacted Areas** 與 Technical Boundaries 為線索（已寫進檔案，勿依賴對話記憶）。
- **告知 sub-agent 性質不同於一般用法**：標的是「尚未實作、即將依此開發」的規格，不是已完成的 diff。除既有三視角外，額外查證現有程式碼：
  1. Spec 假設**既有**的模組／API／欄位：是否存在、行為是否相符。找不到或不符 → finding。若 spec 明確寫的是**本次新建**（尚不存在於 codebase）→ **不是** finding，勿把「新功能尚未實作」報成缺陷。
  2. 需求範圍內是否已有會擋住本次 AC 驗收的既有 bug、資料狀態或設計限制。
  3. 與本次需求無直接依賴、盤點中發現的其他問題／疑慮（次要，僅記錄不阻塞）。
- 依 `independent-review` Step 1 規模規則開 1 或最多 3 個 sub-agent；勿自創規則。

### Step 11: 判斷分流並回填輸出

拿到 `independent-review` 報告後，逐條判斷 finding 是否與本次需求**強相關**（檔名與落地規則見「File Output」）：

- **強相關（會阻擋本次驗收）**：不處理則某條 AC 無法通過 → **併入主 spec**：
  - 新增第 7 節「⚠️ 需求前置阻塞問題（獨立審查發現）」：問題、證據（路徑／行號）、為何擋住驗收。
  - 在對應 AC 或技術邊界註記「此 AC 需先處理上述阻塞問題 N 才能驗證」。
- **弱相關（不影響本次驗收）** → 拆到「盤點問題」檔；主 spec 只留一行連結。
- **無法判斷**：標記「需人工確認是否阻塞本次驗收」，保守放入主 spec 第 7 節。
- 若完全沒發現問題 → 不新增第 7 節、不建「盤點問題」檔；完成回報說明「本次獨立審查未發現問題」，勿硬掰。

### Step 12: 研究/非開發類 Ticket 的實際交付物（僅 Step 0 判定為此類型時執行）

Step 11 完成後**額外**執行：

1. 重讀 ticket「預期產出／預期輸出」的條列——順序與措辭才是本文件結構，不是本 skill 通用的第 0～6（+7）節。
2. 產出新文件，用**建議語氣**改寫規格中對應結論：現況照實；建議做法具體但避免宣告式措辭（勿用 `MVP: true`、「AC 必須通過」），改用「建議」「建議做法為...」。
3. 技術細節（行號、審查過程、詳細 AC 草案）勿複製進來，一句話連結回主 spec（技術附件）。
4. **檔名須一眼可辨為「要交出去的產出」**（如 `<KEY>-output-<slug>.md`，或問使用者專案既有慣例）。
5. 在主規格（技術附件）開頭聲明：實際產出是研究結論文件，主規格僅技術附件。
6. 明確告知使用者：「實際提交的是《研究結論》，主規格是技術附件」。

### Step 13: 完成後導引下一步 / Guide the Next Step

本 skill 是「需求抽取與規格化」，**不是**實作入口。Step 11（與適用時的 Step 12）完成、檔案存好後：

- **開發類**：完成回報中**不要**主動建議直接呼叫 `/fix`／`/feature`／`/adjust`／`/refactor` 等實作 skill。改為引導下一步呼叫 `/user-stories`；之後再以 `next-task` 或指定任務進場實作。
  - 理由：跳過拆解會略過複雜度評估與依賴排序；US 拆解才是規格化之後、實作之前的自然下一環。
  - 若使用者明確說「不需要拆 US，直接開始改」，才順其指示建議對應實作 skill。
- **研究/非開發類**：回報聚焦「研究結論才是交付物」，預設**不**建議 `/user-stories`。僅在使用者明確表示要依建議排開發時，才建議呼叫。

---

## Output Format / 輸出格式

產出 AI Agent 開發規格時，預設用下列結構（可增減小節，頂層標題與節號保持一致）。常態為第 **0～6** 節；第 **7** 節僅 Step 11 有強相關阻塞時附加。

```markdown
0. Context

   - Problem: ...
   - Goal: ...
   - Impacted Areas: ...
   - Stakeholders: ...

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
     - [實作時必須處理或檢查的技術細節]
   - **二、規格與需求灰區 (Spec-level Gaps / Pre-dev Questions)**
     - [開發前需由 PM/UX/架構師先回答的規格缺失]
   - **三、動態詢問與邊界調整 (Runtime/Dynamic Clarifications)**
     - [遇邊界案例時應暫停並與 PM/UX 同步的項目]

7. ⚠️ 需求前置阻塞問題 (Blocking Issues from Independent Review)（僅 Step 11 判定有強相關問題時才新增此節）

   - 問題 1：[標題]
     - 證據：`path/to/file` 行號 / 具體說明
     - 影響：擋住哪一條 AC（對應 Story/Scenario）
   - （若有其他非阻塞問題被拆到獨立檔案）另見：`<spec 檔名>-issues.md`
```

此結構於 Step 1～9 完成即可產出第 0～6 節；第 7 節是 Step 10/11 審查後才決定是否補上的**附加**章節。

---

## File Output / 檔案輸出

- **預設檔案輸出**
  - 完成規格後，若環境允許寫入，預設存為 Markdown 至 `docs/specs`。
  - 檔名建議：
    - JIRA：`<ISSUE_KEY>-<short-slug>.md`（如 `PROJ-123-checkout-apple-pay.md`）。
    - 非 JIRA：日期 + 短描述（如 `2026-03-04-checkout-query-tuning.md`）。
  - 使用者要求不存檔或指定其他路徑時，依其指示覆蓋預設。

- **同一 Ticket 重跑／更新**
  - 預設**覆蓋**同路徑主 spec（勿默默另存一堆版本，除非使用者要求版本化）。
  - Ticket／需求結論有實質變更 → 重跑 Step 10/11，更新第 7 節與 `-issues.md`（無弱相關則刪除過時的 `-issues.md`）。
  - 僅措辭／排版、無實質變更 → 見 Step 10「可不重跑 IR」；仍應覆寫主 spec 本文，並遵守輸出限制勿堆舊版鋪陳。

- **獨立審查後更新（Step 10/11）**
  - **強相關（阻塞）**：改寫主 spec，補第 7 節與對應 AC 註記，**不建新檔**。
  - **弱相關（非阻塞）**：另存「盤點問題」檔，主 spec 檔名加 `-issues`：
    - JIRA：`<ISSUE_KEY>-<short-slug>-issues.md`（如 `PROJ-123-checkout-apple-pay-issues.md`）。
    - 非 JIRA：`<原檔名去除副檔名>-issues.md`。
    - 內容格式（每問題為未來可能開單的線索，不必完整比照主 spec 第 0～6 節）：
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
  - 兩者皆無 → 不建 `-issues.md`、不新增第 7 節，維持第 0～6 節。
  - **注意**：`-issues.md` 不是主規格；下游 `next-task` 解析 `docs/specs/{KEY}-*.md` 時應排除 `*-issues.md`（見該 skill）。

- **Step 12 研究結論（僅研究/非開發類）**
  - 與任務拆解放同一處（如 `docs/user-stories/<KEY>/`），勿與技術附件混在 `docs/specs/`。
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
> 「User report slow checkout, need to add Apple Pay and reduce checkout query latency on the payment confirmation path」

依前述 Workflow 輸出類似結構（實際需更完整；以下為合規範例，**勿**把模糊動詞或未在 Ticket 出現的數字寫進規格）：

- Context／Impacted Areas：checkout 頁、付款確認 API、訂單狀態、第三方支付整合點。
- 核心 User Story：玩家希望可以使用 Apple Pay 完成結帳，以便縮短結帳等待時間。
- 功能細節：新增 Apple Pay 支付流程、授權成功後將訂單狀態更新為 `PAID`、寫入交易紀錄；針對付款確認路徑的查詢列出具體調整建議（例如候選 index／查詢條件），未核准前不改 schema。
- 驗收標準：Given 使用者在 checkout 頁面選擇 Apple Pay，When 授權成功，Then 訂單狀態為 `PAID` 且導向成功頁（如 `/dashboard`）。另補錯誤與邊界（授權失敗、重複提交等）。
- 技術邊界：需與第三方支付供應商整合；DB index 是否調整標「可能需要討論」。效能數字若 Ticket 未給，標「缺少效能指標」，勿杜撰。
- MVP 判定：Apple Pay 支付為 MVP；付款確認路徑以外的報表類查詢調整列為後續（`MVP: false`）。

此範例僅作思路參考，實作時仍依實際 Ticket 完整展開。

---

## Checklist

- [ ] Step 0：已取得內容後判定類型；Non-Dev 以 issue type 為主，模糊時已詢問（未僅憑「預期產出」條列誤判）
- [ ] Step 1：JIRA 路徑已盡力用 MCP；MCP 失敗且僅依貼文續跑時，已明示可能缺 comments
- [ ] 主 spec 含第 0 節 Context（含 Impacted Areas），且已存檔（若環境允許）
- [ ] Step 3→4 關係正確；MVP 只在 Step 8 標記；AC 含 Happy Path／錯誤／邊界條件
- [ ] 資料／API：已給定義，或已寫明「本次無資料層變動」及理由
- [ ] Step 10：已執行 IR，或符合窄條件略過／不重跑並已註明；新建 vs 既有模組未誤報
- [ ] Step 11：阻塞／弱相關／無發現分流正確；`-issues.md` 命名正確
- [ ] 研究類已做 Step 12；開發類完成回報導向 `/user-stories`（非直接實作 skill）
