-- lua/timetracker/init.lua
-- full implementation of timetracker

local vim = vim

-- Native JSON API
local json_decode = vim.fn.json_decode
local json_encode = vim.fn.json_encode

local M = {}

-- Default configuration
M.config = {
  auto_start = false,   -- start timer on Neovim startup
  auto_stop  = false,   -- stop timer on Neovim exit
  name       = nil,     -- override user identifier
}

-- Internal state
local state = {
  current  = nil,
  sessions = {},
}

-- Helpers

local function get_project_root()
  local cwd     = vim.fn.getcwd()
  local git_dir = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  if vim.v.shell_error == 0 and git_dir and git_dir ~= '' then
    return git_dir
  end
  return cwd
end

local function get_storage_file()
  return get_project_root() .. '/.timetracker_sessions.json'
end

local function load_sessions()
  local path = get_storage_file()
  if vim.fn.filereadable(path) == 1 then
    local data = vim.fn.readfile(path)
    local ok, tbl = pcall(json_decode, table.concat(data, '\n'))
    if ok and type(tbl) == 'table' then
      return tbl
    end
  end
  return {}
end

local function save_sessions(sessions)
  local path = get_storage_file()
  local txt  = json_encode(sessions)
  vim.fn.writefile(vim.fn.split(txt, '\n'), path)
end

local function get_user_id()
  return M.config.name
     or os.getenv('USER')
     or vim.loop.os_get_passwd().username
     or 'unknown'
end

local function get_git_branch()
  local res = vim.fn.systemlist('git rev-parse --abbrev-ref HEAD')
  if vim.v.shell_error == 0 and res[1] then
    return res[1]
  end
  return nil
end

-- Bootstrap
state.sessions = load_sessions()

-- Public API

function M.setup(opts)
  opts = opts or {}
  for k,v in pairs(opts) do
    if M.config[k] ~= nil then
      M.config[k] = v
    end
  end

  -- user commands
  vim.api.nvim_create_user_command('StartTimer',  M.StartTimer,  {})
  vim.api.nvim_create_user_command('StopTimer',   M.StopTimer,   {})
  vim.api.nvim_create_user_command('ShowSessions',M.ShowSessions,{})

  -- auto‐start/stop
  if M.config.auto_start then
    vim.api.nvim_create_autocmd('VimEnter', { callback = M.StartTimer })
  end
  if M.config.auto_stop then
    vim.api.nvim_create_autocmd('VimLeavePre', {
      callback = function()
        if state.current then M.StopTimer() end
      end
    })
  end
end

function M.StartTimer()
  if state.current then
    print('Timer is already running.')
    return
  end
  local now = os.time()
  state.current = {
    start_time = now,
    user_id    = get_user_id(),
    branch     = get_git_branch(),
  }
  print(string.format(
    'Timer started at %s (user: %s, branch: %s)',
    os.date('%X', now),
    state.current.user_id,
    state.current.branch or 'none'
  ))
end

function M.StopTimer()
  if not state.current then
    print('No timer is running.')
    return
  end
  local now = os.time()
  local s   = state.current
  s.stop_time = now
  s.elapsed   = now - s.start_time
  table.insert(state.sessions, s)
  save_sessions(state.sessions)
  state.current = nil
  print(string.format(
    'Timer stopped. User: %s, Branch: %s, Elapsed: %d seconds (logged to %s)',
    s.user_id, s.branch or 'none', s.elapsed, get_storage_file()
  ))
end

function M.ShowSessions()
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = {
    string.format('%-3s %-19s %-19s %-6s %-10s %s',
      '#', 'Start', 'Stop', 'Mins', 'User', 'Branch')
  }
  local total = 0
  for i,s in ipairs(state.sessions) do
    local starts = os.date('%Y-%m-%d %H:%M', s.start_time)
    local stops  = os.date('%Y-%m-%d %H:%M', s.stop_time)
    local mins   = s.elapsed / 60
    total = total + s.elapsed
    lines[#lines+1] = string.format(
      '%-3d %-19s %-19s %-6.2f %-10s %s',
      i, starts, stops, mins, s.user_id, s.branch or '-'
    )
  end
  lines[#lines+1] = ''
  lines[#lines+1] = string.format(
    'Total sessions: %d   Total time: %.2f mins',
    #state.sessions, total/60
  )
  vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)

  local w = math.floor(vim.o.columns * 0.8)
  local h = math.floor(vim.o.lines   * 0.6)
  local r = math.floor((vim.o.lines - h) / 2)
  local c = math.floor((vim.o.columns - w) / 2)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor', width = w, height = h,
    row=r, col=c, style='minimal', border='rounded'
  })
  vim.api.nvim_win_set_option(win,'cursorline',true)
  vim.api.nvim_buf_set_keymap(buf,'n','q','<cmd>bd!<CR>',{noremap=true,silent=true})
  vim.api.nvim_buf_set_keymap(buf,'n','<Esc>','<cmd>bd!<CR>',{noremap=true,silent=true})
end

return M

