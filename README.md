# Time Tracker.nvim

A simple Neovim plugin to track time spent on your projects. Log sessions with start/stop commands, view a floating UI of past sessions, and optionally auto-start/stop on editor open/close.

## Features

* **Start/Stop Timer**: `:StartTimer` and `:StopTimer` to log sessions.
* **Floating Sessions UI**: `:ShowSessions` displays a neatly formatted list with totals.
* **Per-Project Storage**: Sessions saved to a JSON file in your project's root (or CWD).
* **Git Branch & User ID**: Records current Git branch and customizable user name.
* **Auto Start/Stop**: Configure the plugin to automatically start on `VimEnter` and stop on `VimLeavePre`.

## Installation

### lazy.nvim

```lua
require('lazy').setup({
  {
    'DannDeer/time-tracker.nvim',
    opts = {
      auto_start = true,
      auto_stop  = true,
      name       = 'alice',
    },
    config = function(_, opts)
      require('timetracker').setup(opts)
    end,
  },
})
```

### packer.nvim

```lua
use {
  'DannDeer/time-tracker.nvim',
  config = function()
    require('timetracker').setup({
      auto_start = false,
      auto_stop  = false,
      name       = 'bob',
    })
  end,
}
```

### vim-plug

```vim
Plug 'DannDeer/time-tracker.nvim'

lua << EOF
  require('timetracker').setup{
    auto_start = false,
    auto_stop  = true,
    name       = 'charlie',
  }
EOF
```

### Pathogen / Manual

1. Clone into your plugin directory:

   ```bash
   git clone https://github.com/DannDeer/time-tracker.nvim ~/.config/nvim/pack/plugins/start/time-tracker.nvim
   ```
2. Add to your `init.lua` or `init.vim`:

   ```lua
   require('timetracker').setup({ name = 'me' })
   ```

## Usage

* **Start Timer**

  ```vim
  :StartTimer
  ```

  Begins a new session, recording timestamp, user, and Git branch.

* **Stop Timer**

  ```vim
  :StopTimer
  ```

  Stops the session and writes to `./.timetracker_sessions.json`.

* **Show Sessions**

  ```vim
  :ShowSessions
  ```

  Opens a floating window listing all past sessions and total time.

## Configuration Options

| Option       | Type    | Default | Description                                |
| ------------ | ------- | ------- | ------------------------------------------ |
| `auto_start` | boolean | `false` | Start timer automatically on Neovim launch |
| `auto_stop`  | boolean | `false` | Stop timer automatically on exit           |
| `name`       | string  | `nil`   | Override user identifier for new sessions  |

## Session File Format

Sessions are stored in JSON at `PROJECT_ROOT/.timetracker_sessions.json`. Each entry contains:

```json
{
  "start_time": 162...,   // epoch seconds
  "stop_time": 162...,    // epoch seconds
  "elapsed": 120,         // seconds
  "user_id": "alice",
  "branch": "main"
}
```

## FAQ

* **Q**: Can I change the storage path?
  **A**: Currently the plugin uses the Git root or CWD. You can fork and modify `get_storage_file()`.

* **Q**: How do I rename existing sessions?
  **A**: Edit the JSON file directly or write a migration script.

* **Q**: Will it work without Git?
  **A**: Yes — branch will show as `nil` and file saved to your CWD.

## Contributing

1. Fork the repo
2. Create a branch (`git checkout -b feat/your-feature`)
3. Commit changes
4. Open a Pull Request

## License

MIT © Daniel Riley

