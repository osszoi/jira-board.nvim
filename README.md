# jira-board-nvim

A beautiful Neovim plugin for browsing and managing Jira issues with a Telescope-powered interface.

![Jira Board](https://img.shields.io/badge/Neovim-0.9+-green.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

## ✨ Features

- 🎨 **Beautiful UI** - Inspired by gh.nvim with colored badges, icons, and markdown rendering
- 🔍 **Smart Search** - Search by ticket ID, title, assignee, or labels
- 🎯 **Flexible Filters** - Filter by status, assignee, labels, and sprints
- 🚀 **Async Loading** - Non-blocking issue fetching with loading indicators
- 🌐 **Multi-Org Support** - Configure different jira commands per directory path
- 📝 **Rich Previews** - Markdown-rendered descriptions with syntax highlighting
- ⚡ **Fast Navigation** - Powered by Telescope for lightning-fast browsing
- 🏃 **Sprint Filtering** - Automatically filters to active sprints by default

## 📋 Requirements

- Neovim >= 0.9.0
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [jira-cli](https://github.com/ankitpokhrel/jira-cli)
- (Optional) [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) for better description rendering

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yourusername/jira-board-nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("jira-board").setup({
      onlyActiveSprints = true, -- filter to current sprint by default
      jira_command = "jira", -- default jira-cli command
      path_commands = {}, -- path-based command mapping
      require_path_match = false, -- allow fallback to jira_command when no path matches
    })
  end,
}
```

### Local Development

For testing locally before pushing to GitHub:

```lua
{
  "jira-board-nvim",
  dir = "~/Work/personal/jira-board-nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("jira-board").setup({
      onlyActiveSprints = true, -- filter to current sprint by default
      jira_command = "jira", -- default jira-cli command
      path_commands = {}, -- path-based command mapping
      require_path_match = false, -- allow fallback to jira_command when no path matches
    })
  end,
}
```

## 🚀 Usage

### Basic Usage

Open the Jira board for the current project:

```vim
:JiraBoard
```

The plugin will use the configured jira command based on your current directory path. By default, it uses the `jira` command.

### Filtering

Filter issues by various criteria:

```vim
" Filter by assignee
:JiraBoard assignee=eduardo@example.com

" Filter by status
:JiraBoard status="To Do"

" Filter by label
:JiraBoard label=UI

" Filter by sprint (current/active sprints)
:JiraBoard sprint=current
" Or simply
:JiraBoard sprint

" Filter by specific sprint name
:JiraBoard sprint="Sprint 42"

" Disable sprint filter (show all issues)
:JiraBoard sprint=false

" Multiple statuses (comma-separated)
:JiraBoard status="To Do,In Progress"

" Combine filters
:JiraBoard assignee=eduardo@example.com status="In Progress" label=Backend sprint=current
```

### From Lua (Dashboard Integration)

Perfect for adding to your Snacks dashboard or custom keymaps:

```lua
-- Single filter
require("jira-board").open({ assignee = "eduardo@example.com" })

-- Multiple filters
require("jira-board").open({
  assignee = "eduardo@example.com",
  status = { "To Do", "In Progress" },
  label = "UI"
})

-- Current sprint only
require("jira-board").open({ sprint = "current" })

-- Disable sprint filter (show all issues)
require("jira-board").open({ sprint = false })

-- Status filter only (uses default sprint filter from config)
require("jira-board").open({ status = "Done" })
```

### Dashboard Example

Add to your Snacks dashboard in `plugins.lua`:

```lua
{
  icon = " ",
  title = "My Jira Tasks",
  key = "j",
  action = function()
    require("jira-board").open({
      assignee = "your.email@company.com",
      status = { "To Do", "In Progress" }
    })
  end,
}
```

## ⌨️ Keymaps

Inside the Jira Board (standard Telescope keymaps):

| Key | Action |
|-----|--------|
| `<CR>` / `Enter` | Open selected issue in browser |
| `<C-n>` / `<Down>` | Move to next issue |
| `<C-p>` / `<Up>` | Move to previous issue |
| `<Esc>` / `<C-c>` | Close the window |
| Type to search | Filter by ticket, title, assignee, or labels |

## 🎨 Visual Elements

### Issue Type Badges

Issues are color-coded by type:
- 🐛 **Bug** - Red
- 📖 **Story** - Green
- ✓ **Task** - Blue
- 🎯 **Epic** - Purple
- 📌 **Sub-task** - Gray

### Priority Indicators

- 🔴 **Critical/Highest** - Red
- 🟠 **High** - Orange
- 🟡 **Medium** - Yellow
- 🔵 **Low** - Blue
- ⚪ **Lowest** - Gray

### Status Icons

- ⭕ **Open, To Do** - Gray
- 🔄 **In Progress** - Blue
- 👁️ **In Review, Code Review** - Dark Blue
- ✅ **Done, Deployed, Approved** - Green

## 🔧 Configuration

The plugin works out of the box with sensible defaults, but you can customize it:

```lua
require("jira-board").setup({
  onlyActiveSprints = true, -- filter to current sprint by default
  jira_command = "jira", -- default jira-cli command
  path_commands = { -- path-based command mapping
    ["~/Work/company-a"] = "jira-company-a",
    ["~/Work/company-b"] = "jira-company-b",
  },
  require_path_match = false, -- allow fallback to jira_command when no path matches
})
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `onlyActiveSprints` | boolean | `true` | When `true`, automatically filters issues to current/active sprints. Set to `false` to show all issues regardless of sprint. Can be overridden per command with `sprint` filter. |
| `jira_command` | string | `"jira"` | Default jira-cli command to use. This is used when no path pattern matches or when `require_path_match` is `false`. |
| `path_commands` | table | `{}` | Map of directory path patterns to jira commands. Supports pattern matching and tilde expansion. When multiple patterns match, the longest match wins. |
| `require_path_match` | boolean | `false` | When `true`, only run jira commands when current directory matches a pattern in `path_commands`. When `false`, falls back to `jira_command` if no pattern matches. |

**Note:** When `onlyActiveSprints` is `true`, all calls to `:JiraBoard` will automatically include `sprint=current` unless you explicitly pass `sprint=false`.

### Path-Based Command Configuration

The `path_commands` option allows you to use different jira-cli configurations based on your current directory:

```lua
path_commands = {
  ["~/Work/company-a"] = "jira-company-a",
  ["~/Work/company-b"] = "jira-company-b",
  ["~/personal/.*"] = "jira-personal",
}
```

When you run `:JiraBoard` from `~/Work/company-a/project`, it will use `jira-company-a`. From `~/personal/my-project`, it will use `jira-personal`. If no pattern matches and `require_path_match` is `false`, it falls back to the global `jira_command`.

## 🎯 Search Functionality

The search/filter input searches across:
- **Ticket ID** (e.g., DS20-1234)
- **Title/Summary**
- **Assignee name**
- **Labels**

Simply start typing to filter issues in real-time!

## 🛠️ Jira CLI Setup

This plugin requires [jira-cli](https://github.com/ankitpokhrel/jira-cli).

### Single Organization

If you only work with one Jira instance, the default `jira` command is all you need. Just configure jira-cli normally.

### Multiple Organizations

For multiple Jira instances, create shell aliases with different config files:

Example `.bashrc` or `.zshrc`:

```bash
alias jira-company-a='jira --config ~/.jira-company-a.yml'
alias jira-company-b='jira --config ~/.jira-company-b.yml'
alias jira-personal='jira --config ~/.jira-personal.yml'
```

Each config file should contain your Jira instance details and authentication. Then configure the plugin to use these aliases based on directory paths (see Configuration section).

## 🤝 Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## 📝 License

MIT

## 🙏 Acknowledgments

- Inspired by [gh.nvim](https://github.com/ldelossa/gh.nvim) UI design
- Powered by [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- Uses [jira-cli](https://github.com/ankitpokhrel/jira-cli) for Jira integration
