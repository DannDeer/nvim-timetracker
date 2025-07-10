# TimeTracker Neovim Plugin

A simple Neovim plugin for tracking time spent on projects. It logs sessions with details like start/stop times, elapsed duration, user ID, and Git branch. Sessions are stored in a JSON file within the project root for easy persistence and review.

## Features

- **Automatic Session Management**: Optionally start/stop the timer on Neovim startup/exit.
- **Project-Aware Storage**: Saves session data in `.timetracker_sessions.json` at the project root (Git root if available, otherwise current working directory).
- **Gitignore Integration**: Automatically or manually add the session file to `.gitignore` in Git repositories to prevent accidental commits.
- **Live Session Display**: Optionally show the current session timer on startup; toggle a floating window with live elapsed time.
- **User Commands**:
  - `:TimeTrackerStart`: Begin a new tracking session.
  - `:TimeTrackerStop`: End the current session and log it.
  - `:TimeTrackerSessions`: Display a floating window with a table of all logged sessions, including totals.
  - `:TimeTrackerCurrentSession`: Toggle a floating window showing the live elapsed time of the active session.
  - `:TimeTrackerGitIgnore`: Manually ensure the session file is added to `.gitignore`.
- **Customizable**: Override default user ID, enable auto-start/stop, auto-add to gitignore, and auto-show current session on start.
- **Git Integration**: Automatically captures the current Git branch for each session.

## Installation

### Using a Plugin Manager

#### Lazy.nvim
Add the following to your `init.lua`:

```lua
require("lazy").setup({
  {
    "DannDot/nvim-timetracker",
    config = function()
      require("timetracker").setup()
    end,
  },
})
```

#### Packer.nvim
Add to your Packer config:

```lua
use {
  "DannDot/nvim-timetracker",
  config = function()
    require("timetracker").setup()
  end,
}
```

#### Manual Installation
Clone the repository into `~/.local/share/nvim/site/pack/vendor/start/`:

```bash
git clone https://github.com/DannDot/nvim-timetracker ~/.local/share/nvim/site/pack/vendor/start/timetracker
```

Then, in your `init.lua`:

```lua
require("timetracker").setup()
```

## Configuration

The plugin can be configured by passing an options table to `setup()`. Default values are shown below:

```lua
require("timetracker").setup({
  auto_start = false,  -- Automatically start the timer on Neovim startup
  auto_stop = false,   -- Automatically stop the timer on Neovim exit
  auto_gitignore = false, -- Automatically add session file to .gitignore on startup if in Git repo
  show_session_on_start = false, -- Automatically show the current session timer on startup
  name = nil,          -- Override the user identifier (defaults to $USER or system username)
})
```

Example with custom settings:

```lua
require("timetracker").setup({
  auto_start = true,
  auto_stop = true,
  auto_gitignore = true,
  show_session_on_start = true,
  name = "my_custom_user",
})
```

## Usage

### Starting and Stopping Sessions
- `:TimeTrackerStart`: Starts a new session. Prints a confirmation with start time, user, and branch.
- `:TimeTrackerStop`: Stops the current session, calculates elapsed time, logs it to the JSON file, and prints a summary.

Sessions are tracked while Neovim is open; stopping saves the data persistently.

### Viewing Sessions
- `:TimeTrackerSessions`: Opens a floating window displaying a table of all sessions:

  Example output:

  ```
  Total sessions: 3   Total time: 45.50 mins

  #   Start               Stop                Mins   User       Branch
  1   2025-07-10 10:00    2025-07-10 10:15    15.00  user       main
  2   2025-07-10 11:00    2025-07-10 11:20    20.00  user       feature/x
  3   2025-07-10 12:00    2025-07-10 12:10    10.50  user       -
  ```

  - Press `q` or `<Esc>` to close the window.
  - The table includes session number, start/stop dates, minutes elapsed, user, and branch (or `-` if none).

- `:TimeTrackerCurrentSession`: Toggles a small floating window in the bottom-right corner showing the live elapsed time (e.g., `Elapsed: 00:05:23`).
  - Displays time in hours:minutes:seconds format.
  - Updates every second.
  - Calling it again closes the window.
  - Only works if a session is active.
  - If `show_session_on_start = true` in config, this is automatically shown on Neovim startup (if a session is started).

### Gitignore Management
- `:TimeTrackerGitIgnore`: Manually checks if the project is a Git repository and adds `.timetracker_sessions.json` to `.gitignore` if not already present, creating the file if necessary.
- If `auto_gitignore = true` in config, this is automatically run on Neovim startup.

### Storage
- All sessions are stored in `.timetracker_sessions.json` in the project root.
- The file is a JSON array of objects, each with:
  - `start_time`: Unix timestamp of start.
  - `stop_time`: Unix timestamp of stop.
  - `elapsed`: Seconds elapsed.
  - `user_id`: User identifier.
  - `branch`: Git branch (or `null` if not in a Git repo).

You can manually edit or backup this file as needed.

## Dependencies
- Neovim 0.5+ (uses Lua APIs like `nvim_create_user_command`, `nvim_open_win`, etc.).
- Git (optional, for branch detection and gitignore management).

No external Lua libraries required.

## License
MIT License.

## Contributing
Feel free to open issues or pull requests on GitHub!
