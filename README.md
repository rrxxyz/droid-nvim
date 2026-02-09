# droid.nvim

Android development workflow for Neovim. Build, run, and debug Android apps without leaving your editor.

> Not yet stable, so expect frequent updates (and the occasional breaking change) as I polish the core experience.

## Requirements

- Neovim 0.10+
- Android SDK with `adb` in PATH
- `gradlew` in project root
- [scrcpy](https://github.com/Genymobile/scrcpy) (optional, for device mirroring)

## SDK Environment Setup

Android Studio handles this automatically, but if you're using Neovim without it, you need to set these manually.

### Linux / macOS

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.):

```sh
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_AVD_HOME="$HOME/.config/.android/avd"
export PATH="$ANDROID_HOME/emulator:$PATH"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
```

### Windows

Add to your system environment variables:

```powershell
setx ANDROID_HOME "%LOCALAPPDATA%\Android\Sdk"
setx ANDROID_AVD_HOME "%USERPROFILE%\.android\avd"
setx PATH "%ANDROID_HOME%\emulator;%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\cmdline-tools\latest\bin;%PATH%"
```

## Installation

```lua
-- lazy.nvim
{
  "rrxxyz/droid-nvim",
  config = function()
    require("droid").setup()
  end,
}
```

### Configuration

All options are optional. Defaults shown below:

```lua
require("droid").setup({
    lsp = {
        enabled = true,              -- Kotlin LSP (auto-detects local binary, falls back to lspconfig)
        cmd = nil,                   -- override: { "kotlin-ls", "--stdio" } or vim.lsp.rpc.connect(...)
    },
    logcat = {
        mode = "horizontal",         -- "horizontal" | "vertical" | "float"
        height = 15,
        filters = {
            package = "mine",        -- "mine" (auto-detect) or specific package
            log_level = "v",         -- v, d, i, w, e, f
        },
    },
    android = {
        android_home = nil,          -- override ANDROID_HOME / ANDROID_SDK_ROOT env var
        android_avd_home = nil,      -- override ANDROID_AVD_HOME env var
    },
})
```

## Commands

### Workflow

| Command | Description |
| --- | --- |
| `:DroidRun` | Build, install, launch, and show logcat |
| `:DroidBuild` | Build APK (uses selected variant) |
| `:DroidInstall` | Build and install APK |
| `:DroidBuildVariant` | Pick build variant (Debug, Release, flavors) |

### Gradle

| Command | Description |
| --- | --- |
| `:DroidClean` | Clean project |
| `:DroidSync` | Sync dependencies |
| `:DroidTask <task>` | Run any Gradle task |
| `:DroidGradleStop` | Stop running Gradle task |

### Device

| Command | Description |
| --- | --- |
| `:DroidDevices` | Show device/emulator picker |
| `:DroidEmulator` | Start emulator |
| `:DroidEmulatorCreate` | Create new emulator (AVD) |
| `:DroidEmulatorStop` | Stop emulator |
| `:DroidMirror` | Mirror device screen (scrcpy) |

### ADB Actions

| Command | Description |
| --- | --- |
| `:DroidClearData` | Clear app data |
| `:DroidForceStop` | Force stop app |
| `:DroidUninstall` | Uninstall app |

### Logcat

| Command | Description |
| --- | --- |
| `:DroidLogcat` | Open logcat |
| `:DroidLogcatFilter log_level=d` | Filter by level |
| `:DroidLogcatFilter tag=MyTag` | Filter by tag |
| `:DroidLogcatFilter package=mine` | Filter by package |
| `:DroidLogcatFilter grep=Exception` | Filter by pattern |

| `:DroidLogcatStop` | Stop logcat |
Combine filters: `:DroidLogcatFilter tag=MyTag log_level=d`

## Keybindings

```lua
-- Workflow
vim.keymap.set("n", "<leader>ar", ":DroidRun<CR>")
vim.keymap.set("n", "<leader>ab", ":DroidBuild<CR>")
vim.keymap.set("n", "<leader>ai", ":DroidInstall<CR>")
vim.keymap.set("n", "<leader>av", ":DroidBuildVariant<CR>")

-- Gradle
vim.keymap.set("n", "<leader>as", ":DroidSync<CR>")
vim.keymap.set("n", "<leader>ac", ":DroidClean<CR>")

-- Device
vim.keymap.set("n", "<leader>ad", ":DroidDevices<CR>")
vim.keymap.set("n", "<leader>ae", ":DroidEmulator<CR>")
vim.keymap.set("n", "<leader>aE", ":DroidEmulatorCreate<CR>")
vim.keymap.set("n", "<leader>am", ":DroidMirror<CR>")

-- Logcat
vim.keymap.set("n", "<leader>al", ":DroidLogcat<CR>")
vim.keymap.set("n", "<leader>ax", ":DroidLogcatStop<CR>")
```

## License

MIT
