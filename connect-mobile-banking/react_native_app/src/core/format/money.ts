// Amounts and dates as the web app writes them (web/lib.js gbp, day, longDay, monthName), without relying on the
// JavaScript engine's locale data, so every phone shows the same.

const MINUS = '−'; // a real minus sign, as the web app uses

function grouped(whole: number): string {
  return String(whole).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

// £1,234.50, or −£32.45 for a negative amount.
export function gbp(value: number | string): string {
  const n = Number(value) || 0;
  const pence = Math.round(Math.abs(n) * 100);
  const text = `£${grouped(Math.floor(pence / 100))}.${String(pence % 100).padStart(2, '0')}`;
  return n < 0 && pence > 0 ? `${MINUS}${text}` : text;
}

// Whole pounds: £1,050.
export function pounds(value: number | string): string {
  const n = Math.round(Number(value) || 0);
  return `${n < 0 ? MINUS : ''}£${grouped(Math.abs(n))}`;
}

// +£3,150.00 for money in, −£32.45 for money out.
export function signed(amount: number, moneyIn = amount > 0): string {
  return `${moneyIn ? '+' : MINUS}${gbp(Math.abs(amount))}`;
}

const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

function parts(iso: string): { y: number; m: number; d: number } {
  const [y, m, d] = String(iso).split('-').map(Number);
  return { y, m: m || 1, d: d || 1 };
}

// "15 Oct"
export const day = (iso: string): string => {
  const { m, d } = parts(iso);
  return `${d} ${MONTHS[m - 1].slice(0, 3)}`;
};

// "15 October"
export const dayMonth = (iso: string): string => {
  const { m, d } = parts(iso);
  return `${d} ${MONTHS[m - 1]}`;
};

// "Thursday 15 October 2026"
export const longDay = (iso: string): string => {
  const { y, m, d } = parts(iso);
  const weekday = new Date(Date.UTC(y, m - 1, d, 12)).getUTCDay();
  return `${DAYS[weekday]} ${d} ${MONTHS[m - 1]} ${y}`;
};

// "2026-10" -> "October 2026"; short: "Oct"
export const monthName = (key: string, short = false): string => {
  const { y, m } = parts(`${key}-15`);
  return short ? MONTHS[m - 1].slice(0, 3) : `${MONTHS[m - 1]} ${y}`;
};

export const tidyMerchant = (name: string): string =>
  String(name || '')
    .toLowerCase()
    .replace(/(^|[\s/-])([a-z])/g, (_, gap: string, c: string) => gap + c.toUpperCase());

// Two letters for a merchant's tile: "Pret A Manger" -> "PA".
export function initials(name: string): string {
  const words = tidyMerchant(name).replace(/[^A-Za-z ]/g, ' ').split(/\s+/).filter(Boolean);
  return (words.length > 1 ? words[0][0] + words[1][0] : (words[0] || '?').slice(0, 2)).toUpperCase();
}
