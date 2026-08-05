# Close loop（分派完成後才載入）

本檔只在 `/next-task` Step 3 分派 skill **返回之後**才讀。驗證 → 驗收 → 回填 → 回報；**仍只閉合這一個任務**。

## C1：驗證

| 情況 | 動作 |
|---|---|
| Test-First **測試準備**任務（任務檔明載「預期紅燈」／「因功能尚未實作而預期失敗」） | 單跑新增測試，確認因**功能未實作**而紅；記錄路徑與失敗訊息 → C2 的 PREPARED 分支 |
| 其他 | 跑受影響測試至全過；失敗則呼叫 `/fix` 至通過或 `/fix` 暫停轉達 |

Runner：Jest `npx jest {path} --no-coverage`；Vitest `npx vitest run {path}`；Playwright 僅當任務要 E2E 且環境就緒。

以任務檔文字判斷 Test-First 準備，不以「現在紅燈」反推。

## C2：驗收

| 情況 | 動作 |
|---|---|
| 一般任務 | 呼叫 `/us-acceptance-check`（目標＝本任務檔）；由它勾 AC、寫「驗收說明」 |
| Test-First 測試準備 | 任務檔寫「驗收說明」：`PREPARED：預期紅燈測試已建立` + 路徑與原因；勾選**測試任務自己的** AC 為 `[x]` |

文件產出型（Step 3 已標）：直接 `/us-acceptance-check`，略過 C1。

## C3：重構掃描（可選）

分類為功能或修錯 → 呼叫 `/refactor-scan`。純測試或本身已是重構 → 略過。

## C4：回填 README

有「全域驗收 Checklist」時，依驗收結論回填該任務行：

| 結論 | 標記 |
|---|---|
| PASS ✅ | `[x]` |
| PARTIAL ⚠️ | `[⚠️]` + 短註 |
| FAIL ❌ | 維持 `[ ]` |
| PREPARED | `[x]` +「預期紅燈；待實作轉綠」 |

無 Checklist 型 → 略過。

## C5：回報與停下

回報：目錄、任務、分派 skill、測試結果、驗收結論、是否 `/refactor-scan`、README 是否更新。可提示「下一個可能是 XXX」；**停住**——要下一件須再次 `/next-task`。

### 交付觸發

| 觸發 | 判定 |
|---|---|
| Epic 收尾 | [resolve-tracking-dir/reference.md](../resolve-tracking-dir/reference.md) §2.3：P0 全完（或無 Checklist 全完） |
| Sprint 收尾 | 使用者明示 sprint 收尾，或本回合以此為目標 |

本機：建議 `/change-report` → `/pr-delivery`（不自動 commit）。Cloud：觸發成立且已驗證 → 執行二者（必要時先 `/new-branch-cloud-agent`）。Epic 收尾可另建議 `/wrap-up`（不代為執行）。
