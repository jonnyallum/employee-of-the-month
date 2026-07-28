import { useLocalSearchParams, useRouter } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { getSupabaseClient } from '@/lib/supabase';
import { useSession } from '@/state/session';
import { colours, radii, spacing } from '@/theme/tokens';

/**
 * Wording for every way an invitation can fail.
 *
 * The database returns a stable product code in `hint`, so none of this matches
 * on message text. `invitation_wrong_email` deliberately does not say which
 * address was invited: whoever is holding this link may not be the person it was
 * sent to, and naming the recipient would tell an interceptor who works there.
 */
const REFUSALS: Record<string, string> = {
  invitation_invalid:
    'This invitation link is not valid. Ask your administrator to send a new one.',
  invitation_expired:
    'This invitation has expired. Ask your administrator to send a new one.',
  invitation_consumed:
    'This invitation has already been used. Try signing in instead.',
  invitation_revoked:
    'This invitation was withdrawn. Ask your administrator if that was a mistake.',
  invitation_wrong_email:
    'This invitation was sent to a different email address. Sign in with the address it was sent to.',
  email_not_verified:
    'Verify your email address first, then open this link again.',
  already_member: 'You are already part of this organisation.',
  already_linked:
    'That place on the roster has already been claimed by another account.',
};

type Stage = 'checking' | 'needs-account' | 'accepting' | 'done' | 'refused';

export default function InviteScreen() {
  const { token } = useLocalSearchParams<{ token?: string }>();
  const { session, signIn, signUp } = useSession();
  const router = useRouter();

  const [stage, setStage] = useState<Stage>('checking');
  const [message, setMessage] = useState<string | null>(null);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [mode, setMode] = useState<'create' | 'signin'>('create');
  const [busy, setBusy] = useState(false);

  const accept = useCallback(async () => {
    if (!token) {
      setStage('refused');
      setMessage('This link is missing its invitation code.');
      return;
    }
    setStage('accepting');
    const client = getSupabaseClient();
    const { error } = await client.rpc('accept_invitation', { token });

    if (error) {
      const hint = (error as { hint?: string }).hint ?? '';
      setStage('refused');
      setMessage(
        REFUSALS[hint] ?? 'This invitation could not be accepted right now.',
      );
      return;
    }
    setStage('done');
  }, [token]);

  useEffect(() => {
    if (!token) {
      setStage('refused');
      setMessage('This link is missing its invitation code.');
      return;
    }
    // Accepting is only possible once there is an account. Somebody arriving
    // from the email usually has neither an account nor a session.
    if (session) void accept();
    else setStage('needs-account');
  }, [session, token, accept]);

  async function authenticate() {
    if (busy) return;
    setBusy(true);
    setMessage(null);
    try {
      if (mode === 'create') await signUp(email, password);
      else await signIn(email, password);
      // The session change re-runs the effect above, which accepts.
    } catch (caught) {
      const text =
        caught instanceof Error ? caught.message : 'Something went wrong.';
      setMessage(
        mode === 'create'
          ? // Supabase's own message is shown for sign-up because it explains
            // password rules the user must satisfy. Sign-in stays deliberately
            // vague, since there the message would reveal whether an account
            // exists.
            text
          : 'Those details did not match an account.',
      );
      setBusy(false);
    }
  }

  return (
    <SafeAreaView style={styles.safeArea}>
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.brandRow}>
          <View style={styles.mark}>
            <Text style={styles.markText}>E</Text>
          </View>
          <Text style={styles.brand}>EMPLOYEE OF THE MONTH</Text>
        </View>

        {stage === 'checking' || stage === 'accepting' ? (
          <View style={styles.centreBlock}>
            <ActivityIndicator color={colours.forest} />
            <Text style={styles.body}>Checking your invitation…</Text>
          </View>
        ) : null}

        {stage === 'done' ? (
          <>
            <Text style={styles.title}>You are in.</Text>
            <Text style={styles.body}>
              You can now take part in your team's recognition month. Your
              nomination is confidential: administrators see the result and how
              many people voted, never who voted for whom.
            </Text>
            <Pressable
              accessibilityLabel="Continue"
              accessibilityRole="button"
              onPress={() => router.replace('/')}
              style={({ pressed }) => [
                styles.button,
                pressed && styles.pressed,
              ]}
            >
              <Text style={styles.buttonText}>Continue</Text>
            </Pressable>
          </>
        ) : null}

        {stage === 'refused' ? (
          <>
            <Text style={styles.title}>This link did not work</Text>
            <View accessibilityRole="alert" style={styles.errorBox}>
              <Text style={styles.errorText}>{message}</Text>
            </View>
            <Pressable
              accessibilityLabel="Go to sign in"
              accessibilityRole="button"
              onPress={() => router.replace('/sign-in')}
              style={({ pressed }) => [
                styles.button,
                pressed && styles.pressed,
              ]}
            >
              <Text style={styles.buttonText}>Go to sign in</Text>
            </Pressable>
          </>
        ) : null}

        {stage === 'needs-account' ? (
          <>
            <Text style={styles.title}>You have been invited</Text>
            <Text style={styles.body}>
              {mode === 'create'
                ? 'Create an account with the email address your invitation was sent to.'
                : 'Sign in with the email address your invitation was sent to.'}
            </Text>

            <Text style={styles.label}>Email address</Text>
            <TextInput
              accessibilityLabel="Email address"
              autoCapitalize="none"
              autoComplete="email"
              autoCorrect={false}
              inputMode="email"
              onChangeText={setEmail}
              placeholder="you@company.co.uk"
              placeholderTextColor={colours.inkMuted}
              style={styles.input}
              value={email}
            />

            <Text style={styles.label}>Password</Text>
            <TextInput
              accessibilityLabel="Password"
              autoCapitalize="none"
              onChangeText={setPassword}
              placeholder="At least 12 characters"
              placeholderTextColor={colours.inkMuted}
              secureTextEntry
              style={styles.input}
              value={password}
            />

            {message ? (
              <View accessibilityRole="alert" style={styles.errorBox}>
                <Text style={styles.errorText}>{message}</Text>
              </View>
            ) : null}

            <Pressable
              accessibilityLabel={
                mode === 'create'
                  ? 'Create account and accept'
                  : 'Sign in and accept'
              }
              accessibilityRole="button"
              accessibilityState={{ busy }}
              disabled={busy || email.trim() === '' || password === ''}
              onPress={() => void authenticate()}
              style={({ pressed }) => [
                styles.button,
                (busy || email.trim() === '' || password === '') &&
                  styles.buttonDisabled,
                pressed && styles.pressed,
              ]}
            >
              {busy ? (
                <ActivityIndicator color={colours.ink} />
              ) : (
                <Text style={styles.buttonText}>
                  {mode === 'create'
                    ? 'Create account and accept'
                    : 'Sign in and accept'}
                </Text>
              )}
            </Pressable>

            <Pressable
              accessibilityLabel={
                mode === 'create'
                  ? 'I already have an account'
                  : 'I need to create an account'
              }
              accessibilityRole="button"
              onPress={() => {
                setMode(mode === 'create' ? 'signin' : 'create');
                setMessage(null);
              }}
            >
              <Text style={styles.switchMode}>
                {mode === 'create'
                  ? 'I already have an account'
                  : 'I need to create an account'}
              </Text>
            </Pressable>
          </>
        ) : null}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: { backgroundColor: colours.canvas, flex: 1 },
  content: {
    flexGrow: 1,
    justifyContent: 'center',
    paddingBottom: spacing.xxl,
    paddingHorizontal: spacing.lg,
  },
  brandRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
    marginBottom: spacing.xl,
  },
  mark: {
    alignItems: 'center',
    backgroundColor: colours.forest,
    borderRadius: radii.sm,
    height: 32,
    justifyContent: 'center',
    width: 32,
  },
  markText: { color: colours.lime, fontSize: 17, fontWeight: '800' },
  brand: {
    color: colours.ink,
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 1.5,
  },
  centreBlock: { alignItems: 'center', gap: spacing.md },
  title: {
    color: colours.ink,
    fontSize: 34,
    fontWeight: '800',
    letterSpacing: -1.4,
  },
  body: {
    color: colours.inkMuted,
    fontSize: 16,
    lineHeight: 24,
    marginTop: spacing.sm,
  },
  label: {
    color: colours.ink,
    fontSize: 13,
    fontWeight: '700',
    marginBottom: spacing.sm,
    marginTop: spacing.lg,
  },
  input: {
    backgroundColor: colours.surface,
    borderColor: colours.line,
    borderRadius: radii.md,
    borderWidth: 1,
    color: colours.ink,
    fontSize: 16,
    minHeight: 58,
    paddingHorizontal: spacing.md,
  },
  button: {
    alignItems: 'center',
    backgroundColor: colours.lime,
    borderRadius: radii.md,
    justifyContent: 'center',
    marginTop: spacing.lg,
    minHeight: 58,
  },
  buttonDisabled: { opacity: 0.45 },
  buttonText: { color: colours.ink, fontSize: 16, fontWeight: '800' },
  pressed: { opacity: 0.82 },
  switchMode: {
    color: colours.moss,
    fontSize: 14,
    fontWeight: '700',
    paddingVertical: spacing.md,
    textAlign: 'center',
  },
  errorBox: {
    backgroundColor: '#FBE9E7',
    borderColor: '#E5A99B',
    borderRadius: radii.sm,
    borderWidth: 1,
    marginTop: spacing.md,
    padding: spacing.md,
  },
  errorText: { color: '#7A2E1D', fontSize: 14, lineHeight: 20 },
});
