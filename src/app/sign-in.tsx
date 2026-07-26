import { useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { useSession } from '@/state/session';
import { colours, radii, spacing } from '@/theme/tokens';

export default function SignInScreen() {
  const { signIn } = useSession();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit() {
    if (busy) return;
    setError(null);
    setBusy(true);
    try {
      await signIn(email, password);
    } catch {
      // Deliberately the same message whether the address is unknown or the
      // password is wrong. Distinguishing them tells an attacker which
      // colleagues have accounts, and FR-AUTH-02 requires that errors do not
      // disclose whether an unrelated account exists.
      setError('Those details did not match an account.');
      setBusy(false);
    }
  }

  const canSubmit = email.trim() !== '' && password !== '' && !busy;

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.content}>
        <View style={styles.brandRow}>
          <View style={styles.mark}>
            <Text style={styles.markText}>E</Text>
          </View>
          <Text style={styles.brand}>EMPLOYEE OF THE MONTH</Text>
        </View>

        <Text style={styles.title}>Sign in</Text>
        <Text style={styles.subtitle}>
          Use the email address your organisation invited.
        </Text>

        <View style={styles.field}>
          <Text style={styles.label} nativeID="email-label">
            Email address
          </Text>
          <TextInput
            accessibilityLabel="Email address"
            accessibilityLabelledBy="email-label"
            autoCapitalize="none"
            autoComplete="email"
            autoCorrect={false}
            inputMode="email"
            onChangeText={setEmail}
            onSubmitEditing={submit}
            placeholder="you@company.co.uk"
            placeholderTextColor={colours.inkMuted}
            style={styles.input}
            value={email}
          />
        </View>

        <View style={styles.field}>
          <Text style={styles.label} nativeID="password-label">
            Password
          </Text>
          <TextInput
            accessibilityLabel="Password"
            accessibilityLabelledBy="password-label"
            autoCapitalize="none"
            autoComplete="current-password"
            onChangeText={setPassword}
            onSubmitEditing={submit}
            placeholder="At least 12 characters"
            placeholderTextColor={colours.inkMuted}
            secureTextEntry
            style={styles.input}
            value={password}
          />
        </View>

        {error ? (
          // role=alert so a screen reader announces the failure rather than
          // leaving it to be discovered visually.
          <View accessibilityRole="alert" style={styles.errorBox}>
            <Text style={styles.errorText}>{error}</Text>
          </View>
        ) : null}

        <Pressable
          accessibilityLabel="Sign in"
          accessibilityRole="button"
          accessibilityState={{ busy, disabled: !canSubmit }}
          disabled={!canSubmit}
          onPress={submit}
          style={({ pressed }) => [
            styles.primaryButton,
            !canSubmit && styles.primaryButtonDisabled,
            pressed && styles.primaryButtonPressed,
          ]}
        >
          {busy ? (
            <ActivityIndicator color={colours.ink} />
          ) : (
            <Text style={styles.primaryButtonText}>Sign in</Text>
          )}
        </Pressable>

        <Text style={styles.footnote}>
          Your nomination is confidential. Administrators see the result and how
          many people voted, never who voted for whom.
        </Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: { backgroundColor: colours.canvas, flex: 1 },
  content: {
    flex: 1,
    justifyContent: 'center',
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.xxl,
  },
  brandRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
    marginBottom: spacing.xxl,
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
  title: {
    color: colours.ink,
    fontSize: 38,
    fontWeight: '800',
    letterSpacing: -1.4,
  },
  subtitle: {
    color: colours.inkMuted,
    fontSize: 16,
    lineHeight: 24,
    marginTop: spacing.sm,
  },
  field: { marginTop: spacing.lg },
  label: {
    color: colours.ink,
    fontSize: 13,
    fontWeight: '700',
    marginBottom: spacing.sm,
  },
  input: {
    backgroundColor: colours.surface,
    borderColor: colours.line,
    borderRadius: radii.md,
    borderWidth: 1,
    color: colours.ink,
    fontSize: 16,
    // 58 rather than the 48dp minimum: this is the primary path into the
    // product and is often used one-handed on site.
    minHeight: 58,
    paddingHorizontal: spacing.md,
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
  primaryButton: {
    alignItems: 'center',
    backgroundColor: colours.lime,
    borderRadius: radii.md,
    justifyContent: 'center',
    marginTop: spacing.lg,
    minHeight: 58,
  },
  primaryButtonDisabled: { opacity: 0.45 },
  primaryButtonPressed: { opacity: 0.82 },
  primaryButtonText: { color: colours.ink, fontSize: 16, fontWeight: '800' },
  footnote: {
    color: colours.inkMuted,
    fontSize: 13,
    lineHeight: 20,
    marginTop: spacing.xl,
  },
});
