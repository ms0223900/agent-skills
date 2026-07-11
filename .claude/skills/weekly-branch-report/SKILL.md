---
name: weekly-branch-report
description: 依作者與日期區間整理 feature 分支週報，分「已合併 uat」（含部分合併）與「進行中」（區間內有 commit 但尚未上 uat）兩類輸出單層清單。使用時機：使用者詢問「這週合併到 uat 的分支」、「進行中的分支」、「我的週報分支」、「整理本週分支清單」，或提供日期區間要求彙整 uat 合併與進行中紀錄。
---

# 週期分支週報 (Weekly Branch Report)

依作者與日期區間，整理 feature 分支週報並分兩類輸出：

1. **已合併 uat**：至少有一筆區間內 commit 已進入 `origin/uat`
2. **進行中**：區間內有作者 commit，且至少有一筆**尚未**進入 `origin/uat`

> 部分合併也算「已合併」；同一工單可同時出現在兩區（例如部分 commit 已上 uat、部分仍在 branch 上）。
> 進行中**僅看區間內 commit**；這週沒有新 commit 的舊分支不列入。

## 輸入參數

從使用者訊息解析，缺省值如下：

| 參數 | 預設 | 說明 |
|------|------|------|
| `author` | **必填**（依使用者指定） | Git author 名稱；對應 `git log --author` 的子字串匹配 |
| `startDate` | 本週週一 00:00（本地時區） | 格式 `YYYY-MM-DD` 或 `YYYY/M/D` |
| `endDate` | 下週週一 00:00（不含） | 同上；區間為 `[startDate, endDate)` |
| `target` | `origin/uat` | 合併目標分支 |
| `ticketPattern` | `(SPRD\|SOPS)-[0-9]+` | 工單編號正則，依專案慣例調整 |

使用者若明確給區間（例如 `2026/6/8 ~ 2026/6/14`），以其為準，不要自行改寫。

### 預設週期計算

使用者未指定日期時，依**執行環境本地時區**計算：

1. 取今天日期 `today`
2. `startDate` = `today` 所在週的**週一** 00:00（ISO 週：週一為一週開始）
3. `endDate` = `startDate + 7 天`（下週週一 00:00，不含當日）

範例（UTC+8）：2026-07-12（週日）執行「這週」→ `2026-07-07` ~ `2026-07-14`（含 7/7～7/13 的 commit，不含 7/14 00:00 起）。

> **區間語意**：`endDate` 為**不含**邊界。使用者給 `6/8 ~ 6/14` 且期望含 6/14 整天時，應將 `endDate` 設為 `6/15`。

## Step 1：在 git 找符合條件的分支

### 1.1 同步遠端

```bash
git fetch --all
```

若 fetch 失敗（無網路、無 remote、認證失敗），**必須向使用者警告**結果可能基於過期的 `origin/uat`，不可靜默忽略。

### 1.2 收集作者於區間內的 non-merge commits

```bash
git rev-list --all \
  --author="{author}" \
  --since="{startDate} 00:00:00" \
  --until="{endDate} 00:00:00" \
  --no-merges
```

- 時間以 **committer date** 為準（Git 預設）。
- 排除 merge commit、stash（`index on` / `WIP on` 可忽略不列入分支）。
- `--author` 為子字串匹配：輸入過短可能誤匹配多人；顯示名稱與 git config 不一致可能漏列。

### 1.3 對每筆 commit 判斷歸屬分支

**禁止**用 `git branch -a --contains` 取第一個 `feature/*` 分支——commit 合併進 uat 後常同時出現在多個分支，會誤判（例如全歸到同一工單分支）。

依序判斷工單編號，命中即停：

1. **subject** 擷取 `{ticketPattern}`
2. **`git log --source --remotes` 的 `%S`**（遍歷時**到達該 commit 的來源 ref**；需 `--source`。搭配 `--all` 時結果可能不穩定，合併進 uat 後常為 uat ref 而非 feature branch）
3. **`git name-rev --name-only <hash>`** 從名稱中擷取工單編號
4. **`{target}` merge commit 訊息**（`Merge branch 'feature/SPRD-xxxx'`）輔助對應；優先掃描區間內 merge，再 fallback 至完整 uat 歷史（支援 merge 日期跨週但 commit 已在 uat 的情境）

```bash
git log --all --source --remotes \
  --author="{author}" \
  --since="{startDate} 00:00:00" \
  --until="{endDate} 00:00:00" \
  --no-merges \
  --format='%H\t%s\t%S'
```

`chore:` 版本號 commit 不列入變更摘要，但仍計入工單（若該工單僅有 chore 已 merge，摘要可寫「版本更新」）。

### 1.4 判定「有合併到 uat」

分支符合條件，若滿足**任一**：

1. 該 commit hash 是 `{target}` 的 ancestor：

```bash
git merge-base --is-ancestor <commit-hash> origin/uat
```

2. 該 commit 屬於某 feature 分支，且 `{target}` 歷史存在合併該分支的 merge commit（commit 為 merge 的 `^2` 後代）：

```bash
# 先 resolve 出 ticket，再查 uat merge
git log origin/uat --merges --grep="Merge branch 'feature/{ticket}'"
# 確認 commit 是該 merge 的 ^2 的 ancestor
git merge-base --is-ancestor <commit-hash> <merge-hash>^2
```

> 判定基準以 `origin/uat` 為準，不要用可能較舊或較新的本地 `uat`。

**已知限制**（無法可靠偵測時可能漏列，應如實告知使用者）：

- **Squash merge**：無 `^2`，條件 2 失效；若 squash 後原 branch commit 不在 uat 祖先鏈，條件 1 也失效
- **Cherry-pick**：pick 後產生新 hash，原 branch commit 可能不被視為 uat ancestor
- **非標準 merge 訊息**：僅支援 `Merge branch 'feature/{TICKET}'` 格式；PR merge、squash 訊息需靠 subject 含工單號

### 1.5 去重

- **不同工單絕不可合併成同一行**（例如 `SPRD-1181`、`SPRD-1190` 應各自獨立）。
- **同一工單只保留一行**，該工單區間內所有非 `chore` commit 概括為一句摘要。
- 略過 `chore:` 版本號 commit 的摘要內容，但工單仍列入清單。
- 依工單編號排序（依前綴分組或數字升冪，保持一致即可）。

### 1.7 判定「進行中」

沿用 Step 1.2～1.3 的 commit 收集與工單歸因，篩選條件改為：

- 區間內有作者 non-merge commit
- 能 resolve 出工單編號
- 該 commit **不符合** Step 1.4「有合併到 uat」的任一條件

同一工單若部分 commit 已上 uat、部分尚未，則**同時**出現在「已合併 uat」與「進行中」兩區。

- 僅 `chore` 且尚未 merge 的工單：**算進行中**，摘要可寫「版本更新（進行中）」。
- 這週無新 commit 的分支：不列入（不做跨週 carry-over）。

### 1.8 可選：使用專案腳本

在**目標專案 repo 根目錄**執行（腳本隨 skill 部署至 `.claude/skills/weekly-branch-report/scripts/`）：

```bash
.claude/skills/weekly-branch-report/scripts/list-weekly-uat-branches.sh \
  --author "{author}" \
  --since 2026-06-08 \
  --until 2026-06-15 \
  --ticket-pattern '(SPRD|SOPS)-[0-9]+'
```

| 腳本參數 | 必填 | 預設 | 說明 |
|----------|------|------|------|
| `--author` | ✅ | — | Git author（無預設值） |
| `--since` | ✅ | — | 區間起日（含） |
| `--until` | ✅ | — | 區間迄日（不含，`until 00:00:00`） |
| `--target` | | `origin/uat` | 合併目標 |
| `--ticket-pattern` | | `(SPRD\|SOPS)-[0-9]+` | 工單正則 |
| `--branch-prefix` | | `feature/` | merge 訊息中的分支前綴 |

腳本輸出四區塊：

1. **Commits**：已合併 uat 的 commit，`ticket|hash|date|subject`（date 為 committer date）
2. **TICKETS**：已合併 uat 的去重工單清單
3. **In progress commits**：進行中的 commit，格式同上
4. **IN_PROGRESS**：進行中的去重工單清單

若 `TICKETS` 或 `IN_PROGRESS` 為 `(none — ...)`，代表該類別在區間內無符合分支。

Agent 依 `TICKETS` / `IN_PROGRESS` 逐工單讀取對應 commits，概括變更摘要並格式化。

## Step 2：整理輸出

**嚴格使用以下格式**，不加額外標題或表格：

```text
{startDate} ~ {endDate}

已合併 uat
- {工單編號} - {分支摘要}
- {工單編號} - {分支摘要}

進行中
- {工單編號} - {分支摘要}
- {工單編號} - {分支摘要}
```

### 格式規則

- 第一行：日期區間，採使用者提供的寫法（如 `2026/6/8 ~ 2026/6/14`）。
- 「已合併 uat」「進行中」為固定區段標題，各佔一行。
- 每個分支一行，以 `- ` 開頭。
- `{工單編號}`：工單編號即可（如 `SPRD-1261`），**不要**加 `feature/` 前綴。
- `{分支摘要}`：簡短中文，一句話描述分支變更內容；從 commit message、issue 標題或開發脈絡歸納，避免冗長。
- 某區段無符合分支時，仍保留區段標題，下一行寫「（無）」。

### 摘要撰寫原則

1. **一行對應一個工單**（見 Step 1.5）。
2. 優先讀取該工單 commits 的 `feat(...)` / `fix(...)` / `refactor(...)` / `docs(...)` 訊息。
3. 多筆 commit 時，概括共通主題，不要逐條列 commit。
4. 僅 `chore` 的工單：已 merge 摘要可寫「版本更新」；進行中可寫「版本更新（進行中）」。
5. 長度建議 10～25 字，例如「修正列表分頁載入與空狀態顯示邏輯」。

## 範例

**輸入**：作者 alice，2026/6/1 ~ 2026/6/7，有合併到 uat 的分支

**輸出**：

```text
2026/6/1 ~ 2026/6/7

已合併 uat
- SPRD-1181 - 修正表單重複提交與狀態清除邏輯
- SPRD-1190 - Detail 頁輪詢間隔與 debounce、空值處理
- SPRD-1197 - 分類列表長文字截斷顯示

進行中
- SPRD-1205 - 搜尋結果排序與空狀態調整
```

**輸入**：作者 alice，2026/6/8 ~ 2026/6/14

**輸出**：

```text
2026/6/8 ~ 2026/6/14

已合併 uat
- SPRD-1218 - 清單項目數量上限與超限提示
- SPRD-1044 - 表格欄位數量限制調整為 8
- SPRD-1246 - 手機版底部導覽選單順序重排
- SOPS-3286 - 核心模組函式與參數修正
- SOPS-3306 - iframe 內嵌時 API 網域放行
- SOPS-3307 - 設定頁選項區分不同模式
- SPRD-1261 - 資料映射與次要欄位顯示修正

進行中
- SPRD-1270 - Detail 頁 loading 與錯誤重試
- SPRD-1218 - 後續空狀態處理
- SOPS-3310 - 版本更新（進行中）
```

## 執行注意事項

- **必須實際執行 git 命令**，不可憑記憶或臆測分支清單。
- **必須傳入 `--author`**（腳本或手動流程皆然）；不可使用硬編碼預設作者。
- 若某區段無符合分支，仍輸出該區段標題，下一行寫「（無）」。
- 不要輸出 merge commit 清單、統計表或 commit hash，除非使用者另外要求。
- 最終回覆以 Step 2 格式為主；調查過程不需冗長說明。
