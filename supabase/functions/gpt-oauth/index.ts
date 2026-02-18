import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { corsHeaders } from "../_shared/cors.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    // OAuth token requests use application/x-www-form-urlencoded
    const contentType = req.headers.get("content-type") ?? "";
    let code: string | null = null;
    let grant_type: string | null = null;

    if (contentType.includes("application/x-www-form-urlencoded")) {
      const text = await req.text();
      const params = new URLSearchParams(text);
      code = params.get("code");
      grant_type = params.get("grant_type");
    } else {
      const body = await req.json();
      code = body.code;
      grant_type = body.grant_type;
    }

    if (grant_type !== "authorization_code") {
      return new Response(JSON.stringify({ error: "unsupported_grant_type" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!code) {
      return new Response(JSON.stringify({ error: "invalid_request", error_description: "code is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Validate that the code is a real api_key in our database
    const { data, error } = await supabase
      .from("api_keys")
      .select("user_id")
      .eq("key", code)
      .single();

    if (error || !data) {
      return new Response(JSON.stringify({ error: "invalid_grant", error_description: "Invalid authorization code" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Return the api_key as the access_token (our simplified OAuth)
    return new Response(JSON.stringify({
      access_token: code,
      token_type: "bearer",
      scope: "tasks",
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err: any) {
    return new Response(JSON.stringify({ error: "server_error", error_description: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
