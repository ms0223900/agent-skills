# Next Package Reference

本檔在 `/next-package` 對應步驟被要求載入時才讀。走訪與完成判定一律引用 [resolve-tracking-dir/reference.md](../resolve-tracking-dir/reference.md)，此處只補「怎麼把連續可動工任務切成一包」。

---

## 一、切包

### 1.1 種子與生長

1. 用 `/next-task` Step 2 同一套規則，取出第一件**依賴已滿足**的未完成任務，當種子。
2. 沿同一走訪順序看「再下一件未完成且前置會被（已完成 ∪ 本包已納入）滿足」的任務。
3. 該件通過下方「必須／建議同包」且未命中「禁止／切斷」→ 納入，繼續。
4. 命中第一個切斷點 → 停止生長。切斷點本身**不**納入。

種子取不到（全卡住或需 PO／PM 簽核）→ 與 `/next-task` 一樣回報並停止，不切包。

### 1.2 必須同包

- Test-First **測試準備 + 對應實作**（拆開會留下預期紅燈）
- 硬依賴：少做一件，分支會停在半成品／無法驗收
- 會改同一批檔、拆成兩張 PR 必衝突的任務

### 1.3 建議同包

- README 驅動型的**同一 Phase**
- 同一垂直切片（同一畫面／API／store；從標題、「相關功能」、路徑線索判斷）
- 連續、各自很小、合在一起才像一個可審 increment

### 1.4 禁止同包

- 不同追蹤目錄或不同 ticket
- P0 順便塞無關的 P1／P2（含註明可後補者）
- `[⚠️]`／`[❌]` 且註明 PO／PM／Release 簽核
- 跨模組新行為又夾無關重構，會讓 PR 無法審

### 1.5 切斷點（預設保守）

命中即停（該件不進本包）：

- 換 Phase
- 換模組／頁面（與種子無共用檔或共用切片）
- 下一件是可後補 P1／P2
- 下一件被依賴卡住，且前置不在本包、也尚未完成
- 再納入會明顯難審（種子以外又跨一層關注點）

### 1.6 包長啟發式

預設目標 **2–5** 件。這不是硬上限。

| 結果 | 動作 |
|---|---|
| 1 件 | 整包就是那 1 件；仍走分支 → 確認 → draft → 一圈 `/next-task` |
| 2–5 件 | 正常出示 |
| 超過 5 件 | 可以；**必須**在確認閘門寫超額理由（例如：Test-First 成對無法拆、同一 Phase 的硬依賴鏈、拆開會留下紅燈或半成品） |
| 種子後沒有相關件 | 不適合同包；建議單次 `/next-task`，停止 |

「為何同包」至少對應 1.2／1.3 的一條。「切斷理由」至少對應 1.5 的一條（整包恰為目錄剩餘必要項且無切斷點 → 寫「無切斷：剩餘必要項皆同切片」）。

---

## 二、分支

| 狀態 | 動作 |
|---|---|
| Cloud／Background，目前 `main`／`master`（或專案禁止直推的主幹） | `/new-branch-cloud-agent`；`<descriptive-name>` 取自 ticket 或整包切片（如 `sprd-1336-phase0`） |
| 已在本包對應的 `cursor/…` 或 `feature/{TICKET}` | 沿用；不要重開 |
| Cloud，目前 `cursor/…` 但主題／舊 PR 對不上本包 | 從主幹另開 |
| 本機，目前主幹 | 停止；請使用者手動 `/new-branch-feature {JIRA}` |
| 本機，已在對應 `feature/{TICKET}` | 沿用 |
| 工作區髒且會擋 `checkout` | stash 或請示；不丟未備份變更 |
| 同分支已有 PR | 沿用那張（Step 4 更新 body）。PR 主題明顯不是本包 → 當「對不上」另開分支 |

確認前只做本表的**決策**（寫進出示內容）。確認後才 `checkout -b` 或呼叫 `/new-branch-cloud-agent`。不要在迴圈裡臨場換分支。

---

## 三、Draft 先於迴圈

確認之後、第一圈 `/next-task` **之前**必須已有本包 draft PR。

### 3.1 讓分支推得出去

相對 base 沒有 commit 時，GitHub／多數平台無法開 PR。此時：

```bash
git commit --allow-empty -m "chore: start package <US-001, US-002, …>"
```

已有超前 commit → 不要再空 commit。

### 3.2 呼叫 `/pr-delivery`（scaffold）

告知 `/pr-delivery` 這是 **scaffold**：

- 允許尚無已驗證實作
- 不跑／不要求完整 `/change-report`
- 標題從整包目的濃縮（有 ticket 則前綴）
- Body 用下方骨架（可再套專案 PR 模板外層）
- `draft: true`；同分支已有 PR → `update_pr`，把整包清單寫進去
- 已有 PR 且已是 ready for review → 只更新 body，不要把它改回 draft

scaffold 失敗（無 URL）→ `/next-package` 停止，不進迴圈。

### 3.3 Scaffold body 骨架

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

每圈 `/next-task` 閉環後：push（若有新 commit），更新同一張 PR 的包內任務勾選與短狀態（PASS／PREPARED／PARTIAL／FAIL）。包尾（Step 6）才跑完整 `/change-report` + 一般模式 `/pr-delivery`。

---

## 四、迴圈

### 4.1 誰擁有什麼

| 層 | 責任 |
|---|---|
| `/next-task` | 一件：選定 → 分派 → close-loop → **停住** |
| `/next-package` | 是否再呼叫 `/next-task`、是否中止、同一張 PR |

呼叫 `/next-task` 時註明：本回合由 `/next-package` 編排、draft 已開；close-loop **不要**呼叫 `/pr-delivery`。

### 4.2 中止（命中即停迴圈）

| 條件 | 動作 |
|---|---|
| 下一件可動工**不在**鎖定整包內 | 視為包尾；進 Step 6（不是失敗） |
| `/next-task` 因依賴全卡住而停 | 中止；更新 PR；回報 |
| 需 PO／PM 簽核 | 中止；回報待確認項 |
| 驗收 FAIL | 中止；回報；PR 標明失敗件 |
| 驗收 PARTIAL，且包內下一件依賴它 | 中止 |
| 驗收 PARTIAL，且包內下一件不依賴它 | 記下，繼續 |
| Test-First PREPARED，且對應實作在本包 | 繼續 |
| `/fix` 暫停轉達 | 中止 |
| 使用者叫停 | 中止 |

中止後**不要**做包外 US。PREPARED 後就中止 → 回報必須寫「PR 上仍是預期紅燈」。

### 4.3 包尾

鎖定清單裡每一件都已閉環（PASS／PREPARED 且無後續實作在包內／或已中止）→ Step 6。目錄仍有包外未完成項是正常的，不叫 epic 收尾。

---

## 五、範例

### 5.1 同 Phase 切一包（SPRD-1336-PHASE2）

追蹤目錄 `docs/user-stories/SPRD-1336-PHASE2/`，Checklist 全未勾。走訪第一件是 Phase 0 的 P0-A，其後 P0-B、P0-C 同 Phase、建議同包。Phase 1 是切斷點。

→ 整包 = Phase 0 的連續 P0；切斷理由 = 換 Phase。若 Phase 0 超過 5 件且皆為硬依賴鏈 → 可整包，超額理由寫「同一 Phase 硬依賴，拆會半成品」。

確認 → 空 commit（若需要）→ scaffold draft → 依序 `/next-task`（P0-A 再 P0-B…）→ 包尾更新同一張 PR。

### 5.2 Test-First 成對

第一件可動工是「US-003 測試準備」，下一件是依賴它的「US-003 實作」。

→ 必須同包。只做測試就停會留下預期紅燈。

### 5.3 不適合同包

種子是「購物車折抵」，下一件是另一頁的「會員頭像」、無共用檔、無依賴。

→ 回報不適合同包，建議 `/next-task`。不要為了湊 2 件硬包。

### 5.4 本機在主幹

Step 2 只寫計畫「請手動 `/new-branch-feature SPRD-1336`」，Step 3 仍出示整包。使用者確認後若仍在主幹 → Step 4 停止。切好分支回來（或同則確認＋已在 `feature/…`）→ Step 4 開 draft，再迴圈。
