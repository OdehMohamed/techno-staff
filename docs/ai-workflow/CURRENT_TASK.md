# Current Task

## In Progress — v2.0.0 Collections Subsystem

**Branch**: `feat/v2-collections`  
**Status**: 🔄 PR 1 of 7 complete — foundation merged into branch

---

## What's being built

A full financial collections subsystem for field debt collection. Collectors are assigned debts and customers, collect cash in the field, hand cash over to management, and log visit attempts.

See [docs/features/collections_design.md](../features/collections_design.md) for the complete design document.

---

## PR plan (all on `feat/v2-collections`)

| PR | Scope | Status |
|----|-------|--------|
| 1 | Schema foundation, role support, routing/shell, translations, Firestore rules foundation, indexes, stub screens | ✅ DONE |
| 2 | Customer and Debt Management (Admin) | ⏳ Next |
| 3 | Core Financial — Payment Recording and Handover (highest risk; CF unit tests required) | ⏳ Pending |
| 4 | Installment Plans | ⏳ Pending |
| 5 | Visit Logs, PTP, Automation Crons | ⏳ Pending |
| 6 | PDF Receipts, Reports, Admin Dashboard | ⏳ Pending |
| 7 | Collector Experience Polish and Settings | ⏳ Pending |

**Policy**: No release until all 7 PRs are merged and smoke-tested.

---

## PR 1 — What was done

| File | Change |
|------|--------|
| `functions/lib/users.js` | Accept `collector` role; initialize `cashOnHand: 0`, `maxCashOnHand: null` |
| `lib/core/constants/firebase_paths.dart` | 10 new collection path constants |
| `assets/translations/en.json` | 130 new keys (531 total); all subsystem translations upfront |
| `assets/translations/ar.json` | 130 new keys (531 total); translation parity maintained |
| `firestore.indexes.json` | 13 new indexes (customers, debts, payments, handovers, visits) |
| `firestore.rules` | `isCollector()` function + 7 new collection rules (customers, debts, installment_plans, payments, handovers, visits, collection_logs) |
| `lib/core/routes/route_names.dart` | 13 new collector route constants |
| `lib/core/routes/app_router.dart` | `collectorHome` → `CollectorApp`; 12 stub routes |
| `lib/features/splash/…/splash_screen.dart` | `collector` role → `RouteNames.collectorHome` |
| `lib/app/collector_app.dart` | **NEW** — 3-tab shell (Collections / Attendance / Settings) |
| `lib/features/collections/…/collector_home_screen.dart` | **NEW** — stub home screen |
| `pubspec.yaml` | `1.10.0+13` → `2.0.0+14` |

---

## PR 2 — Customer and Debt Management (Admin) — NEXT

### Scope
- `CustomerModel`, `DebtModel`, `InstallmentPlanModel`, `InstallmentModel` data models
- `CustomersRepository`, `DebtsRepository`
- `CustomersCubit` + `DebtsAdminCubit` with state
- Admin screens: Customer List, Customer Form (add/edit), Customer Detail, Debt List, Debt Form (add/edit), Debt Detail
- Assign collector to debt (dropdown of collectors)
- `main.dart` — add new cubits to `MultiBlocProvider`

### Not in PR 2
- Payment recording (PR 3)
- Installment plan creation (PR 4)
- Collector-facing screens (PR 7)

---

## Architecture decisions (collections)

| Decision | Rationale |
|----------|-----------|
| All amounts in agorot (integers) | No floating-point errors for financial data |
| `collector` as new role value | Separate shell, scoped data access, attendance still works |
| `onPaymentCreated` CF handles balance math | Client never writes `paidAmount` or `remainingBalance` |
| FIFO installment allocation | CF applies payments to oldest unpaid installment first |
| `config/counters` for receipt numbers | Atomic Firestore transaction; CF resets per calendar year |
| All translation keys in PR 1 | Subsequent PRs are Dart-only → Shorebird-patchable after v2.0.0 ships |
| Single `feat/v2-collections` branch, 7 PRs | No partial release until the full subsystem is stable |

---

## Quality gates (PR 1)

- [x] `flutter analyze lib/` — zero errors/warnings
- [x] `npm run lint` — ESLint clean
- [x] Translation parity (531 EN == 531 AR)
- [ ] Owner smoke test — app launches, collector account routes to CollectorApp, tabs work
- [ ] Firestore rules deployed and verified — **await owner approval before `firebase deploy --only firestore`**
