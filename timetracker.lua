-- plugin/timetracker.lua
-- A simple neovim plugin to track time spent on projects
-- Usage:
-- 	:StartTimer -- begin tracking time
-- 	:StopTimer  -- stop tracking time

local vim = vim
local json = vim.fn.json_encode and vim.fn or require("vim.json")

local M = {}

M.config = {
	auto_start = false,
	auto_stop = false,
	name = nil
}

function M.setup(opts)
	opts = opts or {}
	for k, v in pairs(opts) do
		if M.config[k] ~= nil then
			M.config[k] = v
		end
	end
	-- Register commands based on config
	if M.config.auto_start then
		vim.api.nvim_create_autocmd("VimEnter", {callback = M.startTimer })
	end
	if M.config.auto_stop then
		vim.api.nvim_create_autocmd("VimLeavePre", { callback = function()
			if state.current then M.StopTimer() end
		end })
	end
end

-- Get the project root
local function get_project_root()
	local cwd = vim.fn.getcwd()
	-- try getting the git root if available
	local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
	if vim.v.shell_error == 0 and git_root and git_root ~= "" then
		return git_root
	else
		return cwd
	end
end

-- Get storage file
local function get_storage_file()
	local root = get_project_root()
	return root .. "/.timetracker_sessions.json"
end

-- Load existing sessions from file
local function load_sessions()
	local path = get_storage_file()
	if vim.fn.filereadable(path) == 1 then
		local data = vim.fn.readfile(path)
		local text = table.concat(data, "\n")
		local ok, tbl = pcall(vim.fn.json_decode, text)
		if ok and type(tbl) == "table" then
			return tbl
		end
	end
	return {}
end

-- Save sessions to file
local function save_sessions(sessions)
	if M.config.name then
		return M.config.name
	end
	local path = get_storage_file()
	local json_text = vim.fn.json_encode(sessions)
	vim.fn.writefile(vim.fn.split(json_text, "\n"), path)
end

-- Helper function to get the user id
local function get_user_id()
	return os.getenv("USER") or vim.loop.os_get_passwd().username or "unknown"
end

-- Helper function to get current git branch
local function get_git_branch()
	local cwd = vim.fn.getcwd()
	if vim.fn.isdirectory(cwd .. "/.git") == 1 or vim.fn.systemlist("git rev-parse --git-dir", cwd)[1] ~= nil then
		local result = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")
		if vim.v.shell_error == 0 and result[1] then
			return result[1]
		end
	end
	return nil
end

local state = {
	current = nil,
	sessions = load_sessions()
}

function M.StartTimer()
	if state.current then
		print("Timer is already running")
	else
		local start_time = os.time()
		local user_id = get_user_id()
		local branch = get_git_branch()
		state.current = {
			start_time = start_time,
			user_id = user_id,
			branch = branch
		}
		print(string.format("Timer started at %s (user: %s, branch: %s)", os.date("%X", start_time), user_id,
			branch or "none"))
	end
end

function M.StopTimer()
	if not state.current then
		print("No timer is running")
	else
		local stop_time = os.time()
		local session = state.current
		session.stop_time = stop_time
		session.elapsed = stop_time - session.start_time
		table.insert(state.sessions, session)
		save_sessions(state.sessions)
		state.current = nil

		print(string.format("Timer stopped. User: %s, Branch: %s, Elapsed: %s seconds", session.user_id, session.branch,
			session.elapsed))
	end
end

-- Show sessions in a floating window UI
function M.ShowSessions()
	-- Prepare buffer
	local buf = vim.api.nvim_create_buf(false, true)
	local total_elapsed = 0
	-- Format lines
	local lines = { string.format("%-3s %-19s %-19s %-6s %-10s %s", "#", "Start", "Stop", "Mins", "User", "Branch") }
	for i, s in ipairs(state.sessions) do
		total_elapsed  = total_elapsed + s.elapsed
		local start_str = os.date("%Y-%m-%d %H:%M", s.start_time)
		local stop_str = os.date("%Y-%m-%d %H:%M", s.stop_time)
		local mins = string.format("%.2f", s.elapsed / 60)
		lines[#lines + 1] = string.format("%-3d %-19s %-19s %-6s %-10s %s",
			i, start_str, stop_str, mins, s.user_id, s.branch or "-")
	end
	-- Blank line and totals
	lines[#lines + 1] = ""
	local total_mins = string.format("%.2f mins", total_elapsed / 60)
	lines [#lines + 1] = string.format("Total sessions: %d    Total time: %s", #state.sessions, total_mins)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	-- Window dimensions
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.6)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)
	-- Open floating window
	local win = vim.api.nvim_open_win(buf, true, {
		relative = 'editor',
		width = width,
		height = height,
		row = row,
		col = col,
		style = 'minimal',
		border = 'rounded'
	})
	-- Set options
	vim.api.nvim_win_set_option(win, 'cursorline', true)
	-- Keymaps to close
	vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>bd!<CR>', { silent = true, noremap = true })
	vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '<cmd>bd!<CR>', { silent = true, noremap = true })
end

vim.api.nvim_create_user_command("StartTimer", function() M.StartTimer() end, {})
vim.api.nvim_create_user_command("StopTimer", function() M.StopTimer() end, {})
vim.api.nvim_create_user_command("ShowSessions", function() M.ShowSessions() end, {})

return M
