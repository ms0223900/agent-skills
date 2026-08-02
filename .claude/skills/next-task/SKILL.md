---
name: next-task
description: 選出下一個未完成任務並分派（每次只處理一個）。使用時機：下一個任務；這個 branch 還有哪些沒做完；sprint／epic 收尾。Reachable by wrap-up flows。
---

# Next Task（一次一個）

## 目標

**一次一個任務**：Resolve 目錄 → 找出下一個可動工任務 → 分派 → 閉環 → **停下**。

---

## 執行流程

### Step 1：Resolve 追蹤目錄

呼叫 `/resolve-tracking-dir`（規則見該 skill）。

**完成條件**：已有恰好一個追蹤目錄，或已停下等使用者。

### Step 2：找出下一個可動工任務

依 [resolve-tracking-dir/reference.md](../resolve-tracking-dir/reference.md)「二、文件形態判讀」走訪，取出**依賴已滿足**的第一個未完成任務；候選須用 `^#{2,4}\s*驗收說明` cross-check（已有驗收說明 → 視為完成，繼續找）。

| 結果 | 動作 |
|---|---|
| 找到可動工任務 | 進入 Step 3 |
| 全部因依賴卡住 | 回報卡住清單；停止 |
| 需人工／PM 決策（`[⚠️]`／`[❌]` 且註明 PO／PM 簽核） | 回報待確認事項；停止 |

**完成條件**：已鎖定一個可動工任務檔，或已停止並回報原因。

### Step 3：分類並分派

先讀任務「測試策略／輸出格式」。**文件產出型**（聲明不改程式、輸出即文件）→ 略過實作分派，直接載入 [close-loop.md](close-loop.md) 走 C2。

其餘依 **dispatch ladder**（由上而下，命中即分派；細節見 [reference.md](reference.md)）：

| 優先 | 判準 | 分派 |
|---|---|---|
| 1 | 修錯：既有錯誤／失敗要修好 | `/fix` |
| 2 | 重構：提取／重構／拆分／搬移 | `/refactor` |
| 3 | 純測試：新增測試覆蓋（非修既有紅燈） | `/unit-test`／`/vue-integration-test`／`/react-integration-test`／`/e2e-test` |
| 4 | 其餘新行為 | `/feature` |

分派時附上任務全文（含測試策略）。Test-First 測試準備 → 告知「預期紅燈即可」；Test-First 實作 → 告知「對既有紅燈測試實作至綠」。

分派 skill **返回後**，載入 [close-loop.md](close-loop.md) 做完驗證／驗收／回填／回報，然後**停住**（再次呼叫本 skill 才做下一件）。

**完成條件**：已分派（或文件型已進 close-loop），且 close-loop 已結束並停下。

---

## 何時改用別的 skill

| 情境 | 改用 |
|---|---|
| 只要選定追蹤目錄 | `/resolve-tracking-dir` |
| 已知 US 檔、只驗收 | `/us-acceptance-check` |
| 已知道要改什麼 | `/adjust`／`/feature`／`/refactor` |
| 只要開 PR／變更摘要 | `/change-report`／`/pr-delivery` |
| 尚未拆 User Story | `/user-stories` |

---

## Additional Resources

- 分類歧義、E2E、人工決策例：見 [reference.md](reference.md)
- 分派後閉環：見 [close-loop.md](close-loop.md)（Step 3 返回後才載入）
- Resolve／文件形態：見 `/resolve-tracking-dir`
