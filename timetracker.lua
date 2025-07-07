-- plugin/timetracker.lua
-- A simple neovim plugin to track time spent on projects
-- Usage:
-- 	:StartTimer -- begin tracking time
-- 	:StopTimer  -- stop tracking time

local M = {}
local timer = { 
	current = nil,
	sessions = {}
}

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

function M.StartTimer()
	if timer.current then
		print("Timer is already running")
	else
		local start_time = os.time()
		local user_id = get_user_id()
		local branch = get_git_branch()
		timer.current = {
			start_time = start_time,
			user_id = user_id,
			branch = branch
		}
		print(string.format("Timer started at %s (user: %s, branch: %s)", os.date("%X", start_time), user_id, branch or "none"))
	end
end

function M.StopTimer()
	if not timer.current then
		print("No timer is running")
	else
		local stop_time = os.time()
		local session = timer.current
		session.stop_time = stop_time
		session.elapsed = stop_time - session.start_time
		table.insert(timer.sessions, session)
		timer.current = nil

		print(string.format("Timer stopped. User: %s, Branch: %s, Elapsed: %s seconds", session.user_id, session.branch, session.elapsed))
	end
end

vim.api.nvim_create_user_command("StartTimer", function() M.StartTimer() end, {})
vim.api.nvim_create_user_command("StopTimer", function() M.StopTimer() end, {})

return M
