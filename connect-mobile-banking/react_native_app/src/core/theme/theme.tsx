// The internet banking web app's colours (web/styles.css; CONTRACT.md section 11), light and dark, following the
// phone's setting.
import React, { createContext, useContext, useMemo } from 'react';
import { useColorScheme } from 'react-native';

export type Palette = {
  brand: string;
  brand2: string;
  onBrand: string;
  accent: string;
  ink: string;
  muted: string;
  line: string;
  bg: string;
  card: string;
  soft: string;
  moneyIn: string;
  moneyInSoft: string;
  moneyOut: string;
  moneyOutSoft: string;
  flexible: string;
  flexibleSoft: string;
  essential: string;
  essentialSoft: string;
  savings: string;
  savingsSoft: string;
  creditCard: string;
};

const light: Palette = {
  brand: '#1a2b5f',
  brand2: '#2a3f86',
  onBrand: '#ffffff',
  accent: '#e8edf9',
  ink: '#101631',
  muted: '#5d6482',
  line: '#e5e8f2',
  bg: '#f3f5fb',
  card: '#ffffff',
  soft: '#f6f7fc',
  moneyIn: '#0f8a66',
  moneyInSoft: '#e5f5ef',
  moneyOut: '#c63d3d',
  moneyOutSoft: '#fbeaea',
  flexible: '#e08a1e',
  flexibleSoft: '#fdf1e1',
  essential: '#4864e6',
  essentialSoft: '#e9edfd',
  savings: '#7b5cff',
  savingsSoft: '#efeafe',
  creditCard: '#4a2d6e',
};

const dark: Palette = {
  brand: '#2a3f86',
  brand2: '#3a52a8',
  onBrand: '#ffffff',
  accent: '#1b2242',
  ink: '#e8ebf7',
  muted: '#9aa1bd',
  line: '#2a3150',
  bg: '#0d1226',
  card: '#151b34',
  soft: '#1b2242',
  moneyIn: '#34c294',
  moneyInSoft: '#12352c',
  moneyOut: '#f07a7a',
  moneyOutSoft: '#3a1c22',
  flexible: '#f2a64a',
  flexibleSoft: '#3a2a14',
  essential: '#7d93ff',
  essentialSoft: '#1d2650',
  savings: '#a48cff',
  savingsSoft: '#261f49',
  creditCard: '#5b3a85',
};

export type Theme = {
  dark: boolean;
  c: Palette;
  radius: number;
  space: (n: number) => number;
  font: { title: number; heading: number; body: number; small: number; tiny: number; amount: number };
};

const build = (isDark: boolean): Theme => ({
  dark: isDark,
  c: isDark ? dark : light,
  radius: 16,
  space: (n) => n * 4,
  font: { title: 26, heading: 18, body: 16, small: 14, tiny: 12, amount: 30 },
});

const ThemeContext = createContext<Theme>(build(false));

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const scheme = useColorScheme();
  const theme = useMemo(() => build(scheme === 'dark'), [scheme]);
  return <ThemeContext.Provider value={theme}>{children}</ThemeContext.Provider>;
}

export const useTheme = () => useContext(ThemeContext);
