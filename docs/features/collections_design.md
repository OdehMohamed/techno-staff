# Collections Subsystem — Complete Design Document

> **Status**: Design approved — pending implementation start  
> **Version target**: v2.0.0  
> **Branch**: `feat/v2-collections`  
> **Last updated**: 2026-06-25  
> **Author**: Design session (owner + Claude Sonnet 4.6)

---

## Table of Contents

1. [Overview and Design Constraints](#1-overview-and-design-constraints)
2. [Entities and Relationships](#2-entities-and-relationships)
3. [Firestore Collections](#3-firestore-collections)
4. [Security Rules Strategy](#4-security-rules-strategy)
5. [Cloud Functions](#5-cloud-functions)
6. [Notifications](#6-notifications)
7. [Reports and PDF Generation](#7-reports-and-pdf-generation)
8. [State Transitions](#8-state-transitions)
9. [PR Implementation Plan](#9-pr-implementation-plan)
10. [Testing Strategy](#10-testing-strategy)
11. [Field Supplement Operating Procedures](#11-field-supplement-operating-procedures)
12. [Open Questions Resolved](#12-open-questions-resolved)

---

## 1. Overview and Design Constraints

### What this is

A dedicated **accounts receivable / field collections** subsystem for tracking customer debts and the money collected from them by field collectors. It is architecturally isolated from the existing task, attendance, and chat features.

### Deployment model: Field Supplement → System of Record

**Phase 1 (v2.0.0)**: The app is a field supplement. The business maintains parallel manual records alongside it. App records are used for day-to-day field operations; the authoritative financial record remains manual. This reduces launch risk — if the app has a bug, the manual record catches it.

**Future promotion**: After 4–6 weeks of production use with no reconciliation gaps, the owner may promote the app to System of Record. This transition requires accountant review of receipt format and confirmation that app records satisfy local tax documentation requirements. This document does not prescribe that transition — it designs for it.

### Non-negotiable financial integrity rules

These apply from the first record written. There are no exceptions.

1. **No payment is ever deleted or edited.** Only cancelled (with mandatory reason) or superseded by a correction payment. Cancellation is a state change, not a deletion.
2. **Debt balances are computed exclusively by Cloud Functions**, never by client writes. The client creates payment documents; the CF updates the debt.
3. **Receipt numbers are sequential, unique per calendar year, and generated atomically by CF.** The client writes `receiptNumber: ''`; the CF fills it. A payment without a receipt number is in a transitional state (CF pending), not a valid payment.
4. **Overpayment is blocked by CF.** A payment whose amount exceeds `debt.remainingBalance` is rejected at the CF level. Debt balance never goes below zero.
5. **Every state change on every entity produces an audit log entry** written by CF to `collection_logs`. The client cannot write to `collection_logs`.
6. **Handover discrepancies are recorded permanently.** There is no "override and confirm anyway" path.
7. **Collector cash on hand is always computable** from `payments` where `collectorId == uid && status == 'pending_handover'`. The denormalized `users/{uid}.cashOnHand` field is a performance cache maintained by CF; the authoritative value is the sum query.

### Key design decisions (locked)

| Decision | Choice | Reason |
|---|---|---|
| Currency | ILS only | No multi-currency in v2.0 |
| Amount storage | **Integers in agorot** (1 ILS = 100 agorot) | Eliminates floating-point rounding errors in financial arithmetic |
| Interest | None | Not in scope |
| Collector role | New `role: 'collector'` value in `users/{uid}` | Clean separation in Firestore rules; simpler mental model |
| Collector visibility | Assigned debts only | Collectors cannot see other collectors' data or unassigned debts |
| Payment cancellation | Admin only | Simplest accounting model; avoids self-cancellation audit gaps |
| GPS tracking | Deferred | Privacy and permission complexity outweigh benefit at current scale |
| Photo evidence | Deferred | Design questions on evidence scope unresolved; add after visit workflow proves itself |
| Settlement workflow | Simplified (v2.0.0) | Admin status change + notes; full workflow UI in follow-up |
| Dispute workflow | Simplified (v2.0.0) | Admin status change + notes; full workflow UI in follow-up |
| Collector performance metrics | Data from day 1; dashboard deferred | Meaningless with zero historical data at launch |

---

## 2. Entities and Relationships

```
Admin
  ├── creates / assigns → Customer (N)
  ├── creates / assigns → Debt (N)
  ├── verifies → Handover (N)
  └── has full read/write on all entities

Collector (User with role: 'collector')
  ├── is assigned → Debt (N) via assignedCollectorId
  ├── records → Payment (N)
  ├── logs → Visit (N)
  └── initiates → Handover (N)

Customer
  └── has → Debt (N)

Debt
  ├── belongs to → Customer (1)
  ├── assigned to → Collector (1, nullable)
  ├── has → Payment (N)
  ├── has at most one → InstallmentPlan (1)
  └── has → Visit (N, indirect via visitId on payment)

InstallmentPlan
  └── has → Installment (N) in sub-collection

Payment
  ├── belongs to → Debt (1)
  ├── recorded by → Collector (collectorId, 1)
  ├── entered by → User (recordedById, 1; may differ from collectorId)
  └── included in → Handover (1, nullable)

Handover
  ├── initiated by → Collector (1)
  ├── verified by → Admin (1, nullable)
  └── includes → Payment (N) via paymentIds[]

Visit
  ├── belongs to → Customer (1)
  ├── optionally linked to → Debt (1)
  ├── logged by → Collector (1)
  └── optionally contains → PromiseToPay (1 embedded)

CollectionLog
  └── references → any entity (polymorphic via entityType + entityId)
```

---

## 3. Firestore Collections

### Amount convention

All monetary amounts are stored as **integers in agorot**. 1 ILS = 100 agorot. The value `₪500.00` is stored as `50000`. Display always divides by 100. Arithmetic is integer arithmetic. No floats anywhere in financial fields.

---

### `/customers/{customerId}`

```
name: string                          // required; 2–100 chars
phone: string                         // required; primary contact
phone2: string?                       // secondary contact (family member, secretary)
address: string?
notes: string?                        // free text; may hold guarantor info in Field Supplement phase
isActive: bool                        // default: true; deactivation does not delete
assignedCollectorId: string?          // default collector for new debts on this customer
assignedCollectorName: string?        // denormalized from users/{uid}.name
createdBy: string                     // admin uid
createdAt: Timestamp
updatedAt: Timestamp

// CF-maintained — updated on every debt/payment event:
totalOutstandingBalance: int          // agorot; sum of remainingBalance for status in [active, partial, overdue]
activeDebtCount: int                  // count of debts with status not in [settled, written_off, cancelled]
accountStatus: string                 // 'good_standing' | 'at_risk' | 'delinquent'
                                      // good_standing: no debt overdue > 30 days
                                      // at_risk: any debt 31–90 days overdue
                                      // delinquent: any debt 90+ days overdue
lastPaymentAt: Timestamp?             // most recent payment.collectedAt across all debts
lastContactAt: Timestamp?             // most recent visit.visitedAt
```

---

### `/debts/{debtId}`

```
customerId: string
customerName: string                  // denormalized; updated if customer name changes
description: string                   // "Invoice #1234", "March delivery", etc.
externalReference: string?            // invoice/order number from external system

// Financial (amounts in agorot):
originalAmount: int                   // immutable after creation
paidAmount: int                       // CF-maintained; sum of non-cancelled payments
remainingBalance: int                 // CF-maintained; originalAmount - paidAmount; never < 0
currency: 'ILS'

// Lifecycle:
status: string
  // 'active'      — created, no payments yet
  // 'partial'     — paidAmount > 0 && remainingBalance > 0
  // 'settled'     — remainingBalance == 0 (terminal)
  // 'overdue'     — dueDate < today && not settled (CF daily cron)
  // 'written_off' — admin formally wrote off remaining balance (terminal)
  // 'disputed'    — customer contests validity (simplified: status + notes)
  // 'cancelled'   — debt void (terminal; see write-off vs cancellation distinction)

dueDate: Timestamp?                   // when full payment is expected; drives overdue detection
assignedCollectorId: string?
assignedCollectorName: string?        // denormalized

// Guarantor (field, not a separate entity in v2.0):
guarantorName: string?
guarantorPhone: string?

// Installment plan reference:
hasInstallmentPlan: bool              // default: false
installmentPlanId: string?            // references /installment_plans/{id}
nextInstallmentDueDate: Timestamp?    // CF-maintained denormalized field; drives cron query

// Write-off (populated when status == 'written_off'):
writeOff: {
  amount: int,                        // agorot; remainingBalance at time of write-off
  reason: string,                     // mandatory
  authorizedBy: string,               // admin uid
  authorizedByName: string,
  at: Timestamp
}?

// Dispute (simplified in v2.0 — status field + this object):
dispute: {
  reason: string,
  raisedBy: string,                   // admin uid
  raisedAt: Timestamp,
  resolution: string?                 // free text when resolved
}?

// Settlement (simplified in v2.0 — recorded when admin settles for less):
// Settlement flow: admin records a payment for the negotiated amount, then
// marks debt as 'settled' with this object. forgivenAmount appears in reports.
settlement: {
  originalBalance: int,               // agorot; remainingBalance at settlement time
  settledAmount: int,                 // agorot; what was actually accepted
  forgivenAmount: int,                // agorot; originalBalance - settledAmount
  reason: string,
  authorizedBy: string,
  at: Timestamp
}?

createdBy: string
createdAt: Timestamp
updatedAt: Timestamp

// CF-maintained aging (updated daily by cron):
daysPastDue: int                      // 0 if dueDate is null or not yet overdue
agingBucket: string                   // 'current' | '1-30' | '31-60' | '61-90' | '90+'

// Notification deduplication:
lastReminderAt: Timestamp?
lastOverdueEscalationAt: Timestamp?
```

**write-off vs. cancellation distinction (important for reporting):**
- `cancelled`: the debt was entered in error, a refund was given, or it is formally voided. The business never expected to collect it. Appears in reports as "cancelled debt" — not a loss.
- `written_off`: the debt was real, collection was attempted, and the business gave up. The remaining balance is a recognized loss. `writeOff.amount` appears as a loss line in reconciliation reports. Requires mandatory reason and admin authorization.

---

### `/installment_plans/{planId}`

```
debtId: string
customerId: string
totalInstallments: int
installmentAmount: int                // agorot; per installment (last installment may differ to account for rounding)
frequency: string                     // 'weekly' | 'biweekly' | 'monthly'
startDate: Timestamp                  // due date of first installment
createdBy: string
createdAt: Timestamp
```

---

### `/installment_plans/{planId}/installments/{n}` (sub-collection)

Document ID is the installment number as a zero-padded string: `'001'`, `'002'`, etc.

```
number: int                           // 1-indexed; matches document ID
dueDate: Timestamp
expectedAmount: int                   // agorot; may differ for last installment
paidAmount: int                       // agorot; CF-maintained; starts at 0
status: string                        // 'pending' | 'partial' | 'paid' | 'overdue'
paymentIds: string[]                  // ordered list of payment IDs applied to this installment (FIFO)
paidAt: Timestamp?                    // when status reached 'paid'
```

**FIFO allocation rule**: When a payment is recorded against a debt with an installment plan, the CF applies the payment amount to installments in ascending order by `number`, starting with the oldest unpaid/partial installment. A single payment may cover multiple installments or leave one partially paid.

---

### `/payments/{paymentId}`

Document ID is a client-generated UUID (enables offline idempotency — retried writes produce the same document, not a duplicate).

```
// Identity:
debtId: string
customerId: string
customerName: string                  // denormalized
installmentPlanId: string?            // if the debt has an installment plan

// Who collected vs. who entered:
collectorId: string                   // the person who physically received the money
collectorName: string                 // denormalized
recordedById: string                  // the person who created this Firestore document
                                      // (equals collectorId when collector records directly;
                                      //  may be an admin uid when admin records on behalf of collector)
recordedByName: string

// Financial (amounts in agorot):
amount: int                           // positive; immutable after creation; validated by CF
paymentMethod: string                 // 'cash' | 'check' | 'bank_transfer'
checkNumber: string?
bankReference: string?

// Timestamps:
collectedAt: Timestamp                // when money changed hands (user-entered; drives financial date)
createdAt: Timestamp                  // Firestore server write time (audit only)

// Receipt (CF-generated):
receiptNumber: string                 // 'RCPT-2026-00001'; empty string '' on client creation;
                                      // filled by CF atomically within onPaymentCreated
                                      // A payment with receiptNumber == '' is in transitional state

// Lifecycle:
status: string                        // 'pending_handover' | 'handed_over' | 'verified' | 'cancelled'
handoverId: string?                   // set when included in a handover

notes: string?

// Cancellation (never delete; only cancel):
isCancelled: bool                     // default: false; admin only
cancellationReason: string?           // required if isCancelled: true
cancelledBy: string?                  // admin uid
cancelledAt: Timestamp?

// Correction chain:
isCorrection: bool                    // default: false
                                      // true if this payment corrects a previous erroneous payment
originalPaymentId: string?            // the payment this corrects (for correction chain)
```

**Offline behaviour**: The client creates the payment document with `receiptNumber: ''`. Firestore queues the write offline. When connectivity is restored, the write syncs and `onPaymentCreated` fires, generating the receipt number. During the offline window, the payment is shown in the UI as "Receipt pending". The collector must not share or print a receipt until `receiptNumber` is populated.

---

### `/handovers/{handoverId}`

```
collectorId: string
collectorName: string                 // denormalized

// Financial (amounts in agorot):
claimedAmount: int                    // sum of included payments.amount; computed client-side
actualAmount: int?                    // what admin physically counts; filled at verification

paymentIds: string[]                  // payment document IDs included in this handover
                                      // max practical size: ~100 payments per handover

// Lifecycle:
status: string                        // 'pending_verification' | 'verified' | 'discrepancy'
initiatedAt: Timestamp

// Verification (admin fills these):
verifiedAt: Timestamp?
receivedBy: string?                   // admin uid
receivedByName: string?

// Discrepancy (populated when status == 'discrepancy'):
discrepancyAmount: int?               // agorot; positive = extra received; negative = shortage
discrepancyNotes: string?             // mandatory when discrepancy is recorded

notes: string?
```

**Discrepancy resolution**: A handover in `discrepancy` state is permanently recorded. Resolution happens through operational process (admin debrief, collector explanation), not by editing the handover document. If the discrepancy is a timing issue (payment not yet synced), the admin creates a new handover or adjusts through a separate process. This ensures the discrepancy record is never retroactively hidden.

**Cannot cancel a verified payment**: A payment with `status == 'verified'` that is part of a `verified` handover must not be cancellable by the admin without explicit escalation. The UI should warn: "This payment was verified in handover HHHH. Cancellation will create an accounting discrepancy. Contact management."

---

### `/visits/{visitId}`

```
customerId: string
debtId: string?                       // optional; general customer contact or debt-specific
collectorId: string
visitedAt: Timestamp                  // when the contact occurred (user-entered)
createdAt: Timestamp                  // Firestore write time

contactType: string                   // 'in_person' | 'phone'

outcome: string
  // 'payment_collected'    — payment was made; link paymentId
  // 'partial_payment'      — partial payment; link paymentId
  // 'promise_to_pay'       — customer committed to a future date; fill promiseToPay
  // 'customer_unavailable' — visited location; customer not present
  // 'refused'              — customer present but refuses to pay
  // 'no_answer'            — phone call; no answer
  // 'wrong_contact'        — reached someone other than the customer

paymentId: string?                    // linked payment when outcome is payment_collected or partial_payment

// Promise to Pay (embedded; only when outcome == 'promise_to_pay'):
promiseToPay: {
  amount: int,                        // agorot; what customer promised
  promisedDate: Timestamp,            // calendar day promised (time is irrelevant)
  status: string                      // 'pending' | 'kept' | 'broken'
                                      // CF daily cron updates 'pending' → 'broken'
                                      // onPaymentCreated CF updates 'pending' → 'kept'
                                      //   when a payment exists on or before promisedDate
}?

notes: string?
```

---

### `/collection_logs/{logId}`

Server-written only. Firestore rule: `allow write: if false`.

```
entityType: string                    // 'customer' | 'debt' | 'payment' | 'handover' | 'visit'
entityId: string
action: string                        // see Action Catalog below
actorId: string
actorName: string
timestamp: Timestamp

// Context (nullable; populated depending on action):
customerId: string?
debtId: string?
collectorId: string?
amount: int?                          // agorot
receiptNumber: string?
notes: string?
before: map?                          // snapshot of key fields before the change
after: map?                           // snapshot of key fields after the change
```

**Action Catalog** (complete list — every CF that writes a log must use one of these):

```
customer.created
customer.updated
customer.deactivated
customer.reactivated

debt.created
debt.assigned              // first assignment to a collector
debt.reassigned            // changed from one collector to another
debt.status_changed        // any status transition
debt.written_off
debt.cancelled
debt.disputed
debt.dispute_resolved
debt.settled               // settle-for-less workflow

payment.recorded           // payment created by collector or admin on behalf
payment.receipt_assigned   // CF filled the receiptNumber (may fire separately from payment.recorded)
payment.cancelled          // admin cancelled payment; includes before/after balance
payment.correction_created // a correcting payment was created linking to this one

handover.initiated
handover.verified
handover.discrepancy_noted

visit.logged
ptp.created
ptp.kept                   // CF marked PTP as kept when payment arrived on time
ptp.broken                 // CF daily cron marked PTP as broken
```

---

### `/config/counters` (single document, ID: `counters`)

```
// allow read: if isAdmin(); allow write: if false (CF only)
receipts: {
  year: int,                          // current calendar year; CF resets lastNumber when year changes
  lastNumber: int,                    // last assigned receipt number in current year
  prefix: string                      // 'RCPT' (change here if business requires different format)
}
```

**Receipt number format**: `RCPT-{year}-{number zero-padded to 5 digits}`  
Examples: `RCPT-2026-00001`, `RCPT-2026-00042`, `RCPT-2027-00001` (year reset)  
Gaps in the sequence are acceptable (cancelled payments leave gaps). Reuse is not permitted.

**Year rollover logic** (in CF):
```javascript
const now = new Date();
const currentYear = new Date().toLocaleString('en-US', { timeZone: 'Asia/Jerusalem', year: 'numeric' });
// If counters.receipts.year !== currentYear: reset lastNumber to 0, set year to currentYear, then increment
// All in a single Firestore transaction
```

---

### `/config/collection_settings` (single document, ID: `collection_settings`)

```
// allow read: if isSignedIn(); allow write: if isAdmin()
staleCashWarningDays: int             // default: 3; days before stale-cash CF warns collector
```

---

### Addition to `/users/{uid}`

The following fields are added for the `collector` role:

```
// New fields (null for admin and employee roles):
cashOnHand: int                       // agorot; CF-maintained; sum of pending_handover payments for this collector
maxCashOnHand: int?                   // agorot; null = no limit; admin-configurable per collector
```

---

### Firestore Indexes (new, to add to `firestore.indexes.json`)

```json
[
  {
    "collectionGroup": "debts",
    "queryScope": "COLLECTION",
    "fields": [
      { "fieldPath": "assignedCollectorId", "order": "ASCENDING" },
      { "fieldPath": "status", "order": "ASCENDING" }
    ]
  },
  {
    "collectionGroup": "debts",
    "queryScope": "COLLECTION",
    "fields": [
      { "fieldPath": "assignedCollectorId", "order": "ASCENDING" },
      { "fieldPath": "dueDate", "order": "ASCENDING" }
    ]
  },
  {
    "collectionGroup": "debts",
    "queryScope": "COLLECTION",
    "fields": [
      { "fieldPath": "customerId", "order": "ASCENDING" },
      { "fieldPath": "createdAt", "order": "DESCENDING" }
    ]
  },
  {
    "collectionGroup": "debts",
    "queryScope": "COLLECTION",
    "fields": [
      { "fieldPath": "status", "order": "ASCENDING" },
      { "fieldPath": "dueDate", "order": "ASCENDING" }
    ]
  },
  {
    "collectionGroup": "payments",
    "queryScope": "COLLECTION",
    "fields": [
      { "fieldPath": "collectorId", "order": "ASCENDING" },
      { "fieldPath": "status", "order": "ASCENDING" }
    ]
  },
  {
    "collectionGroup": "payments",
    "queryScope": "COLLECTION",
    "fields": [
      { "fieldPath": "debtId", "order": "ASCENDING" },
      { "fieldPath": "createdAt", "order": "DESCENDING" }
    ]
  },
  {
    "collectionGroup": "payments",
    "queryScope": "COLLECTION",
    "fields": [
      { "fieldPath": "collectorId", "order": "ASCENDING" },
      { "fieldPath": "collectedAt", "order": "DESCENDING" }
    ]
  },
  {
    "collectionGroup": "handovers",
    "queryScope": "COLLECTION",
    "fields": [
      { "fieldPath": "collectorId", "order": "ASCENDING" },
      { "fieldPath": "initiatedAt", "order": "DESCENDING" }
    ]
  },
  {
    "collectionGroup": "visits",
    "queryScope": "COLLECTION",
    "fields": [
      { "fieldPath": "collectorId", "order": "ASCENDING" },
      { "fieldPath": "visitedAt", "order": "DESCENDING" }
    ]
  },
  {
    "collectionGroup": "visits",
    "queryScope": "COLLECTION",
    "fields": [
      { "fieldPath": "customerId", "order": "ASCENDING" },
      { "fieldPath": "visitedAt", "order": "DESCENDING" }
    ]
  },
  {
    "collectionGroup": "collection_logs",
    "queryScope": "COLLECTION",
    "fields": [
      { "fieldPath": "entityId", "order": "ASCENDING" },
      { "fieldPath": "timestamp", "order": "DESCENDING" }
    ]
  },
  {
    "collectionGroup": "installments",
    "queryScope": "COLLECTION_GROUP",
    "fields": [
      { "fieldPath": "dueDate", "order": "ASCENDING" },
      { "fieldPath": "status", "order": "ASCENDING" }
    ]
  }
]
```

---

## 4. Security Rules Strategy

### New helper functions

```javascript
// In firestore.rules — add alongside existing isAdmin():
function isCollector() {
  return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'collector';
}

// isEmployee() is defined for employees only — collectors do NOT have attendance access:
function isEmployee() {
  return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role
         == 'employee';
}
```

### Rules per collection

```javascript
match /customers/{customerId} {
  allow read: if isAdmin()
              || (isCollector() && resource.data.assignedCollectorId == request.auth.uid);
  allow create: if isAdmin();
  allow update: if isAdmin();
  allow delete: if false;
}

match /debts/{debtId} {
  allow read: if isAdmin()
              || (isCollector() && resource.data.assignedCollectorId == request.auth.uid);
  allow create: if isAdmin();
  allow update: if isAdmin();
  // Collectors never write debts directly — CF maintains balance fields
  allow delete: if false;
}

match /installment_plans/{planId} {
  allow read: if isAdmin()
              || (isCollector()
                  && get(/databases/$(database)/documents/debts/$(resource.data.debtId))
                     .data.assignedCollectorId == request.auth.uid);
  allow write: if isAdmin();
}

match /installment_plans/{planId}/installments/{n} {
  allow read: if isAdmin()
              || (isCollector()
                  && get(/databases/$(database)/documents/installment_plans/$(planId))
                     .data.customerId != null);  // simplified: readable if plan is readable
  allow write: if false; // CF only
}

match /payments/{paymentId} {
  allow read: if isAdmin()
              || (isCollector() && resource.data.collectorId == request.auth.uid);

  allow create: if isCollector()
                && request.resource.data.collectorId == request.auth.uid
                && request.resource.data.recordedById == request.auth.uid
                // OR admin records on behalf:
                // (handled by: if isAdmin() then collectorId may differ from auth.uid)
                && request.resource.data.amount > 0
                && request.resource.data.status == 'pending_handover'
                && request.resource.data.isCancelled == false
                && request.resource.data.isCorrection == false
                && request.resource.data.receiptNumber == ''
                && request.resource.data.keys().hasAll([
                     'debtId', 'customerId', 'collectorId', 'recordedById',
                     'amount', 'paymentMethod', 'collectedAt', 'status',
                     'isCancelled', 'isCorrection', 'receiptNumber'
                   ])
                && get(/databases/$(database)/documents/debts/$(request.resource.data.debtId))
                   .data.assignedCollectorId == request.auth.uid;

  allow create: if isAdmin();  // Admin can record on behalf with any collectorId

  // No one can update a payment directly — CF only handles receipt number, status,
  // and cancellation. The exception: admin can update cancellation fields.
  allow update: if isAdmin()
                && request.resource.data.diff(resource.data).affectedKeys().hasOnly([
                     'isCancelled', 'cancellationReason', 'cancelledBy', 'cancelledAt', 'status'
                   ]);

  allow delete: if false;
}

match /handovers/{handoverId} {
  allow read: if isAdmin()
              || (isCollector() && resource.data.collectorId == request.auth.uid);

  allow create: if isCollector()
                && request.resource.data.collectorId == request.auth.uid
                && request.resource.data.status == 'pending_verification'
                && request.resource.data.keys().hasAll([
                     'collectorId', 'collectorName', 'claimedAmount', 'paymentIds',
                     'status', 'initiatedAt'
                   ]);

  allow update: if isAdmin()
                && request.resource.data.diff(resource.data).affectedKeys().hasOnly([
                     'actualAmount', 'status', 'verifiedAt', 'receivedBy',
                     'receivedByName', 'discrepancyAmount', 'discrepancyNotes', 'notes'
                   ]);

  allow delete: if false;
}

match /visits/{visitId} {
  allow read: if isAdmin()
              || (isCollector() && resource.data.collectorId == request.auth.uid);
  allow create: if isCollector() && request.resource.data.collectorId == request.auth.uid;
  allow update: if false; // Visits are immutable after creation
  allow delete: if false;
}

match /collection_logs/{logId} {
  allow read: if isAdmin()
              || (isCollector() && resource.data.actorId == request.auth.uid);
  allow write: if false;
}

match /config/counters {
  allow read: if isAdmin();
  allow write: if false;
}

match /config/collection_settings {
  allow read: if request.auth != null;
  allow write: if isAdmin();
}
```

### Existing rules that change

- `isEmployee()` function: `role == 'employee'` only. Collectors do NOT have attendance access — they are not shift employees. The attendance rule gates on `isEmployee()`, explicitly excluding collectors.
- `users/{uid}` self-update mask: must NOT include `cashOnHand` or `maxCashOnHand` — CF only.
- Admin writes to `users/{uid}` must be allowed for `maxCashOnHand` field.

### Security test checklist (before release)

Each of the following must be explicitly verified, not assumed:

- [ ] Collector cannot read a customer with a different `assignedCollectorId`
- [ ] Collector cannot read a debt with a different `assignedCollectorId`
- [ ] Collector cannot create a payment with `collectorId != uid`
- [ ] Collector cannot create a payment against a debt assigned to another collector
- [ ] Collector cannot update a payment after creation
- [ ] Collector cannot verify or update a handover
- [ ] Employee (non-collector) cannot read any customer, debt, or payment document
- [ ] Admin can read and write all collection documents
- [ ] No client can write to `collection_logs`
- [ ] No client can write to `config/counters`

---

## 5. Cloud Functions

All new CF modules live under `functions/lib/collections/`. The main `functions/index.js` re-exports them. The existing module structure (established in v1.8.0 modularization) is followed.

---

### 5.1 Callable: `createEmployeeUser` (existing — update only)

**Change**: Accept `role: 'collector'` as a valid third value alongside `admin` and `employee`. Validate server-side. Initialize `cashOnHand: 0` and `maxCashOnHand: null` on the created `users/{uid}` document when `role == 'collector'`.

---

### 5.2 Trigger: `onPaymentCreated`

**Trigger**: `onCreate` on `/payments/{paymentId}`

**This is the most critical function in the subsystem. It must be atomic and idempotent.**

**Idempotency guard**: At the start, check if `payment.receiptNumber != ''`. If so, the CF has already run (retry scenario) — exit immediately with no writes.

**Execution (all financial writes in a single Firestore transaction)**:

```
1. BEGIN TRANSACTION
   a. Read payment document (to get current state, validate not cancelled)
   b. Read debt document
      - Validate: debt.status not in ['settled', 'cancelled', 'written_off']
      - Validate: payment.amount <= debt.remainingBalance
        If invalid: ABORT transaction, write collection_log (payment.recorded with error note),
                    update payment status to 'invalid', return error response
   c. Read /config/counters
      - If counters.receipts.year != currentYear(Jerusalem):
          reset lastNumber = 0, set year = currentYear
      - Increment lastNumber
      - Format receipt number: `RCPT-${year}-${String(lastNumber).padStart(5, '0')}`
   d. Write receipts counter (updated)
   e. Write payment.receiptNumber = formattedReceiptNumber
   f. Update debt:
      - paidAmount += payment.amount
      - remainingBalance -= payment.amount (guaranteed >= 0 by step b validation)
      - status = recalculateDebtStatus(paidAmount, remainingBalance, dueDate)
      - updatedAt = now
   g. Update collector user:
      - cashOnHand += payment.amount
   h. Update customer:
      - totalOutstandingBalance: recomputed or decremented by payment.amount
      - lastPaymentAt = payment.collectedAt
2. COMMIT TRANSACTION
3. OUTSIDE TRANSACTION (best-effort):
   i. If debt has installmentPlan: call applyPaymentToInstallments(...)
      (separate transaction; idempotent via paymentIds array check)
   j. Check open PTPs for this customer/debt: if a PTP with promisedDate >= today
      and status == 'pending' exists, mark it 'kept'
   k. Check cashOnHand vs maxCashOnHand: if > 80% of limit, write warning notification
   l. Write collection_log entry (action: 'payment.recorded' + 'payment.receipt_assigned')
   m. Write in-app notification to all admins: "Payment recorded"
```

**Installment FIFO allocation** (`applyPaymentToInstallments`):
```
1. Query installments for planId where status in ['pending', 'partial'] ORDER BY number ASC
2. Remaining = payment.amount
3. For each installment (ascending number):
   a. available = installment.expectedAmount - installment.paidAmount
   b. apply = min(remaining, available)
   c. installment.paidAmount += apply
   d. remaining -= apply
   e. if installment.paidAmount >= installment.expectedAmount: status = 'paid', paidAt = now
   f. elif installment.paidAmount > 0: status = 'partial'
   g. add paymentId to installment.paymentIds
   h. if remaining == 0: break
4. Batch write all updated installments
5. Update debt.nextInstallmentDueDate = next 'pending' or 'partial' installment.dueDate
```

---

### 5.3 Trigger: `onPaymentCancelled`

**Trigger**: `onUpdate` on `/payments/{paymentId}` where `before.isCancelled == false && after.isCancelled == true`

**Validation**: If payment's handover has `status == 'verified'`, block cancellation: write collection_log with error and set payment back to non-cancelled state. The UI should prevent this before it reaches the CF, but the CF is the authoritative guard.

**Execution (Firestore transaction)**:
```
1. Reverse debt balance:
   - paidAmount -= payment.amount
   - remainingBalance += payment.amount
   - status = recalculateDebtStatus(...)
2. Reverse collector cashOnHand:
   - cashOnHand -= payment.amount
3. Update customer totalOutstandingBalance
4. Write collection_log (action: 'payment.cancelled')
5. If payment was in a handover with status 'pending_verification':
   - Remove paymentId from handover.paymentIds
   - Recalculate handover.claimedAmount
```

---

### 5.4 Trigger: `onDebtCreated`

**Trigger**: `onCreate` on `/debts/{debtId}`

```
1. Update customer: totalOutstandingBalance += debt.originalAmount, activeDebtCount++
2. Write collection_log (action: 'debt.created')
3. If debt.assignedCollectorId != null:
   - Write collection_log (action: 'debt.assigned')
   - Send FCM + in-app notification to collector: "New debt assigned"
```

---

### 5.5 Trigger: `onDebtUpdated`

**Trigger**: `onUpdate` on `/debts/{debtId}`

```
1. If assignedCollectorId changed:
   - Write collection_log (action: 'debt.reassigned', before/after collector)
   - Send FCM to new collector: "Debt assigned to you"
2. If status changed:
   - Write collection_log (action: 'debt.status_changed', before/after status)
   - If new status in ['settled', 'cancelled', 'written_off']:
       Update customer: activeDebtCount--
       Recalculate customer.accountStatus
       Update customer.totalOutstandingBalance (subtract remainingBalance before settling)
3. If writeOff populated (written_off):
   - Write collection_log (action: 'debt.written_off')
4. If dispute populated (disputed):
   - Write collection_log (action: 'debt.disputed')
5. If settlement populated (settled via settle-for-less):
   - Write collection_log (action: 'debt.settled')
```

---

### 5.6 Trigger: `onHandoverCreated`

**Trigger**: `onCreate` on `/handovers/{handoverId}`

```
1. Write collection_log (action: 'handover.initiated')
2. Send FCM + in-app notification to all admins: "Handover pending verification"
```

---

### 5.7 Trigger: `onHandoverUpdated`

**Trigger**: `onUpdate` on `/handovers/{handoverId}` where status changed

**If status → 'verified' or 'discrepancy':**
```
1. TRANSACTION:
   a. Batch update all payments in handover.paymentIds:
      - status = 'handed_over' (then 'verified' — or make these simultaneous)
      - handoverId = handover document ID
   b. Determine settled amount:
      - If 'verified': amount = claimedAmount
      - If 'discrepancy': amount = actualAmount (what admin says they received)
   c. Update collector cashOnHand -= settled amount
2. Write collection_log:
   - 'verified': action: 'handover.verified'
   - 'discrepancy': action: 'handover.discrepancy_noted' (discrepancyAmount in after)
3. Send FCM + in-app to collector:
   - 'verified': "Your handover of ₪X has been verified"
   - 'discrepancy': "Discrepancy in your handover — contact admin (₪X difference)"
```

---

### 5.8 Trigger: `onVisitCreated`

**Trigger**: `onCreate` on `/visits/{visitId}`

```
1. Update customer.lastContactAt = visit.visitedAt
2. Write collection_log (action: 'visit.logged')
3. If visit.promiseToPay != null:
   Write collection_log (action: 'ptp.created')
```

---

### 5.9 Scheduled: `updateDebtAgingBuckets`

**Schedule**: Daily `08:00 Asia/Jerusalem`

```
Query: debts WHERE status IN ['active', 'partial', 'overdue'] (paginated, 500/batch)
For each debt:
  If debt.dueDate == null: agingBucket = 'current', daysPastDue = 0
  Else:
    daysPastDue = floor((today - debt.dueDate) / 86400000)
    agingBucket:
      daysPastDue <= 0  → 'current'
      1–30  → '1-30'
      31–60 → '31-60'
      61–90 → '61-90'
      91+   → '90+'
    If daysPastDue > 0 && debt.status != 'overdue': status = 'overdue'
Batch write all updates.
After updating all debts: recalculate customer.accountStatus for each affected customer.
```

---

### 5.10 Scheduled: `sendInstallmentDueReminders`

**Schedule**: Daily `09:00 Asia/Jerusalem`

```
Collection group query: installments WHERE dueDate BETWEEN now AND now+24h
                        AND status IN ['pending', 'partial']
Group by collectorId (via parent debt.assignedCollectorId).
For each collector: send ONE digest in-app notification:
  "[N] installment(s) due tomorrow"
  Tap destination: collector debt list (filtered to installment debts)
Deduplication: check if already sent today for this collector via lastReminderAt on plan.
```

---

### 5.11 Scheduled: `sendOverdueDebtEscalations`

**Schedule**: Daily `10:00 Asia/Jerusalem`

**Same pattern as existing `sendOverdueTaskEscalations`**:

```
Query: debts WHERE agingBucket != 'current' AND status == 'overdue'
       AND (lastOverdueEscalationAt == null OR lastOverdueEscalationAt < today)
For each debt:
  Notify assigned collector: "Payment overdue: [Customer] — [N] days past due"
  If daysPastDue >= 30: ALSO notify all admins (escalation)
  Update debt.lastOverdueEscalationAt = now
```

---

### 5.12 Scheduled: `checkBrokenPtps`

**Schedule**: Daily `08:30 Asia/Jerusalem`

```
Query: visits WHERE promiseToPay.status == 'pending'
                AND promiseToPay.promisedDate < today (Jerusalem)
For each visit:
  Update visit.promiseToPay.status = 'broken'
  Write collection_log (action: 'ptp.broken')
Group by collectorId.
For each collector with broken PTPs: send digest notification:
  "[N] promise(s) to pay were missed"
Send single digest to all admins:
  "[N] promise(s) to pay were missed today"
```

---

### 5.13 Scheduled: `sendStaleCashWarnings`

**Schedule**: Daily `11:00 Asia/Jerusalem`

```
Query: users WHERE role == 'collector' AND cashOnHand > 0
For each collector:
  Find their oldest payment with status == 'pending_handover'
  daysSince = floor((now - oldestPayment.collectedAt) / 86400000)
  Read collection_settings.staleCashWarningDays
  If daysSince >= staleCashWarningDays:
    Notify collector: "You have ₪X in cash for [N] days — please hand over"
    Notify admins: "[Collector] has ₪X for [N] days without handover"
  Deduplication: skip if already warned today (track via users/{uid}.lastStaleCashWarnAt)
```

---

### Helper functions (not exported, shared across CF modules)

```javascript
// Recompute debt status from current financial state
function recalculateDebtStatus(paidAmount, remainingBalance, dueDate, currentStatus) {
  if (remainingBalance === 0) return 'settled';
  const now = new Date();
  const isOverdue = dueDate && dueDate.toDate() < now;
  if (paidAmount > 0) return isOverdue ? 'overdue' : 'partial';
  return isOverdue ? 'overdue' : 'active';
}

// Format agorot as display string (for notification messages — NOT for UI)
function formatAgorot(agorot) {
  return `₪${(agorot / 100).toFixed(2)}`;
}

// Jerusalem-aware date helpers (same pattern as existing sendTaskDeadlineReminders)
function todayInJerusalem() { ... }
function isSameDayJerusalem(ts1, ts2) { ... }
```

---

## 6. Notifications

### Notification digest rule

Cron-triggered notifications (installment reminders, overdue escalations, broken PTP alerts, stale cash) are **digested per collector**: one notification per day per collector per event type, not one per debt/visit. FCM push is used only for actionable events requiring immediate attention (handover, assignment). Cron results use in-app notifications only (no FCM push) to prevent notification fatigue.

### Admin notifications

| Trigger | Channel | Message (EN) | Tap destination |
|---|---|---|---|
| Payment recorded | In-app only | "[Collector] collected ₪X from [Customer]" | Payment detail |
| Handover pending verification | FCM + In-app | "[Collector] is handing over ₪X — please verify" | Handover verification screen |
| Debt 30+ days overdue | In-app | "Escalation: [Customer] — ₪X is 30+ days overdue ([Collector])" | Debt detail |
| Broken PTPs (daily digest) | In-app | "[N] promises to pay were missed today" | Debt list filtered to overdue |
| Collector stale cash | In-app | "[Collector] has ₪X for [N] days without handover" | Collector summary view |
| Debt written off | In-app | "₪X written off for [Customer] by [Admin]" | Debt detail |

### Collector notifications

| Trigger | Channel | Message (EN) | Tap destination |
|---|---|---|---|
| Debt assigned | FCM + In-app | "New debt assigned: [Customer] owes ₪X (due [date])" | Debt detail |
| Debt reassigned away | In-app | "Debt for [Customer] has been reassigned" | Debt list |
| Installment due tomorrow (digest) | In-app | "[N] installment(s) due tomorrow" | Debt list |
| Debt overdue | In-app | "Payment overdue: [Customer] — [N] days past due" | Debt detail |
| PTP broken (digest) | In-app | "[N] promise(s) to pay were missed" | Debt list |
| Stale cash warning | In-app | "You have ₪X in cash for [N] days — please hand over" | Handover initiation |
| Cash approaching limit (80%) | In-app | "Cash on hand at 80% of your limit — consider handing over soon" | Handover initiation |
| Handover verified | FCM + In-app | "Your handover of ₪X has been verified by [Admin]" | Handover detail |
| Handover discrepancy | FCM + In-app | "Discrepancy in your handover — contact admin (₪X difference)" | Handover detail |

### Notification translation

All notification strings must have EN and AR keys, following the existing `functions/lib/i18n` pattern. Collector's `languageCode` field (existing, set on sign-in) drives the language selection in CF.

---

## 7. Reports and PDF Generation

### 7.1 PDF Receipt (per payment)

Uses the existing `pdf` + `printing` package (same as attendance reports). New `ReceiptPdfService`.

**Content**:
```
┌─────────────────────────────────────────────┐
│ [Business Name]                             │
│ RECEIPT / قبالة                             │
│                                             │
│ Receipt No.: RCPT-2026-00042    [Date/Time] │
│                                             │
│ Received from: [Customer Name]              │
│ Contact: [Customer Phone]                   │
│                                             │
│ Amount: ₪500.00                             │
│ In words: Five Hundred New Shekels          │
│ In Arabic: خمسمائة شيكل جديد               │
│                                             │
│ Payment method: Cash                        │
│ Received by: [Collector Name]               │
│ Remaining balance: ₪1,500.00               │
│                                             │
│ ─────────────────────────────────────────── │
│ This receipt is a record of payment received│
│ Official receipt to be provided separately  │
│ ─────────────────────────────────────────── │
└─────────────────────────────────────────────┘
```

**Amount in words**: A custom utility function is required (`amountInWords(int agorot, String locale)`). Hebrew and Arabic both have grammatical gender and dual forms. This function must be separately implemented and unit-tested for amounts from ₪1 to ₪999,999.

**Field Supplement disclaimer**: "Official receipt to be provided separately" — removed when the system transitions to System of Record.

**Access**: Collector can view/share receipts for their own payments. Admin can view/share any payment's receipt.

---

### 7.2 Handover Reconciliation Report (PDF, per handover)

Generated at handover verification time (or on demand afterward).

**Content**: Header (business name, "Handover Reconciliation"), collector name, date, admin who verified, then a table of all included payments (receipt number, customer name, amount, method, collected date), then summary row (claimed amount | actual amount verified | discrepancy if any | status).

---

### 7.3 Collections Dashboard (admin, in-app)

New section on the existing Admin Dashboard screen, or a dedicated Collections tab:

- Total outstanding balance (all active/partial/overdue debts)
- Total collected today | this week | this month
- Total cash currently with all collectors (sum of `users.cashOnHand` where `role == 'collector'`)
- Overdue debts count and total amount
- Aging breakdown (bar chart or table): current / 1–30 / 31–60 / 61–90 / 90+
- Per-collector summary table: name | assigned debts | total collected MTD | cash on hand | pending handovers

---

### 7.4 Aging Report (PDF, admin)

All active/partial/overdue debts grouped by aging bucket (90+ first), sorted by amount descending within each bucket. Per-debt row: customer name, collector, description, original amount, remaining balance, days overdue. Bucket subtotals and grand total.

---

### 7.5 Collector Reconciliation Report (PDF, admin, date range)

For a selected collector and date range: all payments recorded (with receipt numbers, amounts, customer names, collection dates), all handovers initiated and their verification status, ending cash on hand balance. Presents a complete picture of the collector's activity for that period.

---

## 8. State Transitions

### Debt status

```
                    ┌─────────────────────────────────────────────┐
                    │             ADMIN TERMINAL ACTIONS           │
                    ▼             ▼              ▼                 │
active ──────────► overdue   written_off    cancelled          disputed
  │                  │                                             │
  │ (1st payment)    │ (payment)                         (resolved)│
  ▼                  ▼                                             │
partial ──────────► overdue ──────────────────────────────────────►(back to partial/active/settled)
  │
  │ (remainingBalance → 0)
  ▼
settled  ◄────────────────────────── (any status, if balance reaches 0)
```

| Transition | Trigger | Guard |
|---|---|---|
| `active → partial` | `onPaymentCreated` CF | `paidAmount > 0 && remainingBalance > 0` |
| `active/partial → settled` | `onPaymentCreated` CF | `remainingBalance == 0` |
| `active/partial → overdue` | `updateDebtAgingBuckets` cron | `dueDate < today` |
| `overdue → partial/settled` | `onPaymentCreated` CF | payment recorded against overdue debt |
| `any → written_off` | Admin action | must include reason; terminal |
| `any → cancelled` | Admin action | must include reason; terminal |
| `any → disputed` | Admin action | adds dispute object; not terminal |
| `disputed → prior_status` | Admin resolves | dispute.resolution filled |
| `any → settled` (via settlement) | Admin: settle-for-less | settlement object added; balance set to 0 |

---

### Payment status

```
[created by client with receiptNumber='']
         │
         ▼ (onPaymentCreated CF)
   pending_handover
         │
         ▼ (onHandoverUpdated CF, after admin verifies)
    handed_over
         │
         ▼ (simultaneous with handed_over in v2.0; can be a separate step later)
      verified
         
         OR
         
   pending_handover ──► cancelled (admin only; cannot cancel if in verified handover)
```

---

### Handover status

```
[created by collector]
         │
         ▼
  pending_verification
         │
         ├──► verified    (admin confirms claimedAmount == actualAmount)
         │
         └──► discrepancy (admin enters actualAmount != claimedAmount)
```

Both `verified` and `discrepancy` are terminal. There is no "edit handover" path.

---

### Installment status

```
pending ──► partial ──► paid
   │           │
   └───────────┴──► overdue (daily cron; dueDate < today && not paid)
overdue ──────────────────────► paid (if payment received late)
```

---

### Visit PTP status

```
pending ──► kept    (onPaymentCreated CF: payment.collectedAt <= promisedDate)
pending ──► broken  (checkBrokenPtps cron: promisedDate < today, no payment)
```

---

### Customer account status

CF-maintained (updated by `updateDebtAgingBuckets` cron and on debt status changes):

```
good_standing:  no debt has agingBucket in ['31-60', '61-90', '90+']
at_risk:        any debt has agingBucket in ['31-60', '61-90']
delinquent:     any debt has agingBucket == '90+'
```

---

## 9. PR Implementation Plan

All PRs target the single long-running branch `feat/v2-collections`. Nothing is merged to `main` or released until all PRs are merged to the feature branch and the complete subsystem is smoke-tested end-to-end.

---

### PR 1 — Schema, Role, Foundation

**Goal**: Complete structural foundation with no user-visible functionality.

**Files changed**:
- `functions/lib/auth/create-employee.js` — accept `role: 'collector'`; initialize `cashOnHand: 0`, `maxCashOnHand: null` on users doc
- `firestore.rules` — all new collection rules + updated `isEmployee()` + updated `users` self-update mask
- `firestore.indexes.json` — all 13 new indexes from Section 3
- `lib/core/constants/firebase_paths.dart` — constants for all new collection paths
- `lib/core/routes/route_names.dart` — all new collector route constants
- `lib/core/routes/app_router.dart` — stub route cases (return placeholder screens)
- `lib/features/collections/` — new feature directory with empty subdirectory structure
- `lib/features/auth/presentation/cubit/auth_cubit.dart` — handle `collector` role → route to CollectorApp
- `lib/app/collector_app.dart` — add `CollectorApp` shell (bottom nav: Collections | Settings)
- `assets/translations/en.json` + `ar.json` — ALL ~70 new translation keys (complete set for the entire subsystem)
- `pubspec.yaml` — version `2.0.0+14`

**Translation keys strategy**: Add every key for the entire subsystem in PR 1. This makes every subsequent PR Dart-only and Shorebird-patchable as individual bug-fix releases after v2.0.0 ships.

**Smoke test gate**:
- [ ] Admin creates a collector user via the existing employee creation flow (role: collector)
- [ ] Collector signs in → routed to `CollectorApp` shell (placeholder screens)
- [ ] Collector cannot navigate to admin or employee screens
- [ ] Employee cannot see any collections UI element

---

### PR 2 — Customer and Debt Management (Admin)

**Goal**: Admin can set up the collections environment — create customers, create debts, assign to collectors.

**Files changed**:
- `lib/features/collections/data/models/customer_model.dart`
- `lib/features/collections/data/models/debt_model.dart`
- `lib/features/collections/data/repositories/customer_repository.dart`
- `lib/features/collections/data/repositories/debt_repository.dart`
- `lib/features/collections/presentation/cubit/customers_cubit.dart` + state
- `lib/features/collections/presentation/cubit/debts_cubit.dart` + state
- `lib/features/collections/presentation/screens/customer_list_screen.dart` (admin)
- `lib/features/collections/presentation/screens/customer_form_screen.dart` (create/edit)
- `lib/features/collections/presentation/screens/customer_detail_screen.dart`
- `lib/features/collections/presentation/screens/debt_list_screen.dart` (admin)
- `lib/features/collections/presentation/screens/debt_form_screen.dart` (create/edit)
- `lib/features/collections/presentation/screens/debt_detail_screen.dart` (stub; payments in PR 3)
- `lib/app/app.dart` — wire new cubits into MultiBlocProvider
- `functions/lib/collections/debt-triggers.js` — `onDebtCreated`, `onDebtUpdated`

**Smoke test gate**:
- [ ] Admin creates customer (all fields)
- [ ] Admin creates debt for customer, assigns to collector
- [ ] Collector signs in → debt appears in their debt list
- [ ] `collection_logs` entry exists for debt.created and debt.assigned
- [ ] CF notification delivered to collector (FCM)
- [ ] Admin deactivates customer → collector no longer sees customer

---

### PR 3 — Core Financial: Payment Recording and Handover

**This is the highest-risk PR. Do not merge until CF unit tests pass and smoke test is fully completed.**

**Files changed**:
- `lib/features/collections/data/models/payment_model.dart`
- `lib/features/collections/data/models/handover_model.dart`
- `lib/features/collections/data/repositories/payment_repository.dart`
- `lib/features/collections/data/repositories/handover_repository.dart`
- `lib/features/collections/presentation/cubit/payments_cubit.dart` + state
- `lib/features/collections/presentation/cubit/handover_cubit.dart` + state
- `lib/features/collections/presentation/screens/record_payment_screen.dart`
- `lib/features/collections/presentation/screens/payment_detail_screen.dart`
- `lib/features/collections/presentation/screens/handover_initiation_screen.dart`
- `lib/features/collections/presentation/screens/handover_verification_screen.dart` (admin)
- `lib/features/collections/presentation/screens/handover_list_screen.dart`
- `lib/features/collections/presentation/screens/debt_detail_screen.dart` (complete with payment history)
- `lib/features/collections/presentation/screens/collector_home_screen.dart` (basic: my debts + cashOnHand)
- `functions/lib/collections/payment-triggers.js` — `onPaymentCreated`, `onPaymentCancelled`
- `functions/lib/collections/handover-triggers.js` — `onHandoverCreated`, `onHandoverUpdated`
- `functions/lib/collections/receipt-counter.js` — atomic counter logic
- `functions/__tests__/collections/payment-triggers.test.js` — Jest unit tests (see Section 10)

**Required CF unit tests** (must pass before PR merge):
- Receipt number generation: correct format
- Receipt number atomicity: concurrent payments get different numbers
- Year rollover: last payment of year N and first of N+1 get correct formats
- CF idempotency: running `onPaymentCreated` twice on same payment with existing `receiptNumber` is a no-op
- Overpayment rejection: payment.amount > debt.remainingBalance → payment marked invalid
- Debt balance update: verify `paidAmount`, `remainingBalance`, `status` after payment
- Debt status recalculation: active→partial→settled sequence
- Handover verification: payments move to `handed_over`, cashOnHand decrements
- Discrepancy: actualAmount != claimedAmount → status = 'discrepancy', correct amounts recorded

**Smoke test gate**:
- [ ] Collector records cash payment → `receiptNumber` assigned within seconds
- [ ] Debt `paidAmount` and `remainingBalance` update correctly (verify in Firestore console)
- [ ] Collector `cashOnHand` increments correctly
- [ ] Debt status transitions: active → partial → settled (pay in stages)
- [ ] Overpayment attempt → error shown to collector, no payment created
- [ ] Admin cancels payment → balance and cashOnHand reverse (verify in Firestore console)
- [ ] Cancellation of verified handover payment → blocked with warning
- [ ] Collector initiates handover → admin receives notification
- [ ] Admin opens handover verification screen, sees claimed amount
- [ ] Admin enters matching actual amount → status: verified, payments: handed_over, cashOnHand decrements
- [ ] Admin enters mismatching actual amount → status: discrepancy, discrepancyAmount recorded permanently
- [ ] Admin cannot proceed without entering actualAmount field
- [ ] `collection_logs` entries exist for every action above
- [ ] Admin records payment on behalf of collector (collectorId != recordedById) → both fields correct

---

### PR 4 — Installment Plans

**Goal**: Admin can create installment plans; payments are automatically applied to installments in FIFO order.

**Files changed**:
- `lib/features/collections/data/models/installment_plan_model.dart`
- `lib/features/collections/data/models/installment_model.dart`
- `lib/features/collections/data/repositories/installment_repository.dart`
- `lib/features/collections/presentation/cubit/installment_cubit.dart` + state
- `lib/features/collections/presentation/screens/installment_plan_form_screen.dart`
- `lib/features/collections/presentation/screens/installment_plan_detail_screen.dart`
- Updates: `debt_detail_screen.dart` — installment schedule display
- Updates: `record_payment_screen.dart` — "Next installment due: [date] ₪X" hint
- Updates: `debt_form_screen.dart` — toggle to create installment plan at debt creation
- `functions/lib/collections/installment-triggers.js` — `onInstallmentPlanCreated` (creates sub-docs)
- Updates: `payment-triggers.js` — add `applyPaymentToInstallments` call in `onPaymentCreated`
- Add to scheduler: `sendInstallmentDueReminders` (daily 09:00)

**Smoke test gate**:
- [ ] Admin creates installment plan on a debt → correct number of installment sub-documents created with correct due dates
- [ ] Collector records payment equaling one installment → first installment status: paid
- [ ] Collector records payment equaling 1.5 installments → first: paid, second: partial
- [ ] Collector records lump-sum payment → all installments marked paid, debt: settled
- [ ] Installment reminder cron fires → collector notified (invoke manually for testing)
- [ ] `debt.nextInstallmentDueDate` updates correctly after each payment
- [ ] Overpayment guard still functions for installment debts

---

### PR 5 — Visit Logs, PTP, and Automation Crons

**Goal**: Collectors can log all customer contact attempts; PTPs are tracked and automatically flagged when broken; overdue and stale-cash automation fires daily.

**Files changed**:
- `lib/features/collections/data/models/visit_model.dart`
- `lib/features/collections/data/repositories/visit_repository.dart`
- `lib/features/collections/presentation/cubit/visit_cubit.dart` + state
- `lib/features/collections/presentation/screens/log_visit_screen.dart`
- Updates: `debt_detail_screen.dart` — visit history section
- Updates: `customer_detail_screen.dart` — contact history section
- Admin: broken PTP list view; overdue debt list with aging bucket grouping
- Admin: debt detail — write-off action, dispute action, settle-for-less action (simplified)
- `functions/lib/collections/visit-triggers.js` — `onVisitCreated`
- Add to scheduler: `checkBrokenPtps` (08:30), `sendOverdueDebtEscalations` (10:00), `sendStaleCashWarnings` (11:00), `updateDebtAgingBuckets` (08:00)
- `config/collection_settings` admin configuration screen (staleCashWarningDays)

**Smoke test gate**:
- [ ] Collector logs in-person visit with PTP for tomorrow → PTP appears on debt detail
- [ ] No payment recorded before promisedDate → CF marks PTP broken next day (test with past date)
- [ ] Admin marks debt as disputed → status changes, dispute object populated, collection_log entry
- [ ] Admin writes off debt → status: written_off, writeOff object populated, balance zeroed
- [ ] Admin settle-for-less → settlement object populated, payment for negotiated amount created
- [ ] Stale cash cron → invoked manually, collector with 4-day-old pending payment notified
- [ ] Aging buckets update correctly (invoked manually with backdated debt due dates)
- [ ] Customer.accountStatus updates to 'delinquent' when debt hits 90+ days

---

### PR 6 — PDF Receipts, Reconciliation, and Admin Dashboard

**Goal**: Complete reporting layer. Receipt PDFs shareable by collectors. Admin dashboard shows portfolio overview.

**Files changed**:
- `lib/features/collections/data/services/receipt_pdf_service.dart`
- `lib/features/collections/data/services/collections_report_service.dart`
- `lib/features/collections/data/services/amount_in_words.dart` — new utility (see note)
- `lib/features/collections/presentation/screens/collections_dashboard_screen.dart`
- `lib/features/collections/presentation/screens/aging_report_screen.dart`
- Updates: `payment_detail_screen.dart` — "Share Receipt" button
- Updates: `handover_detail_screen.dart` (admin) — "Generate Reconciliation Report" button

**Amount-in-words note**: This utility must handle amounts from ₪0.01 to ₪999,999.99 in both Hebrew and Arabic, respecting grammatical gender. Hebrew: "מאה שקלים חדשים", Arabic: "مئة شيكل جديد". This is non-trivial — implement and unit-test independently as `amount_in_words_test.dart` before integrating into the PDF service.

**Smoke test gate**:
- [ ] Receipt PDF generates for a payment; receipt number, customer name, amount (numbers + words), remaining balance, collector name all correct
- [ ] Amount in words correct for: ₪1, ₪50, ₪100, ₪500, ₪1000, ₪5000, ₪10000
- [ ] Amount in words correct in both EN and AR (share as PDF in AR locale)
- [ ] Reconciliation PDF generates for a verified handover; all payments listed
- [ ] Collections dashboard totals match Firestore data (verify each figure independently)
- [ ] Aging report PDF groups debts correctly by bucket

---

### PR 7 — Collector Experience Polish and Settings

**Goal**: Collector UX is complete and optimized for field use. Admin can configure per-collector cash limits.

**Files changed**:
- `lib/features/collections/presentation/screens/collector_home_screen.dart` (complete)
- Max cash on hand progress indicator: visual bar + percentage on collector home
- Admin: per-collector settings screen (maxCashOnHand field on users/{uid})
- Empty states: all collector screens with actionable copy
- Fast payment flow: auto-focus amount field, streamlined screen sequence
- Visit quick-log shortcut from customer card (most common field action)
- Notification tap routing for all new notification types
- Collector deactivation guard: warn admin if collector has `cashOnHand > 0` before deactivating

**Note**: This PR is Dart-only (no CF changes, no schema changes, no translation changes). It is Shorebird-patchable after v2.0.0 ships.

**Smoke test gate**:
- [ ] Collector home shows correct cashOnHand figure matching Firestore
- [ ] Cash on hand progress bar shows correctly at 0%, 50%, 80%, 100% of limit
- [ ] At 100% of limit: record payment shows block message; payment cannot be created
- [ ] Admin sets maxCashOnHand on collector → limit enforced in subsequent payment attempts
- [ ] Admin attempts to deactivate collector with cashOnHand > 0 → warning dialog
- [ ] All empty states display on first sign-in (no assigned customers/debts)
- [ ] Notification taps route to correct screens for all 8 notification types

---

## 10. Testing Strategy

### CF Unit Tests (Jest, required for PR 3)

File: `functions/__tests__/collections/payment-triggers.test.js`

**Test cases** (minimum required before PR 3 merge):

```javascript
describe('onPaymentCreated', () => {
  test('assigns correct receipt number format')
  test('increments counter atomically (concurrent payments get different numbers)')
  test('resets counter on year change')
  test('idempotency: second invocation on payment with existing receiptNumber is a no-op')
  test('rejects payment where amount > debt.remainingBalance')
  test('updates debt paidAmount correctly')
  test('updates debt remainingBalance correctly (never below zero)')
  test('transitions debt status: active → partial → settled')
  test('does not transition settled debt to other statuses')
  test('updates collector cashOnHand')
})

describe('applyPaymentToInstallments', () => {
  test('applies payment to oldest unpaid installment first (FIFO)')
  test('marks installment paid when paidAmount >= expectedAmount')
  test('leaves installment partial when payment covers only part')
  test('payment spanning multiple installments marks correct statuses')
  test('idempotency: paymentId already in installment.paymentIds → no double application')
})

describe('onPaymentCancelled', () => {
  test('reverses debt balance correctly')
  test('reverses cashOnHand correctly')
  test('blocks cancellation of payment in verified handover')
})

describe('receipt counter year rollover', () => {
  test('RCPT-2026-99999 followed by next payment in 2027 → RCPT-2027-00001')
})
```

### Firestore Emulator Rules Tests

File: `functions/__tests__/firestore-rules/collections-rules.test.js`

Each bullet below is a test case:
- Collector reads own assigned customer ✓
- Collector reads unassigned customer ✗
- Collector reads own assigned debt ✓
- Collector reads unassigned debt ✗
- Collector creates payment with own collectorId and assigned debt ✓
- Collector creates payment with another collector's ID ✗
- Collector creates payment against unassigned debt ✗
- Collector updates payment after creation ✗
- Collector creates handover with own collectorId ✓
- Collector updates handover ✗ (admin-only)
- Employee (non-collector) reads any customer document ✗
- Employee reads any debt document ✗
- Admin reads all collection documents ✓
- Admin cancels a payment (update isCancelled) ✓
- Admin verifies a handover (update status) ✓
- Any role writes to collection_logs ✗
- Any role writes to config/counters ✗

### Manual Smoke Test Checklist

The complete cumulative smoke test is the union of all per-PR gates listed in Section 9. Before releasing v2.0.0:

**Financial integrity verification** (beyond individual PR gates):
- [ ] Run a complete cycle: create customer → create debt (with installments) → collector records multiple payments → collector initiates handover → admin verifies → verify all Firestore figures match expected values (calculate independently on paper, compare to app)
- [ ] Run the discrepancy cycle: same as above but admin enters wrong amount → verify discrepancy is permanently recorded and cashOnHand reflects actual, not claimed
- [ ] Run the cancellation cycle: record payment → cancel → verify balance is exactly back to original
- [ ] Verify a collector with no assigned debts sees nothing (empty states, no data leakage)
- [ ] Verify an employee account has zero access to any collection screen or document (attempt navigation manually)

**Edge cases** (invoke CF manually via test callables or emulator):
- [ ] Overpayment attempt: payment amount exactly equals remainingBalance + 1 agorot → rejected
- [ ] Year rollover: receipt counter resets to 00001 in new year
- [ ] Offline payment → reconnect → receipt number assigned (test with airplane mode)
- [ ] Collector deactivated with cashOnHand > 0: warning shown, deactivation blocked

---

## 11. Field Supplement Operating Procedures

These are operational guidelines for the business during the initial deployment phase, before the app is trusted as System of Record.

### Daily procedures

**For collectors:**
1. At start of shift: check the app for new assigned debts and installments due today.
2. After each collection: record the payment immediately in the app. Do not batch record at day end — the CF-generated receipt number is the collector's accountability record.
3. If offline while collecting: note the amount, customer, and time manually. Record in the app when connectivity is restored. The app will show "Receipt pending" until the CF fires. Do not give the customer a receipt number until one appears in the app.
4. At end of shift: check "Cash on Hand" in the app. It must match the physical cash held. If there is any discrepancy, contact admin before handover.

**For admin:**
1. Review the "Pending Handovers" list at the start or end of each day.
2. When verifying a handover: always count physical cash first, then enter the actual amount in the app. Do not confirm without counting.
3. If a discrepancy is found: record it accurately in the app. Do not enter the claimed amount to make it "pass". The discrepancy record is permanent and is not an accusation — it is a starting point for resolution.
4. Once a week: download or review the Aging Report. Follow up on any debts moving into the 31-60 day bucket.

### Reconciliation (weekly, during Field Supplement phase)

1. Export or screenshot the collector reconciliation summary from the app for the week.
2. Compare total collected (per collector) against the sum of verified handovers for the same period.
3. Compare total outstanding balance in the app against the business's manual ledger.
4. Any discrepancy must be investigated and resolved before the next week's reconciliation.
5. Record the reconciliation result (match / variance amount) in a shared log. This log is the evidence trail for the System of Record promotion decision.

### Collector deactivation procedure

If a collector leaves the business:
1. Ensure their `cashOnHand` is zero (all payments handed over and verified).
2. Reassign all their active debts to another collector (admin debt list → batch reassign).
3. Deactivate their account only after step 1 and 2 are confirmed.
4. If cashOnHand > 0 at deactivation time, the app will warn admin. Do not override — resolve the handover first.

### System of Record promotion checklist

When the business is ready to promote the app from Field Supplement to System of Record:

- [ ] 4+ weeks of production data with zero reconciliation gaps (manual record matches app)
- [ ] All collectors trained on the offline receipt-pending flow
- [ ] Accountant has reviewed the PDF receipt format and confirmed it meets documentation requirements
- [ ] "Official receipt to be provided separately" disclaimer removed from receipt PDF template
- [ ] Accountant confirms write-off and cancelled debt distinctions satisfy local accounting standards
- [ ] Business has a data retention policy acknowledging financial records in Firestore cannot be deleted (only anonymized on GDPR/privacy request)
- [ ] Update this document: remove Field Supplement sections, mark as System of Record

---

## 12. Open Questions Resolved

| Question | Decision |
|---|---|
| Currency | ILS only; no multi-currency |
| Amount storage | Integers in agorot everywhere (Firestore, CF, Dart) |
| Interest accrual | None in v2.0 |
| Collector role | New `role: 'collector'` value |
| Collector visibility | Assigned debts only |
| Payment cancellation | Admin only |
| GPS tracking | Deferred |
| Photo evidence | Deferred (add after visit workflow proven) |
| Installment plans | Required in v2.0.0 (PR 4) |
| Max cash on hand | Required in v2.0.0 (PR 7); configurable per collector |
| Settlement workflow | Simplified in v2.0.0 (status change + settlement object) |
| Dispute workflow | Simplified in v2.0.0 (status change + dispute object) |
| Collector performance metrics | Data accumulated from day 1; dashboard UI in follow-up |
| Receipt format | Defined in Section 7.1; accountant review required before System of Record promotion |
| System of Record timing | 4+ weeks of reconciled production data; accountant sign-off |
| `recordedById` vs `collectorId` | Both fields on payment; `recordedById` = who tapped save; `collectorId` = who collected money |
| Guarantors | Name + phone fields on debt (no separate entity in v2.0) |
| Version number | v2.0.0 |
| PR strategy | 7 PRs on single `feat/v2-collections` branch; release only when all complete |
