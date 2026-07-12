# Refactor Scan Reference

本文件補充 SKILL.md 未涵蓋的評分細節、水位線格式範本，以及與 `refactor`/`next-task` 既有規則的重用對照表。設計原則：**不重新發明詞彙或演算法**——能引用既有 skill 的地方一律引用，本檔案只補充「怎麼把既有規則組合起來判斷重構時機」這個新問題。

---

## 一、三維度評分完整規則

### 1.1 範圍／churn 評分

- 以 SKILL.md Step 1 決定的掃描範圍（一組任務）為輸入，逐一列出每個任務觸及的檔案清單（來源：Step 2 收集的「驗收說明」檔案引用 + git diff/log 的實際異動檔案）。
- 對每個檔案，統計「有幾個不同任務觸及它」。
- **churn hotspot** 判定：同一檔案被 ≥2 個不同任務觸及。任務數愈多，churn 程度愈高，但門檻判斷（見 §一.四）不分級距，只看「命中 / 未命中」。
- 若同一任務內同一檔案被多次修改（例如同一 commit 內），只算一次「觸及」，不重複計數。
- 目錄層級的 churn（例如同一個子模組底下有多個不同檔案，各自只被觸及一次，但整個目錄被持續加東西）也值得留意：若逐檔統計沒有命中 churn hotspot，但同一目錄在掃描範圍內被 ≥3 個任務新增/修改過檔案，視為「目錄層級 churn」，比照檔案層級 churn hotspot 處理（進入依賴鏈與反模式檢查）。

### 1.2 依賴鏈評分

- 直接引用 [next-task/reference.md](../next-task/reference.md) §四的依賴圖判讀規則解析追蹤目錄 README 的「依賴鏈摘要」。
- 對每個 churn hotspot（或目錄層級 churn 命中的模組），找出負責產出/維護它的任務節點，檢查該節點在依賴圖上是否為**多對一匯聚點**（多個下游任務的箭頭匯聚到它）或**一對多的上游節點**（它是多個下游任務的前置）。
- 匯聚點／高扇出上游節點命中 → 依賴鏈風險升級：代表愈來愈多功能疊加或依賴在同一段邏輯上，是典型的「該抽象了」訊號。
- 追蹤目錄沒有「依賴鏈摘要」（無 Checklist 型或純 git 模式）→ 這個維度視為「無法判斷」，不計入命中也不計入未命中，門檻判斷只看範圍/churn 與反模式兩項。

### 1.3 反模式評分

- 依 Step 0 判定的技術棧，對 churn hotspot／本次改動觸及的檔案套用 [refactor/reference.md](../refactor/reference.md) 的反模式表：
  - §1.4（Feature 反模式：條件與列表同元素、重複初始化、模板複雜表達式、直接改 props）
  - §1.1 組件拆分原則（單一元件檔超過 500 行等體積訊號）
  - §四 Quick Checklist（UI/狀態/Style/架構/國際化）
- 同時檢查 Step 2 收集到的「後續建議」（`/us-acceptance-check` 產出）是否已經提過類似疑慮——若有，直接列為佐證，不需要重新讀程式碼確認一次；若沒有，才需要實際打開 churn hotspot 檔案比對反模式表。
- 反模式命中以「命中項目數 ≥1」即算命中，不分權重；命中項目本身（例如「單一元件檔超過 500 行」）會直接作為 Step 5 摘要給使用者看的具體證據。

### 1.4 門檻判斷表（含邊界情況）

| 風險等級 | 條件 | 備註 |
|---|---|---|
| 高風險 | churn hotspot（含目錄層級）命中，且（依賴鏈匯聚/高扇出命中 或 反模式命中 ≥1） | 兩個訊號都命中時，摘要裡兩個證據都要列出 |
| 中風險 | 只命中 churn hotspot，或只命中反模式，尚未同時成立 | 依賴鏈維度「無法判斷」時，只要 churn + 反模式同時命中，仍算高風險，不因缺少依賴鏈資訊而降級 |
| 低風險 | 以上皆未命中 | 掃描範圍內沒有 churn hotspot 是最常見的低風險情況 |

型別/規模對照（高風險時使用，完全沿用 `refactor/SKILL.md` Step 1 的既有定義，不重新定義）：

| 類型 | 判斷依據 |
|---|---|
| Feature | churn hotspot 是 UI 元件檔、composable/hook/mixin，或反模式命中屬於 §1.4 Feature 反模式表 |
| Style | churn hotspot 是 `*.scss`/`*.css`/元件內 `<style>` |
| Architecture | churn hotspot 是狀態模組、API 層，或依賴鏈匯聚點橫跨多個子模組 |

| 規模 | 判斷依據 |
|---|---|
| Small | churn hotspot 僅 1 個檔案，且非依賴鏈匯聚點 |
| Medium | churn hotspot 涉及一整個子模組，或是依賴鏈上的匯聚點 |
| Large | churn hotspot 橫跨多個子系統、跨 PC/Mobile，或依賴鏈圖上有多層匯聚 |

---

## 二、水位線章節格式範本

### 2.1 README 驅動型

在追蹤目錄 README（例如 `docs/user-stories/<EPIC>/README.md`）新增一個獨立章節，緊接在「全域驗收 Checklist」之後：

```markdown
## 重構掃描記錄

- 已掃描至：TASK-004（2026-07-10）
- 已知待觀察熱點：
  - `src/store/bet.js`（連續 3 個任務修改，依賴鏈匯聚點；2026-07-10 判定高風險，使用者選擇暫緩，第 1 次）
```

欄位說明：

- **已掃描至**：本次掃描範圍內順序最後、最新完成的任務編號，加上掃描日期。下次掃描以此為起點（掃描範圍＝此任務之後、到下次呼叫時最新完成任務為止的所有已完成任務）。
- **已知待觀察熱點**：目前處於「已判定高風險但使用者選擇暫緩」狀態的項目清單，含檔案路徑、命中原因、上次判定日期、暫緩次數。項目一旦被使用者同意執行 `/refactor` 並完成，從清單移除；暫緩次數持續累加，供 SKILL.md Step 5 判斷是否需要加重提醒語氣。

若 README 完全沒有這個章節（第一次掃描），直接在「全域驗收 Checklist」之後新增，不影響其他既有章節的順序。

### 2.2 無 Checklist 型 / 純 git 模式（stateless）

不維護持久化水位線，每次呼叫都是獨立判斷。固定回看視窗大小 N：

- 預設 N = 3（目前任務 + 前 3 個已完成任務）。
- 若掃描範圍內任務數 < N（例如 epic 剛起步），一律取「目前為止全部已完成任務」，不強行湊滿 N。
- N 值可依專案任務顆粒度調整：若單一任務的變更範圍普遍很小（例如純測試任務拆分得很細），可考慮加大 N（如 5）以涵蓋足夠的比對窗口；若任務顆粒度本身就很粗，維持預設 3 即可。此調整由執行本 skill 時依實際觀察到的任務顆粒度自行判斷，不需要使用者事先設定。

---

## 三、與既有規則的重用對照表

| 主題 | 本 skill 怎麼用 | 權威來源（不重複維護，改動時只改來源） |
|---|---|---|
| 追蹤目錄解析演算法（4 層候選、glob 陷阱） | SKILL.md Step 1 直接引用 | [next-task/reference.md](../next-task/reference.md) §一 |
| 文件形態判讀（README 驅動型 / 無 Checklist 型） | SKILL.md Step 1 直接引用 | next-task/reference.md §二 |
| 驗收說明 heading 偵測（`^#{2,4}\s*驗收說明`） | SKILL.md Step 2 讀取任務檔案時使用 | next-task/reference.md §五 |
| 依賴鏈 ASCII 圖判讀規則 | SKILL.md Step 3 / 本檔案 §一.二 直接引用 | next-task/reference.md §四 |
| 反模式表（Feature/Style/Architecture、組件拆分原則） | SKILL.md Step 3 / 本檔案 §一.三 直接引用 | [refactor/reference.md](../refactor/reference.md) 全篇 |
| Type（Feature/Style/Architecture）× Size（Small/Medium/Large）判斷 | SKILL.md Step 4 / 本檔案 §一.四 沿用同一套詞彙 | [refactor/SKILL.md](../refactor/SKILL.md) Step 1 |
| 「附上任務全文作為 context」呼叫慣例 | SKILL.md Step 5 呼叫 `/refactor` 時沿用同樣的交接方式 | next-task/SKILL.md Step 4 分派表 |
| watermark／避免重複勞動的概念 | 本檔案 §二整體設計參考自 distill-playbook 的「取材自 TASK-xxx ~ TASK-yyy」，但寫入位置與格式是本 skill 專屬（追蹤目錄 README 的「重構掃描記錄」章節，不是 Playbook） | [distill-playbook/SKILL.md](../distill-playbook/SKILL.md) Step 1/6 |

若上述任一來源檔案的規則有調整（例如依賴圖判讀規則新增了一種圖形樣式），本 skill 不需要跟著改，執行時直接讀取當下最新版本的來源檔案即可。
