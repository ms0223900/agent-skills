---
name: next-package
description: Package related unfinished US onto one branch and one draft PR, then loop /next-task until that package ends. Use when the user wants 整包、同一 PR、相關 US 一起做, or to auto-loop next-task.
---

# Next Package（整包同一 PR）

## 目標

把**相關、可連續動工**的未完成 US 切成一包，開在**同一分支、同一張 draft PR**，再依序呼叫完整 `/next-task`（一次一個，不改它的流程）直到包內最後一件。

`/next-task` 仍是一次一個就停；**迴圈由本 skill 擁有**。

**安裝依賴**：相對路徑會讀 `resolve-tracking-dir`／`next-task`／`new-branch-cloud-agent`／`pr-delivery`；包尾會呼叫 `/change-report`。單裝請一併帶上（見 repo README「安裝群組」）。

---

## 何時使用 / 何時不用

**使用**：使用者要整包、同一 PR、相關 US 一起做、或自動 loop `/next-task`。

**不用（改用其他 skill）**：

| 情境 | 改用 |
|---|---|
| 只要下一件、不切包 | `/next-task` |
| 只要選定追蹤目錄 | `/resolve-tracking-dir` |
| 已知道要改什麼 | `/adjust`／`/feature`／`/refactor` |
| 只要開 PR／變更摘要（沒有整包） | `/change-report`／`/pr-delivery` |
| 尚未拆 User Story | `/user-stories` |

---

## 執行流程

### Step 0：續跑判定

| 對話狀態 | 動作 |
|---|---|
| 已鎖定整包、使用者已確認（或本則含略過確認用語）、draft PR 已存在 | 直接 Step 5 |
| 已鎖定整包且已確認，尚無 draft PR | 直接 Step 4 |
| 已出示整包、本則是調整名單（拿掉／再多包） | 改包後回到 Step 3 |
| 已出示整包、本則尚未確認 | 若像是「分支已開好」→ Step 2 核對後再 Step 3；否則**停住** |
| 以上皆非 | Step 1 |

略過確認用語（須在**啟動本 skill 的那則**或確認則出現）：`不用確認`／`直接做`／`跳過確認`。

**完成條件**：已知道要切包、開 draft、進迴圈、或停住等確認／改包。

---

### Step 1：Resolve 並切包

1. 呼叫 `/resolve-tracking-dir`。
2. 載入 [reference.md](reference.md)「一、切包」：沿 [resolve-tracking-dir/reference.md](../resolve-tracking-dir/reference.md)「二、文件形態判讀」的**同一走訪順序**，以第一件可動工任務為種子往後長，碰到第一個切斷點就停。**不要另寫依賴演算法**。
3. 包長以 2–5 為啟發式；超過必須寫清理由。只有 1 件可動工 → 整包就是那 1 件。種子後面沒有相關任務 → 回報不適合同包，建議 `/next-task`，停止。

**完成條件**：已列出整包任務（含「為何同包」與「切斷理由」；超過啟發式時含超額理由），或已停止並回報原因。

---

### Step 2：分支計畫（確認前不開新分支）

載入 [reference.md](reference.md)「二、分支」。本步只**決定**開新／沿用／請使用者手動開，寫進 Step 3 出示內容。確認前不要 `checkout -b`、不要呼叫 `/new-branch-cloud-agent`（已在正確工作分支上則沿用即可）。

本機 + 主幹 → 計畫寫「請手動 `/new-branch-feature {JIRA}`」；可先出示整包，但確認後若仍在主幹 → **停止**，不可代呼。

**完成條件**：已寫下分支計畫（開新／沿用／請本機手動），或已停止（髒工作區無法安全繼續）。

---

### Step 3：確認閘門（預設停下）

向使用者出示（缺一不可）：

- 整包任務清單與「為何同包」
- 切斷理由（以及包長超過啟發式時的超額理由）
- 分支計畫（開新／沿用／已在目標分支）
- PR 計畫：確認後會**先開 draft、再**跑 `/next-task`

然後**停住**，等使用者主動確認（`確認`／`開始`／`可以`／`做吧` 等）。啟動則已含略過確認用語 → 不停，進 Step 4。

**完成條件**：使用者已確認或已命中略過用語；否則已出示整包並停下。

---

### Step 4：執行分支，並先開 draft PR（必須在任何 `/next-task` 之前）

載入 [reference.md](reference.md)「二、分支」與「三、Draft 先於迴圈」。確認之後、第一圈 `/next-task` 之前：

1. 依 Step 2 計畫執行：Cloud 在主幹 → `/new-branch-cloud-agent`；已在對應分支 → 沿用；本機仍在主幹 → **停止**（請手動 `/new-branch-feature`）。
2. 分支相對 base **沒有任何 commit** → `git commit --allow-empty`，message 含整包任務 ID。
3. 以 **scaffold** 呼叫 `/pr-delivery`（body 用整包清單，不要求已驗證實作）。同分支已有 PR → 更新那張，寫入整包計畫。
4. **沒有 draft PR URL（工具也無法建立）→ 停止，不要進迴圈。** 僅準備了 body 時，停住並請使用者開完 PR 後把 URL 回傳再續跑。

**完成條件**：已在非主幹工作分支，且已有本包要用的 draft PR URL；或已停止並說明缺分支／缺 PR。

---

### Step 5：依序呼叫 `/next-task`

每一圈：完整執行 `/next-task`（含它的 close-loop）。不要改它的步驟、不要在它內部開第二張 PR。

一圈結束後，載入 [reference.md](reference.md)「四、迴圈」：

| 結果 | 動作 |
|---|---|
| 剛完成的是包內最後一件 | 進 Step 6 |
| 下一件可動工仍在本包 | 再呼叫 `/next-task` |
| 命中中止條件 | 更新同一張 PR、回報已完成／未做，**停止**（不要做包外 US） |

每圈只載入**當前**任務全文；不要把整包所有 US 正文一直留在上下文。每圈結束後 push，並更新同一張 PR 的整包 checklist 進度。

**完成條件**：包內最後一件已閉環，或已依中止條件停下並更新 PR。

---

### Step 6：包尾交付

呼叫 `/change-report`，再以一般（已驗證）模式呼叫 `/pr-delivery` **更新同一張** draft。回報：目錄、整包清單、各件結論、PR URL、是否中止。

**完成條件**：同一張 PR 已更新為包尾狀態，且已回報。

---

## Additional Resources

- 切包規則、分支表、scaffold draft、迴圈中止、範例：見 [reference.md](reference.md)
- 走訪／依賴：見 `/resolve-tracking-dir`
- 單任務分派：見 `/next-task`（本 skill 不修改其流程）
