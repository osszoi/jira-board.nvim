local M = {}

M.config = {
  onlyActiveSprints = true,
  jira_command = "jira",
  path_commands = {},
  require_path_match = false,
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
