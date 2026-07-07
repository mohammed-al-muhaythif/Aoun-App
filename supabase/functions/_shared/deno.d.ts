// IDE-only type shims for Supabase Edge Functions.
// At runtime these come from Deno itself + esm.sh URL imports.

declare const Deno: {
  env: { get(name: string): string | undefined };
  serve(handler: (req: Request) => Response | Promise<Response>): void;
};

declare module 'https://esm.sh/@supabase/supabase-js@2.45.0' {
  // Loose shim — full types live in the runtime esm.sh module.
  export function createClient(
    url: string,
    key: string,
    options?: Record<string, unknown>,
  ): {
    auth: {
      admin: {
        createUser(input: Record<string, unknown>): Promise<{ data: { user?: { id: string } } | null; error: unknown }>;
        listUsers(input?: Record<string, unknown>): Promise<{ data: { users: Array<{ id: string; email?: string }> } | null; error: unknown }>;
        updateUserById(id: string, input: Record<string, unknown>): Promise<unknown>;
      };
      getUser(): Promise<{ data: { user?: { id: string } | null }; error: unknown }>;
    };
    from(table: string): any;
    functions: { invoke(name: string, opts?: Record<string, unknown>): Promise<{ data: unknown; error: unknown }> };
  };
}
