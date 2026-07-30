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

### 安裝群組（跨 skill 相對路徑）

Skills CLI（目前 `skills@1.5.21`）**只複製被選中的 skill 資料夾**，不會自動帶上 `../其他 skill/`。下列家族若單裝會斷掉相對路徑引用，請一次裝齊：

```bash
# refactor-scan 家族（引用 next-task / refactor / distill-playbook 的 reference）
npx skills add ms0223900/agent-skills \
  --skill refactor-scan --skill next-task --skill refactor --skill distill-playbook -y

# doc-trim 家族（引用 next-task 的追蹤目錄解析）
npx skills add ms0223900/agent-skills \
  --skill doc-trim --skill next-task -y
```

技術棧偵測（`reference.md` / `reference-stack.md`）已內嵌在各自 skill 資料夾內，單裝 `feature`／`fix`／`adjust` 等**不需要**額外指令。維護端來源在 `dev/shared/stack-detect.source.md`，改完後執行 `./scripts/sync-shared-refs.sh`。

### User-invoked vs model-invoked

標了 **（手動）** 的 skill 設了 `disable-model-invocation: true`：不會自動觸發，需你手動叫名（例如 `/wrap-up`、`/comment-trim`）。其餘可由 agent 依 description 自動觸發，或被其他 skill 呼叫。

## Skills 清單

### 流程編排

| Skill | 說明 |
|-------|------|
| `next-task` | 依 branch / JIRA 找出下一個未完成任務並分派對應 skill；**epic 或 sprint 收尾**時建議交付與 `/wrap-up` |
| `ticket-to-ai-spec` | 把原始 ticket 轉成 AI 可執行的開發規格 |
| `user-stories` | 將需求拆成含 AC、測試策略、依賴關係的 User Stories |
| `new-branch-feature` **（手動）** | 本機依 JIRA 從 master 開 `feature/{TICKET}` 分支 |
| `new-branch-cloud-agent` | Cloud／Background Agent 開 `cursor/<name>-<suffix>` 分支 |

### 決策釐清

| Skill | 說明 |
|-------|------|
| `grill-me` **（手動）** | 手動入口；呼叫後轉入 `grilling`（內容源自 [mattpocock/skills](https://github.com/mattpocock/skills)，已 vendored 進本 repo） |
| `grilling` | 對方案、決策或想法逐題壓力測試，達成共識前不執行（同上） |

`ticket-to-ai-spec`、`feature`、`refactor` 會在規格或架構仍有多個關鍵決策時暫停並建議使用 `/grilling`；不會在執行中偷偷自動完成訪談。執行 `npx skills add ms0223900/agent-skills --skill '*'` 時會一併安裝這兩支，無需另外裝 `mattpocock/skills`。

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
| `static-html-host` **（手動）** | 臨時用 `http.server`＋（可選）localtunnel 預覽靜態 HTML（tmux 常駐；用完須關掉） |

### 除錯與審查

| Skill | 說明 |
|-------|------|
| `quick-debug` | 快速定位 bug / 異常行為 |
| `find-component-render-path` | 分析 UI 元素如何被渲染、如何觸發 |
| `independent-review` | 獨立 sub-agent 批判式審查（只報告、不改碼） |
| `pr-acceptance-checklist` | PR／MR 驗收清單（`for-review` 完整／`for-pr-body` 精簡） |
| `us-acceptance-check` | 檢查 US 驗收條件是否已在程式碼中實現 |
| `merge-conflict-check` **（手動）** | dry-run 評估目前分支合進主幹會不會衝突 |

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
| `wrap-up` **（手動）** | Router：列出下方收尾類 skill 與何時用，本身不執行 |
| `comment-trim` **（手動）** | 精簡功能開發期間累積的贅述註解 |
| `doc-trim` **（手動）** | 精簡 US / spec / playbook 敘述文字（保留結構） |
| `distill-playbook` **（手動）** | 把 epic/feature 驗收經驗蒸餾進 Playbook / Skill |
| `weekly-branch-report` **（手動）** | 依作者與日期整理「已合併 uat / 進行中」分支週報 |

撰寫／編輯 skill 本身可參考 `writing-great-skills` **（手動）**（來自 mattpocock/skills，見 `skills-lock.json`）。

## Repo 結構

```
.claude/skills/
├── feature/
│   ├── SKILL.md
│   └── reference.md          # synced from dev/shared
├── wrap-up/SKILL.md
├── grill-me/SKILL.md
├── grilling/SKILL.md
├── next-task/
│   ├── SKILL.md
│   └── reference.md
├── unit-test/
│   ├── SKILL.md
│   └── reference-*.md
└── ...
dev/shared/
└── stack-detect.source.md    # 維護端單一真相來源（非 skill）
scripts/
└── sync-shared-refs.sh       # 把來源鋪進各 skill 的 reference*.md
```

每個 skill 是一個目錄，至少包含 `SKILL.md`（YAML frontmatter + 指示）。Skills CLI 會自動發現 `.claude/skills/`。`grill-me`／`grilling` 以 vendored copy 形式放在 `.claude/skills/`，勿在 repo 根目錄為它們建立 `skills-lock.json` 條目，否則 Skills CLI 會把它們從可安裝清單排除。`writing-great-skills` 則經 `skills-lock.json` 由上游安裝。

## 建議用法

1. 在目標專案安裝需要的 skills（或全部；跨 skill 家族見上方「安裝群組」）。
2. 用自然語言觸發 model-invoked skills，例如「下一個任務」「幫我寫這個 util 的單元測試」「驗收 US-XXX」。
3. 收尾類請手動呼叫 `/wrap-up` 再選子 skill。
4. 需要最新版時在該專案執行 `npx skills update`。
