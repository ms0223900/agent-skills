<!-- GENERATED — do not edit the body by hand.
Source: dev/shared/test-red-handling.source.md
Regenerate: ./scripts/sync-shared-refs.sh -->

# 測試變紅的處理（Test Red Handling）

改動程式碼後有測試變紅、或要補回歸測試時使用。測試該不該存在，見同目錄的 `reference-test-gate.md`。

## 既有測試變紅

先分辨是哪一種，再處理：

| 判定 | 處理 |
|---|---|
| **行為本來就該變**（US／AC 或需求明確要求新行為） | 依 US／AC 更新期望值 |
| **行為不該變，卻變了** | 這是回歸：修產品碼，測試不動 |
| **行為沒變，測試卻壞了** | 測試綁在實作上：在 owner 邊界改寫成斷言可觀察結果 |
| **測試本身寫錯**（斷言邏輯錯、mock 資料不符現況） | 修測試，總結中附上依據（US／AC、最新規格） |

判定「行為沒變」必須有下列證據之一：
- owner 邊界有一支仍是綠的測試，**斷言的正是紅掉那條斷言守護的同一件事**（只是沒紅不算）。
- 可觀察輸出與 US／AC 一致，或與[改動前的結果](#取得改動前的結果)一致。

對外邊界的呼叫參數屬於行為，不屬於實作：API client 的 payload、`$emit`、`router.push`、analytics、storage 寫入。斷言這些的測試變紅，按「行為不該變，卻變了」處理，除非 US／AC 要求新行為。

改寫後的斷言期望值取自 US／AC 或改動前的結果，**不從目前程式碼的輸出抄**——否則會把 bug 寫進期望值。改寫後的 owner 測試若變紅，改判為回歸、修產品碼。

證據不足以判定時，當作回歸處理（測試不動），再依所在 skill 的除錯流程補證據。改寫會拿掉原本的呼叫形狀或內部斷言，這是允許的例外；在總結中列出改寫了哪些測試、依據哪條證據。

## 回歸測試

- 回歸測試必須在**修正前的程式**上因為**該 bug** 而紅，修正後轉綠。從沒實證紅過的回歸測試，證明的是 mock，不是修法。
- 實證方式：先寫測試並跑出紅燈，再套用修正跑到綠；或修正後依[取得改動前的結果](#取得改動前的結果)在修正前的產品碼上跑這支測試，確認轉紅。
- 紅燈訊息要對上 bug 的症狀（斷言的 expected／actual），而不是找不到測試、import 失敗或語法錯。修正新增了產品檔、測試又 import 它時，改動前一定是 import 失敗：改用「先寫測試、跑出紅燈、再修正」的順序實證。
- 一個 bug 在 owner 邊界寫**一支**回歸測試，不在它經過的每一層各重演一次。

## 取得改動前的結果

要在「改動前的產品碼 + 目前的測試」上跑一次時：

- **改動還沒 commit**：
  1. 記下 `git stash list | wc -l` 的筆數。
  2. `git stash push -u -m <唯一名稱> -- <本次改動的所有產品檔>`（產品檔要列齊，只收一部分會造成 import 錯誤，看起來像改動前也紅）。
  3. 筆數多了一筆才繼續；沒多就代表沒收到任何改動，停下，不要 pop。
  4. 跑測試，不寫入 snapshot、不進 watch：Jest 用 `npx jest --ci <檔案>`，Vitest 用 `CI=true npx vitest run <檔案>`。
  5. `git stash pop --index`。pop 失敗時不要 `drop`：stash 會保留，先移開衝突的檔案（例如測試產生的同名檔）再重試。
- **改動已經 commit**：
  1. `git worktree add <暫存目錄> <改動前的 commit>`。
  2. 在暫存目錄補齊執行環境：symlink 或安裝 `node_modules`、複製 `.env*`、跑專案的 prepare（例如 `nuxi prepare`）。
  3. 把目前的測試檔與它用到的 fixture、helper，以及同一批改動裡改過的測試設定（`jest.config`／`vitest.config`、setup 檔）複製進去，照上一段第 4 步的指令跑。
  4. `git worktree remove --force <暫存目錄>`。
- 跑出來的結果只有在測試真的執行到斷言時才能當證據；找不到模組、設定錯誤、環境缺漏的結果不算，先補齊環境再跑。
