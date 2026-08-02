# Next Task Reference

分類、E2E、人工決策補充。Resolve 與文件形態演算法見 [resolve-tracking-dir/reference.md](../resolve-tracking-dir/reference.md)。

## 一、Dispatch ladder 歧義

同時像「測試」又像「修正」時：

| 產出意圖 | 分類 |
|---|---|
| 修好已壞掉／不通過的測試或功能 | 修錯 → `/fix` |
| 新增原本沒有的測試覆蓋 | 純測試 → 對應測試 skill |
| 仍不清 | 問使用者 |

標題含糊時讀「作為／我想要／以便」與輸出格式；文件產出型優先於「其餘 → `/feature`」。

## 二、測試策略交接

| 欄位 | 分派時告知 |
|---|---|
| Test-First 測試準備 | 寫完確認預期紅燈即可；呼叫測試 skill 時禁止順手實作功能 |
| Test-First 實作（依賴的測試任務已完成） | 對 `{測試檔}` 紅燈實作至綠；期望值錯了才能改測試 |
| Test-After | 先實作；close-loop C1 再補測 |
| Exploratory + 已寫不寫測理由 | 原樣附上理由 |
| 無欄位（舊檔） | 依各 skill 預設 |

## 三、E2E

任務提到 Playwright／E2E／跨頁流程 → `/e2e-test`；寫在 `tests/e2e/...`，沿用 `tests/e2e/support/pages/*.page.ts`。環境未就緒 → close-loop 回報未跑原因，不當成已驗證。

## 四、人工決策例（SPRD-660）

`docs/user-stories/SPRD-660/README.md` 有 `[⚠️]`／`[❌]` 且註明以 PO／Release 或 PM 為準 → Step 2 停止並回報待確認項；不進入分派。
