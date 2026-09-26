# 呼叫端搜尋（Caller Search）

把任何 production 符號（export、函式、方法、action、元件、檔案）列入「連帶可刪」之前，逐節完成本檔的搜尋。Vue／Nuxt／Next 有大量靠慣例、字串或整包匯入接起來的呼叫，單一 grep 零命中不代表沒人用。

**預設保守**：任一節無法排除，這個符號就判「待查」。只有每一節都查過、都能排除，才判「可刪」。

範圍一律是**整個 repo**（排除 `node_modules`、建置輸出、coverage），不限稽核範圍。

## 1. 名稱形式

搜尋以下每一種寫法：識別字原名、PascalCase、kebab-case（`<my-comp>`、`'my-comp'`）、檔名去副檔名、相對路徑與 alias 路徑（`@/…`、`~/…`、`#…`）。

## 2. 字串引用

- Vuex：`dispatch`／`commit` 的 `'module/name'`，`mapActions`／`mapGetters`／`mapState`／`mapMutations` 的陣列或物件，`rootGetters['…']`、`store.getters['…']`。
- 事件名（`$emit('x')`、`@x`、`v-on:x`）、路由 `name`、`provide`／`inject` key、`<component :is="'x'">`、render function 的字串 tag。

## 3. 字串組名與動態解析

先在整個 repo 找出以下寫法，再判斷它們**能不能指到**目標符號：

| 寫法 | 例子 |
|---|---|
| 樣板字串或變數組名的成員存取 | `` this[`format${type}`]() ``、`obj[key]()`、`window[fnName]`、`this.$refs[name]` |
| 組名的 store 呼叫 | `` dispatch(`bet/fetch${type}Odds`) ``、`commit(name)`、`store.getters[key]` |
| 批次載入 | `require.context`、`import.meta.glob`、`import.meta.webpackContext`、`` import(`./x/${name}`) `` |
| 查表註冊 | `components[name]`、`Object.keys(x).forEach(k => Vue.component(k, x[k]))` |

判定：

- **能指到** → 無法排除。符合任一條就算能指到：
  - 樣板字串的靜態片段對得上目標名稱（`` `format${type}` `` 對得上 `formatLegacy`；`` `bet/fetch${type}Odds` `` 對得上 `bet/fetchLegacyOdds`）。
  - 批次載入的目錄或 glob 涵蓋目標檔案。
  - key 完全動態（`this[name]`、`obj[key]`），而目標符號就在那個物件、那個元件或它混入的 mixin 上。
- **指不到** → 這條寫法不影響判定。例如 glob 只涵蓋 `store/modules/*`，而目標在 `utils/`。
- 指不指得到判斷不出來，就視為能指到。

## 4. 整包使用的模組

以下寫法讓模組內**所有** export 都可能被用到，名稱不會出現在呼叫端：

- `import * as mod from '…'`，之後用 `mod[k]`、`{ ...mod }`、`Object.keys/values/entries(mod)`。
- `export * from '…'`。
- `methods: { ...utils }`、`Object.assign(target, mod)`、`Object.assign(window, mod)`。

目標所在模組被這樣使用 → 無法排除。

app 內的 barrel（例如 `utils/index.js` 以 `export { x } from './x'` 具名轉出）不算整包使用：改追 barrel 的 importer 裡有沒有用到 `x`，再對那些檔案重跑 1–4 節。barrel 用的是 `export *` → 屬於整包使用。

## 5. 框架慣例入口

位於下列位置的檔案或符號，由框架按慣例呼叫，repo 裡不會有 import → 一律無法排除。

**Vue 2**
- 全域註冊：`Vue.component`／`Vue.mixin`／`Vue.directive`／`Vue.filter`（含迴圈註冊）。
- `Vue.prototype.$x`、plugin 注入的 `this.$x`。
- mixin 或 `extends` 提供的方法：先找出混入它的元件，在那些元件的 template、methods、computed 裡重跑 1–3 節；找不齊混入者 → 無法排除。

**Nuxt 2**
- `pages/`、`layouts/`、`middleware/`、`plugins/`、`store/`（自動變成 Vuex module）、`static/`。
- `nuxt.config.*` 裡引用的 `plugins`、`modules`、`serverMiddleware`、`router.extendRoutes`。

**Nuxt 3／4**
- `app.vue`、`error.vue`、`app.config.*`、`app/router.options.*`。
- `pages/`、`layouts/`、`middleware/`、`plugins/`、`server/`、`modules/`、`layers/`。
- 自動註冊或自動匯入：`components/`、`composables/`、`utils/`、`shared/`，Pinia 的 `stores/`（或 `storesDirs` 設定的目錄）。
- `nuxt.config.*` 的 `components.dirs`、`imports.dirs` 等設定的自訂目錄（設定裡寫的是 glob，對照目標路徑判斷）。

**Next.js**
- 專案根目錄或 `src/`：`middleware.*`（Next 16 起為 `proxy.*`）、`instrumentation.*`、`instrumentation-client.*`。
- `app/` 下的慣例檔：`page`、`layout`、`template`、`loading`、`error`、`global-error`、`not-found`、`default`、`route`，以及 metadata 檔 `sitemap`、`robots`、`manifest`、`icon`、`apple-icon`、`opengraph-image`、`twitter-image`。
- `pages/` 下每個檔案（含 `_app`、`_document`、`api/`）。
- 慣例檔的特殊 export：`default`、`metadata`、`generateMetadata`、`viewport`、`generateViewport`、`generateStaticParams`、`getStaticProps`、`getStaticPaths`、`getServerSideProps`、`GET`／`POST` 等 HTTP 方法，以及 route segment config（`dynamic`、`revalidate`、`runtime`、`fetchCache`、`preferredRegion`、`maxDuration`）。

**其他**
- 微前端入口的生命週期 export（qiankun 的 `bootstrap`／`mount`／`unmount` 等）、Module Federation 的 `exposes`。
- 套件對外入口：`package.json` 的 `main`／`module`／`exports`／`bin` 指向的檔案，以及它轉出的符號。
- 設定檔引用：webpack／vite 的 `alias`、`ProvidePlugin`、`jest.config` 的 `moduleNameMapper`、Storybook stories。

## 6. 測試端引用

列出所有引用目標檔案的測試端位置：`import`、`jest.mock('…')`／`vi.mock('…')` 的路徑、`__mocks__/` 同名檔、`moduleNameMapper` 項目。這不影響可不可刪；判「可刪」時，這些位置要在 Step 4 一併清掉、在 Step 5 全部跑過。

## 判定與紀錄

- **可刪**：1–5 節都查過且都能排除。在證據表寫下實際跑過的搜尋指令，以及第 6 節的測試端引用清單。
- **待查**：任一節無法排除。寫明是哪一節、哪一行命中。這個符號**連同以「它是死碼」為理由的那支測試**都不動：程式碼留著，那支測試可能是它唯一的守護。
