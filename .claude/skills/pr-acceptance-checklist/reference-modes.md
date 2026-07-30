# PR Acceptance Checklist — 模式輸出模板參考

本文件收錄兩種模式（`for-review`／`for-pr-body`）的完整輸出模板與範例。產出 Step 4 的最終輸出前，依選定模式讀取對應章節。

---

## 一、`for-review` 完整輸出模板

目標：**產出一份可以直接貼在 review comment（或 PR 討論）的「可勾選驗收清單」。** 此模式面向**審閱者**，預設不要塞進 PR 描述的最上方（會排擠 30 秒摘要）；若要附在 PR，建議當 comment 或摺疊區塊。

```markdown
### PR / MR Acceptance Checklist

- **Scope & Files**
  - [ ] 變更檔案皆落在預期模組範圍內（無明顯超出 scope 的修改）。
  - [ ] docs/spec（若有）已與實作一致更新。

- **User Story Alignment**
  - **US-XXX / Story A** – [短描述]
    - [ ] 對應的 UI / template 變更存在且合理。
    - [ ] 對應的事件處理 / methods 已更新或移除。
    - [ ] 對應的 API 呼叫 / wrapper 已更新或移除。
  - **US-YYY / Story B** – [短描述]
    - [ ] ...

- **API & Data Flow**
  - [ ] 所有與此功能相關的 API wrapper（`src/api/**/*`）都有對應的使用方更新。
  - [ ] 不再使用的 API wrapper 已被移除，且無殘留呼叫點。

- **UI / Layout / Styling**
  - [ ] 受影響區塊的 DOM 結構與 class 命名符合專案慣例。
  - [ ] 關鍵區塊（例如投注項目）在 PC / Mobile 下皆不會跑版（字過長時能正常換行或截斷）。
  - [ ] 不再使用的樣式（class / keyframes 等）已清理。

- **Regression & Side Effects**
  - [ ] 舊有核心流程（例如下注、登入、開關購物車）未被非必要改動。
  - [ ] 若有版本號 / config 更新，其值與本次 release 計畫對齊。

- **Tests & Verification (to be run manually/CI)**
  - [ ] 基本 lint / 單元測試 / E2E（若有）通過。
  - [ ] 根據 user stories 的 AC，已在測試環境手動驗證關鍵情境。
```

實際輸出時，請：

- **用專案實際 story 編號與簡述替換 `US-XXX` / `Story A`**。
- 將已由靜態分析「幾乎可以確定已滿足」的項目，附上說明（例如「從 `ListCardItem` 元件的 diff 可見按鈕 DOM 與事件皆已刪除」）。

### `for-review` 完整範例（基於 SPRD-662 的通用化示意）

以下是一個基於「移除某功能及相關 API / UI / 排版調整」的通用化示例（實際使用時請改成當次 PR 的實際名稱與內容）：

```markdown
### PR / MR Acceptance Checklist (Example)

- **Scope & Files**
  - [x] 變更集中在購物車相關 component（`ListCardItem` / `.scss`）、對應 API (`api/game.js`) 與相關 view (`OddsHistory`)、版本號設定 (`config/index.js`)。
  - [x] 無修改到與購物車無關的其它頁面或服務。

- **User Story Alignment**
  - **US-001 – 移除某功能按鈕**
    - [x] 按鈕 DOM 與點擊區域已從 template 中刪除。
    - [x] 按鈕專用樣式（class、keyframes 等）已從樣式檔中移除。
  - **US-002 – 移除點擊事件與彈窗邏輯**
    - [x] 對應的 `@click` 綁定與 methods 已從 component 中移除。
    - [x] 不再需要的 helper import 已刪除。
  - **US-003 – 移除相關 API 呼叫**
    - [x] API wrapper 已從 `api` 模組移除。
    - [x] 所有對該 API 的呼叫點皆已刪除，程式中不再出現該 API 名稱或 URL。
  - **US-004 – 調整排版**
    - [x] 文字區塊改為允許換行與自動斷行，避免跑版。
    - [x] 關鍵資訊區塊在 PC / Mobile 下皆採用左對齊、間距一致。
  - **US-005 – 回歸測試（購物車核心功能正常）**
    - [ ] 需人工 / 自動化實測：輸入金額、切換單項/過關、確認下注、購物車開關、刪除投注項目。

- **API & Data Flow**
  - [x] 不再使用的水位歷程 API 已停止呼叫。
  - [x] 其它 API（下注、查詢等）未被誤改。

- **UI / Layout / Styling**
  - [x] 相關 SCSS 變更僅影響目標區塊，未波及全局樣式。

- **Regression & Side Effects**
  - [x] 除版本號外無修改 config 中其它行為設定。

- **Tests & Verification**
  - [ ] 在測試環境完成 PC / Mobile 的手動驗證（依 user stories AC）。
```

此示例僅作為風格與結構的參考；實際使用時，請根據當次 PR / MR 的 user stories 與變更內容動態調整勾選項與說明。

---

## 二、`for-pr-body` 精簡輸出模板

目標：**產出可直接嵌進 `/change-report`「驗證結果」「風險與待確認」的短區塊**，方便行動端先掃讀。不要輸出完整 Scope／UI／API 長 checklist。

```markdown
### 驗證方式（對照 US）

- **US-XXX** – {一句：靜態分析結論 ✅／⚠️／❓}；建議驗證：{一句或「已由單元測試覆蓋」}
- **US-YYY** – …

### 超出範圍？

- {無／列出可疑檔案或變更}

### 風險與待確認（精簡）

- {最多 3～5 點；無則寫「無」}
```

約束：

- 每個 US 一行結論，不要展開成多層 checkbox。
- 已跑過的指令（lint／test）用一行帶過，細節留給 change-report 的「驗證結果」。
- 無法從 code 判斷的 AC 標 ❓，並寫「需實測／日誌」。
