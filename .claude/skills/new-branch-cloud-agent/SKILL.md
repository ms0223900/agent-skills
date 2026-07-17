---
name: new-branch-cloud-agent
description: 為 Cursor Background／Cloud Agent 建立符合雲端慣例的工作分支（cursor/<descriptive-name>-<suffix>），禁止在 main／master 上直接開發或推送。使用時機：Cloud／Background Agent 開工前、系統指示要求 cursor/ 前綴分支、或使用者說「開雲端分支」「cloud agent 分支」。本機依 JIRA 開 feature/{TICKET} 請用 /new-branch-feature。
---

# 建立 Cloud Agent 分支（New Branch for Cloud Agent）

## 目標

在 **Background／Cloud Agent** 環境開出可安全 commit／push／開 PR 的工作分支，命名符合雲端慣例，並與本機 `feature/{JIRA}` 慣例分開。

**不要**在 `main`／`master`（或專案受保護主幹）上直接改檔或 push。開完分支後的交付交給 `/pr-delivery`。

---

## 何時使用 / 何時不用

**使用時機**：

- 目前是 Background／Cloud Agent，系統指示分支須為 `cursor/...`。
- 使用者說「開雲端分支」「cloud agent 分支」「依 cloud 規則開 branch」。
- `/pr-delivery` Step 0 發現人在主幹上、需要先開雲端工作分支。

**何時不用（改用其他 skill）**：

| 情境 | 改用 |
|------|------|
| 本機開發、有 JIRA 單號、要開 `feature/{TICKET}` | `/new-branch-feature` |
| 只要交付已有變更的 PR | `/pr-delivery`（分支已存在時） |

---

## 分支命名規則

格式：

```text
cursor/<descriptive-name>-<suffix>
```

約束：

1. **前綴**必須是 `cursor/`（小寫）。
2. **`<descriptive-name>`**：kebab-case、小寫英數與連字號；簡短描述本次工作（例如 `p0-change-report-pr-delivery`、`fix-cart-coupon`）。可含 ticket 小寫形式（如 `sprd-1336-phase2`），但不要用 `feature/` 前綴。
3. **`<suffix>`**：
   - 若目前 Cloud／Agent 指示已給定固定後綴（例如指示寫明所有新分支須以 `-fd56` 結尾）→ **必須用該後綴**。
   - 若無指定 → 使用 4～6 位小寫英數短碼（例如從執行 ID／隨機產生），整段名稱仍保持唯一。
4. 全名僅小寫；勿建立僅大小寫不同的分支（macOS／Windows 檔案系統會撞名）。
5. 不要用 `main`／`master`／`develop`／`uat` 當新分支名。

範例：

- `cursor/p0-change-report-pr-delivery-fd56`
- `cursor/sprd-1336-cart-coupon-a1b2`

---

## 你要做的事

1. **確認不在錯誤目標上硬幹**
   - `git branch --show-current`、`git status -sb`。
   - 若已在符合規則的 `cursor/...` 分支且就是本次工作要用的 → 回報「已在目標分支」，不要重複建立。

2. **決定分支名**
   - 從使用者描述或目前任務摘要抽出 `<descriptive-name>`。
   - 套用上方「後綴」規則組成全名。
   - 名稱過長時縮短 descriptive 段，保留後綴。

3. **選定 base 並同步**
   - Base 預設為遠端預設主幹（常見 `main`，否則 `master`；專案慣例是 `develop` 則從其指示）。
   - `git fetch origin <base>`（網路失敗可重試），再 `git checkout <base>` 並快轉到 `origin/<base>`（或 `git pull`）。
   - 工作區有未提交變更且會阻擋切換 → 先 stash 或請示使用者，不要丟棄他人／未備份的工作。

4. **建立並切換**
   - `git checkout -b cursor/<descriptive-name>-<suffix>`。
   - 若分支名已存在：改換後綴或加短描述後重試；不要 force 刪別人的遠端分支。

5. **確認結果**
   - 回報：base、新分支全名、目前 `HEAD` 是否乾淨。
   - 提醒後續交付用 `/pr-delivery`（會再跑 `/change-report`）；本機 JIRA 流程仍用 `/new-branch-feature`。

---

## 與 `/new-branch-feature` 的分工

| | `/new-branch-feature` | `/new-branch-cloud-agent` |
|--|----------------------|---------------------------|
| 對象 | 本機／有 JIRA 的功能開發 | Background／Cloud Agent |
| 命名 | `feature/{JIRA}` | `cursor/<name>-<suffix>` |
| Base | 專案 README 慣例（常為 `master`） | 遠端預設主幹或環境指定 |
| 之後 | 本機開發；commit 策略依專案 | 通常接 `/pr-delivery` 開 draft PR |

兩者不要混用命名空間：不要把 Cloud Agent 工作推到 `feature/...`，也不要在本機 JIRA 流程硬套 `cursor/...`（除非使用者或環境明確要求）。

---

## Examples

**Cloud Agent 指示：分支須為 `cursor/<descriptive-name>-fd56`，任務是加 change-report**

→ 從 `main` 同步後執行：`git checkout -b cursor/p0-change-report-pr-delivery-fd56`，回報已切換。

**`/pr-delivery` 發現目前在 `main` 且有未提交變更**

→ 先 stash 或確認可帶著變更切分支 → 呼叫本 skill 開 `cursor/...` → 再回 `/pr-delivery` 繼續 commit／push／開 PR。
