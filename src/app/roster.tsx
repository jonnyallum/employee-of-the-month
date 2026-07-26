import { Link } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import {
  addParticipant,
  describeAdminError,
  inviteParticipant,
  loadRoster,
  type RosterEntry,
  updateParticipant,
} from '@/features/admin/api';
import { listMemberships, type Membership } from '@/features/recognition/api';
import { useSession } from '@/state/session';
import { colours, radii, spacing } from '@/theme/tokens';

export default function RosterScreen() {
  const { session } = useSession();
  const [membership, setMembership] = useState<Membership | null>(null);
  const [roster, setRoster] = useState<RosterEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [name, setName] = useState('');
  const [team, setTeam] = useState('');
  const [inviting, setInviting] = useState<string | null>(null);
  const [inviteEmail, setInviteEmail] = useState('');

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
      if (mine) setRoster(await loadRoster(mine.organisationId));
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
          <Text style={styles.orgName}>Not an administrator</Text>
          <Link href="/" style={styles.link}>
            Back
          </Link>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.safeArea}>
      <ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.topRow}>
          <Text style={styles.eyebrow}>ROSTER</Text>
          <Link href="/admin" style={styles.link}>
            Done
          </Link>
        </View>
        <Text style={styles.orgName}>{membership.organisationName}</Text>

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

        <View style={styles.card}>
          <Text style={styles.cardTitle}>Add someone</Text>
          <Text style={styles.body}>
            They can be nominated straight away. They can only vote once they
            have accepted an invitation.
          </Text>
          <TextInput
            accessibilityLabel="Name"
            onChangeText={setName}
            placeholder="Name"
            placeholderTextColor={colours.inkMuted}
            style={styles.input}
            value={name}
          />
          <TextInput
            accessibilityLabel="Team, optional"
            onChangeText={setTeam}
            placeholder="Team (optional)"
            placeholderTextColor={colours.inkMuted}
            style={styles.input}
            value={team}
          />
          <Pressable
            accessibilityLabel="Add to roster"
            accessibilityRole="button"
            accessibilityState={{ busy, disabled: name.trim() === '' }}
            disabled={busy || name.trim() === ''}
            onPress={() =>
              void run(async () => {
                await addParticipant(membership.organisationId, name, team);
                setName('');
                setTeam('');
              })
            }
            style={({ pressed }) => [
              styles.button,
              (busy || name.trim() === '') && styles.buttonDisabled,
              pressed && styles.pressed,
            ]}
          >
            <Text style={styles.buttonText}>Add to roster</Text>
          </Pressable>
        </View>

        {roster.map((person) => (
          <View key={person.id} style={styles.card}>
            <View style={styles.personHeader}>
              <View style={styles.personText}>
                <Text style={styles.personName}>{person.displayName}</Text>
                <Text style={styles.personMeta}>
                  {person.team ?? 'No team'} ·{' '}
                  {person.hasAccount
                    ? 'joined'
                    : person.invitedEmail
                      ? `invited ${person.invitedEmail}`
                      : 'no account'}
                </Text>
              </View>
            </View>

            <Toggle
              disabled={busy}
              label="On the roster"
              onChange={(value) =>
                void run(() =>
                  updateParticipant(person.id, {
                    active: value,
                    canVote: person.canVote,
                    canReceive: person.canReceive,
                  }),
                )
              }
              value={person.active}
            />
            <Toggle
              disabled={busy || !person.hasAccount}
              // Stated rather than left to be discovered: the toggle looks
              // broken otherwise, because the database will not let an unlinked
              // participant vote whatever this says.
              hint={
                person.hasAccount
                  ? undefined
                  : 'Cannot vote until they accept an invitation'
              }
              label="Can vote"
              onChange={(value) =>
                void run(() =>
                  updateParticipant(person.id, {
                    active: person.active,
                    canVote: value,
                    canReceive: person.canReceive,
                  }),
                )
              }
              value={person.canVote}
            />
            <Toggle
              disabled={busy}
              label="Can be nominated"
              onChange={(value) =>
                void run(() =>
                  updateParticipant(person.id, {
                    active: person.active,
                    canVote: person.canVote,
                    canReceive: value,
                  }),
                )
              }
              value={person.canReceive}
            />

            {!person.hasAccount ? (
              inviting === person.id ? (
                <>
                  <TextInput
                    accessibilityLabel={`Email address for ${person.displayName}`}
                    autoCapitalize="none"
                    inputMode="email"
                    onChangeText={setInviteEmail}
                    placeholder="their@email.co.uk"
                    placeholderTextColor={colours.inkMuted}
                    style={styles.input}
                    value={inviteEmail}
                  />
                  <Pressable
                    accessibilityLabel={`Send invitation to ${person.displayName}`}
                    accessibilityRole="button"
                    disabled={busy || inviteEmail.trim() === ''}
                    onPress={() =>
                      void run(async () => {
                        await inviteParticipant(person.id, inviteEmail);
                        setInviting(null);
                        setInviteEmail('');
                        setNotice(
                          'Invitation created. Sending the email is not built yet, so nobody can accept it until COM-001 lands.',
                        );
                      })
                    }
                    style={({ pressed }) => [
                      styles.button,
                      (busy || inviteEmail.trim() === '') &&
                        styles.buttonDisabled,
                      pressed && styles.pressed,
                    ]}
                  >
                    <Text style={styles.buttonText}>Create invitation</Text>
                  </Pressable>
                </>
              ) : (
                <Pressable
                  accessibilityLabel={`Invite ${person.displayName}`}
                  accessibilityRole="button"
                  onPress={() => {
                    setInviting(person.id);
                    setInviteEmail(person.invitedEmail ?? '');
                  }}
                >
                  <Text style={styles.invite}>
                    {person.invitedEmail ? 'Reissue invitation' : 'Invite'}
                  </Text>
                </Pressable>
              )
            ) : null}
          </View>
        ))}
      </ScrollView>
    </SafeAreaView>
  );
}

function Toggle({
  label,
  value,
  onChange,
  disabled,
  hint,
}: {
  label: string;
  value: boolean;
  onChange: (value: boolean) => void;
  disabled: boolean;
  // Explicitly `| undefined`. Under exactOptionalPropertyTypes a bare `hint?:`
  // means the key may be absent but never present-and-undefined, and the caller
  // computes it conditionally.
  hint?: string | undefined;
}) {
  return (
    <View style={styles.toggleRow}>
      <View style={styles.toggleText}>
        <Text style={[styles.toggleLabel, disabled && styles.toggleDisabled]}>
          {label}
        </Text>
        {hint ? <Text style={styles.toggleHint}>{hint}</Text> : null}
      </View>
      <Switch
        accessibilityLabel={label}
        disabled={disabled}
        onValueChange={onChange}
        thumbColor={colours.white}
        trackColor={{ false: colours.line, true: colours.moss }}
        value={value}
      />
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
  card: {
    backgroundColor: colours.surface,
    borderColor: colours.line,
    borderRadius: radii.md,
    borderWidth: 1,
    marginTop: spacing.md,
    padding: spacing.md,
  },
  cardTitle: { color: colours.ink, fontSize: 19, fontWeight: '700' },
  body: {
    color: colours.inkMuted,
    fontSize: 14,
    lineHeight: 21,
    marginTop: spacing.xs,
  },
  input: {
    backgroundColor: colours.canvas,
    borderColor: colours.line,
    borderRadius: radii.sm,
    borderWidth: 1,
    color: colours.ink,
    fontSize: 15,
    marginTop: spacing.sm,
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
  buttonDisabled: { opacity: 0.45 },
  buttonText: { color: colours.ink, fontSize: 15, fontWeight: '800' },
  pressed: { opacity: 0.82 },
  personHeader: { flexDirection: 'row', justifyContent: 'space-between' },
  personText: { flexShrink: 1 },
  personName: { color: colours.ink, fontSize: 17, fontWeight: '700' },
  personMeta: {
    color: colours.inkMuted,
    fontSize: 13,
    marginTop: 2,
  },
  toggleRow: {
    alignItems: 'center',
    borderTopColor: colours.line,
    borderTopWidth: 1,
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: spacing.sm,
    minHeight: 48,
    paddingTop: spacing.sm,
  },
  toggleText: { flexShrink: 1 },
  toggleLabel: { color: colours.ink, fontSize: 15 },
  toggleDisabled: { color: colours.inkMuted },
  toggleHint: { color: colours.inkMuted, fontSize: 12, marginTop: 2 },
  invite: {
    color: colours.moss,
    fontSize: 14,
    fontWeight: '800',
    paddingTop: spacing.md,
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
