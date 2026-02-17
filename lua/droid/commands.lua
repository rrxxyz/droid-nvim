local gradle = require "droid.gradle"
local android = require "droid.android"
local logcat = require "droid.logcat"
local actions = require "droid.actions"
local ktlint = require "droid.ktlint"

local M = {}

local active_command = nil

local function clear_active()
    active_command = nil
end

local function guarded(name, fn)
    if active_command then
        vim.notify(
            string.format(":%s is already running — wait for it to finish or stop it first", active_command),
            vim.log.levels.WARN
        )
        return
    end
    active_command = name
    fn(clear_active)
end

local function check_guard(name, fn)
    if active_command then
        vim.notify(
            string.format(":%s is running — %s blocked until it finishes", active_command, name),
            vim.log.levels.WARN
        )
        return
    end
    fn()
end

function M.setup_commands()
    vim.api.nvim_create_user_command("DroidRun", function()
        guarded("DroidRun", function(done)
            actions.build_and_run(done)
        end)
    end, {})

    vim.api.nvim_create_user_command("DroidBuild", function()
        guarded("DroidBuild", function(done)
            gradle.build(done)
        end)
    end, {})

    vim.api.nvim_create_user_command("DroidBuildVariant", function()
        gradle.select_variant()
    end, {})

    vim.api.nvim_create_user_command("DroidClean", function()
        guarded("DroidClean", function(done)
            gradle.clean(done)
        end)
    end, {})

    vim.api.nvim_create_user_command("DroidSync", function()
        guarded("DroidSync", function(done)
            gradle.sync(done)
        end)
    end, {})

    vim.api.nvim_create_user_command("DroidTask", function(opts)
        guarded("DroidTask", function(done)
            gradle.task(opts.fargs[1], table.concat(vim.list_slice(opts.fargs, 2), " "), done)
        end)
    end, { nargs = "+", complete = "shellcmd" })

    vim.api.nvim_create_user_command("DroidDevices", function()
        actions.show_devices()
    end, {})

    vim.api.nvim_create_user_command("DroidInstall", function()
        guarded("DroidInstall", function(done)
            actions.install_only(done)
        end)
    end, {})

    vim.api.nvim_create_user_command("DroidLogcat", function()
        check_guard("DroidLogcat", function()
            actions.logcat_only()
        end)
    end, {})

    vim.api.nvim_create_user_command("DroidLogcatStop", function()
        clear_active()
        logcat.stop()
    end, {})

    vim.api.nvim_create_user_command("DroidLogcatFilter", function(opts)
        local filters = {}

        for _, arg in ipairs(opts.fargs) do
            local key, value = arg:match "([^=]+)=([^=]+)"
            if key and value then
                filters[key] = value
            end
        end

        logcat.apply_filters(filters)
    end, {
        nargs = "*",
        complete = function(arg_lead, _, _)
            local completions = {
                "package=",
                "package=mine",
                "package=none",
                "log_level=v",
                "log_level=d",
                "log_level=i",
                "log_level=w",
                "log_level=e",
                "log_level=f",
                "tag=",
                "grep=",
            }

            local filtered = {}
            for _, comp in ipairs(completions) do
                if comp:find(arg_lead, 1, true) == 1 then
                    table.insert(filtered, comp)
                end
            end
            return filtered
        end,
    })

    vim.api.nvim_create_user_command("DroidGradleStop", function()
        clear_active()
        gradle.stop()
    end, {})

    vim.api.nvim_create_user_command("DroidEmulator", function()
        android.launch_emulator()
    end, {})

    vim.api.nvim_create_user_command("DroidEmulatorStop", function()
        android.stop_emulator()
    end, {})

    vim.api.nvim_create_user_command("DroidEmulatorCreate", function()
        android.create_emulator()
    end, {})

    -- ADB quick actions
    vim.api.nvim_create_user_command("DroidClearData", function()
        android.clear_app_data()
    end, {})

    vim.api.nvim_create_user_command("DroidForceStop", function()
        android.force_stop()
    end, {})

    vim.api.nvim_create_user_command("DroidUninstall", function()
        android.uninstall_app()
    end, {})

    vim.api.nvim_create_user_command("DroidMirror", function()
        android.mirror()
    end, {})

    vim.api.nvim_create_user_command("DroidKtlintFormat", function()
        guarded("DroidKtlintFormat", function(done)
            ktlint.format(done)
        end)
    end, {})

    vim.api.nvim_create_user_command("DroidKtlintUpdateJar", function()
        guarded("DroidKtlintUpdateJar", function(done)
            ktlint.update_jar(done)
        end)
    end, {})
end

return M
