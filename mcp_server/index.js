#!/usr/bin/env node
// Görevlerim MCP server — thin client over the todo-api edge function.
//
// Each user runs this with their OWN API key (from the app: menu → AI entegrasyonu),
// so no Supabase service key is needed on the machine.
//
// Env:
//   TODO_API_KEY   required — gorevlerim_xxx key
//   TODO_API_URL   optional — default https://api.aitopcu.com/functions/v1/todo-api

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const API_KEY = process.env.TODO_API_KEY;
const API_URL = (process.env.TODO_API_URL || "https://api.aitopcu.com/functions/v1/todo-api").replace(/\/$/, "");

if (!API_KEY) {
  console.error("TODO_API_KEY environment variable is required");
  process.exit(1);
}

async function api(method, path, body) {
  const res = await fetch(`${API_URL}${path}`, {
    method,
    headers: {
      "x-api-key": API_KEY,
      "Content-Type": "application/json; charset=utf-8",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let data;
  try { data = JSON.parse(text); } catch { data = { error: text }; }
  if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
  return data;
}

const text = (s) => ({ content: [{ type: "text", text: s }] });
const fail = (e) => text(`Hata: ${e.message || e}`);

const STATUS_ICON = { pending: "⏳", completed: "✅", blocked: "🚫", postponed: "📅" };

function renderTasks(data) {
  if (!data.tasks?.length) return `${data.date} tarihinde görev yok.`;
  const lines = data.tasks.map((t) => {
    const icon = STATUS_ICON[t.status] || "❓";
    const head = `${t.number}. ${icon} ${t.title}${t.block_reason ? ` (bloke: ${t.block_reason})` : ""}  [id:${t.id}]`;
    const desc = t.description ? `\n     ${t.description.replace(/\n/g, "\n     ")}` : "";
    const subs = (t.subtasks || [])
      .map((s) => `     ${STATUS_ICON[s.status] || "❓"} ${s.title}  [subtask_id:${s.id}]`)
      .join("\n");
    return head + desc + (subs ? "\n" + subs : "");
  });
  return `📋 ${data.date} — ${data.completed}/${data.total} tamamlandı\n\n${lines.join("\n")}`;
}

const server = new McpServer({ name: "gorevlerim", version: "2.0.0" });

const dateArg = z.string().optional().describe("Tarih: YYYY-MM-DD, 'today'/'bugün', 'tomorrow'/'yarın', 'yesterday'/'dün'. Varsayılan: bugün");
const groupArg = z.string().optional().describe("Liste (grup) ID'si. Boşsa kişisel liste. list_groups ile öğren.");

server.tool(
  "list_groups",
  "Kullanıcının listelerini (gruplarını) göster",
  {},
  async () => {
    try {
      const data = await api("GET", "/groups");
      if (!data.groups?.length) return text("Liste yok.");
      return text(data.groups.map((g) => `• ${g.name}${g.is_personal ? " (kişisel)" : ""}  [id:${g.id}]`).join("\n"));
    } catch (e) { return fail(e); }
  },
);

server.tool(
  "list_tasks",
  "Bir günün görevlerini alt görevleriyle listele",
  { date: dateArg, group_id: groupArg },
  async ({ date, group_id }) => {
    try {
      const q = new URLSearchParams();
      if (date) q.set("date", date);
      if (group_id) q.set("group_id", group_id);
      const data = await api("GET", `/tasks?${q}`);
      return text(renderTasks(data));
    } catch (e) { return fail(e); }
  },
);

server.tool(
  "add_task",
  "Yeni görev ekle. Alt görevler için subtasks dizisini kullan. Birden fazla bağımsız görev için titles dizisi.",
  {
    title: z.string().optional().describe("Görev başlığı (tek görev)"),
    titles: z.array(z.string()).optional().describe("Birden fazla bağımsız görev başlığı"),
    description: z.string().optional().describe("Açıklama (opsiyonel)"),
    subtasks: z.array(z.string()).optional().describe("Alt görev başlıkları (sadece tek görev için)"),
    date: dateArg,
    group_id: groupArg,
  },
  async ({ title, titles, description, subtasks, date, group_id }) => {
    try {
      if (!title && !titles?.length) return text("title veya titles gerekli.");
      const data = await api("POST", "/tasks", { title, titles, description, subtasks, date, group_id });
      return text(`${data.message} (${data.date}):\n` + data.created.map((c) => `• ${c.title}  [id:${c.id}]`).join("\n"));
    } catch (e) { return fail(e); }
  },
);

server.tool(
  "update_task",
  "Görevi güncelle: başlık, açıklama, durum, bloke sebebi, tarih",
  {
    task_id: z.string().describe("Görev ID'si (list_tasks çıktısındaki id)"),
    title: z.string().optional(),
    description: z.string().optional(),
    status: z.enum(["pending", "completed", "blocked", "postponed"]).optional(),
    block_reason: z.string().optional(),
    date: z.string().optional().describe("Yeni tarih (YYYY-MM-DD / tomorrow)"),
  },
  async ({ task_id, ...rest }) => {
    try {
      const body = Object.fromEntries(Object.entries(rest).filter(([, v]) => v !== undefined));
      const data = await api("PATCH", `/tasks/${task_id}`, body);
      return text(`✅ ${data.message} — durum: ${data.task.status}`);
    } catch (e) { return fail(e); }
  },
);

server.tool(
  "complete_task",
  "Görevi tamamla (sıra numarası veya ID ile). Alt görevler de tamamlanır.",
  {
    task_number: z.number().optional().describe("list_tasks'taki sıra numarası"),
    task_id: z.string().optional(),
    date: dateArg,
    group_id: groupArg,
  },
  async ({ task_number, task_id, date, group_id }) => {
    try {
      if (task_id) {
        const data = await api("PATCH", `/tasks/${task_id}`, { status: "completed" });
        return text(`✅ ${data.message}`);
      }
      if (!task_number) return text("task_number veya task_id gerekli.");
      const data = await api("POST", "/tasks/complete", { task_number, date, group_id });
      return text(`✅ ${data.message}`);
    } catch (e) { return fail(e); }
  },
);

server.tool(
  "complete_subtask",
  "Bir alt görevi tamamla (veya geri al)",
  {
    subtask_id: z.string().describe("list_tasks çıktısındaki subtask_id"),
    done: z.boolean().optional().describe("false verilirse 'bekliyor'a geri alınır. Varsayılan: true"),
  },
  async ({ subtask_id, done }) => {
    try {
      const data = await api("PATCH", `/subtasks/${subtask_id}`, { status: done === false ? "pending" : "completed" });
      return text(`${done === false ? "↩️" : "✅"} ${data.message}`);
    } catch (e) { return fail(e); }
  },
);

server.tool(
  "postpone_task",
  "Görevi başka güne ertele (sıra numarasıyla)",
  {
    task_number: z.number().describe("list_tasks'taki sıra numarası"),
    target_date: z.string().optional().describe("Hedef tarih. Varsayılan: yarın"),
    date: dateArg,
    group_id: groupArg,
  },
  async ({ task_number, target_date, date, group_id }) => {
    try {
      const data = await api("POST", "/tasks/postpone", { task_number, target_date, date, group_id });
      return text(`📅 ${data.message}`);
    } catch (e) { return fail(e); }
  },
);

server.tool(
  "delete_task",
  "Görevi kalıcı olarak sil",
  { task_id: z.string().describe("Görev ID'si") },
  async ({ task_id }) => {
    try {
      const data = await api("DELETE", `/tasks/${task_id}`);
      return text(`🗑️ ${data.message}`);
    } catch (e) { return fail(e); }
  },
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Görevlerim MCP server running (stdio)");
}

main().catch((e) => { console.error(e); process.exit(1); });
