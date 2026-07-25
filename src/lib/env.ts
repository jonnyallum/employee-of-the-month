export interface PublicEnvironment {
  supabaseUrl: string;
  supabasePublishableKey: string;
}

export class EnvironmentConfigurationError extends Error {
  override name = 'EnvironmentConfigurationError';
}

function clean(value: string | undefined): string {
  return value?.trim() ?? '';
}

function expoPublicEnvironment(): Record<string, string | undefined> {
  // Expo only inlines public environment variables accessed with dot notation.
  return {
    EXPO_PUBLIC_SUPABASE_URL: process.env.EXPO_PUBLIC_SUPABASE_URL,
    EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY:
      process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  };
}

export function readPublicEnvironment(
  source: Record<string, string | undefined> = expoPublicEnvironment(),
): PublicEnvironment {
  const supabaseUrl = clean(source.EXPO_PUBLIC_SUPABASE_URL);
  const supabasePublishableKey = clean(
    source.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  );
  const missing = [
    !supabaseUrl && 'EXPO_PUBLIC_SUPABASE_URL',
    !supabasePublishableKey && 'EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
  ].filter(Boolean);

  if (missing.length > 0) {
    throw new EnvironmentConfigurationError(
      `Missing public configuration: ${missing.join(', ')}.`,
    );
  }

  let parsedUrl: URL;
  try {
    parsedUrl = new URL(supabaseUrl);
  } catch {
    throw new EnvironmentConfigurationError(
      'EXPO_PUBLIC_SUPABASE_URL must be a valid HTTPS URL.',
    );
  }

  if (
    parsedUrl.protocol !== 'https:' &&
    !['localhost', '127.0.0.1'].includes(parsedUrl.hostname)
  ) {
    throw new EnvironmentConfigurationError(
      'EXPO_PUBLIC_SUPABASE_URL must use HTTPS outside local development.',
    );
  }

  if (
    supabasePublishableKey.startsWith('eyJ') ||
    supabasePublishableKey.includes('service_role')
  ) {
    throw new EnvironmentConfigurationError(
      'Use a Supabase publishable key in the app, never a service-role or legacy JWT key.',
    );
  }

  return { supabaseUrl, supabasePublishableKey };
}

export function hasPublicEnvironment(
  source: Record<string, string | undefined> = expoPublicEnvironment(),
): boolean {
  try {
    readPublicEnvironment(source);
    return true;
  } catch {
    return false;
  }
}
