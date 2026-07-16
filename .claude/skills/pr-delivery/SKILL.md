---
name: pr-delivery
description: 將已完成的變更交付為 GitHub Pull Request：先呼叫／重用 `/change-report` 產出分層摘要，再 commit、push，並以 PR 模板建立或更新 draft PR。禁止直推 main／master。使用時機：Background／Cloud Agent 收尾、使用者說「幫我開 PR」「交付這次變更」「建立 pull request」、或 `/feature`／`/fix`／`/adjust`／`/refactor` 做完後進入交付階段。
---

# PR 交付（PR Delivery）

## 目標

把「已驗證的程式變更」變成**可在手機上審閱與合併的 GitHub PR**：

1. 用 `/change-report` 產出分層變更說明（30 秒摘要 → 導讀 → 指向原始 Diff）
2. 在**非主幹分支**上 commit（若尚有未提交異動）並 push
3. 建立或更新 **draft** PR，body 使用專案 PR 模板＋change-report 內容

**禁止**直接 push 到 `main`／`master`（或專案指定的受保護主幹）。PR 是審閱與部署之間的關卡。

---

## 何時使用 / 何時不用

**使用時機**：

- Background／Cloud Agent 完成實作後的標準收尾。
- 使用者明確要求「開 PR」「交付」「建立 pull request」。
- `/feature`／`/fix`／`/adjust`／`/refactor`「做完後」判定需要交付時（見下方「觸發條件」）。

**何時不用**：

- 本機互動開發、使用者未要求開 PR，且非 Background Agent → **不要**自動 commit／push／開 PR（與 `/next-task`「不自動 commit」一致）；可只跑 `/change-report` 把摘要給使用者自行貼。
- 變更尚未驗證（測試紅燈、驗收 FAIL）→ 先修到可交付，再開 PR。
- 目前已在 `main`／`master` 且有未推送 commit → **先開 feature 分支**再交付，不要往主幹推。

---

## 觸發條件（誰該自動跑）

| 情境 | 是否執行本 skill |
|------|------------------|
| 明確偵測為 Background／Cloud Agent（系統指示要求 commit／push／開 PR） | ✅ 自動執行 |
| 使用者說「開 PR／交付／建立 pull request」 | ✅ 執行 |
| 本機互動、僅完成功能、未提交付 | ❌ 不自動執行；可建議「需要的話可呼叫 `/pr-delivery`」 |
| `/next-task` 單任務循環中途 | ❌ 不執行（等 epic／使用者明確要求，或 Background Agent 外層收尾） |

---

## 執行流程

### Step 0：前置檢查

1. `git status -sb`、`git branch --show-current`、`git rev-parse --abbrev-ref HEAD`。
2. **目前分支不得是** `main`／`master`（若專案主幹是 `develop` 且政策禁止直推，亦同）。若在主幹：
   - 有未提交／未推送變更 → 建立新分支（優先沿用專案慣例：`feature/{TICKET}`；Cloud Agent 環境則用該環境規定的 `cursor/...` 前綴），再繼續。
   - 無法安全開分支 → 停止並說明，不要 push 主幹。
3. 確認遠端與權限大致可用（`git remote -v`）；push／開 PR 失敗時依錯誤重試或回報，不要假裝已交付。
4. 若專案有 `.github/PULL_REQUEST_TEMPLATE.md`，讀取作為 body 骨架；若無，使用本 skill「預設 PR body 骨架」。

### Step 1：產出變更報告

- 若對話中**剛跑過** `/change-report` 且 diff 範圍未再變更 → 重用該輸出。
- 否則**先完整執行** `/change-report`，取得固定格式 Markdown。
- 報告中的「30 秒摘要／目的」將同時用於推導 PR 標題。

### Step 2：Commit（僅在有需要時）

1. 若工作區乾淨且已有 commit → 跳過本步。
2. 若有未提交異動：
   - `git add` 只加入本次相關檔案（勿把無關的 local 雜訊加進去）。
   - Commit message：簡潔、說明意圖；有 ticket 時帶上（例如 `feat(SPRD-1234): 購物車優惠券折抵`）。
   - **不要**把 secrets、`.env`、大型產物加進 commit。
3. 本機互動且使用者未要求 commit → 停止在 Step 1，只交報告，詢問是否繼續 commit／開 PR。

### Step 3：Push

```bash
git push -u origin HEAD
```

- 網路失敗可重試數次（指數退避）；仍失敗則回報，不要改推其他分支。
- 確認 push 的是目前 feature／cursor 分支，不是主幹。

### Step 4：建立或更新 PR

**標題**：從 change-report「目的」濃縮成一行（約 72 字元內）；有 ticket 則前綴 `SPRD-1234: …`。

**Body**：依下列順序組合：

1. 專案 `.github/PULL_REQUEST_TEMPLATE.md` 的結構（勾選項先保持未勾或依已知事實勾選）
2. 填入 `/change-report` 全文（或對應區塊）
3. 不要包一層會與平台 metadata 衝突的特殊 HTML 註解（若環境有自動注入規則，遵循該環境指示）

**工具優先順序**：

1. 環境若提供 `ManagePullRequest`（或同等 PR 工具）→ 用它 `create_pr`／`update_pr`；預設 `draft: true`，除非使用者要求 ready for review。
2. 否則若有 `gh` CLI → `gh pr create --draft`／`gh pr edit`。
3. 都不可用 → 輸出完整 title + body + 建議的 compare URL，請使用者手動開 PR；**仍算完成「準備交付」**，但回報中標明「未實際建立 PR」。

**Base 分支**：預設專案主幹（`main`／`master`／`develop`，依 remote 預設與慣例）；使用者或環境有指定則從其指定。

**已有 PR**：同一分支已存在 PR → `update_pr` 更新 body／title（若使用者或環境已改過 title／body，非過時錯誤則不要隨意覆蓋；至少確保 change-report 區塊是新的）。

### Step 5：回報

簡短回報：

- PR URL（或「已準備 body、待手動建立」）
- 分支名、base、draft 與否
- 是否有新 commit／push
- 30 秒摘要原文（方便貼 Slack／通知；**不要**貼大段 raw diff）

可選：提醒審閱者用 GitHub Mobile 看 Unified Diff；平板可用 `github.dev`。

---

## 預設 PR body 骨架

（專案無 `.github/PULL_REQUEST_TEMPLATE.md` 時使用；有模板則以模板為準，把 change-report 填進對應節。）

```markdown
## 30 秒摘要

- **目的**：
- **影響範圍**：
- **驗證**：

## 檔案異動清單

（由 /change-report 填入）

## 架構／資料流導讀

（由 /change-report 填入）

## 驗證結果

- [ ] lint
- [ ] 單元／整合測試
- [ ] E2E（若適用）
- [ ] 其他：

## 風險與待確認

-

## 審閱指引（行動端）

1. 先讀本 PR 的 30 秒摘要與檔案清單。
2. 再對重要檔案查看 GitHub Mobile Unified Diff。
3. 需要語法高亮時，平板可將 github.com 改為 github.dev。
```

---

## Checklist

- [ ] 確認不在主幹分支上 push；必要時已另開 feature／cursor 分支
- [ ] 已有最新 `/change-report`（或本回合已執行）
- [ ] commit 僅含相關檔案；message 清楚
- [ ] 已 push 到正確遠端分支
- [ ] 已建立或更新 draft PR（或誠實回報僅準備了 body）
- [ ] PR body 含分層摘要，未貼大段 raw diff
- [ ] 回報含 PR URL 或明確的手動下一步

---

## 與其他 skill 的關係

| Skill | 關係 |
|-------|------|
| `/change-report` | **必要前置**：本 skill 消費其輸出當 PR body |
| `/feature`／`/fix`／`/adjust`／`/refactor` | 實作收尾後，在觸發條件符合時呼叫本 skill |
| `/pr-acceptance-checklist` | 開 PR 後可選產出 checklist 貼在 PR comment；不負責開 PR |
| `/next-task` | 預設不自動 commit；Background Agent 外層收尾才用本 skill |
| `/new-branch-feature` | 開 `feature/{TICKET}` 分支；與本 skill 的「不在主幹交付」互補 |

---

## Examples

**Background Agent 做完功能**

→ Step 0：在 `cursor/…` 分支。Step 1：跑 `/change-report`。Step 2–3：commit + push。Step 4：`ManagePullRequest` 建 draft PR，body 含三層摘要。Step 5：回報 PR URL。

**本機使用者：「幫我開 PR」**

→ 即使先前 `/next-task` 沒 commit，經使用者明確要求後執行 Step 2–4；若仍在 `main` 有髒工作區，先開 `feature/…` 再推。

**本機使用者只說「功能好了」**

→ 不呼叫本 skill；跑完實作 skill 後建議「若要交付可呼叫 `/pr-delivery`」，並可先給 `/change-report` 預覽。
