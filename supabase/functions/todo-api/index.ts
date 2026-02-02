import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { corsHeaders } from "../_shared/cors.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

// Simple API key auth for ChatGPT
const API_KEY = Deno.env.get("TODO_API_KEY") || "changeme";
const DEFAULT_USER_ID = Deno.env.get("TODO_USER_ID")!;

function formatDate(dateStr?: string): string {
  if (!dateStr || dateStr === "today" || dateStr === "bugün") {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  }
  if (dateStr === "tomorrow" || dateStr === "yarın") {
    const d = new Date();
    d.setDate(d.getDate() + 1);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  }
  if (dateStr === "yesterday" || dateStr === "dün") {
    const d = new Date();
    d.setDate(d.getDate() - 1);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  }
  return dateStr;
}

function auth(req: Request): boolean {
  const key = req.headers.get("x-api-key") || new URL(req.url).searchParams.get("api_key");
  return key === API_KEY;
}

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  // Auth check
  if (!auth(req)) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const url = new URL(req.url);
  const path = url.pathname.replace(/^\/todo-api\/?/, "");
  const method = req.method;

  try {
    // GET /tasks — list tasks for a date
    if (method === "GET" && (path === "tasks" || path === "")) {
      const date = formatDate(url.searchParams.get("date") || "today");
      const ownerId = url.searchParams.get("owner_id") || DEFAULT_USER_ID;
      const ownerType = url.searchParams.get("owner_type") || "user";

      const { data: tasks, error } = await supabase
        .from("tasks")
        .select("*, subtasks(*)")
        .eq("owner_id", ownerId)
        .eq("owner_type", ownerType)
        .eq("date", date)
        .order("sort_order", { ascending: true });

      if (error) throw error;

      // Sort subtasks by sort_order
      for (const task of tasks || []) {
        if (task.subtasks) {
          task.subtasks.sort((a: any, b: any) => a.sort_order - b.sort_order);
        }
      }

      return new Response(JSON.stringify({
        date,
        total: tasks?.length || 0,
        completed: tasks?.filter((t: any) => t.status === "completed").length || 0,
        tasks: tasks?.map((t: any, i: number) => ({
          number: i + 1,
          id: t.id,
          title: t.title,
          description: t.description,
          status: t.status,
          block_reason: t.block_reason,
          subtasks: t.subtasks?.map((s: any) => ({
            id: s.id,
            title: s.title,
            status: s.status,
            block_reason: s.block_reason,
          })),
        })),
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // POST /tasks — create task(s)
    if (method === "POST" && (path === "tasks" || path === "")) {
      const body = await req.json();
      const date = formatDate(body.date || "today");
      const ownerId = body.owner_id || DEFAULT_USER_ID;
      const ownerType = body.owner_type || "user";
      const createdBy = body.created_by || DEFAULT_USER_ID;

      // Support comma-separated titles or array
      let titles: string[];
      if (Array.isArray(body.titles)) {
        titles = body.titles;
      } else if (body.title) {
        titles = body.title.split(",").map((t: string) => t.trim()).filter(Boolean);
      } else {
        throw new Error("title or titles required");
      }

      // Parse subtasks from description (lines starting with "* ")
      let description: string | null = body.description || null;
      const subtaskTitles: string[] = [];
      if (description) {
        const lines = description.split("\n");
        const descLines: string[] = [];
        for (const line of lines) {
          if (line.trimStart().startsWith("* ")) {
            subtaskTitles.push(line.trimStart().substring(2).trim());
          } else {
            descLines.push(line);
          }
        }
        description = descLines.join("\n").trim() || null;
      }

      // Also support subtasks array directly
      if (Array.isArray(body.subtasks)) {
        for (const st of body.subtasks) {
          subtaskTitles.push(typeof st === "string" ? st : st.title);
        }
      }

      // Get current max sort_order
      const { data: existing } = await supabase
        .from("tasks")
        .select("sort_order")
        .eq("owner_id", ownerId)
        .eq("owner_type", ownerType)
        .eq("date", date)
        .order("sort_order", { ascending: false })
        .limit(1);

      let nextOrder = existing?.length ? existing[0].sort_order + 1 : 0;
      const created = [];

      for (const title of titles) {
        const { data: task, error } = await supabase
          .from("tasks")
          .insert({
            owner_id: ownerId,
            owner_type: ownerType,
            date,
            title,
            description: titles.length === 1 ? description : null,
            status: "pending",
            sort_order: nextOrder++,
            created_by: createdBy,
          })
          .select()
          .single();

        if (error) throw error;

        // Create subtasks (only for single task)
        if (titles.length === 1 && subtaskTitles.length > 0) {
          const inserts = subtaskTitles.map((st, idx) => ({
            task_id: task.id,
            title: st,
            status: "pending",
            sort_order: idx,
          }));
          await supabase.from("subtasks").insert(inserts);
        }

        created.push({ id: task.id, title: task.title });
      }

      return new Response(JSON.stringify({
        message: `${created.length} görev eklendi`,
        date,
        created,
      }), {
        status: 201,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // PATCH /tasks/:id — update a task
    if (method === "PATCH" && path.startsWith("tasks/")) {
      const taskId = path.replace("tasks/", "");
      const body = await req.json();

      const updates: any = {};
      if (body.title !== undefined) updates.title = body.title;
      if (body.description !== undefined) updates.description = body.description;
      if (body.status !== undefined) updates.status = body.status;
      if (body.block_reason !== undefined) updates.block_reason = body.block_reason;
      if (body.date !== undefined) updates.date = formatDate(body.date);
      updates.updated_at = new Date().toISOString();

      const { data, error } = await supabase
        .from("tasks")
        .update(updates)
        .eq("id", taskId)
        .select()
        .single();

      if (error) throw error;

      // If completing, cascade to subtasks
      if (body.status === "completed") {
        const { data: subtasks } = await supabase
          .from("subtasks")
          .select("id")
          .eq("task_id", taskId);
        for (const s of subtasks || []) {
          await supabase.from("subtasks").update({ status: "completed" }).eq("id", s.id);
        }
      }

      return new Response(JSON.stringify({
        message: `"${data.title}" güncellendi`,
        task: { id: data.id, title: data.title, status: data.status },
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // POST /tasks/complete — complete by number
    if (method === "POST" && path === "tasks/complete") {
      const body = await req.json();
      const date = formatDate(body.date || "today");
      const ownerId = body.owner_id || DEFAULT_USER_ID;
      const ownerType = body.owner_type || "user";
      const taskNumber = body.task_number;

      if (!taskNumber) throw new Error("task_number required");

      const { data: tasks } = await supabase
        .from("tasks")
        .select("id, title")
        .eq("owner_id", ownerId)
        .eq("owner_type", ownerType)
        .eq("date", date)
        .order("sort_order", { ascending: true });

      if (!tasks || taskNumber > tasks.length) {
        throw new Error(`${taskNumber}. görev bulunamadı`);
      }

      const target = tasks[taskNumber - 1];
      await supabase
        .from("tasks")
        .update({ status: "completed", updated_at: new Date().toISOString() })
        .eq("id", target.id);

      // Cascade to subtasks
      const { data: subtasks } = await supabase
        .from("subtasks")
        .select("id")
        .eq("task_id", target.id);
      for (const s of subtasks || []) {
        await supabase.from("subtasks").update({ status: "completed" }).eq("id", s.id);
      }

      return new Response(JSON.stringify({
        message: `"${target.title}" tamamlandı!`,
        task: { id: target.id, title: target.title, status: "completed" },
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // DELETE /tasks/:id — delete a task
    if (method === "DELETE" && path.startsWith("tasks/")) {
      const taskId = path.replace("tasks/", "");

      const { data, error } = await supabase
        .from("tasks")
        .delete()
        .eq("id", taskId)
        .select()
        .single();

      if (error) throw error;

      return new Response(JSON.stringify({
        message: `"${data.title}" silindi`,
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // POST /tasks/postpone — postpone by number
    if (method === "POST" && path === "tasks/postpone") {
      const body = await req.json();
      const date = formatDate(body.date || "today");
      const targetDate = formatDate(body.target_date || "tomorrow");
      const ownerId = body.owner_id || DEFAULT_USER_ID;
      const ownerType = body.owner_type || "user";
      const taskNumber = body.task_number;

      if (!taskNumber) throw new Error("task_number required");

      const { data: tasks } = await supabase
        .from("tasks")
        .select("id, title, owner_id, owner_type")
        .eq("owner_id", ownerId)
        .eq("owner_type", ownerType)
        .eq("date", date)
        .order("sort_order", { ascending: true });

      if (!tasks || taskNumber > tasks.length) {
        throw new Error(`${taskNumber}. görev bulunamadı`);
      }

      const target = tasks[taskNumber - 1];

      // Get max sort_order on target date
      const { data: existingOnTarget } = await supabase
        .from("tasks")
        .select("sort_order")
        .eq("owner_id", target.owner_id)
        .eq("owner_type", target.owner_type)
        .eq("date", targetDate)
        .order("sort_order", { ascending: false })
        .limit(1);

      const nextOrder = existingOnTarget?.length ? existingOnTarget[0].sort_order + 1 : 0;

      await supabase
        .from("tasks")
        .update({
          date: targetDate,
          status: "pending",
          sort_order: nextOrder,
          updated_at: new Date().toISOString(),
        })
        .eq("id", target.id);

      return new Response(JSON.stringify({
        message: `"${target.title}" ${targetDate} tarihine ertelendi`,
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ error: "Not found" }), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
