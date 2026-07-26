import { Link } from 'expo-router';
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
import {
  assessConfidentiality,
  type ConfidentialityAssessment,
  periodLabel,
} from '@/domain/recognition/engine';
import {
  type AdminNomination,
  createCycle,
  describeAdminError,
  loadAdminNominations,
  loadStandings,
  loadTurnout,
  moderateNomination,
  revealWinner,
  type Standing,
  type Turnout,
  transitionCycle,
} from '@/features/admin/api';
import {
  type Cycle,
  listMemberships,
  loadCurrentCycle,
  type Membership,
} from '@/features/recognition/api';
import { useSession } from '@/state/session';
import { colours, radii, spacing } from '@/theme/tokens';

function currentPeriod(): string {
  const now = new Date();
  const month = `${now.getMonth() + 1}`.padStart(2, '0');
  return `${now.getFullYear()}-${month}-01`;
}

export default function AdminScreen() {
  const { session } = useSession();
  const [membership, setMembership] = useState<Membership | null>(null);
  const [cycle, setCycle] = useState<Cycle | null>(null);
  const [turnout, setTurnout] = useState<Turnout | null>(null);
  const [standings, setStandings] = useState<Standing[]>([]);
  const [nominations, setNominations] = useState<AdminNomination[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [criteria, setCriteria] = useState('');
  const [tieChoice, setTieChoice] = useState<string | null>(null);
  const [tieNote, setTieNote] = useState('');

  const load = useCallback(async () => {
    setError(null);
    try {
      const userId = session?.user.id;
      if (!userId) return;
      const memberships = await listMemberships(userId);
      const mine =
        memberships.find((m) => m.role === 'owner' || m.role === 'admin') ??
        null;
      setMembership(mine);
      if (!mine) return;

      const current = await loadCurrentCycle(mine.organisationId);
      setCycle(current);
      if (!current) {
        setTurnout(null);
        setStandings([]);
        setNominations([]);
        return;
      }

      setTurnout(await loadTurnout(current.id));

      // Standings and reasons are refused by the database while a cycle is
      // open. Asking anyway and swallowing the refusal would blur a real rule
      // into a loading state, so the screen simply does not ask.
      if (current.status === 'closed' || current.status === 'revealed') {
        setStandings(await loadStandings(current.id));
        setNominations(await loadAdminNominations(current.id));
      } else {
        setStandings([]);
        setNominations([]);
      }
    } catch (caught) {
      setError(describeAdminError(caught));
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
      setError(describeAdminError(caught));
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

  if (!membership) {
    return (
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.content}>
          <Text style={styles.title}>Not an administrator</Text>
          <Text style={styles.body}>
            Only an owner or administrator can manage a recognition programme.
          </Text>
          <Link href="/" style={styles.link}>
            Back
          </Link>
        </View>
      </SafeAreaView>
    );
  }

  // FR-CYCLE-04. The count comes from turnout, which is the only place the
  // eligible-voter number is available to a client: `can_vote` is withheld from
  // the roster grant precisely so a member cannot work this out.
  const confidentiality: ConfidentialityAssessment | null = turnout
    ? assessConfidentiality(turnout.eligibleVoters)
    : null;

  const leaders = standings.filter((s) => s.rank === 1 && s.nominations > 0);
  const isTie = leaders.length > 1;

  return (
    <SafeAreaView style={styles.safeArea}>
      <ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.topRow}>
          <Text style={styles.eyebrow}>MANAGE PROGRAMME</Text>
          <Link href="/" style={styles.link}>
            Done
          </Link>
        </View>
        <Text style={styles.orgName}>{membership.organisationName}</Text>

        {error ? (
          <View accessibilityRole="alert" style={styles.errorBox}>
            <Text style={styles.errorText}>{error}</Text>
          </View>
        ) : null}

        {confidentiality?.warn ? (
          // Deliberately a full card rather than help text. D-022 says the
          // product must not imply a protection the arithmetic cannot support,
          // and a footnote implies exactly that.
          <View
            accessibilityRole="alert"
            style={[
              styles.warning,
              confidentiality.level === 'determined' && styles.warningSevere,
            ]}
          >
            <Text style={styles.warningLabel}>
              {confidentiality.level === 'determined'
                ? 'VOTES CAN BE WORKED OUT'
                : 'SMALL TEAM'}
            </Text>
            <Text style={styles.warningText}>{confidentiality.message}</Text>
            <Text style={styles.warningCount}>
              {confidentiality.eligibleVoters} eligible voter
              {confidentiality.eligibleVoters === 1 ? '' : 's'}
            </Text>
          </View>
        ) : null}

        {!cycle ? (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Start this month</Text>
            <Text style={styles.body}>
              Nobody can nominate until a cycle exists.
            </Text>
            <Text style={styles.label}>What are you recognising?</Text>
            <TextInput
              accessibilityLabel="Criteria for this month"
              multiline
              onChangeText={setCriteria}
              placeholder="Someone who went out of their way this month."
              placeholderTextColor={colours.inkMuted}
              style={styles.input}
              value={criteria}
            />
            <Action
              busy={busy}
              label="Create this month’s cycle"
              onPress={() =>
                void run(() =>
                  createCycle(
                    membership.organisationId,
                    currentPeriod(),
                    criteria,
                  ),
                )
              }
            />
          </View>
        ) : (
          <>
            <View style={styles.card}>
              <View style={styles.cardHeader}>
                <View>
                  <Text style={styles.cardLabel}>
                    {periodLabel(cycle.periodMonth).toUpperCase()}
                  </Text>
                  <Text style={styles.cardTitle}>
                    {cycle.status === 'draft'
                      ? 'Not open yet'
                      : cycle.status === 'open'
                        ? 'Nominations open'
                        : cycle.status === 'closed'
                          ? 'Closed, not yet revealed'
                          : 'Revealed'}
                  </Text>
                </View>
                <Text style={styles.version}>v{cycle.version}</Text>
              </View>

              {turnout ? (
                <View style={styles.turnoutRow}>
                  <Stat label="eligible" value={`${turnout.eligibleVoters}`} />
                  <Stat label="voted" value={`${turnout.ballotsCounted}`} />
                  <Stat label="turnout" value={`${turnout.turnoutPercent}%`} />
                </View>
              ) : null}

              {cycle.status === 'open' ? (
                <Text style={styles.body}>
                  No standings are available while voting is open, to anybody.
                </Text>
              ) : null}

              {cycle.status === 'draft' ? (
                <Action
                  busy={busy}
                  label="Open nominations"
                  onPress={() =>
                    void run(() =>
                      transitionCycle(cycle.id, cycle.version, 'open'),
                    )
                  }
                />
              ) : null}
              {cycle.status === 'open' ? (
                <Action
                  busy={busy}
                  label="Close nominations"
                  onPress={() =>
                    void run(() =>
                      transitionCycle(cycle.id, cycle.version, 'closed'),
                    )
                  }
                />
              ) : null}
            </View>

            {standings.length > 0 ? (
              <View style={styles.card}>
                <Text style={styles.cardTitle}>Standings</Text>
                {standings.map((s) => (
                  <View key={s.participantId} style={styles.standingRow}>
                    <Text style={styles.standingRank}>{s.rank}</Text>
                    <Text style={styles.standingName}>{s.displayName}</Text>
                    <Text style={styles.standingCount}>{s.nominations}</Text>
                  </View>
                ))}
              </View>
            ) : null}

            {cycle.status === 'closed' ? (
              <View style={styles.card}>
                <Text style={styles.cardTitle}>Reveal the result</Text>
                {isTie ? (
                  <>
                    <Text style={styles.body}>
                      This month is tied. Choose one of the joint leaders and
                      record why. Everyone will see the reason.
                    </Text>
                    {leaders.map((leader) => (
                      <Pressable
                        accessibilityLabel={`Choose ${leader.displayName}`}
                        accessibilityRole="radio"
                        accessibilityState={{
                          selected: tieChoice === leader.participantId,
                        }}
                        key={leader.participantId}
                        onPress={() => setTieChoice(leader.participantId)}
                        style={[
                          styles.leader,
                          tieChoice === leader.participantId &&
                            styles.leaderSelected,
                        ]}
                      >
                        <Text
                          style={[
                            styles.leaderName,
                            tieChoice === leader.participantId &&
                              styles.leaderNameSelected,
                          ]}
                        >
                          {leader.displayName}
                        </Text>
                        {tieChoice === leader.participantId ? (
                          <Text style={styles.tick}>✓</Text>
                        ) : null}
                      </Pressable>
                    ))}
                    <Text style={styles.label}>Why this person?</Text>
                    <TextInput
                      accessibilityLabel="Why you chose this person"
                      multiline
                      onChangeText={setTieNote}
                      placeholder="Recorded with the result and visible to the team."
                      placeholderTextColor={colours.inkMuted}
                      style={styles.input}
                      value={tieNote}
                    />
                  </>
                ) : (
                  <Text style={styles.body}>
                    {leaders[0]
                      ? `${leaders[0].displayName} has the most nominations. The result cannot be changed once revealed.`
                      : 'Nobody was nominated, so there is no result to reveal.'}
                  </Text>
                )}
                <Action
                  busy={busy}
                  disabled={
                    leaders.length === 0 ||
                    (isTie && (!tieChoice || tieNote.trim() === ''))
                  }
                  label="Reveal the winner"
                  onPress={() =>
                    void run(() =>
                      revealWinner({
                        cycleId: cycle.id,
                        expectedVersion: cycle.version,
                        ...(isTie && tieChoice
                          ? {
                              tiedParticipantId: tieChoice,
                              decisionNote: tieNote.trim(),
                            }
                          : {}),
                      }),
                    )
                  }
                />
              </View>
            ) : null}

            {nominations.length > 0 ? (
              <View style={styles.card}>
                <Text style={styles.cardTitle}>Nominations</Text>
                <Text style={styles.body}>
                  Who wrote each of these is not recorded here and cannot be
                  retrieved.
                </Text>
                {nominations.map((n) => (
                  <View key={n.id} style={styles.nomination}>
                    <Text style={styles.nominationNominee}>
                      {n.nomineeDisplayName}
                      {n.status === 'hidden' ? ' · hidden' : ''}
                    </Text>
                    {n.reason ? (
                      <Text style={styles.nominationReason}>{n.reason}</Text>
                    ) : null}
                    <Text style={styles.nominationDate}>{n.createdDate}</Text>
                    {cycle.status !== 'revealed' ? (
                      <Pressable
                        accessibilityLabel={
                          n.status === 'hidden'
                            ? `Restore nomination for ${n.nomineeDisplayName}`
                            : `Hide nomination for ${n.nomineeDisplayName}`
                        }
                        accessibilityRole="button"
                        disabled={busy}
                        onPress={() =>
                          void run(() =>
                            moderateNomination(
                              n.id,
                              n.status === 'hidden' ? 'restore' : 'hide',
                              n.status === 'hidden'
                                ? 'Reviewed and allowed.'
                                : 'Contained unsuitable content.',
                            ),
                          )
                        }
                      >
                        <Text style={styles.moderate}>
                          {n.status === 'hidden' ? 'Restore' : 'Hide'}
                        </Text>
                      </Pressable>
                    ) : null}
                  </View>
                ))}
              </View>
            ) : null}
          </>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.stat}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

function Action({
  label,
  onPress,
  busy,
  disabled,
}: {
  label: string;
  onPress: () => void;
  busy: boolean;
  disabled?: boolean;
}) {
  const off = busy || disabled === true;
  return (
    <Pressable
      accessibilityLabel={label}
      accessibilityRole="button"
      accessibilityState={{ busy, disabled: off }}
      disabled={off}
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        off && styles.buttonDisabled,
        pressed && styles.pressed,
      ]}
    >
      {busy ? (
        <ActivityIndicator color={colours.ink} />
      ) : (
        <Text style={styles.buttonText}>{label}</Text>
      )}
    </Pressable>
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
  orgName: {
    color: colours.ink,
    fontSize: 30,
    fontWeight: '800',
    letterSpacing: -1.2,
    marginTop: spacing.sm,
  },
  title: {
    color: colours.ink,
    fontSize: 26,
    fontWeight: '800',
    letterSpacing: -1,
  },
  card: {
    backgroundColor: colours.surface,
    borderColor: colours.line,
    borderRadius: radii.md,
    borderWidth: 1,
    marginTop: spacing.lg,
    padding: spacing.lg,
  },
  cardHeader: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  cardLabel: {
    color: colours.moss,
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 1.1,
  },
  cardTitle: {
    color: colours.ink,
    fontSize: 21,
    fontWeight: '700',
    marginTop: spacing.xs,
  },
  version: { color: colours.inkMuted, fontSize: 12, fontWeight: '700' },
  body: {
    color: colours.inkMuted,
    fontSize: 15,
    lineHeight: 23,
    marginTop: spacing.sm,
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
    fontSize: 15,
    minHeight: 80,
    padding: spacing.md,
    textAlignVertical: 'top',
  },
  button: {
    alignItems: 'center',
    backgroundColor: colours.lime,
    borderRadius: radii.md,
    justifyContent: 'center',
    marginTop: spacing.md,
    minHeight: 58,
  },
  buttonDisabled: { opacity: 0.45 },
  buttonText: { color: colours.ink, fontSize: 15, fontWeight: '800' },
  pressed: { opacity: 0.82 },
  turnoutRow: {
    flexDirection: 'row',
    gap: spacing.lg,
    marginTop: spacing.md,
  },
  stat: {},
  statValue: { color: colours.ink, fontSize: 26, fontWeight: '800' },
  statLabel: {
    color: colours.inkMuted,
    fontSize: 12,
    fontWeight: '600',
    textTransform: 'uppercase',
  },
  warning: {
    backgroundColor: '#FDF3DC',
    borderColor: colours.amber,
    borderRadius: radii.md,
    borderWidth: 1,
    marginTop: spacing.lg,
    padding: spacing.md,
  },
  warningSevere: { backgroundColor: '#FBE9E7', borderColor: '#E5A99B' },
  warningLabel: {
    color: '#7A5A12',
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 1,
  },
  warningText: {
    color: colours.ink,
    fontSize: 15,
    lineHeight: 22,
    marginTop: spacing.sm,
  },
  warningCount: {
    color: colours.inkMuted,
    fontSize: 13,
    marginTop: spacing.sm,
  },
  standingRow: {
    alignItems: 'center',
    borderTopColor: colours.line,
    borderTopWidth: 1,
    flexDirection: 'row',
    gap: spacing.md,
    paddingVertical: spacing.sm,
  },
  standingRank: {
    color: colours.moss,
    fontSize: 13,
    fontWeight: '800',
    width: 20,
  },
  standingName: { color: colours.ink, flex: 1, fontSize: 15 },
  standingCount: { color: colours.ink, fontSize: 15, fontWeight: '800' },
  leader: {
    alignItems: 'center',
    borderColor: colours.line,
    borderRadius: radii.sm,
    borderWidth: 1,
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: spacing.sm,
    minHeight: 52,
    paddingHorizontal: spacing.md,
  },
  leaderSelected: {
    backgroundColor: colours.forest,
    borderColor: colours.forest,
  },
  leaderName: { color: colours.ink, fontSize: 15, fontWeight: '700' },
  leaderNameSelected: { color: colours.white },
  tick: { color: colours.lime, fontSize: 18, fontWeight: '800' },
  nomination: {
    borderTopColor: colours.line,
    borderTopWidth: 1,
    marginTop: spacing.md,
    paddingTop: spacing.md,
  },
  nominationNominee: { color: colours.ink, fontSize: 15, fontWeight: '700' },
  nominationReason: {
    color: colours.inkMuted,
    fontSize: 14,
    lineHeight: 21,
    marginTop: spacing.xs,
  },
  nominationDate: {
    color: colours.inkMuted,
    fontSize: 12,
    marginTop: spacing.xs,
  },
  moderate: {
    color: colours.moss,
    fontSize: 13,
    fontWeight: '800',
    paddingVertical: spacing.sm,
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
