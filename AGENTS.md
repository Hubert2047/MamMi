<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **MamMi** (1952 symbols, 4787 relationships, 153 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze` (npm 11 crash → `npm i -g gitnexus`; #1939).

## Always Do

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

## Important business logic notes

- Every new feature or user-facing text must add i18n entries for all supported locales (`vi`, `en`, and `zh-TW`) and render through the i18n helper; do not hardcode UI copy in feature components or pages.
- Confirmation flows must use the project's modal components (such as `AlertDialog`), never `window.confirm`; confirmation modals should use the top-positioned layout used by POS table flows when applicable.

- Expense and revenue reporting defaults to the current open closing period: from the latest non-voided closing `periodEnd` until the current time. If no closing exists, use the store creation time as the start.
- Closing periods are time-based, not calendar-day-based. A store may have multiple closings on the same calendar day, so report filters must preserve date and time and must not reduce timestamps to dates only.
- Expense APIs support explicit `from` and `to` timestamps. Date-time inputs should be converted to ISO timestamps before requests; the end time is inclusive through the requested timestamp.
- Inventory purchases are linked to inventory receipts through `receiptId`; expense display names should be derived from the receipt's ingredient lines when available.
- Order reporting and closing periods must use `paidAt`, not `createdAt`, for paid orders. Unpaid active orders created before the latest closing must remain visible so staff can complete them after the closing.
- Order numbering uses an `OrderCounter` document per `{ storeId, periodId }`. New orders get their `sequence` with an atomic MongoDB `$inc`/upsert; never calculate a new number by querying the latest order, because concurrent POS devices can receive the same number. `periodId` is the latest non-voided closing id, or `open` before the first closing. The legacy `number` field remains for compatibility and mirrors `sequence`; the unique database key is `{ storeId, periodId, sequence }`, so short numbers can restart each period without collisions. Pending orders keep the period/sequence assigned at creation; when they are later paid, accounting still uses `paidAt`. Run `npm run migrate:order-sequence` before deploying this numbering change to remove the old global `{ storeId, number }` unique index and create the period-scoped partial index.
- Cloud backup is decoupled from closing. After a closing succeeds, the backend must enqueue an idempotent `BackupJob` keyed by the closing id; a separate worker/container processes the job, performs the database backup, and records `pending`/`running`/`succeeded`/`failed` state with retry support. Backup failure must never roll back or fail a closing. Do not invoke Docker commands or couple R2/Restic/cloud-provider details into closing logic: the worker must be replaceable or removable without changing core POS accounting behavior. A store can close multiple times per calendar day, so backup requests are per closing, never per date.
