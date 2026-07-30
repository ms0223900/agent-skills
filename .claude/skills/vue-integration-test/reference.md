# Vue 2 Integration Test — 檔案骨架、陷阱與參考實例

本文件收錄完整檔案骨架範例、TypeScript 型別標註慣例、常見陷阱清單，以及本專案的參考實例。撰寫測試檔骨架或排查斷言異常前，先讀本文件對應章節。

---

## 一、完整檔案骨架範例

依以下順序撰寫（順序本身即為撰寫步驟，見 SKILL.md 第 3 節）：

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

---

## 二、常見陷阱

1. **上游 `v-if` 阻擋 DOM**：DOM 斷言回 0 時，先在 template 沿著 `v-if` 往外找守門條件（如 `teamData.EvtStatus === 1`），補齊 fixture。
2. **Namespaced vs non-namespaced**：store 模組設定不一致會導致 `mapState` 找不到值；對照來源元件設定。
3. **重複建構 store**：每個 `it` 都建一個新 store，避免前一個測試汙染後面。
4. **Jest 解析 `@/`**：確認 `jest.config.js` 有 `moduleNameMapper: { '^@/(.*)$': '<rootDir>/src/$1' }`。
5. **Vue transition／teleport**：真正的 transition 會讓斷言非同步，必要時 stub。
6. **`mount` vs `shallowMount`**：整合測試幾乎都要 `mount`（才能確認子樹渲染）；`shallowMount` 適合不 care 子元件的純邏輯測試。
7. **假陽性一：依賴 lifecycle 觸發的 debounce/deferred 呼叫，在測試裡不會自動發生**——例如 `immediate: true` 的 watcher 內部包了一層 `lodash/debounce`，若測試沒有 `jest.useFakeTimers()` + `advanceTimersByTime()` 推進，這個呼叫在測試的同步/microtask 執行窗口內根本不會觸發。若測試意圖是驗證「兩次呼叫的先後覆蓋關係」，卻讓其中一次呼叫透過這種會被跳過的路徑觸發，會變成只驗證了一次呼叫、卻誤以為驗證了兩次（測試對競態/覆蓋邏輯完全沒驗證到，卻通過了）。**排解**：測試「呼叫順序/覆蓋」邏輯時，直接呼叫底層非 debounce 方法（自行控制呼叫順序），debounce 本身的計時行為另外用推進假時間的方式單獨驗證，兩者不要混在同一個測試裡。
8. **假陽性二：expected 值與被測 mutation 的參數共用同一個陣列/物件參考**——若 Vuex mutation 是「原地清空/修改後才重新賦值」（例如 `state.list.length = 0; state.list = newList;`），而測試裡拿去 `commit()` 的資料剛好跟拿來斷言的 `expected` 變數是同一個物件參考，之後只要這個 mutation 再被呼叫一次（即使是別的分支、別的資料），連 `expected` 變數本身都會被原地修改掉——導致「actual 被 bug 弄壞」與「expected 也一起被弄壞」兩邊长得一樣，斷言照樣通過（沒測到東西）。**排解**：expected 值一律用獨立深複本（`JSON.parse(JSON.stringify(x))` 或等效方式）在資料尚未被傳進任何 `commit()`/mutation 之前先取快照，不要直接拿測試裡建立 payload 用的原始變數當 expected。這類陷阱在「測試會原地修改陣列/物件的 mutation」時特別容易發生，模擬這種 mutation 的 mock store 也必須忠實複製「原地修改」這個行為本身（不能簡化成單純 `state.x = payload`），否則整類參考別名（reference-aliasing）bug 會變成永遠測不出來、卻誤以為有覆蓋。

---

## 三、參考實例

- `tests/unit/components/BetViewList/SOPS-3401-duplicate-match-bold.integration.test.ts` — 型別標註參考（`Wrapper`／`Store`、`interface` fixture、mock `render` 簽名）。
- `tests/unit/components/BetViewList/__helpers__/mountBetViewList.ts` — 多個整合測試檔共用 `createStore()`/`mountComponent()` 與子元件 mock factory 的抽取範例（SPRD-925）；因 babel-plugin-jest-hoist 限制 `jest.mock(...)` factory 只能參照名稱以 `mock` 開頭的 import 變數，各測試檔頂層仍需自行呼叫 `jest.mock('@/components/X', () => mockXFactory())`，只是不用重複撰寫 factory 內容本身；同一個檔案也示範了「非泛型函式 + `as Wrapper<Vue & XxxVm>` 呼叫端斷言」的寫法，避免本專案 babel-eslint parser 對泛型函式語法的 parsing error。
- `tests/unit/components/MoreGame/SPRD-844-baseball-sorting.integration.test.js` — MoreGame.vue 棒球排序，雙層斷言。
- `feature/SPRD-660` 分支 `tests/unit/components/bet/SPRD-660-high-precision.integration.test.js` — BetViewList／ListCardItem／StrayCount 高精度計算，factory + stubs pattern。
- `tests/unit/__fixtures__/baseball-sorting/` — JSON fixture 結構範例。
- [@vue/test-utils v1 文件](https://v1.test-utils.vuejs.org/)。
