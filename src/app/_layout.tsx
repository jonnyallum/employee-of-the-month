import { Stack, usePathname, useRouter } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { ActivityIndicator, StyleSheet, View } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { SessionProvider, useSession } from '@/state/session';
import { colours } from '@/theme/tokens';

/**
 * Route guard.
 *
 * This improves the experience and grants nothing. Every screen behind it reads
 * data the database has already scoped to the caller, so a member who somehow
 * reached an address they should not see would still be shown nothing. Removing
 * this guard would be untidy rather than a breach, which is the correct
 * relationship between a client route and a security boundary.
 */
function Guard() {
  const { session, loading } = useSession();
  const router = useRouter();
  const pathname = usePathname();

  const onSignIn = pathname === '/sign-in';

  useEffect(() => {
    // Wait for the stored session to be read, otherwise a returning user is
    // bounced to sign-in for a frame before being sent back again.
    if (loading) return;
    if (!session && !onSignIn) router.replace('/sign-in');
    if (session && onSignIn) router.replace('/');
  }, [loading, session, onSignIn, router]);

  if (loading) {
    return (
      <View style={styles.centre}>
        <ActivityIndicator color={colours.forest} />
      </View>
    );
  }

  return (
    <Stack
      screenOptions={{
        contentStyle: { backgroundColor: colours.canvas },
        headerShown: false,
      }}
    />
  );
}

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <StatusBar style="dark" />
        <SessionProvider>
          <Guard />
        </SessionProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  centre: {
    alignItems: 'center',
    backgroundColor: colours.canvas,
    flex: 1,
    justifyContent: 'center',
  },
});
