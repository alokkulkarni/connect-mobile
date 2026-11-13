// Mortgage products, and the mortgage form's bridge message (CONTRACT.md section 9): the form page's "Call us"
// asks the app to start a call joined to that form.

export type Product = { id: string; name: string; fixedTermYears: number; rate: number; fee: number; maxLtv: number };

export interface MortgagesRepository {
  products(): Promise<Product[]>;
}

export const MORTGAGE_STAGES = ['about_you', 'property_loan', 'dip_result', 'product_selection', 'documents', 'review_submit'] as const;
export type MortgageStage = (typeof MORTGAGE_STAGES)[number];
const APPLICATION_ID = /^MA-[A-HJ-NP-Z2-9]{8}$/;

// The page's startCall({applicationId, stage}), checked; null if anything is wrong.
export function parseStartCall(message: unknown): { applicationId: string; stage: MortgageStage } | null {
  let value: unknown = message;
  if (typeof value === 'string') {
    try {
      value = JSON.parse(value);
    } catch {
      return null;
    }
  }
  if (!value || typeof value !== 'object') return null;
  const { applicationId, stage } = value as Record<string, unknown>;
  if (typeof applicationId !== 'string' || !APPLICATION_ID.test(applicationId)) return null;
  if (typeof stage !== 'string' || !(MORTGAGE_STAGES as readonly string[]).includes(stage)) return null;
  return { applicationId, stage: stage as MortgageStage };
}

// What a monthly repayment would be, as an illustration on the products list (repayment mortgage).
export function monthlyRepayment(loan: number, ratePercent: number, years: number): number {
  const r = ratePercent / 100 / 12;
  const n = years * 12;
  if (r === 0) return loan / n;
  return (loan * r) / (1 - Math.pow(1 + r, -n));
}
