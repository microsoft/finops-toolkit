(() => {
  const config = __LOCAL_REPORT_CONFIG__;
  const allowedTools = new Set(config.allowedTools);
  const toolName = "system-mcp-kusto_kusto_query";
  const endpoint = "/api/kusto/query";
  const storageKey = "finops-hub-live-report-state";
  const calls = [];

  window.__sreagentLocal = { calls, endpoint, toolName, report: config.report, allowedTools: [...allowedTools] };
  window.sreagent = {
    async callTool(name, args) {
      const call = {
        name,
        startedAt: new Date().toISOString(),
      };

      try {
        if (!allowedTools.has(name)) {
          throw new Error(`Tool is not approved for report ${config.report}: ${name}`);
        }
        const response = await fetch(endpoint, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ report: config.report, name, args }),
        });
        const payload = await response.json();

        if (!response.ok) {
          throw new Error(
            payload && payload.error
              ? payload.error
              : `Local report bridge failed with HTTP ${response.status}.`,
          );
        }

        calls.push({
          ...call,
          completedAt: new Date().toISOString(),
          ok: true,
          responseType: payload.$type,
        });
        return payload;
      } catch (error) {
        calls.push({
          ...call,
          completedAt: new Date().toISOString(),
          error: error instanceof Error ? error.message : String(error),
          ok: false,
        });
        throw error;
      }
    },

    getState() {
      try {
        return JSON.parse(localStorage.getItem(storageKey) || "{}");
      } catch {
        return {};
      }
    },

    setState(state) {
      localStorage.setItem(storageKey, JSON.stringify(state || {}));
    },
  };
})();
