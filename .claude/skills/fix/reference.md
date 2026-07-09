# Fix Reference / 修錯參考

本文件提供 ESLint、TypeScript、Test、Compile/Build 四類錯誤的詳細成因、反模式與指令速查。SKILL.md 未涵蓋的細節在此補充。

---

## 一、ESLint

### 1.1 常見規則分類與修法

| 規則類型 | 範例規則 | 建議修法 |
|----------|----------|----------|
| 未使用變數/import | `no-unused-vars`, `unused-imports/no-unused-imports` | 確認是否真的不需要，移除；解構時故意保留的用底線前綴（`_unused`）或依專案慣例 |
| Hook 依賴 | `react-hooks/exhaustive-deps` | 補齊依賴陣列；若確定不需要某個依賴，用 `useCallback`/`useMemo` 穩定該值，而不是直接忽略規則 |
| Import 順序/分組 | `import/order` | 依規則要求的分組排序調整，通常有 `--fix` 可用 |
| 格式類（間距、分號、引號） | `indent`, `quotes`, `semi` | 優先跑 `--fix` 自動修正，不手動逐一調整 |
| 命名慣例 | `vue/component-name-in-template-casing` 等 | 依專案既有命名慣例調整，不改規則設定 |

### 1.2 反模式

- 大量在檔案頂端加 `/* eslint-disable */` 關掉整個規則，而非修正實際問題。
- 為了讓 CI 過而調整 `.eslintrc*`／`eslint.config.*` 全域關閉規則（除非使用者明確要求且有正當理由）。
- 用 `eslint-disable-next-line` 卻沒有註解說明「為什麼這裡規則不適用」。

---

## 二、TypeScript

### 2.1 常見情境

| 情境 | 常見錯誤碼/訊息 | 排查方向 |
|------|----------------|----------|
| 型別不符 | `Type 'X' is not assignable to type 'Y'` | 讀兩邊型別定義，確認是呼叫端傳錯還是型別定義本身過時 |
| 缺 null/undefined 檢查 | `Object is possibly 'undefined'` | 補上 guard（`if`/optional chaining），而非直接用 `!` 斷言忽略 |
| 泛型/overload 不符 | `No overload matches this call` | 逐一比對 overload 簽章與實際傳入的參數型別/數量 |
| 第三方型別缺失 | `Could not find a declaration file for module 'X'` | 檢查是否已裝 `@types/x`；若無官方型別，寫最小必要的 `.d.ts` 補充，而非整個模組用 `any` |
| 型別推導在泛型 callback 中丟失 | 回傳型別變成 `any`/`unknown` | 確認呼叫鏈上每一層的型別標註是否完整 |

### 2.2 反模式

- 用 `any` / `as any` / `@ts-ignore` / `@ts-expect-error`（無說明）當成預設解法，掩蓋而非解決型別問題。
- 用非空斷言 `!` 繞過本來該處理的 null/undefined 情境。
- 修改共用型別定義只為了讓「這一處」過，卻沒檢查是否影響其他使用該型別的地方（若影響範圍大，停下來告知使用者，考慮改用 `/refactor`）。

---

## 三、Test

### 3.1 常見失敗型態

| 型態 | 特徵 | 排查方向 |
|------|------|----------|
| 斷言不符 | `expect(a).toBe(b)` 失敗，數值/內容不對 | 讀被測邏輯，找出實際計算與預期的落差點；先假設是哪一步算錯，寫暫時 log 驗證 |
| Snapshot 過期 | snapshot 檔案 diff | 先確認是「產品行為確實改了、snapshot 該更新」還是「產品出現非預期變化」，不要無條件 `-u` 更新 |
| Mock 設定錯 | mock 回傳值/呼叫次數不對 | 檢查 mock 是否對應到目前呼叫方式（參數、次數、非同步時機） |
| Async timing | 測試偶發失敗、與執行順序有關 | 檢查是否缺 `await`、`waitFor`、假 timer 未 flush |

### 3.2 判斷「改產品碼 vs 改測試」

- **測試正確表達 spec/US 的預期行為** → 修產品程式碼，測試本身不動。
- **測試本身寫錯或已過時**（例如 spec 已變更、mock 資料不符現況）→ 才能改測試，且必須在總結中說明「為什麼這裡是測試錯而非產品錯」，附上依據（US 驗收條件、最新規格等），不能只因為「改測試比較快」就動測試。
- 不確定兩者哪個對時，視為「根因不明」，走 SKILL.md Step 3/4 的假設驗證或誠實回報流程，不要憑感覺二選一。

---

## 四、Compile/Build

### 4.1 常見成因

| 成因 | 特徵 | 排查方向 |
|------|------|----------|
| Module not found | `Cannot find module 'X'` | 確認路徑大小寫、alias 設定（`tsconfig.json` paths / `vite.config` resolve.alias）、套件是否已安裝 |
| 循環依賴 | 建置卡住或執行期出現 `undefined` | 用 `git log`/import 圖找出互相 import 的模組，抽出共用部分打破循環 |
| 設定檔問題 | build 工具吐出 config 相關警告/錯誤 | 檢查 `tsconfig.json`、`webpack.config.*`、`vite.config.*`、`nuxt.config.*`、`next.config.*` 是否有近期異動 |
| 語法錯誤 | Parse error，通常有明確行號 | 直接定位到該行，通常是遺漏括號/逗號或用了目標環境不支援的語法 |

### 4.2 反模式

- 用大範圍 `// @ts-nocheck`、`transpileOnly`、關閉型別檢查等方式讓 build 過，掩蓋潛在錯誤。
- 隨意升降套件版本「試試看能不能過」，而未先確認是版本不相容還是程式碼本身的問題。

---

## 五、先假設，後實證：小抄

| 情境 | 最小成本驗證方式 |
|------|------------------|
| 不確定哪個 commit 引入錯誤 | `git log -p -- {file}` 或 `git bisect`（範圍明確時） |
| 不確定某個中間值 | 暫時加 `console.log`/`debugger`，驗證後刪除，不留在最終 diff |
| 不確定是型別定義還是呼叫端問題 | 縮小到最小可重現的單一表達式，分別檢查兩邊型別 |
| 不確定測試失敗是產品碼還是測試本身 | 單獨重跑該測試並輸出實際值，對照 US/spec 的預期行為，而非只看斷言字面 |
| 懷疑是 race condition | 檢查是否缺 `await`／有無並發呼叫；必要時加入延遲或斷點式驗證，而非直接改邏輯碰運氣 |

---

## 六、誠實回報用語範本

當證據不足以確認根因時，具體列出需要的佐證，而非籠統地說「需要更多資訊」：

- 「請提供呼叫 `{METHOD} {path}` 時的實際 response body 與 HTTP status code。」
- 「請提供出現此問題當下，瀏覽器 console／server log 中 `{時間點或關鍵字}` 附近的內容。」
- 「請提供重現此問題時的畫面截圖，以及完整操作步驟（從哪個頁面、點了什麼）。」
- 「請提供目前使用的環境變數/建置模式（例如 `.env.*`、`--mode` 為何），懷疑是環境設定差異導致。」

若使用者要求「先猜一個」，回覆格式：

> 「以下是**未驗證的假設性修法**：{說明改了什麼、假設是什麼}。驗證方式：{如何確認假設成立}。若不成立可直接回退（{回退方式}）。」
