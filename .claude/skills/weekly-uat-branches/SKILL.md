---
name: weekly-uat-branches
description: 查詢指定週期內由特定作者提交、且已合併（含部分合併）至 uat 的 feature 分支，並輸出單層清單。使用時機：使用者詢問「這週合併到 uat 的分支」、「我的週報分支」、「某作者本週 uat 合併紀錄」，或提供日期區間要求整理分支清單。
---

# 週期 uat 合併分支清單 (Weekly UAT Branches)

依作者與日期區間，找出**至少有一筆 commit 已進入 `origin/uat`** 的 feature 分支，輸出單層清單。

> 部分合併也算符合條件；不必等分支 tip 完全合併。

## 輸入參數

從使用者訊息解析，缺省值如下：

| 參數 | 預設 | 說明 |
|------|------|------|
| `author` | 依使用者指定 | Git author 名稱 |
| `startDate` | 本週週一 00:00 | 格式 `YYYY-MM-DD` 或 `YYYY/M/D` |
| `endDate` | 下週週一 00:00（不含） | 同上；區間為 `[startDate, endDate)` |
| `target` | `origin/uat` | 合併目標分支 |
| `ticketPattern` | `[A-Z]+-[0-9]+` | 工單編號正則，依專案慣例調整（如 `PROJ-1234`） |

使用者若明確給區間（例如 `2026/6/8 ~ 2026/6/14`），以其為準，不要自行改寫。

## Step 1：在 git 找符合條件的分支

### 1.1 同步遠端

```bash
git fetch --all
```

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

### 1.3 對每筆 commit 判斷歸屬分支

**禁止**用 `git branch -a --contains` 取第一個 `feature/*` 分支——commit 合併進 uat 後常同時出現在多個分支，會誤判（例如全歸到同一工單分支）。

依序判斷工單編號，命中即停：

1. **subject** 擷取 `{ticketPattern}`
2. **`git log --source --remotes` 的 `%S`**（commit 最初所在的 ref，如 `refs/heads/feature/PROJ-1181`）
3. **`git name-rev --name-only <hash>`** 取最近的 feature ref
4. **同期 `{target}` merge commit 訊息**（`Merge branch 'feature/PROJ-xxxx'`）輔助對應

```bash
git log --all --source --remotes \
  --author="{author}" \
  --since="{startDate} 00:00:00" \
  --until="{endDate} 00:00:00" \
  --no-merges \
  --format='%H\t%s\t%S'
```

`chore:` 版本號 commit 不列入變更清單，但可用 `%S` 輔助判斷同期分支。

### 1.4 判定「有合併到 uat」

分支符合條件，若滿足**任一**：

1. 該分支在區間內至少有一筆作者 commit 是 `{target}` 的 ancestor：

```bash
git merge-base --is-ancestor <commit-hash> origin/uat
```

2. `{target}` 歷史中存在合併該分支的 merge commit：

```bash
git log origin/uat --merges \
  --since="{startDate}" --until="{endDate}" \
  --grep="Merge branch 'feature/{ticket}'"
```

> 判定基準以 `origin/uat` 為準，不要用可能較舊或較新的本地 `uat`。

### 1.5 去重

- **不同工單絕不可合併成同一行**（例如 `PROJ-1181`、`PROJ-1190`、`PROJ-1197` 應各自獨立）。
- **同一工單只保留一行**，該工單區間內所有非 `chore` commit 概括為一句摘要。
- 略過 `chore:` 版本號 commit。
- 依工單編號排序（依前綴分組或數字升冪，保持一致即可）。

### 1.6 可選：使用專案腳本

若專案提供對應腳本，可依參數執行：

```bash
.claude/skills/weekly-uat-branches/scripts/list-weekly-uat-branches.sh \
  --author {author} \
  --since 2026-06-08 \
  --until 2026-06-14
```

> 腳本內的工單前綴正則可能綁定特定專案；使用前確認 `ticketPattern` 是否相符，必要時調整腳本或改用手動 git 命令。

腳本輸出兩區塊：

1. **Commits**：`ticket|hash|date|subject`（每筆 commit 含正確工單編號）
2. **TICKETS**：已去重的工單清單（一行一工單）

Agent 依 `TICKETS` 逐工單讀取對應 commits，概括變更摘要並格式化。

## Step 2：整理輸出

**嚴格使用以下格式**，不加額外標題或表格：

```text
{startDate} ~ {endDate}
- {工單編號} - {分支摘要}
- {工單編號} - {分支摘要}
```

### 格式規則

- 第一行：日期區間，採使用者提供的寫法（如 `2026/6/8 ~ 2026/6/14`）。
- 每個分支一行，以 `- ` 開頭。
- `{工單編號}`：工單編號即可（如 `PROJ-1261`），**不要**加 `feature/` 前綴。
- `{分支摘要}`：簡短中文，一句話描述分支變更內容；從 commit message、issue 標題或開發脈絡歸納，避免冗長。

### 摘要撰寫原則

1. **一行對應一個工單**（見 Step 1.5）。
2. 優先讀取該工單 commits 的 `feat(...)` / `fix(...)` / `refactor(...)` / `docs(...)` 訊息。
3. 多筆 commit 時，概括共通主題，不要逐條列 commit。
4. 長度建議 10～25 字，例如「修正列表分頁載入與空狀態顯示邏輯」。

## 範例

**輸入**：作者 alice，2026/6/1 ~ 2026/6/7，有合併到 uat 的分支

**輸出**：

```text
2026/6/1 ~ 2026/6/7
- PROJ-1181 - 修正表單重複提交與狀態清除邏輯
- PROJ-1190 - Detail 頁輪詢間隔與 debounce、空值處理
- PROJ-1197 - 分類列表長文字截斷顯示
```

**輸入**：作者 alice，2026/6/8 ~ 2026/6/14

**輸出**：

```text
2026/6/8 ~ 2026/6/14
- PROJ-1218 - 清單項目數量上限與超限提示
- PROJ-1044 - 表格欄位數量限制調整為 8
- PROJ-1246 - 手機版底部導覽選單順序重排
- OPS-3286 - 核心模組函式與參數修正
- OPS-3306 - iframe 內嵌時 API 網域放行
- OPS-3307 - 設定頁選項區分不同模式
- PROJ-1261 - 資料映射與次要欄位顯示修正
```

## 執行注意事項

- **必須實際執行 git 命令**，不可憑記憶或臆測分支清單。
- 若區間內無符合分支，仍輸出日期標題行，並回覆「此區間無符合條件的分支」。
- 不要輸出 merge commit 清單、統計表或 commit hash，除非使用者另外要求。
- 最終回覆以 Step 2 格式為主；調查過程不需冗長說明。
