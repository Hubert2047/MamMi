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
