/* eslint-env jest */
// Unit tests for calculateBalanceAdjustment in debt-triggers.js.
// No Firestore emulator required — the helper is side-effect-free.

const {calculateBalanceAdjustment} = require("../../lib/collections/debt-triggers");

// Convenience factories for before/after snapshots
const snap = (status, remainingBalance, extra = {}) => ({
  status,
  remainingBalance,
  ...extra,
});

// ─── Non-terminal → non-terminal (no adjustment) ──────────────────────────────

describe("no adjustment for non-terminal transitions", () => {
  test("active → overdue", () => {
    expect(calculateBalanceAdjustment(
        snap("active", 10000),
        snap("overdue", 10000),
    )).toBe(0);
  });

  test("active → partial", () => {
    expect(calculateBalanceAdjustment(
        snap("active", 10000),
        snap("partial", 7500),
    )).toBe(0);
  });

  test("partial → disputed", () => {
    expect(calculateBalanceAdjustment(
        snap("partial", 5000),
        snap("disputed", 5000),
    )).toBe(0);
  });

  test("already terminal before (written_off) — skip to prevent double-run", () => {
    expect(calculateBalanceAdjustment(
        snap("written_off", 0),
        snap("written_off", 0),
    )).toBe(0);
  });

  test("already terminal before (cancelled) — skip", () => {
    expect(calculateBalanceAdjustment(
        snap("cancelled", 8000),
        snap("cancelled", 8000),
    )).toBe(0);
  });
});

// ─── write-off ────────────────────────────────────────────────────────────────

describe("written_off", () => {
  test("full remaining balance is the adjustment", () => {
    expect(calculateBalanceAdjustment(
        snap("active", 12500),
        snap("written_off", 0),
    )).toBe(12500);
  });

  test("partial debt written off", () => {
    expect(calculateBalanceAdjustment(
        snap("partial", 7000),
        snap("written_off", 0),
    )).toBe(7000);
  });

  test("overdue debt written off", () => {
    expect(calculateBalanceAdjustment(
        snap("overdue", 3000),
        snap("written_off", 0),
    )).toBe(3000);
  });

  test("zero remaining balance → 0 adjustment (nothing to subtract)", () => {
    expect(calculateBalanceAdjustment(
        snap("partial", 0),
        snap("written_off", 0),
    )).toBe(0);
  });
});

// ─── cancel ───────────────────────────────────────────────────────────────────

describe("cancelled", () => {
  test("full remaining balance is the adjustment", () => {
    expect(calculateBalanceAdjustment(
        snap("active", 5000),
        snap("cancelled", 5000), // remainingBalance unchanged by cancel write
    )).toBe(5000);
  });

  test("partially paid debt cancelled", () => {
    expect(calculateBalanceAdjustment(
        snap("partial", 6000),
        snap("cancelled", 6000),
    )).toBe(6000);
  });
});

// ─── settle-for-less ──────────────────────────────────────────────────────────

describe("settled via settleForLess", () => {
  const settlement = {settledAmount: 4000, reason: "negotiated"};

  test("before.remainingBalance is the adjustment", () => {
    // Client writes remainingBalance→0 but no payment was recorded.
    expect(calculateBalanceAdjustment(
        snap("partial", 8000),
        snap("settled", 0, {settlement}),
    )).toBe(8000);
  });

  test("full debt settled for less from active", () => {
    expect(calculateBalanceAdjustment(
        snap("active", 10000),
        snap("settled", 0, {settlement}),
    )).toBe(10000);
  });
});

// ─── settled via normal payment ───────────────────────────────────────────────

describe("settled via normal payment (no adjustment — handled by onPaymentCreated)", () => {
  test("settled without settlement sub-object → 0", () => {
    // No after.settlement means payments covered the balance; onPaymentCreated
    // already decremented customer balance with each payment.
    expect(calculateBalanceAdjustment(
        snap("partial", 2500),
        snap("settled", 0),
    )).toBe(0);
  });

  test("active → settled without settlement sub-object → 0", () => {
    expect(calculateBalanceAdjustment(
        snap("active", 10000),
        snap("settled", 0),
    )).toBe(0);
  });
});
