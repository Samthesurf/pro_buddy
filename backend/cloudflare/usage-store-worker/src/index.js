function json(data, init = {}) {
  const headers = new Headers(init.headers || {});
  if (!headers.has("content-type")) {
    headers.set("content-type", "application/json; charset=utf-8");
  }
  return new Response(JSON.stringify(data), { ...init, headers });
}

function badRequest(message) {
  return json({ error: message }, { status: 400 });
}

function unauthorized() {
  return json({ error: "unauthorized" }, { status: 401 });
}

function notFound() {
  return json({ error: "not_found" }, { status: 404 });
}

function methodNotAllowed() {
  return json({ error: "method_not_allowed" }, { status: 405 });
}

function isNonEmptyString(v) {
  return typeof v === "string" && v.trim().length > 0;
}

function requireWorkerAuth(request, env) {
  const expected = env.WORKER_TOKEN;
  // Fail closed in production; in local dev, Wrangler will usually set this.
  if (!isNonEmptyString(expected)) return false;
  const got = request.headers.get("X-ProBuddy-Worker-Token") || "";
  return got === expected;
}

function parseMs(v) {
  if (v === null || v === undefined || v === "") return null;
  const n = Number(v);
  if (!Number.isFinite(n)) return null;
  return Math.trunc(n);
}

function clampInt(n, min, max) {
  if (!Number.isFinite(n)) return min;
  return Math.min(max, Math.max(min, Math.trunc(n)));
}

function isValidIsoDateDay(v) {
  // YYYY-MM-DD
  return typeof v === "string" && /^\d{4}-\d{2}-\d{2}$/.test(v);
}

function safeJsonParse(v, fallback) {
  if (v === null || v === undefined) return fallback;
  if (typeof v === "object") return v;
  if (typeof v !== "string") return fallback;
  const s = v.trim();
  if (!s) return fallback;
  try {
    return JSON.parse(s);
  } catch (e) {
    return fallback;
  }
}

function normalizeDateTimeText(v) {
  if (v === null || v === undefined) return null;
  if (typeof v !== "string") return null;
  const s = v.trim();
  if (!s) return null;

  // ISO-like strings.
  if (s.includes("T")) {
    const ms = Date.parse(s);
    if (Number.isFinite(ms)) return new Date(ms).toISOString();
    return s;
  }

  // SQLite default: YYYY-MM-DD HH:MM:SS (UTC)
  if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(s)) {
    const iso = s.replace(" ", "T") + "Z";
    const ms = Date.parse(iso);
    if (Number.isFinite(ms)) return new Date(ms).toISOString();
    return iso;
  }

  if (isValidIsoDateDay(s)) {
    return `${s}T00:00:00.000Z`;
  }

  const ms = Date.parse(s);
  if (Number.isFinite(ms)) return new Date(ms).toISOString();
  return s;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    const rowToGoalStep = (r) => {
      const prereq = safeJsonParse(r.prerequisites, []);
      const alts = safeJsonParse(r.alternatives, []);
      const notes = safeJsonParse(r.notes, []);
      const metadata = safeJsonParse(r.metadata, null);

      const prereqArr = Array.isArray(prereq) ? prereq.map((x) => String(x)) : [];
      const altArr = Array.isArray(alts) ? alts.map((x) => String(x)) : [];
      const notesArr = Array.isArray(notes) ? notes.map((x) => String(x)) : [];

      const posX = Number(r.position_x);
      const posY = Number(r.position_y);
      const posLayer = Number(r.position_layer);
      const orderIndex = Number(r.order_index);
      const estDays = Number(r.estimated_days);
      const actualDays =
        r.actual_days_spent === null || r.actual_days_spent === undefined
          ? null
          : Number(r.actual_days_spent);

      return {
        id: String(r.id),
        journey_id: String(r.journey_id),
        title: String(r.title || ""),
        custom_title: r.custom_title ? String(r.custom_title) : null,
        description: r.description ? String(r.description) : "",
        order_index: Number.isFinite(orderIndex) ? orderIndex : 0,
        status: String(r.status || "locked").toLowerCase(),
        prerequisites: prereqArr,
        alternatives: altArr,
        started_at: normalizeDateTimeText(r.started_at),
        completed_at: normalizeDateTimeText(r.completed_at),
        notes: notesArr,
        metadata: metadata && typeof metadata === "object" ? metadata : null,
        position: {
          x: Number.isFinite(posX) ? posX : 0.5,
          y: Number.isFinite(posY) ? posY : 0.0,
          layer: Number.isFinite(posLayer) ? posLayer : 0,
        },
        path_type: String(r.path_type || "main").toLowerCase(),
        estimated_days: Number.isFinite(estDays) ? estDays : 14,
        actual_days_spent: Number.isFinite(actualDays) ? actualDays : null,
        created_at: normalizeDateTimeText(r.created_at),
      };
    };

    const rowToGoalJourney = (r, steps) => {
      const progress = Number(r.overall_progress);
      const currentIdx = Number(r.current_step_index);
      const mapWidth = Number(r.map_width);
      const mapHeight = Number(r.map_height);

      const createdAt = normalizeDateTimeText(r.created_at) || new Date().toISOString();
      const startedAt = normalizeDateTimeText(r.journey_started_at) || createdAt;

      return {
        id: String(r.id),
        user_id: String(r.user_id),
        goal_id: r.goal_id ? String(r.goal_id) : null,
        goal_content: String(r.goal_content || ""),
        goal_reason: r.goal_reason ? String(r.goal_reason) : null,
        steps: Array.isArray(steps) ? steps : [],
        current_step_index: Number.isFinite(currentIdx) ? currentIdx : 0,
        overall_progress: Number.isFinite(progress) ? progress : 0.0,
        created_at: createdAt,
        updated_at: normalizeDateTimeText(r.updated_at),
        journey_started_at: startedAt,
        is_ai_generated: Boolean(r.is_ai_generated),
        ai_notes: r.ai_notes ? String(r.ai_notes) : null,
        map_width: Number.isFinite(mapWidth) ? mapWidth : 1000.0,
        map_height: Number.isFinite(mapHeight) ? mapHeight : 2000.0,
      };
    };

    const loadJourneyWithSteps = async (journeyRow) => {
      if (!journeyRow) return null;
      const stepsRes = await env.DB.prepare(
        "SELECT * FROM goal_steps WHERE journey_id = ? ORDER BY order_index ASC"
      )
        .bind(journeyRow.id)
        .all();
      const stepRows = (stepsRes && stepsRes.results) || [];
      const steps = stepRows.map(rowToGoalStep);
      return rowToGoalJourney(journeyRow, steps);
    };

    // Public health endpoint (no auth).
    if (request.method === "GET" && path === "/health") {
      return json({ ok: true });
    }

    // All v1 endpoints require shared-secret auth.
    if (path.startsWith("/v1/")) {
      if (!requireWorkerAuth(request, env)) return unauthorized();
    }

    if (path === "/v1/cooldowns/check-and-set") {
      if (request.method !== "POST") return methodNotAllowed();

      const body = await request.json().catch(() => null);
      if (!body || typeof body !== "object") return badRequest("invalid_json");

      const userId = String(body.user_id || "");
      const packageName = String(body.package_name || "");
      const alignment = String(body.alignment || "").toLowerCase();
      const cooldownSeconds = Number(body.cooldown_seconds);

      if (!isNonEmptyString(userId)) return badRequest("user_id_required");
      if (!isNonEmptyString(packageName)) return badRequest("package_name_required");
      if (!["aligned", "neutral", "misaligned"].includes(alignment)) {
        return badRequest("invalid_alignment");
      }
      if (!Number.isFinite(cooldownSeconds) || cooldownSeconds < 0) {
        return badRequest("invalid_cooldown_seconds");
      }

      const nowMs = Date.now();
      const thresholdMs = nowMs - Math.trunc(cooldownSeconds * 1000);

      // Atomic: insert if missing; update only if last_sent_at_ms <= threshold.
      const stmt = env.DB.prepare(`
        INSERT INTO notification_cooldowns (user_id, package_name, alignment, last_sent_at_ms)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(user_id, package_name, alignment) DO UPDATE SET
          last_sent_at_ms = excluded.last_sent_at_ms
        WHERE notification_cooldowns.last_sent_at_ms <= ?
      `);

      const result = await stmt.bind(userId, packageName, alignment, nowMs, thresholdMs).run();

      return json({
        should_notify: (result && result.changes === 1) || false,
        now_ms: nowMs,
      });
    }

    if (path === "/v1/usage-feedback") {
      if (request.method !== "POST") return methodNotAllowed();

      const body = await request.json().catch(() => null);
      if (!body || typeof body !== "object") return badRequest("invalid_json");

      const id = String(body.id || "");
      const userId = String(body.user_id || "");
      const packageName = String(body.package_name || "");
      const appName = String(body.app_name || "");
      const alignment = String(body.alignment || "").toLowerCase();
      const message = String(body.message || "");
      const reason = body.reason === null || body.reason === undefined ? null : String(body.reason);
      const notificationSent = Boolean(body.notification_sent);

      let createdAtMs = null;
      if (Number.isFinite(body.created_at_ms)) createdAtMs = Math.trunc(body.created_at_ms);
      if (createdAtMs === null && isNonEmptyString(body.created_at)) {
        const parsed = Date.parse(body.created_at);
        if (Number.isFinite(parsed)) createdAtMs = Math.trunc(parsed);
      }
      if (createdAtMs === null) createdAtMs = Date.now();

      if (!isNonEmptyString(id)) return badRequest("id_required");
      if (!isNonEmptyString(userId)) return badRequest("user_id_required");
      if (!isNonEmptyString(packageName)) return badRequest("package_name_required");
      if (!isNonEmptyString(appName)) return badRequest("app_name_required");
      if (!["aligned", "neutral", "misaligned"].includes(alignment)) {
        return badRequest("invalid_alignment");
      }
      if (!isNonEmptyString(message)) return badRequest("message_required");

      const stmt = env.DB.prepare(`
        INSERT INTO usage_feedback (
          id, user_id, package_name, app_name, alignment, message, reason, created_at_ms, notification_sent
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          user_id = excluded.user_id,
          package_name = excluded.package_name,
          app_name = excluded.app_name,
          alignment = excluded.alignment,
          message = excluded.message,
          reason = excluded.reason,
          created_at_ms = excluded.created_at_ms,
          notification_sent = excluded.notification_sent
      `);

      await stmt
        .bind(
          id,
          userId,
          packageName,
          appName,
          alignment,
          message,
          reason,
          createdAtMs,
          notificationSent ? 1 : 0
        )
        .run();

      return json({ ok: true });
    }

    if (path === "/v1/usage-feedback/history") {
      if (request.method !== "GET") return methodNotAllowed();

      const userId = url.searchParams.get("user_id") || "";
      if (!isNonEmptyString(userId)) return badRequest("user_id_required");

      const startMs = parseMs(url.searchParams.get("start_ms"));
      const endMs = parseMs(url.searchParams.get("end_ms"));
      // Backend `/history` caps at 500; summary may request more.
      const limit = clampInt(Number(url.searchParams.get("limit") || 50), 1, 5000);

      let sql =
        "SELECT id, user_id, package_name, app_name, alignment, message, reason, created_at_ms, notification_sent " +
        "FROM usage_feedback WHERE user_id = ?";
      const binds = [userId];

      if (startMs !== null) {
        sql += " AND created_at_ms >= ?";
        binds.push(startMs);
      }
      if (endMs !== null) {
        sql += " AND created_at_ms <= ?";
        binds.push(endMs);
      }

      sql += " ORDER BY created_at_ms DESC LIMIT ?";
      binds.push(limit);

      const res = await env.DB.prepare(sql).bind(...binds).all();
      const rows = (res && res.results) || [];

      const items = rows.map((r) => ({
        id: r.id,
        user_id: r.user_id,
        package_name: r.package_name,
        app_name: r.app_name,
        alignment: r.alignment,
        message: r.message,
        reason: r.reason || null,
        created_at: new Date(Number(r.created_at_ms)).toISOString(),
        notification_sent: Boolean(r.notification_sent),
      }));

      return json({ items, total: items.length });
    }

    if (path === "/v1/progress-score/latest") {
      if (request.method !== "GET") return methodNotAllowed();

      const userId = url.searchParams.get("user_id") || "";
      if (!isNonEmptyString(userId)) return badRequest("user_id_required");

      const sql =
        "SELECT user_id, date_utc, score_percent, reason, updated_at_ms " +
        "FROM progress_scores WHERE user_id = ? " +
        "ORDER BY date_utc DESC LIMIT 1";

      const res = await env.DB.prepare(sql).bind(userId).first();
      if (!res) {
        return json({ item: null });
      }

      return json({
        item: {
          user_id: res.user_id,
          date_utc: res.date_utc,
          score_percent: Number(res.score_percent),
          reason: String(res.reason || ""),
          updated_at: new Date(Number(res.updated_at_ms)).toISOString(),
        },
      });
    }

    if (path === "/v1/progress-score/history") {
      if (request.method !== "GET") return methodNotAllowed();

      const userId = url.searchParams.get("user_id") || "";
      if (!isNonEmptyString(userId)) return badRequest("user_id_required");

      const limit = clampInt(Number(url.searchParams.get("limit") || 30), 1, 100);

      const sql =
        "SELECT user_id, date_utc, score_percent, reason, updated_at_ms " +
        "FROM progress_scores WHERE user_id = ? " +
        "ORDER BY date_utc DESC LIMIT ?";

      const res = await env.DB.prepare(sql).bind(userId, limit).all();
      const rows = (res && res.results) || [];

      const items = rows.map((r) => ({
        user_id: r.user_id,
        date_utc: r.date_utc,
        score_percent: Number(r.score_percent),
        reason: String(r.reason || ""),
        updated_at: new Date(Number(r.updated_at_ms)).toISOString(),
      }));

      return json({ items, total: items.length });
    }

    if (path === "/v1/progress-score/upsert") {
      if (request.method !== "POST") return methodNotAllowed();

      const body = await request.json().catch(() => null);
      if (!body || typeof body !== "object") return badRequest("invalid_json");

      const userId = String(body.user_id || "");
      const dateUtc = String(body.date_utc || "");
      const scorePercent = Number(body.score_percent);
      const reason = String(body.reason || "");

      if (!isNonEmptyString(userId)) return badRequest("user_id_required");
      if (!isValidIsoDateDay(dateUtc)) return badRequest("invalid_date_utc");
      if (!Number.isFinite(scorePercent)) return badRequest("invalid_score_percent");
      const scoreInt = clampInt(scorePercent, 0, 100);
      if (!isNonEmptyString(reason)) return badRequest("reason_required");

      const nowMs = Date.now();

      const stmt = env.DB.prepare(`
        INSERT INTO progress_scores (
          user_id, date_utc, score_percent, reason, created_at_ms, updated_at_ms
        )
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(user_id, date_utc) DO UPDATE SET
          score_percent = excluded.score_percent,
          reason = excluded.reason,
          updated_at_ms = excluded.updated_at_ms
      `);

      await stmt
        .bind(userId, dateUtc, scoreInt, reason, nowMs, nowMs)
        .run();

      return json({ ok: true });
    }

    // ==================== Onboarding Preferences ====================

    if (path === "/v1/onboarding-preferences") {
      if (request.method === "POST") {
        // Upsert onboarding preferences
        const body = await request.json().catch(() => null);
        if (!body || typeof body !== "object") return badRequest("invalid_json");

        const userId = String(body.user_id || "");
        if (!isNonEmptyString(userId)) return badRequest("user_id_required");

        const challenges = JSON.stringify(Array.isArray(body.challenges) ? body.challenges : []);
        const habits = JSON.stringify(Array.isArray(body.habits) ? body.habits : []);
        const distractionHours = Number(body.distraction_hours) || 0;
        const focusDurationMinutes = Number(body.focus_duration_minutes) || 0;
        const goalClarity = clampInt(Number(body.goal_clarity) || 5, 1, 10);
        const productiveTime = String(body.productive_time || "Morning");
        const checkInFrequency = String(body.check_in_frequency || "Daily");

        const nowMs = Date.now();

        const stmt = env.DB.prepare(`
          INSERT INTO onboarding_preferences (
            user_id, challenges, habits, distraction_hours, focus_duration_minutes,
            goal_clarity, productive_time, check_in_frequency, created_at, updated_at
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(user_id) DO UPDATE SET
            challenges = excluded.challenges,
            habits = excluded.habits,
            distraction_hours = excluded.distraction_hours,
            focus_duration_minutes = excluded.focus_duration_minutes,
            goal_clarity = excluded.goal_clarity,
            productive_time = excluded.productive_time,
            check_in_frequency = excluded.check_in_frequency,
            updated_at = excluded.updated_at
        `);

        await stmt
          .bind(
            userId,
            challenges,
            habits,
            distractionHours,
            focusDurationMinutes,
            goalClarity,
            productiveTime,
            checkInFrequency,
            nowMs,
            nowMs
          )
          .run();

        return json({ ok: true });
      }

      if (request.method === "GET") {
        // Get onboarding preferences
        const userId = url.searchParams.get("user_id") || "";
        if (!isNonEmptyString(userId)) return badRequest("user_id_required");

        const res = await env.DB.prepare(
          "SELECT * FROM onboarding_preferences WHERE user_id = ?"
        )
          .bind(userId)
          .first();

        if (!res) {
          return json({ item: null });
        }

        // Parse JSON arrays
        let challenges = [];
        let habits = [];
        try {
          challenges = JSON.parse(res.challenges || "[]");
        } catch (e) {
          challenges = [];
        }
        try {
          habits = JSON.parse(res.habits || "[]");
        } catch (e) {
          habits = [];
        }

        return json({
          item: {
            user_id: res.user_id,
            challenges,
            habits,
            distraction_hours: Number(res.distraction_hours) || 0,
            focus_duration_minutes: Number(res.focus_duration_minutes) || 0,
            goal_clarity: Number(res.goal_clarity) || 5,
            productive_time: res.productive_time || "Morning",
            check_in_frequency: res.check_in_frequency || "Daily",
            created_at: new Date(Number(res.created_at)).toISOString(),
            updated_at: new Date(Number(res.updated_at)).toISOString(),
          },
        });
      }

      return methodNotAllowed();
    }

    // ==================== App Use Cases (Global Cache) ====================

    if (path === "/v1/app-use-cases/bulk") {
      if (request.method !== "POST") return methodNotAllowed();

      const body = await request.json().catch(() => null);
      if (!body || typeof body !== "object") return badRequest("invalid_json");

      const packageNames = body.package_names;
      if (!Array.isArray(packageNames) || packageNames.length === 0) {
        return badRequest("package_names_required");
      }

      // Limit to 200 packages per request
      const limitedPackages = packageNames.slice(0, 200);

      // Build query with placeholders
      const placeholders = limitedPackages.map(() => "?").join(",");
      const sql = `SELECT package_name, app_name, use_cases, category, created_at_ms FROM app_use_cases WHERE package_name IN (${placeholders})`;

      const res = await env.DB.prepare(sql).bind(...limitedPackages).all();
      const rows = (res && res.results) || [];

      const items = rows.map((r) => ({
        package_name: r.package_name,
        app_name: r.app_name,
        use_cases: r.use_cases,
        category: r.category,
        created_at_ms: r.created_at_ms,
      }));

      return json({ items, total: items.length });
    }

    if (path === "/v1/app-use-cases") {
      if (request.method !== "POST") return methodNotAllowed();

      const body = await request.json().catch(() => null);
      if (!body || typeof body !== "object") return badRequest("invalid_json");

      const packageName = String(body.package_name || "");
      const appName = String(body.app_name || "");
      const useCases = String(body.use_cases || "[]");
      const category = body.category ? String(body.category) : null;
      const createdAtMs = Number(body.created_at_ms) || Date.now();

      if (!isNonEmptyString(packageName)) return badRequest("package_name_required");
      if (!isNonEmptyString(appName)) return badRequest("app_name_required");

      const stmt = env.DB.prepare(`
        INSERT INTO app_use_cases (package_name, app_name, use_cases, category, created_at_ms)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(package_name) DO UPDATE SET
          app_name = excluded.app_name,
          use_cases = excluded.use_cases,
          category = excluded.category,
          created_at_ms = excluded.created_at_ms
      `);

      await stmt.bind(packageName, appName, useCases, category, createdAtMs).run();

      return json({ ok: true });
    }

    if (path === "/v1/app-use-cases/cleanup") {
      if (request.method !== "DELETE") return methodNotAllowed();

      // Delete app use cases that have empty use_cases arrays (poisoned cache)
      // This cleans up failed Gemini generations
      const stmt = env.DB.prepare(`
        DELETE FROM app_use_cases 
        WHERE use_cases = '[]' OR use_cases IS NULL OR use_cases = ''
      `);

      const result = await stmt.run();

      return json({
        ok: true,
        deleted_count: result.changes || 0,
        message: `Cleaned up ${result.changes || 0} empty use case entries`
      });
    }

    // ==================== Users (Persistent Storage) ====================

    if (path === "/v1/users") {
      if (request.method === "POST") {
        // Upsert user
        const body = await request.json().catch(() => null);
        if (!body || typeof body !== "object") return badRequest("invalid_json");

        const id = String(body.id || "");
        const email = String(body.email || "");
        const displayName = body.display_name ? String(body.display_name) : null;
        const photoUrl = body.photo_url ? String(body.photo_url) : null;
        const onboardingComplete = body.onboarding_complete ? 1 : 0;

        if (!isNonEmptyString(id)) return badRequest("id_required");
        if (!isNonEmptyString(email)) return badRequest("email_required");

        const nowMs = Date.now();

        const stmt = env.DB.prepare(`
          INSERT INTO users (id, email, display_name, photo_url, onboarding_complete, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            email = excluded.email,
            display_name = excluded.display_name,
            photo_url = excluded.photo_url,
            onboarding_complete = excluded.onboarding_complete,
            updated_at = excluded.updated_at
        `);

        await stmt.bind(id, email, displayName, photoUrl, onboardingComplete, nowMs, nowMs).run();

        return json({ ok: true });
      }

      if (request.method === "GET") {
        // Get user by ID
        const userId = url.searchParams.get("user_id") || "";
        if (!isNonEmptyString(userId)) return badRequest("user_id_required");

        const res = await env.DB.prepare(
          "SELECT * FROM users WHERE id = ?"
        ).bind(userId).first();

        if (!res) {
          return json({ item: null });
        }

        return json({
          item: {
            id: res.id,
            email: res.email,
            display_name: res.display_name,
            photo_url: res.photo_url,
            onboarding_complete: Boolean(res.onboarding_complete),
            created_at: new Date(Number(res.created_at)).toISOString(),
            updated_at: new Date(Number(res.updated_at)).toISOString(),
          },
        });
      }

      return methodNotAllowed();
    }

    if (path === "/v1/users/onboarding-status") {
      if (request.method !== "POST") return methodNotAllowed();

      const body = await request.json().catch(() => null);
      if (!body || typeof body !== "object") return badRequest("invalid_json");

      const userId = String(body.user_id || "");
      const onboardingComplete = body.onboarding_complete ? 1 : 0;

      if (!isNonEmptyString(userId)) return badRequest("user_id_required");

      const nowMs = Date.now();

      const stmt = env.DB.prepare(`
        UPDATE users SET onboarding_complete = ?, updated_at = ? WHERE id = ?
      `);

      await stmt.bind(onboardingComplete, nowMs, userId).run();

      return json({ ok: true });
    }

    // ==================== Goals (Persistent Storage) ====================

    if (path === "/v1/goals") {
      if (request.method === "POST") {
        // Create or update goal
        const body = await request.json().catch(() => null);
        if (!body || typeof body !== "object") return badRequest("invalid_json");

        const id = String(body.id || "");
        const userId = String(body.user_id || "");
        const content = String(body.content || "");
        const reason = body.reason ? String(body.reason) : null;
        const timeline = body.timeline ? String(body.timeline) : null;

        if (!isNonEmptyString(id)) return badRequest("id_required");
        if (!isNonEmptyString(userId)) return badRequest("user_id_required");
        if (!isNonEmptyString(content)) return badRequest("content_required");

        const nowMs = Date.now();

        const stmt = env.DB.prepare(`
          INSERT INTO goals (id, user_id, content, reason, timeline, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            content = excluded.content,
            reason = excluded.reason,
            timeline = excluded.timeline,
            updated_at = excluded.updated_at
        `);

        await stmt.bind(id, userId, content, reason, timeline, nowMs, nowMs).run();

        return json({ ok: true });
      }

      if (request.method === "GET") {
        // Get goals for user
        const userId = url.searchParams.get("user_id") || "";
        if (!isNonEmptyString(userId)) return badRequest("user_id_required");

        const res = await env.DB.prepare(
          "SELECT * FROM goals WHERE user_id = ? ORDER BY created_at ASC"
        ).bind(userId).all();

        const rows = (res && res.results) || [];

        const items = rows.map((r) => ({
          id: r.id,
          user_id: r.user_id,
          content: r.content,
          reason: r.reason,
          timeline: r.timeline,
          created_at: new Date(Number(r.created_at)).toISOString(),
          updated_at: new Date(Number(r.updated_at)).toISOString(),
        }));

        return json({ items, total: items.length });
      }

      if (request.method === "DELETE") {
        // Delete a specific goal
        const body = await request.json().catch(() => null);
        if (!body || typeof body !== "object") return badRequest("invalid_json");

        const id = String(body.id || "");
        const userId = String(body.user_id || "");

        if (!isNonEmptyString(id)) return badRequest("id_required");
        if (!isNonEmptyString(userId)) return badRequest("user_id_required");

        await env.DB.prepare(
          "DELETE FROM goals WHERE id = ? AND user_id = ?"
        ).bind(id, userId).run();

        return json({ ok: true });
      }

      return methodNotAllowed();
    }

    if (path === "/v1/goals/bulk") {
      if (request.method !== "DELETE") return methodNotAllowed();

      // Delete all goals for a user
      const body = await request.json().catch(() => null);
      if (!body || typeof body !== "object") return badRequest("invalid_json");

      const userId = String(body.user_id || "");
      if (!isNonEmptyString(userId)) return badRequest("user_id_required");

      await env.DB.prepare("DELETE FROM goals WHERE user_id = ?").bind(userId).run();

      return json({ ok: true });
    }

    // ==================== App Selections (Persistent Storage) ====================

    if (path === "/v1/app-selections") {
      if (request.method === "POST") {
        // Create or update app selection
        const body = await request.json().catch(() => null);
        if (!body || typeof body !== "object") return badRequest("invalid_json");

        const id = String(body.id || "");
        const userId = String(body.user_id || "");
        const packageName = String(body.package_name || "");
        const appName = String(body.app_name || "");
        const reason = body.reason ? String(body.reason) : null;
        const importanceRating = clampInt(Number(body.importance_rating) || 3, 1, 5);

        if (!isNonEmptyString(id)) return badRequest("id_required");
        if (!isNonEmptyString(userId)) return badRequest("user_id_required");
        if (!isNonEmptyString(packageName)) return badRequest("package_name_required");
        if (!isNonEmptyString(appName)) return badRequest("app_name_required");

        const nowMs = Date.now();

        const stmt = env.DB.prepare(`
          INSERT INTO app_selections (id, user_id, package_name, app_name, reason, importance_rating, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(user_id, package_name) DO UPDATE SET
            id = excluded.id,
            app_name = excluded.app_name,
            reason = excluded.reason,
            importance_rating = excluded.importance_rating,
            updated_at = excluded.updated_at
        `);

        await stmt.bind(id, userId, packageName, appName, reason, importanceRating, nowMs, nowMs).run();

        return json({ ok: true });
      }

      if (request.method === "GET") {
        // Get app selections for user
        const userId = url.searchParams.get("user_id") || "";
        if (!isNonEmptyString(userId)) return badRequest("user_id_required");

        const res = await env.DB.prepare(
          "SELECT * FROM app_selections WHERE user_id = ? ORDER BY created_at ASC"
        ).bind(userId).all();

        const rows = (res && res.results) || [];

        const items = rows.map((r) => ({
          id: r.id,
          user_id: r.user_id,
          package_name: r.package_name,
          app_name: r.app_name,
          reason: r.reason,
          importance_rating: Number(r.importance_rating),
          created_at: new Date(Number(r.created_at)).toISOString(),
          updated_at: new Date(Number(r.updated_at)).toISOString(),
        }));

        return json({ items, total: items.length });
      }

      if (request.method === "DELETE") {
        // Delete a specific app selection
        const body = await request.json().catch(() => null);
        if (!body || typeof body !== "object") return badRequest("invalid_json");

        const id = String(body.id || "");
        const userId = String(body.user_id || "");

        if (!isNonEmptyString(id)) return badRequest("id_required");
        if (!isNonEmptyString(userId)) return badRequest("user_id_required");

        await env.DB.prepare(
          "DELETE FROM app_selections WHERE id = ? AND user_id = ?"
        ).bind(id, userId).run();

        return json({ ok: true });
      }

      return methodNotAllowed();
    }

    if (path === "/v1/app-selections/bulk") {
      if (request.method === "POST") {
        // Bulk upsert app selections
        const body = await request.json().catch(() => null);
        if (!body || typeof body !== "object") return badRequest("invalid_json");

        const selections = body.selections;
        if (!Array.isArray(selections) || selections.length === 0) {
          return badRequest("selections_required");
        }

        const nowMs = Date.now();
        const statements = [];

        for (const sel of selections.slice(0, 100)) { // Limit to 100 at a time
          const id = String(sel.id || "");
          const userId = String(sel.user_id || "");
          const packageName = String(sel.package_name || "");
          const appName = String(sel.app_name || "");
          const reason = sel.reason ? String(sel.reason) : null;
          const importanceRating = clampInt(Number(sel.importance_rating) || 3, 1, 5);

          if (!isNonEmptyString(id) || !isNonEmptyString(userId) ||
            !isNonEmptyString(packageName) || !isNonEmptyString(appName)) {
            continue;
          }

          statements.push(
            env.DB.prepare(`
              INSERT INTO app_selections (id, user_id, package_name, app_name, reason, importance_rating, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?)
              ON CONFLICT(user_id, package_name) DO UPDATE SET
                id = excluded.id,
                app_name = excluded.app_name,
                reason = excluded.reason,
                importance_rating = excluded.importance_rating,
                updated_at = excluded.updated_at
            `).bind(id, userId, packageName, appName, reason, importanceRating, nowMs, nowMs)
          );
        }

        if (statements.length > 0) {
          await env.DB.batch(statements);
        }

        return json({ ok: true, count: statements.length });
      }

      if (request.method === "DELETE") {
        // Delete all app selections for a user
        const body = await request.json().catch(() => null);
        if (!body || typeof body !== "object") return badRequest("invalid_json");

        const userId = String(body.user_id || "");
        if (!isNonEmptyString(userId)) return badRequest("user_id_required");

        await env.DB.prepare("DELETE FROM app_selections WHERE user_id = ?").bind(userId).run();

        return json({ ok: true });
      }

      return methodNotAllowed();
    }

    // ==================== Notification Profiles (Persistent Storage) ====================

    if (path === "/v1/notification-profiles") {
      if (request.method === "POST") {
        // Upsert notification profile
        const body = await request.json().catch(() => null);
        if (!body || typeof body !== "object") return badRequest("invalid_json");

        const userId = String(body.user_id || "");
        if (!isNonEmptyString(userId)) return badRequest("user_id_required");

        // Store the entire profile as JSON
        const profileData = body.profile_data || {};
        const profileJson = JSON.stringify(profileData);

        const nowMs = Date.now();

        const stmt = env.DB.prepare(`
          INSERT INTO notification_profiles (user_id, profile_data, created_at, updated_at)
          VALUES (?, ?, ?, ?)
          ON CONFLICT(user_id) DO UPDATE SET
            profile_data = excluded.profile_data,
            updated_at = excluded.updated_at
        `);

        await stmt.bind(userId, profileJson, nowMs, nowMs).run();

        return json({ ok: true });
      }

      if (request.method === "GET") {
        // Get notification profile for user
        const userId = url.searchParams.get("user_id") || "";
        if (!isNonEmptyString(userId)) return badRequest("user_id_required");

        const res = await env.DB.prepare(
          "SELECT * FROM notification_profiles WHERE user_id = ?"
        ).bind(userId).first();

        if (!res) {
          return json({ item: null });
        }

        let profileData = {};
        try {
          profileData = JSON.parse(res.profile_data || "{}");
        } catch (e) {
          profileData = {};
        }

        return json({
          item: {
            user_id: res.user_id,
            profile_data: profileData,
            created_at: new Date(Number(res.created_at)).toISOString(),
            updated_at: new Date(Number(res.updated_at)).toISOString(),
          },
        });
      }

      if (request.method === "DELETE") {
        // Delete notification profile
        const body = await request.json().catch(() => null);
        if (!body || typeof body !== "object") return badRequest("invalid_json");

        const userId = String(body.user_id || "");
        if (!isNonEmptyString(userId)) return badRequest("user_id_required");

        await env.DB.prepare(
          "DELETE FROM notification_profiles WHERE user_id = ?"
        ).bind(userId).run();

        return json({ ok: true });
      }

      return methodNotAllowed();
    }

    // ==================== Goal Journeys (Persistent Storage) ====================

    if (path === "/v1/goal-journeys/upsert") {
      if (request.method !== "POST") return methodNotAllowed();

      const body = await request.json().catch(() => null);
      if (!body || typeof body !== "object") return badRequest("invalid_json");

      const journey = body.journey && typeof body.journey === "object" ? body.journey : null;
      if (!journey) return badRequest("journey_required");

      const id = String(journey.id || "");
      const userId = String(journey.user_id || "");
      const goalId = journey.goal_id ? String(journey.goal_id) : null;
      const goalContent = String(journey.goal_content || "");
      const goalReason = journey.goal_reason ? String(journey.goal_reason) : null;
      const currentStepIndex = clampInt(Number(journey.current_step_index) || 0, 0, 1000000);

      const overallProgressRaw = Number(journey.overall_progress);
      const overallProgress = Number.isFinite(overallProgressRaw) ? overallProgressRaw : 0.0;

      const isAIGenerated = journey.is_ai_generated ? 1 : 0;
      const aiNotes = journey.ai_notes ? String(journey.ai_notes) : null;

      const mapWidthRaw = Number(journey.map_width);
      const mapHeightRaw = Number(journey.map_height);
      const mapWidth = Number.isFinite(mapWidthRaw) ? mapWidthRaw : 1000.0;
      const mapHeight = Number.isFinite(mapHeightRaw) ? mapHeightRaw : 2000.0;

      const journeyStartedAt = journey.journey_started_at
        ? String(journey.journey_started_at)
        : new Date().toISOString();
      const createdAt = journey.created_at ? String(journey.created_at) : new Date().toISOString();
      const updatedAt = journey.updated_at ? String(journey.updated_at) : null;

      if (!isNonEmptyString(id)) return badRequest("id_required");
      if (!isNonEmptyString(userId)) return badRequest("user_id_required");
      if (!isNonEmptyString(goalContent)) return badRequest("goal_content_required");

      const statements = [];

      statements.push(
        env.DB.prepare(`
          INSERT INTO goal_journeys (
            id, user_id, goal_id, goal_content, goal_reason,
            current_step_index, overall_progress, is_ai_generated, ai_notes,
            map_width, map_height, journey_started_at, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            user_id = excluded.user_id,
            goal_id = excluded.goal_id,
            goal_content = excluded.goal_content,
            goal_reason = excluded.goal_reason,
            current_step_index = excluded.current_step_index,
            overall_progress = excluded.overall_progress,
            is_ai_generated = excluded.is_ai_generated,
            ai_notes = excluded.ai_notes,
            map_width = excluded.map_width,
            map_height = excluded.map_height,
            updated_at = excluded.updated_at
        `).bind(
          id,
          userId,
          goalId,
          goalContent,
          goalReason,
          currentStepIndex,
          overallProgress,
          isAIGenerated,
          aiNotes,
          mapWidth,
          mapHeight,
          journeyStartedAt,
          createdAt,
          updatedAt
        )
      );

      const steps = Array.isArray(journey.steps) ? journey.steps : [];
      const stepIds = [];

      for (const s of steps) {
        if (!s || typeof s !== "object") return badRequest("invalid_step");

        const stepId = String(s.id || "");
        const title = String(s.title || "");

        if (!isNonEmptyString(stepId)) return badRequest("step_id_required");
        if (!isNonEmptyString(title)) return badRequest("step_title_required");

        stepIds.push(stepId);

        const customTitle = s.custom_title ? String(s.custom_title) : null;
        const description = s.description ? String(s.description) : "";
        const orderIndex = clampInt(Number(s.order_index ?? s.order ?? 0), 0, 1000000);
        const status = String(s.status || "locked").toLowerCase();

        const prereqArr = Array.isArray(s.prerequisites)
          ? s.prerequisites.map((x) => String(x))
          : safeJsonParse(s.prerequisites, []);
        const altArr = Array.isArray(s.alternatives)
          ? s.alternatives.map((x) => String(x))
          : safeJsonParse(s.alternatives, []);
        const notesArr = Array.isArray(s.notes) ? s.notes.map((x) => String(x)) : safeJsonParse(s.notes, []);

        const prereqText = JSON.stringify(Array.isArray(prereqArr) ? prereqArr : []);
        const altText = JSON.stringify(Array.isArray(altArr) ? altArr : []);
        const notesText = JSON.stringify(Array.isArray(notesArr) ? notesArr : []);

        const metadataObj =
          s.metadata && typeof s.metadata === "object" ? s.metadata : safeJsonParse(s.metadata, null);
        const metadataText = metadataObj ? JSON.stringify(metadataObj) : null;

        const position = s.position && typeof s.position === "object" ? s.position : {};
        const posXRaw = Number(position.x);
        const posYRaw = Number(position.y);
        const posLayerRaw = Number(position.layer);
        const posX = Number.isFinite(posXRaw) ? posXRaw : 0.5;
        const posY = Number.isFinite(posYRaw) ? posYRaw : 0.0;
        const posLayer = Number.isFinite(posLayerRaw) ? posLayerRaw : 0;

        const pathType = String(s.path_type || "main").toLowerCase();
        const estimatedDays = clampInt(Number(s.estimated_days) || 14, 1, 1000000);
        const actualDaysSpent =
          s.actual_days_spent === null || s.actual_days_spent === undefined
            ? null
            : Number(s.actual_days_spent);

        const startedAt = s.started_at ? String(s.started_at) : null;
        const completedAt = s.completed_at ? String(s.completed_at) : null;
        const stepCreatedAt = s.created_at ? String(s.created_at) : new Date().toISOString();

        statements.push(
          env.DB.prepare(`
            INSERT INTO goal_steps (
              id, journey_id, title, custom_title, description, order_index, status,
              prerequisites, alternatives, started_at, completed_at, notes, metadata,
              position_x, position_y, position_layer, path_type, estimated_days, actual_days_spent, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              journey_id = excluded.journey_id,
              title = excluded.title,
              custom_title = excluded.custom_title,
              description = excluded.description,
              order_index = excluded.order_index,
              status = excluded.status,
              prerequisites = excluded.prerequisites,
              alternatives = excluded.alternatives,
              started_at = excluded.started_at,
              completed_at = excluded.completed_at,
              notes = excluded.notes,
              metadata = excluded.metadata,
              position_x = excluded.position_x,
              position_y = excluded.position_y,
              position_layer = excluded.position_layer,
              path_type = excluded.path_type,
              estimated_days = excluded.estimated_days,
              actual_days_spent = excluded.actual_days_spent
          `).bind(
            stepId,
            id,
            title,
            customTitle,
            description,
            orderIndex,
            status,
            prereqText,
            altText,
            startedAt,
            completedAt,
            notesText,
            metadataText,
            posX,
            posY,
            posLayer,
            pathType,
            estimatedDays,
            actualDaysSpent,
            stepCreatedAt
          )
        );
      }

      // Delete steps removed from this journey (keep DB consistent if the step list ever changes).
      if (stepIds.length > 0) {
        const placeholders = stepIds.map(() => "?").join(",");
        statements.push(
          env.DB.prepare(
            `DELETE FROM goal_steps WHERE journey_id = ? AND id NOT IN (${placeholders})`
          ).bind(id, ...stepIds)
        );
      } else {
        statements.push(env.DB.prepare("DELETE FROM goal_steps WHERE journey_id = ?").bind(id));
      }

      await env.DB.batch(statements);

      return json({ ok: true, journey_id: id, steps_saved: stepIds.length });
    }

    if (path === "/v1/goal-journeys/current") {
      if (request.method !== "GET") return methodNotAllowed();

      const userId = url.searchParams.get("user_id") || "";
      if (!isNonEmptyString(userId)) return badRequest("user_id_required");

      const res = await env.DB.prepare(
        "SELECT * FROM goal_journeys WHERE user_id = ? ORDER BY COALESCE(updated_at, created_at) DESC LIMIT 1"
      )
        .bind(userId)
        .first();

      if (!res) return json({ item: null });

      const item = await loadJourneyWithSteps(res);
      return json({ item });
    }

    if (path === "/v1/goal-journeys/by-id") {
      if (request.method !== "GET") return methodNotAllowed();

      const userId = url.searchParams.get("user_id") || "";
      const journeyId = url.searchParams.get("journey_id") || "";
      if (!isNonEmptyString(userId)) return badRequest("user_id_required");
      if (!isNonEmptyString(journeyId)) return badRequest("journey_id_required");

      const res = await env.DB.prepare(
        "SELECT * FROM goal_journeys WHERE id = ? AND user_id = ? LIMIT 1"
      )
        .bind(journeyId, userId)
        .first();

      if (!res) return json({ item: null });

      const item = await loadJourneyWithSteps(res);
      return json({ item });
    }

    if (path === "/v1/goal-journeys/by-step") {
      if (request.method !== "GET") return methodNotAllowed();

      const userId = url.searchParams.get("user_id") || "";
      const stepId = url.searchParams.get("step_id") || "";
      if (!isNonEmptyString(userId)) return badRequest("user_id_required");
      if (!isNonEmptyString(stepId)) return badRequest("step_id_required");

      const res = await env.DB.prepare(
        `SELECT g.*
         FROM goal_journeys g
         JOIN goal_steps s ON s.journey_id = g.id
         WHERE g.user_id = ? AND s.id = ?
         LIMIT 1`
      )
        .bind(userId, stepId)
        .first();

      if (!res) return json({ item: null });

      const item = await loadJourneyWithSteps(res);
      return json({ item });
    }

    if (path === "/v1/goal-journeys") {
      if (request.method !== "DELETE") return methodNotAllowed();

      const body = await request.json().catch(() => null);
      if (!body || typeof body !== "object") return badRequest("invalid_json");

      const userId = String(body.user_id || "");
      const journeyId = String(body.journey_id || "");
      if (!isNonEmptyString(userId)) return badRequest("user_id_required");
      if (!isNonEmptyString(journeyId)) return badRequest("journey_id_required");

      const statements = [
        env.DB.prepare(
          "DELETE FROM step_progress_log WHERE step_id IN (SELECT id FROM goal_steps WHERE journey_id = ?)"
        ).bind(journeyId),
        env.DB.prepare("DELETE FROM goal_steps WHERE journey_id = ?").bind(journeyId),
        env.DB.prepare("DELETE FROM goal_journeys WHERE id = ? AND user_id = ?").bind(journeyId, userId),
      ];

      await env.DB.batch(statements);

      return json({ ok: true });
    }

    // ==================== User Data Deletion ====================

    if (path === "/v1/user/data") {
      if (request.method !== "DELETE") return methodNotAllowed();

      const body = await request.json().catch(() => null);
      if (!body || typeof body !== "object") return badRequest("invalid_json");

      const userId = String(body.user_id || "");
      if (!isNonEmptyString(userId)) return badRequest("user_id_required");

      // Delete from all tables (including persistent storage tables)
      // Note: app_use_cases is global, not per-user, so not deleted here
      const batch = [
        env.DB.prepare("DELETE FROM usage_feedback WHERE user_id = ?").bind(userId),
        env.DB.prepare("DELETE FROM notification_cooldowns WHERE user_id = ?").bind(userId),
        env.DB.prepare("DELETE FROM progress_scores WHERE user_id = ?").bind(userId),
        env.DB.prepare("DELETE FROM onboarding_preferences WHERE user_id = ?").bind(userId),
        env.DB.prepare("DELETE FROM goals WHERE user_id = ?").bind(userId),
        env.DB.prepare("DELETE FROM app_selections WHERE user_id = ?").bind(userId),
        env.DB.prepare("DELETE FROM notification_profiles WHERE user_id = ?").bind(userId),
        env.DB.prepare("DELETE FROM step_progress_log WHERE user_id = ?").bind(userId),
        env.DB.prepare(
          "DELETE FROM goal_steps WHERE journey_id IN (SELECT id FROM goal_journeys WHERE user_id = ?)"
        ).bind(userId),
        env.DB.prepare("DELETE FROM goal_journeys WHERE user_id = ?").bind(userId),
        env.DB.prepare("DELETE FROM users WHERE id = ?").bind(userId)
      ];

      await env.DB.batch(batch);

      return json({ ok: true });
    }

    return notFound();
  },
};
