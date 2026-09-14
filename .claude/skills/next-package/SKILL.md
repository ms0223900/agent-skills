---
name: next-package
description: Package related unfinished US and loop /next-task. Cloud or 同一 PR: one draft. Use when the user wants 整包 or 同一 PR.
---

# Next Package

## 何時改用

| 情境 | 改用 |
|---|---|
| 只要下一件 | `/next-task` |
| 只要選定追蹤目錄 | `/resolve-tracking-dir` |
| 已知道要改什麼 | `/adjust`／`/feature`／`/refactor` |
| 只要開 PR／變更摘要 | `/change-report`／`/pr-delivery` |
| 尚未拆 User Story | `/user-stories` |

---

## 執行流程

### Step 0：續跑

| 對話狀態 | 動作 |
|---|---|
| package 已鎖定、gate 已過、scaffold 已有 URL | Step 5 |
| package 已鎖定、gate 已過、應 scaffold 但尚無 URL | Step 4 |
| package 已鎖定、gate 已過、本機不開 PR、已在工作分支 | Step 5 |
| package 已鎖定、gate 已過、本機不開 PR、仍在主幹 | Step 4 |
| 已出示 package、本則是調整名單 | 改包後 Step 3 |
| 已出示 package、本則尚未確認 | 分支已就緒 → Step 2 再 Step 3；否則本回合結束 |
| 以上皆非 | Step 1 |

略過 gate 用語（啟動則或確認則）：`不用確認`／`直接做`／`跳過確認`。

**完成條件**：上表恰好命中一列，且下一跳已選定。

---

### Step 1：切 package

1. 呼叫 `/resolve-tracking-dir`。
2. 載入 [reference.md](reference.md)「一、切 package」，沿 [resolve-tracking-dir/reference.md](../resolve-tracking-dir/reference.md)「二、文件形態判讀」的走訪順序生長。

**完成條件**：已列出 package（每個入包 ID 有「為何同包」；種子之後每一件候選皆入包或帶 1.4／1.5 理由；N>5 時有超額理由），或已停止並回報原因。

---

### Step 2：環境與分支計畫

載入 [reference.md](reference.md)「二、分支」（含「是否為雲端開發環境」與「交付」）。只寫判定與計畫（開新／沿用／請本機手動；scaffold／本機不開 PR）。**不確定 → 本機。**

**完成條件**：已寫下環境（雲端／本機，含命中訊號或「未命中→本機」）、交付（scaffold／本機不開 PR）、分支三選一；或已停止（工作區無法安全繼續）。

---

### Step 3：gate

出示 package 卡片（缺一不可）：入包清單與為何同包、切斷理由（N>5 含超額理由）、環境判定、分支計畫、交付計畫（scaffold 後再 loop／本機不開 PR 直接 loop）。

確認用語：`確認`／`開始`／`可以`／`做吧`。啟動則已含略過用語 → gate 通過，進 Step 4。確認則更正環境 → 以更正為準。

**完成條件**：

- 等候確認：本回合產出僅為這張卡片——無新 commit、無 PR、未呼叫 `/next-task`。
- 已確認或已命中略過用語：gate 通過。

---

### Step 4：執行分支與交付前置

載入 [reference.md](reference.md)「二、分支」。gate 通過後執行 Step 2 計畫。

- 交付＝scaffold → 再載入「三、scaffold」，直到本包有 draft PR URL。
- 交付＝本機不開 PR → 只確保非主幹工作分支；不呼叫 `/pr-delivery`、不為推 PR 而空 commit。

**完成條件**：已在非主幹工作分支；交付＝scaffold 則另有本包 URL。缺分支，或 scaffold 缺 URL → 停止（請使用者把 URL 帶回）。

---

### Step 5：loop

每圈呼叫 `/next-task`。返回後載入 [reference.md](reference.md)「四、迴圈」，只依該表決定下一動。每圈只帶當前任務全文。交付＝scaffold 時，閉環後更新同一張 checklist（見〈三、scaffold〉3.4）。

**完成條件**：鎖定清單每一個 ID 都有 close-loop 結論（PASS／PREPARED／PARTIAL／FAIL）或已命中一列中止。少一個 ID 就繼續 loop。

---

### Step 6：包尾

呼叫 `/change-report`。交付＝scaffold → 再以一般模式呼叫 `/pr-delivery` 更新同一張 draft。交付＝本機不開 PR → 不呼叫 `/pr-delivery`；可提示需要的話再開。回報目錄、每個 ID 的結論、有則 PR URL、是否中止。

**完成條件**：鎖定 ID 皆有結論；交付＝scaffold 則同一張已更新為包尾，否則已交出 change-report。
