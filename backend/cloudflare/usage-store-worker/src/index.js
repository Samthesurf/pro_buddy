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

    return notFound();
  },
};
