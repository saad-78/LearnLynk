// =====================================================
// SUPABASE EDGE FUNCTION: create-task
// Task 3: Validates input and creates a task record
// =====================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

// =====================================================
// CORS HEADERS
// Required for browser requests
// =====================================================
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// =====================================================
// TYPES
// =====================================================
interface CreateTaskRequest {
  application_id: string;
  task_type: "call" | "email" | "review";
  due_at: string;
  title?: string;
  description?: string;
  assigned_to?: string;
}

interface CreateTaskResponse {
  success: boolean;
  task_id?: string;
  error?: string;
}

// =====================================================
// VALIDATION CONSTANTS
// =====================================================
const VALID_TASK_TYPES = ["call", "email", "review"] as const;

// =====================================================
// MAIN HANDLER
// =====================================================
serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Only allow POST requests
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({
        success: false,
        error: "Method not allowed. Use POST.",
      }),
      {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  try {
    // =====================================================
    // 1. PARSE REQUEST BODY
    // =====================================================
    let body: CreateTaskRequest;
    
    try {
      body = await req.json();
    } catch (parseError) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Invalid JSON in request body",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const { application_id, task_type, due_at, title, description, assigned_to } = body;

    // =====================================================
    // 2. VALIDATE REQUIRED FIELDS
    // =====================================================
    if (!application_id || typeof application_id !== "string") {
      return new Response(
        JSON.stringify({
          success: false,
          error: "application_id is required and must be a valid UUID string",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (!task_type) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "task_type is required",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (!due_at) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "due_at is required",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // =====================================================
    // 3. VALIDATE task_type
    // Must be one of: call, email, review
    // =====================================================
    if (!VALID_TASK_TYPES.includes(task_type)) {
      return new Response(
        JSON.stringify({
          success: false,
          error: `task_type must be one of: ${VALID_TASK_TYPES.join(", ")}`,
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // =====================================================
    // 4. VALIDATE due_at
    // Must be a valid ISO 8601 timestamp in the future
    // =====================================================
    let dueDate: Date;
    
    try {
      dueDate = new Date(due_at);
      
      // Check if valid date
      if (isNaN(dueDate.getTime())) {
        throw new Error("Invalid date format");
      }
      
      // Check if in the future
      const now = new Date();
      if (dueDate <= now) {
        return new Response(
          JSON.stringify({
            success: false,
            error: "due_at must be a future timestamp",
          }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }
    } catch (dateError) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "due_at must be a valid ISO 8601 timestamp (e.g., 2025-01-01T12:00:00Z)",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // =====================================================
    // 5. INITIALIZE SUPABASE CLIENT (Service Role)
    // Uses service role key to bypass RLS
    // =====================================================
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
      return new Response(
        JSON.stringify({
          success: false,
          error: "Internal server configuration error",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // =====================================================
    // 6. VERIFY APPLICATION EXISTS
    // Optional but shows best practices
    // =====================================================
    const { data: applicationExists, error: checkError } = await supabase
      .from("applications")
      .select("id, tenant_id")
      .eq("id", application_id)
      .single();

    if (checkError || !applicationExists) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Application not found",
        }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // =====================================================
    // 7. INSERT TASK INTO DATABASE
    // =====================================================
    const { data: newTask, error: insertError } = await supabase
      .from("tasks")
      .insert({
        application_id,
        type: task_type,
        title: title || `${task_type.charAt(0).toUpperCase() + task_type.slice(1)} task`,
        description: description || null,
        due_at: dueDate.toISOString(),
        status: "pending",
        tenant_id: applicationExists.tenant_id, // Inherit from application
        assigned_to: assigned_to || null,
      })
      .select("id")
      .single();

    if (insertError) {
      console.error("Database insert error:", insertError);
      return new Response(
        JSON.stringify({
          success: false,
          error: "Failed to create task",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // =====================================================
    // 8. EMIT REALTIME BROADCAST EVENT
    // Notify clients that a new task was created
    // =====================================================
    try {
      const channel = supabase.channel("tasks");
      
      await channel.send({
        type: "broadcast",
        event: "task.created",
        payload: {
          task_id: newTask.id,
          application_id,
          type: task_type,
          due_at: dueDate.toISOString(),
        },
      });
      
      // Clean up channel
      await supabase.removeChannel(channel);
    } catch (realtimeError) {
      // Log but don't fail the request
      console.warn("Failed to emit realtime event:", realtimeError);
    }

    // =====================================================
    // 9. RETURN SUCCESS RESPONSE
    // =====================================================
    return new Response(
      JSON.stringify({
        success: true,
        task_id: newTask.id,
      } as CreateTaskResponse),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );

  } catch (error) {
    // =====================================================
    // GLOBAL ERROR HANDLER
    // Catch any unexpected errors
    // =====================================================
    console.error("Unexpected error in create-task function:", error);
    
    return new Response(
      JSON.stringify({
        success: false,
        error: "Internal server error",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

