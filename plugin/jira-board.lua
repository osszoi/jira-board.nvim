if vim.g.loaded_jira_board then
  return
end
vim.g.loaded_jira_board = true

local function parse_args(args)
  local filters = {}
  local parts = vim.split(args, " ", { trimempty = true })

  for _, part in ipairs(parts) do
    local key, value = part:match("^(%w+)=(.+)$")
    if key and value then
      value = value:gsub("^['\"]", ""):gsub("['\"]$", "")

      if value:find(",") then
        filters[key] = vim.split(value, ",", { trimempty = true })
      else
        filters[key] = value
      end
    elseif part:match("^%w+$") then
      filters[part] = true
    end
  end

  return filters
end

vim.api.nvim_create_user_command("JiraBoard", function(opts)
  local filters = parse_args(opts.args)
  require("jira-board").open(filters)
end, { nargs = "*" })
