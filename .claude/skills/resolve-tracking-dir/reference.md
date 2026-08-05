# Resolve Tracking Dir Reference

## 一、Resolve ladder（選定追蹤目錄）

**Resolve**：依固定 **ladder** 選出恰好一個追蹤目錄；命中即停。

### 1.1 路徑契約與合法目錄

追蹤目錄 = `*/user-stories/<slug>/`（例：`docs/user-stories/SPRD-1336/`、`docs/user-stories/career-news/`）。

**合法**：目錄內至少有一個任務檔（`US-*.md`／`P0-*.md`／`TASK-*.md`）。僅有 README、無任務檔 → 不計入合法（避免佔位目錄擋掉 token legacy）。

任務清單與依賴來源：`README.md`（若有）+ 個別任務 `.md`；細節見「二、文件形態判讀」（本檔；`/next-task` 找下一任務亦用此節）。

### 1.2 Ladder（依序）

| 階 | 條件 | 動作 |
|---|---|---|
| 1 | 使用者給了追蹤目錄 path，或某個任務 `.md` 檔路徑 | 該目錄即結果（**強制 override**：即使已收尾也不改找 sibling）；結束 resolve |
| 2 | 使用者給了 ticket key，**或**目前 branch 不是 `main`／`master` | 取 **token**（§1.3）→ 在 `*/user-stories/*/` 用 **case-insensitive** `^{token}(-.+)?$` 收合法目錄。池非空 → §1.4。池空 → §1.6 token legacy；legacy 非空 → §1.4。仍空 → 階 3 |
| 3 | branch 是 `main`／`master`，或階 2 仍無候選 | **Scan** 全部 `*/user-stories/*/` 合法目錄 → §1.4 |

Token 匹配用 `^{token}(-.+)?$`（case-insensitive），不用 `startswith`（`SPRD-133` 會誤命中 `SPRD-1336`）。

### 1.3 Token（僅階 2）

1. 使用者給的 ticket key，或從 branch 擷取 `[A-Za-z]+-[0-9]+`（大小寫皆可；例：`feature/sprd-1336` → `sprd-1336`，比對時與目錄名 case-insensitive）。
2. 否則取 branch **slug**：去掉常見前綴（`feature/`、`cursor/`、`fix/`、`chore/` 等）。**僅當** branch 以 `cursor/` 開頭時，才去掉尾端雲端後綴（`-` + 4～6 位英數，如 `-5ec2`）。其餘小寫保留。

### 1.4 從候選池選定

對**當前池**（階 2 命中、§1.6 legacy、或階 3 scan 的結果）依本檔「二、文件形態判讀」標 unfinished（含被依賴卡住的）。已收尾者不進 unfinished 池。

| 結果 | 動作 |
|---|---|
| 0 個合法，或 0 個 unfinished | 回報找不到／全收尾；建議 `/user-stories`（若完全無追蹤目錄可一併提 `/ticket-to-ai-spec`）；停止 |
| 恰好 1 個 unfinished | 自動選用，並說明原因 |
| ≥2 個 unfinished | 進入 §1.5 |

同 token 多變體（如 `SPRD-1336/` 與 `SPRD-1336-PHASE2/`）各自獨立判完成度，再套本表。

### 1.5 Commit 收斂（僅 ≥2 unfinished）

固定順序取痕跡（路徑限 `*/user-stories/**`；有 token 時 legacy 候選一併看 `docs/specs/**` 對應路徑）：

1. **Working tree**：`git status --porcelain` 與 `git diff --name-only HEAD`（含 staged）中，落在 unfinished 目錄下的路徑。
2. 若仍無法唯一：**最近 5 筆** `git log -n 5 --name-only --pretty=format: -- '**/user-stories/**'`（legacy 池再加對應 `docs/specs/` pathspec）。

合併上述痕跡後：

| 結果 | 動作 |
|---|---|
| 恰好 1 個 unfinished 有痕跡 | 選它；說明「依 working tree／commit」 |
| 0 個或 ≥2 個都有痕跡 | 列出所有 unfinished + 完成度摘要，請使用者指定；停止 |

### 1.6 Token legacy（有 token，且階 2 的 `*/user-stories/*` 無合法命中時）

掃該 token 的舊路徑（match 同樣 case-insensitive `^{token}(-.+)?$`）：

| 路徑 | 用途 |
|---|---|
| `docs/specs/{token}/us/` | 任務目錄 |
| `docs/specs/{token}-user-stories/` | 任務目錄 |
| `docs/specs/{token}-*.md`（排除 `*-issues.md`） | 純規格、無任務顆粒度 → 建議先 `/user-stories`，不進 unfinished 比較 |

有合法任務目錄 → §1.4。無 → 階 3 scan（若尚未 scan）。

---

## 二、文件形態判讀

同一個追蹤目錄只會是以下其中一種形態，先判讀形態再挑演算法。

### 2.1 README 驅動型（有「全域驗收 Checklist」+「依賴鏈摘要」）

範例：`docs/user-stories/SPRD-1336-PHASE2/README.md`。

判斷依據：README 內同時有 `## 全域驗收 Checklist`（或同義標題）與類似 ASCII 依賴圖的區塊（含 `─►`、`├─►`、`└─►` 字元）。

**演算法**：

1. 依文件出現順序列出所有 Phase（`## Phase N — ...` 標題）。
2. 每個 Phase 底下有一張表格，含「順序」欄；依該欄由小到大排序該 Phase 內的任務。
3. 解析「全域驗收 Checklist」：每個 Phase 一個子清單，每行 `- [marker] 任務名稱`；用「三、Checkbox 正規化表」把 marker 轉成 done / not-done。
4. 解析「依賴鏈摘要」ASCII 圖（見「四、依賴圖判讀規則」），建立「任務 → 前置任務清單」的對照。
5. 依 Phase 順序、Phase 內順序欄，逐一走訪任務：
   - 已完成（正規化後為 done）→ 略過。
   - 未完成 → 檢查它的前置任務是否**全部**已完成（依 4. 建立的對照；沒有列在圖上的任務視為無前置，永遠可動工）。全部完成 → 這是候選的「下一個任務」，進入第 6 步 cross-check；否則 → 略過，繼續往下一個任務找。
6. **Cross-check**：打開候選任務自己的檔案，用 `^#{2,4}\s*驗收說明` 找是否已經有驗收說明區塊。
   - 沒有 → 確認為下一個任務，結束演算法。
   - 有 → README 勾選過期，視為已完成，記錄這個落差，回到第 5 步繼續找下一個。
7. 若走訪完所有任務都沒有找到「未完成且前置已滿足」的任務 → 回報「目前無可動工任務」，並列出卡在依賴上的未完成任務清單。

**P0/P1/P2 附註規則**：任務清單旁常有 `P0`／`P1`／`P2` 或「*(P1，可後補)*」這類註記。這**不影響**第 5 步的走訪順序（一律照文件順序 + 順序欄），但會影響「這個目錄整體是否已收尾」的判斷（見 2.3）以及 `/next-task` close-loop 收尾判斷：P1/P2 且註明可後補的項目即使未勾選，也不阻擋「整體已收尾」的結論；只有 P0（或未特別註記、視為必要）項目全勾才算收尾。

Phase 自己的「完成條件」文字（例如「Phase 0 完成條件：...」）通常是「依賴鏈摘要」圖的人類可讀重述，兩者衝突時以 ASCII 依賴圖為準；若完成條件文字提到某些 P1 項目「可與後續 Phase 平行進行」，代表這些項目本來就不會出現在依賴圖中作為後續 Phase 任務的前置，直接照依賴圖判斷即可，不需要另外特別處理。

### 2.2 無 Checklist 型（狀態只存在任務檔案本身）

範例：`docs/user-stories/SOPS-2721/README.md`（只有任務索引 + 文字描述的「依賴：...」，沒有全域 checkbox 清單）。

**演算法**：

1. 依檔名序（`US-001-*.md`、`US-002-*.md`……）列出目錄下所有任務檔案。
2. 對每個檔案，判斷是否「已完成」：檔案內有 `驗收說明` 區塊（heading 層級與措辭不一定，用 `^#{2,4}\s*驗收說明` 判斷）**且**該區塊上方「驗收條件」清單全部是 `[x]`（沒有殘留 `[ ]`、`[⚠️]`、`[❌]`）。若該任務是 Test-First 測試準備任務，這裡的「驗收條件」指的是測試任務自己的完成條件（例如「已建立且確認預期紅燈」），不是後續實作任務才會成立的功能 AC——見 `/next-task` close-loop.md C2 的 AC 區分；測試任務自己的 AC 該打勾就要打勾，否則本演算法會判定它「未完成」而永遠重複選到同一個任務，卡住無法推進到依賴它的實作任務。
3. 由前往後找第一個「未完成」的檔案。
4. 找到候選後，讀該檔案（或 README 對應段落）裡的「依賴」說明，取出被依賴的任務 ID；若任一被依賴任務尚未完成（依 2. 的判斷）→ 略過此候選，繼續往下一個檔案找。
5. 全部檔案都已完成 → 回報整個目錄已收尾。

**檔名序 ≠ 優先序陷阱**：README 常把任務分成「核心（P0）／優化（P1）／選配（P2）」等分組，但檔名數字不一定照優先序排（例如某個檔名數字比其他還小，卻可能被歸在後面的優化分組）。純靠檔名數字序走訪可能造成誤判，因此第 4 步的依賴交叉檢查是必要的、不能省略；有疑義時，以 README 內對每個 US 的分組與文字依賴描述為準，而不是單純比較檔名數字大小。

### 2.3 目錄整體收尾判斷

- README 驅動型：全部 P0（含未特別標 P1/P2、視為必要）任務皆已完成 → 視為收尾（P1/P2 且註明可後補者不計）。
- 無 Checklist 型：全部任務檔案皆已完成 → 視為收尾。

---

## 三、Checkbox 正規化表

| 原始 marker | 正規化 | 備註 |
|---|---|---|
| `[x]`、`[X]` | done | |
| `[x️]`（`x` 後夾帶不可見的 Unicode variation selector，如 U+FE0F） | done | 常見手動編輯留下的殘字，肉眼跟 `[x]` 看起來一樣；實例：`docs/user-stories/SPRD-660/README.md` 的 `US-005` 那行 |
| `[ ]` | not-done | |
| `[❌]` | not-done | 通常代表「已驗收但未通過」，不是「還沒做」，回報時要分清楚這個語意差異 |
| `[⚠️]` | not-done（語意是「部分完成／待人工簽核」） | 若旁邊註記「PO／Release 簽核為準」等字樣，視為需人工決策，見 `/next-task` Step 2 人工決策規則 |
| `[🔍]` | not-done | 代表「需人工確認」，一般只出現在任務檔案自己的驗收條件裡，較少出現在 README 全域 checklist |

判讀時用「去掉方括號內所有非 `x`/`X` 的字元後，是否還剩下 `x`」來判斷 done/not-done，這樣可以同時涵蓋 `[x]`、`[X]`、`[x️]` 等變體，不需要窮舉所有 Unicode 組合。

---

## 四、依賴圖判讀規則（「依賴鏈摘要」ASCII 圖）

這類圖是給人看的 box-drawing 圖，不是嚴格的機器格式，判讀時用「像人一樣看圖」的方式，而不是硬套單一 regex：

- **箭頭方向**：箭頭指向的一端是「下游」（依賴方，要等上游做完才能開始）；箭尾/線段另一端是「上游」（前置）。
- **單行直接對應**：形如 `SOURCE ─────► TARGET` 的整行，可直接用正則 `^(\S+)\s*[─]+►\s*(\S+)` 抓出 `SOURCE`、`TARGET`。
- **一對多**（同一上游、多個下游）：上游名稱單獨一行，接著多行縮排的 `├─►`／`└─►`。例如：
  ```
  US001（FinalGameList）
    ├─► US003（下注 service，需 FinalGameList 形狀穩定）
    └─► US004（OddsSection）
  ```
  代表 US003、US004 都必須等 US001 完成。
- **多對一**（多個上游合併成一個下游）：多個上游各自用 `┬`／`┼`／`┐`／`┤`／`┘` 之類的框線字元匯聚到同一個箭頭。例如：
  ```
  US004 ─┐
  US005 ─┼─► US008（SCSS 拆分，需四個子元件皆就位）
  US006 ─┤
  US007 ─┘
         └─► US009（殼層瘦身與整合驗收，= Epic 完成）
  ```
  代表 US008 需要 US004～US007 全部完成；緊接在同一個匯聚點下面又出現一個 `└─►`，代表同一組上游（實務上還要加上 US008 本身，因為 US009 的描述就是「四個子元件都就位後的殼層驗收」）全部完成才能開始 US009。遇到這種巢狀延伸，以文字註記（此例中「殼層瘦身與整合驗收，= Epic 完成」）確認語意，不要只看框線。
- **條件式依賴**（用括號註明「若不可行」「可選」）：預設**不**當作會阻擋別人的硬依賴，只在對應條件成立時才生效。例如 `US001 ──（若不可行）──► US012` 代表 US012 只有在 US001 這條路線失敗才需要做，正常情況下不會被排進「下一個任務」。
- **沒有出現在圖上的任務**：視為沒有前置依賴，只要它在文件順序上排到，且沒被其他規則擋住，就可以被選為下一個任務。

---

## 五、驗收說明 heading 偵測

用正則 `^#{2,4}\s*驗收說明` 逐行掃描任務檔案，涵蓋 `#### 驗收說明`、`## 驗收說明`、`## 驗收說明（實作備註）`、`## 驗收說明（2025-03-25）` 等實際出現過的變體（標題文字後面可能還有註記，只要開頭符合就算命中）。

---

## 六、Resolve 範例

### 6.1 Feature branch + token（SPRD-1336-PHASE2）

Branch：`feature/SPRD-1336`（或 `feature/sprd-1336`，case-insensitive）→ 階 2，token 命中。

- `docs/user-stories/SPRD-1336/` — 已收尾（P0 全勾，僅 P1 可後補未勾）
- `docs/user-stories/SPRD-1336-PHASE2/` — unfinished
- §1.4：恰好 1 個 unfinished → 選 `SPRD-1336-PHASE2/`

其後找下一個任務：Phase 0 順序 P0-A…；Checklist 全 `[ ]`；P0-A 無前置且無驗收說明 → **P0-A 折疊展開行為測試**（純測試 → `/vue-integration-test`）。下一輪同目錄則輪到 P0-B。

### 6.2 main + scan + commit 收斂

Branch：`main` → 階 3，scan 全部 `*/user-stories/*/`。

- `docs/user-stories/career-news/` — unfinished
- `docs/user-stories/cart-coupon/` — unfinished
- §1.5：先看 working tree；若無唯一痕跡，再看 `git log -n 5`；僅 `career-news/` 有痕跡 → 選它

若兩邊痕跡皆無或皆有 → 列出兩者請使用者指定。

### 6.3 Cloud agent branch、無 ticket key

Branch：`cursor/fix-login-5ec2` → 階 2，無 ticket key → 因 `cursor/` 前綴，剝後綴得 slug `fix-login`。

- 若存在 `docs/user-stories/fix-login/` → §1.4
- 若無 → §1.6 token legacy；仍無 → 階 3 scan

（對照：`feature/tax-form-2024` 非 `cursor/`，**不**剝 `-2024`，token 為 `tax-form-2024`。）

### 6.4 Token 無 user-stories 命中 → legacy 優先於全域 scan

Branch：`feature/SPRD-900`；無 `docs/user-stories/SPRD-900*`；有 `docs/specs/SPRD-900/us/`（unfinished）；另有無關的 `docs/user-stories/career-news/`。

→ 階 2 池空 → §1.6 命中 legacy → §1.4 選 `docs/specs/SPRD-900/us/`（**不**因 career-news 存在而改掃全域）。

---

