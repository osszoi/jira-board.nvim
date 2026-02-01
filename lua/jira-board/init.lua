local M = {}

M.config = {
  onlyActiveSprints = true,
  jira_command = "jira",
  path_commands = {},
  require_path_match = false,
  type_configs = {
    Bug = { icon = "", fg = "#f87171", bg = "#450a0a" },
    Story = { icon = "", fg = "#4ade80", bg = "#052e16" },
    Task = { icon = "", fg = "#60a5fa", bg = "#172554" },
    Epic = { icon = "", fg = "#c084fc", bg = "#2e1065" },
    ["Sub-task"] = { icon = "", fg = "#94a3b8", bg = "#1e293b" },
  },
  priority_configs = {
    Highest = { icon = "󰀪", fg = "#dc2626", label = "CRITICAL" },
    Critical = { icon = "󰀪", fg = "#dc2626", label = "CRITICAL" },
    High = { icon = "", fg = "#ef4444", label = "HIGH" },
    Medium = { icon = "", fg = "#eab308", label = "MEDIUM" },
    Low = { icon = "", fg = "#60a5fa", label = "LOW" },
    Lowest = { icon = "", fg = "#94a3b8", label = "LOWEST" },
  },
  status_configs = {
    Open = { icon = "", fg = "#94a3b8" },
    ["To Do"] = { icon = "", fg = "#94a3b8" },
    ["In Progress"] = { icon = "", fg = "#60a5fa" },
    ["In Review"] = { icon = "", fg = "#3b82f6" },
    ["Code Review"] = { icon = "", fg = "#3b82f6" },
    ["Ready in dev"] = { icon = "", fg = "#22c55e" },
    Done = { icon = "", fg = "#22c55e" },
    Approved = { icon = "", fg = "#22c55e" },
    Deployed = { icon = "", fg = "#22c55e" },
    Closed = { icon = "", fg = "#22c55e" },
  },
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M.open(filters)
  filters = filters or {}

  if filters.sprint == nil and M.config.onlyActiveSprints then
    filters.sprint = "current"
  end

  require("jira-board.ui").open(filters)
end

return M
