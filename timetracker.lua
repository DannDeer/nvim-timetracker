-- plugin/timetracker.lua
-- A simple neovim plugin to track time spent on projects
-- Usage:
-- 	:StartTimer -- begin tracking time
-- 	:StopTimer  -- stop tracking time

local vim = vim
local json = vim.fn.json_encode and vim.fn or require("vim.json")

local M = {}

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
		print(string.format("Timer started at %s (user: %s, branch: %s)", os.date("%X", start_time), user_id, branch or "none"))
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

		print(string.format("Timer stopped. User: %s, Branch: %s, Elapsed: %s seconds", session.user_id, session.branch, session.elapsed))
	end
end

function M.ListSessions()
	for i, s in ipairs(state.sessions) do
		print(string.format(
			"%d: %s -> %s | user: %s | branch: %s | %.2f mins",
			i,
			os.date("%Y-%m-%d %X", s.start_time),
			os.date("%Y-%m-%d %X", s.stop_time),
			s.user_id,
			s.branch,
			s.elapsed / 60
		))
	end
end

vim.api.nvim_create_user_command("StartTimer", function() M.StartTimer() end, {})
vim.api.nvim_create_user_command("StopTimer", function() M.StopTimer() end, {})
vim.api.nvim_create_user_command("ListSessions", function() M.ListSessions() end, {})

return M
