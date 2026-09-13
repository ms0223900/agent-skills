# Next Package Reference

本檔在 `/next-package` 對應步驟被要求載入時才讀。走訪與完成判定引用 [resolve-tracking-dir/reference.md](../resolve-tracking-dir/reference.md)；此處只補如何把連續可動工任務切成一個 **package**。

---

## 一、切 package

### 1.1 種子與生長

1. 用 `/next-task` Step 2 同一套規則，取出第一件依賴已滿足的未完成任務當種子。
2. 沿同一走訪順序，看下一件「未完成且前置 ⊆（已完成 ∪ 已入 package）」的候選。
3. 依 1.7 勝負決定入包或停止生長。
4. 種子之後、停止生長之前的每一件候選：入 package，或帶 1.4／1.5 理由。未交代的候選 → 切包未完成。

種子取不到（全卡住或需 PO／PM 簽核）→ 與 `/next-task` 一樣回報並停止。

### 1.2 必須同包

- Test-First 測試準備 + 對應實作
- 硬依賴：少做一件則無法驗收
- 會改同一批檔、拆 PR 會衝突

### 1.3 建議同包（須命中至少一條可檢查訊號）

- 同一 Phase（README 驅動型）
- 同一「相關功能」欄
- US 正文有共用路徑線索（同一目錄／元件名）
- 走訪順序上相鄰

### 1.4 禁止同包

- 不同追蹤目錄或不同 ticket
- `[⚠️]`／`[❌]` 且註明 PO／PM／Release 簽核
- 與種子既無 1.2、也無 1.3 訊號，卻夾無關重構

### 1.5 切斷點

該件不進 package，生長在此停止：

- 換 Phase（1.2 必須者除外，見 1.7）
- 與種子無共用 Phase、「相關功能」、路徑線索
- 可後補 P1／P2
- 前置未完成且不在本 package
- 再納入會使 package 同時跨兩個 1.3 切片（例如換頁又換 API）

### 1.6 包長

目標 **2–5**。

| 結果 | 動作 |
|---|---|
| 1 件 | package 即該件；仍走 gate → scaffold → 一圈 `/next-task` |
| 2–5 件 | 出示 |
| 超過 5 件 | 出示，gate 卡片寫超額理由（1.2 成對無法拆、同一 Phase 硬依賴鏈） |
| 種子後沒有 1.2／1.3 訊號 | 建議 `/next-task` 並停止 |

「為何同包」對應 1.2 或 1.3。「切斷理由」對應 1.5（剩餘必要項皆同一 1.3 切片 → 寫「無切斷：剩餘必要項同切片」）。

### 1.7 勝負

**1.4 禁止 > 1.2 必須 > 1.5 切斷 > 1.3 建議。**

1.2 必須的任務即使命中 1.5（例如 Test-First 成對跨 Phase）仍納入，並在卡片上寫例外／超額理由。

---

## 二、分支

| 狀態 | 動作 |
|---|---|
| Cloud／Background，目前主幹 | 計畫：確認後 `/new-branch-cloud-agent`；名稱取自 ticket 或切片（如 `sprd-1336-phase0`） |
| 已在本 package 對應的 `cursor/…` 或 `feature/{TICKET}` | 沿用 |
| Cloud，目前 `cursor/…` 但主題／舊 PR 對不上 | 計畫：確認後從主幹另開 |
| 本機，目前主幹 | 計畫：請使用者 `/new-branch-feature {JIRA}`；確認後若仍在主幹則停在 Step 4 |
| 本機，已在對應 `feature/{TICKET}` | 沿用 |
| 工作區髒且會擋切換 | stash 或請示 |
| 同分支已有 PR 且主題是本 package | Step 4 更新那張 |
| 同分支已有 PR 但主題對不上 | 當「對不上」另開 |

gate 前只寫本表決策。gate 後才執行開分支。loop 期間維持同一分支。

---

## 三、scaffold

gate 之後、第一圈 `/next-task` 之前，本 package 已有 draft PR URL。

### 3.1 讓分支推得出去

相對 base 沒有 commit 時：

```bash
git commit --allow-empty -m "chore: start package <US-001, US-002, …>"
```

已有超前 commit → 沿用那些 commit。

### 3.2 呼叫 `/pr-delivery`（scaffold）

告知呼叫為 **scaffold**。body 用 3.3。標題從 package 目的濃縮（有 ticket 則前綴）。`draft: true`；同分支已有 PR → `update_pr`。已是 ready for review → 只更新 body，維持 ready。

無 URL → 停在 Step 4。

scaffold 的「跳過 change-report」由 `/pr-delivery` 執行；空 commit 訊息與 body 骨架以本節為準。

### 3.3 Body 骨架

```markdown
## 整包計畫

- **目錄**：
- **為何同包**：
- **切斷理由**：
- **包長**：N（若 N>5：超額理由）
- **狀態**：尚未開始 `/next-task`

## 包內任務

- [ ] {任務 ID}：{標題}
- [ ] …

## 驗證結果

- [ ] 實作尚未開始（scaffold）

## 風險與待確認

- 本 PR 在第一圈 `/next-task` 之前建立；後續同一張 PR 更新。
```

### 3.4 迴圈中更新

每圈閉環後：push（若有新 commit），更新同一張 PR 的包內勾選與短狀態（PASS／PREPARED／PARTIAL／FAIL）。包尾（Step 6）才跑 `/change-report` + 一般模式 `/pr-delivery`。

---

## 四、迴圈

### 4.1 誰擁有什麼

| 層 | 責任 |
|---|---|
| `/next-task` | 一件：選定 → 分派 → close-loop → 停住 |
| `/next-package` | 是否再呼叫 `/next-task`、是否中止、同一張 PR |

呼叫 `/next-task` 時註明：本回合由 `/next-package` 編排、scaffold 已開；交付由編排層呼叫 `/pr-delivery`。

### 4.2 中止（命中即停 loop）

| 條件 | 動作 |
|---|---|
| 下一件可動工不在鎖定 package 內 | 包尾；Step 6 |
| `/next-task` 因依賴全卡住而停 | 中止；更新 PR；回報 |
| 需 PO／PM 簽核 | 中止；回報待確認項 |
| 驗收 FAIL | 中止；回報；PR 標明失敗件 |
| 驗收 PARTIAL，且包內下一件依賴它 | 中止 |
| 驗收 PARTIAL，且包內下一件不依賴它 | 記下，繼續 |
| Test-First PREPARED，且對應實作在本 package | 繼續 |
| `/fix` 暫停轉達 | 中止 |
| 使用者叫停 | 中止 |

中止後只更新本 package 的 PR 與回報。PREPARED 後中止 → 回報寫「PR 上仍是預期紅燈」。

### 4.3 包尾

鎖定清單每一個 ID 都有 close-loop 結論或已命中 4.2 一列 → Step 6。目錄仍有 package 外未完成項 → 維持 package 收尾，不當成 epic 收尾。

---

## 五、範例

### 5.1 同 Phase（SPRD-1336-PHASE2）

`docs/user-stories/SPRD-1336-PHASE2/`，Checklist 未勾。種子是 Phase 0 的 P0-A；P0-B、P0-C 同 Phase（1.3）。Phase 1 命中 1.5。

→ package = Phase 0 連續 P0；切斷理由 = 換 Phase。Phase 0 超過 5 件且皆 1.2 → 整包，超額理由寫「同一 Phase 硬依賴」。

### 5.2 Test-First 成對

種子是「US-003 測試準備」，下一件是依賴它的「US-003 實作」。

→ 1.2 必須同包。即使中間夾 1.5 換 Phase，1.7 仍納入實作。

### 5.3 無 1.3 訊號

種子是「購物車折抵」，下一件是另一頁「會員頭像」，無共用 Phase／相關功能／路徑。

→ 建議 `/next-task`。

### 5.4 本機在主幹

Step 2 計畫「請手動 `/new-branch-feature SPRD-1336`」，Step 3 仍出示卡片。確認後仍在主幹 → Step 4 停止。已在 `feature/…` 回來 → Step 4 做 scaffold，再 loop。
