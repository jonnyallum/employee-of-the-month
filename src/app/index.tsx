import { Link } from 'expo-router';
import { useCallback, useEffect, useMemo, useState } from 'react';
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

import { periodLabel, REASON_MAX_LENGTH } from '@/domain/recognition/engine';
import {
  type Cycle,
  castNomination,
  describeError,
  listMemberships,
  listNominees,
  loadCurrentCycle,
  loadMyNomination,
  type Membership,
  type MyNomination,
  type Nominee,
  withdrawNomination,
} from '@/features/recognition/api';
import { getSupabaseClient } from '@/lib/supabase';
import { useSession } from '@/state/session';
import { colours, radii, spacing } from '@/theme/tokens';

interface Loaded {
  membership: Membership | null;
  cycle: Cycle | null;
  nominees: Nominee[];
  myParticipantId: string | null;
  canVote: boolean;
  mine: MyNomination | null;
}

const EMPTY: Loaded = {
  membership: null,
  cycle: null,
  nominees: [],
  myParticipantId: null,
  canVote: false,
  mine: null,
};

export default function CycleScreen() {
  const { session, signOut } = useSession();
  const [data, setData] = useState<Loaded>(EMPTY);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selected, setSelected] = useState<string | null>(null);
  const [reason, setReason] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const load = useCallback(async () => {
    setError(null);
    try {
      const userId = session?.user.id;
      if (!userId) return;
      const memberships = await listMemberships(userId);
      const membership = memberships[0] ?? null;
      if (!membership) {
        setData(EMPTY);
        return;
      }

      const client = getSupabaseClient();
      const [cycle, nominees, participantResult] = await Promise.all([
        loadCurrentCycle(membership.organisationId),
        listNominees(membership.organisationId),
        client.rpc('get_my_participant', {
          target_organisation_id: membership.organisationId,
        }),
      ]);

      const me = (participantResult.data ?? [])[0] ?? null;
      const mine = cycle ? await loadMyNomination(cycle.id) : null;

      setData({
        membership,
        cycle,
        nominees,
        myParticipantId: me?.id ?? null,
        canVote: me?.can_vote ?? false,
        mine,
      });
      setSelected(mine?.nomineeParticipantId ?? null);
      setReason(mine?.reason ?? '');
    } catch (caught) {
      setError(describeError(caught));
    } finally {
      setLoading(false);
    }
  }, [session]);

  useEffect(() => {
    void load();
  }, [load]);

  // The database refuses a self-nomination anyway. Filtering here means the
  // interface never offers a choice that would be rejected.
  const choosable = useMemo(
    () => data.nominees.filter((n) => n.id !== data.myParticipantId),
    [data.nominees, data.myParticipantId],
  );

  async function submit() {
    if (!data.cycle || !selected || submitting) return;
    setSubmitting(true);
    setError(null);
    try {
      await castNomination({
        cycleId: data.cycle.id,
        nomineeParticipantId: selected,
        reason,
        // Stable for this cycle and voter, so a retry after a dropped
        // connection returns the original ballot rather than being refused as
        // a second one.
        idempotencyKey: `${data.cycle.id}:${data.myParticipantId}`,
      });
      await load();
    } catch (caught) {
      setError(describeError(caught));
    } finally {
      setSubmitting(false);
    }
  }

  async function withdraw() {
    if (!data.cycle || submitting) return;
    setSubmitting(true);
    setError(null);
    try {
      await withdrawNomination(data.cycle.id);
      setSelected(null);
      setReason('');
      await load();
    } catch (caught) {
      setError(describeError(caught));
    } finally {
      setSubmitting(false);
    }
  }

  if (loading) {
    return (
      <SafeAreaView style={styles.centre}>
        <ActivityIndicator color={colours.forest} />
      </SafeAreaView>
    );
  }

  const { membership, cycle, mine } = data;

  return (
    <SafeAreaView style={styles.safeArea}>
      <ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.topRow}>
          <View style={styles.brandRow}>
            <View style={styles.mark}>
              <Text style={styles.markText}>E</Text>
            </View>
            <Text style={styles.brand}>
              {membership?.organisationName?.toUpperCase() ??
                'EMPLOYEE OF THE MONTH'}
            </Text>
          </View>
          <View style={styles.topActions}>
            {/* Shown by role for convenience only. The admin screen's own
                calls are refused by the database for anyone else, so hiding
                this link is tidiness rather than a control. */}
            {membership?.role === 'owner' || membership?.role === 'admin' ? (
              <Link href="/admin" style={styles.manage}>
                Manage
              </Link>
            ) : null}
            <Pressable
              accessibilityLabel="Sign out"
              accessibilityRole="button"
              onPress={() => void signOut()}
            >
              <Text style={styles.signOut}>Sign out</Text>
            </Pressable>
          </View>
        </View>

        {error ? (
          <View accessibilityRole="alert" style={styles.errorBox}>
            <Text style={styles.errorText}>{error}</Text>
          </View>
        ) : null}

        {!membership ? (
          <EmptyState
            body="You are signed in but not part of an organisation. Ask whoever runs your programme to invite this email address."
            title="No organisation yet"
          />
        ) : !cycle ? (
          <EmptyState
            body="Your organisation has not opened a recognition month. You will be told when it does."
            title="Nothing running yet"
          />
        ) : (
          <>
            <View style={styles.hero}>
              <Text style={styles.kicker}>
                {periodLabel(cycle.periodMonth)}
              </Text>
              <Text style={styles.title}>
                {cycle.status === 'revealed'
                  ? 'The result is in.'
                  : cycle.status === 'open'
                    ? 'Make good work visible.'
                    : 'Nominations are closed.'}
              </Text>
              {cycle.criteria ? (
                <Text style={styles.subtitle}>{cycle.criteria}</Text>
              ) : null}
            </View>

            {cycle.status === 'revealed' ? (
              <View style={styles.winnerCard}>
                <Text style={styles.cardLabel}>THIS MONTH</Text>
                <Text style={styles.winnerName}>{cycle.winnerName}</Text>
                <Text style={styles.winnerCount}>
                  {cycle.winnerNominations} nomination
                  {cycle.winnerNominations === 1 ? '' : 's'}
                </Text>
                {cycle.tieDecisionNote ? (
                  <View style={styles.tieNote}>
                    <Text style={styles.tieNoteLabel}>
                      HOW THE TIE WAS DECIDED
                    </Text>
                    <Text style={styles.tieNoteText}>
                      {cycle.tieDecisionNote}
                    </Text>
                  </View>
                ) : null}
              </View>
            ) : cycle.status === 'closed' ? (
              <View style={styles.quietCard}>
                <Text style={styles.quietTitle}>Counting up</Text>
                <Text style={styles.quietBody}>
                  Voting has closed. The result will appear here once it is
                  revealed.
                </Text>
              </View>
            ) : !data.canVote ? (
              <View style={styles.quietCard}>
                <Text style={styles.quietTitle}>
                  You are not voting this month
                </Text>
                <Text style={styles.quietBody}>
                  You can still be nominated by colleagues. Speak to your
                  programme administrator if you think this is wrong.
                </Text>
              </View>
            ) : mine ? (
              <View style={styles.chosenCard}>
                <Text style={styles.cardLabel}>YOUR NOMINATION</Text>
                <Text style={styles.chosenName}>{mine.nomineeDisplayName}</Text>
                {mine.reason ? (
                  <Text style={styles.chosenReason}>{mine.reason}</Text>
                ) : null}
                <Text style={styles.chosenNote}>
                  Only you can see this. You can change it until nominations
                  close.
                </Text>
                <Pressable
                  accessibilityLabel="Change my nomination"
                  accessibilityRole="button"
                  accessibilityState={{ busy: submitting }}
                  disabled={submitting}
                  onPress={() => void withdraw()}
                  style={({ pressed }) => [
                    styles.secondaryButton,
                    pressed && styles.pressed,
                  ]}
                >
                  <Text style={styles.secondaryButtonText}>
                    {submitting ? 'Working…' : 'Change my nomination'}
                  </Text>
                </Pressable>
              </View>
            ) : (
              <>
                <Text style={styles.sectionLabel}>CHOOSE A COLLEAGUE</Text>
                <View style={styles.list}>
                  {choosable.map((nominee) => {
                    const isSelected = selected === nominee.id;
                    return (
                      <Pressable
                        accessibilityLabel={`Nominate ${nominee.displayName}`}
                        accessibilityRole="radio"
                        accessibilityState={{ selected: isSelected }}
                        key={nominee.id}
                        onPress={() => setSelected(nominee.id)}
                        style={({ pressed }) => [
                          styles.nominee,
                          isSelected && styles.nomineeSelected,
                          pressed && styles.pressed,
                        ]}
                      >
                        <View style={styles.nomineeText}>
                          <Text
                            style={[
                              styles.nomineeName,
                              isSelected && styles.nomineeNameSelected,
                            ]}
                          >
                            {nominee.displayName}
                          </Text>
                          {nominee.team ? (
                            <Text
                              style={[
                                styles.nomineeTeam,
                                isSelected && styles.nomineeTeamSelected,
                              ]}
                            >
                              {nominee.team}
                            </Text>
                          ) : null}
                        </View>
                        {/* A tick as well as colour: colour must never carry
                            state on its own. */}
                        {isSelected ? <Text style={styles.tick}>✓</Text> : null}
                      </Pressable>
                    );
                  })}
                </View>

                <Text style={styles.sectionLabel}>WHY? (OPTIONAL)</Text>
                <TextInput
                  accessibilityLabel="Why are you nominating them? Optional."
                  maxLength={REASON_MAX_LENGTH}
                  multiline
                  onChangeText={setReason}
                  placeholder="What did they actually do?"
                  placeholderTextColor={colours.inkMuted}
                  style={styles.reasonInput}
                  value={reason}
                />
                <Text style={styles.counter}>
                  {reason.length}/{REASON_MAX_LENGTH}. Please do not include
                  health, disciplinary or other sensitive details.
                </Text>

                <Pressable
                  accessibilityLabel="Submit nomination"
                  accessibilityRole="button"
                  accessibilityState={{
                    busy: submitting,
                    disabled: !selected || submitting,
                  }}
                  disabled={!selected || submitting}
                  onPress={() => void submit()}
                  style={({ pressed }) => [
                    styles.primaryButton,
                    (!selected || submitting) && styles.disabled,
                    pressed && styles.pressed,
                  ]}
                >
                  {submitting ? (
                    <ActivityIndicator color={colours.ink} />
                  ) : (
                    <Text style={styles.primaryButtonText}>
                      Submit nomination
                    </Text>
                  )}
                </Pressable>

                <Text style={styles.footnote}>
                  One nomination each. No live results: nobody sees who is ahead
                  until the month closes.
                </Text>
              </>
            )}
          </>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

function EmptyState({ title, body }: { title: string; body: string }) {
  return (
    <View style={styles.quietCard}>
      <Text style={styles.quietTitle}>{title}</Text>
      <Text style={styles.quietBody}>{body}</Text>
    </View>
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
  brandRow: { alignItems: 'center', flexDirection: 'row', gap: spacing.sm },
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
    flexShrink: 1,
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 1.5,
  },
  topActions: { alignItems: 'center', flexDirection: 'row', gap: spacing.sm },
  manage: {
    color: colours.ink,
    fontSize: 13,
    fontWeight: '800',
    padding: spacing.sm,
  },
  signOut: {
    color: colours.inkMuted,
    fontSize: 13,
    fontWeight: '700',
    padding: spacing.sm,
  },
  hero: { paddingBottom: spacing.lg, paddingTop: spacing.xl },
  kicker: {
    color: colours.moss,
    fontSize: 13,
    fontWeight: '700',
    letterSpacing: 1.2,
    marginBottom: spacing.sm,
    textTransform: 'uppercase',
  },
  title: {
    color: colours.ink,
    fontSize: 38,
    fontWeight: '800',
    letterSpacing: -1.6,
    lineHeight: 42,
  },
  subtitle: {
    color: colours.inkMuted,
    fontSize: 16,
    lineHeight: 24,
    marginTop: spacing.md,
  },
  sectionLabel: {
    color: colours.moss,
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 1.1,
    marginBottom: spacing.sm,
    marginTop: spacing.lg,
  },
  list: { gap: spacing.sm },
  nominee: {
    alignItems: 'center',
    backgroundColor: colours.surface,
    borderColor: colours.line,
    borderRadius: radii.md,
    borderWidth: 1,
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 58,
    paddingHorizontal: spacing.md,
  },
  nomineeSelected: {
    backgroundColor: colours.forest,
    borderColor: colours.forest,
  },
  nomineeText: { flexShrink: 1 },
  nomineeName: { color: colours.ink, fontSize: 16, fontWeight: '700' },
  nomineeNameSelected: { color: colours.white },
  nomineeTeam: { color: colours.inkMuted, fontSize: 13, marginTop: 2 },
  nomineeTeamSelected: { color: '#A9B9B3' },
  tick: { color: colours.lime, fontSize: 20, fontWeight: '800' },
  reasonInput: {
    backgroundColor: colours.surface,
    borderColor: colours.line,
    borderRadius: radii.md,
    borderWidth: 1,
    color: colours.ink,
    fontSize: 16,
    minHeight: 104,
    padding: spacing.md,
    textAlignVertical: 'top',
  },
  counter: {
    color: colours.inkMuted,
    fontSize: 12,
    lineHeight: 18,
    marginTop: spacing.sm,
  },
  primaryButton: {
    alignItems: 'center',
    backgroundColor: colours.lime,
    borderRadius: radii.md,
    justifyContent: 'center',
    marginTop: spacing.lg,
    minHeight: 58,
  },
  primaryButtonText: { color: colours.ink, fontSize: 16, fontWeight: '800' },
  secondaryButton: {
    alignItems: 'center',
    borderColor: colours.lime,
    borderRadius: radii.md,
    borderWidth: 1,
    justifyContent: 'center',
    marginTop: spacing.lg,
    minHeight: 58,
  },
  secondaryButtonText: { color: colours.lime, fontSize: 15, fontWeight: '800' },
  disabled: { opacity: 0.45 },
  pressed: { opacity: 0.82 },
  footnote: {
    color: colours.inkMuted,
    fontSize: 13,
    lineHeight: 20,
    marginTop: spacing.lg,
  },
  winnerCard: {
    backgroundColor: colours.forest,
    borderRadius: radii.lg,
    padding: spacing.lg,
  },
  cardLabel: {
    color: colours.lime,
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 1.1,
  },
  winnerName: {
    color: colours.white,
    fontSize: 32,
    fontWeight: '800',
    letterSpacing: -1,
    marginTop: spacing.sm,
  },
  winnerCount: { color: '#A9B9B3', fontSize: 14, marginTop: spacing.xs },
  tieNote: {
    borderTopColor: '#32564C',
    borderTopWidth: 1,
    marginTop: spacing.lg,
    paddingTop: spacing.md,
  },
  tieNoteLabel: {
    color: '#A9B9B3',
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 1,
  },
  tieNoteText: {
    color: colours.white,
    fontSize: 14,
    lineHeight: 21,
    marginTop: spacing.sm,
  },
  chosenCard: {
    backgroundColor: colours.forest,
    borderRadius: radii.lg,
    padding: spacing.lg,
  },
  chosenName: {
    color: colours.white,
    fontSize: 28,
    fontWeight: '800',
    letterSpacing: -0.8,
    marginTop: spacing.sm,
  },
  chosenReason: {
    color: '#D5E0DB',
    fontSize: 15,
    fontStyle: 'italic',
    lineHeight: 22,
    marginTop: spacing.sm,
  },
  chosenNote: {
    color: '#A9B9B3',
    fontSize: 13,
    lineHeight: 20,
    marginTop: spacing.md,
  },
  quietCard: {
    backgroundColor: colours.surface,
    borderColor: colours.line,
    borderRadius: radii.md,
    borderWidth: 1,
    marginTop: spacing.lg,
    padding: spacing.lg,
  },
  quietTitle: { color: colours.ink, fontSize: 19, fontWeight: '700' },
  quietBody: {
    color: colours.inkMuted,
    fontSize: 15,
    lineHeight: 23,
    marginTop: spacing.sm,
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
