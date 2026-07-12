---
name: unit-test
description: 撰寫框架無關的單元測試（純函式、utils、composables、hooks、store actions/mutations 等不涉及 DOM 渲染的邏輯），依專案偵測結果使用 Jest 或 Vitest。依循 FIRST 原則、AAA 結構、測試替身（dummy/stub/spy/mock/fake）分寸拿捏，並以 mutation test 自我驗證測試強度。使用時機：使用者要幫「某個函式/composable/hook/邏輯」寫單元測試，或說「這支 util 需要測試」。元件渲染/DOM 斷言請用 vue-integration-test（Vue）或 react-integration-test（React/Next）；瀏覽器端到端行為請用 e2e-test。
---

# 單元測試撰寫指南（Unit Test Workflow）

單元測試是整個測試金字塔的地基：確保「單一邏輯單元」本身正確，速度快、獨立、可重複執行，是後續 integration/E2E 測試能安心疊上去的前提。

## 何時使用 / 何時不用

**用**：測試對象是**不涉及 DOM 渲染**的邏輯——純函式、`src/utils/`、`src/lib/`、Vue composable、React/Next custom hook（不含渲染斷言的部分）、Vuex/Pinia/Zustand 的 actions/mutations/reducers、資料轉換、驗證規則、狀態機。

**不用（改用其他 skill）**：

| 情境 | 改用 |
|------|------|
| 需要斷言元件實際渲染出的 DOM／computed（Vue） | `vue-integration-test` |
| 需要斷言 React/Next 元件渲染行為（RTL） | `react-integration-test` |
| 需要跨頁面、真實瀏覽器的使用者流程 | `e2e-test` |
| 修正既有錯誤（含測試失敗診斷） | `fix` |

---

## 技術棧與測試框架偵測（Step 0）

1. 讀 `package.json` dependencies/devDependencies：`jest` vs `vitest`，以及 `vue`/`nuxt`/`next`/`react`。
2. 讀 `jest.config.*` 或 `vitest.config.*` / `vite.config.*` 內的 `test` 設定：`testEnvironment`/`environment`、`testMatch`/`include`、`moduleNameMapper`/`alias`、`globals`。
3. 讀 `AGENTS.md` / `CLAUDE.md`（若存在）確認專案既有測試慣例（檔案位置、命名、mock 慣例）。
4. **優先遵守專案既有 pattern**：讀同目錄或同模組既有 `*.test.*`/`*.spec.*` 檔案，沿用其 mock 風格與斷言慣例，而非重新發明一套。
5. **兩種設定檔同時存在時（migration 中常見）**：以「即將撰寫的測試檔所在目錄/模組」裡既有 `*.test.*`/`*.spec.*` 實際使用的 runner 為準；該目錄本身也沒有既有測試可參考時，不要自行猜測，先詢問使用者要用哪個 runner。

| 抽象概念 | Jest | Vitest |
|----------|------|--------|
| Mock 函式/模組 | `jest.fn()` / `jest.mock()` | `vi.fn()` / `vi.mock()` |
| Spy | `jest.spyOn()` | `vi.spyOn()` |
| 假時間 | `jest.useFakeTimers()` | `vi.useFakeTimers()` |
| 全域變數/環境變數 stub | 直接賦值 + 手動還原 | `vi.stubGlobal()` / `vi.stubEnv()` |
| 全域 `describe/it/expect` | 預設全域 | 需 `test.globals: true` 才有全域 |

兩者差異細節（hoisting、ESM 處理、config 選項等）見 [reference-framework.md](reference-framework.md)。

---

## 執行流程

### Step 1：釐清測試邊界

- 明確界定「被測單元」：一個函式、一個 composable/hook、一個 reducer/mutation——**不是**整個模組。
- 列出這個單元的：輸入（含邊界值、非法值）、輸出（含錯誤/例外情況）、與外部的互動邊界（呼叫了哪些外部依賴，需要 stub/mock 掉）。
- 若被測邏輯本身耦合了 DOM 或元件渲染，先評估是否該拆成「純邏輯 + 元件外殼」，再對純邏輯部分寫單元測試（元件外殼交給對應的 integration test skill）。

### Step 2：命名與檔案位置

- 預設**與原始檔案同目錄 co-locate**：`fooBar.ts` → `fooBar.test.ts`（或依專案既有慣例改用 `.spec.ts`、獨立 `__tests__/`）。
- **副檔名優先序**：專案已導入 TypeScript 時預設用 `.ts`／`.tsx`；未支援 TypeScript 的專案才用 `.js`／`.jsx`。
- 只有跨模組的共用測試工具/fixture 才放到獨立的 `tests/`、`__fixtures__/` 目錄。
- 檔名與 `describe` 標題清楚對應被測模組，方便追蹤。

### Step 3：撰寫結構 — AAA + FIRST

- 每個 `it`/`test` 內部分成 **Arrange → Act → Assert** 三段，用空行或簡短註解分隔；如果一個測試無法乾淨拆成這三段，代表它測了太多事。
- 自我檢查是否符合 **FIRST**：Fast、Independent、Repeatable、Self-validating、Timely（原則細節見 [reference-theory.md](reference-theory.md)）。
- **一個測試只驗證一個行為/情境**：happy path、每個邊界值、每個錯誤情境分開寫，不要用「and」把多個情境塞進同一個 `it`。
- **測試命名描述行為而非方法名**：例如 `should throw when amount is negative`，而不是 `test amount`。
- 斷言**公開的輸入輸出行為**，不要斷言私有實作細節（呼叫順序、內部變數）；重構後只要行為不變，測試就不該跟著改。

### Step 4：Mock / 測試替身，適可而止

- 依 Meszaros 的測試替身分類（dummy/stub/spy/mock/fake，定義見 reference-theory.md）選擇最輕量、足夠的替身；**優先用 stub 控制輸入、用真實邏輯驗證輸出**，只有在需要驗證「某個副作用確實發生」時才用 mock 斷言呼叫。
- 常見反模式：把被測單元觸及的每個東西都 mock 掉（包含簡單的 value object）、`verify()`/`toHaveBeenCalled()` 斷言比真正的行為斷言還多——這種測試驗證的是「程式碼呼叫了 X」而非「程式碼行為正確」，重構時容易誤報壞掉。
- 網路請求（`fetch`/`axios`）：優先使用 MSW（Mock Service Worker）在網路邊界攔截，而不是手動塞 `global.fetch = jest.fn()`（容易漏掉 `response.headers.get()` 等細節）。
- 假時間/日期：`jest.useFakeTimers()` / `vi.useFakeTimers()`，搭配 promise 時改用 async 版本（`advanceTimersByTimeAsync` 等）避免 microtask 死鎖。

### Step 5：Async 陷阱

- 一定要 `await`/`return` 非同步斷言，否則測試可能在 promise resolve 前就先通過。
- 明確斷言 rejection：`await expect(promise).rejects.toThrow(...)`，不要 fire-and-forget。
- 若測試 hang 住，優先懷疑「假時間 + 真實 promise」的 microtask 死鎖，改用 async 計時器 API。

### Step 6：隔離性

- 設定 `clearMocks`/`resetMocks`（至少）或 `restoreMocks`（最徹底，會還原 `spyOn` 的原始實作）於 Jest/Vitest config，避免前一個測試汙染下一個。
- 不共用可變的 module-level 狀態；每個 `it` 前用 `beforeEach` 重建。
- Vitest 的 `vi.stubGlobal`/`vi.stubEnv` 預設不會自動還原，需設定 `unstubGlobals`/`unstubEnvs` 或手動 `vi.unstubAllGlobals()`。

### Step 7：執行與驗證

**若這是 TDD 測試準備任務**（測試策略為 Test-First，且被明確告知「這是測試準備任務，預期紅燈」——常見於 `/next-task`／`/feature`／`/adjust` 依 `/user-stories` 的 Test-First 拆分呼叫本 skill 時）：

- 只需跑一次，確認測試**因對應功能尚未實作而失敗**，且失敗原因不是測試本身寫錯（斷言邏輯有誤）、環境設定錯，或型別/語法錯誤。
- 確認是預期紅燈後即完成任務，**不要**呼叫 `/fix`，也**不要**動手把對應功能實作出來——那是後續依賴此測試的實作任務的責任，本 skill 只負責產出這支測試。
- 若失敗原因看起來不是「因為功能還沒實作」（例如測試本身語法錯、import 路徑錯），代表測試寫錯了，先修好測試本身，而不是視為預期紅燈直接結案。

**一般情境**（非 TDD 測試準備任務）：依 Step 0 偵測到的 runner 跑到全部通過：

| Runner | 指令 |
|--------|------|
| Jest | `npx jest {file} --no-coverage` |
| Vitest | `npx vitest run {file}` |

若失敗且原因不是測試本身寫錯，依 `/fix` 的流程診斷（先假設後實證），不要為了通過而放寬斷言。

### Step 8：Mutation Test（自我驗證，選用但建議做一次）

完成綠燈後，把被測邏輯反向破壞一次（例如把 `<` 改成 `<=`、拿掉一個條件分支），確認測試會變紅；證明測試真的綁定邏輯而非巧合通過。驗證完記得還原程式碼並再跑一次確認回綠。

---

## Checklist

- [ ] 被測單元邊界清楚（純函式/composable/hook/reducer，不含 DOM 渲染）
- [ ] 檔案位置與命名依專案既有慣例（預設 co-locate）
- [ ] 每個測試符合 AAA 結構、只驗證一個行為，命名描述行為
- [ ] Mock 使用最小必要替身，未過度 mock；網路請求優先用 MSW
- [ ] 非同步斷言皆已 `await`，rejection 有明確斷言
- [ ] Config 已設定 `clearMocks`/`restoreMocks`，測試間無共用可變狀態
- [ ] 已跑到全部通過；有做過一次 mutation test 自我驗證（或說明為何略過）

---

## Examples

**「幫 `calculateOdds(bets)` 這個純函式寫單元測試」**

→ 判斷為純函式，適用本 skill；列出輸入邊界（空陣列、負數賠率、超過上限）與對應輸出/例外；依專案偵測到 Jest，寫 `calculateOdds.test.ts` co-locate 在同目錄；每個邊界情境各自一個 `it`，AAA 分段；跑 `npx jest calculateOdds.test.ts --no-coverage` 全過後，反向改一個運算子做 mutation test 驗證。

**「這個 Nuxt composable `useBetValidation` 需要測試」**

→ 只測 composable 回傳的邏輯（不掛載元件），必要時用 `@vue/test-utils` 的 `mount` 一個最小 wrapper 或直接呼叫 composable 函式；stub 掉它依賴的 store getter；斷言回傳值與錯誤訊息，而非內部呼叫細節。

---

## Additional Resources

- Jest／Vitest 框架細節、設定、mocking 差異：[reference-framework.md](reference-framework.md)
- 單元測試理論（FIRST、AAA、測試替身、測試金字塔、命名、mutation testing）：[reference-theory.md](reference-theory.md)
