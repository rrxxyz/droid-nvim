# droid.nvim

Android development workflow for Neovim. Build, run, and debug Android apps without leaving your editor.

> v0.0.1-alpha01 — Early alpha. Expect frequent updates and occasional breaking changes.

## Requirements

- Neovim 0.11+
- Android SDK with `adb` in PATH
- `gradlew` in project root
- Java 21+ (for Kotlin LSP)
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
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    -- "mason-org/mason.nvim", -- optional, for :MasonInstall kotlin-lsp
  },
  config = function()
    require("droid").setup()
  end,
}
```

> **Note:** droid-nvim manages Kotlin LSP and treesitter syntax highlighting internally.
> If you have other plugins configuring Kotlin LSP (e.g., nvim-lspconfig) or treesitter for Kotlin,
> consider disabling them to avoid conflicts.

### Configuration

All options are optional. Defaults shown below:

```lua
require("droid").setup({
    lsp = {
        enabled = true,
        jre_path = nil,                    -- path to JRE 21+ (auto-detected from bundled/JAVA_HOME/system)
        jdk_for_symbol_resolution = nil,   -- JDK path for kotlin-lsp symbol resolution
        jvm_args = {},                     -- additional JVM arguments for kotlin-lsp
        root_markers = nil,                -- override if needed; kotlin-lsp auto-detects project root by default
        suppress_diagnostics = {},         -- diagnostic codes to hide, e.g. { "PackageDirectoryMismatch" }
        inlay_hints = {
            enabled = true,                -- auto-enable inlay hints on attach
            parameters = true,             -- parameter name hints
            parameters_compiled = true,    -- parameter hints in compiled code
            parameters_excluded = false,   -- excluded parameter hints
            types_property = true,         -- property type hints
            types_variable = true,         -- variable type hints
            function_return = true,        -- function return type hints
            function_parameter = true,     -- function parameter type hints
            lambda_return = true,          -- lambda return type hints
            lambda_receivers_parameters = true, -- lambda receiver/parameter hints
            value_ranges = true,           -- value range hints
            kotlin_time = true,            -- Kotlin Duration hints
            call_chains = false,           -- function return type in call chains
        },
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

### Kotlin LSP

Kotlin LSP starts lazily when you first open a `.kt` file. It discovers `kotlin-lsp` in this order:

1. **Mason** — `mason/packages/kotlin-lsp/` (install with `:MasonInstall kotlin-lsp`)
2. **Environment variable** — `$KOTLIN_LSP_DIR`
3. **System PATH** — `kotlin-lsp` or `kotlin-language-server`

Java is resolved similarly: bundled JRE (Mason) → `lsp.jre_path` config → `$JAVA_HOME` → system `java`. Requires Java 21+.

#### Disabling Kotlin LSP

Globally via config:

```lua
require("droid").setup({
    lsp = { enabled = false },
})
```

Per-buffer (e.g., in an autocmd or ftplugin):

```lua
vim.b.droid_lsp_disabled = true
```

#### Per-project config

Create a `.droid-lsp.lua` in your project root to override LSP settings per-project:

```lua
-- .droid-lsp.lua
return {
    jre_path = "/usr/lib/jvm/java-21",
    jdk_for_symbol_resolution = "/usr/lib/jvm/java-21",
}
```

#### Decompilation

Navigating to a class from a dependency (e.g., go-to-definition on a library symbol) automatically decompiles the `.class` file via `jar://` and `jrt://` protocol handlers.

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

### Kotlin LSP

These commands are available in `.kt` buffers with `kotlin_ls` attached.

| Command | Description |
| --- | --- |
| `:DroidImports` | Organize imports |
| `:DroidFormat` | Format buffer (IntelliJ IDEA rules) |
| `:DroidSymbols` | Document symbols |
| `:DroidWorkspaceSymbols` | Workspace symbol search |
| `:DroidReferences` | Find all references |
| `:DroidRename` | Rename symbol |
| `:DroidCodeAction` | Show code actions |
| `:DroidQuickFix` | Quick fix for diagnostics on current line |
| `:DroidInlayHintsToggle` | Toggle inlay hints for current buffer |
| `:DroidHintsToggle` | Toggle HINT-severity diagnostics |
| `:DroidExportWorkspace` | Export workspace config to JSON |
| `:DroidCleanWorkspace` | Stop LSP and clean cached workspace |
| `:DroidLspStop` | Stop kotlin_ls |
| `:DroidLspRestart` | Restart kotlin_ls |

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

-- Kotlin LSP
vim.keymap.set("n", "<leader>ao", ":DroidImports<CR>")
vim.keymap.set("n", "<leader>af", ":DroidFormat<CR>")
```

## License

GPLv3
