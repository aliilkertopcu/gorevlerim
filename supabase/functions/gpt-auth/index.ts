import { corsHeaders } from "../_shared/cors.ts";

// This function acts as a proxy authorization URL on the supabase.co domain.
// CustomGPT requires authorizationUrl, tokenUrl, and API host to share a domain.
// We receive the OAuth params and redirect the user to the Flutter web app to handle login/consent.

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const redirectUri = url.searchParams.get("redirect_uri") ?? "";
  const state = url.searchParams.get("state") ?? "";
  const clientId = url.searchParams.get("client_id") ?? "";

  // Build the Flutter web consent page URL, passing through OAuth params
  const flutterAppUrl = new URL("https://aliilkertopcu.github.io/gorevlerim/");
  flutterAppUrl.hash = `/gpt-connect?redirect_uri=${encodeURIComponent(redirectUri)}&state=${encodeURIComponent(state)}&client_id=${encodeURIComponent(clientId)}`;

  return new Response(null, {
    status: 302,
    headers: {
      ...corsHeaders,
      "Location": flutterAppUrl.toString(),
    },
  });
});
