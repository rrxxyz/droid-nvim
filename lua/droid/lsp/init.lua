local config = require "droid.config"

local M = {}

local initialised = false

---------------------------------------------------------------------------
-- Java resolution
---------------------------------------------------------------------------

--- Try a list of candidate paths and return the first executable one.
---@param candidates string[]
---@return string|nil
local function first_executable(candidates)
    for _, p in ipairs(candidates) do
        if vim.fn.executable(p) == 1 then
            return p
        end
    end
    return nil
end

--- Resolve the bundled JRE path, accounting for macOS layout.
---@param pkg_dir string
---@return string
local function bundled_jre_dir(pkg_dir)
    local uv = vim.uv or vim.loop
    if uv.os_uname().sysname == "Darwin" then
        return pkg_dir .. "/jre/Contents/Home"
    end
    return pkg_dir .. "/jre"
end

--- Locate a java binary.  Order: bundled (Mason/manual) → user config → JAVA_HOME → PATH.
---@param pkg_dir string|nil  kotlin-lsp package directory
---@param cfg table            plugin config
---@return string|nil
local function find_java(pkg_dir, cfg)
    local candidates = {}
    if pkg_dir then
        table.insert(candidates, bundled_jre_dir(pkg_dir) .. "/bin/java")
    end
    if cfg.lsp.jre_path then
        table.insert(candidates, cfg.lsp.jre_path .. "/bin/java")
    end
    if vim.env.JAVA_HOME then
        table.insert(candidates, vim.env.JAVA_HOME .. "/bin/java")
    end
    table.insert(candidates, "java")
    return first_executable(candidates)
end

---------------------------------------------------------------------------
-- kotlin-lsp package resolution
---------------------------------------------------------------------------

--- Look for the kotlin-lsp package (Mason install or env var).
---@return string|nil  directory path
local function find_package_dir()
    local mason = vim.fn.stdpath "data" .. "/mason/packages/kotlin-lsp"
    if vim.fn.isdirectory(mason) == 1 then
        return mason
    end
    local env = vim.env.KOTLIN_LSP_DIR
    if env and vim.fn.isdirectory(env) == 1 then
        return env
    end
    return nil
end

--- Collect all .jar files under the package lib directory and join with `:`.
--- Checks `lib/` (JetBrains kotlin-lsp) first, falls back to `server/lib/` (legacy).
---@param pkg_dir string
---@return string|nil classpath
local function collect_jars(pkg_dir)
    for _, sub in ipairs { "/lib", "/server/lib" } do
        local lib = pkg_dir .. sub
        if vim.fn.isdirectory(lib) == 1 then
            local jars = vim.fn.glob(lib .. "/*.jar", false, true)
            if #jars > 0 then
                return table.concat(jars, ":")
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Workspace isolation
---------------------------------------------------------------------------

function M.workspace_cache_dir()
    return vim.fn.stdpath "cache" .. "/droid-kotlin-workspaces"
end

---@param root string  project root
---@return string
local function workspace_for(root)
    return M.workspace_cache_dir() .. "/" .. vim.fn.sha256(root):sub(1, 16)
end

---------------------------------------------------------------------------
-- Per-project config (.droid-lsp.lua)
---------------------------------------------------------------------------

---@return table
local function project_overrides()
    local f = vim.fn.getcwd() .. "/.droid-lsp.lua"
    if vim.fn.filereadable(f) == 0 then
        return {}
    end
    local ok, tbl = pcall(dofile, f)
    if ok and type(tbl) == "table" then
        return tbl
    end
    if not ok then
        vim.notify("droid.nvim: bad .droid-lsp.lua — " .. tostring(tbl), vim.log.levels.WARN)
    end
    return {}
end

---------------------------------------------------------------------------
-- LSP settings builder
---------------------------------------------------------------------------

---@param cfg table
---@return table
local function make_settings(cfg)
    local s = {
        kotlin = {
            compiler = { jvm = { target = "default" } },
        },
    }
    local ih = cfg.lsp.inlay_hints
    if ih then
        s["jetbrains.kotlin.hints.parameters"] = ih.parameters ~= false
        s["jetbrains.kotlin.hints.parameters.compiled"] = ih.parameters_compiled ~= false
        s["jetbrains.kotlin.hints.parameters.excluded"] = ih.parameters_excluded == true
        s["jetbrains.kotlin.hints.settings.types.property"] = ih.types_property ~= false
        s["jetbrains.kotlin.hints.settings.types.variable"] = ih.types_variable ~= false
        s["jetbrains.kotlin.hints.type.function.return"] = ih.function_return ~= false
        s["jetbrains.kotlin.hints.type.function.parameter"] = ih.function_parameter ~= false
        s["jetbrains.kotlin.hints.settings.lambda.return"] = ih.lambda_return ~= false
        s["jetbrains.kotlin.hints.lambda.receivers.parameters"] = ih.lambda_receivers_parameters ~= false
        s["jetbrains.kotlin.hints.settings.value.ranges"] = ih.value_ranges ~= false
        s["jetbrains.kotlin.hints.value.kotlin.time"] = ih.kotlin_time ~= false
        s["jetbrains.kotlin.hints.call.chains"] = ih.call_chains == true
    end
    return s
end

--- Build response for workspace/configuration request.
--- Converts flat plugin settings into the nested structure kotlin-lsp expects.
---@param cfg table
---@param items table[]  params.items from the LSP request
---@return table[]
local function handle_workspace_configuration(cfg, items)
    local ih = cfg.lsp.inlay_hints or {}
    local results = {}
    for _, item in ipairs(items) do
        local section = item.section or ""
        if section == "hints.parameters" then
            table.insert(results, ih.parameters ~= false)
        elseif section == "hints.parameters.compiled" then
            table.insert(results, ih.parameters_compiled ~= false)
        elseif section == "hints.parameters.excluded" then
            table.insert(results, ih.parameters_excluded == true)
        elseif section == "hints.settings.types.property" or section == "hints.types.property" then
            table.insert(results, ih.types_property ~= false)
        elseif section == "hints.settings.types.variable" or section == "hints.types.variable" then
            table.insert(results, ih.types_variable ~= false)
        elseif section == "hints.type.function.return" then
            table.insert(results, ih.function_return ~= false)
        elseif section == "hints.type.function.parameter" then
            table.insert(results, ih.function_parameter ~= false)
        elseif section == "hints.settings.lambda.return" or section == "hints.lambda.return" then
            table.insert(results, ih.lambda_return ~= false)
        elseif section == "hints.lambda.receivers.parameters" then
            table.insert(results, ih.lambda_receivers_parameters ~= false)
        elseif section == "hints.settings.value.ranges" or section == "hints.ranges.value" then
            table.insert(results, ih.value_ranges ~= false)
        elseif section == "hints.value.kotlin.time" or section == "hints.kotlin.time" then
            table.insert(results, ih.kotlin_time ~= false)
        elseif section == "hints.call.chains" then
            table.insert(results, ih.call_chains == true)
        else
            table.insert(results, vim.NIL)
        end
    end
    return results
end

---------------------------------------------------------------------------
-- Core lazy initialisation (runs on first FileType kotlin)
---------------------------------------------------------------------------

---@param cfg table
local function start(cfg)
    if initialised or vim.b.droid_lsp_disabled then
        return
    end

    -- Merge per-project overrides
    local overrides = project_overrides()
    if next(overrides) then
        cfg = vim.tbl_deep_extend("force", cfg, { lsp = overrides })
    end

    local pkg_dir = find_package_dir()
    local java = find_java(pkg_dir, cfg)
    if not java then
        vim.notify("droid.nvim: java not found — install Java 21+ or set lsp.jre_path", vim.log.levels.ERROR)
        return
    end

    -- Validate version
    local jre = require "droid.lsp.jre"
    local ok, err = jre.check(java)
    if not ok then
        vim.notify("droid.nvim: " .. err, vim.log.levels.ERROR)
        return
    end

    -- Build the server command
    local ws = workspace_for(vim.fn.getcwd())
    local cmd
    if pkg_dir then
        local cp = collect_jars(pkg_dir)
        if not cp then
            vim.notify("droid.nvim: no jars in " .. pkg_dir .. "/lib", vim.log.levels.ERROR)
            return
        end
        cmd = { java }
        -- stylua: ignore start
        vim.list_extend(cmd, {
            "--add-opens=java.base/java.io=ALL-UNNAMED",
            "--add-opens=java.base/java.lang=ALL-UNNAMED",
            "--add-opens=java.base/java.lang.ref=ALL-UNNAMED",
            "--add-opens=java.base/java.lang.reflect=ALL-UNNAMED",
            "--add-opens=java.base/java.net=ALL-UNNAMED",
            "--add-opens=java.base/java.nio=ALL-UNNAMED",
            "--add-opens=java.base/java.nio.charset=ALL-UNNAMED",
            "--add-opens=java.base/java.text=ALL-UNNAMED",
            "--add-opens=java.base/java.time=ALL-UNNAMED",
            "--add-opens=java.base/java.util=ALL-UNNAMED",
            "--add-opens=java.base/java.util.concurrent=ALL-UNNAMED",
            "--add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED",
            "--add-opens=java.base/java.util.concurrent.locks=ALL-UNNAMED",
            "--add-opens=java.base/jdk.internal.ref=ALL-UNNAMED",
            "--add-opens=java.base/jdk.internal.vm=ALL-UNNAMED",
            "--add-opens=java.base/sun.net.dns=ALL-UNNAMED",
            "--add-opens=java.base/sun.nio.ch=ALL-UNNAMED",
            "--add-opens=java.base/sun.nio.fs=ALL-UNNAMED",
            "--add-opens=java.base/sun.security.ssl=ALL-UNNAMED",
            "--add-opens=java.base/sun.security.util=ALL-UNNAMED",
            "--add-opens=java.desktop/com.apple.eawt=ALL-UNNAMED",
            "--add-opens=java.desktop/com.apple.eawt.event=ALL-UNNAMED",
            "--add-opens=java.desktop/com.apple.laf=ALL-UNNAMED",
            "--add-opens=java.desktop/com.sun.java.swing=ALL-UNNAMED",
            "--add-opens=java.desktop/com.sun.java.swing.plaf.gtk=ALL-UNNAMED",
            "--add-opens=java.desktop/java.awt=ALL-UNNAMED",
            "--add-opens=java.desktop/java.awt.dnd.peer=ALL-UNNAMED",
            "--add-opens=java.desktop/java.awt.event=ALL-UNNAMED",
            "--add-opens=java.desktop/java.awt.font=ALL-UNNAMED",
            "--add-opens=java.desktop/java.awt.image=ALL-UNNAMED",
            "--add-opens=java.desktop/java.awt.peer=ALL-UNNAMED",
            "--add-opens=java.desktop/javax.swing=ALL-UNNAMED",
            "--add-opens=java.desktop/javax.swing.plaf.basic=ALL-UNNAMED",
            "--add-opens=java.desktop/javax.swing.text=ALL-UNNAMED",
            "--add-opens=java.desktop/javax.swing.text.html=ALL-UNNAMED",
            "--add-opens=java.desktop/sun.awt=ALL-UNNAMED",
            "--add-opens=java.desktop/sun.awt.X11=ALL-UNNAMED",
            "--add-opens=java.desktop/sun.awt.datatransfer=ALL-UNNAMED",
            "--add-opens=java.desktop/sun.awt.image=ALL-UNNAMED",
            "--add-opens=java.desktop/sun.awt.windows=ALL-UNNAMED",
            "--add-opens=java.desktop/sun.font=ALL-UNNAMED",
            "--add-opens=java.desktop/sun.java2d=ALL-UNNAMED",
            "--add-opens=java.desktop/sun.lwawt=ALL-UNNAMED",
            "--add-opens=java.desktop/sun.lwawt.macosx=ALL-UNNAMED",
            "--add-opens=java.desktop/sun.swing=ALL-UNNAMED",
            "--add-opens=java.management/sun.management=ALL-UNNAMED",
            "--add-opens=jdk.attach/sun.tools.attach=ALL-UNNAMED",
            "--add-opens=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED",
            "--add-opens=jdk.internal.jvmstat/sun.jvmstat.monitor=ALL-UNNAMED",
            "--add-opens=jdk.jdi/com.sun.tools.jdi=ALL-UNNAMED",
            "--enable-native-access=ALL-UNNAMED",
            "-Djdk.lang.Process.launchMechanism=FORK",
            "-Djava.awt.headless=true",
            "-Djava.system.class.loader=com.intellij.util.lang.PathClassLoader",
        })
        -- stylua: ignore end
        vim.list_extend(cmd, cfg.lsp.jvm_args or {})
        vim.list_extend(cmd, {
            "-cp",
            cp,
            "com.jetbrains.ls.kotlinLsp.KotlinLspServerKt",
            "--stdio",
            "--system-path=" .. ws,
        })
    else
        local bin = first_executable { "kotlin-lsp", "kotlin-language-server" }
        if not bin then
            vim.notify("droid.nvim: kotlin-lsp not found — install via Mason or add to PATH", vim.log.levels.ERROR)
            return
        end
        cmd = { bin, "--stdio", "--system-path=" .. ws }
    end

    local settings = make_settings(cfg)
    local init_opts = {}
    if cfg.lsp.jdk_for_symbol_resolution then
        init_opts.defaultJdk = cfg.lsp.jdk_for_symbol_resolution
    end

    vim.lsp.config("kotlin_ls", {
        cmd = cmd,
        filetypes = { "kotlin" },
        root_markers = cfg.lsp.root_markers,
        settings = settings,
        init_options = init_opts,
        capabilities = {
            textDocument = {
                inlayHint = { dynamicRegistration = true },
            },
        },
        handlers = {
            ["workspace/configuration"] = function(_, params, ctx)
                return handle_workspace_configuration(cfg, params.items)
            end,
        },
    })
    vim.lsp.enable "kotlin_ls"

    -- Decompiler autocmds (jar://, jrt://)
    local decompiler = require "droid.lsp.decompiler"
    local dec_grp = vim.api.nvim_create_augroup("DroidDecompile", { clear = true })
    for _, scheme in ipairs(decompiler.schemes) do
        vim.api.nvim_create_autocmd("BufReadCmd", {
            group = dec_grp,
            pattern = scheme .. "://*",
            callback = function(ev)
                decompiler.handle(ev.match)
            end,
        })
    end

    -- Suppress specific diagnostic codes by wrapping publishDiagnostics handler
    local suppress = cfg.lsp.suppress_diagnostics or {}
    if #suppress > 0 then
        local codes = {}
        for _, code in ipairs(suppress) do
            codes[code] = true
        end
        local default_handler = vim.lsp.handlers["textDocument/publishDiagnostics"]
        vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, handler_cfg)
            local c = vim.lsp.get_client_by_id(ctx.client_id)
            if c and c.name == "kotlin_ls" and result and result.diagnostics then
                result.diagnostics = vim.tbl_filter(function(d)
                    return not codes[d.code]
                end, result.diagnostics)
            end
            return default_handler(err, result, ctx, handler_cfg)
        end
    end

    require("droid.lsp.commands").setup()
    require("droid.lsp.diagnostics").setup()

    -- Auto-enable inlay hints when kotlin_ls attaches
    local ih = cfg.lsp.inlay_hints
    if ih and ih.enabled ~= false then
        vim.api.nvim_create_autocmd("LspAttach", {
            group = vim.api.nvim_create_augroup("DroidInlayHints", { clear = true }),
            callback = function(ev)
                local c = vim.lsp.get_client_by_id(ev.data.client_id)
                if c and c.name == "kotlin_ls" and c.supports_method "textDocument/inlayHint" then
                    vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
                end
            end,
        })
    end

    initialised = true
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function M.stop()
    local client = require "droid.lsp.client"
    for _, c in ipairs(client.all()) do
        c:stop()
    end
end

function M.clean_workspace()
    M.stop()
    local dir = M.workspace_cache_dir()
    if vim.fn.isdirectory(dir) == 1 then
        vim.fn.delete(dir, "rf")
        vim.notify("droid.nvim: workspace cache removed", vim.log.levels.INFO)
    else
        vim.notify("droid.nvim: nothing to clean", vim.log.levels.INFO)
    end
end

function M.restart()
    M.stop()
    initialised = false
    vim.defer_fn(function()
        start(config.get())
    end, 500)
end

--- Called once from droid/init.lua.
function M.setup()
    local cfg = config.get()
    if not cfg.lsp or not cfg.lsp.enabled then
        return
    end
    if not vim.lsp.config then
        vim.notify("droid.nvim: Kotlin LSP needs Neovim 0.11+", vim.log.levels.WARN)
        return
    end

    vim.api.nvim_create_user_command("DroidCleanWorkspace", M.clean_workspace, {})
    vim.api.nvim_create_user_command("DroidLspStop", function()
        M.stop()
        vim.notify("droid.nvim: kotlin_ls stopped", vim.log.levels.INFO)
    end, {})
    vim.api.nvim_create_user_command("DroidLspRestart", M.restart, {})

    vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("DroidKotlinLsp", { clear = true }),
        pattern = "kotlin",
        once = true,
        callback = function()
            start(cfg)
        end,
    })
end

return M
