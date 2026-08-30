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
const STT_MODEL = Deno.env.get("GROQ_STT_MODEL") ?? "whisper-large-v3";
const KEEP_AUDIO = (Deno.env.get("VOICE_KEEP_AUDIO") ?? "true") !== "false"; // store clips for prompt tuning
const AUDIO_BUCKET = "voice-audio";
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

// Groq free tier is rate limited per minute (429). Retry with backoff before giving up.
async function fetchWithRetry(input: string, init: RequestInit, label: string, attempts = 4): Promise<Response> {
  let last: Response | null = null;
  for (let i = 0; i < attempts; i++) {
    const res = await fetch(input, init);
    if (res.status !== 429 && res.status < 500) return res;
    last = res;
    const retryAfter = Number(res.headers.get("retry-after"));
    const waitMs = Math.min(15000, (retryAfter > 0 ? retryAfter * 1000 : 1500 * 2 ** i));
    console.warn(`${label}: ${res.status}, retrying in ${waitMs}ms`);
    await res.body?.cancel();
    await new Promise((r) => setTimeout(r, waitMs));
  }
  return last!;
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

async function transcribe(file: File, fallbackDuration: number, vocabulary: string[], prevText = ""): Promise<Transcript> {
  const form = new FormData();
  form.append("file", file, file.name || "audio.webm");
  form.append("model", STT_MODEL);
  form.append("language", "tr");
  form.append("response_format", "verbose_json");
  form.append("temperature", "0");
  // Style/vocabulary hint: proper Turkish punctuation, task phrasing, and the
  // names/terms this user actually uses (group members, recent task words).
  const vocab = vocabulary.length ? `Kişiler ve terimler: ${vocabulary.join(", ")}. ` : "";
  // For streamed segments, the tail of the previous segment keeps Whisper's context continuous.
  const tail = prevText ? ` ${prevText.slice(-160)}` : "";
  form.append("prompt", `${vocab}Bugünkü görevler: çamaşırları makineye at, bulaşık makinesini boşalt, mutfağı topla. Ana başlık: taahhüt işleri. Alt görev: internet aboneliği anlaşmasını yap. Yarına iş: faturayı yatır.${tail}`);

  const res = await fetchWithRetry("https://api.groq.com/openai/v1/audio/transcriptions", {
    method: "POST",
    headers: { Authorization: `Bearer ${GROQ_API_KEY}` },
    body: form,
  }, "STT");

  if (res.status === 429) throw new Error("Ses tanıma şu an yoğun, birkaç saniye sonra tekrar dene");
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
const HALLUCINATIONS = [
  /altyaz[ıi]\s*m\.?\s*k\.?/gi,
  /\baltyaz[ıi]\b:?\s*[a-zçğıöşü. ]{0,25}$/gi,
  /\babone ol(un)?\b\.?/gi,
  /izledi[ğg]iniz için teşekkür(ler| ederim)\.?/gi,
  /kanal[ıi]ma abone ol[a-zçğıöşü]*\.?/gi,
];

function cleanTranscript(raw: string): string {
  let text = raw.replace(/\s+/g, " ").trim();
  for (const re of HALLUCINATIONS) text = text.replace(re, " ");
  text = text.replace(/\s+/g, " ").trim();
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
    actions: {
      type: "array",
      description: "Changes to EXISTING tasks referenced by id from the context list",
      items: {
        type: "object",
        properties: {
          type: { type: "string", enum: ["complete", "uncomplete", "postpone", "delete", "complete_subtask"] },
          task_id: { type: "string" },
          subtask_id: { type: "string", description: "only for complete_subtask, else empty string" },
          target_date: { type: "string", description: "YYYY-MM-DD for postpone, else empty string" },
        },
        required: ["type", "task_id", "subtask_id", "target_date"],
        additionalProperties: false,
      },
    },
    ignored: {
      type: "array",
      items: { type: "string" },
      description: "Transcript fragments that were not tasks",
    },
  },
  required: ["tasks", "actions", "ignored"],
  additionalProperties: false,
};

interface ContextSubtask { id: string; title: string; status: string }
interface ContextTask { id: string; title: string; status: string; date?: string; subtasks: ContextSubtask[] }

function renderContext(tasks: ContextTask[]): string {
  if (!tasks.length) return "";
  const lines = tasks.slice(0, 60).map((t) => {
    const st = t.status === "completed" ? "✓" : t.status === "blocked" ? "⛔" : "○";
    const subs = (t.subtasks ?? [])
      .slice(0, 20)
      .map((s) => `    - [subtask_id=${s.id}] ${s.status === "completed" ? "✓" : "○"} ${s.title}`)
      .join("\n");
    return `  - [task_id=${t.id}] ${st} ${t.title}${t.date ? ` (${t.date})` : ""}${subs ? "\n" + subs : ""}`;
  });
  return `\nMEVCUT GÖREVLER (kullanıcının şu an baktığı liste; ○ bekliyor, ✓ tamamlandı):\n${lines.join("\n")}\n`;
}

function buildSystemPrompt(viewDate: string, groupName: string, context: ContextTask[]): string {
  const today = todayISO();
  const groupLine = groupName
    ? `Görevler "${groupName}" adlı listeye eklenecek; bu listenin adı zaten bağlamı verir, aynı adla bir üst görev UYDURMA.`
    : "";
  const contextBlock = renderContext(context);
  const actionRules = context.length
    ? `
MEVCUT GÖREVLER ÜZERİNDE İŞLEM (actions): Kullanıcı yukarıdaki listedeki bir görevden bahsediyorsa YENİ GÖREV AÇMA, actions'a yaz:
- "X tamamlandı / bitti / yaptım / hallettim / X'i işaretle" → {type:"complete", task_id}
- "X aslında bitmedi / geri al" → {type:"uncomplete", task_id}
- "X'i yarına/cumaya ertele, X'i sonraya bırak" → {type:"postpone", task_id, target_date: YYYY-MM-DD}
- "X'i sil / iptal et / kaldır" → {type:"delete", task_id}
- Bir ALT görev tamamlandıysa → {type:"complete_subtask", task_id, subtask_id}
Eşleştirme: söylenen ifade ile listedeki başlık aynı işi anlatıyorsa eşleştir (kelime birebir olmak zorunda değil: "süpürge" → "Xiaomi robot süpürgenin arızasını incele"). Listede karşılığı yoksa aksiyon ÜRETME, gerekiyorsa yeni görev olarak ekle. task_id/subtask_id yalnızca listedeki id'lerden olabilir; asla uydurma. Kullanılmayan alanlar boş string.
`
    : "";
  return `Sen bir görev asistanısın. Kullanıcı Türkçe konuşarak yapacağı işleri anlatıyor; sen bu konuşmadan yapılandırılmış görev listesi çıkarıyorsun ve mevcut görevler üzerinde istediği değişiklikleri belirliyorsun.

Bugünün tarihi: ${today}. Kullanıcının uygulamada baktığı gün: ${viewDate}. Tarih söylenmeyen görevleri ${viewDate} tarihine koy.
${groupLine}
${contextBlock}${actionRules}

Metin otomatik ses tanımadan geliyor; yanlış duyulmuş kelimeler olabilir. Bağlamdan açıkça anlaşılan hataları düzelt ("İstanbul'a giriş için hazırlanan çanta" → "İstanbul'a gidiş", "mutfak topla" → "mutfağı topla"). Emin olmadığın yerde metne sadık kal.

YAPI İŞARETLERİ (en önemli kural): Kullanıcı konuşurken yapıyı sözle kurar. Bu ifadeler görev DEĞİLDİR, gürültü de DEĞİLDİR; birer KOMUTTUR ve ignored'a da yazılmaz:
- "ana başlık X", "ana görev X", "başlık X", "yeni görev X", "yeni iş X", "başka bir iş X", "bir de X" → X adında YENİ bir ana görev başlar.
- "alt görev Y", "birinci/ikinci/üçüncü alt görev Y", "bunun altına Y", "adımları: …", "şunları da içersin" → Y, EN SON açılan ana görevin ALT GÖREVİ olur. Yeni bir ana görev işareti gelene kadar sonraki maddeler de aynı ana görevin altına gider.
- Tarih ifadeleri kapsamlıdır: "bugüne", "yarına iş", "cumaya", "haftaya" gibi bir ifade, kendisinden SONRA gelen görev(ler)e uygulanır; yeni bir tarih ifadesi gelene kadar geçerlidir. "bugün" = ${today}; "yarın", "cuma", "haftaya", "ayın 15'i" ifadelerini ${today} tarihine göre YYYY-MM-DD yap.

- GERİYE DÖNÜK gruplama: "bunu/bunları X'in işi olarak üst başlık altına ekle", "hepsini X başlığı altına koy", "bunlar X'in altına" gibi bir talimat, kendisinden ÖNCE sayılan maddeleri de kapsar; o ana kadar açılmış bir ana görev yoksa kayıttaki tüm düz maddeler (öncekiler ve sonrakiler) X adlı ana görevin alt görevleri olur.

GÖREV SAYILAN İFADELER: emir kipi ("balkonu yıka"), gelecek zaman ("odamı toplayacağım"), EDİLGEN gelecek zaman ("balkonlar yıkanacak", "çamaşırlar dürülecek", "ütü yapılacak", "bir saat uyunacak"), "-nın yapılması / -nın alınması" ad tamlamaları, "… lazım / … gerekiyor". Bunların HEPSİ görevdir; asla ignored'a gitmez. Edilgen/ad tamlaması kalıplarını emir kipine çevir: "Balkonlar yıkanacak" → "Balkonları yıka", "faturanın yatırılması" → "Faturayı yatır", "bir saat uyulacak" → "Bir saat uyu".

ÖRNEK 1
Metin: "Bugüne yeni görev. Ana başlık taahhüt işleri. Alt görev, muayenehanenin internet aboneliğinin yapılması. İkinci alt görev, Türk Telekom hattımın ne zaman bittiğinin netleştirilmesi. Bugünün yeni işi, arabanın temizlenmesi. Yarına iş, asansör bakım faturasının yatırılması."
Çıktı: tasks = [
  {title: "Taahhüt işleri", date: ${today}, subtasks: ["Muayenehanenin internet aboneliğini yap", "Türk Telekom hattının bitiş tarihini netleştir"]},
  {title: "Arabayı temizle", date: ${today}, subtasks: []},
  {title: "Asansör bakım faturasını yatır", date: <${today} + 1 gün>, subtasks: []}
], ignored = []

ÖRNEK 2 (geriye dönük gruplama + edilgen kalıplar)
Metin: "Balkonlar yıkanacak. Kendi odamı toplayacağım. Ama bunu Neslihan'ın işi olarak bir üst başlık üzerinde alt başlık olarak ekleyebilirsin. Çamaşırlar dürülecek, ütü yapılacak. Bir de bir saat uyulacak."
Çıktı: tasks = [
  {title: "Neslihan'ın işleri", date: ${viewDate}, subtasks: ["Balkonları yıka", "Odamı topla", "Çamaşırları dür", "Ütü yap", "Bir saat uyu"]}
], ignored = []

DİĞER KURALLAR:
- Yapı işareti yoksa: birbirinden bağımsız işler (çamaşır at, bulaşık makinesini boşalt) AYRI görevlerdir; bir işin doğal adımları (market → süt, ekmek) alt görevlerdir.
- ignored SADECE şunlar için: sohbet, düşünce, arka plandaki kişilere/hayvanlara söylenen sözler ("dur", "köpek yapma"), hiç anlam verilemeyen parçalar. Bir eylem anlatan hiçbir cümle ignored'a gitmez; yanlış duyulmuş olsa bile en makul düzeltmeyle görev yap ("tüm makinesini yerleştir" → "Ütü makinesini yerleştir"). Kendine sor: "Bu cümle yapılacak bir iş mi?" Evetse görevdir.
- Başlıklar Türkçe dil bilgisine uygun, kısa, emir kipinde; "-nın yapılması" gibi ad tamlamalarını emir kipine çevir ("faturanın yatırılması" → "Faturayı yatır"). Nesne ekleri doğru ("Mutfağı topla"). İlk harf büyük, sonda nokta yok.
- description: başlığın tekrarı ya da farklı çekimi ASLA yazılmaz. Sadece başlığa sığmayan gerçek ek bilgi (kim, nerede, hangi şart) varsa yaz; yoksa boş string. Görevin hemen ardından gelen açıklayıcı cümle description'a gider, ignored'a değil.
- Aynı işi anlatan ARDIŞIK cümleler tek görevdir: "Robot süpürgeye bakacağız. Tamirat, bakım yapacağız." → tek görev "Robot süpürgeyi incele ve onar" (ikinci cümle description'a gidebilir). Yeni görev ancak yeni bir iş/nesne ya da yapı işaretiyle başlar.
- Aynı görevi iki kez yazma; kullanıcı kendini düzeltirse ("yok onu iptal et") son halini al.
- Konuşmada hiç görev yoksa tasks boş dizi olsun; hiç değişiklik yoksa actions boş dizi olsun.
- Sadece şemaya uygun JSON döndür.`;
}

interface ProposalAction {
  type: "complete" | "uncomplete" | "postpone" | "delete" | "complete_subtask";
  task_id: string;
  subtask_id: string;
  target_date: string;
  title?: string;
  subtask_title?: string;
}
interface Proposal {
  tasks: { title: string; description: string; date: string; subtasks: string[] }[];
  actions: ProposalAction[];
  ignored: string[];
}

async function extractTasks(transcript: string, viewDate: string, groupName: string, context: ContextTask[]): Promise<Proposal> {
  const res = await fetchWithRetry("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${GROQ_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: LLM_MODEL,
      temperature: 0.1,
      messages: [
        { role: "system", content: buildSystemPrompt(viewDate, groupName, context) },
        { role: "user", content: transcript },
      ],
      response_format: {
        type: "json_schema",
        json_schema: { name: "task_proposal", strict: true, schema: taskSchema },
      },
    }),
  }, "LLM");

  if (res.status === 429) throw new Error("Yapay zeka şu an yoğun, birkaç saniye sonra tekrar dene");
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

  // Validate actions against the provided context — never trust invented ids
  const byId = new Map(context.map((t) => [t.id, t]));
  const seen = new Set<string>();
  parsed.actions = (parsed.actions ?? [])
    .map((a) => {
      const task = byId.get(a.task_id);
      if (!task) return null;
      const sub = a.type === "complete_subtask"
        ? (task.subtasks ?? []).find((x) => x.id === a.subtask_id)
        : undefined;
      if (a.type === "complete_subtask" && !sub) return null;
      const targetDate = a.type === "postpone" && /^\d{4}-\d{2}-\d{2}$/.test(a.target_date ?? "")
        ? a.target_date
        : "";
      if (a.type === "postpone" && !targetDate) return null;
      const key = `${a.type}:${a.task_id}:${a.subtask_id ?? ""}`;
      if (seen.has(key)) return null;
      seen.add(key);
      return {
        type: a.type,
        task_id: task.id,
        subtask_id: sub?.id ?? "",
        target_date: targetDate,
        title: task.title,
        subtask_title: sub?.title,
      } as ProposalAction;
    })
    .filter((a): a is ProposalAction => a !== null);
  return parsed;
}

// ---------- Quota ----------
// Per-user override (profiles.voice_limit_sec), falls back to env default
async function getLimit(userId: string): Promise<number> {
  const { data } = await supabase
    .from("profiles")
    .select("voice_limit_sec")
    .eq("id", userId)
    .maybeSingle();
  const v = Number(data?.voice_limit_sec);
  return v > 0 ? v : DAILY_LIMIT;
}

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

// ---------- Vocabulary for STT ----------
// Names the user is likely to say: members of the target group (or all their groups).
async function vocabularyFor(userId: string, groupId: string | null): Promise<string[]> {
  const names = new Set<string>();
  const me = await supabase.from("profiles").select("display_name").eq("id", userId).maybeSingle();
  if (me.data?.display_name) names.add(me.data.display_name);

  let groupIds: string[] = [];
  if (groupId) {
    groupIds = [groupId];
  } else {
    const mine = await supabase.from("group_members").select("group_id").eq("user_id", userId);
    groupIds = (mine.data ?? []).map((m: { group_id: string }) => m.group_id);
  }
  if (groupIds.length) {
    const members = await supabase
      .from("group_members")
      .select("profiles(display_name)")
      .in("group_id", groupIds);
    for (const m of members.data ?? []) {
      const n = (m as { profiles?: { display_name?: string } }).profiles?.display_name;
      if (n) names.add(n);
    }
  }
  const people = [...names]
    .map((n) => n.trim().split(/\s+/)[0])
    .filter((n) => n.length > 1)
    .slice(0, 12);

  // Personal vocabulary: distinctive words from the user's recent task titles
  // (brands, places, proper nouns) — helps Whisper with "Suzuki", "muayenehane".
  const terms = new Set<string>();
  if (groupIds.length) {
    const recent = await supabase
      .from("tasks")
      .select("title")
      .in("owner_id", groupIds)
      .order("created_at", { ascending: false })
      .limit(150);
    const stop = new Set(["için", "veya", "daha", "bir", "ile", "olan", "gibi", "sonra", "önce", "yeni", "yap", "et", "al"]);
    for (const row of recent.data ?? []) {
      for (const raw of String(row.title ?? "").split(/[\s,.;:!?()"]+/)) {
        const w = raw.replace(/['’].*$/, "").trim();
        if (w.length < 4 || stop.has(w.toLowerCase())) continue;
        // keep capitalised words (names/brands) and long rare-looking words
        if (/^[A-ZÇĞİÖŞÜ]/.test(w) || w.length >= 9) terms.add(w);
      }
      if (terms.size >= 25) break;
    }
  }
  const termList = [...terms].filter((t) => !people.includes(t)).slice(0, 25);
  return [...people, ...termList];
}

// ---------- Audio archive (temporary, for prompt tuning) ----------
async function storeAudio(userId: string, transcriptId: string, file: File): Promise<string | null> {
  if (!KEEP_AUDIO) return null;
  const ext = (file.name.split(".").pop() || "webm").toLowerCase();
  const path = `${userId}/${transcriptId}.${ext}`;
  const { error } = await supabase.storage
    .from(AUDIO_BUCKET)
    .upload(path, file, { contentType: file.type || "application/octet-stream", upsert: true });
  if (error) {
    console.error("audio upload:", error.message);
    return null;
  }
  return path;
}

// ---------- Handler ----------
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  if (!GROQ_API_KEY) return reply({ error: "GROQ_API_KEY tanımlı değil" }, 500);

  const userId = await authenticate(req);
  if (!userId) return reply({ error: "Unauthorized" }, 401);

  // POST ?status=1 → quota only; POST ?history=1 → last recordings
  const url = new URL(req.url);
  const limit = await getLimit(userId);
  if (url.searchParams.get("status") === "1") {
    const used = await getUsedToday(userId);
    return reply({ used_seconds: used, limit_seconds: limit });
  }
  if (url.searchParams.get("history") === "1") {
    const { data, error } = await supabase
      .from("voice_transcripts")
      .select("id, created_at, duration_seconds, transcript, proposal, group_id")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(30);
    if (error) return reply({ error: error.message }, 500);
    return reply({ items: data ?? [] });
  }

  try {
    const form = await req.formData();
    const file = form.get("file");

    // Streaming mode: transcribe one ~30 s segment, count quota, return text only.
    if (url.searchParams.get("partial") === "1") {
      if (!(file instanceof File)) return reply({ error: "file alanı gerekli" }, 400);
      if (file.size > MAX_BYTES) return reply({ error: "Parça 25 MB'den büyük" }, 413);
      const segDuration = Math.ceil(Number(form.get("duration_seconds") ?? 0)) || 0;
      const prevText = String(form.get("prev_text") ?? "").slice(0, 400);
      const gidRaw = String(form.get("group_id") ?? "");
      const gid = /^[0-9a-f-]{36}$/i.test(gidRaw) ? gidRaw : null;
      const usedNow = await getUsedToday(userId);
      if (usedNow >= limit) {
        return reply({ error: "quota_exceeded", message: "Bugünkü ses kaydı limitin doldu.", used_seconds: usedNow, limit_seconds: limit }, 429);
      }
      const vocabulary = await vocabularyFor(userId, gid);
      const seg = await transcribe(file, segDuration, vocabulary, prevText);
      const usedAfterSeg = await recordUsage(userId, Math.max(seg.durationSec, 1));
      return reply({ transcript: seg.text, duration_seconds: seg.durationSec, used_seconds: usedAfterSeg, limit_seconds: limit });
    }

    // Testing/tuning path (and streaming finalisation): a ready transcript skips STT.
    // If a file is still attached (streaming), it is archived but not transcribed.
    const transcriptOverride = String(form.get("transcript") ?? "").trim();
    const sttMode = String(form.get("stt_mode") ?? "");
    if (!transcriptOverride) {
      if (!(file instanceof File)) return reply({ error: "file alanı gerekli" }, 400);
      if (file.size > MAX_BYTES) return reply({ error: "Ses dosyası 25 MB'den büyük" }, 413);
    }

    const clientDuration = Math.ceil(Number(form.get("duration_seconds") ?? 0)) || 0;
    const viewDateRaw = String(form.get("date") ?? "");
    const viewDate = /^\d{4}-\d{2}-\d{2}$/.test(viewDateRaw) ? viewDateRaw : todayISO();
    const groupName = String(form.get("group_name") ?? "").trim().slice(0, 80);
    let context: ContextTask[] = [];
    try {
      const raw = String(form.get("context_tasks") ?? "");
      if (raw) {
        const parsedCtx = JSON.parse(raw);
        if (Array.isArray(parsedCtx)) {
          context = parsedCtx
            .filter((t) => t && typeof t.id === "string" && typeof t.title === "string")
            .slice(0, 60)
            .map((t) => ({
              id: t.id,
              title: String(t.title).slice(0, 200),
              status: String(t.status ?? "pending"),
              date: typeof t.date === "string" ? t.date : undefined,
              subtasks: Array.isArray(t.subtasks)
                ? t.subtasks
                    .filter((x: { id?: unknown; title?: unknown }) => typeof x?.id === "string" && typeof x?.title === "string")
                    .slice(0, 20)
                    .map((x: { id: string; title: string; status?: string }) => ({ id: x.id, title: String(x.title).slice(0, 200), status: String(x.status ?? "pending") }))
                : [],
            }));
        }
      }
    } catch (_) { /* ignore malformed context */ }
    const groupIdRaw = String(form.get("group_id") ?? "");
    const groupId = /^[0-9a-f-]{36}$/i.test(groupIdRaw) ? groupIdRaw : null;

    if (clientDuration > MAX_CLIP) {
      return reply({ error: `Tek kayıt en fazla ${Math.floor(MAX_CLIP / 60)} dakika olabilir` }, 400);
    }

    // Pre-check quota with the client-reported duration (cheap, avoids a wasted STT call)
    const usedBefore = await getUsedToday(userId);
    if (!transcriptOverride && (usedBefore >= limit || usedBefore + clientDuration > limit)) {
      return reply({
        error: "quota_exceeded",
        message: "Bugünkü ses kaydı limitin doldu. Yarın tekrar deneyebilirsin.",
        used_seconds: usedBefore,
        limit_seconds: limit,
      }, 429);
    }

    let transcript: Transcript;
    let usedAfter = usedBefore;
    if (transcriptOverride) {
      transcript = { text: cleanTranscript(transcriptOverride), durationSec: sttMode === "stream" ? clientDuration : 0 };
    } else {
      const vocabulary = await vocabularyFor(userId, groupId);
      transcript = await transcribe(file as File, clientDuration, vocabulary);
      // Record actual duration (server-measured), even if transcript is empty
      usedAfter = await recordUsage(userId, Math.max(transcript.durationSec, 1));
    }

    if (!transcript.text) {
      return reply({
        transcript: "",
        tasks: [],
        ignored: [],
        used_seconds: usedAfter,
        limit_seconds: limit,
        message: "Kayıtta konuşma algılanamadı.",
      });
    }

    const proposal = await extractTasks(transcript.text, viewDate, groupName, context);

    // Keep history for review/debugging (+ the audio clip while we tune prompts)
    const { data: hist, error: histErr } = await supabase.from("voice_transcripts").insert({
      user_id: userId,
      group_id: groupId,
      duration_seconds: transcript.durationSec,
      transcript: transcript.text,
      proposal,
      stt_model: transcriptOverride ? (sttMode === "stream" ? `${STT_MODEL} (stream)` : "override") : STT_MODEL,
      llm_model: LLM_MODEL,
    }).select("id").single();
    if (histErr) console.error("voice_transcripts insert:", histErr.message);
    if (hist && file instanceof File) {
      const audioPath = await storeAudio(userId, hist.id, file);
      if (audioPath) {
        await supabase.from("voice_transcripts").update({ audio_path: audioPath }).eq("id", hist.id);
      }
    }

    return reply({
      transcript: transcript.text,
      tasks: proposal.tasks,
      actions: proposal.actions,
      ignored: proposal.ignored,
      used_seconds: usedAfter,
      limit_seconds: limit,
      models: { stt: STT_MODEL, llm: LLM_MODEL },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("voice-to-tasks error:", message);
    return reply({ error: message }, 500);
  }
});
