# 驗收說明範例

## 輸入（US 原始內容片段）

```markdown
#### 驗收條件
- [x] 當輸入金額 < `BetMin` 時，自動修正為 `BetMin` 並顯示提示
- [x] 當輸入金額 > `BetMax` 時，自動修正為最大上限並顯示提示
- [ ] 輸入框失焦或即時變化時應執行校驗邏輯
- [x] 文案應正確使用 i18n 配置
```

---

## 輸出（更新 US 的「驗收條件」與「驗收說明」）

```markdown
#### 驗收條件
- [x] 當輸入金額 < `BetMin` 時，自動修正為 `BetMin` 並顯示提示
- [x] 當輸入金額 > `BetMax` 時，自動修正為最大上限並顯示提示
- [⚠️] 輸入框失焦或即時變化時應執行校驗邏輯
- [x] 文案應正確使用 i18n 配置

#### 驗收說明

**整體結論**：PARTIAL ⚠️

> AC-1、AC-2、AC-4 已確認實作；AC-3 涉及即時觸發與 debounce 時序，屬於靜態分析難以完全驗證的範圍，因此標記為需人工確認。

---

**AC-1：當輸入金額 < `BetMin` 時，自動修正為 `BetMin` 並顯示提示**

狀態：✅ 通過

- `src/components/BetViewList.vue` 的 `minMaxJudge(cartData)` 在 `cartData.betAmount < cartData.BetMin` 時，將金額修正為 `cartData.BetMin`，並設 `cartData.isShowMinText = true`
- `src/components/QuickBetPanel.vue` 的 `created()` 也有相同的下限修正邏輯，確保快下注入口一致
- 以上兩處邏輯都直接對應「低於最小金額時自動修正」的行為要求

---

**AC-2：當輸入金額 > `BetMax` 時，依就低原則修正**

狀態：✅ 通過

- `src/utils/lib.js` 的 `BetMaxLimit(BetMax, BetMaxEvt)` 回傳兩者較小值作為實際上限
- `src/components/QuickBetPanel.vue` 使用 `this.$lib.BetMaxLimit(...)` 計算 `realBetMax` 並修正超額金額
- 這代表超出上限時，實際採用的是可用上限的就低值，而不是單純顯示錯誤

---

**AC-3：輸入框失焦或即時變化時應執行校驗**

狀態：🔍 需人工確認

- `src/components/ListCardItem.vue` 的輸入框有 `@input` 與 `@blur` 事件綁定，會觸發 `inputRowItemChangeHandler` 與 `betAmountBlur`
- `src/components/ListCardItem.vue` 的校驗邏輯分散在事件處理與延遲呼叫中，僅靠靜態閱讀難以完全確認觸發順序
- **需人工確認**：建議於瀏覽器實際操作時檢查 debounce 與失焦事件是否皆能按預期觸發

---

**AC-4：文案應正確使用 i18n 配置**

狀態：✅ 通過

- `src/components/BetViewList.vue` 與 `src/components/QuickBetPanel.vue` 的提示文案皆使用 `$t('Common.BetMinTip')` / `$t('Common.BetMaxTip')`，無硬編碼文字
- 文案來源可直接追溯到 i18n 鍵值，符合「顯示層只取字典、不硬編碼」的要求

---

**後續建議**

- AC-3 的 debounce 觸發時機需透過人工操作確認，建議補充 E2E 測試案例以減少回歸風險
- 若後續 AC 涉及更多入口，建議在範例中補一條「多入口交叉驗證」的寫法，避免只驗證單一元件
```
