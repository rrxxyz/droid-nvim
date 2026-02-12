local M = {}

local LSP_NAME = "kotlin_ls"

---@param filter? {bufnr?: number}
---@return vim.lsp.Client[]
function M.all(filter)
    local opts = { name = LSP_NAME }
    if filter and filter.bufnr then
        opts.bufnr = filter.bufnr
    end
    return vim.lsp.get_clients(opts)
end

---@param filter? {bufnr?: number}
---@return vim.lsp.Client|nil
function M.first(filter)
    local list = M.all(filter)
    return list[1]
end

--- Send workspace/executeCommand to the first attached kotlin_ls.
---@param cmd_name string   e.g. "kotlin.decompile"
---@param args? table       command arguments
---@param cb fun(err: any, result: any)
---@param bufnr? number
function M.run_command(cmd_name, args, cb, bufnr)
    bufnr = bufnr or 0
    local c = M.first { bufnr = bufnr }
    if not c then
        cb("kotlin_ls not attached", nil)
        return
    end
    c:request("workspace/executeCommand", { command = cmd_name, arguments = args or {} }, function(err, result)
        cb(err, result)
    end, bufnr)
end

return M
