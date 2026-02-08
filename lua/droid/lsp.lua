local config = require "droid.config"

local M = {}

function M.setup()
    local cfg = config.get()
    if not cfg.lsp or not cfg.lsp.enabled then
        return
    end

    if not vim.lsp.config then
        vim.notify("droid.nvim: Kotlin LSP requires Neovim 0.11+", vim.log.levels.WARN)
        return
    end

    local cmd = cfg.lsp.cmd or { "kotlin-lsp" }

    -- Prefer local binary if available
    if type(cmd) == "table" and vim.fn.executable(cmd[1]) == 1 then
        vim.lsp.config("kotlin_lsp", {
            cmd = cmd,
            filetypes = { "kotlin" },
            root_markers = { "build.gradle", "build.gradle.kts", "pom.xml" },
        })
        vim.lsp.enable("kotlin_lsp")
        return
    end

    -- TCP connections (cmd is a function) — use directly
    if type(cmd) == "function" then
        vim.lsp.config("kotlin_lsp", {
            cmd = cmd,
            filetypes = { "kotlin" },
            root_markers = { "build.gradle", "build.gradle.kts", "pom.xml" },
        })
        vim.lsp.enable("kotlin_lsp")
        return
    end

    -- Fall back to nvim-lspconfig
    local has_lspconfig = pcall(require, "lspconfig")
    if has_lspconfig then
        vim.lsp.enable("kotlin_lsp")
    end
end

return M
