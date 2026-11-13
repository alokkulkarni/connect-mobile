// The whole app renders in Sample mode, from sign-in to Home, with every native module mocked (jest.setup.js).
import React from 'react';
import ReactTestRenderer, { act } from 'react-test-renderer';
import App from './App';
import type { Session, SessionRepository } from '../features/session/domain/session';

function memory(session: Session | null): SessionRepository {
  let stored = session;
  return {
    load: async () => stored,
    save: async (s) => {
      stored = s;
    },
    clear: async () => {
      stored = null;
    },
  };
}

const texts = (tree: ReactTestRenderer.ReactTestRenderer): string =>
  tree.root
    .findAll((node) => (node.type as unknown) === 'Text')
    .map((node) => node.props.children)
    .flat(Infinity)
    .filter((c: unknown) => typeof c === 'string')
    .join(' | ');

async function settle() {
  for (let i = 0; i < 10; i++) {
    await act(async () => {
      await new Promise<void>((resolve) => setTimeout(resolve, 0));
    });
  }
}

test('shows sign-in when there is no session', async () => {
  let tree!: ReactTestRenderer.ReactTestRenderer;
  await act(async () => {
    tree = ReactTestRenderer.create(<App repository={memory(null)} />);
  });
  await settle();
  expect(texts(tree)).toContain('Open your internet banking');
  expect(texts(tree)).toContain('Explore with sample data');
  await act(async () => tree.unmount());
});

test('opens Home with the sample customer in Sample mode', async () => {
  let tree!: ReactTestRenderer.ReactTestRenderer;
  await act(async () => {
    tree = ReactTestRenderer.create(<App repository={memory({ mode: 'sample' })} />);
  });
  await settle();
  const shown = texts(tree);
  expect(shown).toContain('Demo · sample data');
  expect(shown).toContain('Total in your accounts');
  expect(shown).toMatch(/Good (morning|afternoon|evening), James/);
  expect(shown).toContain('Ask us anything');
  await act(async () => tree.unmount());
});
