---
name: static-html-host
description: 臨時用 Python http.server +（可選）localtunnel 預覽靜態 HTML；tmux 常駐。使用時機：host HTML、開公開預覽、Cloud Agent 對外 tunnel、關掉預覽 server。不是正式部署。預覽完畢後須請使用者下指令關閉。
---

# 靜態檔臨時 Host（Static HTML Host）

## 目標

在 **Cloud／Background Agent**（或本機）用「靜態檔 + 臨時 tunnel」快速對外預覽 HTML／靜態資源。

| 要做 | 不做 |
|------|------|
| `python3 -m http.server` 本機靜態站 | Nginx／Docker／正式部署／CI preview |
| `npx localtunnel` 公開轉發（可選） | 把 tunnel URL／密碼寫進 repo |
| 兩個 process 各掛 tmux session 常駐 | 改應用程式碼、commit 預覽產物 |
| 回報可實際開啟的 URL（含 loca.lt 密碼） | 假裝這是正式 HTTPS／CDN |

本質：操作流程 skill（會改機器狀態、不改產品碼）。完整指令備忘見同目錄 `reference-commands.md`。

**生命週期**：預設**不會自動關閉**。用完後必須請使用者說「關掉預覽／停 tunnel」，再跑 Step 5；否則會一直跑到環境回收為止（有 tunnel 時等於暴露窗口一直開著）。

---

## 何時使用 / 何時不用

**使用時機**：

- 「幫我 host 這個 HTML」「開公開預覽」「tunnel 給我開」
- Cloud Agent 環境要讓使用者瀏覽器開到靜態頁
- 「關掉 host／停 tunnel／清理預覽」
- 明確只要臨時預覽、不要 Nginx／Docker

**何時不用**：

| 情境 | 改用／做法 |
|------|------------|
| 正式部署、CI preview、Nginx／Docker | 專案既有部署流程 |
| 需要後端 API 或 build 的 app | 先 build，再 host `dist`；或專案 `vite preview` 等 |
| 本機已能直接開檔、且不需對外分享 | 可只開 HTTP server，不必 tunnel |
| 只要看 diff／開 PR | `/change-report`、`/pr-delivery` |

---

## 架構（兩層）

```text
[使用者瀏覽器]
    → https://<subdomain>.loca.lt/<urlencoded-path>
    →（loca.lt 密碼頁：填 agent 出口公網 IP）
    → localtunnel (tmux: static-html-tunnel-<port>)
    → 127.0.0.1:<port>
    → python3 -m http.server (tmux: static-html-server-<port>)
    → document root = <root>（預設＝目標檔所在目錄）
```

Session 前綴：`static-html-server`／`static-html-tunnel`，後綴 `-<port>`（支援並存多個預覽）。**不要**用場景綁死名稱（如 `tw-stock-*`）。

---

## 輸入參數

從使用者訊息解析；缺省如下：

| 參數 | 預設 | 說明 |
|------|------|------|
| `file` | **必填或可自動唯一推得**（見 Step 0） | 入口檔相對／絕對路徑 |
| `root` | **含 `file` 的目錄**（不是整棵 repo） | `http.server` document root |
| `port` | `8080`；佔用則依序試 `8081`…`8090` | HTTP port |
| `bind` | **`127.0.0.1`** | 僅本機；靠 tunnel 對外。僅使用者明確要求時才用 `0.0.0.0` |
| `tunnel` | **依環境判定**（見 Step 0）；判不了就**問使用者**，未答前偏向 `false` | 是否開 public URL |
| `server_session` | `static-html-server-<port>` | tmux session |
| `tunnel_session` | `static-html-tunnel-<port>` | tmux session |
| `timeout_sec` | `45` | 等 tunnel URL／煙測的上限 |

---

## 執行流程

### Step 0：解析參數與環境

**0a. 入口檔 `file`**

1. 使用者有給路徑 → 使用之；不存在則失敗回報。
2. 未給 → 在 **cwd 一層**（不遞迴）找 `*.html`：
   - 恰 1 個 → 採用
   - 僅有／可明確偏好 `index.html` → 可用 `index.html`
   - 多個且無法唯一決定 → **列清單請使用者選**，禁止猜
3. 不遞迴掃整個 repo。

**0b. `root`**

- 預設 = `dirname(file)` 的絕對路徑
- 若使用者堅持更大目錄（如 repo root）→ 允許，但 Step 4 **必須**出安全警告

**0c. `tunnel` 環境判定（依序）**

1. 使用者明確說開／不開 → 遵從
2. 存在 `/exec-daemon/tmux.portal.conf`（或系統提示標明 Cloud／Background Agent）→ 傾向 `true`
3. 否則傾向 `false`
4. 仍不確定 → **問一句**：「需要公開 tunnel 網址嗎？」；未答前不要默認開

**0d. Cloud tmux**

- Cloud／Background：一律 `tmux -f /exec-daemon/tmux.portal.conf …`
- 本機：一般 `tmux` 即可

以下 snipets 中的 `tmux` 在 Cloud 環境皆應加上 `-f /exec-daemon/tmux.portal.conf`。

---

### Step 1：前置檢查

1. 確認 `python3`、`tmux` 可用；若 `tunnel=true`，再確認 `npx` 可用。
2. 確認 `file` 在 `root` 底下（或可解析成相對 root 的 URL path）。
3. Port：用 `ss`／`lsof`／`curl` 檢查；被**非本 skill**佔用 → 換下一個候選 port 並更新 session 名。
4. **Session reuse（強制）**：若 `server_session` 已存在，**不得**無條件 reuse。須同時滿足：
   - pane 內 process 仍在聽目標 `port`
   - document root／工作目錄與本次 `root` 一致（且煙測能讀到目標檔）
   - 否則：`tmux kill-session` 後重建  
   Tunnel session 同理：process 活著且能取得有效 URL；否則重建。

---

### Step 2：起 HTTP server

```bash
SESSION="static-html-server-${PORT}"
tmux has-session -t "=$SESSION" 2>/dev/null || \
  tmux new-session -d -s "$SESSION" -c "$ROOT" -- \
    python3 -m http.server "$PORT" --bind 127.0.0.1
```

**禁止**錯誤寫法：`tmux has-session -d …`（`-d` 不是 `has-session` 旗標）。

煙測（`REL_PATH` = file 相對 root；中文必須 URL-encode）：

```bash
curl -sI "http://127.0.0.1:${PORT}/${REL_PATH_ENCODED}" | head -n1
```

期望 200（或合理 3xx）。非 2xx／3xx → 失敗，不要回報「已可開」。

---

### Step 3：起 localtunnel（僅 `tunnel=true`）

```bash
SESSION="static-html-tunnel-${PORT}"
tmux has-session -t "=$SESSION" 2>/dev/null || \
  tmux new-session -d -s "$SESSION" -- \
    npx --yes localtunnel --port "$PORT"
```

**URL 擷取**：

1. 輪詢（約每 1–2s，上限 `timeout_sec`）：`tmux capture-pane -t "$SESSION" -p -S -100`
2. Regex：`https://[a-z0-9-]+\.loca\.lt`
3. 逾時 → 失敗：kill 本次 tunnel session、附 pane 尾端 log，**不要**回報空 URL
4. Reuse 舊 session 若找不到 URL → 重建（勿捏造舊 URL）

**loca.lt 密碼（必做）**：

```bash
TUNNEL_PASSWORD=$(curl -fsS --max-time 10 https://loca.lt/mytunnelpassword)
```

- 這是 **跑 tunnel 那台機器的出口公網 IP**，不是使用者筆電 IP
- 取不到 → 仍可回報公開 URL，但標 ⚠️「密碼取得失敗，頁面可能打不開」，並附上手動指令

**禁止**只寫「點擊通過即可」——現行 loca.lt 是密碼頁，密碼＝上述 IP。

---

### Step 4：回報使用者（固定格式）

```markdown
### 靜態預覽已啟動

- 入口檔：`<file>`
- Document root：`<root>`
- Bind / Port：`127.0.0.1:<port>`
- 本機 URL：`http://127.0.0.1:<port>/<urlencoded-path>`
- 公開 URL：（若有）`https://<sub>.loca.lt/<urlencoded-path>`
- loca.lt 密碼：（若有 tunnel）`<公網 IP>`
  （到密碼頁時填此 IP；不是你電腦的 IP）
- tmux：`static-html-server-<port>` / `static-html-tunnel-<port>`（若有）
- 性質：臨時預覽，非正式部署

⚠️ 安全：此 root 下檔案經 URL／目錄列舉可能被讀取。勿把含密鑰的目錄當 root。

⚠️ 關閉提醒：預覽**不會自動關閉**。看完後請下指令「關掉預覽」或「停 tunnel」，否則會一直跑到環境結束（有公開 tunnel 時暴露窗口會一直開著）。
```

無 tunnel 時省略公開 URL／密碼兩行，並註明「僅本機可開；Cloud 外網請開 tunnel」。  
**每次成功啟動都必須包含關閉提醒**，不可省略。

---

### Step 5：停止／清理（一等公民）

觸發：「關掉 host」「停 tunnel」「清理預覽」「關掉預覽」。

```bash
tmux kill-session -t "static-html-server-${PORT}" 2>/dev/null || true
tmux kill-session -t "static-html-tunnel-${PORT}" 2>/dev/null || true
```

若不知 port：`tmux ls` 列出 `static-html-*`，確認後再殺；回報已停止的 session。

失敗路徑也應盡量清理「這次新建但未成功對外」的 tunnel session。

停止後回報：

```markdown
### 靜態預覽已停止

- 已結束：`static-html-server-<port>`（／`static-html-tunnel-<port>`）
```

---

## 失敗回報矩陣

| 失敗 | Agent 行為 |
|------|------------|
| 缺 `python3`／`tmux`／（需 tunnel 時）`npx` | 停止；列缺什麼 |
| `file` 歧義 | 列候選；不猜 |
| port `8080`–`8090` 全佔用 | 停止；請使用者指定 port |
| 煙測非 2xx／3xx | 不回報「已可開」；附 curl 結果 |
| tunnel URL 逾時 | 不回報空連結；附 pane 尾端 log |
| 密碼 API 失敗 | URL 可報，但標密碼風險 |
| egress／網路擋 tunnel | 明確說可能限制出站；改只給本機 URL 或請使用者本機開 |

---

## 反模式

- 無條件 reuse 同名 session
- 預設 `root`＝整棵 repo＋`bind 0.0.0.0` 對外
- 只寫「點擊通過」、不回報 IP 密碼
- 多個 HTML 時自動猜一個
- `tmux has-session -d`
- 成功啟動卻省略「用完請關掉」提醒
- 把 Nginx／Docker／正式部署設定混進本 skill
- 把 tunnel URL／密碼 commit 進 repo

---

## Checklist

- [ ] `file`／`root`／`port`／`tunnel` 已解析；歧義已問清
- [ ] session reuse 已驗證 port＋root＋process，或已重建
- [ ] 本機煙測通過
- [ ] 若有 tunnel：已擷取 URL **且**已取得並回報 loca.lt 密碼
- [ ] 已輸出安全警告
- [ ] **已輸出關閉提醒**（預覽完畢請使用者下指令關掉）
- [ ] 未把 tunnel URL／密碼 commit 進 repo
- [ ] 使用者若只要停服：已跑 Step 5

---

## Examples

**「Cloud 幫我 host `台股看盤_盯盤系統_260610.html` 並開公開網址」**

→ Step 0：偵測到 `/exec-daemon/tmux.portal.conf` → `tunnel=true`；`root=dirname(file)`。  
→ Step 2–3：起 server＋tunnel；擷取 loca.lt；`curl https://loca.lt/mytunnelpassword`。  
→ Step 4：本機 URL＋公開 URL＋密碼＋安全警告＋**關閉提醒**。

**「本機只預覽、不對外」**

→ `tunnel=false`；只起 `static-html-server-8080`；只回報 `127.0.0.1`＋關閉提醒。

**「幫我 host」且 cwd 有多個 HTML**

→ 列清單請選；不啟動 server。

**「關掉預覽」**

→ Step 5 kill 對應 `static-html-*` sessions 並回報已停止。

**「再 host 另一個目錄，但 `static-html-server-8080` 還在」**

→ root 不一致 → 不 reuse；kill 後重建（或改用其他 port／session）。
