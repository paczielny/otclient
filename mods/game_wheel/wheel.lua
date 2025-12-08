WheelDestiny.disable = function()
    for _, widget in ipairs(WheelDestiny.UI.main.wheel.base.front:getChildren()) do
        if widget:getId() ~= "base" then
            widget.hover:setVisible(false)
        end
    end

    for side, _ in pairs(WheelDestiny.Sides) do
        local widget = WheelDestiny.UI.main.wheel.base[side]
        widget.hover:setVisible(false)
        widget.socketHover:setVisible(false)
    end
end

WheelDestiny.Init = function()
    WheelDestiny.UI = g_ui.displayUI("wheel")
    g_ui.loadUI("categories/wheel_of_destiny_selection")

    WheelDestiny.UI.main.wheel = g_ui.loadUI("categories/wheel_of_destiny", WheelDestiny.UI.main)
    WheelDestiny.UI.main.gem = g_ui.loadUI("categories/gem_atelier", WheelDestiny.UI.main)
    WheelDestiny.UI.main.fragment = g_ui.loadUI("categories/fragment_workshop", WheelDestiny.UI.main)
    WheelDestiny.PresetNew = g_ui.displayUI("presets/preset_new")
    WheelDestiny.PresetRename = g_ui.displayUI("presets/preset_rename")

    WheelDestiny.PresetInit()

    WheelDestiny.UI:hide()
    WheelDestiny.UI.main.wheel:hide()
    WheelDestiny.UI.main.gem:hide()
    WheelDestiny.UI.main.fragment:hide()
    
    WheelDestiny.PresetNew:hide()
    WheelDestiny.PresetRename:hide()

    Gem_Atelier.UI = WheelDestiny.UI.main.gem
    Gem_Atelier.activeQualityFilter = 1
    Gem_Atelier.activeAffinityFilter = 1

    Fragment_Workshop.UI = WheelDestiny.UI.main.fragment
    Fragment_Workshop.LesserFragments = {}
    Fragment_Workshop.GreaterFragments = {}
    Fragment_Workshop.Fragments = {
        [1] = {},
        [2] = {}
    }

    WheelDestiny.ActivedGem = {
        [0] = nil,
        [1] = nil,
        [2] = nil,
        [3] = nil
    }

    WheelDestiny.ActivedGemSlots = {
        [0] = { [1] = nil, [2] = nil, [3] = nil},
        [1] = { [1] = nil, [2] = nil, [3] = nil},
        [2] = { [1] = nil, [2] = nil, [3] = nil},
        [3] = { [1] = nil, [2] = nil, [3] = nil}
    }

    WheelDestiny.hoverVerify = false
    WheelDestiny.preview = false
    WheelDestiny.state = 0
    WheelDestiny.slots = {}
    WheelDestiny.usedPoints = 0
    WheelDestiny.availablePoints = 0
    WheelDestiny.totalPoints = 0
    WheelDestiny.vocation = 1
    WheelDestiny.sidePoints = {
        ["topLeft"] = {
            points = 0
        },
        ["topRight"] = {
            points = 0
        },
        ["bottomLeft"] = {
            points = 0
        },
        ["bottomRight"] = {
            points = 0
        }
    }

    WheelDestiny.Resources = {
        [0] = 0,
        [81] = 0,
        [82] = 0,
        [83] = 0,
        [84] = 0,
        [85] = 0
    }

    WheelDestiny.ExternalPreset = {}
    WheelDestiny.InternalPreset = {}
    WheelDestiny.CurrentPreset = {}

    WheelDestiny.Button = modules.game_mainpanel.addToggleButton("wheelButton", tr('Open Wheel of Destiny'),
            "/images/options/wheel", function()
        WheelDestiny.Toggle(true)
    end, false, 6, true)

    connect(g_game, {
        onGameStart = WheelDestiny.OnStart,
        onGameEnd = WheelDestiny.OnEnd,
        onParseWheelOfDestiny = WheelDestiny.onParseWheelOfDestiny,
        onParseWheelGems = WheelDestiny.onParseWheelGems,
        onParseWheelFragments = WheelDestiny.onParseWheelFragments,
        onResourceBalance = WheelDestiny.onResourceBalance
    })

    WheelDestiny.UI.main.wheel.onMouseMove = function(self, mousePosition)
        if WheelDestiny.hoverVerify then
            local clickedWidget = self:recursiveGetChildByPos(mousePosition)
            if not clickedWidget then
                WheelDestiny.disable()
                WheelDestiny.UI.main.wheel.test.informationBox:setVisible(false)
                if not WheelDestiny.UI.main.wheel.test.presetBox:isVisible() then
                    WheelDestiny.UI.main.wheel.test.defaultBox:setVisible(true)
                end
                WheelDestiny.hoverVerify = false
                WheelDestiny.hoverWidget = nil
            else
                if not WheelDestiny.UI.main.wheel.test.presetBox:isVisible() then
                    WheelDestiny.UI.main.wheel.test.informationBox:setVisible(true)
                    WheelDestiny.UI.main.wheel.test.defaultBox:setVisible(false)
                end
                WheelDestiny.updateHoverInformation()
            end
        end
    end

    WheelDestiny.changeOption(WheelDestiny.UI.main.wheel.test.buttons.information, true)
    WheelDestiny.changeHome(WheelDestiny.UI.buttons.wheelButton, true)

    for _, slots in pairs(WheelDestiny.UI.main.wheel.base.selectors.front:getChildren()) do
        slots:setPhantom(true)
        for slotId, slotItem  in pairs(slots:getChildren()) do
            if slotItem:getId() ~= "selected" then
                slotItem:destroy()
            end
        end
    end

    if g_game.isOnline() then
        if WheelDestiny.UI:isVisible() then 
            WheelDestiny.Toggle()
        end
    end
end

WheelDestiny.Terminate = function()
    disconnect(g_game, {
        onGameStart = WheelDestiny.OnStart,
        onGameEnd = WheelDestiny.OnEnd,
        onParseWheelOfDestiny = WheelDestiny.onParseWheelOfDestiny,
        onParseWheelGems = WheelDestiny.onParseWheelGems,
        onParseWheelFragments = WheelDestiny.onParseWheelFragments,
        onResourceBalance = WheelDestiny.onResourceBalance
    })

    WheelDestiny.UI.main.wheel = nil
    WheelDestiny.UI:destroy()
end

WheelDestiny.OnStart = function()
end

WheelDestiny.OnEnd = function()
    WheelDestiny.reset()
    Gem_Atelier.reset()
    WheelDestiny.Toggle()

    if WheelDestiny.PresetNew then
        WheelDestiny.PresetNew:unlock()
        WheelDestiny.PresetNew:hide()
    end

    if WheelDestiny.PresetRename then
        WheelDestiny.PresetRename:unlock()
        WheelDestiny.PresetRename:hide()
    end
end

WheelDestiny.changeHome = function(self, force)
    local options = {
        ["wheelButton"] = "wheel",
        ["gemButton"] = "gem",
        ["fragmentButton"] = 'fragment'
    }

    local parent = self:getParent()
    for _, child in pairs(parent:getChildren()) do
        child:setChecked(false)

        local option = options[child:getId()]
        if option then
            WheelDestiny.UI.main[option]:hide()
        end
    end

     local option = options[self:getId()]
     if option then
        WheelDestiny.UI.main[option]:show()
     end
    
    self:setChecked(true)
end

WheelDestiny.onParseWheelGems = function(gems, revealedGems)
    Gem_Atelier.onReceiveData(gems, revealedGems, WheelDestiny.vocation)
end

WheelDestiny.onParseWheelFragments = function(lesserFragments, greaterFragments)
    Fragment_Workshop.onReceiveData(lesserFragments, greaterFragments)
end

WheelDestiny.onResourceBalance = function(type, balance)
    if WheelDestiny.Resources[type] then
        WheelDestiny.Resources[type] = balance

        Gem_Atelier.updateBalance()
        WheelDestiny.updateBalance()
        Fragment_Workshop.updateBalance()
    end
end