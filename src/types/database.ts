export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      audit_events: {
        Row: {
          action: string
          actor_user_id: string | null
          entity_id: string | null
          entity_type: string
          id: number
          metadata: Json
          occurred_at: string
          organisation_id: string
        }
        Insert: {
          action: string
          actor_user_id?: string | null
          entity_id?: string | null
          entity_type: string
          id?: never
          metadata?: Json
          occurred_at?: string
          organisation_id: string
        }
        Update: {
          action?: string
          actor_user_id?: string | null
          entity_id?: string | null
          entity_type?: string
          id?: never
          metadata?: Json
          occurred_at?: string
          organisation_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "audit_events_organisation_id_fkey"
            columns: ["organisation_id"]
            isOneToOne: false
            referencedRelation: "organisations"
            referencedColumns: ["id"]
          },
        ]
      }
      device_push_tokens: {
        Row: {
          app_version: string | null
          created_at: string
          disabled_at: string | null
          id: string
          last_result: string | null
          last_seen_at: string
          organisation_id: string | null
          platform: string
          token: string
          user_id: string
        }
        Insert: {
          app_version?: string | null
          created_at?: string
          disabled_at?: string | null
          id?: string
          last_result?: string | null
          last_seen_at?: string
          organisation_id?: string | null
          platform?: string
          token: string
          user_id: string
        }
        Update: {
          app_version?: string | null
          created_at?: string
          disabled_at?: string | null
          id?: string
          last_result?: string | null
          last_seen_at?: string
          organisation_id?: string | null
          platform?: string
          token?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "device_push_tokens_organisation_id_fkey"
            columns: ["organisation_id"]
            isOneToOne: false
            referencedRelation: "organisations"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_deliveries: {
        Row: {
          attempt: number
          channel: string
          created_at: string
          cycle_id: string | null
          error_code: string | null
          event_type: string
          id: number
          idempotency_key: string
          result: string | null
          user_id: string | null
        }
        Insert: {
          attempt?: number
          channel: string
          created_at?: string
          cycle_id?: string | null
          error_code?: string | null
          event_type: string
          id?: never
          idempotency_key: string
          result?: string | null
          user_id?: string | null
        }
        Update: {
          attempt?: number
          channel?: string
          created_at?: string
          cycle_id?: string | null
          error_code?: string | null
          event_type?: string
          id?: never
          idempotency_key?: string
          result?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      organisation_invitations: {
        Row: {
          accepted_at: string | null
          created_at: string
          created_by: string | null
          email_normalised: string
          expires_at: string
          id: string
          organisation_id: string
          participant_id: string
          revoked_at: string | null
          token_hash: string
        }
        Insert: {
          accepted_at?: string | null
          created_at?: string
          created_by?: string | null
          email_normalised: string
          expires_at: string
          id?: string
          organisation_id: string
          participant_id: string
          revoked_at?: string | null
          token_hash: string
        }
        Update: {
          accepted_at?: string | null
          created_at?: string
          created_by?: string | null
          email_normalised?: string
          expires_at?: string
          id?: string
          organisation_id?: string
          participant_id?: string
          revoked_at?: string | null
          token_hash?: string
        }
        Relationships: [
          {
            foreignKeyName: "organisation_invitations_organisation_id_fkey"
            columns: ["organisation_id"]
            isOneToOne: false
            referencedRelation: "organisations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "organisation_invitations_participant_fk"
            columns: ["organisation_id", "participant_id"]
            isOneToOne: false
            referencedRelation: "participants"
            referencedColumns: ["organisation_id", "id"]
          },
        ]
      }
      organisation_members: {
        Row: {
          joined_at: string
          organisation_id: string
          role: string
          status: string
          updated_at: string
          user_id: string
        }
        Insert: {
          joined_at?: string
          organisation_id: string
          role: string
          status?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          joined_at?: string
          organisation_id?: string
          role?: string
          status?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "organisation_members_organisation_id_fkey"
            columns: ["organisation_id"]
            isOneToOne: false
            referencedRelation: "organisations"
            referencedColumns: ["id"]
          },
        ]
      }
      organisations: {
        Row: {
          created_at: string
          created_by: string | null
          deleted_at: string | null
          id: string
          name: string
          timezone: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          id?: string
          name: string
          timezone: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          id?: string
          name?: string
          timezone?: string
          updated_at?: string
        }
        Relationships: []
      }
      participants: {
        Row: {
          active: boolean
          avatar_path: string | null
          can_receive: boolean
          can_vote: boolean
          created_at: string
          display_name: string
          id: string
          left_at: string | null
          organisation_id: string
          team: string | null
          updated_at: string
          user_id: string | null
        }
        Insert: {
          active?: boolean
          avatar_path?: string | null
          can_receive?: boolean
          can_vote?: boolean
          created_at?: string
          display_name: string
          id?: string
          left_at?: string | null
          organisation_id: string
          team?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          active?: boolean
          avatar_path?: string | null
          can_receive?: boolean
          can_vote?: boolean
          created_at?: string
          display_name?: string
          id?: string
          left_at?: string | null
          organisation_id?: string
          team?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "participants_organisation_id_fkey"
            columns: ["organisation_id"]
            isOneToOne: false
            referencedRelation: "organisations"
            referencedColumns: ["id"]
          },
        ]
      }
      privacy_requests: {
        Row: {
          completed_at: string | null
          due_at: string | null
          id: string
          operator_note: string | null
          received_at: string
          request_type: string
          state: string
          user_id: string | null
        }
        Insert: {
          completed_at?: string | null
          due_at?: string | null
          id?: string
          operator_note?: string | null
          received_at?: string
          request_type: string
          state?: string
          user_id?: string | null
        }
        Update: {
          completed_at?: string | null
          due_at?: string | null
          id?: string
          operator_note?: string | null
          received_at?: string
          request_type?: string
          state?: string
          user_id?: string | null
        }
        Relationships: []
      }
      profiles: {
        Row: {
          created_at: string
          display_name: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          display_name: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          display_name?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      recognition_ballot_events: {
        Row: {
          cycle_id: string
          event_type: string
          id: number
          occurred_at: string
          organisation_id: string
        }
        Insert: {
          cycle_id: string
          event_type: string
          id?: never
          occurred_at?: string
          organisation_id: string
        }
        Update: {
          cycle_id?: string
          event_type?: string
          id?: never
          occurred_at?: string
          organisation_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "recognition_ballot_events_cycle_fk"
            columns: ["organisation_id", "cycle_id"]
            isOneToOne: false
            referencedRelation: "recognition_cycles"
            referencedColumns: ["organisation_id", "id"]
          },
          {
            foreignKeyName: "recognition_ballot_events_organisation_id_fkey"
            columns: ["organisation_id"]
            isOneToOne: false
            referencedRelation: "organisations"
            referencedColumns: ["id"]
          },
        ]
      }
      recognition_cycles: {
        Row: {
          closes_at: string | null
          created_at: string
          criteria: string | null
          id: string
          leaderboard_mode: string
          opens_at: string | null
          organisation_id: string
          period_month: string
          revealed_at: string | null
          revealed_by: string | null
          status: string
          tie_decision_note: string | null
          updated_at: string
          version: number
          winner_name: string | null
          winner_nominations: number | null
          winner_participant_id: string | null
        }
        Insert: {
          closes_at?: string | null
          created_at?: string
          criteria?: string | null
          id?: string
          leaderboard_mode?: string
          opens_at?: string | null
          organisation_id: string
          period_month: string
          revealed_at?: string | null
          revealed_by?: string | null
          status?: string
          tie_decision_note?: string | null
          updated_at?: string
          version?: number
          winner_name?: string | null
          winner_nominations?: number | null
          winner_participant_id?: string | null
        }
        Update: {
          closes_at?: string | null
          created_at?: string
          criteria?: string | null
          id?: string
          leaderboard_mode?: string
          opens_at?: string | null
          organisation_id?: string
          period_month?: string
          revealed_at?: string | null
          revealed_by?: string | null
          status?: string
          tie_decision_note?: string | null
          updated_at?: string
          version?: number
          winner_name?: string | null
          winner_nominations?: number | null
          winner_participant_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "recognition_cycles_organisation_id_fkey"
            columns: ["organisation_id"]
            isOneToOne: false
            referencedRelation: "organisations"
            referencedColumns: ["id"]
          },
        ]
      }
      recognition_nominations: {
        Row: {
          created_at: string
          cycle_id: string
          id: string
          idempotency_key: string | null
          moderated_at: string | null
          moderated_by: string | null
          moderation_reason: string | null
          nominator_participant_id: string
          nominator_user_id: string
          nominee_participant_id: string
          organisation_id: string
          reason: string | null
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          cycle_id: string
          id?: string
          idempotency_key?: string | null
          moderated_at?: string | null
          moderated_by?: string | null
          moderation_reason?: string | null
          nominator_participant_id: string
          nominator_user_id: string
          nominee_participant_id: string
          organisation_id: string
          reason?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          cycle_id?: string
          id?: string
          idempotency_key?: string | null
          moderated_at?: string | null
          moderated_by?: string | null
          moderation_reason?: string | null
          nominator_participant_id?: string
          nominator_user_id?: string
          nominee_participant_id?: string
          organisation_id?: string
          reason?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "recognition_nominations_cycle_fk"
            columns: ["organisation_id", "cycle_id"]
            isOneToOne: false
            referencedRelation: "recognition_cycles"
            referencedColumns: ["organisation_id", "id"]
          },
          {
            foreignKeyName: "recognition_nominations_nominator_fk"
            columns: ["organisation_id", "nominator_participant_id"]
            isOneToOne: false
            referencedRelation: "participants"
            referencedColumns: ["organisation_id", "id"]
          },
          {
            foreignKeyName: "recognition_nominations_nominee_fk"
            columns: ["organisation_id", "nominee_participant_id"]
            isOneToOne: false
            referencedRelation: "participants"
            referencedColumns: ["organisation_id", "id"]
          },
          {
            foreignKeyName: "recognition_nominations_organisation_id_fkey"
            columns: ["organisation_id"]
            isOneToOne: false
            referencedRelation: "organisations"
            referencedColumns: ["id"]
          },
        ]
      }
      recognition_settings: {
        Row: {
          created_at: string
          criteria_template: string | null
          email_reminders_default: boolean
          last_purge_at: string | null
          organisation_id: string
          push_reminders_default: boolean
          retention_months: number | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          criteria_template?: string | null
          email_reminders_default?: boolean
          last_purge_at?: string | null
          organisation_id: string
          push_reminders_default?: boolean
          retention_months?: number | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          criteria_template?: string | null
          email_reminders_default?: boolean
          last_purge_at?: string | null
          organisation_id?: string
          push_reminders_default?: boolean
          retention_months?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "recognition_settings_organisation_id_fkey"
            columns: ["organisation_id"]
            isOneToOne: true
            referencedRelation: "organisations"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      accept_invitation: { Args: { token: string }; Returns: string }
      add_participant: {
        Args: {
          display_name: string
          target_organisation_id: string
          team?: string
        }
        Returns: string
      }
      cast_nomination: {
        Args: {
          idempotency_key?: string
          nominee_participant_id: string
          reason?: string
          target_cycle_id: string
        }
        Returns: string
      }
      create_cycle: {
        Args: {
          closes_at?: string
          criteria?: string
          opens_at?: string
          period: string
          target_organisation_id: string
        }
        Returns: string
      }
      create_invitation: {
        Args: {
          invited_email: string
          target_participant_id: string
          valid_for?: string
        }
        Returns: {
          expires_at: string
          invitation_id: string
          token: string
        }[]
      }
      create_organisation: {
        Args: { organisation_name: string; organisation_timezone: string }
        Returns: string
      }
      delete_organisation: {
        Args: { confirm_name: string; target_organisation_id: string }
        Returns: string
      }
      export_my_data: { Args: never; Returns: Json }
      get_admin_nominations: {
        Args: { target_cycle_id: string }
        Returns: {
          created_date: string
          id: string
          moderated_at: string
          moderation_reason: string
          nominee_display_name: string
          nominee_participant_id: string
          reason: string
          status: string
        }[]
      }
      get_closed_standings: {
        Args: { target_cycle_id: string }
        Returns: {
          display_name: string
          nominations: number
          participant_id: string
          rank: number
        }[]
      }
      get_cycle_confidentiality: {
        Args: { target_cycle_id: string }
        Returns: string
      }
      get_cycle_turnout: {
        Args: { target_cycle_id: string }
        Returns: {
          ballots_counted: number
          eligible_voters: number
          turnout_percent: number
        }[]
      }
      get_my_nomination: {
        Args: { target_cycle_id: string }
        Returns: {
          created_at: string
          id: string
          nominee_display_name: string
          nominee_participant_id: string
          reason: string
          status: string
        }[]
      }
      get_my_participant: {
        Args: { target_organisation_id: string }
        Returns: {
          can_receive: boolean
          can_vote: boolean
          display_name: string
          id: string
          team: string
        }[]
      }
      get_my_privacy_requests: {
        Args: never
        Returns: {
          completed_at: string
          due_at: string
          id: string
          received_at: string
          request_type: string
          state: string
        }[]
      }
      get_roster: {
        Args: { target_organisation_id: string }
        Returns: {
          active: boolean
          can_receive: boolean
          can_vote: boolean
          display_name: string
          has_account: boolean
          id: string
          invitation_expires_at: string
          invited_email: string
          team: string
        }[]
      }
      leave_organisation: {
        Args: { target_organisation_id: string }
        Returns: undefined
      }
      moderate_nomination: {
        Args: {
          action: string
          moderation_reason: string
          target_nomination_id: string
        }
        Returns: undefined
      }
      purge_expired_nominations: {
        Args: { dry_run?: boolean }
        Returns: {
          cycle_id: string
          nominations_affected: number
          organisation_id: string
          period_month: string
        }[]
      }
      redact_winner_snapshot: {
        Args: {
          mode: string
          redaction_reason: string
          target_cycle_id: string
        }
        Returns: undefined
      }
      request_account_deletion: { Args: never; Returns: string }
      reveal_winner: {
        Args: {
          decision_note?: string
          expected_version: number
          target_cycle_id: string
          tied_participant_id?: string
        }
        Returns: string
      }
      revoke_invitation: {
        Args: { target_invitation_id: string }
        Returns: undefined
      }
      transfer_ownership: {
        Args: { new_owner_user_id: string; target_organisation_id: string }
        Returns: undefined
      }
      transition_cycle: {
        Args: {
          expected_version: number
          next_status: string
          target_cycle_id: string
        }
        Returns: number
      }
      update_participant: {
        Args: {
          active: boolean
          can_receive: boolean
          can_vote: boolean
          target_participant_id: string
        }
        Returns: undefined
      }
      withdraw_nomination: {
        Args: { target_cycle_id: string }
        Returns: undefined
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {},
  },
} as const

