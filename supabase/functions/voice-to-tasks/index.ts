// voice-to-tasks — Turkish speech → structured task proposal
//
// Flow:
//   1. Authenticate the app user via Supabase JWT (Authorization: Bearer <access_token>)
//   2. Enforce a per-user daily audio quota (voice_usage table)
//   3. Groq Whisper (whisper-large-v3-turbo, language=tr) → transcript
//   4. Groq LLM with strict JSON schema → { tasks: [...], ignored: [...] }
//   5. Return the proposal; the client shows a preview and writes to DB on confirm
//
// Request: multipart/form-data
//   file              audio (webm/ogg/m4a/mp3/wav), ≤ 25 MB
//   duration_seconds  (optional) client-measured duration, used as fallback
//   date              (optional) YYYY-MM-DD, the day the user is looking at (default: today)
//
// Env (supabase secrets set ...):
//   GROQ_API_KEY            required
//   GROQ_STT_MODEL          default whisper-large-v3-turbo
//   GROQ_LLM_MODEL          default qwen/qwen3.8-27b
//   VOICE_DAILY_LIMIT_SEC   default 600 (10 minutes)
//   VOICE_MAX_CLIP_SEC      default 600

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { corsHeaders } from "../_shared/cors.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const STT_MODEL = Deno.env.get("GROQ_STT_MODEL") ?? "whisper-large-v3-turbo";
const LLM_MODEL = Deno.env.get("GROQ_LLM_MODEL") ?? "qwen/qwen3.8-27b";
const DAILY_LIMIT = Number(Deno.env.get("VOICE_DAILY_LIMIT_SEC") ?? "600");
const MAX_CLIP = Number(Deno.env.get("VOICE_MAX_CLIP_SEC") ?? "600");
const MAX_BYTES = 25 * 1024 * 1024;

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" };

function reply(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function todayISO(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

// ---------- Auth ----------
async function authenticate(req: Request): Promise<string | null> {
  const auth = req.headers.get("authorization");
  if (!auth?.startsWith("Bearer ")) return null;
  const { data, error } = await supabase.auth.getUser(auth.slice(7));
  if (error || !data.user) return null;
  return data.user.id;
}

// ---------- Groq: speech to text ----------
interface Transcript {
  text: string;
  durationSec: number;
}

async function transcribe(file: File, fallbackDuration: number): Promise<Transcript> {
  const form = new FormData();
  form.append("file", file, file.name || "audio.webm");
  form.append("model", STT_MODEL);
  form.append("language", "tr");
  form.append("response_format", "verbose_json");
  form.append("temperature", "0");

  const res = await fetch("https://api.groq.com/openai/v1/audio/transcriptions", {
    method: "POST",
    headers: { Authorization: `Bearer ${GROQ_API_KEY}` },
    body: form,
  });

  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`STT failed (${res.status}): ${detail.slice(0, 300)}`);
  }

  const data = await res.json();
  let duration = Number(data.duration);
  if (!duration || Number.isNaN(duration)) {
    const segs = Array.isArray(data.segments) ? data.segments : [];
    duration = segs.length ? Number(segs[segs.length - 1].end) : fallbackDuration;
  }
  return { text: cleanTranscript(data.text ?? ""), durationSec: Math.ceil(duration || fallbackDuration || 0) };
}

// Whisper hallucinates on silence, typically as a short phrase repeated many times
// ("abone ol abone ol abone ol...", "Altyazı M.K."). Collapse 3+ consecutive repeats.
function cleanTranscript(raw: string): string {
  let text = raw.replace(/\s+/g, " ").trim();
  // phrase of 1-6 words repeated 3+ times back to back → keep one copy
  text = text.replace(/\b((?:\S+\s+){0,5}\S+?)(?:[\s,.]+\1){2,}\b/giu, "$1");
  return text.trim();
}

// ---------- Groq: transcript → tasks ----------
const taskSchema = {
  type: "object",
  properties: {
    tasks: {
      type: "array",
      items: {
        type: "object",
        properties: {
          title: { type: "string" },
          description: { type: "string" },
          date: { type: "string", description: "YYYY-MM-DD" },
          subtasks: { type: "array", items: { type: "string" } },
        },
        required: ["title", "description", "date", "subtasks"],
        additionalProperties: false,
      },
    },
    ignored: {
      type: "array",
      items: { type: "string" },
      description: "Transcript fragments that were not tasks",
    },
  },
  required: ["tasks", "ignored"],
  additionalProperties: false,
};

function buildSystemPrompt(viewDate: string): string {
  const today = todayISO();
  return `Sen bir görev asistanısın. Kullanıcı Türkçe konuşarak yapacağı işleri anlatıyor; sen bu konuşmadan yapılandırılmış görev listesi çıkarıyorsun.

Bugünün tarihi: ${today}. Kullanıcının uygulamada baktığı gün: ${viewDate}. Tarih söylenmeyen görevleri ${viewDate} tarihine koy.

Kurallar:
- Sadece yapılacak iş niteliğindeki ifadeleri görev yap. Sohbet, düşünce, arka plandaki kişilere veya hayvanlara söylenen sözler ("dur", "köpek yapma", "bir saniye"), tekrarlar ve dolgu kelimeleri görev DEĞİLDİR; bunları "ignored" listesine kısa parçalar halinde koy.
- Kullanıcı "alt görev", "bunun altına", "şunları da içersin", "adımları" gibi ifadelerle hiyerarşi kurarsa alt görev olarak yapılandır. Birbirine bağlı küçük adımlar varsa ana görev + alt görevler olarak grupla.
- Görev başlıkları kısa, emir kipinde, ilk harfi büyük olsun ("Market alışverişi yap"). Açıklamaya sadece başlığa sığmayan gerçek detayı yaz; yoksa boş string.
- Tarihleri çöz: "bugün" = ${today}; "yarın", "cuma", "haftaya", "ayın 15'i" gibi ifadeleri ${today} tarihine göre YYYY-MM-DD formatına çevir. Belirsizse ${viewDate}.
- Aynı görevi iki kez yazma; kullanıcı kendini düzeltirse ("yok onu iptal et") son halini al.
- Konuşmada hiç görev yoksa tasks boş dizi olsun.
- Sadece şemaya uygun JSON döndür.`;
}

interface Proposal {
  tasks: { title: string; description: string; date: string; subtasks: string[] }[];
  ignored: string[];
}

async function extractTasks(transcript: string, viewDate: string): Promise<Proposal> {
  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${GROQ_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: LLM_MODEL,
      temperature: 0.2,
      messages: [
        { role: "system", content: buildSystemPrompt(viewDate) },
        { role: "user", content: transcript },
      ],
      response_format: {
        type: "json_schema",
        json_schema: { name: "task_proposal", strict: true, schema: taskSchema },
      },
    }),
  });

  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`LLM failed (${res.status}): ${detail.slice(0, 300)}`);
  }

  const data = await res.json();
  const content = data.choices?.[0]?.message?.content ?? "{}";
  const parsed = JSON.parse(content) as Proposal;

  // Defensive cleanup
  parsed.tasks = (parsed.tasks ?? [])
    .map((t) => ({
      title: (t.title ?? "").trim(),
      description: (t.description ?? "").trim(),
      date: /^\d{4}-\d{2}-\d{2}$/.test(t.date ?? "") ? t.date : viewDate,
      subtasks: (t.subtasks ?? []).map((s) => (s ?? "").trim()).filter(Boolean),
    }))
    .filter((t) => t.title.length > 0);
  parsed.ignored = (parsed.ignored ?? []).map((s) => (s ?? "").trim()).filter(Boolean);
  return parsed;
}

// ---------- Quota ----------
async function getUsedToday(userId: string): Promise<number> {
  const { data } = await supabase
    .from("voice_usage")
    .select("seconds_used")
    .eq("user_id", userId)
    .eq("usage_date", todayISO())
    .maybeSingle();
  return data?.seconds_used ?? 0;
}

async function recordUsage(userId: string, seconds: number): Promise<number> {
  const { data, error } = await supabase.rpc("increment_voice_usage", {
    p_user_id: userId,
    p_seconds: seconds,
  });
  if (error) throw error;
  return Number(data);
}

// ---------- Handler ----------
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  if (!GROQ_API_KEY) return reply({ error: "GROQ_API_KEY tanımlı değil" }, 500);

  const userId = await authenticate(req);
  if (!userId) return reply({ error: "Unauthorized" }, 401);

  // GET-like status probe: POST with ?status=1 returns quota only
  const url = new URL(req.url);
  if (url.searchParams.get("status") === "1") {
    const used = await getUsedToday(userId);
    return reply({ used_seconds: used, limit_seconds: DAILY_LIMIT });
  }

  try {
    const form = await req.formData();
    const file = form.get("file");
    if (!(file instanceof File)) return reply({ error: "file alanı gerekli" }, 400);
    if (file.size > MAX_BYTES) return reply({ error: "Ses dosyası 25 MB'den büyük" }, 413);

    const clientDuration = Math.ceil(Number(form.get("duration_seconds") ?? 0)) || 0;
    const viewDateRaw = String(form.get("date") ?? "");
    const viewDate = /^\d{4}-\d{2}-\d{2}$/.test(viewDateRaw) ? viewDateRaw : todayISO();

    if (clientDuration > MAX_CLIP) {
      return reply({ error: `Tek kayıt en fazla ${Math.floor(MAX_CLIP / 60)} dakika olabilir` }, 400);
    }

    // Pre-check quota with the client-reported duration (cheap, avoids a wasted STT call)
    const usedBefore = await getUsedToday(userId);
    if (usedBefore >= DAILY_LIMIT || usedBefore + clientDuration > DAILY_LIMIT) {
      return reply({
        error: "quota_exceeded",
        message: "Bugünkü ses kaydı limitin doldu. Yarın tekrar deneyebilirsin.",
        used_seconds: usedBefore,
        limit_seconds: DAILY_LIMIT,
      }, 429);
    }

    const transcript = await transcribe(file, clientDuration);

    // Record actual duration (server-measured), even if transcript is empty
    const usedAfter = await recordUsage(userId, Math.max(transcript.durationSec, 1));

    if (!transcript.text) {
      return reply({
        transcript: "",
        tasks: [],
        ignored: [],
        used_seconds: usedAfter,
        limit_seconds: DAILY_LIMIT,
        message: "Kayıtta konuşma algılanamadı.",
      });
    }

    const proposal = await extractTasks(transcript.text, viewDate);

    return reply({
      transcript: transcript.text,
      tasks: proposal.tasks,
      ignored: proposal.ignored,
      used_seconds: usedAfter,
      limit_seconds: DAILY_LIMIT,
      models: { stt: STT_MODEL, llm: LLM_MODEL },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("voice-to-tasks error:", message);
    return reply({ error: message }, 500);
  }
});
