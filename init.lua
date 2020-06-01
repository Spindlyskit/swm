-- Copyright (c) 2020 Spindlyskit. All rights reserved.
-- This work is licensed under the terms of the MIT license. See LICENCE for details

-- Additional logging
require('hs.crash')
hs.crash.crashLogToNSLog = false

require('wm')

-- Hyper mode status
-- (Capslock is bound to f18 by Karabiner)
hyper = hs.hotkey.modal.new({}, 'F17')

function enterHyperMode()
    hyper.triggered = false
    hyper:enter()
end

function exitHyperMode()
    hyper:exit()
    -- Hyper works as an escape if not used as a modifier
    if not hyper.triggered then
        hs.eventtap.keyStroke({}, "ESCAPE")
    end
    wm.chord = false
end

hyperListener = hs.hotkey.bind({}, 'F18', enterHyperMode, exitHyperMode)
hyperListener = hs.hotkey.bind({ 'shift' }, 'F18', enterHyperMode, exitHyperMode)

-- Helper function
function toggleApp(id)
    local currentBundle = hs.application.frontmostApplication():bundleID()
    if currentBundle == id and hs.window.focusedWindow() ~= nil then
        hs.eventtap.keyStroke({ 'cmd' }, 'h')
        return
    end

    hs.application.launchOrFocusByBundleID(id)
    if id == 'com.apple.finder' then
        hs.appfinder.appFromName('Finder'):activate()
    end
end


-- Hyper application bindings
hyperAppBindings = {
    'return', 'com.googlecode.iterm2',
    'f', 'com.apple.finder',
    's', 'com.apple.safari',
}

for i = 1, #hyperAppBindings, 2 do
    hyper:bind({}, hyperAppBindings[i], function()
        toggleApp(hyperAppBindings[i + 1])
        hyper.triggered = true
    end)
end

-- Basic hyper bindings
hyper:bind({}, 'x', function()
    hs.caffeinate.lockScreen()
    hyper.triggered = true
end)

hyper:bind({ 'shift' }, 'x', function()
    hs.caffeinate.logOut()
    hyper.triggered = true
end)

-- Window management
hs.window.animationDuration = 0

hyper:bind({}, 'space', function()
    wm:maximize()
    hyper.triggered = true
end)

function simpleWMBind(key, op)
    hyper:bind({}, key, function()
        wm[op or key](wm)
        hyper.triggered = true
    end)
end

simpleWMBind('space', 'maximize')
simpleWMBind('up')
simpleWMBind('down')
simpleWMBind('left')
simpleWMBind('right')
simpleWMBind('c', 'center')
simpleWMBind('r', 'restore')
