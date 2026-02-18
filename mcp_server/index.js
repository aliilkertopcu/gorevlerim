import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { createClient } from "@supabase/supabase-js";
import { z } from "zod";

// Environment variables
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const TODO_USER_ID = process.env.TODO_USER_ID; // Default user ID for personal tasks

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error("SUPABASE_URL and SUPABASE_SERVICE_KEY environment variables are required");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Resolve user's personal group (all tasks are group-owned since migration 006)
async function resolveOwner(groupId) {
  if (groupId) return { ownerId: groupId, ownerType: "group" };

  const { data } = await supabase
    .from("groups")
    .select("id")
    .eq("created_by", TODO_USER_ID)
    .eq("is_personal", true)
    .maybeSingle();

  if (!data) throw new Error("Kişisel grup bulunamadı. TODO_USER_ID doğru mu?");
  return { ownerId: data.id, ownerType: "group" };
}

// Helper: format date as YYYY-MM-DD
function formatDate(dateStr) {
  if (!dateStr || dateStr === "today") {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  }
  if (dateStr === "tomorrow") {
    const d = new Date();
    d.setDate(d.getDate() + 1);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  }
  return dateStr; // Assume already YYYY-MM-DD
}

// Create MCP Server
const server = new McpServer({
  name: "todo-app",
  version: "1.0.0",
});

// Tool: List tasks for a date
server.tool(
  "list_tasks",
  "Belirli bir tarihteki görevleri listele",
  {
    date: z.string().optional().describe("Tarih (YYYY-MM-DD, 'today', veya 'tomorrow'). Varsayılan: today"),
    group_id: z.string().optional().describe("Grup ID'si. Belirtilmezse kişisel grup kullanılır."),
  },
  async ({ date, group_id }) => {
    const dateStr = formatDate(date);
    const { ownerId, ownerType } = await resolveOwner(group_id);

    const { data: tasks, error } = await supabase
      .from("tasks")
      .select("*, subtasks(*)")
      .eq("owner_id", ownerId)
      .eq("owner_type", ownerType)
      .eq("date", dateStr)
      .order("sort_order", { ascending: true });

    if (error) {
      return { content: [{ type: "text", text: `Hata: ${error.message}` }] };
    }

    if (!tasks || tasks.length === 0) {
      return { content: [{ type: "text", text: `${dateStr} tarihinde görev yok.` }] };
    }

    const summary = tasks.map((t, i) => {
      const status = { pending: "⏳", completed: "✅", blocked: "🚫", postponed: "📅" }[t.status] || "❓";
      const subtaskInfo = t.subtasks?.length
        ? ` [${t.subtasks.filter((s) => s.status === "completed").length}/${t.subtasks.length} alt görev]`
        : "";
      const blockInfo = t.status === "blocked" && t.block_reason ? ` (Sebep: ${t.block_reason})` : "";
      return `${i + 1}. ${status} ${t.title}${subtaskInfo}${blockInfo}`;
    }).join("\n");

    return {
      content: [{ type: "text", text: `📋 ${dateStr} Görevleri:\n\n${summary}` }],
    };
  }
);

// Tool: Add a task
server.tool(
  "add_task",
  "Yeni görev ekle. Birden fazla görev eklemek için virgülle ayır.",
  {
    title: z.string().describe("Görev başlığı. Birden fazla görev için virgülle ayır: 'Market, Çamaşır, Fatura öde'"),
    date: z.string().optional().describe("Tarih (YYYY-MM-DD, 'today', 'tomorrow'). Varsayılan: today"),
    description: z.string().optional().describe("Açıklama. Alt görevler için her satırı '* ' ile başlat"),
    group_id: z.string().optional().describe("Grup ID'si. Belirtilmezse kişisel grup kullanılır."),
  },
  async ({ title, date, description, group_id }) => {
    const dateStr = formatDate(date);
    const { ownerId, ownerType } = await resolveOwner(group_id);

    // Support multiple tasks separated by comma
    const titles = title.split(",").map((t) => t.trim()).filter(Boolean);
    const createdTasks = [];

    // Get current max sort_order
    const { data: existing } = await supabase
      .from("tasks")
      .select("sort_order")
      .eq("owner_id", ownerId)
      .eq("owner_type", ownerType)
      .eq("date", dateStr)
      .order("sort_order", { ascending: false })
      .limit(1);

    let nextOrder = existing?.length ? existing[0].sort_order + 1 : 0;

    for (const t of titles) {
      // Parse subtasks from description
      let cleanDesc = description || null;
      const subtaskTitles = [];

      if (description) {
        const lines = description.split("\n");
        const descLines = [];
        for (const line of lines) {
          if (line.trimStart().startsWith("* ")) {
            subtaskTitles.push(line.trimStart().substring(2).trim());
          } else {
            descLines.push(line);
          }
        }
        cleanDesc = descLines.join("\n").trim() || null;
      }

      const { data: task, error } = await supabase
        .from("tasks")
        .insert({
          owner_id: ownerId,
          owner_type: ownerType,
          date: dateStr,
          title: t,
          description: titles.length === 1 ? cleanDesc : null,
          status: "pending",
          sort_order: nextOrder++,
          created_by: TODO_USER_ID,
        })
        .select()
        .single();

      if (error) {
        return { content: [{ type: "text", text: `Hata: ${error.message}` }] };
      }

      // Create subtasks (only for single task with description)
      if (titles.length === 1 && subtaskTitles.length > 0) {
        const subtaskInserts = subtaskTitles.map((st, idx) => ({
          task_id: task.id,
          title: st,
          status: "pending",
          sort_order: idx,
        }));
        await supabase.from("subtasks").insert(subtaskInserts);
      }

      createdTasks.push(task);
    }

    const result = createdTasks.map((t) => `✅ "${t.title}" eklendi`).join("\n");
    return {
      content: [{ type: "text", text: `${dateStr} tarihine görev(ler) eklendi:\n\n${result}` }],
    };
  }
);

// Tool: Update a task
server.tool(
  "update_task",
  "Görev güncelle (başlık, açıklama, durum değiştir)",
  {
    task_id: z.string().describe("Görev ID'si"),
    title: z.string().optional().describe("Yeni başlık"),
    description: z.string().optional().describe("Yeni açıklama"),
    status: z.enum(["pending", "completed", "blocked", "postponed"]).optional().describe("Yeni durum"),
    block_reason: z.string().optional().describe("Bloke sebebi (status=blocked ise)"),
    postpone_to: z.string().optional().describe("Erteleme tarihi (YYYY-MM-DD veya 'tomorrow')"),
  },
  async ({ task_id, title, description, status, block_reason, postpone_to }) => {
    const updates = {};
    if (title) updates.title = title;
    if (description !== undefined) updates.description = description;
    if (status) updates.status = status;
    if (block_reason) updates.block_reason = block_reason;
    if (postpone_to) {
      updates.date = formatDate(postpone_to);
      updates.status = "pending";
    }
    updates.updated_at = new Date().toISOString();

    const { data, error } = await supabase
      .from("tasks")
      .update(updates)
      .eq("id", task_id)
      .select()
      .single();

    if (error) {
      return { content: [{ type: "text", text: `Hata: ${error.message}` }] };
    }

    return {
      content: [{ type: "text", text: `✅ "${data.title}" güncellendi. Durum: ${data.status}` }],
    };
  }
);

// Tool: Complete a task
server.tool(
  "complete_task",
  "Görevi tamamlandı olarak işaretle (sıra numarasıyla veya ID ile)",
  {
    task_number: z.number().optional().describe("Görev sıra numarası (1'den başlar)"),
    task_id: z.string().optional().describe("Görev ID'si"),
    date: z.string().optional().describe("Tarih. Varsayılan: today"),
    group_id: z.string().optional().describe("Grup ID'si. Belirtilmezse kişisel grup kullanılır."),
  },
  async ({ task_number, task_id, date, group_id }) => {
    let targetId = task_id;

    if (!targetId && task_number) {
      const dateStr = formatDate(date);
      const { ownerId, ownerType } = await resolveOwner(group_id);

      const { data: tasks } = await supabase
        .from("tasks")
        .select("id, title")
        .eq("owner_id", ownerId)
        .eq("owner_type", ownerType)
        .eq("date", dateStr)
        .order("sort_order", { ascending: true });

      if (!tasks || task_number > tasks.length) {
        return { content: [{ type: "text", text: `${task_number}. görev bulunamadı.` }] };
      }

      targetId = tasks[task_number - 1].id;
    }

    if (!targetId) {
      return { content: [{ type: "text", text: "task_number veya task_id gerekli." }] };
    }

    const { data, error } = await supabase
      .from("tasks")
      .update({ status: "completed", updated_at: new Date().toISOString() })
      .eq("id", targetId)
      .select()
      .single();

    if (error) {
      return { content: [{ type: "text", text: `Hata: ${error.message}` }] };
    }

    return {
      content: [{ type: "text", text: `✅ "${data.title}" tamamlandı!` }],
    };
  }
);

// Tool: Delete a task
server.tool(
  "delete_task",
  "Görevi sil",
  {
    task_id: z.string().describe("Silinecek görev ID'si"),
  },
  async ({ task_id }) => {
    const { data, error } = await supabase
      .from("tasks")
      .delete()
      .eq("id", task_id)
      .select()
      .single();

    if (error) {
      return { content: [{ type: "text", text: `Hata: ${error.message}` }] };
    }

    return {
      content: [{ type: "text", text: `🗑️ "${data.title}" silindi.` }],
    };
  }
);

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Todo MCP Server running on stdio");
}

main().catch(console.error);
