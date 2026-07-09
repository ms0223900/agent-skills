---
name: new-branch-feature
description: 從 master 建立新的 feature 分支。使用時機：使用者提供 JIRA 單號或 JIRA 網址，想要建立對應的 feature 分支（例如「幫我開 SPRD-614 的分支」）。
---

# 建立 feature 分支 (New Branch for Feature)

依照 README 規範：自 `master` 建立新分支，分支命名為 `feature/{JIRA_單號}`。

## 你要做的事

1. **取得 JIRA 單號**
   - 從使用者輸入中取得 JIRA 單號。
   - 若使用者給的是 **JIRA 單號**（例如 `SPRD-614`、`SOPS-1001`），直接使用。
   - 若使用者給的是 **JIRA 網址**，從網址中擷取單號（常見格式：`/browse/PROJECT-NUMBER` 或路徑中含有 `PROJECT-NUMBER` 的區段）。單號格式為：大寫專案代碼 + `-` + 數字，例如 `SPRD-614`。
   - 若無法從輸入取得有效單號，請回覆使用者並請他提供 JIRA 單號或 JIRA 連結。

2. **切換到 master 並同步**
   - 執行：`git checkout master`
   - 執行：`git pull`（或 `git pull origin master`）以拉取最新進度。

3. **建立並切換到新分支**
   - 分支名稱必須為：`feature/{JIRA單號}`（例如 `feature/SPRD-614`）。
   - 執行：`git checkout -b feature/{JIRA單號}`（將 `{JIRA單號}` 替換為實際擷取到的單號）。

4. **確認結果**
   - 簡短回報：已切到 `master`、已拉取最新、已建立並切換到 `feature/{JIRA單號}`。

## 使用者輸入說明

使用者會在指令後方輸入 JIRA 單號或 JIRA 網址，例如：
- `/new-branch-feature SPRD-614`
- `/new-branch-feature SOPS-1001`
- `/new-branch-feature https://company.atlassian.net/browse/SPRD-614`

請根據上述規則解析並執行，不要跳過任何步驟。
