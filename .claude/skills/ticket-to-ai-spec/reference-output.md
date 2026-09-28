# Ticket → AI Dev Spec — 輸出格式參考

本文件收錄主 spec 的完整 Output Format 章節模板、`-issues.md` 盤點問題檔模板，以及使用範例。撰寫檔案輸出（主 spec 或研究結論）前，先讀本文件對應章節。

---

## 一、主 spec 完整 Output Format（第 0～7 節）

產出 AI Agent 開發規格時，預設用下列結構（可增減小節，頂層標題與節號保持一致）。常態為第 **0～6** 節；第 **7** 節僅 Step 11 有強相關阻塞時附加。

```markdown
0. Context

   - Problem: ...
   - Goal: ...
   - Impacted Areas: ...
   - Stakeholders: ...
   - Assumptions:
     - [已確認] ...
     - [由 ticket 或程式碼推得] ...
     - [仍需確認] ...（不寫進 AC；沒有假設時此小節只寫「無」）

1. 核心 User Story (Core User Stories)

   - 能力圖（僅兩個以上可獨立驗收的能力時才寫；每項一行：名稱、邊界、依賴、撰寫順序）
   - 列出 1~N 條 User Story（高風險規格才加 `FR-1` 這類編號）：
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
   - 狀態與權威來源:（僅付款、權益、Webhook、狀態機、RLS）

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
     - 等級：CRITICAL、會擋 AC 的 P0，或「需人工確認」
     - 證據：`path/to/file` 行號 / 具體說明
     - 影響：擋住哪一條 AC（Story / Scenario）；若是範圍超出 ticket，改寫「範圍與 ticket 不符」並列出 Story
     - 替換句：（可改寫時才寫；使用者接受前不寫回第 1～5 節）
   - （若有其他非阻塞問題被拆到獨立檔案）另見：`<spec 檔名>-issues.md`
```

此結構於 Step 1～9 完成即可產出第 0～6 節；第 7 節是 Step 10/11 審查後才決定是否補上的**附加**章節。

---

## 二、`-issues.md` 盤點問題檔模板

Step 11 判定為弱相關（不影響本次驗收）時，另存「盤點問題」檔，內容格式如下（每問題為未來可能開單的線索，不必完整比照主 spec 第 0～6 節）：

```markdown
# {ISSUE_KEY} 盤點問題與疑慮（非本次需求阻塞項）

> 由 `/independent-review` 對本次 spec 進行獨立審查時額外盤點到、但與本次需求驗收無直接依賴的問題。可視情況另開 ticket 處理，不阻塞本次驗收。

## 問題 1：{標題}

- **來源視角**：{獨立審查的視角 A/B/C 或查證項目}
- **問題描述**：...
- **證據**：`path/to/file` 行號 / 具體說明
- **建議後續**：例如「另開 ticket」「列入下個 sprint 的 tech debt」
```

主 spec 在第 6 節或新增第 7 節末端加一行：「另見 `<檔名>-issues.md`，盤點到的非阻塞問題」。

---

## 三、使用範例（簡化示意）

當使用者說：

> 請分析以下 Ticket 內容，並產出 AI Agent 開發規格：
> 「User report slow checkout, need to add Apple Pay and reduce checkout query latency on the payment confirmation path」

依前述 Workflow 輸出類似結構（實際需更完整；以下為合規範例，**勿**把模糊動詞或未在 Ticket 出現的數字寫進規格）：

- Context／Impacted Areas：checkout 頁、付款確認 API、訂單狀態、第三方支付整合點。Assumptions 用「已確認／由 ticket 或程式碼推得／仍需確認」標示；沒有則寫「無」。
- 能力圖（此例有兩件可獨立驗收的能力）：Apple Pay 結帳 — 授權與訂單狀態；無依賴；先寫。付款確認查詢 — 只含確認路徑；依賴訂單狀態欄位已存在；後寫。
- 核心 User Story：兩件都屬付款，各自編號，例如 `FR-1` 玩家以 Apple Pay 完成結帳。技術邊界寫「狀態與權威來源」。付款確認查詢另立 Story 並標 `MVP: true/false`。
- 功能細節：新增 Apple Pay 支付流程、授權成功後將訂單狀態更新為 `PAID`、寫入交易紀錄；針對付款確認路徑的查詢列出具體調整建議（例如候選 index／查詢條件），未核准前不改 schema。
- 驗收標準：Given 使用者在 checkout 頁面選擇 Apple Pay，When 授權成功，Then 訂單狀態為 `PAID` 且導向成功頁（如 `/dashboard`）。另補錯誤與邊界（授權失敗、重複提交等）。
- 技術邊界：需與第三方支付供應商整合；DB index 是否調整標「可能需要討論」。效能數字若 Ticket 未給，標「缺少效能指標」，勿杜撰。
- MVP 判定：Apple Pay 支付為 MVP；付款確認路徑以外的報表類查詢調整列為後續（`MVP: false`）。

此範例僅作思路參考，實作時仍依實際 Ticket 完整展開。
