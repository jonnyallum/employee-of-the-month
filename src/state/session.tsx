import type { Session } from '@supabase/supabase-js';
import {
  createContext,
  type ReactNode,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react';

import { getSupabaseClient } from '@/lib/supabase';

interface SessionValue {
  session: Session | null;
  /** True until the stored session has been read. Guards must wait for this. */
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
}

const SessionContext = createContext<SessionValue | null>(null);

export function SessionProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const client = getSupabaseClient();
    let active = true;

    // Read the persisted session first so a returning user is not bounced to
    // sign-in for the moment it takes to restore.
    client.auth.getSession().then(({ data }) => {
      if (!active) return;
      setSession(data.session);
      setLoading(false);
    });

    // The subscription is what makes a revoked or expired session take effect
    // without a restart. Route guards read this, never a cached copy.
    const { data: subscription } = client.auth.onAuthStateChange(
      (_event, next) => {
        if (!active) return;
        setSession(next);
        setLoading(false);
      },
    );

    return () => {
      active = false;
      subscription.subscription.unsubscribe();
    };
  }, []);

  const value = useMemo<SessionValue>(
    () => ({
      session,
      loading,
      async signIn(email, password) {
        const client = getSupabaseClient();
        const { error } = await client.auth.signInWithPassword({
          email: email.trim().toLowerCase(),
          password,
        });
        if (error) throw error;
      },
      async signOut() {
        await getSupabaseClient().auth.signOut();
      },
    }),
    [session, loading],
  );

  return (
    <SessionContext.Provider value={value}>{children}</SessionContext.Provider>
  );
}

export function useSession(): SessionValue {
  const value = useContext(SessionContext);
  if (!value) {
    throw new Error('useSession must be used inside a SessionProvider.');
  }
  return value;
}
