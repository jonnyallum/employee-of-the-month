import AsyncStorage from '@react-native-async-storage/async-storage';
import {
  createClient,
  processLock,
  type SupabaseClient,
} from '@supabase/supabase-js';
import 'react-native-url-polyfill/auto';

import { readPublicEnvironment } from './env';

let client: SupabaseClient | null = null;

export function getSupabaseClient(): SupabaseClient {
  if (client) return client;

  const environment = readPublicEnvironment();
  client = createClient(
    environment.supabaseUrl,
    environment.supabasePublishableKey,
    {
      auth: {
        storage: AsyncStorage,
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: false,
        lock: processLock,
      },
    },
  );

  return client;
}
