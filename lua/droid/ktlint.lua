local config = require "droid.config"
local progress = require "droid.progress"
local buffer = require "droid.buffer"

local M = {}

local function get_jar_path(version)
    local cfg = config.get()
    local dir = (cfg.ktlint and cfg.ktlint.jar_dir) or (vim.fn.stdpath "data" .. "/droid-nvim")
    return dir .. "/ktlint-compose-" .. version .. "-all.jar"
end

local function find_ktlint()
    local mason_bin = vim.fn.stdpath "data" .. "/mason/bin/ktlint"
    if vim.fn.executable(mason_bin) == 1 then
        return mason_bin
    end
    local found = vim.fn.exepath "ktlint"
    if found ~= "" then
        return found
    end
    return nil
end

--- Resolve ktlint binary, auto-installing via mason if not found.
local function ensure_ktlint(callback)
    local bin = find_ktlint()
    if bin then
        callback(bin)
        return
    end

    local ok, registry = pcall(require, "mason-registry")
    if not ok then
        vim.notify(
            "ktlint not found and mason is not available — install ktlint manually",
            vim.log.levels.ERROR
        )
        callback(nil)
        return
    end

    local pkg_ok, pkg = pcall(registry.get_package, "ktlint")
    if not pkg_ok then
        vim.notify("ktlint package not found in mason registry", vim.log.levels.ERROR)
        callback(nil)
        return
    end

    vim.notify("ktlint not found — installing via mason...", vim.log.levels.INFO)
    progress.start_spinner "Installing ktlint via mason"

    local handle = pkg:install()
    handle:on("closed", function()
        vim.schedule(function()
            progress.stop_spinner()
            if pkg:is_installed() then
                vim.notify("ktlint installed via mason", vim.log.levels.INFO)
                callback(vim.fn.stdpath "data" .. "/mason/bin/ktlint")
            else
                vim.notify("Failed to install ktlint via mason", vim.log.levels.ERROR)
                callback(nil)
            end
        end)
    end)
end

local function find_project_root()
    local gradlew = vim.fs.find("gradlew", { upward = true })[1]
    if gradlew then
        return vim.fs.dirname(gradlew)
    end
    return vim.fn.getcwd()
end

local function download_jar(version, jar_path, callback)
    local url = "https://github.com/mrmans0n/compose-rules/releases/download/v"
        .. version
        .. "/ktlint-compose-"
        .. version
        .. "-all.jar"

    vim.fn.mkdir(vim.fn.fnamemodify(jar_path, ":h"), "p")
    progress.start_spinner("Downloading compose-rules v" .. version)

    vim.system({ "curl", "-fsSL", "-o", jar_path, url }, {}, function(obj)
        vim.schedule(function()
            progress.stop_spinner()
            if obj.code == 0 and vim.fn.filereadable(jar_path) == 1 then
                vim.notify("Downloaded compose-rules v" .. version, vim.log.levels.INFO)
                callback(true, jar_path)
            else
                vim.fn.delete(jar_path)
                vim.notify(
                    "Failed to download compose-rules jar: " .. (obj.stderr or "unknown error"),
                    vim.log.levels.ERROR
                )
                callback(false, nil)
            end
        end)
    end)
end

local function ensure_jar(callback)
    local cfg = config.get()
    local version = (cfg.ktlint and cfg.ktlint.compose_rules_version) or "0.5.6"
    local jar_path = get_jar_path(version)

    if vim.fn.filereadable(jar_path) == 1 then
        callback(true, jar_path)
        return
    end

    download_jar(version, jar_path, callback)
end

local function run_ktlint(ktlint_bin, jar_path, extra_args, cwd, callback)
    local parts = { vim.fn.shellescape(ktlint_bin), "-R", vim.fn.shellescape(jar_path) }
    vim.list_extend(parts, extra_args or {})
    local cmd = table.concat(parts, " ")

    local buf, _ = buffer.get_or_create("gradle", "horizontal")
    if not buf then
        if callback then
            callback(false, -1)
        end
        return
    end

    vim.api.nvim_buf_call(buf, function()
        local job_id = vim.fn.jobstart(cmd, {
            term = true,
            cwd = cwd,
            on_exit = function(_, exit_code)
                buffer.set_current_job(nil)
                vim.schedule(function()
                    if exit_code ~= 0 then
                        buffer.focus()
                        buffer.scroll_to_bottom()
                    end
                    if callback then
                        callback(exit_code == 0, exit_code)
                    end
                end)
            end,
        })
        buffer.set_current_job(job_id)
    end)
end

local function run_after_setup(extra_args, spinner_msg, ok_msg, fail_msg, on_complete)
    local cfg = config.get()
    if cfg.ktlint and cfg.ktlint.enabled == false then
        vim.notify("ktlint is disabled in config", vim.log.levels.WARN)
        if on_complete then
            on_complete()
        end
        return
    end

    ensure_ktlint(function(ktlint_bin)
        if not ktlint_bin then
            if on_complete then
                on_complete()
            end
            return
        end

        ensure_jar(function(ok, jar_path)
            if not ok then
                if on_complete then
                    on_complete()
                end
                return
            end

            local cwd = find_project_root()
            progress.start_spinner(spinner_msg)

            run_ktlint(ktlint_bin, jar_path, extra_args, cwd, function(success, exit_code)
                progress.stop_spinner()
                if success then
                    vim.notify(ok_msg, vim.log.levels.INFO)
                else
                    vim.notify(string.format("%s (exit code: %d)", fail_msg, exit_code), vim.log.levels.WARN)
                end
                if on_complete then
                    on_complete()
                end
            end)
        end)
    end)
end

--- Run ktlint --format on all Kotlin files in the project.
function M.format(on_complete)
    run_after_setup(
        { "--format" },
        "Running ktlint format",
        "ktlint: formatting applied",
        "ktlint: format failed",
        on_complete
    )
end


--- Returns the jar path if it already exists on disk, nil otherwise.
function M.jar_path()
    local cfg = config.get()
    local version = (cfg.ktlint and cfg.ktlint.compose_rules_version) or "0.5.6"
    local path = get_jar_path(version)
    return vim.fn.filereadable(path) == 1 and path or nil
end

--- Inject compose-rules jar into nvim-lint's ktlint linter args.
--- Must be called with a valid jar_path; called again if jar is downloaded later.
function M.setup_nvim_lint(jar_path)
    local ok, lint = pcall(require, "lint")
    if not ok or not jar_path then
        return
    end

    local linter = lint.linters.ktlint
    if not linter then
        return
    end

    -- Resolve base args (handle both list and function forms)
    local orig = linter.args
    local base = type(orig) == "function" and orig() or vim.deepcopy(orig or {})

    -- Strip any previously injected -R to avoid duplicates on re-setup
    local filtered = {}
    local skip = false
    for _, v in ipairs(base) do
        if skip then
            skip = false
        elseif v == "-R" then
            skip = true
        else
            table.insert(filtered, v)
        end
    end

    linter.args = vim.list_extend({ "-R", jar_path }, filtered)
    linter.cwd = find_project_root()
end

--- Register a ktlint formatter in conform.nvim that includes the compose-rules jar.
function M.setup_conform()
    local ok, conform = pcall(require, "conform")
    if not ok then
        return
    end

    conform.formatters.ktlint = {
        command = function()
            return find_ktlint() or "ktlint"
        end,
        args = function()
            local args = { "--format", "--stdin", "--log-level=none" }
            local jar = M.jar_path()
            if jar then
                vim.list_extend(args, { "-R", jar })
            end
            return args
        end,
        cwd = function()
            return find_project_root()
        end,
        stdin = true,
    }
end

--- Called from droid setup(). Downloads jar eagerly and wires up nvim-lint / conform.
function M.setup()
    local function configure(jar_path)
        M.setup_nvim_lint(jar_path)
        M.setup_conform()
    end

    local function on_jar_ready(ok, jar_path)
        if ok then
            vim.schedule(function()
                configure(jar_path)
            end)
        end
    end

    -- If jar already exists, configure immediately (deferred until plugins are loaded).
    -- If jar needs downloading, configure once the download completes.
    local function startup()
        local jar = M.jar_path()
        if jar then
            configure(jar)
        else
            ensure_jar(on_jar_ready)
        end
    end

    if vim.v.vim_did_enter == 1 then
        startup()
    else
        vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = startup })
    end
end

--- Re-download the compose-rules jar (useful after updating the version in config).
function M.update_jar(on_complete)
    local cfg = config.get()
    local version = (cfg.ktlint and cfg.ktlint.compose_rules_version) or "0.5.6"
    local jar_path = get_jar_path(version)

    if vim.fn.filereadable(jar_path) == 1 then
        vim.fn.delete(jar_path)
    end

    download_jar(version, jar_path, function(ok, _)
        if not ok then
            vim.notify("Failed to update compose-rules jar", vim.log.levels.ERROR)
        end
        if on_complete then
            on_complete()
        end
    end)
end

return M
