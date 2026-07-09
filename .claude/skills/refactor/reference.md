# Refactor Reference / 重構參考

本文件提供 Feature、Style、Architecture 重構的詳細原則與程式碼範例。SKILL.md 未涵蓋的細節在此補充。

---

## 一、Feature 重構

### 1.1 組件拆分原則

| 情境 | 建議做法 |
|------|----------|
| 單一 `.vue` 超過 500 行 | 識別可獨立區塊，拆成子組件於 `components/` 或同目錄 |
| 模板區塊邏輯重複 | 抽出為共用組件，放 `src/components/` |
| methods 過多、職責混雜 | 依職責拆成多個 mixins 或獨立 modules（保持 Vue 2 Options API） |
| 複雜表單或列表區塊 | 拆成 `*Form.vue`、`*List.vue` 等子組件 |

### 1.2 抽取共用邏輯

```javascript
// 若多個組件共用相同邏輯，可用 mixin
// mixins/useGameBet.js
export default {
  methods: {
    validateBetAmount(amount) {
      // 共用驗證邏輯
    }
  }
}
```

### 1.3 Props / Events 規範

- Props：JS 用 camelCase，模板用 kebab-case
- 自訂事件：kebab-case（例如 `@close-window`）
- 為 props 撰寫型別、`required`、`validator` 避免誤用

### 1.4 避免常見反模式

- `v-if` 與 `v-for` 不寫同一元素 → 用 computed 過濾後再遍歷
- `created` 與 `watch` 重複呼叫 → 用 `watch` 的 `immediate: true`
- 模板內複雜表達式 → 移至 `computed` 或 `methods`
- 直接修改 props → 用 `data` 或 `computed` 接收，必要時 `$emit` 通知父層

---

## 二、Style 重構

### 2.1 變數與 mixin 複用

```scss
// 使用專案既有變數
@import '@/assets/sass/theme/mixin.scss';

.my-block {
  color: $main-theme-color;
  padding: $spacing-unit;
}
```

### 2.2 BEM-like 命名

```
Block: .game-card
Element: .game-card__header, .game-card__body
Modifier: .game-card--highlighted
```

避免過度巢狀：`.game-card__header__title` 可簡化為 `.game-card__title`。

### 2.3 顏色與數值

- 顏色：HSL > RGB > 十六進位；避免 `red` 等關鍵字
- 變亮/變暗： prefer `mix(white, $color, %)` / `mix(black, $color, %)`
- 小數：`0.5` 不用 `.5`；`0` 不寫單位

### 2.4 組件樣式

- `<style lang="scss" scoped>` 必須
- Sass 巢狀適度使用，避免選擇器過重、難以維護

---

## 三、Architecture 重構

### 3.1 分層概念（Clean Architecture 精簡版）

```
[View/Component] → [Store Actions / Business Logic] → [API / Data]
```

- **View**：只負責渲染、事件委派，不直接寫複雜運算
- **Store**：state、mutations、actions、getters；非同步只在 actions
- **API**：透過 axios 實例，錯誤集中處理

### 3.2 Vuex 模組拆分

當單一 Vuex 模組過大時：

1. 依「領域」或「功能」切分子模組（例如 `Game` → `GameBet`、`GameList`、`GameDetail`）
2. 使用 `namespaced: true` 避免命名衝突
3. 子模組間依賴時，可用 `rootState`、`rootGetters`，但要避免循環依賴

### 3.3 依賴方向

- 組件不直接依賴其他組件的內部實作
- 共用邏輯放 store 或獨立 service/mixin
- API 層不依賴 Vue 或 Vuex，保持可獨立測試

### 3.4 效能與資源釋放

- ECharts、Papaparse 等：組件銷毀時釋放實例、移除 listener
- 大列表：考慮虛擬滾動或分頁，避免一次渲染過多 DOM

---

## 四、Quick Checklist / 快速檢查

| 類別 | 檢查項目 |
|------|----------|
| Vue | v-for 有 :key、props 有型別、無 v-if+v-for 同元素、模板無複雜表達式 |
| Vuex | 只透過 mutation 更新 state、組件只 dispatch、非同步只放 action |
| Style | scoped、變數複用、BEM-like、無 magic numbers |
| 架構 | UI→邏輯→資料、依賴方向正確、模組邊界清晰 |
| 國際化 | 文案用 `$t('key')`，不硬編碼中英文 |
