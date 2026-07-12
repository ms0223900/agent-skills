---
name: vue-integration-test
description: Guides writing Vue 2 component integration tests with @vue/test-utils + Jest + Vuex. Covers mock store factories, heavy-child stubbing via `jest.mock` + `stubs`, DOM + computed dual-layer assertions, and mutation-test self-check. Use when the user wants to add a `.integration.test.ts` (preferred) or `.integration.test.js` for a Vue component, test rendered output against fixtures, or verify store-driven render paths.
---

# Vue 2 Integration Test Workflow

本專案 Vue 2 + Vuex 元件整合測試的撰寫指南，沿用本專案既有參考（`tests/unit/components/MoreGame/SPRD-844-baseball-sorting.integration.test.js`、`feature/SPRD-660` 分支之 `SPRD-660-high-precision.integration.test.js`）與 [@vue/test-utils v1 best practices](https://v1.test-utils.vuejs.org/)。

## 何時使用

- 使用者要求為某個 Vue 元件寫「整合測試」、「渲染測試」、「component integration test」。
- 想驗證 store → computed → DOM 的完整資料流。
- 要把單元測試（pure function）升級成對元件實際渲染行為的斷言。
- **不適用**：純函式／utils／composable 測試（用 `unit-test`）、E2E／瀏覽器行為測試（用 `e2e-test`）、React/Next 元件（用 `react-integration-test`）。

## 流程

### 1. 釐清測試目標

- 要測哪個元件（路徑＋計算屬性／分支）？
- 要覆蓋哪些情境？（對應 fixture 或 user story 的 Scenario）
- 斷言哪幾層？
  - **Computed 層**：直接讀 `wrapper.vm.xxx` — 穩定、易斷言，但偏實作細節。
  - **DOM 層**：`wrapper.findAll('.some-class').length` 或 `wrapper.text()` — 最接近使用者實際看到的結果。
  - **建議**：重要情境兩層都斷言，互為交叉驗證。

### 2. 命名與檔案位置

- **副檔名優先序**：專案已導入 TypeScript 時，新測試預設用 `.ts`（`.integration.test.ts`）；只有專案本身尚未支援 TypeScript（無 `tsconfig.json`、jest 未設定 ts transform）時才退回 `.js`。判斷方式：檢查專案 `tsconfig.json` 是否存在、`jest.config.*` 的 `transform` 是否已涵蓋 `.ts`；同目錄若已有 `.ts` 測試檔，直接視為該目錄的既有慣例，優先沿用。
- 路徑：`tests/unit/components/<元件名稱>/<JIRA-單號>-<簡述>.integration.test.ts`
- 範例：`tests/unit/components/BetViewList/SOPS-3401-duplicate-match-bold.integration.test.ts`（型別標註範例）
- Fixture 獨立放 `tests/unit/__fixtures__/<feature>/*.json`，以 JSON 定義 `input` 與 `expected`，方便機讀比對。

### 3. 檔案骨架（照以下順序撰寫）

```js
/**
 * <JIRA>：<功能簡述> — <Component>.vue 元件層整合測試
 *
 * 覆蓋：<具體分支／computed> (<檔案>:<行號>)
 *       與 DOM 輸出 (<DOM 選擇器>) 是否與 fixture 對齊。
 * 情境：Scenario 1（...）、Scenario 2（...）
 */

// 1. 先 preemptive mock 重量級／transitive 匯入的子元件，避免 jest 轉檔炸鍋
jest.mock('@/components/Heavy/HeavyIndex', () => ({ __esModule: true, default: {} }));
jest.mock('@/components/NoisyChild', () => ({
  __esModule: true,
  default: { name: 'NoisyChild', render: () => null },
}));

// 2. imports
import { createLocalVue, mount } from '@vue/test-utils';
import Vue from 'vue';
import Vuex from 'vuex';
import Target from '@/components/Target.vue';
import fixtureA from '../../__fixtures__/<feature>/scenario-a.json';

// 3. localVue 設定（Vuex + 自訂 directive）
const localVue = createLocalVue();
localVue.use(Vuex);
localVue.directive('loading', { bind() {}, update() {} });

// 4. Fixture builder — 把最小 payload 包成元件期望的 shape
function buildStorePayload(input) { /* ... */ }

// 5. Mock store factory — 只填目標元件實際讀到的 state／getters
function createMockRootStore(payload) {
  return new Vuex.Store({
    getters: { /* 根 getters */ },
    modules: {
      ModuleA: { namespaced: true, state: { /* ... */ } },
      // ...
    },
  });
}

// 6. Mount helper — 集中 mocks／stubs，方便所有 it 重複使用
function mountTarget(input) {
  const store = createMockRootStore(buildStorePayload(input));
  return mount(Target, {
    localVue,
    store,
    mocks: {
      $SportLib: { /* 只 stub 實際被呼叫的方法 */ },
    },
    stubs: {
      Odd: true,
      // 列出所有會渲染但與本測試無關的子元件
    },
  });
}

// 7. Post-mount helper — 處理必要的 data 設定 + nextTick
async function mountAndSetup(input) {
  const wrapper = mountTarget(input);
  wrapper.setData({ selectKey: 'main' }); // 若 template v-for 依賴 data
  await Vue.nextTick();
  return wrapper;
}

// 8. Assertion helpers — 把取值邏輯收斂，降低重複
const toIDs = (wrapper) => wrapper.vm.SomeComputed.map(x => x.id);
const toDomCount = (wrapper) => wrapper.findAll('.target-row').length;

// 9. describe 結構對齊 fixture／Scenario
describe('<JIRA> <Component>.vue 渲染整合測試 — <基準>', () => {
  describe('Scenario 1 — ...', () => {
    it('computed 層順序與 expected 一致', async () => {
      const wrapper = await mountAndSetup(fixtureA.input);
      expect(toIDs(wrapper)).toEqual(fixtureA.expected.order);
    });
    it('DOM 層渲染數量對應 expected', async () => {
      const wrapper = await mountAndSetup(fixtureA.input);
      expect(toDomCount(wrapper)).toBe(fixtureA.expected.order.length);
    });
  });
});
```

**TypeScript 專案的型別標註慣例**（比照 `SOPS-3401-duplicate-match-bold.integration.test.ts`）：
- `import { createLocalVue, mount, Wrapper } from '@vue/test-utils'; import Vuex, { Store } from 'vuex';`
- mock 子元件的 `render()`：`render(this: { propA?: T }, h: (tag: string, data?: Record<string, unknown>) => unknown): unknown`
- 用 `interface` 描述測試 fixture 的資料形狀，而非任由 TS 推斷成 `any`
- 抓大放小：不需要對整個被測元件的 props/data 做完整型別窮舉，足以讓編輯器不噴大量紅字即可

### 4. Mock store 要點

- **只塞元件實際讀到的欄位**。方法：`grep -n 'this\.\$store\.state\.'` 與 `mapState\|mapGetters` 找出依賴。
- 每個 module 設定 `namespaced: true`（若專案慣例是 namespaced store）。
- 若元件會 `commit` mutation：填入空函式 `mutations: { xxx() {} }`；若 `dispatch` action：填 `actions: { xxx: () => Promise.resolve() }`。
- 根 getter 用 `getters: { userOddsAdjustment: () => 0 }`。
- 若 store 邏輯本身是待測對象（例如測 `setGameList` mutation + 元件渲染貫通），改為 `import` 真實 module 並 `new Vuex.Store({ modules: { RealModule } })`。

### 5. Mocks / Stubs 策略

- `mocks`：覆寫 Vue prototype 上的全域（`$SportLib`、`$t`、`$lib`、`$conf`、`$router`、`$route`）。`$t` 通常已在 `tests/unit/setup.js` 全域處理。
- `stubs`：
  - `{ ChildName: true }` — 渲染為空 tag，最輕量。
  - `{ ChildName: { template: '<div />' } }` — 需要 slot 或 prop 互動時。
  - `jest.mock` — 模組層級 mock，用在 **transitive 匯入會炸** 的情況（例如 LiveBoardIndex 匯入一串 SVG/子元件）。
- 優先順序：能 `stubs: true` 就不要 `jest.mock`；必要時才升級到 module mock。

### 6. 斷言撰寫建議（@vue/test-utils best practices）

- 以「使用者可觀察的行為」為主：`wrapper.text()`、`findAll('.selector').length`、`.attributes()`、`.classes()`、`.emitted()`。
- 避免斷言 implementation detail（如 `vm` 內部方法名），除非測試就是為了鎖定該 computed 的行為。
- **Selector 選擇**：
  - 穩定：`data-testid`（推薦新增）、角色語意 class、元件 stub 名 `findComponent({ name: 'X' })`。
  - 易碎：動態 class、CSS 模組化 hash、index-based 存取。
- **非同步更新**：`setData`／`setProps`／`trigger` 後一律 `await Vue.nextTick()`（或 `await wrapper.vm.$nextTick()`）；若涉及多層響應，再加一次 tick 或改用 `flush-promises`。
- **快照測試**：整合測試**不建議**用 `toMatchSnapshot`（快照 diff 太大難審視）。優先用顯式斷言。

### 7. 常見陷阱

1. **上游 `v-if` 阻擋 DOM**：DOM 斷言回 0 時，先在 template 沿著 `v-if` 往外找守門條件（如 `teamData.EvtStatus === 1`），補齊 fixture。
2. **Namespaced vs non-namespaced**：store 模組設定不一致會導致 `mapState` 找不到值；對照來源元件設定。
3. **重複建構 store**：每個 `it` 都建一個新 store，避免前一個測試汙染後面。
4. **Jest 解析 `@/`**：確認 `jest.config.js` 有 `moduleNameMapper: { '^@/(.*)$': '<rootDir>/src/$1' }`。
5. **Vue transition／teleport**：真正的 transition 會讓斷言非同步，必要時 stub。
6. **`mount` vs `shallowMount`**：整合測試幾乎都要 `mount`（才能確認子樹渲染）；`shallowMount` 適合不 care 子元件的純邏輯測試。
7. **假陽性一：依賴 lifecycle 觸發的 debounce/deferred 呼叫，在測試裡不會自動發生**——例如 `immediate: true` 的 watcher 內部包了一層 `lodash/debounce`，若測試沒有 `jest.useFakeTimers()` + `advanceTimersByTime()` 推進，這個呼叫在測試的同步/microtask 執行窗口內根本不會觸發。若測試意圖是驗證「兩次呼叫的先後覆蓋關係」，卻讓其中一次呼叫透過這種會被跳過的路徑觸發，會變成只驗證了一次呼叫、卻誤以為驗證了兩次（測試對競態/覆蓋邏輯完全沒驗證到，卻通過了）。**排解**：測試「呼叫順序/覆蓋」邏輯時，直接呼叫底層非 debounce 方法（自行控制呼叫順序），debounce 本身的計時行為另外用推進假時間的方式單獨驗證，兩者不要混在同一個測試裡。
8. **假陽性二：expected 值與被測 mutation 的參數共用同一個陣列/物件參考**——若 Vuex mutation 是「原地清空/修改後才重新賦值」（例如 `state.list.length = 0; state.list = newList;`），而測試裡拿去 `commit()` 的資料剛好跟拿來斷言的 `expected` 變數是同一個物件參考，之後只要這個 mutation 再被呼叫一次（即使是別的分支、別的資料），連 `expected` 變數本身都會被原地修改掉——導致「actual 被 bug 弄壞」與「expected 也一起被弄壞」兩邊长得一樣，斷言照樣通過（沒測到東西）。**排解**：expected 值一律用獨立深複本（`JSON.parse(JSON.stringify(x))` 或等效方式）在資料尚未被傳進任何 `commit()`/mutation 之前先取快照，不要直接拿測試裡建立 payload 用的原始變數當 expected。這類陷阱在「測試會原地修改陣列/物件的 mutation」時特別容易發生，模擬這種 mutation 的 mock store 也必須忠實複製「原地修改」這個行為本身（不能簡化成單純 `state.x = payload`），否則整類參考別名（reference-aliasing）bug 會變成永遠測不出來、卻誤以為有覆蓋。

### 8. Mutation Test（自我驗證）

完成綠燈後，**把被測的核心邏輯反向破壞一次**（例如把排序改成升序），確認測試會紅。這步證明測試是在綁定邏輯而非 fixture 本身。改完記得還原並再跑一次確認回綠。

### 9. 執行與整合

**若這是 TDD 測試準備任務**（測試策略為 Test-First，且被明確告知「這是測試準備任務，預期紅燈」）：只需跑一次，確認是因對應功能/元件尚未實作而失敗（而非測試本身寫錯），即完成任務，**不要**呼叫 `/fix`、**不要**動手把對應功能實作出來。

**一般情境**：

- 單跑：`npx jest <測試檔路徑> --no-coverage`
- 全 suite：`npx jest --no-coverage`
- Watch：`npx jest --watch`
- 若要 lint：`npx eslint <測試檔路徑>`
- 若失敗且原因不是測試本身寫錯，依 `/fix` 的流程診斷，不要為了通過而放寬斷言。
- 若專案的 `jest.config.*` 是用 `babel-jest`（純去型別）處理 `.ts`，型別標註不影響測試實際執行結果，但仍要維持與專案既有 `.ts` 測試檔一致的型別風格。

## 產出時的溝通

1. 先說明：要覆蓋的元件路徑、情境、斷言層。
2. 快速探 template（上游 `v-if`）與元件依賴（`$store.state.*`、`mapState`、`$SportLib` 等），決定 mock 範圍。
3. 寫 test → 跑 → 依失敗訊息補 fixture 欄位（常見：`EvtStatus`、`Noshow`、`Status`）。
4. 綠燈後做一次 mutation test 驗證，再還原。
5. 最後回報：測試檔位置、通過數、mutation test 結果、發現的關鍵門檻（供其他測試撰寫者參考）。

## 參考實例

- `tests/unit/components/BetViewList/SOPS-3401-duplicate-match-bold.integration.test.ts` — 型別標註參考（`Wrapper`／`Store`、`interface` fixture、mock `render` 簽名）。
- `tests/unit/components/BetViewList/__helpers__/mountBetViewList.ts` — 多個整合測試檔共用 `createStore()`/`mountComponent()` 與子元件 mock factory 的抽取範例（SPRD-925）；因 babel-plugin-jest-hoist 限制 `jest.mock(...)` factory 只能參照名稱以 `mock` 開頭的 import 變數，各測試檔頂層仍需自行呼叫 `jest.mock('@/components/X', () => mockXFactory())`，只是不用重複撰寫 factory 內容本身；同一個檔案也示範了「非泛型函式 + `as Wrapper<Vue & XxxVm>` 呼叫端斷言」的寫法，避免本專案 babel-eslint parser 對泛型函式語法的 parsing error。
- `tests/unit/components/MoreGame/SPRD-844-baseball-sorting.integration.test.js` — MoreGame.vue 棒球排序，雙層斷言。
- `feature/SPRD-660` 分支 `tests/unit/components/bet/SPRD-660-high-precision.integration.test.js` — BetViewList／ListCardItem／StrayCount 高精度計算，factory + stubs pattern。
- `tests/unit/__fixtures__/baseball-sorting/` — JSON fixture 結構範例。
- [@vue/test-utils v1 文件](https://v1.test-utils.vuejs.org/)。
