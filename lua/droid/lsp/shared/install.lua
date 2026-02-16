--- Mason auto-install utility for droid.nvim LSPs
--- Detection order: Mason → Environment Variable → System PATH → Auto-install via Mason

local M = {}

--- Check if a path is a valid executable
---@param path string
---@return boolean
local function is_executable(path)
    return vim.fn.executable(path) == 1
end

--- Find first executable from a list of candidates
---@param candidates string[]
---@return string|nil
function M.first_executable(candidates)
    for _, p in ipairs(candidates) do
        if is_executable(p) then
            return p
        end
    end
    return nil
end

--- Check if Mason is available
---@return boolean
function M.has_mason()
    local ok = pcall(require, "mason-registry")
    return ok
end

--- Get Mason package installation path
---@param package_name string
---@return string
function M.mason_path(package_name)
    return vim.fn.stdpath "data" .. "/mason/packages/" .. package_name
end

--- Check if a package is installed in Mason
---@param package_name string
---@return boolean
function M.is_mason_installed(package_name)
    return vim.fn.isdirectory(M.mason_path(package_name)) == 1
end

--- Install a package via Mason (async)
---@param package_name string Mason package name
---@param display_name string User-friendly name for notifications
---@param on_complete? function Callback when installation completes (success: boolean)
function M.install_via_mason(package_name, display_name, on_complete)
    if not M.has_mason() then
        vim.notify(
            string.format(
                "droid.nvim: %s not found and Mason is not available.\n"
                    .. "Install mason.nvim or install %s manually:\n"
                    .. "  Set %s_DIR environment variable\n"
                    .. "  or add %s to system PATH",
                display_name,
                package_name,
                package_name:upper():gsub("-", "_"),
                package_name
            ),
            vim.log.levels.ERROR
        )
        if on_complete then
            on_complete(false)
        end
        return
    end

    local registry = require "mason-registry"

    -- Refresh registry if needed
    if not registry.is_installed(package_name) then
        local ok, pkg = pcall(registry.get_package, package_name)
        if not ok or not pkg then
            vim.notify(
                string.format(
                    "droid.nvim: Package '%s' not found in Mason registry.\n"
                        .. "Try running :MasonUpdate first, or install manually.",
                    package_name
                ),
                vim.log.levels.ERROR
            )
            if on_complete then
                on_complete(false)
            end
            return
        end

        vim.notify(string.format("droid.nvim: Installing %s via Mason...", display_name), vim.log.levels.INFO)

        pkg:install():once("closed", function()
            vim.schedule(function()
                if pkg:is_installed() then
                    vim.notify(
                        string.format("droid.nvim: %s installed successfully. Reopen file to start LSP.", display_name),
                        vim.log.levels.INFO
                    )
                    if on_complete then
                        on_complete(true)
                    end
                else
                    vim.notify(
                        string.format("droid.nvim: Failed to install %s via Mason.", display_name),
                        vim.log.levels.ERROR
                    )
                    if on_complete then
                        on_complete(false)
                    end
                end
            end)
        end)
    else
        -- Already installed
        if on_complete then
            on_complete(true)
        end
    end
end

--- Ensure a package is installed, auto-install if not found
--- Detection order: Mason → ENV → PATH → Auto-install
---@param opts { mason_name: string, env_var: string, binaries: string[], display_name: string }
---@return { type: "mason"|"env"|"binary", path: string }|nil
function M.find_or_install(opts)
    -- 1. Check Mason
    if M.is_mason_installed(opts.mason_name) then
        return { type = "mason", path = M.mason_path(opts.mason_name) }
    end

    -- 2. Check environment variable
    local env = vim.env[opts.env_var]
    if env and vim.fn.isdirectory(env) == 1 then
        return { type = "env", path = env }
    end

    -- 3. Check system PATH
    local bin = M.first_executable(opts.binaries)
    if bin then
        return { type = "binary", path = bin }
    end

    -- 4. Auto-install via Mason (async, returns nil for this attempt)
    M.install_via_mason(opts.mason_name, opts.display_name)

    return nil
end

return M
