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

/**
 * D-036 gave the residual ballot record an end date, so the notice can no
 * longer say it is kept "for as long as the result exists". That was true when
 * it was written and stopped being true when the second retention dial was
 * added; a notice that lags the schema is exactly what D-031 was about.
 */
function residualSentence(months: number | null): string {
  if (months === null) {
    return 'We also keep a record that you voted, without anything you wrote or who you chose. Your organisation has chosen to keep that indefinitely.';
  }
  return `We also keep a record that you voted, without anything you wrote or who you chose, for a further ${months} months. After that it is deleted too.`;
}

export default function PrivacyScreen() {
  const { session, signOut } = useSession();
  const [membership, setMembership] = useState<Membership | null>(null);
  const [residual, setResidual] = useState<number | null>(null);
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
        setResidual(policy?.residualRetentionMonths ?? null);
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

        {/* D-031. This used to open with "Nobody." — which the threat model
            and LEGAL_AND_PRIVACY.md section 3 both contradict, because a court
            order, a database administrator or our own trusted server role can
            reach nominator_user_id. A promise disproved by our own documents is
            worse than a longer sentence. "Nobody in your organisation" is the
            promise anyone actually cares about, and it is true. */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Who can see your nomination</Text>
          <Text style={styles.body}>
            Nobody in your organisation. Administrators see how many people
            voted and who won. They cannot see who you nominated, and no screen,
            export or report in this app will show them.
          </Text>
          <Text style={styles.body}>
            We keep an internal record of who voted so that everyone votes once.
            That record is not available to your employer. A small number of our
            own technical staff can reach the underlying database to fix a fault
            or investigate a security problem; that access is controlled and
            logged. We would also have to disclose it if we were legally
            required to, such as by a court order.
          </Text>
          <Text style={styles.emphasis}>
            This is confidential, not anonymous. In a small team it may still be
            possible to work out how somebody voted from the result alone. We
            warn you before you vote when your team is that small.
          </Text>
        </View>

        {/* Article 13(1)(c) and (d): name the basis and the interest. Article
            21(4) requires the right to object to be given explicitly and
            separately from everything else, which is why it has its own card
            rather than a line in a list. */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Taking part is your choice</Text>
          <Text style={styles.body}>
            You do not have to nominate anyone. Nobody is told whether you
            voted, and there is no record anywhere in this app of who did not.
          </Text>
          <Text style={styles.body}>
            Your employer relies on its legitimate interests in running a
            voluntary recognition scheme. You have the right to object to that
            at any time, and to ask your employer to stop including you.
          </Text>
          <Text style={styles.body}>
            Results from this app must not be used in appraisals, pay,
            promotion, redundancy or disciplinary decisions. Your employer has
            agreed to that in its contract with us.
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
            {/* The wording here has been corrected twice, and both times the
                schema moved first. It once implied everything about a vote went
                at the retention period, which was wrong because the ballot
                stayed (D-003). It then said the ballot stayed "for as long as
                the result exists", which stopped being true when D-036 gave
                that record its own end date. */}
            <Text style={styles.body}>{residualSentence(residual)}</Text>
          </View>
        ) : null}

        <View style={styles.card}>
          <Text style={styles.cardTitle}>Get a copy of your data</Text>
          {/* "Never" was too absolute. Withholding the author rests on the
              third party exemption in Schedule 2 Part 3 paragraph 16 of the
              Data Protection Act 2018, which is a balancing exemption: it can
              be displaced if the author consents or disclosure is reasonable.
              Promising "never" forecloses a judgment the statute requires. */}
          <Text style={styles.body}>
            Everything we hold about you, including anything colleagues wrote
            about you once voting closed. We will not normally tell you who
            wrote it. If we are ever legally required to, we will explain why.
          </Text>
          <Text style={styles.body}>
            If you think something written about you is inappropriate, tell your
            employer's administrator. They can remove it.
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
                A record that you won a month, if you did, is kept by default.
                Your employer announced it at the time. If you want that
                removed, ask your employer's administrator — the decision is
                theirs and they can do it without deleting the result.
              </Text>
            </>
          ) : (
            <>
              {/* D-028. Retention after an erasure request is the employer's
                  decision under Article 21, not ours, and this is the moment
                  the person is actually making the choice — so it says so here
                  as well as in the notice, and routes them to the controller
                  rather than to us. */}
              <Text style={styles.body}>
                This removes your account and your personal information. Nothing
                anybody wrote about you is kept.
              </Text>
              <Text style={styles.body}>
                A record that you won a month, if you did, is kept by default,
                because your employer announced it at the time. If you want that
                removed or shown as initials instead, ask your employer's
                administrator before you delete your account. They can do it,
                and we will act on their instruction.
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

        {/* Article 13(2)(d). Left until after the actions because it is a
            route of last resort, but it has to be here and it has to name the
            regulator rather than gesturing at "the relevant authority". */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>If you are unhappy</Text>
          <Text style={styles.body}>
            Tell your employer's administrator first, or contact us. If you are
            still unhappy, you can complain to the Information Commissioner's
            Office at ico.org.uk, which regulates data protection in the UK.
          </Text>
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
