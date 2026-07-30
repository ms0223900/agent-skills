# Merge Conflict Check — 指令參考

本文件收錄各步驟的確切 git 指令、判讀規則與降級方案。執行對應步驟前，先讀本文件相應章節，依內容操作。

---

## Step 0：前置檢查指令

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

---

## Step 1：自動判斷主幹（main vs master）指令與規則

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

---

## Step 2：同步遠端指令

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

---

## Step 3：共同祖先與 trivial 情況指令

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

---

## Step 4：Dry-run（merge-tree）指令與判讀

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

---

## Examples（含指令對照）

**「目前分支合進 main 會不會衝突？」**

→ Step 1：偵測到 `origin/main` → `base=origin/main`。`direction=into-base`。Step 2：`git fetch origin main`。Step 4：`git merge-tree --write-tree --name-only --messages origin/main HEAD`。exit 0 → 報告 ✅，衝突檔案「無」。

**「幫我看把 master 合進這個 feature 會不會撞」**

→ 使用者指定 master 且要求主幹併入目前分支 → `base=origin/master`（或本地 `master`），`direction=into-head`。Step 4：`git merge-tree --write-tree --name-only --messages HEAD origin/master`。若有衝突 → ⚠️ + 檔案表，建議本機解完再重跑。

**「main 跟合進 PR、以及把 main 拉進來，兩邊都看一下」**

→ 自動選 `origin/main`；`into-base` 與 `into-head` 各跑一次，輸出兩個模板區塊，結論分開寫。

**遠端 fetch 失敗**

→ 警告後改用本地 `origin/main` 或 `main` 繼續 dry-run；報告「遠端同步」標過期風險；不要假裝已與遠端一致。
