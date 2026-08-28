<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **MamMi** (3651 symbols, 8440 relationships, 222 execution flows).

> Index stale? Run `node .gitnexus/run.cjs analyze --index-only` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? Bootstrap with `npx`, `bunx`, or `pnpm dlx` — e.g. `bunx gitnexus@latest analyze` (npm 11 npx crash; #1939).

## Always Do

- **MUST run impact analysis before editing.** Use `impact({target: "symbolName", direction: "upstream"})` (MCP) or `node .gitnexus/run.cjs impact "symbolName" --direction upstream --repo .` (CLI fallback); report callers, processes, and risk. Never substitute grep for graph analysis.
- **MUST analyze graph changes before committing.** Use `detect_changes({scope: "all"})` (MCP) or `node .gitnexus/run.cjs detect-changes --scope all --repo .` (CLI fallback). `partial: true` or `truncated: true` is not a clean check — a zero means unseen, not unaffected; re-run it. For regression review: `detect_changes({scope: "compare", base_ref: "main"})` or `node .gitnexus/run.cjs detect-changes --scope compare --base-ref "main" --repo .`.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- **MUST treat `risk: UNKNOWN` as unresolved, not as low.** An empty caller set is not evidence the symbol is unused — it can also mean the callers are not resolvable by the index (plain-object property access, dynamic dispatch, cross-language calls). `impact` pairs `UNKNOWN` with a `riskNote` saying so. Confirm with a text search before treating the symbol as safe to change or delete; do not proceed on the strength of a zero.
- When exploring unfamiliar code, use `query({search_query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `context({name: "symbolName"})`.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method before MCP/CLI impact analysis.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis, and never read `UNKNOWN` as an all-clear — it means the walk could not answer, which is the one verdict that requires confirming by other means.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit before MCP/CLI graph change analysis.

## Resources

| Resource | Use for |
| --- | --- |
| `gitnexus://repo/MamMi/context` | Codebase overview, check index freshness |
| `gitnexus://repo/MamMi/clusters` | All functional areas |
| `gitnexus://repo/MamMi/processes` | All execution flows |
| `gitnexus://repo/MamMi/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
| --- | --- |
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->

## Important business logic notes

### Promotion and discount pricing

- Treat a promotion as either `automatic` (the backend applies it when eligible) or `manual` (a staff member explicitly selects it). The frontend may preview a result but the backend is the authority and must recalculate it when an order is created, updated, or paid.
- SuperAdmin owns the shared promotion definition and its rules. A store only receives a store-promotion configuration and may enable/disable an assigned promotion; it must not mutate the shared rules, targets, amount, or priority.
- A promotion can target `order`, `product`, `addon`, or `line`. `product` discounts only the product base price, `addon` discounts only the matching add-on, `line` discounts the product plus its add-ons, and `order` discounts the post-item subtotal.
- An order item represents one identical configuration of product, variant, add-ons, and note. Differing configuration creates a separate item. Each add-on occurs at most once in an item and applies to every unit in `item.quantity`; therefore add-on price and add-on discount are multiplied by `item.quantity`.
- Evaluate eligibility from the original gross subtotal before discounts. Resolve conflicts first: promotions in the same `exclusiveGroup` choose the highest `priority` (then the larger discount if tied); promotions are non-combinable by default. Apply product/add-on/line promotions first, then order promotions in priority order. A fixed discount must never exceed its target's remaining price.
- Within every accepted promotion and across accepted promotions, pricing order is strict: start from product and add-on gross price; apply all `product` rules to matching product remainders; then all `addon` rules to matching add-on remainders; then `line` rules to each matching line remainder; finally apply the one possible `order` rule to the entire post-item remainder. A `line` reward allocates to product remainder first and only then to its add-on remainders. An `order` reward likewise allocates product remainders first, then add-on remainders. Never reverse these stages or calculate an order reward from the original subtotal.
- Store an immutable applied-promotion snapshot on the order (promotion id, version, localized name, target, discount amount, and per-item/per-addon allocation). Historical orders, receipts, reporting, refunds, and closings must never be recomputed from a later-edited promotion.
- POS must send its latest `expectedPricing` (`total` plus applied promotion id/version/discount amount) when it creates or updates an order. The backend recalculates pricing independently and must return `409 PROMOTION_PRICE_CHANGED` instead of accepting a stale or altered client snapshot. QR/public confirmation remains server-calculated and does not trust a client price.
- POS checkout must always show the original price, every discount, total discount, and amount due. The compact payment view shows amount due; a button opens a full-screen details modal for the item-level breakdown. All user-facing copy must use `vi`, `en`, and `zh-TW` i18n entries.
- Catalog category cards may project only unconditional, currently valid, automatic `product` rules and must show original price → projected product price. They must never include add-on, line, whole-order, manual, or `minSubtotal`-dependent rewards because those are not guaranteed from the card alone. After staff opens a product configuration, add-ons display their own unconditional automatic `addon` reward; line/order rewards remain in the order/checkout allocation breakdown. This same surface rule applies in every sales channel UI.
- Public QR and online menus must receive those projected `displayPrice` values from the backend; never send automatic promotion rules to a public client or recalculate campaign rules in the browser. The browser may add these already-projected product/add-on prices for an immediate catalogue subtotal, but it must request the server quote when the cart/details view opens to show all automatic `line`/`order` rewards.
- Debounce public-cart quotes (about 300 ms) and cache a quote only for the exact cart-line payload until the server-provided expiry (currently 60 seconds). Before public confirmation, persist the current cart lines, then let the backend rebuild the menu, validate every selected option/add-on, and recalculate the final price. Confirmation returns that server total for the success view.
- A fixed combo is one sellable item with a fixed price and no configurable add-ons. Its component products are for kitchen/inventory only. Promotions targeting a component do not automatically apply to its combo; a combo must be explicitly targeted.

#### Creating promotion rules

- A `Promotion` has shared metadata (`names`, `mode`, `status`, validity window, `priority`, `combinable`, `exclusiveGroup`, optional `minSubtotal`) and one or more `rules`. A rule is `{ target, productIds?, addonIds?, reward: { type, amount } }`.
- A promotion is available only when `status === 'active'`, `startsAt <= now` when set, and `endsAt >= now` when set. `endsAt` is inclusive at the stored instant. Once `now > endsAt`, transition the persisted status from `active` to `expired` idempotently before every promotion list, preview, public-menu, and pricing path; it must never be merely hidden in the UI.
- `target: 'order'` reduces the complete order after product/add-on/line rules. It must not have `productIds` or `addonIds`. Use `minSubtotal` for campaigns such as “spend 500, get 50 off”.
- A promotion may contain at most one `order` rule. Automatic promotions containing an `order` rule share the implicit `automatic-order` exclusive group, so only the highest-priority eligible one applies. Many manual promotions may contain an order rule, but staff may select only one manual promotion per order.
- `target: 'product'` reduces only `basePrice × quantity` on matching product ids. `target: 'addon'` reduces only matching add-ons. `target: 'line'` reduces the product and its add-ons together. For product/line rules, `productIds` narrows the eligible order items; for addon rules, `addonIds` narrows eligible add-ons. An omitted target-id list means every eligible product/add-on for that target.
- `reward.type: 'percent'` is applied to the remaining target price. `reward.type: 'value'` is a fixed amount per configured product/add-on unit for product/add-on/line rules and once per order for order rules. Clamp every reward at the remaining target price; never create a negative payable amount.
- Multiple rules in the same promotion are intentional: e.g. one promotion may contain `{ target: 'addon', addonIds: ['boba'], reward: { type: 'value', amount: 10 } }` and `{ target: 'addon', addonIds: ['pudding'], reward: { type: 'value', amount: 15 } }`.
- Example automatic whole-order promotion: `mode: 'automatic'`, `minSubtotal: 500`, `rules: [{ target: 'order', reward: { type: 'value', amount: 50 } }]`. Example staff-selected product promotion: `mode: 'manual'`, `rules: [{ target: 'product', productIds: ['<itemId>'], reward: { type: 'percent', amount: 10 } }]`.
- SuperAdmin assigns a promotion to stores by creating `StorePromotion` records. Store Admin may only set `enabled`; changing rules, the amount, targets, status, priority, or store assignment is SuperAdmin-only.
- Use `exclusiveGroup` when only one campaign in a family can win (for example `order-discount`). Set `combinable: false` by default. If campaigns are allowed to stack, process all item-target rules before order-target rules and preserve the applied result in the order snapshot.

#### POS promotion preview parity

- The POS preview in `fe/src/api/promotion.ts` (`calculatePromotionPreview`) must mirror the authoritative Backend calculation in `be/src/utils/promotionCalculations.ts` (`calculatePromotionPricing`): eligibility, `minSubtotal`, priority, exclusive groups, promotion ordering, reward clamping, and product/add-on/line/order allocation must stay equivalent.
- The POS preview is for responsive display only. Backend pricing remains authoritative and must recalculate at order create/update/payment, validate `expectedPricing`, and reject stale client pricing with `409 PROMOTION_PRICE_CHANGED`.
- Any promotion-pricing logic change must update and run both `be/src/utils/promotionCalculations.test.ts` and `fe/src/api/promotion.test.ts`. Add matching parity cases on both sides, especially for whole-order allocations and `AppliedPromotion.targets`.
- When changing the applied-promotion snapshot, update the Backend order model, Backend pricing type, Frontend API type, and both test suites together. Historical orders must remain readable when optional fields are absent.

- Every new feature or user-facing text must add i18n entries for all supported locales (`vi`, `en`, and `zh-TW`) and render through the i18n helper; do not hardcode UI copy in feature components or pages.
- Confirmation flows must use the project's modal components (such as `AlertDialog`), never `window.confirm`; confirmation modals should use the top-positioned layout used by POS table flows when applicable.

- Expense and revenue reporting defaults to the current open closing period: from the latest non-voided closing `periodEnd` until the current time. If no closing exists, use the store creation time as the start.
- Closing periods are time-based, not calendar-day-based. A store may have multiple closings on the same calendar day, so report filters must preserve date and time and must not reduce timestamps to dates only.
- Expense APIs support explicit `from` and `to` timestamps. Date-time inputs should be converted to ISO timestamps before requests; the end time is inclusive through the requested timestamp.
- Inventory purchases are linked to inventory receipts through `receiptId`; expense display names should be derived from the receipt's ingredient lines when available.
- Order reporting and closing periods must use `paidAt`, not `createdAt`, for paid orders. Unpaid active orders created before the latest closing must remain visible so staff can complete them after the closing.
- Order numbering uses an `OrderCounter` document per `{ storeId, periodId }`. New orders get their `sequence` with an atomic MongoDB `$inc`/upsert; never calculate a new number by querying the latest order, because concurrent POS devices can receive the same number. `periodId` is the latest non-voided closing id, or `open` before the first closing. The legacy `number` field remains for compatibility and mirrors `sequence`; the unique database key is `{ storeId, periodId, sequence }`, so short numbers can restart each period without collisions. Pending orders keep the period/sequence assigned at creation; when they are later paid, accounting still uses `paidAt`. Run `npm run migrate:order-sequence` before deploying this numbering change to remove the old global `{ storeId, number }` unique index and create the period-scoped partial index.
- Cloud backup is decoupled from closing. After a closing succeeds, the backend must enqueue an idempotent `BackupJob` keyed by the closing id; a separate worker/container processes the job, performs the database backup, and records `pending`/`running`/`succeeded`/`failed` state with retry support. Backup failure must never roll back or fail a closing. Do not invoke Docker commands or couple R2/Restic/cloud-provider details into closing logic: the worker must be replaceable or removable without changing core POS accounting behavior. A store can close multiple times per calendar day, so backup requests are per closing, never per date.
