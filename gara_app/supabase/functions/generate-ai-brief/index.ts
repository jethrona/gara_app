import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

// ── SETUP ─────────────────────────────────────────────────────────────────
// 1. Get a free API key at https://console.groq.com
// 2. Supabase Dashboard → Project Settings → Edge Functions → Secrets
//    Add: GROQ_API_KEY = <your key>
// 3. Deploy: supabase functions deploy generate-ai-brief --project-ref <ref>
// ──────────────────────────────────────────────────────────────────────────

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface GenerateRequest {
  biologicalSex: string;
  severityLevel: string;
  durationSymptoms: string;
  symptomCategory: string;
  symptomDescription: string;
  patientName: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed. Use POST." }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  if (!GROQ_API_KEY) {
    return new Response(
      JSON.stringify({
        error: "GROQ_API_KEY not configured",
        details:
          "Go to Supabase Dashboard → Project Settings → Edge Functions → Secrets and add GROQ_API_KEY.",
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  let body: GenerateRequest;
  try {
    body = await req.json();
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "Invalid JSON body", details: String(e) }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const required = [
    "biologicalSex", "severityLevel", "durationSymptoms",
    "symptomCategory", "symptomDescription", "patientName",
  ] as const;
  for (const field of required) {
    if (!body[field]) {
      return new Response(
        JSON.stringify({ error: `Missing required field: ${field}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
  }

  const systemPrompt =
    "You are a medical triage AI assistant for the Gara Telemedicine Platform in Rwanda. " +
    "Generate a concise, objective clinical brief in English based on the patient-reported information below. " +
    "Format your response exactly as follows:\n\n" +
    "CLINICAL BRIEF:\n" +
    "- Presenting Complaint: [1-2 sentence summary]\n" +
    "- Duration: [summary]\n" +
    "- Severity Assessment: [assessment]\n" +
    "- Key Symptoms: [bullet points]\n" +
    "- Recommended Action: [recommendation]\n\n" +
    "Keep the response professional, objective, and under 250 words. " +
    "Do not provide a diagnosis — only summarize the reported symptoms for the attending doctor.";

  const userPrompt =
    `Patient: ${body.patientName}\n` +
    `Biological Sex: ${body.biologicalSex}\n` +
    `Symptom Category: ${body.symptomCategory}\n` +
    `Severity Level: ${body.severityLevel}\n` +
    `Duration of Symptoms: ${body.durationSymptoms}\n` +
    `Patient's Description: ${body.symptomDescription}`;

  try {
    console.log(`[generate-ai-brief] Calling Groq for patient: ${body.patientName}`);

    const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${GROQ_API_KEY}`,
      },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
        temperature: 0.3,
        max_tokens: 1024,
        top_p: 0.8,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`[generate-ai-brief] Groq API error ${response.status}: ${errorText}`);
      return new Response(
        JSON.stringify({
          error: "Groq API error",
          details: `HTTP ${response.status}: ${errorText}`,
        }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const data = await response.json();
    const text = data?.choices?.[0]?.message?.content;

    if (!text) {
      console.error("[generate-ai-brief] No text in Groq response:", JSON.stringify(data));
      return new Response(
        JSON.stringify({
          error: "No text in response",
          details: "Groq returned an empty response.",
        }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[generate-ai-brief] Success — brief generated (${text.length} chars)`);

    return new Response(
      JSON.stringify({ brief: text.trim() }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (e) {
    console.error("[generate-ai-brief] Unexpected function error:", e);
    return new Response(
      JSON.stringify({ error: "Internal error", details: String(e) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
