import { useMemo } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { periodLabel, turnout } from '@/domain/recognition/engine';
import { hasPublicEnvironment } from '@/lib/env';
import { colours, radii, spacing } from '@/theme/tokens';

const previewParticipants = [
  { id: 'a', userId: 'user-a', canVote: true, canReceive: true },
  { id: 'b', userId: 'user-b', canVote: true, canReceive: true },
  { id: 'c', userId: 'user-c', canVote: true, canReceive: true },
  { id: 'd', userId: null, canVote: false, canReceive: true },
] as const;

const previewNominations = [
  {
    id: 'n-1',
    cycleId: 'cycle-july',
    nominatorUserId: 'user-a',
    nomineeParticipantId: 'b',
    reason: 'Made every handover easier this month.',
    status: 'active',
  },
  {
    id: 'n-2',
    cycleId: 'cycle-july',
    nominatorUserId: 'user-b',
    nomineeParticipantId: 'c',
    reason: 'Stepped in when the team needed help.',
    status: 'active',
  },
] as const;

export default function HomeScreen() {
  const previewTurnout = useMemo(
    () => turnout(previewParticipants, previewNominations, 'cycle-july'),
    [],
  );
  const isConfigured = hasPublicEnvironment();

  return (
    <SafeAreaView style={styles.safeArea}>
      <ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.eyebrowRow}>
          <View style={styles.mark}>
            <Text style={styles.markText}>E</Text>
          </View>
          <Text style={styles.brand}>EMPLOYEE OF THE MONTH</Text>
        </View>

        <View style={styles.hero}>
          <Text style={styles.kicker}>{periodLabel('2026-07-01')}</Text>
          <Text style={styles.title}>Make good work visible.</Text>
          <Text style={styles.subtitle}>
            One fair nomination per person. A clear monthly winner. Recognition
            that feels earned.
          </Text>
        </View>

        <View style={styles.cycleCard}>
          <View style={styles.cardTopRow}>
            <View>
              <Text style={styles.cardLabel}>NOMINATIONS OPEN</Text>
              <Text style={styles.cardTitle}>July recognition</Text>
            </View>
            <View style={styles.livePill}>
              <View style={styles.liveDot} />
              <Text style={styles.liveText}>LIVE</Text>
            </View>
          </View>

          <View style={styles.progressTrack}>
            <View
              style={[
                styles.progressFill,
                { width: `${previewTurnout.turnoutPct}%` },
              ]}
            />
          </View>

          <View style={styles.progressCopy}>
            <Text style={styles.progressStrong}>
              {previewTurnout.cast} of {previewTurnout.canVote}
            </Text>
            <Text style={styles.progressMuted}>people have nominated</Text>
          </View>

          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Choose a colleague to nominate"
            style={({ pressed }) => [
              styles.primaryButton,
              pressed && styles.primaryButtonPressed,
            ]}
          >
            <Text style={styles.primaryButtonText}>Choose a colleague</Text>
            <Text style={styles.arrow}>→</Text>
          </Pressable>
        </View>

        <View style={styles.principleRow}>
          <View style={styles.principle}>
            <Text style={styles.principleNumber}>01</Text>
            <Text style={styles.principleTitle}>Private ballot</Text>
            <Text style={styles.principleBody}>
              Colleagues see the result, never who voted for whom.
            </Text>
          </View>
          <View style={styles.principle}>
            <Text style={styles.principleNumber}>02</Text>
            <Text style={styles.principleTitle}>Fair by design</Text>
            <Text style={styles.principleBody}>
              One vote each, no self-voting, with ties handled openly.
            </Text>
          </View>
        </View>

        <View style={styles.buildStatus}>
          <View
            style={[
              styles.statusDot,
              isConfigured ? styles.statusReady : styles.statusLocal,
            ]}
          />
          <Text style={styles.buildStatusText}>
            {isConfigured
              ? 'Backend configuration detected'
              : 'Local foundation preview'}
          </Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: colours.canvas,
  },
  content: {
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.xxl,
  },
  eyebrowRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
    paddingTop: spacing.md,
  },
  mark: {
    alignItems: 'center',
    backgroundColor: colours.forest,
    borderRadius: radii.sm,
    height: 32,
    justifyContent: 'center',
    width: 32,
  },
  markText: {
    color: colours.lime,
    fontSize: 17,
    fontWeight: '800',
  },
  brand: {
    color: colours.ink,
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 1.5,
  },
  hero: {
    paddingBottom: spacing.xl,
    paddingTop: spacing.xxl,
  },
  kicker: {
    color: colours.moss,
    fontSize: 13,
    fontWeight: '700',
    letterSpacing: 1.2,
    marginBottom: spacing.md,
    textTransform: 'uppercase',
  },
  title: {
    color: colours.ink,
    fontSize: 46,
    fontWeight: '800',
    letterSpacing: -2.1,
    lineHeight: 49,
    maxWidth: 340,
  },
  subtitle: {
    color: colours.inkMuted,
    fontSize: 17,
    lineHeight: 26,
    marginTop: spacing.md,
    maxWidth: 355,
  },
  cycleCard: {
    backgroundColor: colours.forest,
    borderRadius: radii.lg,
    padding: spacing.lg,
  },
  cardTopRow: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  cardLabel: {
    color: colours.lime,
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 1.1,
  },
  cardTitle: {
    color: colours.white,
    fontSize: 25,
    fontWeight: '700',
    letterSpacing: -0.6,
    marginTop: spacing.sm,
  },
  livePill: {
    alignItems: 'center',
    backgroundColor: '#254B41',
    borderRadius: radii.pill,
    flexDirection: 'row',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 7,
  },
  liveDot: {
    backgroundColor: colours.lime,
    borderRadius: radii.pill,
    height: 7,
    width: 7,
  },
  liveText: {
    color: colours.white,
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 0.8,
  },
  progressTrack: {
    backgroundColor: '#32564C',
    borderRadius: radii.pill,
    height: 8,
    marginTop: spacing.xl,
    overflow: 'hidden',
  },
  progressFill: {
    backgroundColor: colours.lime,
    borderRadius: radii.pill,
    height: '100%',
  },
  progressCopy: {
    alignItems: 'baseline',
    flexDirection: 'row',
    gap: 6,
    marginTop: spacing.sm,
  },
  progressStrong: {
    color: colours.white,
    fontSize: 14,
    fontWeight: '700',
  },
  progressMuted: {
    color: '#A9B9B3',
    fontSize: 13,
  },
  primaryButton: {
    alignItems: 'center',
    backgroundColor: colours.lime,
    borderRadius: radii.md,
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: spacing.lg,
    minHeight: 58,
    paddingHorizontal: spacing.md,
  },
  primaryButtonPressed: {
    opacity: 0.82,
  },
  primaryButtonText: {
    color: colours.ink,
    fontSize: 16,
    fontWeight: '800',
  },
  arrow: {
    color: colours.ink,
    fontSize: 24,
    lineHeight: 24,
  },
  principleRow: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginTop: spacing.lg,
  },
  principle: {
    backgroundColor: colours.surface,
    borderColor: colours.line,
    borderRadius: radii.md,
    borderWidth: 1,
    flex: 1,
    minHeight: 174,
    padding: spacing.md,
  },
  principleNumber: {
    color: colours.moss,
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 1,
  },
  principleTitle: {
    color: colours.ink,
    fontSize: 16,
    fontWeight: '700',
    marginTop: spacing.lg,
  },
  principleBody: {
    color: colours.inkMuted,
    fontSize: 13,
    lineHeight: 19,
    marginTop: spacing.sm,
  },
  buildStatus: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
    justifyContent: 'center',
    marginTop: spacing.xl,
  },
  statusDot: {
    borderRadius: radii.pill,
    height: 7,
    width: 7,
  },
  statusLocal: {
    backgroundColor: colours.amber,
  },
  statusReady: {
    backgroundColor: colours.moss,
  },
  buildStatusText: {
    color: colours.inkMuted,
    fontSize: 12,
    fontWeight: '600',
  },
});
