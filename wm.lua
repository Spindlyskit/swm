-- Copyright (c) 2020 Spindlyskit. All rights reserved.
-- This work is licensed under the terms of the MIT license. See LICENCE for details

-- Maximum time between keypresses in a chord
local maxChordTime = 0.3
local events = hs.uielement.watcher
local directions = {
    NONE = 0,
    UP = 1,
    DOWN = 2,
    LEFT = 3,
    RIGHT = 4,
    MAX = 5,
    -- Moved by the wm but not resized
    MOVED = 6,
}

wm = {}
-- Store state of open windows
wm.windows = {}
-- Last window manager keybind time
wm.lastPressTime = 0
-- Sizes windows can take
wm.sizes = { 1/2, 1/3, 2/3 }
wm.maximizedSizes = { 1, 3/4 }

-- Handle window events
local function handleWindowEvent(win, event, watcher, info)
    if event == events.elementDestroyed then
        print('wm: Window destroy on ' .. info.id)
        wm.windows[info.id] = nil
        watcher:stop()
        return
    end
end

-- Start tracking state for a window and add a watcher to destroy it on close
local function addWindowState(win, id)
    local windowState = {}
    -- The last snap direction
    windowState.direction = directions.NONE
    -- Number of times that direction has been pushed
    windowState.directionCounter = 0
    -- The window state before it became managed
    windowState.restore = win:frame()
    wm.windows[id] = windowState

    print('wm: Now managing window ' .. id)

    local watcher = win:newWatcher(handleWindowEvent, { pid = win:pid(), id = id })
    watcher:start({ events.elementDestroyed })

    return windowState
end

-- Update the direction and directionCounter
local function updateDirection(win, id, direction, mod)
    local windowState = wm.windows[id]

    if windowState.direction == direction then
        windowState.directionCounter = (windowState.directionCounter + 1) % mod
    else
        if windowState.direction == directions.NONE then
            windowState.restore = win:frame()
        end

        windowState.direction = direction
        windowState.directionCounter = 0
    end
end

local function shouldIgnoreWin(win)
    return not win or not win:isStandard()
end

-- Get the new size multiplier of a window
local function getNewSize(win, direction, sizes)
    if shouldIgnoreWin(win) then
        return nil
    end

    local id = win:id()
    local windowState = wm.windows[id]

    if not windowState then
        windowState = addWindowState(win, id)
    end

    updateDirection(win, id, direction, #sizes)

    return sizes[windowState.directionCounter + 1]
end

-- Snap positioning functions
local function snapMax(f, newSize)
    local gapUnit = 1/2 * (1 - newSize)
    f.x = f.x + f.w * gapUnit
    f.y = f.y + f.h * gapUnit
    f.w = f.w * newSize
    f.h = f.h * newSize
end

local function snapUp(f, newSize)
    f.h = newSize * f.h
end

local function snapDown(f, newSize)
    f.y = f.y + f.h * (1 - newSize)
    f.h = newSize * f.h
end

local function snapLeft(f, newSize)
    f.w = f.w * newSize
end

local function snapRight(f, newSize)
    f.x = f.x + f.w * (1 - newSize)
    f.w = f.w * newSize
end

local snapDirections = {
    [directions.MAX] = snapMax,
    [directions.UP] = snapUp,
    [directions.DOWN] = snapDown,
    [directions.LEFT] = snapLeft,
    [directions.RIGHT] = snapRight,
}

function wm:snap(direction, sizes)
    sizes = sizes or self.sizes
    local win = hs.window.focusedWindow()
    local newSize = getNewSize(win, direction, sizes)

    if not newSize then
        return false
    end

    local frame = win:screen():frame()

    if not snapDirections[direction] then
        return
    end

    snapDirections[direction](frame, newSize)

    win:setFrame(frame)
end

-- Put a window in the center of the screen
function wm:center()
    local win = hs.window.focusedWindow()

    if shouldIgnoreWin(win) then
        return nil
    end

    local id = win:id()
    local windowState = wm.windows[id]

    if not windowState then
        windowState = addWindowState(win, id)
    end

    updateDirection(win, id, directions.MOVED, 1)

    local wf = win:frame()
    local f = win:screen():frame()

    f.x = f.x + f.w / 2 - wf.w / 2
    f.y = f.y + f.h / 2 - wf.h / 2
    f.w = wf.w
    f.h = wf.h

    win:setFrame(f)
end

-- Restore a window to its inital position
function wm:restore()
    local win = hs.window.focusedWindow()

    if shouldIgnoreWin(win) then
        return false
    end

    local id = win:id()
    local windowState = self.windows[id]

    if not windowState then
        return false
    end

    updateDirection(win, id, directions.NONE, 1)

    win:setFrame(windowState.restore)
end

-- Shortcuts
function wm:maximize() wm:snap(directions.MAX, self.maximizedSizes) end
function wm:up() wm:snap(directions.UP, self.sizes) end
function wm:down() wm:snap(directions.DOWN, self.sizes) end
function wm:left() wm:snap(directions.LEFT, self.sizes) end
function wm:right() wm:snap(directions.RIGHT, self.sizes) end
