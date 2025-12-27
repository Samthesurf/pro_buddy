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

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

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
        env.DB.prepare("DELETE FROM users WHERE id = ?").bind(userId)
      ];

      await env.DB.batch(batch);

      return json({ ok: true });
    }

    return notFound();
  },
};
