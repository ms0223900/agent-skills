---
name: e2e-test
description: 撰寫端到端（E2E）瀏覽器測試，以 BDD Given/When/Then 為理論基礎——直接把 User Story 的驗收條件（AC）轉譯成情境，而不是另外發明一套測試規格。目前以 Playwright 為主要落地工具（可延伸至其他瀏覽器測試工具）。涵蓋 Page Object / fixture 慣例、role-based locator 策略、避免 manual sleep 與 flaky test。使用時機：使用者要幫某個 user flow / user story 寫「E2E 測試」、「端到端測試」、「Playwright 測試」，或要求把驗收條件轉成自動化情境。純函式/邏輯測試用 `unit-test`；單一元件渲染測試用 `vue-integration-test`/`react-integration-test`。
---

# E2E 測試撰寫指南（E2E Test Workflow）

E2E 測試驗證「使用者真正會經歷的完整流程」，是測試金字塔最上層、數量該最少但最貼近真實使用情境的一層。本 skill 的核心立場：**User Story 的 Given/When/Then 驗收條件，就是 E2E 測試的規格來源**——不要另外自己編一套行為描述，也不要把 QA 手動驗收步驟跟自動化測試寫成兩套互相脫節的東西。

---

## 何時使用 / 何時不用

**用**：需要驗證跨頁面、真實瀏覽器互動的使用者流程（例如「登入 → 加入購物車 → 結帳」），且該流程有明確的 US 驗收條件可依循。

**不用（改用其他 skill）**：

| 情境 | 改用 |
|------|------|
| 純函式/utils/composable/hook 邏輯 | `unit-test` |
| 單一 Vue 元件渲染/DOM 斷言 | `vue-integration-test` |
| 單一 React/Next 元件渲染/DOM 斷言 | `react-integration-test` |
| US 本身還沒有明確的驗收條件（Given/When/Then 或等效描述） | 先請使用者/PM 補齊 AC，或用 `user-stories`/`ticket-to-ai-spec` 補上，不要自己編造行為 |

---

## 技術棧與 E2E 工具偵測（Step 0）

1. 讀 `package.json` devDependencies：`@playwright/test`、`cypress`，或其他 E2E 工具。
2. 讀對應設定檔：`playwright.config.*`（`projects`、`use.baseURL`、`testDir`）或 `cypress.config.*`。
3. 讀既有 E2E 測試目錄（常見 `tests/e2e/`、`e2e/`、`cypress/e2e/`），確認：
   - 既有 Page Object / fixture 結構（例如 `tests/e2e/support/pages/*.page.ts`）
   - 既有的登入/資料準備方式（auth fixture、seed API）
   - 命名慣例（依 JIRA 單號、依功能）
4. **優先沿用既有慣例**；若專案尚無 E2E 建置，本文件以 Playwright 為預設落地工具，具體實務見 [reference.md](reference.md) 的「二、Playwright 實務」。

---

## 執行流程

### Step 1：從驗收條件取得 Given/When/Then

- 讀取目標 US/任務檔案的**驗收條件**。若已是 Given/When/Then 格式，直接使用；若是條列式 AC，逐條轉譯成 Given（前置條件）/When（使用者動作或系統事件）/Then（可觀察結果）。
- 若 AC 含糊、隱含假設（例如「跟之前一樣」）或邏輯衝突，**不要自己腦補行為**——比照 `ticket-to-ai-spec` 的處理原則，標記為「需要澄清」並詢問使用者，或建議先用 `/user-stories`/`/ticket-to-ai-spec` 補齊。
- 原則上每一條 AC 對應**一個** Given/When/Then 三元組。若一個使用者動作產生多個彼此不可分割的可觀察結果（例如「送出成功訊息並清空購物車」），可在同一個 Then 情境中以多個 assertion 驗證；若包含可獨立驗證的使用者行為或結果，才應拆成不同 AC 與情境，不要把多段 happy path 硬塞進一個測試。

### Step 2：情境顆粒度 — 一個 Scenario 只驗證一個行為

- 一個 Given/When/Then 三元組對應**一個**測試（`test(...)`/`it(...)`），不要把整條 happy path 串成一個「大情境」測到底。
- 判斷準則：能否用一句話講出這個情境要驗證的**單一**結果？講不出來就代表測太多事，拆開。
- 詳細理論與常見錯誤（步驟寫得太貼近實作、混雜多個 AC）見 [reference.md](reference.md) 的「一、BDD Given/When/Then」。

### Step 3：撰寫方式 — Given → Arrange、When → Act、Then → Assert

- **Given（Arrange）**：只建立這個行為真正依賴的前置條件（登入狀態、資料狀態、導航位置），不要塞入不影響結果的多餘設定。
- **When（Act）**：剛好一個使用者觸發的動作或系統事件。
- **Then（Assert）**：只斷言使用者看得到的結果（可見文字、頁面跳轉、確認狀態、UI 反映的持久化資料）——不斷言內部 state、函式呼叫、DOM 內部結構。
- 步驟描述用**業務語言**（「使用者確認下注」），不要用實作語言（「點擊 `.btn-97`」、「等待 `isLoading` 變 false」）——這樣畫面重構後，情境描述本身不用跟著改，只需要調整底層的 locator。

### Step 4：Page Object / Fixture

- 中大型專案沿用 Page Object Model：`pages/`（一個 class 對應一個頁面/功能）、`tests/`（情境本身）、`fixtures/`（自訂 fixture）、`utils/`（共用工具）。
- 小型測試優先用 **Playwright 的 `test.extend()` composable fixture**，比傳統 POM class 更少樣板、同樣有隔離性。
- Page object 內的方法用「目的」命名（`submitLoginForm`），不要用 DOM 結構命名，讓畫面重構不會牽動測試命名。

### Step 5：Locator 策略

- 優先順序：`getByRole` → `getByLabel` → `getByPlaceholder` → `getByText` → `getByTestId` → CSS/XPath（最後手段，且不要用在互動元素上）。
- `data-testid` 用在真的沒有語意化 role/label/text 可用時（常見於沒有語意標記的動態元件）。

### Step 6：避免 anti-pattern

- **不要**用 `waitForTimeout()`/`sleep()`：一律用 web-first assertion（`toBeVisible`、`toHaveText` 等）或綁定具體條件的 `waitForResponse`/`waitForLoadState`。
- **測試隔離**：每個測試建立自己的資料（透過 API 或 fixture），不要依賴前一個測試留下的狀態或固定的執行順序；除非流程本身必須依序（如精靈步驟），否則不要用 `test.describe.serial`。
- **Network mocking**：用 `page.route()`/`context.route()` 攔截並回傳假資料，需在觸發動作**之前**註冊；`waitForResponse` 也要在觸發動作前設定好（搭配 `Promise.all`），否則可能等到 timeout。

### Step 7：Flaky Test 處理

- `retries` 是**診斷用的安全網**，不是修復手段——retry 幫你把測試撐過去，不代表原因已經解決，仍要回頭排查根因。
- 設定 `trace: 'on-first-retry'`，失敗時能看到完整 timeline/DOM/network/console，而不是只有截圖。
- 常見 flaky 來源：測試資料/順序依賴、沒 mock 的第三方呼叫、動畫/轉場時間、navigation 與 assertion 之間的 race condition。

### Step 8：執行與驗證

**若這是 TDD 測試準備任務**（測試策略為 Test-First，且被明確告知「這是測試準備任務，預期紅燈」）：只需跑一次，確認情境因對應功能尚未實作而失敗（而非 selector 寫錯、環境未就緒等測試本身的問題）即完成，**不要**呼叫 `/fix`、**不要**動手把對應功能實作出來。

**一般情境**：

- 單跑：`npx playwright test {file}`
- 全 suite（僅在使用者明確要求或有 CI 需求時；本地跑 E2E 通常較慢，需要開發伺服器）
- 執行前確認測試環境（baseURL、測試帳號/資料）已就緒，避免對正式環境跑測試。

---

## Checklist

- [ ] 每個情境的 Given/When/Then 都能對應回 US 的一條驗收條件，沒有自己腦補行為
- [ ] 一個情境只驗證一個可觀察結果；沒有把多條 AC 串成一個大情境
- [ ] 情境描述用業務語言，不含 CSS class/API 路徑等實作細節
- [ ] Locator 優先用 role/label/text，`data-testid` 為最後手段，未使用脆弱的 CSS/XPath
- [ ] 沒有 `waitForTimeout`/`sleep`；等待都綁定具體條件
- [ ] 每個測試資料獨立、不依賴執行順序
- [ ] 已跑過並通過；若不穩定，已排查 flaky 根因而非只加 retries

---

## Examples

**US 驗收條件：「Given 使用者已登入且購物車有一筆投注，When 使用者點擊確認下注，Then 系統顯示下注成功訊息並清空購物車」**

→ Given：用 fixture 建立已登入狀態並透過 API 預先塞入一筆投注（不透過 UI 操作，加快且穩定）；When：`await betSlipPage.confirmBet()`；Then：`await expect(page.getByText('下注成功')).toBeVisible()` 且斷言購物車項目數為 0。全程用業務語言命名 page object 方法。

**AC 含糊：「跟之前的結帳流程一樣」**

→ 不要自行假設「之前」指哪個版本；在回覆中標註「此驗收條件需要指定參考對象（哪個版本/頁面的結帳流程），建議請 PM 補充」，並詢問使用者，暫不生成情境。

---

## Additional Resources

- BDD Given/When/Then 撰寫原則、常見錯誤、顆粒度判準；Playwright 的 Page Object/fixture、locator、隔離性、network mocking、flaky 處理、專案設定細節：見 [reference.md](reference.md)
