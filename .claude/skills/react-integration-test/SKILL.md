---
name: react-integration-test
description: Guides writing React / Next.js component tests with React Testing Library (RTL) + @testing-library/user-event（不使用 Enzyme／shallow render）。涵蓋 query 優先順序、真實 Provider（Context/Redux/Zustand/React Query）取代 mock 內部、MSW 網路層 mocking、Next.js Server/Client Component 邊界。Use when the user wants a component/integration test for a React or Next.js component, or asks to verify rendered output / user interaction against a component.
---

# React / Next.js Integration Test Workflow

本專案 React／Next.js 元件測試指南，統一使用 [React Testing Library](https://testing-library.com/docs/react-testing-library/intro/)（RTL）+ `@testing-library/user-event`，**不使用 Enzyme**——Enzyme 對 React 18+/19 已無可靠 adapter，`shallow`／`.instance()`／`.state()` 這類寫法一律不採用。

## 何時使用

- 使用者要求為某個 React／Next.js 元件寫「整合測試」、「component test」、「渲染測試」。
- 想驗證使用者互動（點擊、輸入、切換）後的畫面結果，或元件搭配 hooks/context/store 的資料流。
- **不適用**：純函式／hook 內部邏輯（不涉及渲染）→ 用 `unit-test`；跨頁面瀏覽器流程 → 用 `e2e-test`；Vue 元件 → 用 `vue-integration-test`。

---

## 流程

### 1. 釐清測試目標

- 測哪個元件（路徑＋要覆蓋的 props/互動分支）？
- 覆蓋哪些情境？對應 fixture 或 user story 的 Scenario。
- **核心原則：測行為，不測實作**——斷言使用者看得到/做得到的事（畫面文字、可互動元素，或傳入 `vi.fn()`／`jest.fn()` callback 後其是否以正確資料被呼叫），不斷言元件內部 state、hook 回傳值本身、或私有方法。
- 不要用「能不能整個重寫實作、輸入輸出不變、卻完全不用改這支測試」當標準——若答案是不能，代表測到了實作細節。

### 2. 命名與檔案位置

- 路徑：`{Component}.test.tsx`，優先與元件同目錄 co-locate（`ComponentName/ComponentName.tsx` + `ComponentName/ComponentName.test.tsx`），除非專案既有慣例是集中在 `__tests__/`。
- Fixture／mock handler 獨立放 `__fixtures__/`／`mocks/`，方便跨測試重用。

### 3. 檔案骨架（照以下順序撰寫）

```tsx
/**
 * <JIRA/描述> — <Component>.tsx 元件整合測試
 * 覆蓋：<互動/狀態分支> 與 render 輸出是否符合 fixture。
 */

// 1. imports
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';
import Target from './Target';
import fixtureA from '../../__fixtures__/<feature>/scenario-a.json';

// 2. MSW server — 攔截網路層，不 mock fetch/axios 本身
const server = setupServer(
  http.get('/api/xxx', () => HttpResponse.json(fixtureA.apiResponse)),
);
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

// 3. Provider wrapper — 用真實 Provider，不 mock store/context 內部
function renderWithProviders(ui: React.ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>,
  );
}

// 4. describe 結構對齊 fixture／Scenario
describe('<Component> 渲染整合測試', () => {
  it('使用者送出表單後顯示成功訊息', async () => {
    const user = userEvent.setup();
    renderWithProviders(<Target />);

    await user.type(screen.getByLabelText('金額'), '100');
    await user.click(screen.getByRole('button', { name: '送出' }));

    expect(await screen.findByText('送出成功')).toBeInTheDocument();
  });
});
```

### 4. Query 優先順序

依 Testing Library 官方建議，能用上面的就不用下面的：

1. `getByRole`（搭配 `{ name }`）— 對應 accessibility tree，絕大多數情境的首選。
2. `getByLabelText` — 表單欄位。
3. `getByPlaceholderText` — 沒有 label 時的次選。
4. `getByText` — 非互動內容（純文字、段落）。
5. `getByDisplayValue` / `getByAltText` / `getByTitle` — 較窄的特殊情境。
6. `getByTestId` — **最後手段**，只有在完全沒有語意化 query 可用時才用。

用 `queryBy*` 斷言「不存在」；用 `findBy*` 斷言「非同步後才出現」；一般查詢優先用 `screen.getByRole(...)` 而非解構 `render()` 的回傳值。

### 5. `user-event` 優先於 `fireEvent`

- `fireEvent` 只丟出單一原始 DOM 事件；`userEvent`（v14+）模擬完整的真實互動序列（focus、keydown、input、keyup…），更貼近使用者實際行為，也會檢查元素是否真的可互動。
- 點擊、輸入、Tab、選取一律優先用 `userEvent`；只有 `userEvent` 尚未支援的事件才退回 `fireEvent`。
- v14 起所有 `userEvent` API 都是 async：每次呼叫都要 `await`，並用 `userEvent.setup()` 每個測試各自建立一個 instance，不要用 static method。

### 6. 非同步與避免 `act()` 警告

- 非同步才會出現的元素用 `findBy*`（內建 `waitFor` + polling），錯誤訊息比手動 `waitFor` 更清楚。
- `waitFor` 的 callback 裡只放查詢/斷言，不要放有副作用的程式碼。
- `render` 與 `userEvent`/`fireEvent` 本身已包在 `act` 裡，不需要額外包一層 `act()`；出現「not wrapped in act」警告通常代表真的漏了某個 `await`（例如某個 state 更新沒等待），修法是補上 `await` 或改用 `findBy*`，而不是想辦法讓警告消失。

### 7. Hooks / Context / Redux / Zustand / React Query

- **優先用真實 Provider，而非 mock store/context 內部**：把待測元件包在真的 `<Provider>`（Redux）、真的 Context.Provider，或真的 Zustand store / `QueryClientProvider`，每個測試建立一份全新 instance（例如 `createTestStore()`/`renderWithProviders()` helper）。
- 不要 mock selector、自訂 hook 或 `react-redux`/`zustand` 內部——這會讓測試脫離實際的 app 組裝方式，掩蓋真正的 bug。
- React Query：用 `QueryClientProvider` 搭配測試用 `QueryClient`（`retry: false`），只 mock 網路層（見下方 MSW），不要 mock query hook 本身。
- Zustand：每個測試建立一份獨立、範圍侷限的 store/provider，避免狀態跨測試殘留。

### 8. 網路請求 Mocking — 用 MSW，不要直接 mock fetch

- 用 MSW（Mock Service Worker）在網路層攔截，對 `fetch`、`axios`、React Query、Apollo 等一視同仁，應用程式碼完全不用改。
- 相較手動 `global.fetch = jest.fn()`／`jest.mock('axios')`：handler 可在 dev/test/Storybook 間共用（單一事實來源）、能模擬真實網路語意（status code、延遲、錯誤），且不用碰觸 app 程式碼。
- 慣例：`setupServer(...handlers)` 於 `beforeAll` 啟動、`afterEach` 呼叫 `server.resetHandlers()`、`afterAll` 呼叫 `server.close()`；個別測試需要錯誤/邊界情境時用 `server.use(...)` 覆寫。

### 9. Next.js 特殊情況

- Client Component（`"use client"`）用 RTL/jsdom 測試方式與一般 React 元件相同，不需特殊處理。
- Server Component（async、使用 `cookies()`/`headers()`/DB 呼叫等 server-only API）**目前無法用 RTL/jsdom 可靠地單元測試**——jsdom 是瀏覽器環境模擬，RSC 不會在裡面渲染，Jest 也不完整支援 async Server Component。建議：只對同步、簡單的 Server Component 做測試，把邏輯/畫面盡量抽到可測的 Client Component；完整的 RSC + data fetching + hydration 行為交給 `e2e-test`（Playwright）驗證。
- `next/navigation`（`useRouter`、`usePathname`、`useSearchParams`）用 `jest.mock('next/navigation', ...)` 回傳 `jest.fn()`（或用 `next-router-mock` 套件處理依賴真實導航狀態的頁面）；舊版 Pages Router 則對應 mock `next/router`。

### 10. 常見反模式

- 明明 `getByRole`/`getByLabelText` 就能定位，卻用 CSS class 或隨意加的 `data-testid`——這通常也暗示著可及性（accessibility）本身有缺口。
- 伸手進元件內部：斷言 state 變數、呼叫 instance method、斷言非使用者可見的實作細節。
- 每樣東西都用 snapshot 測試——大型 snapshot 很快過期、容易被無腦 `-u` 更新，也表達不出測試意圖。
- 用手動 `act()` 取代 `findBy*`/`waitFor`/`await userEvent`。
- 過度 mock：mock 掉自訂 hook、context 或 store 內部，而不是用真實 Provider 只 mock 網路層。

### 11. 執行與整合

**若這是 TDD 測試準備任務**（測試策略為 Test-First，且被明確告知「這是測試準備任務，預期紅燈」）：只需跑一次，確認是因對應功能/元件尚未實作而失敗（而非測試本身寫錯），即完成任務，**不要**呼叫 `/fix`、**不要**動手把對應功能實作出來。

**一般情境**：

- 單跑：`npx jest <測試檔路徑> --no-coverage` 或 `npx vitest run <測試檔路徑>`（依專案偵測到的 runner；兩種設定檔同時存在時，以同目錄/模組既有測試實際使用的 runner 為準，無既有測試可參考則先詢問使用者，不要自行猜測）
- 全 suite：`npx jest --no-coverage` / `npx vitest run`
- 若要 lint：`npx eslint <測試檔路徑>`

### 12. Mutation Test（自我驗證）

完成綠燈後，把被測的核心互動邏輯反向破壞一次（例如把驗證條件反過來），確認測試會紅，證明測試綁定的是行為而非巧合通過。驗證完記得還原並再跑一次確認回綠。

---

## 產出時的溝通

1. 先說明：要覆蓋的元件路徑、情境、要斷言的使用者行為。
2. 快速確認元件依賴的 Provider/Context/Store/API，決定要包哪些真實 Provider、要用 MSW mock 哪些 endpoint。
3. 寫 test → 跑 → 依失敗訊息補齊 fixture/handler。
4. 綠燈後做一次 mutation test 驗證，再還原。
5. 最後回報：測試檔位置、通過數、mutation test 結果。

## 參考資源

- [Testing Library — Queries 優先順序](https://testing-library.com/docs/queries/about/)
- [Testing Library — user-event](https://testing-library.com/docs/user-event/intro/)
- [MSW 文件](https://mswjs.io/docs/)
- [Next.js — Testing 官方指南](https://nextjs.org/docs/app/guides/testing)
