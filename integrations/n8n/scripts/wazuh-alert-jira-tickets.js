#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const http = require("http");
const https = require("https");
const crypto = require("crypto");

const OUTPUT_DIR = process.env.TRIAGE_OUTPUT_DIR || "/home/node/.n8n/output";

function env(name, fallback = "") {
  const value = process.env[name];
  return value === undefined || value === "" ? fallback : value;
}

function envBool(name, fallback = false) {
  const value = env(name, fallback ? "true" : "false").toLowerCase();
  return ["1", "true", "yes", "y"].includes(value);
}

function envNumber(name, fallback) {
  const raw = env(name, String(fallback));
  const value = Number(raw);
  return Number.isFinite(value) ? value : fallback;
}

function compactWhitespace(value, maxLength = 500) {
  return String(value || "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maxLength);
}

function parseList(value, fallback = []) {
  const raw = String(value || "").trim();
  if (!raw) return fallback;
  return raw.split(",").map((item) => item.trim()).filter(Boolean);
}

function parseJsonEnv(name, fallback) {
  const raw = env(name, JSON.stringify(fallback));
  try {
    return JSON.parse(raw);
  } catch (error) {
    console.error(`WARN: ${name} is not valid JSON. Using default value. ${error.message}`);
    return fallback;
  }
}

function sanitizeLabel(value) {
  return String(value || "unknown")
    .toLowerCase()
    .replace(/[^a-z0-9-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 200) || "unknown";
}

function shortHash(value) {
  return crypto.createHash("sha256").update(String(value)).digest("hex").slice(0, 16);
}

function basicAuth(username, password) {
  return `Basic ${Buffer.from(`${username}:${password}`).toString("base64")}`;
}

function requestJson(url, options = {}) {
  const target = new URL(url);
  const isHttps = target.protocol === "https:";
  const lib = isHttps ? https : http;
  const headers = Object.assign({}, options.headers || {});
  let body;

  if (options.body !== undefined) {
    body = typeof options.body === "string" ? options.body : JSON.stringify(options.body);
    headers["Content-Type"] = headers["Content-Type"] || "application/json";
    headers["Content-Length"] = Buffer.byteLength(body);
  }

  if (options.username || options.password) {
    headers.Authorization = basicAuth(options.username || "", options.password || "");
  }

  const requestOptions = {
    method: options.method || "GET",
    headers,
    timeout: options.timeoutMs || 45000,
  };

  if (isHttps && options.insecureTls) {
    requestOptions.agent = new https.Agent({ rejectUnauthorized: false });
  }

  return new Promise((resolve, reject) => {
    const req = lib.request(target, requestOptions, (res) => {
      let data = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => { data += chunk; });
      res.on("end", () => {
        let bodyValue = data;
        const looksJson = data.trim().startsWith("{") || data.trim().startsWith("[");
        if (looksJson) {
          try {
            bodyValue = JSON.parse(data);
          } catch (error) {
            reject(error);
            return;
          }
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          const error = new Error(`HTTP ${res.statusCode} from ${target.origin}${target.pathname}`);
          error.statusCode = res.statusCode;
          error.body = bodyValue;
          reject(error);
          return;
        }
        resolve(bodyValue);
      });
    });

    req.on("timeout", () => req.destroy(new Error(`Request timed out: ${url}`)));
    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

function priorityGroup(priority) {
  return `incident_priority_${priority.toLowerCase()}`;
}

function priorityFromGroups(groups) {
  const normalized = new Set((groups || []).map((item) => String(item).toLowerCase()));
  if (normalized.has("incident_priority_p1")) return "P1";
  if (normalized.has("incident_priority_p2")) return "P2";
  if (normalized.has("incident_priority_p3")) return "P3";
  return "";
}

function priorityFromLevel(level) {
  if (level >= 13) return "P1";
  if (level >= 10) return "P2";
  if (level >= 7) return "P3";
  return "";
}

function allowedPriorities() {
  return parseList(env("ALERT_PRIORITIES", "P1,P2,P3"), ["P1", "P2", "P3"])
    .map((item) => item.toUpperCase());
}

function buildWazuhAlertQuery() {
  const priorities = allowedPriorities();
  const priorityGroups = priorities.map(priorityGroup);
  const lookbackMinutes = envNumber("ALERT_LOOKBACK_MINUTES", 60);
  const includeLevelDerived = envBool("ALERT_INCLUDE_LEVEL_DERIVED", false);
  const should = [{ terms: { "rule.groups": priorityGroups } }];
  const excludeRuleIds = parseList(env("ALERT_EXCLUDE_RULE_IDS", ""), []);

  if (includeLevelDerived) {
    should.push({ range: { "rule.level": { gte: envNumber("ALERT_LEVEL_DERIVED_MIN", 7) } } });
  }

  const boolQuery = {
    filter: [
      { range: { timestamp: { gte: `now-${lookbackMinutes}m` } } },
      { bool: { should, minimum_should_match: 1 } },
    ],
  };

  if (excludeRuleIds.length) {
    boolQuery.must_not = [{ terms: { "rule.id": excludeRuleIds } }];
  }

  return {
    size: envNumber("ALERT_MAX_RESULTS", 100),
    sort: [{ timestamp: { order: "desc", unmapped_type: "date" } }],
    _source: [
      "timestamp",
      "agent.id",
      "agent.name",
      "agent.ip",
      "agent.labels",
      "manager.name",
      "rule.id",
      "rule.level",
      "rule.description",
      "rule.groups",
      "rule.mitre",
      "rule.frequency",
      "rule.firedtimes",
      "data",
      "syscheck.path",
      "full_log",
      "previous_output",
      "location",
      "decoder.name",
      "predecoder.program_name",
    ],
    query: { bool: boolQuery },
  };
}

async function loadWazuhAlerts() {
  const sample = env("ALERT_SAMPLE_FILE", "");
  if (sample) {
    return JSON.parse(fs.readFileSync(sample, "utf8"));
  }

  const baseUrl = env("WAZUH_INDEXER_URL").replace(/\/+$/, "");
  const index = env("ALERT_WAZUH_INDEX", "wazuh-alerts-*");
  if (!baseUrl) throw new Error("WAZUH_INDEXER_URL is not configured");

  return requestJson(`${baseUrl}/${index}/_search`, {
    method: "POST",
    body: buildWazuhAlertQuery(),
    username: env("WAZUH_INDEXER_USERNAME"),
    password: env("WAZUH_INDEXER_PASSWORD"),
    insecureTls: envBool("WAZUH_INDEXER_INSECURE_TLS", true),
    timeoutMs: 45000,
  });
}

function triggerReason(source, priority, derivedFromLevel) {
  const rule = source.rule || {};
  const groups = rule.groups || [];
  const reasons = [];

  if (!derivedFromLevel) {
    reasons.push(`La regla trae el grupo ${priorityGroup(priority)}, por eso se clasifica como ${priority}.`);
  } else {
    reasons.push(`La regla no trae grupo P1/P2/P3, pero el nivel ${rule.level} se mapeo a ${priority}.`);
  }

  if (groups.includes("soc_incident")) reasons.push("Wazuh la marco como incidente SOC correlacionado.");
  if (groups.includes("critical_asset")) reasons.push("El evento afecta o involucra un activo critico del laboratorio.");
  if (groups.includes("internet_facing")) reasons.push("El activo o flujo esta expuesto hacia internet.");
  if ((rule.mitre || {}).id) reasons.push(`Tiene mapeo MITRE: ${[].concat(rule.mitre.id).join(", ")}.`);
  return reasons.join(" ");
}

function incidentKey(source, priority) {
  const rule = source.rule || {};
  const agent = source.agent || {};
  const data = source.data || {};
  const syscheck = source.syscheck || {};
  return [
    priority,
    rule.id || "unknown-rule",
    agent.id || agent.name || "unknown-agent",
    data.srcip || "",
    data.dstip || "",
    data.srcuser || "",
    data.dstuser || "",
    syscheck.path || "",
  ].join("|");
}

function normalizeAlerts(wazuhResponse) {
  const hits = (((wazuhResponse || {}).hits || {}).hits || []);
  const priorities = new Set(allowedPriorities());
  const includeLevelDerived = envBool("ALERT_INCLUDE_LEVEL_DERIVED", false);
  const grouped = new Map();

  for (const hit of hits) {
    const source = hit._source || {};
    const rule = source.rule || {};
    const groups = rule.groups || [];
    const groupPriority = priorityFromGroups(groups);
    const derivedPriority = includeLevelDerived ? priorityFromLevel(Number(rule.level || 0)) : "";
    const priority = groupPriority || derivedPriority;
    if (!priority || !priorities.has(priority)) continue;

    const keyRaw = incidentKey(source, priority);
    const keyHash = shortHash(keyRaw);
    const data = source.data || {};
    const agent = source.agent || {};
    const syscheck = source.syscheck || {};
    const existing = grouped.get(keyHash);
    const event = {
      keyHash,
      keyRaw,
      clientName: env("CLIENT_NAME", "Demo PYME"),
      priority,
      derivedFromLevel: !groupPriority,
      timestamp: source.timestamp || "",
      ruleId: String(rule.id || ""),
      ruleLevel: Number(rule.level || 0),
      ruleDescription: rule.description || "",
      ruleGroups: groups,
      mitre: rule.mitre || {},
      firedtimes: rule.firedtimes || "",
      agentId: agent.id || "",
      agentName: agent.name || "unknown",
      agentIp: agent.ip || "",
      managerName: (source.manager || {}).name || "",
      srcip: data.srcip || "",
      dstip: data.dstip || "",
      srcport: data.srcport || "",
      dstport: data.dstport || "",
      srcuser: data.srcuser || "",
      dstuser: data.dstuser || "",
      syscheckPath: syscheck.path || "",
      decoder: (source.decoder || {}).name || "",
      programName: (source.predecoder || {}).program_name || "",
      location: source.location || "",
      fullLog: compactWhitespace(source.full_log || "", 1200),
      previousOutput: compactWhitespace(source.previous_output || "", 1500),
      triggerReason: triggerReason(source, priority, !groupPriority),
    };

    if (!existing) {
      grouped.set(keyHash, Object.assign(event, { count: 1, firstSeen: event.timestamp, lastSeen: event.timestamp }));
      continue;
    }

    existing.count += 1;
    if (event.timestamp > existing.lastSeen) {
      Object.assign(existing, event, { count: existing.count, firstSeen: existing.firstSeen, lastSeen: event.timestamp });
    } else if (!existing.firstSeen || event.timestamp < existing.firstSeen) {
      existing.firstSeen = event.timestamp;
    }
  }

  const priorityRank = { P1: 1, P2: 2, P3: 3 };
  return Array.from(grouped.values())
    .sort((a, b) => priorityRank[a.priority] - priorityRank[b.priority] || b.ruleLevel - a.ruleLevel || b.count - a.count)
    .slice(0, envNumber("ALERT_TOP_FINDINGS", 25));
}

function jiraIssueUrl(issueKey) {
  const baseUrl = env("JIRA_BASE_URL").replace(/\/+$/, "");
  return issueKey && baseUrl ? `${baseUrl}/browse/${issueKey}` : "";
}

async function jiraRequest(pathname, options = {}) {
  const baseUrl = env("JIRA_BASE_URL").replace(/\/+$/, "");
  if (!baseUrl) throw new Error("JIRA_BASE_URL is not configured");
  return requestJson(`${baseUrl}${pathname}`, {
    method: options.method || "GET",
    body: options.body,
    username: env("JIRA_EMAIL"),
    password: env("JIRA_API_TOKEN"),
    headers: { Accept: "application/json" },
    timeoutMs: 45000,
  });
}

function jiraLabels(alert) {
  return [
    "wazuh-alert",
    `alert-${alert.keyHash}`,
    `priority-${sanitizeLabel(alert.priority)}`,
    `rule-${sanitizeLabel(alert.ruleId)}`,
    `agent-${sanitizeLabel(alert.agentId || alert.agentName)}`,
    `client-${sanitizeLabel(alert.clientName)}`,
  ];
}

function jiraDescriptionText(alert) {
  const lines = [
    `Cliente: ${alert.clientName}`,
    `Prioridad: ${alert.priority}`,
    `Motivo del ticket: ${alert.triggerReason}`,
    "",
    "Resumen del evento",
    `- Regla Wazuh: ${alert.ruleId} - ${alert.ruleDescription}`,
    `- Nivel Wazuh: ${alert.ruleLevel}`,
    `- Agente afectado: ${alert.agentName} (${alert.agentId || "sin id"})`,
    `- IP del agente: ${alert.agentIp || "N/A"}`,
    `- Manager: ${alert.managerName || "N/A"}`,
    `- Primera vez observada: ${alert.firstSeen || alert.timestamp || "N/A"}`,
    `- Ultima vez observada: ${alert.lastSeen || alert.timestamp || "N/A"}`,
    `- Eventos agrupados en esta ejecucion: ${alert.count}`,
    "",
    "Indicadores relevantes",
    `- IP origen: ${alert.srcip || "N/A"}`,
    `- IP destino: ${alert.dstip || "N/A"}`,
    `- Usuario origen: ${alert.srcuser || "N/A"}`,
    `- Usuario destino: ${alert.dstuser || "N/A"}`,
    `- Ruta FIM: ${alert.syscheckPath || "N/A"}`,
    `- Decoder/programa: ${alert.decoder || "N/A"} / ${alert.programName || "N/A"}`,
    `- Ubicacion de log: ${alert.location || "N/A"}`,
    `- Grupos Wazuh: ${(alert.ruleGroups || []).join(", ") || "N/A"}`,
    `- MITRE: ${[].concat((alert.mitre || {}).id || []).join(", ") || "N/A"}`,
    "",
    "Evidencia Wazuh",
    alert.fullLog || "N/A",
  ];

  if (alert.previousOutput) {
    lines.push("", "Eventos relacionados previos", alert.previousOutput);
  }

  lines.push(
    "",
    "Accion recomendada",
    "- Validar si el evento corresponde a actividad autorizada o a una amenaza real.",
    "- Revisar el activo afectado y la IP/usuario de origen si existen.",
    "- Contener o bloquear el origen si la actividad no esta autorizada.",
    "- Documentar hallazgos y cerrar el ticket solo cuando la alerta este explicada o mitigada."
  );

  return lines.join("\n");
}

function adfDescription(text) {
  const content = String(text || "")
    .split("\n")
    .map((line) => ({
      type: "paragraph",
      content: line ? [{ type: "text", text: line }] : [],
    }));
  return { type: "doc", version: 1, content };
}

async function findExistingJiraIssue(alert) {
  if (!envBool("JIRA_ALERT_DEDUPE", envBool("JIRA_DEDUPE", true))) return null;
  const project = env("JIRA_PROJECT_KEY");
  const labels = jiraLabels(alert);
  const jql = `project = "${project}" AND labels = "${labels[0]}" AND labels = "${labels[1]}" AND statusCategory != Done`;
  try {
    const response = await jiraRequest(`/rest/api/3/search?jql=${encodeURIComponent(jql)}&fields=key&maxResults=1`);
    const issue = ((response.issues || [])[0]) || null;
    if (!issue || !issue.key) return null;
    return { key: issue.key, issueUrl: jiraIssueUrl(issue.key), self: issue.self || "" };
  } catch (error) {
    console.error(`WARN: Jira dedupe check failed for alert ${alert.keyHash}: ${error.message}`);
    return null;
  }
}

async function createJiraAlertTickets(alerts) {
  const enabled = envBool("JIRA_CREATE_ALERT_TICKETS", envBool("JIRA_CREATE_TICKETS", false));
  const maxTickets = envNumber("JIRA_ALERT_MAX_TICKETS", envNumber("JIRA_MAX_TICKETS", 15));
  const priorityMap = parseJsonEnv("JIRA_PRIORITY_MAP_JSON", { P1: "Highest", P2: "High", P3: "Medium", P4: "Low" });
  const results = [];

  for (const alert of alerts.slice(0, maxTickets)) {
    const summary = `[${alert.priority}] Wazuh ${alert.ruleId}: ${alert.ruleDescription} - ${alert.agentName}`;
    if (!enabled) {
      results.push({ keyHash: alert.keyHash, priority: alert.priority, ruleId: alert.ruleId, agentName: alert.agentName, action: "dry-run", summary, issueUrl: "" });
      continue;
    }

    const existingIssue = await findExistingJiraIssue(alert);
    if (existingIssue) {
      results.push({ keyHash: alert.keyHash, priority: alert.priority, ruleId: alert.ruleId, agentName: alert.agentName, action: "skipped-existing", ...existingIssue });
      continue;
    }

    const descriptionText = jiraDescriptionText(alert);
    const description = env("JIRA_DESCRIPTION_FORMAT", "adf").toLowerCase() === "plain"
      ? descriptionText
      : adfDescription(descriptionText);

    const fields = {
      project: { key: env("JIRA_PROJECT_KEY") },
      issuetype: { name: env("JIRA_ISSUE_TYPE", "Task") },
      summary,
      description,
      labels: jiraLabels(alert),
    };

    if (envBool("JIRA_SET_PRIORITY_FIELD", true)) {
      fields.priority = { name: priorityMap[alert.priority] || "Medium" };
    }

    try {
      const response = await jiraRequest("/rest/api/3/issue", { method: "POST", body: { fields } });
      results.push({ keyHash: alert.keyHash, priority: alert.priority, ruleId: alert.ruleId, agentName: alert.agentName, action: "created", key: response.key, self: response.self, issueUrl: jiraIssueUrl(response.key) });
    } catch (error) {
      results.push({ keyHash: alert.keyHash, priority: alert.priority, ruleId: alert.ruleId, agentName: alert.agentName, action: "error", error: error.message, body: error.body || "" });
    }
  }

  return results;
}

function markdownSummary(result) {
  const lines = [
    `# Wazuh Alert Jira Automation - ${result.clientName}`,
    "",
    `Generated at: ${result.generatedAt}`,
    "",
    "## Summary",
    "",
    `- Wazuh index: ${result.wazuhIndex}`,
    `- Lookback minutes: ${result.query.lookbackMinutes}`,
    `- Raw alerts returned: ${result.rawAlertCount}`,
    `- Grouped incidents: ${result.alerts.length}`,
    `- P1: ${result.countsByPriority.P1 || 0}`,
    `- P2: ${result.countsByPriority.P2 || 0}`,
    `- P3: ${result.countsByPriority.P3 || 0}`,
    `- Jira creation enabled: ${result.jiraCreateTickets}`,
    "",
    "## Alerts",
    "",
  ];

  for (const alert of result.alerts) {
    lines.push(`### ${alert.priority} - Rule ${alert.ruleId} - ${alert.agentName}`);
    lines.push("");
    lines.push(`- Description: ${alert.ruleDescription}`);
    lines.push(`- Trigger: ${alert.triggerReason}`);
    lines.push(`- Count: ${alert.count}`);
    lines.push(`- Source IP: ${alert.srcip || "N/A"}`);
    lines.push(`- User: ${alert.srcuser || alert.dstuser || "N/A"}`);
    lines.push(`- Log: ${alert.fullLog || "N/A"}`);
    lines.push("");
  }

  return lines.join("\n");
}

function writeOutputs(result) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  const stamp = new Date().toISOString().replace(/[-:.]/g, "").replace("T", "T").replace("Z", "Z");
  const jsonPath = path.join(OUTPUT_DIR, `alert-jira-triage-${stamp}.json`);
  const mdPath = path.join(OUTPUT_DIR, `alert-jira-triage-${stamp}.md`);
  const latestJson = path.join(OUTPUT_DIR, "alert-jira-triage-latest.json");
  const latestMd = path.join(OUTPUT_DIR, "alert-jira-triage-latest.md");
  result.outputFiles = { jsonPath, mdPath, latestJson, latestMd };
  const json = JSON.stringify(result, null, 2);
  const md = markdownSummary(result);
  fs.writeFileSync(jsonPath, json);
  fs.writeFileSync(mdPath, md);
  fs.writeFileSync(latestJson, json);
  fs.writeFileSync(latestMd, md);
}

async function main() {
  const generatedAt = new Date().toISOString();
  const wazuhResponse = await loadWazuhAlerts();
  const rawAlertCount = (((wazuhResponse || {}).hits || {}).hits || []).length;
  const alerts = normalizeAlerts(wazuhResponse);
  const countsByPriority = alerts.reduce((acc, alert) => {
    acc[alert.priority] = (acc[alert.priority] || 0) + 1;
    return acc;
  }, {});
  const jiraResults = await createJiraAlertTickets(alerts);

  const result = {
    clientName: env("CLIENT_NAME", "Demo PYME"),
    generatedAt,
    wazuhIndex: env("ALERT_WAZUH_INDEX", "wazuh-alerts-*"),
    query: {
      lookbackMinutes: envNumber("ALERT_LOOKBACK_MINUTES", 60),
      priorities: allowedPriorities(),
      includeLevelDerived: envBool("ALERT_INCLUDE_LEVEL_DERIVED", false),
    },
    rawAlertCount,
    countsByPriority,
    jiraCreateTickets: envBool("JIRA_CREATE_ALERT_TICKETS", envBool("JIRA_CREATE_TICKETS", false)),
    jiraResults,
    alerts,
  };

  writeOutputs(result);
  console.log(JSON.stringify(result, null, 2));
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exit(1);
});
