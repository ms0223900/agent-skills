---
name: next-task
description: 依目前 git branch（或指定的 JIRA 單號）自動找出對應追蹤目錄中「依賴順序上下一個未完成的任務」，依任務類型分派至 `/vue-integration-test`（純測試）、`/refactor`（提取/重構/拆分/搬移）或 `/feature`（一般功能）實作，跑 Jest 到全過，再呼叫 `/us-acceptance-check` 驗收該任務並回填追蹤目錄 README 的「全域驗收 Checklist」。每次只處理一個任務，不會連續跑完整個 Phase。使用時機：使用者說「接下來要做什麼」、「下一個任務」、「next task」、「這個 branch 還有哪些沒做完」、「幫我把下一個 US/TASK 做完」。
---

# 尋找並實作下一個任務（Next Task Workflow）

## 目標

在不需要使用者手動指定「要做哪個 US/TASK」的前提下，依序完成：**定位追蹤目錄 → 找出依賴順序上的下一個未完成任務 → 依任務性質分派實作 → 測試全過 → 驗收該任務 → 回填追蹤目錄進度 → 停下回報**。本 skill **只處理一個任務**，不會自動連續往下做完整個 Phase 或整個 epic。

---

## 執行流程

### Step 1：解析 Ticket Key

1. 若使用者直接給了 ticket key（格式 `[A-Z]+-[0-9]+`，例如 `SPRD-1336`），直接使用。
2. 否則讀取目前 branch：`git branch --show-current`，用同樣的正則從 branch 名稱擷取 ticket key（例如 `feature/SPRD-1336` → `SPRD-1336`）。
3. 若兩者都無法取得有效 key，停下並請使用者提供 ticket key 或切換到正確的 feature branch。

### Step 2：定位追蹤目錄候選

依 [reference.md](reference.md) 的「追蹤目錄解析演算法」，收集第 1～3 層**全部**實際存在的候選目錄（不論跨哪一層，不是找到第一個就停）：

1. `docs/user-stories/{KEY}*/`（可能有多個後綴變體，例如 `{KEY}-PHASE2`）
2. `docs/specs/{KEY}/us/`
3. `docs/specs/{KEY}-user-stories/`
4. `docs/specs/{KEY}-*.md`（純規格檔，無任務拆解——只有在 1～3 都不存在時才當作唯一線索）

對每個第 1～3 層候選，依 reference.md 的規則跑一次「找下一個任務」演算法，判斷「是否仍有未完成任務」。

**決策規則**：

- 找不到任何候選 → 明確告知使用者「找不到 {KEY} 的任何追蹤文件」，建議依序執行 `/ticket-to-ai-spec` 和/或 `/user-stories`，然後停止。
- 只有第 4 類（純規格檔）候選 → 告知使用者只有規格、沒有任務拆解，無法自動判定下一個任務，建議先執行 `/user-stories` 拆解，然後停止。
- 恰好 1 個候選「仍有未完成任務」，其餘皆已收尾 → 自動選用該候選，並向使用者說明為什麼（例如：「`docs/user-stories/SPRD-1336/` 已全數收尾，改用仍在進行中的 `docs/user-stories/SPRD-1336-PHASE2/`」）。
- 超過 1 個候選「仍有未完成任務」→ **不要自行猜測**，列出所有候選目錄與各自的完成度摘要，請使用者指定要用哪一個，然後停止等待回覆。

### Step 3：在選定目錄中找出下一個未完成任務

先判斷該目錄屬於哪種文件形態（見 reference.md「文件形態判讀」）：

- **README 驅動型**（有「全域驗收 Checklist」與「依賴鏈摘要」，例如 `docs/user-stories/SPRD-1336-PHASE2/README.md`）
- **無 Checklist 型**（README 只有任務索引與文字描述的依賴關係，狀態只存在各任務檔案本身，例如 `docs/user-stories/SOPS-2721/README.md`）

依對應演算法（reference.md 有完整步驟）逐步找出「順序上最前面、且依賴皆已完成」的第一個未完成任務。**找到候選後，務必打開該任務自己的檔案**，確認它並未已經有 `驗收說明` 區塊（heading 層級與措辭略有不同，用 `^#{2,4}\s*驗收說明` 判斷）。若已經有 → 代表 README 勾選狀態過期，這個任務其實已完成，在回報中註明此落差，並繼續往下找真正的下一個任務。

若目前所有未完成任務都因依賴未滿足而卡住（沒有任何一個當下可動工）→ **不要硬做**，明確回報「目前沒有可動工的任務，被下列依賴卡住：...」，並停止（不要選一個依賴未滿足的任務動手實作）。

若判定的下一個任務被標記為需要人工/PM 決策（例如 `[⚠️]`、`[❌]` 並附註「PO／Release 簽核為準」「需與 PM 再確認」等字樣，如 `docs/user-stories/SPRD-660/README.md`）→ 視為不可由本 skill 自動推進，回報該任務目前卡在人工決策、列出待確認事項，然後停止，不要代替 PO/PM 做決定或動手實作。

### Step 4：分類任務並分派實作

讀取任務標題與內容，依關鍵字分類：

| 判斷依據 | 分類 | 分派 |
|---|---|---|
| 含「測試」，且不含「提取」/「重構」/「拆分」/「搬移」 | 純測試任務 | Vue 元件測試 → 依 `/vue-integration-test` 撰寫；純函式/utils → 直接寫 unit test。**不要**呼叫 `/feature` 或 `/refactor` |
| 含「提取」/「重構」/「拆分」/「搬移」（不論是否也提到「測試」） | 重構任務 | 呼叫 `/refactor`，附上任務全文作為 context |
| 其餘（新行為或行為變更） | 功能任務 | 呼叫 `/feature`，附上任務全文作為 context |

分派時附上任務檔案的「作為／我想要／以便」、輸入格式、輸出格式、驗收條件、依賴關係全文，等同直接把 ticket 交給協作者。

若任務屬於 Playwright / E2E 性質：只依既有慣例（`docs/specs/SPRD-1336-playwright-feasibility.md` 與 `tests/e2e` 下既有 Page Object Model，如 `tests/e2e/support/pages/*.page.ts`）撰寫 E2E 測試程式碼，**不要**在本 skill 的驗證步驟中執行 `npx playwright test`（太慢、需要開發伺服器）。

> 注意分工邊界：`/feature`／`/refactor` 自己做完後也會在任務檔案內打勾其驗收條件細項（AC 層級），這與本 skill 在 Step 7 對「追蹤目錄 README 全域 Checklist」的回填是不同層級的紀錄；Step 6 會呼叫 `/us-acceptance-check` 對任務檔案的 AC 重新、權威性地判定一次，兩者不會互相牴觸，不需要重複手動勾選。

### Step 5：跑測試至全過

```bash
npx jest {受影響的測試檔路徑} --no-coverage
```

若失敗，診斷並修正（程式碼或測試）直到全部通過；不要為了通過而降低覆蓋率或刪減斷言。

### Step 6：驗收該任務

呼叫 `/us-acceptance-check`，目標檔案為本次任務自己的檔案。讓它逐條核對驗收條件、更新該檔案的 checklist 標記，並寫入「驗收說明」區塊。**不要自己手動勾選或編寫驗收說明**，一律交給 `/us-acceptance-check` 執行，避免邏輯分裂。

### Step 7：回填追蹤目錄 README

`/us-acceptance-check` 完成後，取得它的整體結論（PASS ✅ / PARTIAL ⚠️ / FAIL ❌）：

- 若該追蹤目錄的 README 有「全域驗收 Checklist」→ 依下表回填該任務對應的那一行：

  | `/us-acceptance-check` 結論 | README 行標記 |
  |---|---|
  | PASS ✅ | `[x]` |
  | PARTIAL ⚠️ | `[⚠️]`，附簡短說明或指向該任務「驗收說明」 |
  | FAIL ❌ | 維持 `[ ]`，**不要**回報為完成 |

- 若該目錄屬於「無 Checklist 型」（狀態只存在任務檔案本身，例如 SOPS-2721）→ 跳過本步驟。

### Step 8：完成回報

簡短總結：選了哪個追蹤目錄與原因、做了哪個任務、分派到哪個 skill、測試結果、`/us-acceptance-check` 結論、README 是否更新。

- 依 reference.md 的收尾判斷規則，若這是 README 驅動型且回填後所有 P0（必要）任務皆已勾選（P1/P2 依註記可延後不計）→ 告知使用者「這個 epic/feature 看起來已收尾」，建議之後另外執行 `/distill-playbook`；**不要**自己去動 playbook / CLAUDE.md / 其他 skill 檔案，那是 `/distill-playbook` 自己的職責範圍。
- 提示「下一個任務可能會是 XXX」，但**不要自動繼續實作**；需要使用者再次呼叫本 skill 才會處理下一個任務。
- **不要**自動 `git add` / `git commit` 任何變更。

---

## 邊界情況

- **完全找不到追蹤文件**：見 Step 2，建議 `/ticket-to-ai-spec` 和/或 `/user-stories`，停止。
- **多個追蹤目錄候選都還有未完成任務**：見 Step 2，列出候選讓使用者選，不要猜。
- **README 打勾但任務檔案本身沒有「驗收說明」，或反過來**：以任務檔案自己的實際狀態為準（見 Step 3 的 cross-check），並在回報中指出 README 與檔案不同步的落差。
- **下一個候選任務的依賴未滿足**：一律跳過、continue 往下找，永遠不要為了「有事做」而略過依賴直接動工；若全部卡住就照實回報並停止。
- **任務被標成需要人工/PM 決策**（如 SPRD-660 的「PO／Release 簽核為準」）：視為不可自動推進，回報並停止，不要替 PO/PM 做決定。
- **純規格檔、無任務拆解**：不強行猜測任務邊界，建議先 `/user-stories`。

---

## 何時不要使用這個 skill

- 已經明確知道要驗收哪一份 US/TASK 檔案，且不需要「找出下一個」也不需要動手實作 → 直接用 `/us-acceptance-check`。
- 使用者已經明確描述好要調整的內容（不需要先幫他找任務）→ 用 `/adjust`（補充調整既有功能的固定流程）或直接 `/feature`／`/refactor`。
- 想整併一整個 epic 收尾後的知識到 Playbook/Skill/CLAUDE.md → 用 `/distill-playbook`；本 skill 只在偵測到疑似收尾時「建議」使用者另外執行，不會自己動手整併。
- 需求文件都還沒拆成 User Story → 先用 `/user-stories`，本 skill 假設任務拆解已經存在。

---

## Additional Resources

- 追蹤目錄解析演算法、checkbox 正規化表、依賴圖判讀規則、完整範例：見 [reference.md](reference.md)
