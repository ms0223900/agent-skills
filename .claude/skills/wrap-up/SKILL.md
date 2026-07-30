---
name: wrap-up
description: Router for finish/report hand-fired skills.
disable-model-invocation: true
---

# 收尾技能路由（Wrap-Up）

功能/epic 收尾時，依需求手動挑選以下之一（或多個），本身不做任何事：

- 註解太長太贅述 → `/comment-trim`
- US/spec/playbook 文件太囉唆 → `/doc-trim`
- 要把經驗整併進 Playbook/Skill/CLAUDE.md → `/distill-playbook`
- 要整理本週分支週報 → `/weekly-branch-report`
- 想知道合進主幹會不會衝突 → `/merge-conflict-check`
- 要臨時對外預覽靜態頁面 → `/static-html-host`

Comments taking too long, too verbose → `/comment-trim`.
Docs (US/spec/playbook) too wordy → `/doc-trim`.
Consolidate learnings into Playbook/Skill/CLAUDE.md → `/distill-playbook`.
Weekly branch report → `/weekly-branch-report`.
Check merge conflicts with base branch → `/merge-conflict-check`.
Temporary public preview of static HTML → `/static-html-host`.

不含 `/new-branch-feature`（那是開工，不是收尾）。
`/change-report`／`/pr-delivery` 仍為 model-invoked 交付步驟，不在本路由。
