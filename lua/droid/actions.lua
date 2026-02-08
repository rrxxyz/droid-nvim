local config = require "droid.config"
local gradle = require "droid.gradle"
local android = require "droid.android"
local logcat = require "droid.logcat"
local progress = require "droid.progress"

local M = {}

local function handle_post_install(tools, device_id, launch_app)
    local cfg = config.get()

    local function start_logcat()
        local delay_ms = cfg.android.logcat_startup_delay_ms or 2000
        vim.defer_fn(function()
            logcat.refresh_logcat(tools.adb, device_id, nil, nil)
            local message = launch_app and "Build, install, and launch completed" or "Build and install completed"
            vim.notify(message, vim.log.levels.INFO)
        end, delay_ms)
    end

    if launch_app then
        android.launch_app_on_device(tools.adb, device_id, start_logcat)
    else
        start_logcat()
    end
end

local function execute_build_install(tools, device_id, launch_app, on_complete)
    gradle.build_and_install(function(success, exit_code, message, step)
        if on_complete then
            on_complete()
        end

        if not success then
            vim.notify(string.format("Workflow failed at %s step: %s", step, message), vim.log.levels.ERROR)
            return
        end

        handle_post_install(tools, device_id, launch_app)
    end)
end

function M.get_required_tools()
    local adb = android.get_adb_path()
    local emulator = android.get_emulator_path()

    if not adb or not emulator then
        vim.notify("Android SDK tools not found. Check ANDROID_SDK_ROOT.", vim.log.levels.ERROR)
        return nil
    end

    return { adb = adb, emulator = emulator }
end

function M.select_target(tools, callback)
    if not tools then
        return
    end
    android.choose_target(tools.adb, tools.emulator, callback)
end

function M.build_and_run(on_complete)
    local tools = M.get_required_tools()
    if not tools then
        if on_complete then
            on_complete()
        end
        return
    end

    M.select_target(tools, function(target)
        if not target then
            if on_complete then
                on_complete()
            end
            return
        end

        if target.type == "device" then
            execute_build_install(tools, target.id, true, on_complete)
        elseif target.type == "avd" then
            progress.start_spinner "Starting emulator"
            android.start_emulator(tools.emulator, target.avd)
            android.wait_for_device_ready(tools.adb, function(device_id)
                progress.stop_spinner()
                if not device_id then
                    vim.notify("Failed to start emulator or device not ready", vim.log.levels.ERROR)
                    if on_complete then
                        on_complete()
                    end
                    return
                end
                execute_build_install(tools, device_id, true, on_complete)
            end)
        end
    end)
end

function M.install_only(on_complete)
    local tools = M.get_required_tools()
    if not tools then
        if on_complete then
            on_complete()
        end
        return
    end

    M.select_target(tools, function(target)
        if not target then
            if on_complete then
                on_complete()
            end
            return
        end

        if target.type == "device" then
            execute_build_install(tools, target.id, false, on_complete)
        elseif target.type == "avd" then
            progress.start_spinner "Starting emulator"
            android.start_emulator(tools.emulator, target.avd)
            android.wait_for_device_ready(tools.adb, function(device_id)
                progress.stop_spinner()
                if not device_id then
                    vim.notify("Failed to start emulator or device not ready", vim.log.levels.ERROR)
                    if on_complete then
                        on_complete()
                    end
                    return
                end
                execute_build_install(tools, device_id, false, on_complete)
            end)
        end
    end)
end

function M.logcat_only()
    local tools = M.get_required_tools()
    if not tools then
        return
    end

    logcat.apply_filters {}
end

function M.show_devices()
    local tools = M.get_required_tools()
    if not tools then
        return
    end

    M.select_target(tools, function(target)
        if not target then
            return
        end

        local msg = target.type == "device" and string.format("Selected device: %s (%s)", target.name, target.id)
            or string.format("Selected AVD: %s (%s)", target.name, target.avd)

        vim.notify(msg, vim.log.levels.INFO)
    end)
end

return M
