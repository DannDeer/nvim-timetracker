-- plugin/timetracker.lua
-- A simple neovim plugin to track time spent on projects
-- Usage:
-- 	:StartTimer -- begin tracking time
-- 	:StopTimer  -- stop tracking time

local M = {}
local timer = { start_time = nil }

function M.StartTimer()
	if timer.start_time then
		print("Timer is already running")
	else
		timer.start_time = os.time()
		local start_str = os.date("%X", timer.start_time)
		print("Timer started at " .. start_str)
	end
end

function M.StopTimer()
	if not timer.start_time then
		print("No timer is running")
	else
		local elapsed = os.time() - timer.start_time
		timer.start_time = nil
		print("Timer stopped. Elapsed time: " .. elapsed .. " seconds")
	end
end

vim.api.nvim_create_user_command("StartTimer", function() M.StartTimer() end, {})
vim.api.nvim_create_user_command("StopTimer", function() M.StopTimer() end, {})

return M
