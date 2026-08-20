---
name: security-audit
description: 公開上線或公開宣傳前的全庫漏洞盤點；只產報告、不改碼。
disable-model-invocation: true
---

# 公開上線前資安盤點（Security Audit）

## 目標

在服務**即將公開上線、對外宣傳、或把預覽網址給外人**之前，對目前 codebase 做一次全庫漏洞盤點：只找**可利用、有真實衝擊**的問題，產出報告後停下。

方法來自 [Cloudflare security-audit](https://github.com/cloudflare/security-audit-skill) 的六階段管線（偵察 → 獵洞 → 對抗式驗證 → 報告 → 結構化輸出 → 獨立複驗）。來源與授權見 [UPSTREAM.md](UPSTREAM.md)。

本 skill **只審計、只報告**：

- **不**自動修碼、不呼叫 `/fix`／`/feature`／`/adjust`
- **不**把 `REPORT.md`／`findings.json` commit 進 git（報告可能含攻擊路徑）
- **不**對未授權的第三方系統做攻擊或掃描

You are a security auditor. Report **exploitable vulnerabilities with real impact** — not theoretical checklist gaps.

---

## 何時使用 / 何時不用

**使用時機**（手動呼叫 `/security-audit`；本 skill **不會**自動觸發）：

- 服務要**公開上線**、把環境從內測轉成外人可達
- 要**公開宣傳**（發文、Demo、給客戶／媒體的預覽網址）
- 使用者明確說「上線前盤點」「公開前資安 review」「full security audit」

這是**偶爾**才跑的關卡，不是每個 PR／每個 epic 的收尾步驟。單次 run 覆蓋不完整；若時間允許，可隔一段時間再跑一次（見下方「Coverage and prior runs」）。

**何時不用（改用其他 skill）**：

| 情境 | 改用 |
|------|------|
| 只要看這次 diff 的安全問題 | 內建的 `security-review` |
| 批判式挑邏輯／假設／跨檔不一致（非資安） | `/independent-review` |
| 核對 US／PR 有沒有做到規格內的事 | `/us-acceptance-check`、`/pr-acceptance-checklist` |
| 功能開發中、每個小任務驗證 | `/feature`／`/fix` 自己的驗證步驟；不要為此開六階段稽核 |
| 只要變更導讀或開 PR | `/change-report`、`/pr-delivery` |
| 確認 finding 之後要動手修產品碼 | 先讓使用者看報告；確認要修再 `/fix`／`/adjust` |

`/wrap-up` 會列出本 skill，但**不會代為執行**。

---

## 授權範圍

1. **Target** 預設為目前工作目錄；使用者指定路徑則用指定路徑。只審計這個團隊有權修改的 codebase。
2. 動態驗證（payload、最小 harness）只針對 target 的本地／開發實例。缺部署環境就標 `requires deployment testing`，不要對生產或外人的站下手。
3. 產物寫到 output directory，**不要**寫進專案 source tree，也**不要** `git add` 它們。

---

## Platform terminology

This skill is agent-neutral. In the methodology:

- **Task tool** means the coding agent's delegation or sub-agent mechanism. On Cursor: `Task`.
- **`research` agent** means a delegated agent optimized for focused codebase exploration and factual verification. On Cursor: `subagent_type: explore`.
- **`general` agent** means a delegated agent that can investigate broadly and spawn focused research agents. On Cursor: `subagent_type: generalPurpose`.
- **`subagent_type`** means the equivalent delegated-agent role supported by the current platform.

Use the platform's equivalent capabilities while preserving the specified roles, parallelism, prompts, and independence boundaries.

---

## Setup

Before starting, establish two paths:

- **Target**: the codebase to audit (from the user's request or the current working directory)
- **Output directory**: where all audit artifacts go. Ask the user if not specified, or default to `~/security-audit-skill/<repo-name>/run-<N>` where `<N>` is the next unused integer (check what exists with `ls`). Create it if it doesn't exist. This keeps multiple runs separate **and** keeps reports out of git.

All files written during the audit go in the output directory:

- `architecture.md` — Phase 1 output, fed into Phase 2 agent prompts
- `REPORT.md` — human-readable report (Phase 4)
- `FINDINGS-DETAIL.md` — detailed data flows for MEDIUM+ findings (Phase 4)
- `findings.json` — machine-readable structured output (Phase 5)

Subagents (Phases 1, 2, 3, 6) do NOT write files — they return results to you via the Task tool. You are responsible for writing all files to the output directory.

### Coverage and prior runs

Each audit run explores different code paths. No single run finds everything. Testing shows the best single run finds roughly half the total vulnerabilities across multiple runs.

**If prior runs exist** for the same repo (check `~/security-audit-skill/<repo-name>/`), read their `findings.json` files before starting Phase 2. Use them to:

1. **Skip known findings** — don't waste agents re-discovering the same status bypass. Mention prior findings in the report but focus hunting effort on new ground.
2. **Target gaps** — if prior runs focused heavily on injection and auth, weight this run toward business logic, creative attacks, and the wildcard agent.
3. **Resolve disagreements** — if prior runs gave conflicting verdicts on the same finding, validate it definitively.

Include a brief summary of prior runs in the architecture summary so Phase 2 agents know what's already been found.

**If no prior runs exist**, note in the report that coverage improves with additional runs.

---

## Core Principles

### Only report what you can exploit

Every finding must have a concrete attack scenario: who is the attacker, what do they do, and what do they get? "An attacker could theoretically..." is not a finding. "Send this request, get this result" is.

### Confirm dynamically when you can

This is a source-first audit, but a claim you can execute beats one you can only argue. Where the target is locally buildable, build and run it. Where confirmation needs infrastructure you don't have, mark it "requires deployment testing" and do not report it as confirmed.

### Determine the baseline dynamically

In Phase 1, identify what this application is and what comparable applications exist. Use those comparables to calibrate — not to dismiss findings. Do NOT hardcode a specific comparable.

### Defense-in-depth gaps are not vulnerabilities

If Layer A prevents the attack, the absence of Layer B is a hardening note, not a finding.

### Severity requires impact

Severity is likelihood × impact:

- **CRITICAL**: Unauthenticated RCE, full database dump, admin account takeover without credentials
- **HIGH**: Authenticated RCE, SQLi with exfiltration, stored XSS for all users, auth bypass; defeating an explicit RBAC boundary with real consequences
- **MEDIUM**: Conditional XSS, CSRF with meaningful state change, secret disclosure; business-logic bypass with limited blast radius
- **LOW**: Non-secret information disclosure, DoS requiring sustained effort
- **INFORMATIONAL**: Confirmed but minimal-impact observation. Pure defense-in-depth gaps belong in hardening notes.

If you cannot describe the concrete damage an attacker achieves, the severity is probably lower than you think.

These principles are enforced by the **validation rules in [HUNTING.md](HUNTING.md)**. Domain companions add checks on top of that bar; they do not replace it.

---

## Workflow overview

Follow all six phases in order. Load each file when that phase starts; do not skip a phase to look finished.

1. **Recon** — Phase 1 in [RECONNAISSANCE.md](RECONNAISSANCE.md): map architecture, trust boundaries, and input surfaces. **Done when** `architecture.md` exists in the output directory.
2. **Hunt** — [HUNTING.md](HUNTING.md) for orchestration and validation rules; pick scopes from [ATTACK-CLASSES.md](ATTACK-CLASSES.md), which routes native / AI-LLM / HTTP-auth / client-side targets to [MEMORY-SAFETY-AND-BINARY.md](MEMORY-SAFETY-AND-BINARY.md), [AI-AND-LLM.md](AI-AND-LLM.md), [WEB-PROTOCOL-AND-AUTH.md](WEB-PROTOCOL-AND-AUTH.md), [CLIENT-SIDE.md](CLIENT-SIDE.md). **Done when** every launched hunter has returned and candidates are collected.
3. **Validate** — Phase 3 in [VALIDATION-AND-REPORTING.md](VALIDATION-AND-REPORTING.md): consolidate duplicates and independently try to disprove every finding. **Done when** each candidate is confirmed, rejected, or marked needs-deployment-testing.
4. **Report** — Phase 4 in [VALIDATION-AND-REPORTING.md](VALIDATION-AND-REPORTING.md): write `REPORT.md` and `FINDINGS-DETAIL.md`. **Done when** both files are in the output directory.
5. **Structured output** — Phase 5 in [VALIDATION-AND-REPORTING.md](VALIDATION-AND-REPORTING.md), `report-schema.json`, and `validate-findings.cjs`: write and validate `findings.json`. **Done when** the validator exits 0.
6. **Independent verification** — Phase 6 in [VALIDATION-AND-REPORTING.md](VALIDATION-AND-REPORTING.md): verify every factual claim and reconcile outputs. **Done when** claims match source, and the user-facing summary lists output paths plus finding counts by severity.

After Phase 6: **stop**. Summarize for the user (output path, counts, top confirmed findings). Do not patch. Do not start `/fix` unless the user explicitly asks after reading the report.

---

## Anti-Patterns to Avoid

1. Listing everything that deviates from OWASP as a finding. OWASP is a checklist, not a bug list.
2. Rating defense-in-depth gaps as HIGH/CRITICAL.
3. Ignoring the deployment model (CDN rate limiting can be a valid layer).
4. Treating designed trust-model behavior as a bug (admin-does-admin-things is not a finding).
5. Padding the report with LOW findings to look thorough.
6. "Potential" findings without proof. If you need "potentially" or "theoretically", research more or drop it.
7. Ignoring what the codebase does well. If auth is solid, say so.
8. Constructing exploits from unverified parser/runtime assumptions. Cite the spec or test it.
9. Skipping business logic and chained attacks — scanners already cover the obvious classes.
10. Giving up too easily ("parameterized queries so no SQLi"). Check every `sql.raw()`, dynamic identifiers, FTS, and bypass paths.

---

## Checklist

- [ ] 使用者手動呼叫本 skill（或明確要求上線前／公開前盤點），不是每個 PR 自動跑
- [ ] Target 是目前 repo 或使用者指定、且有權修改的 codebase
- [ ] Output directory 在 repo 外（或使用者指定的非 source 路徑）；未把報告加入 git
- [ ] 六階段都做完，沒有為了收尾跳過驗證或獨立複驗
- [ ] 只報告可利用的 finding；hardening notes 與 INFORMATIONAL 分開
- [ ] 沒有自動改產品碼；回報後停下等使用者決定

---

## 與其他 skill 的關係

| Skill | 關係 |
|-------|------|
| 內建 `security-review` | 針對**這次變更**的安全審查；本 skill 是**全庫**、上線前盤點 |
| `/independent-review` | 批判邏輯與假設；不是漏洞獵洞 |
| `/wrap-up` | 列出本 skill 與何時用；**不代呼** |
| `/pr-delivery`／`/change-report` | 交付與 diff 導讀；**不**自動掛本 skill |
| `/fix`／`/adjust` | 使用者看完報告、確認要修之後才接 |

---

## Examples

**「下週要公開宣傳，上線前幫我做一次資安盤點」**

→ 確認 target＝目前 repo。Output 預設 `~/security-audit-skill/<repo>/run-N`。跑完六階段，回報 `REPORT.md` 路徑與各嚴重度數量。不修碼。

**「這個 PR 的 auth 改動安不安全？」**

→ 不用本 skill。改走內建 `/security-review`（看 diff，不是全庫六階段）。

**「epic 做完了，順便稽核一下」**

→ 若只是功能收尾、沒有要公開上線或對外宣傳 → 告訴使用者本 skill 是上線前關卡，問要不要現在跑；不要自己開跑。
