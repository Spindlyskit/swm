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

-- Update a window's frame
function wm:updateWin(win, update)
    local max = win:screen():frame()

    update(max)

    win:setFrame(max)
end

-- Maximize a window (cycle through maximizedSizes)
function wm:maximize()
    local win = hs.window.focusedWindow()
    local newSize = getNewSize(win, directions.MAX, self.maximizedSizes)

    if not newSize then
        return false
    end

    if newSize == 1 then
        self:updateWin(win, function() end)
        return
    end

    local gapUnit = 1/2 * (1 - newSize)
    self:updateWin(win, function(f)
        f.x = f.x + f.w * gapUnit
        f.y = f.y + f.h * gapUnit
        f.w = f.w * newSize
        f.h = f.h * newSize
    end)
end

-- Snap a window to the top of the screen
function wm:up()
    local win = hs.window.focusedWindow()
    local newSize = getNewSize(win, directions.UP, self.sizes)

    if not newSize then
        return false
    end

    self:updateWin(win, function(f)
        f.h = newSize * f.h
    end)
end

-- Snap a window to the bottom of the screen
function wm:down()
    local win = hs.window.focusedWindow()
    local newSize = getNewSize(win, directions.DOWN, self.sizes)

    if not newSize then
        return false
    end

    self:updateWin(win, function(f)
        f.y = f.y + f.h * (1 - newSize)
        f.h = newSize * f.h
    end)
end

-- Snap a window to the left of the screen
function wm:left()
    local win = hs.window.focusedWindow()
    local newSize = getNewSize(win, directions.LEFT, self.sizes)

    if not newSize then
        return false
    end

    self:updateWin(win, function(f)
        f.w = f.w * newSize
    end)
end

-- Snap a window to the right of the screen
function wm:right()
    local win = hs.window.focusedWindow()
    local newSize = getNewSize(win, directions.RIGHT, self.sizes)

    if not newSize then
        return false
    end

    self:updateWin(win, function(f)
        f.x = f.x + f.w * (1 - newSize)
        f.w = f.w * newSize
    end)
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

    wm:updateWin(win, function(f)
        f.x = f.x + f.w / 2 - wf.w / 2
        f.y = f.y + f.h / 2 - wf.h / 2
        f.w = wf.w
        f.h = wf.h
    end)
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

    self:updateWin(win, function(f)
        f.x = windowState.restore.x
        f.y = windowState.restore.y
        f.w = windowState.restore.w
        f.h = windowState.restore.h
    end)
end