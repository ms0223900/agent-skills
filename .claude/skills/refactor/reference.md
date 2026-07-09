# Refactor Reference / 重構參考

本文件提供 Feature、Style、Architecture 重構的詳細原則與程式碼範例。SKILL.md 未涵蓋的細節在此補充。

---

## 一、Feature 重構

### 1.1 組件拆分原則

| 情境 | 建議做法 |
|------|----------|
| 單一元件檔超過 500 行 | 識別可獨立區塊，拆成子組件於 `components/` 或同目錄 |
| 模板/JSX 區塊邏輯重複 | 抽出為共用組件，放 `src/components/` 或 `components/` |
| handlers 過多、職責混雜 | 依職責拆成 composable / hook / mixin / 獨立 modules |
| 複雜表單或列表區塊 | 拆成 `*Form`、`*List` 等子組件 |

### 1.2 抽取共用邏輯

**Vue 2 範例（mixin）**

```javascript
// mixins/useGameBet.js
export default {
  methods: {
    validateBetAmount(amount) {
      // 共用驗證邏輯
    }
  }
}
```

**Nuxt 3 範例（composable）**

```typescript
// composables/useGameBet.ts
export function useGameBet() {
  function validateBetAmount(amount: number) {
    // 共用驗證邏輯
  }
  return { validateBetAmount }
}
```

**Next.js 範例（hook）**

```typescript
// hooks/useGameBet.ts
export function useGameBet() {
  function validateBetAmount(amount: number) {
    // 共用驗證邏輯
  }
  return { validateBetAmount }
}
```

### 1.3 Props / Events / Callbacks 規範

- Vue props：JS 用 camelCase，模板用 kebab-case；自訂事件 kebab-case（`@close-window`）
- React/Next：props 用 camelCase；callback props 命名清楚（`onClose`）
- 為 props 撰寫型別、`required`、validator（Vue）或 TypeScript interface 避免誤用

### 1.4 避免常見反模式

| 反模式 | Vue | React/Next |
|--------|-----|------------|
| 條件與列表同元素 | `v-if` + `v-for` 不寫同一元素 → computed 過濾 | 條件與 `.map` 分離 |
| 重複初始化 | `created` 與 `watch` 重複 → `watch` `immediate: true` | 多個 `useEffect` 重複邏輯 → 合併 |
| 模板複雜表達式 | 移至 `computed` / `methods` | 移至變數 / helper |
| 直接改 props | 用 local state 或 `$emit` | 用 local state 或 callback |

---

## 二、Style 重構

### 2.1 變數與 mixin 複用

```scss
// 使用專案既有變數（路徑依專案調整）
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

- Vue：`<style lang="scss" scoped>` 依專案慣例
- React/Next：CSS modules（`*.module.css`）或專案 styled 方案
- Sass 巢狀適度使用，避免選擇器過重、難以維護

---

## 三、Architecture 重構

### 3.1 分層概念（Clean Architecture 精簡版）

```
[View/Component] → [Store Actions / Business Logic] → [API / Data]
```

- **View**：只負責渲染、事件委派，不直接寫複雜運算
- **狀態層**：依棧管理 state 與非同步邏輯
- **API**：透過專案 HTTP client，錯誤集中處理

### 3.2 狀態模組拆分

當單一狀態模組過大時：

1. 依「領域」或「功能」切分子模組（例如 `Game` → `GameBet`、`GameList`、`GameDetail`）
2. 使用命名空間或獨立 store slice 避免命名衝突
3. 子模組間依賴時避免循環依賴

**框架對照**

| 框架 | 拆分方式 | 非同步慣例 |
|------|----------|------------|
| Vuex | `namespaced: true` 子 modules | actions only |
| Pinia | 多個 `defineStore` | store actions |
| Zustand | 多個 `create` slice | async in actions |

### 3.3 依賴方向

- 組件不直接依賴其他組件的內部實作
- 共用邏輯放 store、composable/hook 或獨立 service
- API 層不依賴 UI 框架或狀態庫，保持可獨立測試

### 3.4 效能與資源釋放

- 圖表、第三方 SDK 等：元件卸載時釋放實例、移除 listener
- 大列表：考慮虛擬滾動或分頁，避免一次渲染過多 DOM

---

## 四、Quick Checklist / 快速檢查

| 類別 | 檢查項目 |
|------|----------|
| UI | 列表有穩定 key、props 有型別、條件渲染與遍歷分離、模板/JSX 無複雜表達式 |
| 狀態 | 依棧慣例更新 state、非同步邏輯在正確層級 |
| Style | 作用域正確、變數複用、BEM-like、無 magic numbers |
| 架構 | UI→邏輯→資料、依賴方向正確、模組邊界清晰 |
| 國際化 | 文案用專案 i18n 方案，不硬編碼 |
