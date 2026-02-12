local M = {}

--- Run `java -version` and extract the major version number.
--- Output goes to stderr and looks like: openjdk version "21.0.2" 2024-01-16
---@param java_bin string
---@return number|nil major_version
---@return string|nil raw_output
local function get_version(java_bin)
    local proc = vim.system({ java_bin, "-version" }, { text = true }):wait()
    local raw = (proc.stderr or "") .. (proc.stdout or "")
    if proc.code ~= 0 or raw == "" then
        return nil, raw
    end

    local quoted = raw:match '"([^"]+)"'
    if not quoted then
        return nil, raw
    end

    local first = tonumber(quoted:match "^(%d+)")
    if not first then
        return nil, raw
    end

    -- Pre-Java 9 used 1.x scheme (e.g. 1.8 = Java 8)
    if first == 1 then
        return tonumber(quoted:match "^1%.(%d+)"), raw
    end
    return first, raw
end

--- Check that `java_bin` is at least Java 21.
---@param java_bin string
---@return boolean
---@return string|nil err
function M.check(java_bin)
    local ver, raw = get_version(java_bin)
    if not ver then
        return false, "Could not determine Java version from: " .. (raw or java_bin):sub(1, 100)
    end
    if ver < 21 then
        return false, string.format("Java %d found — kotlin-lsp needs 21+", ver)
    end
    return true, nil
end

return M
