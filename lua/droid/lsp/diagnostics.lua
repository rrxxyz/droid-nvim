local M = {}

local hints_visible = true
local original_set = nil

--- Per-buffer, per-namespace storage of original (unfiltered) diagnostics.
---@type table<number, table<number, vim.Diagnostic[]>>
local stored = {}

--- Filter out HINT-severity diagnostics.
---@param diagnostics vim.Diagnostic[]
---@return vim.Diagnostic[]
local function filter_hints(diagnostics)
    return vim.tbl_filter(function(d)
        return d.severity ~= vim.diagnostic.severity.HINT
    end, diagnostics)
end

--- Refresh diagnostics for all stored buffers using current toggle state.
local function refresh_all()
    for bufnr, namespaces in pairs(stored) do
        if vim.api.nvim_buf_is_valid(bufnr) then
            for ns, diags in pairs(namespaces) do
                local to_set = hints_visible and diags or filter_hints(diags)
                original_set(ns, bufnr, to_set)
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
        -- Only intercept for valid Kotlin buffers
        local ft = ""
        if vim.api.nvim_buf_is_valid(bufnr) then
            ft = vim.bo[bufnr].filetype
        end
        if ft == "kotlin" then
            -- Deep copy and store original diagnostics
            if not stored[bufnr] then
                stored[bufnr] = {}
            end
            stored[bufnr][ns] = vim.deepcopy(diagnostics)

            if not hints_visible then
                diagnostics = filter_hints(diagnostics)
            end
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
