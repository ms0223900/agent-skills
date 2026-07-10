# Unit Test Reference — 框架篇（Jest / Vitest）

本文件收錄 Jest 與 Vitest 的專案慣例、mocking 策略、非同步陷阱、快照測試取捨、隔離性設定、覆蓋率門檻，以及兩者的實務差異。SKILL.md 未涵蓋的細節在此補充。

---

## 一、專案與設定慣例

- **檔名**：`*.test.ts` / `*.test.tsx`（或依專案慣例 `.spec.ts`）。Jest、Vitest 皆可，選一種並用 `testMatch`/`include` 固定下來。
- **Co-location 優先**：`Component.ts` 旁放 `Component.test.ts` 是目前主流慣例——import 路徑短、易於發現。跨模組共用/整合測試才放獨立的 `__tests__/` 或 `tests/`。
- **Manual mocks（Jest）**：`__mocks__/` 同層資料夾可自動套用 module mock；node_modules 的 mock 仍需顯式 `jest.mock('module')`。Vitest 也支援 `__mocks__/`，但因 ESM mocking 較顯式，較少依賴此慣例。
- **Transformer 選擇（僅 Jest 需要）**：`ts-jest` 有真正型別檢查但最慢；`babel-jest`/`@swc/jest` 只做語法轉換不做型別檢查（配合另外跑 `tsc --noEmit`）。**目前建議預設用 `@swc/jest`** 換取速度。
- **Vitest 設定要點**：`vitest.config.ts`（或 `vite.config.ts` 的 `test` 欄位）需要 `test.environment`（`node`/`jsdom`/`happy-dom`）、`test.globals`、`test.setupFiles`、`test.coverage`（provider 用 `v8` 或 `istanbul`）。因為重用 Vite pipeline，TS/JSX 不需額外 transform 設定。
- **`globals` 選項**：Vitest **預設不會**像 Jest 一樣全域注入 `describe/it/expect`（需顯式 `import from 'vitest'`）；要模擬 Jest 的全域行為，設 `test.globals: true` 並在 `tsconfig.json` 加 `"types": ["vitest/globals"]`。

---

## 二、Mocking 策略

- **模組 mock**：`jest.mock('./module')` 與 `vi.mock('./module')` API 幾乎一致（~95% 相容），但兩者的 hoist 機制不同：**Vitest 的 `vi.mock` 是建置時靜態分析 hoist**，mock factory 內不能直接參照頂層 `const`，需用 `vi.hoisted()` 宣告；**Jest 是透過 `babel-plugin-jest-hoist` 這個 Babel 原始碼轉換（source transform）**，在編譯階段把 `jest.mock()` 呼叫搬到 import 之前，對頂層 `const` 的參照較寬容——兩者都是編譯期的靜態轉換，不是執行期的 bytecode 操作，差別在於轉換工具鏈與寬容度。
- **Spy**：`jest.spyOn(obj, 'method')` 與 `vi.spyOn(obj, 'method')` 幾乎相同；當你只想觀察/覆寫某個方法、其餘保留真實實作時用 spy，而非整個模組 mock 掉。
- **ESM mocking 差異**：Jest 對 ESM 仍需 `--experimental-vm-modules` + `jest.unstable_mockModule` 才能做真正 ESM mock；Vitest 把 ESM 當一等公民（透過 Vite 的 module graph 執行），對 ESM 密集或 Vite/Nuxt 專案明顯更簡單。
- **假時間/日期**：兩者皆有 `jest.useFakeTimers()`/`vi.useFakeTimers()`、`advanceTimersByTime`、`setSystemTime`。共同陷阱：推進假時間可能讓「以 promise 為基礎的微任務」程式碼死鎖——優先用 **async 版本**（`advanceTimersByTimeAsync`/`runAllTimersAsync`），會在每個 tick 之間 flush microtask。
- **Fetch/axios**：避免臨時 `global.fetch = jest.fn()`——只 stub 到 `Response` 物件的一部分，程式一旦呼叫 `response.headers.get(...)` 就會爆。**目前最佳實務：用 Mock Service Worker（MSW）**，在網路層攔截（同時支援 fetch/XHR/axios），不受換 client library 影響，且可設定 `onUnhandledRequest: 'error'` 讓任何沒被 mock 到的呼叫直接失敗曝光。

---

## 三、非同步測試陷阱

- 忘記在非同步斷言前 `await`/`return`：測試可能在 promise resolve 前就先通過，`.then()` 裡的斷言其實從未真正執行。務必 `await` 或 `return` 該 promise。
- 未處理的 rejection（rejected promise 沒被 await/catch）在兩個框架都會獨立浮現成失敗——改用明確斷言 `await expect(promise).rejects.toThrow(...)`，不要 fire-and-forget。
- 假時間 + 真實 promise 混用要小心；若測試 hang 住，優先懷疑 timer/microtask 死鎖，改用上述 async 計時器 API。

---

## 四、快照測試的取捨

- 適合大型、穩定的序列化輸出（渲染後的 DOM 樹、API 回應形狀），但若 reviewer 不看內容就 `--update`/`-u`，會退化成純噪音。
- 原則：把 `.snap` 檔當成「需要被審查的程式碼」——PR review 時每一筆 diff 都要真的看過再接受。
- 避免用快照測試：業務邏輯斷言（改用明確的 `toEqual`/`toBe`）、含不確定性內容（timestamp、id，除非先正規化）、整個大元件的巨大快照（無關的改動也會讓它失敗）。
- Vitest 與 Jest 的快照格式相容，但從 Jest 遷移時注意換行符/絕對路徑差異可能造成假 diff。

---

## 五、隔離性

- Config 至少設定 `clearMocks: true`（每個測試重置呼叫紀錄）；**`restoreMocks: true` 是最徹底的設定**，是唯一會把 `spyOn` 建立的 mock 還原成原始實作的選項（Jest、Vitest 皆支援 `clearMocks`/`resetMocks`/`restoreMocks` 這三個旗標）。
- Vitest 特有陷阱：`vi.stubGlobal`/`vi.stubEnv` **不會**在測試間自動還原，除非設定 `unstubGlobals`/`unstubEnvs`，或手動呼叫 `vi.unstubAllGlobals()`。
- 不要讓 module-level 的可變狀態跨測試檔共用；任何記憶體內 store/singleton 都要在 `beforeEach` 重置。

---

## 六、覆蓋率門檻

- 實務目標：約 80% 行/分支覆蓋率作為 release gate，CI 失敗門檻可略低（例如 70%）作為安全網而非硬性擋關。
- 覆蓋率百分比是「異味偵測器」，不是目標——只跑過 happy path 也可能有很高的行覆蓋率，卻漏掉錯誤路徑。對關鍵邏輯優先看 branch/condition coverage，而非單純的 line coverage。
- 設定方式：Jest 用 `coverageThreshold`，Vitest 用 `test.coverage.thresholds`；Vitest 預設 `v8` provider（快、不需插樁）。

---

## 七、Jest vs Vitest — 實務切換對照

| 面向 | Jest | Vitest |
|---|---|---|
| ESM | 實驗性、需開關 | 原生一等公民 |
| 速度 | 冷啟動較慢（Jest 30 已縮小差距） | watch mode 較快（Vite module graph），遷移案例常見 30–70% CI 時間下降 |
| Mocking API | `jest.mock`/`jest.fn`/`jest.spyOn` | `vi.mock`/`vi.fn`/`vi.spyOn`，約 95% API 相容 |
| Hoisting | `babel-plugin-jest-hoist`（Babel 原始碼轉換）hoist | 建置時靜態分析 hoist，外部變數需 `vi.hoisted()` |
| Globals | 預設全域 | 需 `test.globals: true` 才 opt-in |
| 設定 | 獨立 `jest.config`，需 Babel/ts-jest/swc transform | 重用 Vite 設定，不需額外 transform pipeline |
