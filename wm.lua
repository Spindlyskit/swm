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

-- Update a window's position while handling restoring
function wm:updateWin(win, update)
    local max = win:screen():frame()

    update(max)

    win:setFrame(max)
end

-- Maximize a window (cycle through maxmizedSizes)
function wm:maximize()
    local win = hs.window.focusedWindow()

    if shouldIgnoreWin(win) then
        return false
    end

    local id = win:id()
    local windowState = self.windows[id]

    if not windowState then
        windowState = addWindowState(win, id)
    end
    
    updateDirection(win, id, directions.UP, #self.maximizedSizes)

    newSize = self.maximizedSizes[windowState.directionCounter + 1]

    -- Don't waste time dividing by one
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