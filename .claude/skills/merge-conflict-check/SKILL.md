---
name: merge-conflict-check
description: 以 git dry-run 評估目前分支與主幹合併是否會衝突，不改工作區、不做真合併。
disable-model-invocation: true
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

> 以下為高層級步驟與完成標準；**確切 git 指令、判讀規則與降級方案一律見 [reference-commands.md](reference-commands.md)**，執行對應步驟前先讀該節，不要憑記憶下指令。

### Step 0：前置檢查

目標：記錄目前分支與 `HEAD`，確認工作區狀態。完成標準：已知目前分支名、`HEAD` short SHA；若工作區有未提交變更，已標記「不納入本次檢查」。指令見 [reference-commands.md](reference-commands.md) Step 0。不要 stash、不要幫使用者 commit「只為了檢查」。

### Step 1：自動判斷主幹（main vs master）

目標：判定唯一 `base` ref。完成標準：已得出唯一 `base`（使用者指定則直接用；否則依優先序自動偵測，`main` 優先於 `master`；皆無則回報 ❓ 並詢問使用者，停止）。判定規則見 [reference-commands.md](reference-commands.md) Step 1。報告中須寫清實際採用的 ref（例如 `origin/main`），不要只寫「主幹」。

### Step 2：同步遠端（可選但預設做）

目標：`fetch=true`（預設）時更新遠端主幹。完成標準：已 fetch 成功，或 fetch 失敗／`fetch=false` 時已在報告中醒目標註過期風險／未 fetch，不可靜默忽略。指令見 [reference-commands.md](reference-commands.md) Step 2。

### Step 3：共同祖先與 trivial 情況

目標：判斷是否為無需 dry-run 的簡單情況。完成標準：已判定「無共同祖先」「head/base 已互為 ancestor（trivial 可合併）」或「需進入 Step 4 dry-run」三者之一。指令與判讀表見 [reference-commands.md](reference-commands.md) Step 3。

### Step 4：Dry-run（merge-tree）

目標：用 `git merge-tree` 評估合併結果，不碰工作區。完成標準：已取得衝突結論（✅／⚠️）與衝突檔案清單（若有）。**首選指令、判讀規則與兩層降級方案（降級 A：舊 Git；降級 B：temporary worktree）一律見 [reference-commands.md](reference-commands.md) Step 4**——依 Git 版本選用對應指令，任何情況都不得改動使用者目前工作區或建立 merge commit。

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

四個常見情境（單方向、指定 master、雙方向都問、fetch 失敗）的完整指令走法見 [reference-commands.md](reference-commands.md) 最末節。
