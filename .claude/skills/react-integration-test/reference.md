# React / Next.js Integration Test — 檔案骨架與 Next.js 細節參考

本文件收錄完整檔案骨架範例，以及 Next.js Server/Client Component 測試能力邊界的詳細說明。撰寫測試檔骨架、或處理 Next.js 特殊情境前，先讀本文件對應章節。

---

## 一、完整檔案骨架範例

依以下順序撰寫（順序本身即為撰寫步驟，見 SKILL.md 第 3 節）：

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

---

## 二、Next.js 特殊情況細節

- Client Component（`"use client"`）用 RTL/jsdom 測試方式與一般 React 元件相同，不需特殊處理。
- Server Component（async、使用 `cookies()`/`headers()`/DB 呼叫等 server-only API）**目前無法用 RTL/jsdom 可靠地單元測試**——jsdom 是瀏覽器環境模擬，RSC 不會在裡面渲染，Jest 也不完整支援 async Server Component。建議：只對同步、簡單的 Server Component 做測試，把邏輯/畫面盡量抽到可測的 Client Component；完整的 RSC + data fetching + hydration 行為交給 `e2e-test`（Playwright）驗證。
- `next/navigation`（`useRouter`、`usePathname`、`useSearchParams`）用 `jest.mock('next/navigation', ...)` 回傳 `jest.fn()`（或用 `next-router-mock` 套件處理依賴真實導航狀態的頁面）；舊版 Pages Router 則對應 mock `next/router`。
