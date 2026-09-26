# 呼叫端搜尋（Caller Search）

把任何 production 符號（export、函式、方法、action、元件、檔案）列入「連帶可刪」之前，逐節完成本檔的搜尋。Vue／Nuxt／Next 有大量靠慣例、字串或整包匯入接起來的呼叫，單一 grep 零命中不代表沒人用。

**預設保守**：任一節無法排除，這個符號就判「待查」。只有每一節都查過、都能排除，才判「可刪」。

範圍一律是**整個 repo**，含隱藏檔（`rg --hidden`，才搜得到 `.storybook/`、`.github/`、`.eslintrc.*`），只排除 `node_modules`、建置輸出、coverage。目錄位置以 `nuxt.config` 的 `srcDir`、`dir` 等設定為準，不只看預設目錄名。

## 1. 名稱形式

搜尋以下每一種寫法：

- 識別字原名、PascalCase、kebab-case（`<my-comp>`、`'my-comp'`）、檔名去副檔名。
- 相對路徑、alias 路徑（`@/…`、`~/…`、`#…`）、目錄匯入（`@/lib` 解析到 `lib/index`）。
- 轉出或匯入時改過的名字：`export { a as b }`、`import { b as c }` 之後，改追 `b`、`c`。

## 2. 字串引用

- Vuex：`dispatch`／`commit` 的 `'module/name'`，`mapActions`／`mapGetters`／`mapState`／`mapMutations` 的陣列或物件，`rootGetters['…']`、`store.getters['…']`。
- 事件名（`$emit('x')`、`@x`、`v-on:x`）、路由 `name`、`provide`／`inject` key、`<component :is="'x'">`、`resolveComponent('x')`、render function 的字串 tag。

## 3. 字串組名與動態解析

先在整個 repo 找出以下寫法，再判斷它們**能不能指到**目標符號：

| 寫法 | 例子 |
|---|---|
| 字串組名的成員存取 | `` this[`format${type}`]() ``、`this['format' + type]()`、`obj[key]()`、`window[fnName]`、`this.$refs[name]`、`this.$options.methods[n]` |
| 以字串或路徑取值再呼叫 | `_.invoke(this, name)`、`_.get(obj, path)()`、`Reflect.get(obj, key)` |
| 組名的 store 呼叫 | `` dispatch(`bet/fetch${type}Odds`) ``、`commit(name)`、`store.getters[key]` |
| 批次載入 | `require.context`、`import.meta.glob`、`import.meta.webpackContext`、`` import(`./x/${name}`) `` |
| 查表註冊 | `components[name]`、`Object.keys(x).forEach(k => Vue.component(k, x[k]))` |
| 動態元件 | `` <component :is="`Icon${type}`"> ``、`:is="name"`、`resolveComponent(name)` |

判定：

- **能指到** → 無法排除。符合任一條就算能指到：
  - 組名字串的任何靜態片段對得上目標名稱（`format` + 變數對得上 `formatLegacy`；`` `bet/fetch${type}Odds` `` 對得上 `bet/fetchLegacyOdds`）。
  - 批次載入的目錄或 glob 涵蓋目標檔案。
  - key 完全動態（`this[name]`、`obj[key]`），而目標符號就在那個物件上。寫在 mixin 裡的 `this[...]`，比對對象是**所有混入它的元件**實際擁有的方法，含全域 mixin。
- **指不到** → 這條寫法不影響判定。例如 glob 只涵蓋 `store/modules/*`，而目標在 `utils/`。
- 判斷不出指不指得到，就視為能指到。

## 4. 整包使用的模組

以下寫法讓模組內**所有** export 都可能被用到，名稱不會出現在呼叫端：

- `import * as mod from '…'`，之後用 `mod[k]`、`{ ...mod }`、`Object.keys/values/entries(mod)`。
- `export * from '…'`。
- `methods: { ...utils }`、`Object.assign(target, mod)`、`Object.assign(window, mod)`。

目標所在模組被這樣使用 → 無法排除。例外：整包只用於迴圈全域註冊（`Object.keys(filters).forEach(k => Vue.filter(k, filters[k]))`、元件同理）時，改搜註冊後的使用名稱（filter 的 `| name`、`$options.filters`；元件的 PascalCase／kebab-case 名），全部零命中才可排除。

app 內的 barrel 以 `export { x } from './x'` 具名轉出時不算整包使用：改追 barrel 的 importer 有沒有用到 `x`（或改名後的名字），對那些檔案重跑 1–4 節。barrel 用的是 `export *` → 屬於整包使用。

## 5. 框架慣例入口

### 5a. 一律無法排除

由網址、框架執行期或外部設定直接呼叫，repo 裡不會有 import：

- **Nuxt 2**：`pages/`、`layouts/`、`middleware/`、`plugins/`、`store/`（自動變成 Vuex module）、`static/`；`nuxt.config.*` 裡引用的 `plugins`、`modules`、`serverMiddleware`、`router.extendRoutes`。
- **Nuxt 3／4**：`app.vue`、`error.vue`、`app.config.*`、`app/router.options.*`、`pages/`、`layouts/`、`middleware/`、`plugins/`、`modules/`、`server/`（`server/utils/` 除外，見 5b）；專案本身是 layer、會被其他專案 `extends` 時，整個專案都算。
- **Next.js**：慣例檔的**所有 export** 都算入口。慣例檔包括：
  - 根目錄或 `src/` 的 `middleware.*`（Next 16 起為 `proxy.*`）、`instrumentation.*`、`instrumentation-client.*`、`mdx-components.*`。
  - `app/` 下的 `page`、`layout`、`template`、`loading`、`error`、`global-error`、`not-found`、`global-not-found`、`forbidden`、`unauthorized`、`default`、`route`，以及 metadata 檔（`sitemap`、`robots`、`manifest`、`icon`、`apple-icon`、`opengraph-image`、`twitter-image`）。
  - `pages/` 下每個檔案（含 `_app`、`_document`、`api/`）。
  - 以上清單依當時的框架版本會有新增；檔名看起來像框架慣例、而這份清單沒列時，視為慣例檔。
- **全域元件目錄**：Nuxt 3／4 的 `components/global/`、`*.global.vue`，以及 `components` 設定裡 `global: true` 的目錄（Nuxt 2 同）。這些元件能被字串組名解析，不適用 5b。
- **全域註冊與注入**：Vue 2 的 `Vue.component`／`Vue.directive`／`Vue.filter`、`Vue.prototype.$x`；Vue 3 的 `app.component`／`app.directive`／`app.provide`、`app.config.globalProperties.$x`；plugin 注入的 `this.$x`。（迴圈註冊的例外見第 4 節。）
- **其他**：微前端入口的生命週期 export（qiankun 的 `bootstrap`／`mount`／`unmount` 等）、Module Federation 的 `exposes`、`package.json` 的 `main`／`module`／`exports`／`bin` 指向的檔案與它轉出的符號、webpack／vite 中**指向單一檔案**的 `alias`、`ProvidePlugin`。

### 5b. 自動註冊與自動匯入：補充搜尋全部零命中才可排除

這些目錄的符號不會被 import，但也不能被動態存取，所以可以證明沒人用：

| 來源 | 目錄 | 補充搜尋 |
|---|---|---|
| 元件自動註冊 | Nuxt 2（`components: true`）與 Nuxt 3／4 的 `components/`、`components.dirs` 自訂目錄、`unplugin-vue-components` | 註冊後的名稱：預設帶目錄前綴（`components/bet/LegacyCard.vue` → `BetLegacyCard`、`bet-legacy-card`），重複的段會合併（`components/base/BaseButton.vue` → `BaseButton`），`prefix`／`pathPrefix: false` 設定會改變名稱——三種都拿不準時連同檔名本身都搜；另搜 `Lazy` 前綴名、`resolveComponent('…')`、`#components` |
| 自動匯入 | Nuxt 3／4 的 `composables/`、`utils/`、`shared/`、`server/utils/`、`imports.dirs` 自訂目錄、Pinia `stores/`（或 `storesDirs`）、`unplugin-auto-import` | 在 `.vue`（template 與 script）、`.ts`、`.tsx`、`.js`、`.jsx`、`.mjs`、`.cjs` 裡搜裸名稱；`from '#imports'`；`nuxt.config` 的 `imports.presets` |

補充搜尋全部零命中，且 1–4 節也都能排除 → 可排除。任一命中 → 無法排除。

### 5c. mixin 與 `extends`

mixin 或 `extends` 提供的方法：先找出所有混入它的元件（含 `Vue.mixin` 全域混入），在那些元件的 template、methods、computed 裡重跑 1–3 節。找不齊混入者 → 無法排除。

## 6. 測試端引用

列出所有引用目標檔案的測試端位置：`import`、`jest.mock('…')`／`vi.mock('…')` 的路徑、`__mocks__/` 同名檔、`jest.config` 的 `moduleNameMapper` 項目。這一節不影響可不可刪，但決定清理範圍：

- import 目標符號的每一支測試，都必須在同一批裡被刪除或改寫成不再依賴它；有任何一支不在這批，目標符號改判「待查」。
- 判「可刪」時，在 Step 4 清掉測試端對該符號的引用：整個檔案被刪才移除 `jest.mock`／`vi.mock`、`__mocks__/` 同名檔與 `moduleNameMapper` 項目；檔案還留著時只移除 mock 裡該符號的部分。相關測試在 Step 5 全部跑過。

## 判定與紀錄

- **可刪**：1–5 節都能排除。在證據表逐節各寫一行「查了什麼、命中幾處」；第 3 節有命中時，逐一寫出為什麼指不到。附上實際跑過的搜尋指令與第 6 節清單。
- **待查**：任一節無法排除。寫明是哪一節、哪一行命中。這個符號**連同以「它是死碼」為理由的那支測試**都不動：程式碼留著，那支測試可能是它唯一的守護。
