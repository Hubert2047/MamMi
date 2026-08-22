<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **MamMi** (1048 symbols, 2407 relationships, 76 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze` (npm 11 crash → `npm i -g gitnexus`; #1939).

## Always Do

- **MUST prefer existing shadcn/ui components over native HTML controls when an equivalent component is available.** Add or compose a shadcn/ui component before introducing a native control for UI interactions.
- **MUST use the app's primary color for active states.** This includes active tabs, selected navigation items, checked active/selling controls, and other selected UI states; do not use a neutral gray or default background for active states.
- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows. For regression review, compare against the default branch: `detect_changes({scope: "compare", base_ref: "main"})`.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `query({search_query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `context({name: "symbolName"})`.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method without first running `impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit changes without running `detect_changes()` to check affected scope.

## Financial and Multi-store Rules

- Every operational record must be scoped by `storeId`. The server derives it from the authenticated session/token; never trust a client-supplied store scope.
- Daily closing is continuous **per store**: the next closing period starts at that store's latest confirmed closing `periodEnd`. Do not use a global or calendar-day boundary.
- A confirmed closing locks financial records in that store and period. Voiding the latest confirmed closing reopens only its own period; historical corrections must be represented by an auditable adjustment, cancellation, or void flow.
- Orders are financial snapshots. Persist product/addon names and prices on the order, compute totals on the server, and do not recalculate historical orders from the current catalog.
- Any change to store scoping, orders, payments, financial-period locking, or daily-closing logic MUST include automated tests for the happy path, cross-store isolation, period boundaries, and rejected concurrent/stale updates where applicable.

## Product Availability Rules

- Store product availability is split into `permanentlyActive` and `temporarilyUnavailable`; do not reintroduce a shared `active` field for store products.
- `permanentlyActive` can be changed only by Admin or SuperAdmin. `temporarilyUnavailable` can be changed by any authenticated store user.
- Temporary unavailability expires at the next 00:00 in the store timezone. The backend is authoritative and must enforce the expiry; the frontend must not implement this rule alone.
- POS must expose only temporary availability controls. Admin views must expose both permanent and temporary controls.
- Availability is store-scoped. A product is sellable only when it is permanently active and not temporarily unavailable.
- Store addons follow the same two-state availability model as products. `StoreAddon.permanentlyActive` is Admin/SuperAdmin-only; `StoreAddon.temporarilyUnavailable` is available to authenticated POS users and expires at the next store midnight.
- POS temporary-availability UI has separate Product and Add-on tabs. Admin store pricing UI exposes both permanent and temporary addon controls; temporary control is hidden when the addon is permanently inactive.
- POS temporary-availability lists must still display permanently inactive products/addons for visibility, but their temporary-availability controls are disabled and cannot be changed by staff. The main POS menu may continue hiding them from sale.
- POS main menu must keep permanently active but temporarily unavailable products visible and disabled, with a short localized paused label; permanently inactive products remain hidden from sale.
- If a selected product or addon becomes temporarily unavailable while a POS draft line is being edited, keep the selection visible, show a localized warning, allow the user to remove it, and disable the confirm/add/update action until the invalid selection is removed. Do not silently delete the selection.
- Order creation and checkout of pending orders must revalidate both store-product and store-addon availability server-side; frontend realtime state is only an optimization and never the authority.
- POS checkout must display only active store discounts. If the currently selected discount becomes inactive after a realtime refresh, clear it from the draft order before continuing.
- `getItems?available=true` must exclude addons that are permanently inactive or temporarily unavailable; management/POS availability views may load permanently active but temporarily unavailable addons so they can be shown disabled. Order creation must revalidate selected addon availability server-side to prevent stale POS clients from placing unavailable addons.

## Realtime Rules

- Database writes are the source of truth. Emit realtime events only after a successful store-scoped write.
- Realtime is separated by `storeId` and business channel. The backend owns these rooms: `store:{storeId}:catalog`, `store:{storeId}:orders`, and `store:{storeId}:closing`.
- `catalog` contains shared catalog changes and store-specific price/availability changes. `orders` contains order creation, status, cancellation, and payment changes. `closing` contains confirmed/voided closing changes.
- A client declares its type during socket authentication: `pos`, `admin`, `customer`, or `order`. POS receives catalog and orders; Admin/SuperAdmin receives catalog, orders, and closing; customer web receives catalog only; an order-view client receives only catalog plus its explicitly authorized order room.
- Store switching must leave every room for the old store before joining rooms for the new store. The server revalidates store access on every switch; never trust only the store id sent by the browser.
- Event names are domain-specific: `catalog.item.updated`, `catalog.store-item.price.updated`, `catalog.store-item.availability.updated`, `catalog.store-addon.updated`, `catalog.store-addon.availability.updated`, `catalog.discount.updated`, `catalog.changed`, `order.created`, `order.updated`, `order.cancelled`, `order.payment.updated`, `closing.created`, and `closing.voided`.
- Every event must be emitted only after persistence succeeds. Event payloads contain `storeId`, identifiers, changed fields, and timestamps/version when available; they do not replace API responses or contain unfiltered sensitive records.
- Order-specific updates may additionally be emitted to `order:{orderId}`. Joining that room requires server-side verification that the order belongs to the active store. Public QR ordering must use a short-lived order-scoped credential before this room is exposed to unauthenticated users.
- Frontends subscribe only to events required by their client type and invalidate/refetch the matching React Query keys: catalog events invalidate `items`/`store-items`, order events invalidate `orders`, and closing events invalidate `daily-closing-history`/`daily-closing-summary`. Reconnects remain safe because API refetch is authoritative.
- Webhooks follow the same pipeline as UI actions: authenticate/verify provider signature, normalize the payload, validate store ownership, persist in a transaction/idempotent operation, then emit the appropriate channel event. Never emit directly from an unverified webhook.
- Realtime tests must cover channel-to-event mapping, client subscription permissions, cross-store room isolation, order-room ownership checks, event emission only after successful writes, and frontend query invalidation by client type.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/MamMi/context` | Codebase overview, check index freshness |
| `gitnexus://repo/MamMi/clusters` | All functional areas |
| `gitnexus://repo/MamMi/processes` | All execution flows |
| `gitnexus://repo/MamMi/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
