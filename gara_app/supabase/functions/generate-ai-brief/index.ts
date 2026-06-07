import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");

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

  if (!GEMINI_API_KEY) {
    console.error("GEMINI_API_KEY secret is not set in Supabase Edge Function secrets.");
    return new Response(
      JSON.stringify({
        error: "GEMINI_API_KEY not configured",
        details:
          "Go to Supabase Dashboard -> Project Settings -> Edge Functions -> Secrets and add GEMINI_API_KEY.",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  const GEMINI_API_URL =
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=${GEMINI_API_KEY}`;

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

  const prompt = `You are a medical triage AI assistant for the Gara Telemedicine Platform in Rwanda. Generate a concise, objective clinical brief in English based on the following patient-reported information.

Patient: ${body.patientName}
Biological Sex: ${body.biologicalSex}
Symptom Category: ${body.symptomCategory}
Severity Level: ${body.severityLevel}
Duration of Symptoms: ${body.durationSymptoms}
Patient's Description: ${body.symptomDescription}

Format your response exactly as follows:

CLINICAL BRIEF:
- Presenting Complaint: [1-2 sentence summary]
- Duration: [summary]
- Severity Assessment: [assessment]
- Key Symptoms: [bullet points]
- Recommended Action: [recommendation]

Keep the response professional, objective, and under 250 words. Do not provide a diagnosis -- only summarize the reported symptoms for the attending doctor.`;

  try {
    console.log(`[generate-ai-brief] Calling Gemini for patient: ${body.patientName}`);

    const geminiResponse = await fetch(GEMINI_API_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.3,
          topP: 0.8,
          topK: 40,
          maxOutputTokens: 1024,
        },
        safetySettings: [
          { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_ONLY_HIGH" },
          { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_ONLY_HIGH" },
          { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_ONLY_HIGH" },
          { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_ONLY_HIGH" },
        ],
      }),
    });

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      console.error(`[generate-ai-brief] Gemini API error ${geminiResponse.status}: ${errorText}`);

      return new Response(
        JSON.stringify({
          error: "Gemini API error",
          details: `HTTP ${geminiResponse.status}: ${errorText}`,
        }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const data = await geminiResponse.json();

    if (data?.promptFeedback?.blockReason) {
      console.warn(`[generate-ai-brief] Prompt blocked: ${data.promptFeedback.blockReason}`);
      return new Response(
        JSON.stringify({
          error: "Content filtered",
          details: `Gemini blocked the prompt: ${data.promptFeedback.blockReason}`,
        }),
        { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!text) {
      console.error("[generate-ai-brief] No text in Gemini response:", JSON.stringify(data));
      return new Response(
        JSON.stringify({
          error: "No text in response",
          details: "Gemini returned an empty response. Check your API key quota.",
        }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[generate-ai-brief] Success -- brief generated (${text.length} chars)`);

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
