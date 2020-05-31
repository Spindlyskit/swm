-- Maximum time between keypresses in a chord
local maxChordTime = 0.3

wm = {}
wm.restore = {}
wm.pressed = {
    up = -1,
    down = -1,
    left = -1,
    right = -1,
    max = -1,
}
wm.lastPressTime = 0
wm.sizes = { 1/2, 1/3, 2/3 }
wm.maximizedSizes = { 1, 3/4 }

-- Update a window's position while handling restoring
function wm:updateWin(update)
    local win = hs.window.focusedWindow()
    if not win or not win:isStandard() then 
        return false
    end

    local f = win:frame()
    local max = win:screen():frame()

    update(max)

    win:setFrame(max)
    return true
end

function wm:maximize()
    self.pressed.up = (self.pressed.up + 1) % #self.maximizedSizes

    local newSize = self.maximizedSizes[self.pressed.up + 1]

    -- Don't waste time dividing by one
    if newSize == 1 then
        self:updateWin(function() end)
        return
    end

    local gapUnit = 1/2 * (1 - newSize)
    self:updateWin(function(f)
        f.x = f.w * gapUnit
        f.y = f.h * gapUnit
        f.w = f.w * newSize
        f.h = f.h * newSize
    end)
end
