local M = {}

local defaults = {
    logcat = {
        mode = "horizontal", -- "horizontal" | "vertical" | "float"
        height = 15,
        width = 80,
        float_width = 120,
        float_height = 30,
        filters = {
            package = "mine", -- "mine" (auto-detect), specific package, or "none"
            log_level = "v", -- v, d, i, w, e, f
            tag = nil,
            grep_pattern = nil,
        },
    },
    lsp = {
        enabled = true,
        jre_path = nil, -- path to JRE 21+ (auto-detected from bundled/JAVA_HOME/system)
        jdk_for_symbol_resolution = nil, -- JDK path for kotlin-lsp symbol resolution
        jvm_args = {}, -- additional JVM arguments for kotlin-lsp
        root_markers = nil, -- override if needed; kotlin-lsp auto-detects project root by default
        suppress_diagnostics = {}, -- diagnostic codes to hide, e.g. { "PackageDirectoryMismatch", "FunctionName" }
        inlay_hints = {
            enabled = true,
            parameters = true,
            parameters_compiled = true,
            parameters_excluded = false,
            types_property = true,
            types_variable = true,
            function_return = true,
            function_parameter = true,
            lambda_return = true,
            lambda_receivers_parameters = true,
            value_ranges = true,
            kotlin_time = true,
            call_chains = false,
        },
    },
    android = {
        auto_select_single_target = true,
        android_home = nil,
        android_avd_home = nil,
        device_wait_timeout_ms = 120000,
        boot_complete_timeout_ms = 120000,
        boot_check_interval_ms = 3000,
        logcat_startup_delay_ms = 2000,
    },
}

M.config = vim.deepcopy(defaults)

local function validate_config(cfg)
    local valid_modes = { horizontal = true, vertical = true, float = true }
    if cfg.logcat and cfg.logcat.mode and not valid_modes[cfg.logcat.mode] then
        vim.notify("Invalid logcat mode. Using 'horizontal'", vim.log.levels.WARN)
        cfg.logcat.mode = "horizontal"
    end

    if cfg.logcat then
        if cfg.logcat.height and (type(cfg.logcat.height) ~= "number" or cfg.logcat.height <= 0) then
            cfg.logcat.height = 15
        end
        if cfg.logcat.width and (type(cfg.logcat.width) ~= "number" or cfg.logcat.width <= 0) then
            cfg.logcat.width = 80
        end
    end
end

function M.setup(opts)
    opts = opts or {}
    validate_config(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts)
end

function M.get()
    return M.config
end

return M
