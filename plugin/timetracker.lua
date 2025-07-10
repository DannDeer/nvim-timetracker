-- plugin/timetracker.lua
-- loader stub (this runs *after* your user’s init.lua)

-- lazy.nvim (or other manager) will inject `opts` here.
-- If you’re not using lazy, you can hardcode your options.
local opts = {
  auto_start = false,
  auto_stop  = false,
  auto_gitignore = false,
  show_session_on_start = false,
  name       = nil,
}

require('timetracker').setup(opts)

