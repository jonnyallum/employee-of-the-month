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
        // PKCE, not the default implicit flow. Under implicit, a confirmation
        // link returns the access token and refresh token in the URL fragment,
        // so they appear in the address bar, in browser history and in anything
        // that logs or shares a URL. A real signup link produced exactly that
        // during testing, and the tokens had to be revoked.
        //
        // PKCE returns a single-use `code` instead, which is worthless without
        // the verifier held in this client's storage. Nothing sensitive travels
        // in a URL.
        flowType: 'pkce',
      },
    },
  );

  return client;
}
