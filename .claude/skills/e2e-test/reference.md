# E2E Test Reference — BDD 理論與 Playwright 實務

本文件分兩部分：一、BDD Given/When/Then 的撰寫理論（框架無關）；二、Playwright 的具體實務細節。SKILL.md 未涵蓋的細節在此補充。

---

## 一、BDD Given/When/Then 撰寫原則

### 1.1 轉譯對照

- **Given → Arrange**：只建立這個行為**真正依賴**的前置條件（使用者狀態、資料狀態、導航狀態）；不影響結果的多餘設定不要放進 Given——多餘的 Given 通常代表這個情境其實測了不只一件事。
- **When → Act**：剛好一個使用者觸發的動作或系統事件。若情境需要「而且使用者又做了 X」，代表該拆成另一個情境。
- **Then → Assert**：只斷言可觀察、使用者看得到的結果（可見文字、導航變化、確認狀態、UI 上反映的持久化資料）——絕不斷言內部 state、函式呼叫或 DOM 內部結構。
- 一條驗收條件對應一個 Given/When/Then 三元組，一個三元組對應一個 E2E 測試。若一條 AC 需要多個 When 或多個 Then 才描述得完整，代表這條 AC 本身該先拆分，而不是硬寫成一個複雜情境。

### 1.2 常見錯誤

- **步驟寫得太貼近實作**：「點擊 `.btn-97`」、「呼叫 `/api/bets/confirm`」、「等待 `isLoading` flag 變 false」——這些描述的是「畫面怎麼做出來的」，不是「使用者體驗到什麼」。應改寫為「使用者確認下注」、「使用者看到確認訊息」。
- **CSS selector、元件名稱、內部 state 名稱滲入步驟文字**：一旦步驟讀起來像程式碼，就不是 BDD，只是「程式的文字說明」。
- **用技術術語取代業務詞彙**：「modal 的 z-index 更新了」而不是「投注面板關閉了」。
- **含糊、無法驗證的 Then**：「系統運作正常」而不是具體、可檢查的結果。
- **用「而且／或者／但是」把多條 AC 藏在一起**：這通常代表其實是兩條以上的驗收條件被合併了，應該拆開各自處理。

### 1.3 讓情境撐過重構

- 描述**使用者的目標與可觀察結果**，永遠不要描述 markup、class 名稱、元件階層或用了哪個 API——這些東西本來就該在重構時自由變動。
- 步驟寫得讓非技術角色（PM、QA、客服）不看程式碼也能讀懂、能照著操作。
- 斷言真實使用者會注意到的東西：可見文字/標籤、頁面/路由變化、確認狀態、錯誤訊息——不斷言 test-id 數量、store mutation、動畫時間。
- 當畫面結構重整、但使用者可見行為沒變時，情境文字與這支 E2E 測試「要驗證什麼」都不該需要改動——只有測試實作內部的 locator 需要調整。

### 1.4 顆粒度：一個情境只驗證一個行為

- 每個情境只驗證單一行為/結果。一個情境同時驗證登入、又檢查歡迎橫幅、又驗證跳轉，其實是三個情境黏在一起——其中一個壞掉會掩蓋另外兩個，也讓診斷變困難。
- 寧可拆成多個小、可獨立閱讀的情境，也不要寫一個從頭走到尾的「大情境」。長串的 happy path 該拆解成對應各自 AC 的、可獨立驗證的步驟。
- 判準：如果無法用一句話講出「這個情境要驗證的單一結果」，代表涵蓋範圍太廣。
- 情境獨立也能降低測試間的耦合——一個前置條件壞掉，不會連帶讓不相關的測試一起失敗。

### 1.5 驗收條件作為共同真相來源

- User Story 寫成 Given/When/Then 的驗收條件，**同時**服務手動 QA（人依照同一組 Given/When/Then 當作檢查清單操作）與自動化 E2E 測試（把同一個三元組轉成 arrange/act/assert）——不需要另外寫一份「測試規格」。
- 因為驗收條件本身用業務語言、可觀察結果描述，不論是人工點擊還是程式驅動瀏覽器執行，驗證的都是同一句陳述，維持一致性。
- 可追溯性因此得以保留：每條 AC ↔ 一個情境 ↔ 一支 E2E 測試，測試失敗時能直接回推到違反了哪一條具體的業務需求。

---

## 二、Playwright 實務

### 2.1 Page Object 與 Fixture

- 中大型 suite 仍建議用 POM：`pages/`（一個 class 對應一個頁面/功能）、`tests/`（只放情境）、`fixtures/`（自訂 test fixture）、`utils/`（共用工具）。
- 小到中型 suite，官方目前更推薦**用 composable fixture 取代傳統 POM class**：透過 `test.extend()` 注入現成的 page object，隔離性相同但樣板更少。
- **頁面層級斷言**（例如「表單已送出」）放在 page object 內；**情境專屬斷言**留在測試檔案。
- Locator/方法依「目的」命名（`submitLoginForm`），而非依 DOM 結構命名，讓畫面重構不會牽動測試。
- Fixture 負責 setup/teardown（登入狀態、預先塞入的資料），讓測試本身保持宣告式、易讀。

### 2.2 Locator 策略

- 優先順序（Playwright 官方文件）：`getByRole(role, { name })` → `getByLabel()` → `getByPlaceholder()` → `getByText()` → `getByTestId()` → CSS/XPath 僅作最後手段，且不要用在互動元素上。
- `getByRole` 同時具備無障礙檢查的效果，因為它模擬輔助科技辨識元素的方式。
- CSS class 與 XPath 很脆弱——綁定了「不影響使用者行為、但重構就會變」的實作細節（`div` 換成 `section`、class 改名）。
- 當沒有語意化的 role/label/text 可以唯一定位時，才用 `data-testid`（常見於沒有語意標記的動態 Vue/React 元件）。
- 用 `.filter()`/`.locator()` 串接、縮小範圍，取代冗長的複合 CSS selector。

### 2.3 自動等待 — 不要手動 sleep

- 每個動作（`click`、`fill`、`check`、`selectOption`）與每個 web-first 斷言（`toBeVisible`、`toHaveText` 等）都會自動等待元素被 attach、可見、穩定、可互動。
- `page.waitForTimeout()`／任意 `sleep()` 是反模式：會讓測試變慢（永遠等最大值）又仍然不穩定（等的時間不見得對）。優先用綁定具體條件的 web-first assertion 或 `waitForResponse`/`waitForLoadState`。
- Await 的對象是**斷言本身**：`await expect(locator).toBeVisible()`，而不是 `if (await locator.isVisible())` 這種手動預先檢查。
- 多個非阻斷性檢查可用 `expect.soft`。

### 2.4 測試隔離

- 每個測試預設拿到全新的 **BrowserContext**（像無痕視窗），測試間不共用 cookie/localStorage/session——不要關閉這個預設行為。
- 每個測試/worker 應該自己準備資料（透過 API 呼叫在 `beforeEach` 或 fixture 內完成），不要依賴前一個測試留下的資料，也不要依賴固定的測試執行順序。
- 除非流程真的必須依序執行（例如精靈式多步驟表單），否則不要用 `test.describe.serial`——那會重新引入耦合與連鎖失敗。
- 避免測試你不掌控的第三方/外部網域，改為 mock 掉。

### 2.5 Network Mocking 與等待回應

- 用 `page.route()`/`context.route()` 攔截並回傳固定的假資料——確定性高、快、不受後端狀況影響。
- 必須在**觸發動作之前**註冊 route，Playwright 依呼叫當下的順序比對請求。
- `waitForResponse(urlOrPredicate)` 也必須在觸發動作**之前**設定好（搭配 `Promise.all` 包裝），否則回應可能已經先發生，導致一路等到 timeout。
- 用具體的 URL/predicate 比對並驗證 status/payload，不要用過於寬鬆的 pattern——否則同一個 endpoint 被呼叫多次時可能抓到錯的那一次。
- 每個攔截的 route 只 resolve 一次；需要部分放行（例如 GraphQL）時用 `route.fallback()`。

### 2.6 Flaky Test 處理

- 把 `retries`（例如 CI 設 `retries: 2`）當成**診斷用的安全網**，不是修法——長期依賴 retry 而不去查根因，等於讓不穩定測試繼續存在。
- 設定 `trace: 'on-first-retry'`（或 `retain-on-failure`），失敗的測試能留下完整 trace.zip（timeline、DOM snapshot、network、console）供 Trace Viewer 檢視，而不只是截圖。
- 避免時間相關/隨意猜測的斷言（固定 sleep、猜動畫時長）；用 web-first assertion，`waitForLoadState('networkidle')` 只在真的有對應信號時才用。
- 常見 flaky 來源：共用測試資料/順序依賴、沒 mock 的第三方呼叫、動畫/轉場時間、navigation 與 assertion 之間的 race condition。

### 2.7 專案結構與設定

- `playwright.config.ts`：用 `devices[...]`（`Desktop Chrome`、`Desktop Firefox`、`Desktop Safari`、`Pixel 5`、`iPhone 12`，或指定 `channel: 'chrome'|'msedge'`）定義各瀏覽器/裝置的 `projects`，讓同一套情境能跨瀏覽器/裝置執行。
- 開啟 `fullyParallel: true` 與 CI sharding 加速；集中設定 `testDir`、`reporter: 'html'`、`use`（`baseURL`、`trace`、`screenshot`、`video`）。
- 用 `projects` 之間的 `dependencies` 處理「setup project」（例如產生 auth/storage-state 只跑一次，其他 project 直接消費）。
- 用 `test.step('description', async () => {...})` 把測試內的步驟分組，改善 trace/report 可讀性與除錯，而不需要拆成多支測試。
- 保留 TypeScript 以獲得 IDE 支援；CI 上跑 Linux，本地不限；定期更新 Playwright 以取得 locator/engine 修正。
