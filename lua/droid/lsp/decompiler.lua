local client = require "droid.lsp.client"

local M = {}

--- URI schemes that kotlin-lsp can decompile.
M.schemes = { "jar", "jrt" }

--- Called from a BufReadCmd autocmd. Asks kotlin_ls to decompile the URI
--- and fills the buffer with the result.
---@param uri string  e.g. "jar:///path/to/lib.jar!/com/Foo.class"
function M.handle(uri)
    local buf = vim.api.nvim_get_current_buf()

    -- The LSP may still be starting — poll until it attaches or we time out.
    local attempts, limit = 0, 50 -- 50 * 200ms = 10s

    local function poll()
        attempts = attempts + 1
        if client.first { bufnr = buf } then
            M._decompile(buf, uri)
            return
        end
        if attempts >= limit then
            vim.notify("droid.nvim: kotlin_ls did not attach in time for decompilation", vim.log.levels.WARN)
            return
        end
        vim.defer_fn(poll, 200)
    end

    poll()
end

---@private
function M._decompile(buf, uri)
    client.run_command("decompile", { uri }, function(err, result)
        vim.schedule(function()
            if err or not result or result == "" then
                vim.notify(
                    "droid.nvim: decompile failed" .. (err and (": " .. tostring(err)) or ""),
                    vim.log.levels.ERROR
                )
                return
            end
            if not vim.api.nvim_buf_is_valid(buf) then
                return
            end

            -- JetBrains kotlin-lsp returns {code, language}; legacy returns a plain string
            local code = type(result) == "table" and result.code or result
            local lang = type(result) == "table" and result.language or nil

            if not code or code == "" then
                vim.notify("droid.nvim: decompile returned empty result", vim.log.levels.ERROR)
                return
            end

            local normalized = code:gsub("\r\n", "\n")
            vim.bo[buf].modifiable = true
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(normalized, "\n", { plain = true }))
            vim.bo[buf].modifiable = false
            vim.bo[buf].modified = false
            vim.bo[buf].buftype = "nofile"
            vim.bo[buf].swapfile = false
            vim.bo[buf].filetype = lang and lang:lower() or "kotlin"
        end)
    end, buf)
end

return M
