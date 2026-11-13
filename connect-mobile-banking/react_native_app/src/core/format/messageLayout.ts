// How an assistant message is laid out for reading on a phone: one sentence per line, lists as lists, the closing
// question on its own, the advice disclaimer small. A port of the web widget's format.js; plain data, drawn as text.

export type Block =
  | { kind: 'line' | 'ask' | 'note'; text: string }
  | { kind: 'list'; lead: string; items: string[]; ordered: boolean };

const BULLET = /^\s*(?:[-*•–]|(\d+)[.)])\s+(.*)$/;
const SENTENCE_END = /(?<=[.!?])\s+(?=[A-Z£0-9"'‘“(])/;
const NOTE = /^this is guidance based on your past spending/i;
const LEAD = /^(.*?\b(?:are|were|is|was|include|includes|including)\b)\s+(.+?)[.!]?$/i;

// Markdown emphasis and headings shown as plain text (talk.js plain, format.js tidy).
export const plain = (text: string): string => String(text).replace(/(\*\*|__)(.+?)\1/g, '$2');
const tidy = (text: string) => plain(text).replace(/^#+\s*/, '').trim();
const capital = (text: string) => text.charAt(0).toUpperCase() + text.slice(1);

function asList(sentence: string): Block | null {
  if ((sentence.match(/£/g) || []).length < 3) return null;
  const found = sentence.match(LEAD);
  if (!found) return null;
  const items = found[2]
    .split(/,\s*(?:and\s+)?|\s+and\s+(?=[^,]*£[^,]*$)/)
    .map((item) => item.trim())
    .filter(Boolean);
  if (items.length < 3 || !items.every((item) => item.includes('£'))) return null;
  const lead = found[1].replace(/\s+(?:are|were|is|was)$/i, '');
  return {
    kind: 'list',
    lead: `${lead}:`,
    ordered: false,
    items: items.map((item) => capital(item.replace(/\s+at\s+(£[\d,]+(?:\.\d{2})?)/, ': $1'))),
  };
}

export function layout(words: string): Block[] {
  const blocks: Block[] = [];
  let list: Extract<Block, { kind: 'list' }> | null = null;
  for (const raw of String(words || '').split(/\n/)) {
    const line = tidy(raw);
    if (!line) {
      list = null;
      continue;
    }
    const bullet = line.match(BULLET);
    if (bullet) {
      if (!list) {
        const before = blocks[blocks.length - 1];
        const lead = before && before.kind === 'line' && before.text.endsWith(':') ? (blocks.pop() as { text: string }).text : '';
        list = { kind: 'list', lead, items: [], ordered: Boolean(bullet[1]) };
        blocks.push(list);
      }
      list.items.push(tidy(bullet[2]));
      continue;
    }
    list = null;
    for (const sentence of line.split(SENTENCE_END).map((s) => s.trim()).filter(Boolean)) {
      const asItems = asList(sentence);
      if (asItems) blocks.push(asItems);
      else if (NOTE.test(sentence)) blocks.push({ kind: 'note', text: sentence });
      else blocks.push({ kind: 'line', text: sentence });
    }
  }
  for (let i = blocks.length - 1; i >= 0; i--) {
    const block = blocks[i];
    if (block.kind === 'note') continue;
    if (block.kind === 'line' && block.text.endsWith('?')) blocks[i] = { kind: 'ask', text: block.text };
    break;
  }
  return blocks;
}

// Text split into plain parts and £ amounts, so amounts can be bold.
export function amounts(text: string): { text: string; amount: boolean }[] {
  return String(text)
    .split(/(£[\d,]+(?:\.\d{1,2})?)/)
    .filter(Boolean)
    .map((part) => ({ text: part, amount: part.startsWith('£') }));
}
