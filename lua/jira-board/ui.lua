local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local previewers = require("telescope.previewers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local entry_display = require("telescope.pickers.entry_display")

local function detect_jira_command()
  local cwd = vim.fn.getcwd()
  local config = require("jira-board").config

  local matched_command = nil
  local longest_match_len = 0

  for path_pattern, command in pairs(config.path_commands) do
    local expanded_pattern = vim.fn.expand(path_pattern)
    if cwd:match("^" .. expanded_pattern) then
      if #expanded_pattern > longest_match_len then
        matched_command = command
        longest_match_len = #expanded_pattern
      end
    end
  end

  if matched_command then
    return matched_command
  end

  if config.require_path_match then
    return nil
  end

  return config.jira_command
end

local function build_jira_command(jira_cmd, filters)
  local cmd_parts = { jira_cmd, "issue list" }
  local jql_parts = {}

  if filters.sprint then
    if filters.sprint == "current" or filters.sprint == true then
      table.insert(jql_parts, "sprint in openSprints()")
    else
      table.insert(jql_parts, string.format("sprint = \\\"'%s'\\\"", filters.sprint))
    end
  end

  if filters.assignee then
    table.insert(cmd_parts, string.format("-a\"%s\"", filters.assignee))
  end

  if filters.status then
    if type(filters.status) == "table" then
      for _, status in ipairs(filters.status) do
        table.insert(cmd_parts, string.format("-s\"%s\"", status))
      end
    else
      table.insert(cmd_parts, string.format("-s\"%s\"", filters.status))
    end
  end

  if filters.label then
    if type(filters.label) == "table" then
      for _, label in ipairs(filters.label) do
        table.insert(cmd_parts, string.format("-l\"%s\"", label))
      end
    else
      table.insert(cmd_parts, string.format("-l\"%s\"", filters.label))
    end
  end

  if #jql_parts > 0 then
    local jql = table.concat(jql_parts, " AND ")
    table.insert(cmd_parts, string.format("-q\"%s\"", jql))
  end

  table.insert(cmd_parts, "--raw")

  return table.concat(cmd_parts, " ")
end

local function fetch_jira_issues(filters)
  filters = filters or {}
  local jira_cmd = detect_jira_command()

  if not jira_cmd then
    vim.notify("Not in a Jira organization", vim.log.levels.WARN)
    return nil
  end

  local jira_command = build_jira_command(jira_cmd, filters)
  local cmd = string.format("bash -i -c '%s' 2>/dev/null", jira_command)

  local handle = io.popen(cmd)
  if not handle then
    vim.notify("Failed to run jira command", vim.log.levels.ERROR)
    return nil
  end

  local result = handle:read("*a")
  handle:close()

  local ok, issues = pcall(vim.fn.json_decode, result)
  if not ok or not issues then
    vim.notify("Failed to parse jira output", vim.log.levels.ERROR)
    return nil
  end

  return issues
end

local function wrap_text(text, width)
  width = width or 80
  local lines = {}

  for line in text:gmatch("[^\n]+") do
    if #line <= width then
      table.insert(lines, line)
    else
      local current_line = ""
      for word in line:gmatch("%S+") do
        if #current_line + #word + 1 <= width then
          current_line = current_line == "" and word or current_line .. " " .. word
        else
          if current_line ~= "" then
            table.insert(lines, current_line)
          end
          current_line = word
        end
      end
      if current_line ~= "" then
        table.insert(lines, current_line)
      end
    end
  end

  return lines
end

local function parse_adf_text(content, indent)
  indent = indent or 0
  if not content then
    return ""
  end

  local text = ""
  local prefix = string.rep("  ", indent)

  if type(content) == "table" then
    for _, node in ipairs(content) do
      if node.type == "text" then
        local txt = node.text or ""
        if node.marks then
          for _, mark in ipairs(node.marks) do
            if mark.type == "strong" then
              txt = "**" .. txt .. "**"
            elseif mark.type == "em" then
              txt = "_" .. txt .. "_"
            elseif mark.type == "code" then
              txt = "`" .. txt .. "`"
            end
          end
        end
        text = text .. txt
      elseif node.type == "hardBreak" then
        text = text .. "\n" .. prefix
      elseif node.type == "paragraph" and node.content then
        text = text .. prefix .. parse_adf_text(node.content, indent) .. "\n"
      elseif node.type == "heading" and node.content then
        local level = node.attrs and node.attrs.level or 1
        text = text .. "\n" .. prefix .. string.rep("#", level) .. " " .. parse_adf_text(node.content, indent) .. "\n"
      elseif node.type == "bulletList" and node.content then
        for _, item in ipairs(node.content) do
          if item.content then
            text = text .. prefix .. "• " .. parse_adf_text(item.content, indent + 1)
          end
        end
      elseif node.type == "orderedList" and node.content then
        for i, item in ipairs(node.content) do
          if item.content then
            text = text .. prefix .. i .. ". " .. parse_adf_text(item.content, indent + 1)
          end
        end
      elseif node.type == "listItem" and node.content then
        text = text .. parse_adf_text(node.content, indent)
      elseif node.type == "codeBlock" and node.content then
        text = text .. "\n```\n" .. parse_adf_text(node.content, indent) .. "\n```\n"
      elseif node.content then
        text = text .. parse_adf_text(node.content, indent)
      end
    end
  end
  return text
end

local function get_type_config(issue_type)
  local config = require("jira-board").config
  return config.type_configs[issue_type] or { icon = "", fg = "#94a3b8", bg = "#1e293b" }
end

local function get_priority_config(priority)
  local config = require("jira-board").config
  return config.priority_configs[priority] or { icon = "", fg = "#94a3b8", label = priority or "NONE" }
end

local function get_status_config(status)
  local config = require("jira-board").config
  return config.status_configs[status] or { icon = "", fg = "#94a3b8" }
end

local function format_description(issue)
  if not issue then
    return "No data"
  end

  local lines = {}
  local highlights = {}

  local type_config = get_type_config(issue.issue_type)
  local header = string.format(" %s %s ", type_config.icon, issue.issue_type:upper())
  table.insert(lines, header .. "  " .. issue.key)
  table.insert(highlights, { line = 0, col_start = 0, col_end = #header, hl_group = "JiraBoardTypeBadge" })
  table.insert(highlights, { line = 0, col_start = #header + 2, col_end = -1, hl_group = "JiraBoardKey" })

  table.insert(lines, "")

  local wrapped_title = wrap_text(issue.summary, 78)
  for _, title_line in ipairs(wrapped_title) do
    table.insert(lines, "  " .. title_line)
    table.insert(highlights, { line = #lines - 1, col_start = 0, col_end = -1, hl_group = "JiraBoardTitle" })
  end

  table.insert(lines, "")

  local priority_config = get_priority_config(issue.priority)
  local status_config = get_status_config(issue.status)

  local priority_line = string.format("%s  %s", priority_config.icon, priority_config.label)
  table.insert(lines, priority_line)
  table.insert(highlights, {
    line = #lines - 1,
    col_start = 0,
    col_end = -1,
    hl_group = "JiraBoardPriority" .. (issue.priority or "None"),
  })

  local assignee_line = string.format("  %s", issue.assignee)
  table.insert(lines, assignee_line)
  table.insert(highlights, { line = #lines - 1, col_start = 0, col_end = -1, hl_group = "JiraBoardAssignee" })

  local status_line = string.format("%s  %s", status_config.icon, issue.status)
  table.insert(lines, status_line)
  table.insert(highlights, {
    line = #lines - 1,
    col_start = 0,
    col_end = -1,
    hl_group = "JiraBoardStatus" .. (issue.status:gsub(" ", "") or "Unknown"),
  })

  if issue.labels and #issue.labels > 0 then
    table.insert(lines, "")
    local labels_line = ""
    for i, label in ipairs(issue.labels) do
      labels_line = labels_line .. string.format("  %s  ", label)
      if i < #issue.labels then
        labels_line = labels_line .. "   "
      end
    end
    table.insert(lines, labels_line)
    table.insert(highlights, { line = #lines - 1, col_start = 0, col_end = -1, hl_group = "JiraBoardLabels" })
  end

  table.insert(lines, "")
  table.insert(lines, "────────────────────────────────────────────────────────────────")

  local desc_text = issue.description_text or "_No description provided_"
  if desc_text ~= "" then
    table.insert(lines, "")
    for line in desc_text:gmatch("[^\n]+") do
      local wrapped = wrap_text(line, 78)
      for _, wrapped_line in ipairs(wrapped) do
        table.insert(lines, "  " .. wrapped_line)
      end
    end
  end

  return lines, highlights
end

local function setup_highlights()
  local config = require("jira-board").config

  vim.api.nvim_set_hl(0, "JiraBoardKey", { fg = "#38bdf8", bold = true })
  vim.api.nvim_set_hl(0, "JiraBoardTitle", { fg = "#f8fafc", bold = true })
  vim.api.nvim_set_hl(0, "JiraBoardLabels", { fg = "#cbd5e1", bg = "#334155", italic = true })
  vim.api.nvim_set_hl(0, "JiraBoardAssignee", { fg = "#c084fc", italic = true })

  for type_name, type_config in pairs(config.type_configs) do
    local hl_name = "JiraBoardType" .. type_name:gsub("[^%w]", "")
    vim.api.nvim_set_hl(0, hl_name, { fg = type_config.fg, bold = true })
  end

  for priority, priority_config in pairs(config.priority_configs) do
    vim.api.nvim_set_hl(0, "JiraBoardPriority" .. priority, { fg = priority_config.fg, bold = true })
  end

  for status, status_config in pairs(config.status_configs) do
    local hl_name = "JiraBoardStatus" .. status:gsub(" ", "")
    vim.api.nvim_set_hl(0, hl_name, { fg = status_config.fg, bold = true })
  end
end

local function create_previewer()
  setup_highlights()

  return previewers.new_buffer_previewer({
    title = "Details",
    define_preview = function(self, entry)
      local lines, highlights = format_description(entry.value)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

      local type_config = get_type_config(entry.value.issue_type or "Task")
      vim.api.nvim_set_hl(0, "JiraBoardTypeBadge", { fg = type_config.fg, bg = type_config.bg, bold = true })

      for _, hl in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(
          self.state.bufnr,
          -1,
          hl.hl_group,
          hl.line,
          hl.col_start,
          hl.col_end
        )
      end

      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(self.state.bufnr) then
          vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
        end
      end)
    end,
  })
end

function M.open(filters)
  filters = filters or {}
  local jira_cmd = detect_jira_command()
  if not jira_cmd then
    return
  end

  local loading_entry = {
    key = "...",
    summary = "Loading issues...",
    description = "Fetching data from Jira...",
  }

  local results = { loading_entry }
  local current_picker = nil

  local function make_entry(issue)
    local key, summary, description, issue_type, labels, priority, assignee, status

    if issue.fields then
      key = issue.key or "UNKNOWN"
      summary = issue.fields.summary or "No summary"
      issue_type = issue.fields.issueType and issue.fields.issueType.name or "Task"
      labels = issue.fields.labels or {}
      priority = issue.fields.priority and issue.fields.priority.name or "None"
      assignee = issue.fields.assignee and issue.fields.assignee.displayName or "Unassigned"
      status = issue.fields.status and issue.fields.status.name or "Unknown"

      local desc_text = ""
      if issue.fields.description and type(issue.fields.description) == "table" then
        if issue.fields.description.content then
          desc_text = parse_adf_text(issue.fields.description.content)
        else
          desc_text = vim.inspect(issue.fields.description)
        end
      elseif issue.fields.description then
        desc_text = tostring(issue.fields.description)
      end

      description = desc_text
    else
      key = issue.key or "UNKNOWN"
      summary = issue.summary or "No summary"
      description = issue.description or ""
      issue_type = "Task"
      labels = {}
      priority = "None"
      assignee = "Unassigned"
      status = "Unknown"
    end

    local labels_str = table.concat(labels, " ")
    local search_text = string.format("%s %s %s %s", key, summary, assignee, labels_str)

    local displayer = entry_display.create({
      separator = " │ ",
      items = {
        { width = 12 },
        { width = 10 },
        { remaining = true },
      },
    })

    return {
      value = {
        key = key,
        summary = summary,
        description_text = description,
        issue_type = issue_type,
        labels = labels,
        priority = priority,
        assignee = assignee,
        status = status,
        jira_cmd = jira_cmd,
      },
      display = function(entry)
        local type_config = get_type_config(entry.value.issue_type)
        local type_display = string.format("%s %s", type_config.icon, entry.value.issue_type)

        return displayer({
          { entry.value.key, "JiraBoardKey" },
          { type_display, "JiraBoardType" .. entry.value.issue_type:gsub("[^%w]", "") },
          entry.value.summary,
        })
      end,
      ordinal = search_text,
    }
  end

  local opts = {
    prompt_title = "Jira Board",
    results_title = "Issues",
    layout_strategy = "horizontal",
    layout_config = {
      horizontal = {
        width = 0.9,
        height = 0.9,
        preview_width = 0.5,
        preview_cutoff = 0,
      },
    },
    sorting_strategy = "ascending",
    finder = finders.new_table({
      results = results,
      entry_maker = make_entry,
    }),
    sorter = conf.generic_sorter({}),
    previewer = create_previewer(),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if not selection or selection.value.key == "..." then
          return
        end
        actions.close(prompt_bufnr)
        local key = selection.value.key

        local cmd = string.format("bash -i -c '%s open %s' 2>&1 >/dev/null &", jira_cmd, key)
        vim.fn.jobstart(cmd, { detach = true })

        vim.notify(string.format("Opening %s in browser...", key), vim.log.levels.INFO)
      end)
      return true
    end,
  }

  local title_parts = { "Jira Board" }
  if filters.sprint then
    local sprint_str = (filters.sprint == "current" or filters.sprint == true) and "Current Sprint" or ("sprint:" .. filters.sprint)
    table.insert(title_parts, sprint_str)
  end
  if filters.assignee then
    table.insert(title_parts, "assignee:" .. filters.assignee)
  end
  if filters.status then
    local status_str = type(filters.status) == "table" and table.concat(filters.status, ",") or filters.status
    table.insert(title_parts, "status:" .. status_str)
  end
  if filters.label then
    local label_str = type(filters.label) == "table" and table.concat(filters.label, ",") or filters.label
    table.insert(title_parts, "label:" .. label_str)
  end
  opts.prompt_title = table.concat(title_parts, " | ")

  current_picker = pickers.new(opts)
  current_picker:find()

  local jira_command = build_jira_command(jira_cmd, filters)
  vim.notify("Running: " .. jira_command, vim.log.levels.DEBUG)
  vim.fn.jobstart(string.format("bash -i -c '%s'", jira_command), {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if not data then
        return
      end
      local result = table.concat(data, "\n")
      local ok, issues = pcall(vim.fn.json_decode, result)
      if ok and issues and #issues > 0 then
        vim.schedule(function()
          if current_picker then
            current_picker:refresh(finders.new_table({
              results = issues,
              entry_maker = make_entry,
            }), { reset_prompt = false })
          end
        end)
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 then
        vim.schedule(function()
          vim.notify("Jira error: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
        end)
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.schedule(function()
          vim.notify("Failed to fetch Jira issues (exit code: " .. code .. ")", vim.log.levels.ERROR)
        end)
      end
    end,
  })
end

return M
