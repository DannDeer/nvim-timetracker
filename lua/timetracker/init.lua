-- lua/timetracker/init.lua
-- full implementation of timetracker

local vim = vim

local json_decode = vim.fn.json_decode
local json_encode = vim.fn.json_encode

local M = {}

-- Default configuration
M.config = {
	auto_start            = false, -- start timer on Neovim startup
	auto_stop             = false, -- stop timer on Neovim exit
	auto_gitignore        = false, -- automatically adds to gitignore
	show_session_on_start = false, -- show current session on startup
	name                  = nil, -- override user identifier
	highlight_groups      = { -- Customizable highlight groups for UI
		Header = { fg = '#61afef', bold = true },
		Total = { fg = '#98c379', italic = true },
		SessionLine = { fg = '#dcdfe4' },
		CurrentTimer = { fg = '#e06c75', bg = '#282c34', bold = true },
	},
}

-- Internal state
local state = {
	current      = nil,
	sessions     = {},
	timer_handle = nil,
	win_id       = nil,
	buf_id       = nil,
	namespace_id = vim.api.nvim_create_namespace('timetracker'),
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
	for k, v in pairs(opts) do
		if M.config[k] ~= nil then
			M.config[k] = v
		end
	end

	-- Define highlight groups
	vim.api.nvim_set_hl(0, 'TimeTrackerHeader', M.config.highlight_groups.Header)
	vim.api.nvim_set_hl(0, 'TimeTrackerTotal', M.config.highlight_groups.Total)
	vim.api.nvim_set_hl(0, 'TimeTrackerSessionLine', M.config.highlight_groups.SessionLine)
	vim.api.nvim_set_hl(0, 'TimeTrackerCurrentTimer', M.config.highlight_groups.CurrentTimer)

	-- user commands
	vim.api.nvim_create_user_command('TimeTrackerStart', M.StartTimer, {})
	vim.api.nvim_create_user_command('TimeTrackerStop', M.StopTimer, {})
	vim.api.nvim_create_user_command('TimeTrackerSessions', M.ShowSessions, {})
	vim.api.nvim_create_user_command('TimeTrackerCurrentSession', M.ShowCurrentSession, {})
	vim.api.nvim_create_user_command('TimeTrackerGitIgnore', M.EnsureGitIgnore, {})

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
	if M.config.auto_gitignore then
		vim.api.nvim_create_autocmd('VimEnter', { callback = M.EnsureGitIgnore })
	end
	if M.config.show_session_on_start then
		vim.api.nvim_create_autocmd('VimEnter', { callback = M.ShowCurrentSession })
	end
end

function M.StartTimer()
	if state.current then
		vim.notify('Timer is already running.', vim.log.levels.WARN)
		return
	end
	local now = os.time()
	state.current = {
		start_time = now,
		user_id    = get_user_id(),
		branch     = get_git_branch(),
	}
	vim.notify(string.format(
		'Timer started at %s (user: %s, branch: %s)',
		os.date('%X', now),
		state.current.user_id,
		state.current.branch or 'none'
	), vim.log.levels.INFO)
end

function M.StopTimer()
	if not state.current then
		vim.notify('No timer is running.', vim.log.levels.WARN)
		return
	end
	local now   = os.time()
	local s     = state.current
	s.stop_time = now
	s.elapsed   = now - s.start_time
	table.insert(state.sessions, s)
	save_sessions(state.sessions)
	state.current = nil
	vim.notify(string.format(
		'Timer stopped. User: %s, Branch: %s, Elapsed: %d seconds (logged to %s)',
		s.user_id, s.branch or 'none', s.elapsed, get_storage_file()
	), vim.log.levels.INFO)
end

function M.ShowSessions()
	local buf = vim.api.nvim_create_buf(false, true)
	local lines = {
		'TimeTracker Sessions',
		'--------------------',
		string.format('%-3s %-19s %-19s %-6s %-10s %s',
			'#', 'Start', 'Stop', 'Mins', 'User', 'Branch')
	}
	local total = 0
	for i, s in ipairs(state.sessions) do
		local starts    = os.date('%Y-%m-%d %H:%M', s.start_time)
		local stops     = os.date('%Y-%m-%d %H:%M', s.stop_time)
		local mins      = s.elapsed / 60
		total           = total + s.elapsed
		lines[#lines + 1] = string.format(
			'%-3d %-19s %-19s %-6.2f %-10s %s',
			i, starts, stops, mins, s.user_id, s.branch or '-'
		)
	end
	table.insert(lines, 2, string.format(
		'Total sessions: %d   Total time: %.2f mins',
		#state.sessions, total / 60
	))
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Apply highlights
	vim.api.nvim_buf_add_highlight(buf, state.namespace_id, 'TimeTrackerHeader', 0, 0, -1)
	vim.api.nvim_buf_add_highlight(buf, state.namespace_id, 'TimeTrackerTotal', 1, 0, -1)
	for i = 3, #lines - 1 do
		vim.api.nvim_buf_add_highlight(buf, state.namespace_id, 'TimeTrackerSessionLine', i, 0, -1)
	end

	local w = math.floor(vim.o.columns * 0.8)
	local h = math.min(math.floor(vim.o.lines * 0.6), #lines + 2)
	local r = math.floor((vim.o.lines - h) / 2)
	local c = math.floor((vim.o.columns - w) / 2)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = 'editor',
		width = w,
		height = h,
		row = r,
		col = c,
		style = 'minimal',
		border = 'rounded',
		title = 'TimeTracker Sessions',
		title_pos = 'center',
	})
	vim.api.nvim_win_set_option(win, 'cursorline', true)
	vim.api.nvim_win_set_option(win, 'number', false)
	vim.api.nvim_win_set_option(win, 'relativenumber', false)
	vim.api.nvim_win_set_option(win, 'signcolumn', 'no')
	vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>bd!<CR>', { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '<cmd>bd!<CR>', { noremap = true, silent = true })
end

function M.ShowCurrentSession()
	-- If there is no active timer
	if not state.current then
		vim.notify("No active timer to display", vim.log.levels.WARN)
		return
	end
	-- If there is already a timer window open
	if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
		vim.api.nvim_win_close(state.win_id, true)
		state.win_id = nil
		if state.timer_handle then
			state.timer_handle:stop()
			state.timer_handle:close()
			state.timer_handle = nil
		end
		return
	end
	local function get_text()
		local elapsed = os.time() - state.current.start_time
		return string.format('⏱️  %02d:%02d:%02d', math.floor(elapsed / 3600), math.floor((elapsed % 3600) / 60), elapsed % 60)
	end
	local text = get_text()
	local w = #text + 4 -- Padding for borders/aesthetics
	local h = 1
	-- Create buffer/window
	state.buf_id = vim.api.nvim_create_buf(false, true)
	local ui = vim.api.nvim_list_uis()[1]
	local row = ui.height - 3
	local col = ui.width - w - 2
	state.win_id = vim.api.nvim_open_win(state.buf_id, false, {
		relative = 'editor',
		width = w,
		height = h,
		row = row,
		col = col,
		style = 'minimal',
		border = 'single',
	})
	vim.api.nvim_win_set_option(state.win_id, 'winhl', 'NormalFloat:TimeTrackerCurrentTimer')
	-- Update function for the timer window
	local function update()
		if not state.current or not vim.api.nvim_win_is_valid(state.win_id) then return end
		local new_text = get_text()
		vim.api.nvim_buf_set_lines(state.buf_id, 0, -1, false, { new_text })
		local new_width = #new_text + 4
		vim.api.nvim_win_set_config(state.win_id, { relative = 'editor', width = new_width, row = row, col = ui.width - new_width - 2 })
	end
	-- Initial update
	update()
	state.timer_handle = vim.loop.new_timer()
	state.timer_handle:start(1000, 1000, vim.schedule_wrap(update))
end

function M.EnsureGitIgnore()
	local git_dir = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
	if vim.v.shell_error ~= 0 or not git_dir or git_dir == '' then
		return -- Not a git dir
	end
	local root = git_dir
	local gitignore_path = root .. '/.gitignore'
	local tracking_entry = '.timetracker_sessions.json'
	if vim.fn.filereadable(gitignore_path) == 0 then
		-- Create .gitignore with entry
		vim.fn.writefile({ tracking_entry }, gitignore_path)
	else
		-- Read existing lines
		local lines = vim.fn.readfile(gitignore_path)
		local has_entry = false
		for _, line in ipairs(lines) do
			local trimmed = line:gsub("^%s*(.-)%s*$", "%1")
			if trimmed == tracking_entry then
				has_entry = true
				break
			end
		end
		if not has_entry then
			-- Add entry to the file
			table.insert(lines, tracking_entry)
			vim.fn.writefile(lines, gitignore_path)
		end
	end
end

return M
