# agent-skills

個人／團隊用的 Agent Skills 庫，涵蓋需求拆解、實作、測試、重構、驗收與收尾整理。  
相容 [Skills CLI](https://github.com/vercel-labs/skills)（`npx skills`），可一鍵安裝到 Cursor、Claude Code 等 agent。

## 安裝 Install

在目標 repo 根目錄執行：

```bash
# 安裝全部 skills（專案級，可 commit 給團隊）
npx skills add ms0223900/agent-skills --skill '*' -y

# 只裝指定 skills
npx skills add ms0223900/agent-skills --skill feature --skill next-task --skill unit-test -y

# 全域安裝（本機所有專案都能用）
npx skills add ms0223900/agent-skills --skill '*' -g -y

# 指定 agent（例如同時給 Cursor 與 Claude Code）
npx skills add ms0223900/agent-skills --skill '*' -a cursor -a claude-code -y
```

其他來源寫法：

```bash
npx skills add https://github.com/ms0223900/agent-skills
npx skills add git@github.com:ms0223900/agent-skills.git
```

### 預覽 / 更新

```bash
# 列出此庫有哪些 skills
npx skills add ms0223900/agent-skills --list

# 更新已安裝的 skills
npx skills update
```

### Project vs Global

| 範圍 | 旗標 | 用途 |
|------|------|------|
| **Project**（預設） | 不加 `-g` | 寫入專案目錄，可 commit，團隊共享 |
| **Global** | `-g` | 裝到本機 user directory，跨所有專案 |

Private repo 需本機已具備 GitHub 權限（SSH key 或 HTTPS token）。

## Skills 清單

### 流程編排

| Skill | 說明 |
|-------|------|
| `next-task` | 依 branch / JIRA 找出下一個未完成任務並分派對應 skill；**epic 或 sprint 收尾**時建議交付與知識沉澱 |
| `ticket-to-ai-spec` | 把原始 ticket 轉成 AI 可執行的開發規格 |
| `user-stories` | 將需求拆成含 AC、測試策略、依賴關係的 User Stories |
| `new-branch-feature` | 本機依 JIRA 從 master 開 `feature/{TICKET}` 分支 |
| `new-branch-cloud-agent` | Cloud／Background Agent 開 `cursor/<name>-<suffix>` 分支 |
| `weekly-branch-report` | 依作者與日期整理「已合併 uat / 進行中」分支週報 |

### 實作

| Skill | 說明 |
|-------|------|
| `feature` | 功能實作（評估複雜度、依測試策略、跨 Vue/Nuxt/Next） |
| `adjust` | 補充調整既有功能（更新 US → 測試策略 → 實作 → 驗收） |
| `fix` | 修正 ESLint / TypeScript / test / build 等有明確輸出的錯誤 |
| `refactor` | 重構（SOLID / Clean Code，可依任務測試策略） |
| `refactor-scan` | 判斷是否到重構時機；確認後才呼叫 `refactor` |

### 測試

| Skill | 說明 |
|-------|------|
| `unit-test` | 框架無關單元測試（Jest / Vitest） |
| `vue-integration-test` | Vue 2 元件整合測試（VTU + Jest + Vuex） |
| `react-integration-test` | React / Next 元件測試（RTL + user-event） |
| `e2e-test` | E2E（Playwright，BDD / AC 驅動） |

### 環境／預覽

| Skill | 說明 |
|-------|------|
| `static-html-host` | 臨時用 `http.server`＋（可選）localtunnel 預覽靜態 HTML（tmux 常駐；用完須關掉） |

### 除錯與審查

| Skill | 說明 |
|-------|------|
| `quick-debug` | 快速定位 bug / 異常行為 |
| `find-component-render-path` | 分析 UI 元素如何被渲染、如何觸發 |
| `independent-review` | 獨立 sub-agent 批判式審查（只報告、不改碼） |
| `pr-acceptance-checklist` | PR／MR 驗收清單（`for-review` 完整／`for-pr-body` 精簡） |
| `us-acceptance-check` | 檢查 US 驗收條件是否已在程式碼中實現 |

### 交付與審閱

| Skill | 說明 |
|-------|------|
| `change-report` | 以 git diff 產出分層變更報告（可選嵌入 `pr-acceptance-checklist` 的 `for-pr-body`） |
| `pr-delivery` | commit／push／建立 draft PR（消費 change-report；禁止直推 main） |

搭配 `.github/PULL_REQUEST_TEMPLATE.md`：PR 描述預設含行動端審閱指引。

**建議鏈結**：

1. 實作收尾（`feature`／`fix`／`adjust`／`refactor`）→ `/change-report`
2. Background Agent、或使用者要求交付、或 **epic／sprint 收尾**（見 `next-task` Step 8）→ `/pr-delivery`
3. 開 PR 後可選 → `pr-acceptance-checklist`（`for-review`）貼成 comment
4. 分支：本機 JIRA → `new-branch-feature`；Cloud Agent → `new-branch-cloud-agent`

### 收尾與知識沉澱

| Skill | 說明 |
|-------|------|
| `comment-trim` | 精簡功能開發期間累積的贅述註解 |
| `doc-trim` | 精簡 US / spec / playbook 敘述文字（保留結構） |
| `distill-playbook` | 把 epic/feature 驗收經驗蒸餾進 Playbook / Skill |

## Repo 結構

```
.claude/skills/
├── feature/SKILL.md
├── next-task/SKILL.md
├── unit-test/
│   ├── SKILL.md
│   └── reference-*.md
└── ...
```

每個 skill 是一個目錄，至少包含 `SKILL.md`（YAML frontmatter + 指示）。Skills CLI 會自動發現 `.claude/skills/`。

## 建議用法

1. 在目標專案安裝需要的 skills（或全部）。
2. 用自然語言觸發，例如「下一個任務」「幫我寫這個 util 的單元測試」「驗收 US-XXX」。
3. 需要最新版時在該專案執行 `npx skills update`。
