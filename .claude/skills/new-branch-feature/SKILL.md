---
name: new-branch-feature
description: 從 master（或專案慣用主幹）建立本機用的 feature 分支 feature/{JIRA}。使用時機：使用者提供 JIRA 單號或 JIRA 網址（例如「幫我開 SPRD-614 的分支」）。Background／Cloud Agent 請改用 /new-branch-cloud-agent（cursor/<name>-<suffix>）。
---

# 建立 feature 分支 (New Branch for Feature)

依照 README 規範：自 `master` 建立新分支，分支命名為 `feature/{JIRA_單號}`。

> **分工**：本 skill 給**本機／有 JIRA 的功能開發**。若是 Background／Cloud Agent，或環境要求 `cursor/...` 分支命名 → 改用 `/new-branch-cloud-agent`，不要把雲端工作硬塞進 `feature/{JIRA}`。

## 你要做的事

1. **取得 JIRA 單號**
   - 從使用者輸入中取得 JIRA 單號。
   - 若使用者給的是 **JIRA 單號**（例如 `SPRD-614`、`SOPS-1001`），直接使用。
   - 若使用者給的是 **JIRA 網址**，從網址中擷取單號（常見格式：`/browse/PROJECT-NUMBER` 或路徑中含有 `PROJECT-NUMBER` 的區段）。單號格式為：大寫專案代碼 + `-` + 數字，例如 `SPRD-614`。
   - 若無法從輸入取得有效單號，請回覆使用者並請他提供 JIRA 單號或 JIRA 連結。
   - 若使用者其實是要開 Cloud Agent 分支（提到 cloud／background／`cursor/`）→ 改呼叫 `/new-branch-cloud-agent`，不要繼續用本 skill。

2. **切換到 master 並同步**
   - 執行：`git checkout master`
   - 執行：`git pull`（或 `git pull origin master`）以拉取最新進度。
   - 若專案慣用主幹不是 `master`（例如 `main`），依該專案 README／既有分支慣例，並在回報中說明實際使用的 base。

3. **建立並切換到新分支**
   - 分支名稱必須為：`feature/{JIRA單號}`（例如 `feature/SPRD-614`）。
   - 執行：`git checkout -b feature/{JIRA單號}`（將 `{JIRA單號}` 替換為實際擷取到的單號）。

4. **確認結果**
   - 簡短回報：已切到 base、已拉取最新、已建立並切換到 `feature/{JIRA單號}`。

## 使用者輸入說明

使用者會在指令後方輸入 JIRA 單號或 JIRA 網址，例如：
- `/new-branch-feature SPRD-614`
- `/new-branch-feature SOPS-1001`
- `/new-branch-feature https://company.atlassian.net/browse/SPRD-614`

請根據上述規則解析並執行，不要跳過任何步驟。
