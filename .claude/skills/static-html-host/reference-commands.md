# static-html-host — 指令備忘

供 `/static-html-host` 執行時對照；以 `SKILL.md` 規則為準。

Cloud／Background Agent 請在所有 `tmux` 前加：

```bash
tmux -f /exec-daemon/tmux.portal.conf …
```

---

## 變數

```bash
PORT=8080
ROOT="/path/to/dir"          # 預設＝入口檔所在目錄
REL_PATH_ENCODED="..."       # 相對 root；中文需 URL-encode
SERVER_SESSION="static-html-server-${PORT}"
TUNNEL_SESSION="static-html-tunnel-${PORT}"
```

---

## HTTP server

```bash
tmux has-session -t "=$SERVER_SESSION" 2>/dev/null || \
  tmux new-session -d -s "$SERVER_SESSION" -c "$ROOT" -- \
    python3 -m http.server "$PORT" --bind 127.0.0.1

curl -sI "http://127.0.0.1:${PORT}/${REL_PATH_ENCODED}" | head -n1
```

---

## localtunnel

```bash
tmux has-session -t "=$TUNNEL_SESSION" 2>/dev/null || \
  tmux new-session -d -s "$TUNNEL_SESSION" -- \
    npx --yes localtunnel --port "$PORT"

# 輪詢擷取 URL
tmux capture-pane -t "$TUNNEL_SESSION" -p -S -100
# 期望匹配：https://[a-z0-9-]+\.loca\.lt

# loca.lt 密碼＝跑 tunnel 機器的出口公網 IP
curl -fsS --max-time 10 https://loca.lt/mytunnelpassword
```

---

## 停止

```bash
tmux kill-session -t "$SERVER_SESSION" 2>/dev/null || true
tmux kill-session -t "$TUNNEL_SESSION" 2>/dev/null || true

# 不知 port 時
tmux ls | grep static-html || true
```

---

## 中文路徑 encode（示例）

```bash
python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "台股看盤.html"
```
