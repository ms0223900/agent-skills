---
name: test-audit
description: 稽核既有測試，找出低價值、綁實作、重複的測試與只為測試存在的 production 接縫，附證據後分批清理。
disable-model-invocation: true
---

# 測試稽核（Test Audit）

稽核**既有**測試：找出垃圾測試、綁實作的測試、跨層重複的測試，以及只為測試而存在的 production 接縫。目標是**提高信心**，不是刪除數量——拿不準的候選列入「待查」，不動。

Step 0–3 **不改工作樹**，產出證據報告；使用者確認後，Step 4–6 才一次清理一批。

## 範圍

使用者呼叫時指定其一；沒指定就先問：

- **路徑／glob**：一個目錄、模組或一組測試檔（例如 `src/modules/bet/`）。
- **diff**：某分支相對 base 的改動（`git diff <base>...HEAD`），稽核其中新增／修改的測試。
- **整個專案**：先列出模組清單與各自測試檔數，請使用者選第一批，一次只稽核一個模組。

## Step 0：規範、指令與 baseline

1. 讀 [reference-test-gate.md](reference-test-gate.md)（把關四題、owner 定義、垃圾測試清單、保留標準），之後每個判斷都以它為準。
2. 讀範圍內（含上層目錄）的 `AGENTS.md`／`CLAUDE.md`。
3. 讀範圍所屬 package 的 `package.json` scripts（monorepo 讀該 package 的），以及 `jest.config.*`／`vitest.config.*`／`playwright.config.*` 與 CI 設定（`.github/workflows/`、`.gitlab-ci.yml` 等）。
4. `git rev-parse --is-shallow-repository` 為 `true` 時先 `git fetch --unshallow`；失敗就記下「歷史不可得」。
5. 跑一次 baseline：範圍內測試、lint、typecheck、build（有指令的才跑）。本 skill 裡跑測試一律不寫入 snapshot、不進 watch：Jest 用 `npx jest --ci`，Vitest 用 `CI=true npx vitest run`。

**完成條件**：以下都已記下——單檔測試、lint、typecheck、build 的指令（沒有的寫「無」）；只在特定 jest project 或 CI job 裡跑的測試；歷史是否可得；baseline 原本就紅的測試與原本就有的錯誤。

## Step 1：探索

- 列出範圍內每一支測試檔，逐支對照垃圾測試清單找候選。命中清單只代表「值得查」，處置在 Step 2 依證據決定。
- Step 0 baseline 原本就紅的測試，一律列為候選。
- 範圍大於一個模組、且可用 sub-agent 時，分道平行探索，每道只回報候選與證據：
  - 邏輯層：utils、store、composables、hooks 的單元測試
  - 元件層：Vue／React 元件整合測試
  - E2E：Playwright／Cypress 情境
  - 跨層掃描：同一條 AC 或同一個函式在多層重複被測；只剩測試在呼叫的 export
- 命中清單但證據不足的候選照樣列出，Step 2 判待查。

**完成條件**：範圍內每支測試檔都已掃過，且每個候選都標出命中的垃圾測試條目（或「綁實作」「跨層重複」「測試專用接縫」「baseline 紅燈」）。

## Step 2：逐一蒐證

判斷任一候選前，完整讀過：該測試、它覆蓋的 production owner 與進入點、呼叫端與被呼叫端、同類的兄弟實作、重疊的測試、它在 CI 的哪個 job 跑，以及 `git log -p` 找出這支測試或接縫當初為何加入。測試宣稱依賴第三方行為時，直接看該套件的型別或原始碼。

為每個候選判定處置：

- **刪除**：證據齊全，且 owner 邊界有另一支測試守住同一件事，或本來就抓不到錯。
- **改寫**：守護的契約是真的，但斷言綁在實作上 → 移到 owner 邊界重寫。
- **合併**：近似重複 → 併進一個 `it.each`／table-driven case 或共用 fixture。
- **保留（誤報）**：符合保留標準；只需寫出它獨立守護的契約。
- **疑似產品 bug**：baseline 原本就紅 → 重現並回報，留給使用者決定是否另開修正。
- **待查**：證據不足，寫明缺什麼。

刪除、改寫、合併的候選填齊下表。某欄確實不適用時寫「不適用：<原因>」；**空白就改判待查**：

| 欄位 | 內容 |
|---|---|
| 測試 | 檔案路徑 + `describe`／`it` 名稱 |
| 實際能抓到的錯 | 這支測試真正會變紅的改動；抓不到任何可信回歸也要寫明 |
| owner 證明 | owner 邊界哪支測試已守住同一件事（寫出路徑與測試名）；或為什麼不需要。「因為受測程式碼是死碼」只在該程式碼經呼叫端搜尋判「可刪」時成立 |
| 歷史 | 這支測試或接縫是為了什麼加入的；「歷史不可得」時，「owner 證明」必須是具體的測試 |
| 連帶可刪 | 刪掉後能一併移除的 production 符號，每一項都附 [reference-caller-search.md](reference-caller-search.md) 的判定與實際跑過的搜尋指令；沒有就寫「不適用：只刪測試」 |
| 風險與驗證指令 | 刪錯的後果，以及能證明沒刪錯的測試指令 |

**列任何 production 符號進「連帶可刪」之前，先逐節完成 [reference-caller-search.md](reference-caller-search.md)。** 判「待查」的符號不列入，而以「它是死碼」為理由的那支測試也改判待查。

**完成條件**：每個候選都有處置；刪除、改寫、合併的候選證據表填齊；保留的候選寫出守護的契約；「連帶可刪」的每一項都附呼叫端搜尋的逐節紀錄。

## Step 3：報告並等待確認

用下列結構回報，然後**停下**，等使用者選定要清理的批次：

```markdown
## 測試稽核報告：<範圍>

### 摘要
- 掃描 N 支測試檔；候選 M 個（刪除 a／改寫 b／合併 c／保留 d／疑似 bug e／待查 f）
- baseline：<原本就紅的測試與錯誤，或「全綠」>

### 建議批次
1. <批次名：一個 owner 邊界／模組> — 候選 #1, #3, #4；預估測試 -X 行
   - production 刪除（每一項都要逐項確認，選定批次不等於確認）：
     - [ ] <符號> @ <檔案>：呼叫端搜尋「可刪」，指令 <…>

### 候選明細
#### #1 <檔案> › <測試名>
- 命中：<垃圾測試條目>
- 處置：刪除／改寫／合併／保留／疑似 bug／待查
- <證據表各欄；保留只寫守護的契約>

### 待查
- <候選或 production 符號>：缺 <欄位>，或呼叫端搜尋第 <n> 節無法排除（<命中位置>）
```

使用者只要報告時，到此結束。

## Step 4：清理一批

一次只做**一個**使用者確認的批次（同一個 owner 邊界或模組）：

- 依處置刪除、改寫或合併測試。
- production 符號只刪使用者**逐項勾選確認**的項目，不留相容別名；依呼叫端搜尋第 6 節一併清掉測試端引用。
- 改寫與合併後的測試依把關四題寫，並依把關第 2 題做 mutation test；合併時，被併入的每個原測試所守的受測邏輯都要破壞過。

**完成條件**：批次內每個候選都已照處置落地，或已註明為何改成保留；每支改寫與合併的測試都做過 mutation test。

## Step 5：驗證

1. 跑受影響的 owner 與兄弟測試、呼叫端搜尋第 6 節列出的測試檔，以及 Step 0 記下的 lint、typecheck。
2. 移除的是原始碼 grep 或設定比對類測試時，改跑真正擁有該契約的指令（`build`、產生器腳本、dry-run）。
3. 刪了 production 符號時跑 build。build 抓不到全域註冊、字串 dispatch 這類執行期才解析的引用，這部分以呼叫端搜尋為準。
4. 範圍外的測試失敗、而 Step 0 沒有它的 baseline 時：記下 `git stash list | wc -l`，`git stash push -u -m test-audit-<時間戳> -- <本批改動的檔案>` 只收起這批改動，確認筆數多一筆後跑同一支測試，再 `git stash pop --index`（pop 失敗時不要 drop，先移開衝突檔案再重試）。只有同一條斷言、同樣的失敗訊息才算原本就紅；找不到模組或設定錯誤不算。
5. 跑 `git diff HEAD --check`。
6. 對這批改動執行 `/independent-review`，交給它被刪或合併的斷言清單與候選 owner 測試的路徑（不附結論），請它逐條判斷是否仍有測試守住，並找出改寫後永遠不會紅的斷言。處理它回報的問題。

**完成條件**：和 baseline 相比沒有新增的紅燈或錯誤；`/independent-review` 回報已處理。有新增失敗就回到 Step 4 修正，失敗的測試保留不刪。

## Step 6：回報與下一批

先 `git add -N` 新增的檔案，用 `git diff HEAD --numstat` 統計行數，再 `git reset --quiet -- <新增的檔案>` 撤回 intent-to-add；production／工具與測試／測試輔助分開列。回報：

- 移除了哪幾類低價值測試、根因是什麼
- production owner 的簡化（刪掉的 export、死碼）
- 保留的誤報與它們的價值
- 實際跑過的驗證指令與結果
- production 與測試的行數增減
- 下一批建議

交付照常走 `/change-report`；使用者要求開 PR 時再用 `/pr-delivery`。下一批以目前的工作樹重新走 Step 1–3，產出新報告並等待確認。
