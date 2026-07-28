import { Link } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import {
  describePrivacyError,
  exportMyData,
  leaveOrganisation,
  listMyPrivacyRequests,
  loadRetention,
  type PrivacyRequest,
  requestAccountDeletion,
} from '@/features/privacy/api';
import { listMemberships, type Membership } from '@/features/recognition/api';
import { useSession } from '@/state/session';
import { colours, radii, spacing } from '@/theme/tokens';

function retentionSentence(months: number | null): string {
  if (months === null) {
    return 'Your organisation keeps the reasons people wrote indefinitely.';
  }
  return `Your organisation deletes the reasons people wrote ${months} months after a result is announced.`;
}

export default function PrivacyScreen() {
  const { session, signOut } = useSession();
  const [membership, setMembership] = useState<Membership | null>(null);
  const [retention, setRetention] = useState<number | null | undefined>(
    undefined,
  );
  const [requests, setRequests] = useState<PrivacyRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState('');
  const [exported, setExported] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const userId = session?.user.id;
      if (!userId) return;
      const memberships = await listMemberships(userId);
      const mine = memberships[0] ?? null;
      setMembership(mine);
      if (mine) {
        const policy = await loadRetention(mine.organisationId);
        setRetention(policy?.retentionMonths ?? null);
      }
      setRequests(await listMyPrivacyRequests());
    } catch (caught) {
      setError(describePrivacyError(caught));
    } finally {
      setLoading(false);
    }
  }, [session]);

  useEffect(() => {
    void load();
  }, [load]);

  async function run(action: () => Promise<unknown>) {
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      await action();
      await load();
    } catch (caught) {
      setError(describePrivacyError(caught));
    } finally {
      setBusy(false);
    }
  }

  if (loading) {
    return (
      <SafeAreaView style={styles.centre}>
        <ActivityIndicator color={colours.forest} />
      </SafeAreaView>
    );
  }

  const pendingDeletion = requests.find(
    (r) => r.requestType === 'deletion' && r.state !== 'completed',
  );

  return (
    <SafeAreaView style={styles.safeArea}>
      <ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.topRow}>
          <Text style={styles.eyebrow}>YOUR DATA</Text>
          <Link href="/" style={styles.link}>
            Done
          </Link>
        </View>
        <Text style={styles.title}>Privacy</Text>

        {error ? (
          <View accessibilityRole="alert" style={styles.errorBox}>
            <Text style={styles.errorText}>{error}</Text>
          </View>
        ) : null}
        {notice ? (
          <View accessibilityRole="alert" style={styles.noticeBox}>
            <Text style={styles.noticeText}>{notice}</Text>
          </View>
        ) : null}

        {/* The wording here is the same claim the legal draft makes, and it is
            deliberately narrower than "anonymous". The product stores who voted
            in order to enforce one vote; what it does not do is expose it. */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Who can see your nomination</Text>
          <Text style={styles.body}>
            Nobody. Administrators see how many people voted and the result.
            They cannot see who you nominated, and no screen, export or report
            in this app will tell them.
          </Text>
          <Text style={styles.body}>
            We keep an internal record of who voted so that everyone votes once.
            That record is not available to your employer.
          </Text>
          <Text style={styles.emphasis}>
            This is confidential, not anonymous. In a small team it may still be
            possible to work out how somebody voted from the result alone.
          </Text>
        </View>

        {membership && retention !== undefined ? (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>How long things are kept</Text>
            <Text style={styles.body}>{retentionSentence(retention)}</Text>
            <Text style={styles.body}>
              The record that somebody won a month is kept, so past results stay
              accurate.
            </Text>
          </View>
        ) : null}

        <View style={styles.card}>
          <Text style={styles.cardTitle}>Get a copy of your data</Text>
          <Text style={styles.body}>
            Everything we hold about you, including anything colleagues wrote
            about you once voting closed. We will never tell you who wrote it.
          </Text>
          <Pressable
            accessibilityLabel="Get a copy of my data"
            accessibilityRole="button"
            accessibilityState={{ busy }}
            disabled={busy}
            onPress={() =>
              void run(async () => {
                const data = await exportMyData();
                const text = JSON.stringify(data, null, 2);
                setExported(text);
                // On web the export can be saved straight away. On a device
                // this becomes a share sheet, which is MEM-011.
                if (Platform.OS === 'web' && typeof document !== 'undefined') {
                  const blob = new Blob([text], { type: 'application/json' });
                  const link = document.createElement('a');
                  link.href = URL.createObjectURL(blob);
                  link.download = 'my-recognition-data.json';
                  link.click();
                  URL.revokeObjectURL(link.href);
                }
                setNotice('Your data was prepared.');
              })
            }
            style={({ pressed }) => [
              styles.button,
              busy && styles.buttonDisabled,
              pressed && styles.pressed,
            ]}
          >
            <Text style={styles.buttonText}>Get a copy of my data</Text>
          </Pressable>
          {exported ? (
            <ScrollView style={styles.exportBox} nestedScrollEnabled>
              <Text style={styles.exportText}>{exported}</Text>
            </ScrollView>
          ) : null}
        </View>

        {membership ? (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>
              Leave {membership.organisationName}
            </Text>
            <Text style={styles.body}>
              You stop being able to nominate straight away. Nominations you
              already made stay counted, because withdrawing them would change a
              result other people have seen.
            </Text>
            <Pressable
              accessibilityLabel={`Leave ${membership.organisationName}`}
              accessibilityRole="button"
              accessibilityState={{ busy }}
              disabled={busy}
              onPress={() =>
                void run(async () => {
                  await leaveOrganisation(membership.organisationId);
                  setNotice('You have left the organisation.');
                })
              }
              style={({ pressed }) => [
                styles.secondaryButton,
                busy && styles.buttonDisabled,
                pressed && styles.pressed,
              ]}
            >
              <Text style={styles.secondaryButtonText}>
                Leave this organisation
              </Text>
            </Pressable>
          </View>
        ) : null}

        <View style={[styles.card, styles.dangerCard]}>
          <Text style={styles.cardTitle}>Delete your account</Text>
          {pendingDeletion ? (
            <>
              <Text style={styles.body}>
                You asked us to delete your account on{' '}
                {new Date(pendingDeletion.receivedAt).toDateString()}. It is{' '}
                {pendingDeletion.state === 'received'
                  ? 'waiting to be processed'
                  : 'being processed'}
                .
              </Text>
              <Text style={styles.body}>
                A record that you won a month, if you did, is kept. Your
                employer announced it, and removing it would change a past
                result.
              </Text>
            </>
          ) : (
            <>
              <Text style={styles.body}>
                This removes your account and your personal information. A
                record that you won a month, if you did, is kept, because your
                employer announced it at the time.
              </Text>
              <Text style={styles.label}>Type DELETE to confirm</Text>
              <TextInput
                accessibilityLabel="Type DELETE to confirm"
                autoCapitalize="characters"
                onChangeText={setConfirmDelete}
                placeholder="DELETE"
                placeholderTextColor={colours.inkMuted}
                style={styles.input}
                value={confirmDelete}
              />
              <Pressable
                accessibilityLabel="Request account deletion"
                accessibilityRole="button"
                accessibilityState={{
                  busy,
                  disabled: confirmDelete.trim().toUpperCase() !== 'DELETE',
                }}
                disabled={
                  busy || confirmDelete.trim().toUpperCase() !== 'DELETE'
                }
                onPress={() =>
                  void run(async () => {
                    await requestAccountDeletion();
                    setConfirmDelete('');
                    setNotice('Your deletion request has been recorded.');
                  })
                }
                style={({ pressed }) => [
                  styles.dangerButton,
                  (busy || confirmDelete.trim().toUpperCase() !== 'DELETE') &&
                    styles.buttonDisabled,
                  pressed && styles.pressed,
                ]}
              >
                <Text style={styles.dangerButtonText}>
                  Request account deletion
                </Text>
              </Pressable>
            </>
          )}
        </View>

        <Pressable
          accessibilityLabel="Sign out"
          accessibilityRole="button"
          onPress={() => void signOut()}
        >
          <Text style={styles.signOut}>Sign out</Text>
        </Pressable>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: { backgroundColor: colours.canvas, flex: 1 },
  centre: {
    alignItems: 'center',
    backgroundColor: colours.canvas,
    flex: 1,
    justifyContent: 'center',
  },
  content: {
    paddingBottom: spacing.xxl,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
  },
  topRow: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  eyebrow: {
    color: colours.moss,
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 1.2,
  },
  link: {
    color: colours.ink,
    fontSize: 14,
    fontWeight: '700',
    padding: spacing.sm,
  },
  title: {
    color: colours.ink,
    fontSize: 34,
    fontWeight: '800',
    letterSpacing: -1.4,
    marginTop: spacing.sm,
  },
  card: {
    backgroundColor: colours.surface,
    borderColor: colours.line,
    borderRadius: radii.md,
    borderWidth: 1,
    marginTop: spacing.md,
    padding: spacing.lg,
  },
  dangerCard: { borderColor: '#E5A99B' },
  cardTitle: { color: colours.ink, fontSize: 19, fontWeight: '700' },
  body: {
    color: colours.inkMuted,
    fontSize: 15,
    lineHeight: 23,
    marginTop: spacing.sm,
  },
  emphasis: {
    color: colours.ink,
    fontSize: 15,
    fontWeight: '700',
    lineHeight: 23,
    marginTop: spacing.md,
  },
  label: {
    color: colours.ink,
    fontSize: 13,
    fontWeight: '700',
    marginBottom: spacing.sm,
    marginTop: spacing.md,
  },
  input: {
    backgroundColor: colours.canvas,
    borderColor: colours.line,
    borderRadius: radii.sm,
    borderWidth: 1,
    color: colours.ink,
    fontSize: 16,
    minHeight: 52,
    paddingHorizontal: spacing.md,
  },
  button: {
    alignItems: 'center',
    backgroundColor: colours.lime,
    borderRadius: radii.md,
    justifyContent: 'center',
    marginTop: spacing.md,
    minHeight: 52,
  },
  buttonText: { color: colours.ink, fontSize: 15, fontWeight: '800' },
  secondaryButton: {
    alignItems: 'center',
    borderColor: colours.line,
    borderRadius: radii.md,
    borderWidth: 1,
    justifyContent: 'center',
    marginTop: spacing.md,
    minHeight: 52,
  },
  secondaryButtonText: { color: colours.ink, fontSize: 15, fontWeight: '700' },
  dangerButton: {
    alignItems: 'center',
    backgroundColor: '#7A2E1D',
    borderRadius: radii.md,
    justifyContent: 'center',
    marginTop: spacing.md,
    minHeight: 52,
  },
  dangerButtonText: { color: colours.white, fontSize: 15, fontWeight: '800' },
  buttonDisabled: { opacity: 0.45 },
  pressed: { opacity: 0.82 },
  exportBox: {
    backgroundColor: colours.canvas,
    borderColor: colours.line,
    borderRadius: radii.sm,
    borderWidth: 1,
    marginTop: spacing.md,
    maxHeight: 220,
    padding: spacing.sm,
  },
  exportText: {
    color: colours.inkMuted,
    fontFamily: 'monospace',
    fontSize: 11,
  },
  signOut: {
    color: colours.inkMuted,
    fontSize: 14,
    fontWeight: '700',
    paddingVertical: spacing.lg,
    textAlign: 'center',
  },
  noticeBox: {
    backgroundColor: '#FDF3DC',
    borderColor: colours.amber,
    borderRadius: radii.sm,
    borderWidth: 1,
    marginTop: spacing.md,
    padding: spacing.md,
  },
  noticeText: { color: colours.ink, fontSize: 14, lineHeight: 20 },
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
