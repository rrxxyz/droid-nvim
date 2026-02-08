local gradle = require "droid.gradle"
local android = require "droid.android"
local logcat = require "droid.logcat"
local actions = require "droid.actions"

local M = {}

function M.setup_commands()
    vim.api.nvim_create_user_command("DroidRun", function()
        actions.build_and_run()
    end, {})

    vim.api.nvim_create_user_command("DroidBuild", function()
        gradle.build()
    end, {})

    vim.api.nvim_create_user_command("DroidBuildVariant", function()
        gradle.select_variant()
    end, {})

    vim.api.nvim_create_user_command("DroidClean", function()
        gradle.clean()
    end, {})

    vim.api.nvim_create_user_command("DroidSync", function()
        gradle.sync()
    end, {})

    vim.api.nvim_create_user_command("DroidTask", function(opts)
        gradle.task(opts.fargs[1], table.concat(vim.list_slice(opts.fargs, 2), " "))
    end, { nargs = "+", complete = "shellcmd" })

    vim.api.nvim_create_user_command("DroidDevices", function()
        actions.show_devices()
    end, {})

    vim.api.nvim_create_user_command("DroidInstall", function()
        actions.install_only()
    end, {})

    vim.api.nvim_create_user_command("DroidLogcat", function()
        actions.logcat_only()
    end, {})

    vim.api.nvim_create_user_command("DroidLogcatStop", function()
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
        gradle.stop()
    end, {})

    vim.api.nvim_create_user_command("DroidEmulator", function()
        android.launch_emulator()
    end, {})

    vim.api.nvim_create_user_command("DroidEmulatorStop", function()
        android.stop_emulator()
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
end

return M
