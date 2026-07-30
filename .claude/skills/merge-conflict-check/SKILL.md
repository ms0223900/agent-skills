---
name: merge-conflict-check
description: 以 git dry-run（merge-tree）評估目前分支與 main／master 合併是否會衝突，不改工作區、不做真合併。使用時機：使用者問「合進 main 會不會衝突」「merge 會不會撞」「把 main 合進來會不會衝突」、PR 前自檢、長時間 feature 分支要對主幹。
---

# 合併衝突檢查（Merge Conflict Check）

## 目標

用 **dry-run** 評估目前分支與主幹（`main` 或 `master`）合併時**會不會有衝突**，產出可掃讀報告。

本 skill **只讀、只報告**：

- **禁止** `git merge` / `git rebase` / 改檔 / commit / push / 開 PR
- **禁止**在目前工作區執行會改 index／working tree 的 merge（含 `--no-commit` 再 abort）
- 首選 `git merge-tree`（不碰工作區）

要看變更內容 → `/change-report`。要開 PR → `/pr-delivery`。

---

## 何時使用 / 何時不用

**使用時機**：

- 「這個分支合進 main／master 會不會衝突？」
- 「把 main／master merge 進目前分支會不會撞？」
- PR 前快速自檢、長時間 feature 分支對齊主幹前

**何時不用**：

| 情境 | 改用 |
|------|------|
| 要真的解衝突、rebase、merge | 交給使用者本機操作（本 skill 不代做） |
| 只要看改了什麼 | `/change-report` |
| 要開／更新 PR | `/pr-delivery` |
| 目前就在主幹且無分岔可評估 | 直接回報「無分岔／無衝突可評估」 |

---

## 輸入參數

從使用者訊息解析；缺省如下：

| 參數 | 預設 | 說明 |
|------|------|------|
| `base` | **自動偵測**（見 Step 1） | 目標主幹：`main` 或 `master`（含 `origin/` 遠端 ref） |
| `head` | 目前分支 `HEAD` | 可改指定其他本地／遠端分支 |
| `fetch` | `true` | 是否先 `git fetch` 更新遠端主幹 |
| `direction` | `into-base` | 見下方「合併方向」 |

### 合併方向

| `direction` | 語意 | 何時選用 |
|-------------|------|----------|
| `into-base`（預設） | 把 `head` 合併進 `base`（PR 合併方向：`base ← head`） | 使用者說「合進 main」「PR 會不會衝突」「能不能 merge 到 master」 |
| `into-head` | 把 `base` 合併進 `head`（把主幹合進目前分支） | 使用者**明確提及**「把 main／master 合進來」「merge main into 目前分支」「rebase／對齊主幹前會不會撞」 |

規則：

1. 預設只跑 **`into-base`**。
2. 若使用者提及把主幹併入目前分支 → 另跑（或改跑）**`into-head`**，報告中標明方向。
3. 若兩者都問到 → **兩方向都跑**，報告分兩段，勿混成一個結論。

---

## 執行流程

### Step 0：前置檢查

```bash
git status -sb
git branch --show-current
git rev-parse --short HEAD
```

1. 記錄目前分支名與 `HEAD` short SHA。
2. 若工作區有未提交異動（含 staged／unstaged／untracked 會影響合併語意者）：
   - **仍只評估已 commit 的 `head` tip**
   - 報告中必須標「⚠️ 工作區有未提交變更，未納入本次檢查」
3. 不要 stash、不要幫使用者 commit「只為了檢查」。

### Step 1：自動判斷主幹（main vs master）

使用者有明確指定 `main`／`master`／`origin/xxx` → 直接使用，跳過自動偵測。

否則依序判定 **唯一** `base`（先遠端、再本地）：

1. `git rev-parse --verify origin/main` 成功 → `base = origin/main`
2. 否則 `git rev-parse --verify origin/master` 成功 → `base = origin/master`
3. 否則本地 `main` → `base = main`
4. 否則本地 `master` → `base = master`
5. 若專案文件／慣例明確以其他分支為受保護主幹（例如 README 寫預設 `develop`）且使用者未指定 → 可改用該主幹，但報告必須寫「依專案慣例使用 `develop`」
6. 以上皆無 → 結論 **❓ 無法判定**，詢問使用者目標分支，**停止**（不要猜）

同名同時存在時：**優先 `main`，不用 `master`**（遠端與本地皆同此優先序）。

報告中寫清實際採用的 ref（例如 `origin/main`），不要只寫「主幹」。

### Step 2：同步遠端（可選但預設做）

`fetch=true`（預設）時：

```bash
# 只 fetch 需要的主幹短名（main 或 master）
git fetch origin <base-short-name>
```

- `<base-short-name>`：從 Step 1 的 ref 去掉 `origin/`（`origin/main` → `main`）。
- fetch 失敗（網路／權限）→ **必須醒目警告**「僅用本地 ref，結果可能過期」，然後繼續用現有本地／遠端追蹤分支；不可靜默忽略。
- `fetch=false`（使用者要求離線／不要 fetch）→ 跳過，並在報告標「未 fetch」。

可選確認 tip：

```bash
git rev-parse --short <base>
git log -1 --oneline <base>
```

### Step 3：共同祖先與trivial 情況

```bash
git merge-base <base> <head>
git merge-base --is-ancestor <head> <base>   # head 是否已全部在 base 裡
git merge-base --is-ancestor <base> <head>   # base 是否已全部在 head 裡
```

| 情況 | 結論 | 說明 |
|------|------|------|
| 無共同祖先（`merge-base` 失敗）且未允許 unrelated | ❓ 無法判定 | 說明無共同歷史；除非使用者要求，否則不要加 `--allow-unrelated-histories` |
| `into-base` 且 `head` 已是 `base` 的 ancestor | ✅ 可合併 | 「`head` 已包含於 `base`／無新 commit 可合併」，不算衝突 |
| `into-head` 且 `base` 已是 `head` 的 ancestor | ✅ 可合併 | 「`base` 已包含於 `head`／已對齊主幹」，不算衝突 |
| 其餘 | 進入 Step 4 dry-run | |

### Step 4：Dry-run（merge-tree）

依 `direction` 選定「ours／進入方」與「theirs／併入方」：

| direction | 指令語意（現代 Git） |
|-----------|----------------------|
| `into-base` | 將 `<head>` 併入 `<base>`：`git merge-tree --write-tree <base> <head>` |
| `into-head` | 將 `<base>` 併入 `<head>`：`git merge-tree --write-tree <head> <base>` |

**首選（Git ≥ 2.38，含 `--write-tree`）**：

```bash
# into-base：PR 方向
git merge-tree --write-tree --name-only --messages <base> <head>
echo "exit=$?"

# into-head：主幹併入目前分支
git merge-tree --write-tree --name-only --messages <head> <base>
echo "exit=$?"
```

判讀：

- **exit code 0**：無衝突 → 結論 ✅
- **exit code 非 0**：有衝突 → 結論 ⚠️；從 stdout／stderr 解析衝突路徑與訊息
- `--name-only`：取得衝突／受影響路徑清單
- `--messages`：取得衝突說明文字，供摘要使用

**輸出解析要點**：

1. 收集衝突檔案路徑（去重、保持相對 repo 根目錄）。
2. 盡量標衝突類型（內容衝突／delete-modify／rename 等）；`merge-tree` 訊息有寫就沿用，沒有就標「內容或其他（見訊息）」。
3. 不要把整份 merge-tree 原始輸出貼進報告；最多附各檔簡短摘錄。
4. **絕對不要**根據結果去改工作區或建立 merge commit。

**降級 A（無 `--write-tree` 的舊 Git）**：

```bash
git merge-tree $(git merge-base <ours> <theirs>) <ours> <theirs>
```

- `<ours>`／`<theirs>` 對應上表 direction。
- 輸出中出現衝突標記或衝突區段 → ⚠️；否則 ✅。
- 仍不得改工作區。

**降級 B（僅當 merge-tree 完全不可用）**：

1. 用 **temporary worktree**（或臨時目錄 clone／worktree）在隔離環境做 `git merge --no-commit --no-ff`，讀取衝突後**刪除該 worktree**。
2. **禁止**在使用者目前工作區 merge。
3. 報告註明「已用 temporary worktree 備援」。

### Step 5：產出報告

嚴格使用下方「輸出模板」。重點：

- 結論只允許：✅ 可合併｜⚠️ 有衝突｜❓ 無法判定
- 寫明 direction、實際 `base` ref、`head` 分支與 short SHA、merge-base、是否已 fetch
- 有衝突時給檔案表 + 一句建議（本 skill **不代為解衝突**）
- 兩方向都跑時，各用一完整模板區塊，標題標明方向

---

## 輸出模板

```markdown
## 合併衝突檢查 / Merge Conflict Check

- **結論**：✅ 可合併｜⚠️ 有衝突｜❓ 無法判定
- **方向**：`into-base`（`<head>` → `<base>`）或 `into-head`（`<base>` → `<head>`）
- **基準（base）**：`<ref>` @ `<short-sha>`
- **評估分支（head）**：`<branch-or-ref>` @ `<short-sha>`
- **共同祖先**：`<merge-base short-sha>`｜無
- **遠端同步**：已 fetch `origin/<name>`｜僅用本地（過期風險）｜使用者要求未 fetch
- **工作區**：乾淨｜⚠️ 有未提交變更（未納入檢查）

### 衝突檔案（若有）

| 檔案 | 衝突類型 |
|------|----------|
| `path/to/file` | 內容衝突／delete-modify／rename／其他 |

（無衝突則寫「無」）

### 摘要

- 一句話：衝突數量與是否集中於同一模組／目錄
- （可選）各檔衝突訊息或標記附近極短摘錄；不要貼大段 raw 輸出

### 建議下一步

- ✅ 可合併：可自行開 PR，或呼叫 `/pr-delivery`；若要看變更內容用 `/change-report`
- ⚠️ 有衝突：請在本機將主幹合入／rebase 後解衝突再重跑本檢查；本 skill 不代做 merge／rebase
- ❓ 無法判定：依上方原因補 fetch、指定 base、或確認歷史是否相關後重跑
```

兩方向都評估時，用兩個同結構區塊，標題加後綴，例如：

- `## 合併衝突檢查 — into-base（分支 → 主幹）`
- `## 合併衝突檢查 — into-head（主幹 → 目前分支）`

---

## Checklist

- [ ] 已自動判定或採用使用者指定的 `base`（`main` 優先於 `master`），報告寫出實際 ref
- [ ] 已依使用者用語決定 `into-base`／`into-head`／兩者
- [ ] 僅用 `merge-tree`（或批准的 temporary worktree 備援），未污染目前工作區
- [ ] 未執行真合併、未改檔、未 commit／push／開 PR
- [ ] fetch 失敗或工作區髒時已醒目標註
- [ ] 輸出符合模板；結論為三態之一

---

## 與其他 skill 的關係

| Skill | 關係 |
|-------|------|
| `/change-report` | 看「改了什麼」；本 skill 只看「合會不會撞」 |
| `/pr-delivery` | 開 PR 前可手動先跑本 skill；**本 skill 不自動掛進 pr-delivery** |
| `/weekly-branch-report` | 跨工單週報；本 skill 是單分支合併可行性 |

---

## Examples

**「目前分支合進 main 會不會衝突？」**

→ Step 1：偵測到 `origin/main` → `base=origin/main`。`direction=into-base`。Step 2：`git fetch origin main`。Step 4：`git merge-tree --write-tree --name-only --messages origin/main HEAD`。exit 0 → 報告 ✅，衝突檔案「無」。

**「幫我看把 master 合進這個 feature 會不會撞」**

→ 使用者指定 master 且要求主幹併入目前分支 → `base=origin/master`（或本地 `master`），`direction=into-head`。Step 4：`git merge-tree --write-tree --name-only --messages HEAD origin/master`。若有衝突 → ⚠️ + 檔案表，建議本機解完再重跑。

**「main 跟合進 PR、以及把 main 拉進來，兩邊都看一下」**

→ 自動選 `origin/main`；`into-base` 與 `into-head` 各跑一次，輸出兩個模板區塊，結論分開寫。

**遠端 fetch 失敗**

→ 警告後改用本地 `origin/main` 或 `main` 繼續 dry-run；報告「遠端同步」標過期風險；不要假裝已與遠端一致。
