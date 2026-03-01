local M = {}

local config = require "droid.config"

local hints_visible = true
local original_set = nil

--- Per-buffer, per-namespace storage of original (unfiltered) diagnostics.
---@type table<number, table<number, vim.Diagnostic[]>>
local stored = {}

--- Build a lookup set of suppressed diagnostic codes for a given filetype.
---@param ft string
---@return table<string|number, true>|nil
local function get_suppressed_codes(ft)
    local cfg = config.get()
    local lang_cfg
    if ft == "kotlin" then
        lang_cfg = cfg.lsp.kotlin
    elseif ft == "java" then
        lang_cfg = cfg.lsp.java
    end
    if not lang_cfg then
        return nil
    end
    local suppress = lang_cfg.suppress_diagnostics
    if not suppress or #suppress == 0 then
        return nil
    end
    local codes = {}
    for _, code in ipairs(suppress) do
        codes[code] = true
    end
    return codes
end

--- Filter out HINT-severity diagnostics.
---@param diagnostics vim.Diagnostic[]
---@return vim.Diagnostic[]
local function filter_hints(diagnostics)
    return vim.tbl_filter(function(d)
        return d.severity ~= vim.diagnostic.severity.HINT
    end, diagnostics)
end

--- Filter out diagnostics whose code matches the suppression list.
---@param diagnostics vim.Diagnostic[]
---@param codes table<string|number, true>
---@return vim.Diagnostic[]
local function filter_suppressed(diagnostics, codes)
    return vim.tbl_filter(function(d)
        return not codes[d.code]
    end, diagnostics)
end

--- Apply all active filters to a diagnostic list.
---@param diagnostics vim.Diagnostic[]
---@param ft string
---@return vim.Diagnostic[]
local function apply_filters(diagnostics, ft)
    local codes = get_suppressed_codes(ft)
    if codes then
        diagnostics = filter_suppressed(diagnostics, codes)
    end
    if not hints_visible then
        diagnostics = filter_hints(diagnostics)
    end
    return diagnostics
end

--- Refresh diagnostics for all stored buffers using current toggle state.
local function refresh_all()
    for bufnr, namespaces in pairs(stored) do
        if vim.api.nvim_buf_is_valid(bufnr) then
            local ft = vim.bo[bufnr].filetype
            for ns, diags in pairs(namespaces) do
                original_set(ns, bufnr, apply_filters(diags, ft))
            end
        else
            stored[bufnr] = nil
        end
    end
end

function M.toggle_hints()
    hints_visible = not hints_visible
    refresh_all()
    vim.notify("droid.nvim: HINT diagnostics " .. (hints_visible and "shown" or "hidden"), vim.log.levels.INFO)
end

function M.setup()
    if original_set then
        return
    end
    original_set = vim.diagnostic.set

    vim.diagnostic.set = function(ns, bufnr, diagnostics, opts)
        -- Only intercept for droid.nvim-managed filetypes
        local ft = ""
        if vim.api.nvim_buf_is_valid(bufnr) then
            ft = vim.bo[bufnr].filetype
        end
        if ft == "kotlin" or ft == "java" or ft == "groovy" then
            -- Deep copy and store original diagnostics
            if not stored[bufnr] then
                stored[bufnr] = {}
            end
            stored[bufnr][ns] = vim.deepcopy(diagnostics)
            diagnostics = apply_filters(diagnostics, ft)
        end
        return original_set(ns, bufnr, diagnostics, opts)
    end

    local grp = vim.api.nvim_create_augroup("DroidDiagnostics", { clear = true })
    vim.api.nvim_create_autocmd("BufDelete", {
        group = grp,
        callback = function(ev)
            stored[ev.buf] = nil
        end,
    })
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = grp,
        callback = function()
            stored = {}
        end,
    })
end

return M
