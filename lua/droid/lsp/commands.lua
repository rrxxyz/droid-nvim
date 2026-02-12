local client = require "droid.lsp.client"

local M = {}

local function need_client()
    local c = client.first { bufnr = 0 }
    if not c then
        vim.notify("kotlin_ls not attached", vim.log.levels.WARN)
    end
    return c
end

function M.setup()
    local cmd = vim.api.nvim_create_user_command

    cmd("DroidImports", function()
        if not need_client() then
            return
        end
        client.run_command("kotlin.organize.imports", { vim.uri_from_bufnr(0) }, function(err)
            if err then
                vim.schedule(function()
                    vim.notify("Organize imports: " .. tostring(err), vim.log.levels.ERROR)
                end)
            end
        end)
    end, {})

    cmd("DroidFormat", function()
        if not need_client() then
            return
        end
        vim.lsp.buf.format { name = "kotlin_ls" }
    end, {})

    cmd("DroidSymbols", function()
        if not need_client() then
            return
        end
        vim.lsp.buf.document_symbol()
    end, {})

    cmd("DroidWorkspaceSymbols", function()
        if not need_client() then
            return
        end
        vim.lsp.buf.workspace_symbol ""
    end, {})

    cmd("DroidReferences", function()
        if not need_client() then
            return
        end
        vim.lsp.buf.references()
    end, {})

    cmd("DroidRename", function()
        if not need_client() then
            return
        end
        vim.lsp.buf.rename()
    end, {})

    cmd("DroidCodeAction", function()
        if not need_client() then
            return
        end
        vim.lsp.buf.code_action()
    end, {})

    cmd("DroidQuickFix", function()
        if not need_client() then
            return
        end
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        vim.lsp.buf.code_action {
            context = {
                only = { "quickfix" },
                diagnostics = vim.diagnostic.get(0, { lnum = row }),
            },
        }
    end, {})

    cmd("DroidInlayHintsToggle", function()
        local bufnr = vim.api.nvim_get_current_buf()
        local enabled = vim.lsp.inlay_hint.is_enabled { bufnr = bufnr }
        vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
        vim.notify("droid.nvim: inlay hints " .. (not enabled and "enabled" or "disabled"), vim.log.levels.INFO)
    end, {})

    cmd("DroidHintsToggle", function()
        require("droid.lsp.diagnostics").toggle_hints()
    end, {})

    cmd("DroidExportWorkspace", function()
        if not need_client() then
            return
        end
        client.run_command("exportWorkspace", { vim.fn.getcwd() }, function(err, result)
            vim.schedule(function()
                if err then
                    vim.notify("Export failed: " .. tostring(err), vim.log.levels.ERROR)
                    return
                end
                if not result then
                    return
                end
                vim.cmd "enew"
                local buf = vim.api.nvim_get_current_buf()
                local text = type(result) == "string" and result or vim.json.encode(result)
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
                vim.bo[buf].filetype = "json"
                vim.bo[buf].buftype = "nofile"
                vim.bo[buf].modified = false
            end)
        end)
    end, {})
end

return M
