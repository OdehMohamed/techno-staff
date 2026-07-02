/* eslint-env jest */
// Unit tests for pure helper functions in payment-triggers.js.
// No Firestore emulator required — helpers are side-effect-free.

const {
  recalculateDebtStatus,
  formatReceiptNumber,
  currentYearJerusalem,
  formatAgorot,
  validatePaymentAgainstDebt,
} = require("../../lib/collections/payment-triggers");

// ─── recalculateDebtStatus ────────────────────────────────────────────────────

describe("recalculateDebtStatus", () => {
  const futureDate = {toDate: () => new Date(Date.now() + 86400000 * 30)};
  const pastDate = {toDate: () => new Date(Date.now() - 86400000)};

  test("settled when remainingBalance is 0", () => {
    expect(recalculateDebtStatus(5000, 0, futureDate)).toBe("settled");
    expect(recalculateDebtStatus(5000, 0, pastDate)).toBe("settled");
    expect(recalculateDebtStatus(5000, 0, null)).toBe("settled");
  });

  test("active when no payments made and not overdue", () => {
    expect(recalculateDebtStatus(0, 10000, futureDate)).toBe("active");
  });

  test("active when no payments made and no due date", () => {
    expect(recalculateDebtStatus(0, 10000, null)).toBe("active");
  });

  test("overdue when no payments made and past due", () => {
    expect(recalculateDebtStatus(0, 10000, pastDate)).toBe("overdue");
  });

  test("partial when some paid and not overdue", () => {
    expect(recalculateDebtStatus(3000, 7000, futureDate)).toBe("partial");
  });

  test("overdue when some paid but past due", () => {
    expect(recalculateDebtStatus(3000, 7000, pastDate)).toBe("overdue");
  });

  test("partial when some paid and no due date", () => {
    expect(recalculateDebtStatus(3000, 7000, null)).toBe("partial");
  });
});

// ─── formatReceiptNumber ──────────────────────────────────────────────────────

describe("formatReceiptNumber", () => {
  test("pads single-digit number to 5 places", () => {
    expect(formatReceiptNumber("RCPT", 2026, 1)).toBe("RCPT-2026-00001");
  });

  test("pads multi-digit number correctly", () => {
    expect(formatReceiptNumber("RCPT", 2026, 42)).toBe("RCPT-2026-00042");
  });

  test("handles 5-digit number without padding", () => {
    expect(formatReceiptNumber("RCPT", 2026, 99999)).toBe("RCPT-2026-99999");
  });

  test("uses custom prefix", () => {
    expect(formatReceiptNumber("INV", 2025, 7)).toBe("INV-2025-00007");
  });

  test("year rollover: new year resets to 1", () => {
    // Year 2027 first receipt
    expect(formatReceiptNumber("RCPT", 2027, 1)).toBe("RCPT-2027-00001");
  });
});

// ─── currentYearJerusalem ─────────────────────────────────────────────────────

describe("currentYearJerusalem", () => {
  test("returns a 4-digit year", () => {
    const year = currentYearJerusalem();
    expect(year).toBeGreaterThanOrEqual(2024);
    expect(year).toBeLessThanOrEqual(2100);
    expect(Number.isInteger(year)).toBe(true);
  });
});

// ─── formatAgorot ─────────────────────────────────────────────────────────────

describe("formatAgorot", () => {
  test("formats zero", () => {
    expect(formatAgorot(0)).toBe("₪0.00");
  });

  test("formats whole shekels", () => {
    expect(formatAgorot(500)).toBe("₪5.00");
  });

  test("formats shekels with agorot", () => {
    expect(formatAgorot(1250)).toBe("₪12.50");
  });

  test("formats large amount", () => {
    expect(formatAgorot(1000000)).toBe("₪10000.00");
  });

  test("formats 1 agora", () => {
    expect(formatAgorot(1)).toBe("₪0.01");
  });
});

// ─── validatePaymentAgainstDebt ───────────────────────────────────────────────

describe("validatePaymentAgainstDebt", () => {
  test("valid exact payment equals remaining balance", () => {
    const result = validatePaymentAgainstDebt(5000, 5000, "active");
    expect(result).toEqual({valid: true, reason: null});
  });

  test("valid partial payment less than remaining balance", () => {
    const result = validatePaymentAgainstDebt(3000, 5000, "active");
    expect(result).toEqual({valid: true, reason: null});
  });

  test("valid payment on overdue debt", () => {
    const result = validatePaymentAgainstDebt(2000, 10000, "overdue");
    expect(result).toEqual({valid: true, reason: null});
  });

  test("valid payment on partial debt", () => {
    const result = validatePaymentAgainstDebt(1000, 4000, "partial");
    expect(result).toEqual({valid: true, reason: null});
  });

  test("invalid: overpayment exceeds remaining balance", () => {
    const result = validatePaymentAgainstDebt(6000, 5000, "active");
    expect(result).toEqual({valid: false, reason: "overpayment"});
  });

  test("invalid: payment on settled debt", () => {
    const result = validatePaymentAgainstDebt(1000, 0, "settled");
    expect(result).toEqual({valid: false, reason: "debt_terminal"});
  });

  test("invalid: payment on cancelled debt", () => {
    const result = validatePaymentAgainstDebt(1000, 5000, "cancelled");
    expect(result).toEqual({valid: false, reason: "debt_terminal"});
  });

  test("invalid: payment on written_off debt", () => {
    const result = validatePaymentAgainstDebt(1000, 5000, "written_off");
    expect(result).toEqual({valid: false, reason: "debt_terminal"});
  });

  test("terminal check takes priority over overpayment", () => {
    const result = validatePaymentAgainstDebt(99999, 0, "settled");
    expect(result).toEqual({valid: false, reason: "debt_terminal"});
  });
});
