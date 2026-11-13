// The screens: five tabs (Home, Accounts, Cards, Money Hub, More), and the rest stacked over them.
import React from 'react';
import { Text, View } from 'react-native';
import {
  BottomTabBar,
  BottomTabBarProps,
  createBottomTabNavigator,
} from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { useTheme } from '../../core/theme/theme';
import { AccountsScreen } from '../../features/accounts/presentation/AccountsScreen';
import { FormScreen } from '../../features/assistant/presentation/FormScreen';
import { CardsScreen } from '../../features/cards/presentation/CardsScreen';
import { HelpScreen } from '../../features/help/presentation/HelpScreen';
import { HomeScreen } from '../../features/home/presentation/HomeScreen';
import { MoneyHubScreen } from '../../features/money_hub/presentation/MoneyHubScreen';
import { MortgagesScreen } from '../../features/mortgages/presentation/MortgagesScreen';
import { NotificationsScreen } from '../../features/notifications/presentation/NotificationsScreen';
import { MoreScreen } from '../../features/settings/presentation/MoreScreen';
import { SettingsScreen } from '../../features/settings/presentation/SettingsScreen';
import { TransactionDetailScreen } from '../../features/transactions/presentation/TransactionDetailScreen';
import { TransactionsScreen } from '../../features/transactions/presentation/TransactionsScreen';
import type { RootParams, TabParams } from './routes';
import { setTabBarHeight } from './tabBarHeight';

const Tab = createBottomTabNavigator<TabParams>();
const Stack = createNativeStackNavigator<RootParams>();

const ICONS: Record<keyof TabParams, string> = {
  Home: '🏠',
  Accounts: '💼',
  Cards: '💳',
  MoneyHub: '📊',
  More: '☰',
};

function TabIcon({
  name,
  focused,
}: {
  name: keyof TabParams;
  focused: boolean;
}) {
  return (
    <Text style={{ fontSize: 20, opacity: focused ? 1 : 0.55 }}>
      {ICONS[name]}
    </Text>
  );
}

const tabIcon =
  (name: keyof TabParams) =>
  ({ focused }: { focused: boolean }) =>
    <TabIcon name={name} focused={focused} />;

// The standard tab bar, measured, so the assistant can sit above it.
function MeasuredTabBar(props: BottomTabBarProps) {
  return (
    <View onLayout={event => setTabBarHeight(event.nativeEvent.layout.height)}>
      <BottomTabBar {...props} />
    </View>
  );
}

const tabBar = (props: BottomTabBarProps) => <MeasuredTabBar {...props} />;

function Tabs() {
  const { c } = useTheme();
  return (
    <Tab.Navigator
      tabBar={tabBar}
      screenOptions={({ route }) => ({
        headerStyle: { backgroundColor: c.brand },
        headerTintColor: '#fff',
        headerTitleStyle: { fontWeight: '700' },
        headerShadowVisible: false,
        tabBarActiveTintColor: c.brand2,
        tabBarInactiveTintColor: c.muted,
        tabBarStyle: { backgroundColor: c.card, borderTopColor: c.line },
        tabBarLabelStyle: { fontSize: 11, fontWeight: '600' },
        tabBarIcon: tabIcon(route.name),
      })}
    >
      <Tab.Screen
        name="Home"
        component={HomeScreen}
        options={{ title: 'Home', headerTitle: 'Nationwide' }}
      />
      <Tab.Screen name="Accounts" component={AccountsScreen} />
      <Tab.Screen name="Cards" component={CardsScreen} />
      <Tab.Screen
        name="MoneyHub"
        component={MoneyHubScreen}
        options={{ title: 'Money Hub' }}
      />
      <Tab.Screen name="More" component={MoreScreen} />
    </Tab.Navigator>
  );
}

export function RootNavigator() {
  const { c } = useTheme();
  return (
    <Stack.Navigator
      screenOptions={{
        headerStyle: { backgroundColor: c.brand },
        headerTintColor: '#fff',
        headerTitleStyle: { fontWeight: '700' },
        headerShadowVisible: false,
        headerBackButtonDisplayMode: 'minimal',
        contentStyle: { backgroundColor: c.bg },
        // White clock and battery on the navy header. The native stack owns the status bar on iOS (the app's
        // <StatusBar> is ignored while UIViewControllerBasedStatusBarAppearance is on).
        statusBarStyle: 'light',
      }}
    >
      <Stack.Screen
        name="Tabs"
        component={Tabs}
        options={{ headerShown: false }}
      />
      <Stack.Screen name="Transactions" component={TransactionsScreen} />
      <Stack.Screen
        name="TransactionDetail"
        component={TransactionDetailScreen}
        options={{ title: 'Payment' }}
      />
      <Stack.Screen name="Mortgages" component={MortgagesScreen} />
      <Stack.Screen
        name="Help"
        component={HelpScreen}
        options={{ title: 'Help and FAQs' }}
      />
      <Stack.Screen name="Notifications" component={NotificationsScreen} />
      <Stack.Screen name="Settings" component={SettingsScreen} />
      <Stack.Screen
        name="Form"
        component={FormScreen}
        options={({ route }) => ({
          title:
            route.params.kind === 'mortgage'
              ? 'Mortgage application'
              : 'Your dispute',
        })}
      />
    </Stack.Navigator>
  );
}
