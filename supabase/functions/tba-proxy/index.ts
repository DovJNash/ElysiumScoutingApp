const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const allowedPath =
  /^\/district\/2027isr\/(?:teams|events)\/simple$|^\/event\/2027[a-z0-9]+\/(?:teams|matches)\/simple$|^\/team\/frc[1-9]\d*\/simple$/;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const apiKey = Deno.env.get("TBA_API_KEY");
  if (!apiKey) {
    return jsonResponse({ error: "TBA_API_KEY is not configured" }, 500);
  }

  let path: unknown;
  try {
    ({ path } = await request.json());
  } catch {
    return jsonResponse({ error: "Request body must be valid JSON" }, 400);
  }
  if (typeof path !== "string" || !allowedPath.test(path)) {
    return jsonResponse({ error: "Unsupported TBA endpoint" }, 400);
  }

  try {
    const response = await fetch(
      `https://www.thebluealliance.com/api/v3${path}`,
      {
        headers: {
          "X-TBA-Auth-Key": apiKey,
          "X-TBA-App-Id": "elysium1937.scouting.app",
        },
      },
    );
    const body = await response.text();
    return new Response(body, {
      status: response.status,
      headers: corsHeaders,
    });
  } catch {
    return jsonResponse({ error: "TBA request failed" }, 502);
  }
});
