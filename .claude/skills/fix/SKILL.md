---
name: fix
description: 修正 ESLint error、TypeScript type error、測試失敗、compile/build error 等有明確工具輸出的錯誤。流程為重現錯誤→分類→（根因不明時）先假設後實證→修正根因→重跑驗證到全過。根因涉及行為/資料流等模糊問題時會先借用 quick-debug 定位再回來修；若程式碼本身無法確認根因，必須誠實告知並具體請使用者提供 API response、log、畫面截圖等佐證，不可以亂猜亂改。使用時機：使用者貼 ESLint/tsc/test/build 的錯誤訊息，或說「幫我修這個錯誤」「這個測試過不了」「type error 修一下」「build 失敗」。
---

# 修錯工作流程（Fix Workflow）

## 目標

處理**有明確工具輸出**的錯誤：ESLint error、TypeScript type error、測試失敗、compile/build error。流程為：**重現錯誤 → 分類 → 根因判斷（先假設，後實證）→ 修正根因 → 重跑驗證到全過**。

核心原則：

- **不亂猜亂改**：沒有先驗證假設就不動手改程式碼。
- **先假設，後實證**：根因不明時，提出具體、可驗證的假設，用最小成本方式驗證後才修正。
- **誠實以報**：若程式碼本身無法確認根因（需要外部證據），必須明確告知使用者「證據不足」並具體列出需要什麼資訊，不可以用「先改改看」的方式包裝成確定的修法。

---

## 技術棧偵測（Step 0）

套用本 skill 前，先判定目標專案技術棧：

1. 讀 `package.json` dependencies（`vue`、`nuxt`、`next`、`react`、狀態庫等）與 `scripts`（`lint`、`typecheck`、`test`、`build` 對應的實際指令）
2. 讀 `AGENTS.md` / `CLAUDE.md`（若存在）
3. 檢查工具設定檔：`.eslintrc*` / `eslint.config.*`、`tsconfig.json`、`jest.config.*` / `vitest.config.*`、`playwright.config.*`、`nuxt.config.*` / `next.config.*` / `vite.config.*`
4. 將結果記在內部上下文，再套用下方框架對照 overlay；**優先遵守專案既有規範與同目錄既有 pattern**，無文件時才用偵測到的框架預設慣例
5. **`jest.config.*` 與 `vitest.config.*` 同時存在時（migration 中常見）**：以受影響測試檔所在目錄/模組裡既有測試實際使用的 runner 為準；無既有測試可參考時，先詢問使用者，不要自行猜測。

| 抽象概念 | Vue 2 | Nuxt 3 | Next.js (App Router) |
|----------|-------|--------|----------------------|
| 元件狀態 | Options `data`/`computed`/`watch` | Composition `ref`/`computed`/`watch` | hooks / `useState` |
| 全域狀態 | Vuex | Pinia | Zustand / Redux / server state |
| 型別檢查 | `vue-tsc` / JS + JSDoc | `nuxi typecheck` / `vue-tsc` | `tsc --noEmit` |
| 測試 runner | Jest | Vitest / Jest | Jest / Vitest |
| i18n | vue-i18n `$t` | `@nuxtjs/i18n` | `next-intl` 等（依專案） |

---

## 使用時機 / 何時不用

**用**：使用者貼出或描述具體錯誤 —— ESLint 報錯訊息、`tsc`/型別檢查錯誤、測試失敗輸出（斷言不符、snapshot 過期）、build/compile 失敗 log。

**不用（改用其他 skill）**：

| 情境 | 改用 |
|------|------|
| 沒有明確工具報錯，只是「行為怪怪的」「畫面不對」，需要先定位問題層級 | `quick-debug` |
| 只是「這個元素／class 怎麼渲染」「怎麼在畫面上叫出來」 | `find-component-render-path` |
| 純粹新增功能、無錯誤 | `feature` |
| 純重構、無 bug（拆組件、抽共用邏輯、調整架構） | `refactor` |
| 使用者提出補充需求（非修錯） | `adjust` |
| 測試失敗是**刻意設計的 TDD 紅燈**（測試策略為 Test-First 的測試準備任務，對應功能本來就還沒實作） | 不是 /fix 的守備範圍——這是預期行為，不要順手把功能實作出來；回報給使用者，交由對應的實作任務走 `/feature`／`/refactor`／`/adjust` |

若修正過程中發現根因其實是**大範圍的架構/型別設計問題**（例如某型別在十幾個檔案都用錯、需要重新設計介面），超出「修一個錯誤」的範圍 → 停下，告知使用者，建議改用 `/refactor` 或切換 Plan 模式，不要在本 skill 內順手做大改。

---

## 執行流程

### Step 1：重現與收集證據

1. 優先使用使用者已提供的錯誤文字 / log / 截圖；資訊不完整時才動手重現。
2. 依 Step 0 偵測結果執行對應指令：

   | 類型 | 常見指令（依專案 `package.json` scripts 調整） |
   |------|------|
   | ESLint | `npx eslint {path}` / `npm run lint` |
   | TypeScript | `npx tsc --noEmit` / `npx vue-tsc --noEmit` |
   | Test | `npx jest {file} --no-coverage` / `npx vitest run {file}` / `npx playwright test {file}` |
   | Build/Compile | `npm run build` / `next build` / `nuxt build` / `vite build` |

3. 必須取得**完整**錯誤訊息：檔案:行號:列號、錯誤碼/規則 ID、堆疊、或斷言的 expected vs actual diff。只擷取有意義的片段，不要整段貼滿噪音 warning。
4. 多筆錯誤同時出現時，先概覽全部再分組——同一根因常引發多筆錯誤，逐條各自修容易互相打架。

### Step 2：錯誤分類

依錯誤輸出判斷屬於哪一類，各類「先看哪裡」摘要如下（詳細成因表與反模式見 [reference.md](reference.md)）：

| 類型 | 先看 | 常見成因 |
|------|------|----------|
| ESLint | 規則 ID、報錯那一行 | 未使用變數、hook 依賴陣列、import 順序、格式規則 |
| TypeScript | 錯誤碼、型別定義、呼叫點 | 型別不符、缺 null/undefined 檢查、泛型/overload 不符、第三方型別缺失 |
| Test | 斷言 diff、測試前後 setup/mock | 產品邏輯改了但測試沒跟上、snapshot 過期、mock 設定錯、async timing |
| Compile/Build | 建置工具輸出的第一則錯誤 | module not found、循環依賴、設定檔（tsconfig/webpack/vite）問題、語法錯誤 |

### Step 3：根因判斷 —— 先假設，後實證

1. 依錯誤訊息 + 讀程式碼，提出一個**具體、可驗證**的假設（不是「可能是這裡有問題」這種模糊說法）。
2. 判斷這個假設是「單純的工具鏈問題」還是「牽涉行為/資料流的模糊問題」：
   - **單純工具鏈問題**（型別寫錯、規則違反、斷言邏輯清楚可推導）→ 直接在本 skill 內用最小成本方式驗證：
     - 單獨重跑那一支失敗測試，對照 expected/actual
     - 讀對應 interface/type 定義，縮小到單一表達式確認型別
     - `git log -p` / `git blame` 找出引入該錯誤的 commit
     - 暫時性 log/斷言（驗證完即刪除，不留在最終 diff）
   - **牽涉行為/資料流的模糊問題**（例如測試失敗背後是 race condition、state 被多處修改、API 回傳形狀不如預期、跨元件資料流)→ 先呼叫 `/quick-debug` 對該錯誤做結構化定位（拿到「問題定位摘要」與程式碼引用），再回到本 Step 用其結論收斂假設，不要自己再重新摸索一輪。
3. 假設被推翻 → 修正假設 → 再驗證，最多 2–3 輪。仍無法收斂 → 進入 Step 4，誠實回報。
4. 假設被證實後才進入 Step 5 動手修正。**沒有先驗證就直接改程式碼視為違規**。
5. **同一個可見症狀在修正、驗證通過後，被使用者（尤其是實機/瀏覽器測試）回報「還是重現」**：不要預設是上一輪修法不夠力、只在原本的修法上加碼；先當作「上一輪的假設只涵蓋了這個症狀的其中一個根因，還有其他獨立成因未被觸及」，回到 Step 1 重新收集證據（新一輪的重現條件、log），當作一個新的假設週期處理。同一個症狀因多個獨立根因分好幾輪才修完是真實會發生的情況，不是「修法失敗」的訊號。

### Step 4：證據不足時 —— 誠實回報，請使用者補資訊

觸發時機：根因涉及程式碼看不到的外部狀態，例如：

- 實際 API response 的內容/狀態碼（程式只能看到呼叫端，看不到後端實際回什麼）
- 正式環境或使用者裝置上的 log
- 第三方服務/SDK 的實際行為
- 視覺/CSS 問題需要實際畫面比對
- 需要 runtime 才能重現的 race condition，且本地重跑不出來

規則：

- **不可以**用「改看看、也許這樣就對了」的方式送出未驗證的修改當作正式修法，也不可以連續嘗試多種不相關的改法碰運氣。
- 明確告知使用者：目前證據不足以確認根因，並具體列出需要什麼，例如：
  - 「請提供呼叫 `POST /api/xxx` 時的實際 response body 與 status code」
  - 「請提供出現此問題當下，瀏覽器 console 或 server log 中對應時間點的內容」
  - 「請提供重現此問題時的畫面截圖，以及操作步驟」
- 若使用者仍要求「先猜一個」，可以提供，但必須明確標註為**未驗證的假設性修法**，並說明如何驗證、如何回退。

### Step 5：實作修正（修根因，不修症狀）

- 最小 diff，優先沿用既有 pattern / type / utils，不引入新抽象。
- 各類型原則（反模式清單見 [reference.md](reference.md)）：
  - **ESLint**：修規則指出的實際問題；不預設用 `eslint-disable` 打發，除非規則在此處確實不適用，且需在該行加註解說明原因。
  - **TypeScript**：修型別定義或邏輯本身；避免把 `any` / `as any` / `@ts-ignore` 當成預設解法。
  - **Test**：若測試正確表達預期行為 → 修正產品程式碼；只有在測試本身過時或寫錯時才改測試，且需在總結中說明理由，不要為了讓測試通過而刪減斷言。
  - **Compile/Build**：修設定或程式碼本身；不要用大範圍 ignore/skip 掩蓋問題。

### Step 6：驗證直到全部通過

1. 重跑 Step 1 的原始失敗指令，確認通過。
2. 再跑一次較廣範圍的檢查，確認沒有引入新錯誤或迴歸：
   - 同模組/同檔案的其他測試
   - `npm run lint`（若本次是修 lint/型別/邏輯，順手確認沒新增 lint 錯誤）
   - `tsc --noEmit`（若本次改動涉及型別）
3. 若修正過程中又冒出新錯誤 → 回到 Step 2 重新分類，不要視為「大致修好了」就結束。
4. 檢查本次新增/修改的註解：只在 WHY 非顯而易見時才留，不解釋 WHAT，不引用當下任務/PR/呼叫端，不寫多段落說明；發現明顯贅述就直接精簡。

### Step 7：總結回報

簡短總結：

- 根因是什麼（附證據引用，格式 `startLine:endLine:filepath`）
- 實際改了什麼
- 驗證用的指令與結果
- 是否有需要人工再確認的部分（例如：改了測試而非產品碼時，需說明原因並請人工複核）

完成後可視情況呼叫 `/refactor-scan`，評估這次修正（及前幾次相關改動）是否已達重構門檻——尤其是當根因牽涉的檔案在觀察窗口內已被反覆修改時；不強制執行，只在需要時使用。

**交付（行動端可審閱）**：驗證通過後呼叫 `/change-report` 產出分層變更摘要。若為 Background／Cloud Agent，或使用者要求「開 PR／交付」，再呼叫 `/pr-delivery` 建立 draft PR（禁止直推 `main`／`master`）。本機互動且未要求開 PR 時，只產出報告並可提示「需要的話可呼叫 `/pr-delivery`」，不要自動 commit。

---

## Checklist

- [ ] 已取得完整錯誤訊息（檔案:行號、錯誤碼/規則 ID、diff 或堆疊），而非只憑片段猜測
- [ ] 已正確分類（ESLint / TypeScript / Test / Compile-Build）
- [ ] 根因不明時，已先提出具體假設並用最小成本驗證，而非直接動手改
- [ ] 模糊的行為/資料流問題已先借用 `/quick-debug` 定位
- [ ] 若證據不足，已誠實告知並具體列出需要的資訊（API response / log / 截圖），未包裝未驗證的猜測為確定修法
- [ ] 修正的是根因而非症狀（未濫用 `eslint-disable` / `any` / `@ts-ignore` / 刪測試斷言）
- [ ] 原始失敗指令已重跑並通過；相關範圍已再次確認無新增錯誤/迴歸

---

## Examples

**「這行 ESLint 報 `no-unused-vars`，幫我修一下」**

→ 分類為 ESLint、根因明確（型別 3.a：先假設後實證中屬於「單純工具鏈問題」）；讀該變數用途，若確實未使用則移除，若是解構時故意保留則依專案慣例加底線前綴或行內註解說明；重跑 `npx eslint {file}` 確認通過。

**「這支測試一直失敗，`expect(total).toBe(100)` 但實際是 90」**

→ 分類為 Test；讀測試 setup 與被測函式，提出假設（例如「某筆項目的稅額計算漏加」）；先驗證假設 —— 單獨重跑該測試、在被測函式內暫時 log 中間值確認漏算的是哪一步；假設成立後修正產品程式碼（不是改測試的期望值），重跑至通過。

**「API 回來資料好像少了一個欄位，導致這個 type error」**

→ 分類為 TypeScript，但根因牽涉「API 實際回傳的內容」，程式碼看不到後端真正回什麼；先檢查專案內型別定義與呼叫端程式碼是否一致，若懷疑是後端回傳形狀改變 → 誠實告知使用者：「目前無法從程式碼確認後端實際回傳內容，請提供呼叫 `GET /api/xxx` 的實際 response body」，暫不猜測性修改型別定義。

---

## Additional Resources

- 各類型詳細成因表、反模式清單、指令速查、先假設後實證小抄：見 [reference.md](reference.md)
