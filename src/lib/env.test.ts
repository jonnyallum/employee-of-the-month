import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  EnvironmentConfigurationError,
  hasPublicEnvironment,
  readPublicEnvironment,
} from './env';

const validEnvironment = {
  EXPO_PUBLIC_SUPABASE_URL: 'https://example.supabase.co',
  EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_example',
};

test('reads the two public Supabase values', () => {
  assert.deepEqual(readPublicEnvironment(validEnvironment), {
    supabaseUrl: validEnvironment.EXPO_PUBLIC_SUPABASE_URL,
    supabasePublishableKey:
      validEnvironment.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  });
});

test('reports every missing value in one actionable error', () => {
  assert.throws(
    () => readPublicEnvironment({}),
    (error: unknown) =>
      error instanceof EnvironmentConfigurationError &&
      error.message.includes('EXPO_PUBLIC_SUPABASE_URL') &&
      error.message.includes('EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY'),
  );
});

test('rejects service-role and legacy JWT-shaped keys', () => {
  assert.throws(
    () =>
      readPublicEnvironment({
        ...validEnvironment,
        EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: 'service_role_secret',
      }),
    /never a service-role/,
  );
  assert.throws(
    () =>
      readPublicEnvironment({
        ...validEnvironment,
        EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: 'eyJlegacy-jwt',
      }),
    /legacy JWT/,
  );
});

test('requires HTTPS away from local development', () => {
  assert.throws(
    () =>
      readPublicEnvironment({
        ...validEnvironment,
        EXPO_PUBLIC_SUPABASE_URL: 'http://example.supabase.co',
      }),
    /must use HTTPS/,
  );
  assert.equal(
    hasPublicEnvironment({
      ...validEnvironment,
      EXPO_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:54321',
    }),
    true,
  );
});
