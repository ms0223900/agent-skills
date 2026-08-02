---
name: resolve-tracking-dir
description: Resolve 恰好一個 */user-stories/<slug>/ 追蹤目錄（path → token → legacy → scan；多候選時 working tree → git log -n 5）。Reachable by /next-task、/adjust、/doc-trim、/refactor-scan。使用時機：只要選定追蹤目錄、不必找下一任務。
---

# Resolve 追蹤目錄

## 目標

依固定 **ladder** 選定恰好一個追蹤目錄。不評分。

## 執行流程

### Step 1：跑 Resolve ladder

依 [reference.md](reference.md)「一、Resolve ladder」執行（合法判定、token、commit 收斂、token legacy、unfinished 判定全在該節）。

**完成條件**：已選定恰好一個追蹤目錄，或已停下並列出選項／原因。

### Step 2：回報

回報：選定路徑、命中的 ladder 階、若用了 commit／working tree 收斂則說明依據。

---

## Additional Resources

- Ladder、token、文件形態（unfinished／找下一任務共用）、範例：見 [reference.md](reference.md)
