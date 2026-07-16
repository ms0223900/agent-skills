---
name: change-report
description: 以 git diff 為輸入，產出適合行動端／手機審閱的分層變更報告（30 秒摘要、檔案異動清單、Mermaid 架構導讀、驗證結果、風險與待確認）。不修改程式碼、不建立 PR。使用時機：功能／修錯／重構完成後要寫 PR 描述、使用者說「幫我寫變更摘要」「視覺化這次 diff」「PR 導讀」、或作為 `/pr-delivery` 的前置步驟。
---

# 變更報告產出（Change Report）

## 目標

把一次功能／修錯／重構的 `git diff` 轉成**可快速掃讀**的 Markdown 報告，讓審閱者（尤其手機／平板）先理解「改了什麼、影響哪裡」，再決定是否深入看原始 Diff。

本 skill **只產出報告文字，不修改任何檔案、不 commit、不建立 PR**。要建立 PR 時交給 `/pr-delivery`。

輸出對齊三層審閱結構：

| 層級 | 內容 | 用途 |
|------|------|------|
| 30 秒摘要 | 目的、影響範圍、驗證結果 | 手機通知／PR 標題下第一眼 |
| 視覺化導讀 | 檔案異動清單、Mermaid 圖、決策與風險 | 決定要不要深入 |
| 原始證據 | 指向 PR Diff／commit range（本 skill 只寫指引，不貼大段 diff） | 細讀時用 |

---

## 何時使用 / 何時不用

**使用時機**：

- `/feature`／`/fix`／`/adjust`／`/refactor` 完成後，需要寫 PR 描述或變更說明。
- 使用者說「幫我寫變更摘要」「視覺化這次 diff」「產出 PR 導讀」。
- `/pr-delivery` 建立／更新 PR 前的必要前置步驟。

**何時不用**：

- 還在實作中、diff 尚未穩定 → 等收尾再跑。
- 只要機械式核對「有沒有做到 AC、有沒有動到不該動的」→ 用 `/pr-acceptance-checklist` 或 `/us-acceptance-check`。
- 要批判式挑錯 → 用 `/independent-review`。
- 要直接開 PR → 先跑本 skill，再呼叫 `/pr-delivery`。

---

## 執行流程

### Step 1：界定 diff 範圍

1. 偵測基準分支（依專案慣例優先：`main` → `master` → `develop`；或使用者指定）。
2. 掃描範圍預設為：`git merge-base <base> HEAD` 到 `HEAD`（已 commit）**加上**工作區未提交異動（`git diff` / `git status`）。
3. 使用者明確指定 commit range 或檔案清單 → 以指定為準。
4. 範圍無法判斷時，用一句話詢問，不要猜測。

收集素材（只讀）：

```bash
git status -sb
git diff --stat <base>...HEAD
git diff --name-status <base>...HEAD
git log --oneline <base>..HEAD
# 若有未提交異動，另附：
git diff --stat
git diff --name-status
```

可選補強：對應的 US／spec／任務檔「驗收說明」、剛跑過的測試指令與結果。

### Step 2：歸類檔案異動

將 `--name-status` 結果分成：

| 類型 | 典型路徑 |
|------|----------|
| Domain / Feature | `src/components/`、`src/views/`、`pages/`、`app/`、`src/api/`、`src/store/` |
| Tests | `tests/`、`__tests__/`、`*.test.*`、`*.spec.*`、`e2e/` |
| Docs / Specs | `docs/`、`*.md`（非 skill） |
| Tooling / Skills / Config | `.claude/`、`.cursor/`、lint／CI 設定、`package.json` |

標出：新增 (A)、修改 (M)、刪除 (D)、更名 (R)。若有明顯超出本次需求範圍的檔案，在「風險與待確認」標為 ❓。

### Step 3：推導摘要與影響範圍

從 diff + commit message +（若有）US／驗收說明，寫出：

- **變更目的**：一句話（做了什麼、為什麼）。
- **影響範圍**：使用者可見行為、API／資料流、設定／旗標、測試覆蓋——只寫實際有動到的。
- **重要決策**（若有）：為什麼選 A 不選 B；查證後決定不改某處。
- **不做什麼**：明確排除的範圍，避免審閱者以為漏做。

禁止：貼大段 raw diff、逐檔複述每一行變更、空泛形容（「優化了程式碼」）。

### Step 4：畫 Mermaid 導讀（有架構／資料流變化時才畫）

符合任一條件才產出圖，否則寫「本次無架構／資料流邊界變更，略過圖示」：

- 新增／拆分／合併模組或元件邊界
- 改變 API 呼叫鏈、store／狀態流向、路由守衛
- 搬移跨目錄職責

圖種類擇一（保持小、可讀）：

- `flowchart`：呼叫／資料流
- `graph`：模組依賴
- 避免超過約 12 個節點；節點用人類可讀名稱，不要堆檔名路徑

### Step 5：彙整驗證與風險

- **驗證結果**：已跑的指令（lint／單元／整合／E2E）與通過／未跑原因；Exploratory 未寫測試時照實說明。
- **風險／待確認**：行為邊界、相容性、需人工點擊的路徑、超出 scope 的檔案、無法從 code 驗證的 AC。
- 若剛跑過 `/us-acceptance-check`，可引用其 PASS／PARTIAL／FAIL 結論，不要重跑整套驗收除非使用者要求。

### Step 6：輸出固定格式

**只輸出下列 Markdown**（可直接貼進 PR body 或交給 `/pr-delivery`）。不要在前後加長篇說明。

```markdown
## 30 秒摘要

- **目的**：{一句話}
- **影響範圍**：{使用者可見／API／設定／測試，擇要}
- **驗證**：{通過的指令，或「未跑／Exploratory：原因」}

## 檔案異動清單

| 狀態 | 路徑 | 說明（一句） |
|------|------|--------------|
| M | `path/to/file` | … |
| A | `path/to/new` | … |

## 架構／資料流導讀

（有變更時放 mermaid flowchart／graph；否則寫「本次無架構／資料流邊界變更，略過圖示」）

## 重要決策

- {若無則寫「無」}

## 驗證結果

- {指令與結果條列}

## 風險與待確認

- {若無則寫「無」}

## 原始證據

- Diff 範圍：`{base}...HEAD`（含未提交異動時註明）
- 請以 GitHub PR Files／Unified Diff 為準；本報告不取代原始 diff。
```

---

## Checklist

- [ ] 已確認 diff 範圍（base…HEAD 與／或工作區），範圍不明時已詢問
- [ ] 檔案異動清單完整，且有一句人話說明（不是只貼路徑）
- [ ] 30 秒摘要可獨立閱讀，不依賴打開 IDE
- [ ] Mermaid 僅在有架構／資料流變化時出現，且節點數可控
- [ ] 未貼大段 raw diff；原始證據只指向範圍與 PR Diff
- [ ] 未修改任何檔案；需要開 PR 時引導呼叫 `/pr-delivery`

---

## 與其他 skill 的關係

| Skill | 關係 |
|-------|------|
| `/pr-delivery` | 消費本 skill 的輸出作為 PR body；負責 commit／push／開 PR |
| `/pr-acceptance-checklist` | Reviewer 核對「該做／不該做」；可選把其 checklist 附在 PR comment，不取代本報告 |
| `/us-acceptance-check` | 提供「驗證結果」素材 |
| `/independent-review` | 深度批判審查；本 skill 是導讀，不是挑錯 |
| `/weekly-branch-report` | 跨多工單週報摘要；本 skill 是單次變更的交付導讀 |

---

## Examples

**「這次 feature 做完了，幫我寫 PR 變更摘要」**

→ Step 1：`merge-base main HEAD` + 工作區 diff。Step 2：歸類 5 個 M、2 個 A。Step 3：目的寫成「購物車支援優惠券折抵」。Step 4：有 store → API 新鏈路 → 畫 flowchart。Step 5：附上 `npx vitest run …` 通過。Step 6：輸出固定 Markdown，提示可接 `/pr-delivery`。

**「只有改了兩行文案」**

→ 仍產出完整模板；Mermaid 寫略過；檔案清單兩列；風險寫「無」。不要為了小改動省略模板結構——行動端審閱靠固定標題掃讀。
