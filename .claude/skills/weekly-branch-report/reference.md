# Weekly Branch Report — Git 查詢指令參考

本文件收錄 Step 1（在 git 找符合條件的分支）的確切查詢指令、判定規則與已知限制。執行 Step 1 前先讀本文件，依內容操作，不可憑記憶或臆測分支清單。

---

## 1.1 同步遠端

```bash
git fetch --all
```

若 fetch 失敗（無網路、無 remote、認證失敗），**必須向使用者警告**結果可能基於過期的 `origin/uat`，不可靜默忽略。

---

## 1.2 收集作者於區間內的 non-merge commits

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

---

## 1.3 對每筆 commit 判斷歸屬分支

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

---

## 1.4 判定「有合併到 uat」

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

---

## 1.5 去重

- **不同工單絕不可合併成同一行**（例如 `SPRD-1181`、`SPRD-1190` 應各自獨立）。
- **同一工單只保留一行**，該工單區間內所有非 `chore` commit 概括為一句摘要。
- 略過 `chore:` 版本號 commit 的摘要內容，但工單仍列入清單。
- 依工單編號排序（依前綴分組或數字升冪，保持一致即可）。

---

## 1.7 判定「進行中」

沿用 1.2～1.3 的 commit 收集與工單歸因，篩選條件改為：

- 區間內有作者 non-merge commit
- 能 resolve 出工單編號
- 該 commit **不符合** 1.4「有合併到 uat」的任一條件

同一工單若部分 commit 已上 uat、部分尚未，則**同時**出現在「已合併 uat」與「進行中」兩區。

- 僅 `chore` 且尚未 merge 的工單：**算進行中**，摘要可寫「版本更新（進行中）」。
- 這週無新 commit 的分支：不列入（不做跨週 carry-over）。

---

## 1.8 可選：使用專案腳本

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
