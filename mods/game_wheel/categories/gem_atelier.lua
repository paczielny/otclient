local sides = {
    [0] = "topLeft",
    [1] = "topRight",
    [2] = "bottomLeft",
    [3] = "bottomRight"
}

Gem_Atelier.getGemAttribute = function(index)
    local attributes = {
        [1] = "firstAttribute",
        [2] = "secondAttribute",
        [3] = "thirdAttribute"
    }

    return attributes[index]
end

local function getGemsSize(data)
    local count = 0
    if data.firstAttribute then
        count = count + 1
    end

    if data.secondAttribute then
        count = count + 1
    end

    if data.thirdAttribute then
        count = count + 1
    end

    return count
end

local function getHoverRect(tier)
    local hovers = {
        [0] = 4,
        [1] = 5,
        [2] = 6,
        [3] = 7
    }
    return hovers[tier]
end

Gem_Atelier.onLock = function()
    local widget = Gem_Atelier.SelectedGem.widget
    g_game.requestWheelGemAction(3, tonumber(widget:getId()))
end

Gem_Atelier.updateFilters = function()
    if not Gem_Atelier.UI then
        return
    end

    local gems = Gem_Atelier.UI.gems
    local showAllQuality = Gem_Atelier.activeQualityFilter == 1
    local showAllAffinity = Gem_Atelier.activeAffinityFilter == 1
    local lockedOnly = Gem_Atelier.UI.lockedCheck:isChecked()
    local first = nil

    local qualityOptions = {
        [2] = 0,
        [3] = 1,
        [4] = 2
    }

    local affinityOptions = {
        [2] = 0,
        [3] = 1,
        [4] = 2,
        [5] = 3
    }

    for _, widget in pairs(gems:getChildren()) do
        local passesQualityFilter = showAllQuality or (qualityOptions[Gem_Atelier.activeQualityFilter] == widget.data.object.quality)
        local passesAffinityFilter = showAllAffinity or (affinityOptions[Gem_Atelier.activeAffinityFilter] == widget.data.object.affinity)

        local passesLockedFilter = not lockedOnly or widget.locked:isOn()

        if passesQualityFilter and passesAffinityFilter and passesLockedFilter then
            if not first then
                first = widget
            end
            widget:setVisible(true)
            widget.data.visible = true
        else
            widget:setVisible(false)
            widget.data.visible = false
        end
    end

    if first then
        Gem_Atelier.onSelectGem(first)

        Gem_Atelier.UI.view.selectedEmpty:setVisible(false)
        Gem_Atelier.UI.view.selected:setVisible(true)
    else
        Gem_Atelier.UI.view.selectedEmpty:setVisible(true)
        Gem_Atelier.UI.view.selected:setVisible(false)
    end

    local count = 0
    local widgetsPerPage = 15
    Gem_Atelier.Info.pages = 1
    Gem_Atelier.Info.actualPage = 1

    for _, child in ipairs(gems:getChildren()) do
        if child.data.visible then
            count = count + 1
            child.data.page = math.ceil(count / widgetsPerPage)
    
            if child.data.page > Gem_Atelier.Info.pages then
                Gem_Atelier.Info.pages = child.data.page
            end
        end

        if child.data.page ~= Gem_Atelier.Info.actualPage then
            child:setVisible(false)
        end
    end
    
    Gem_Atelier.Info.count = count
    Gem_Atelier.updatePage()
end

Gem_Atelier.onLockedFilter = function()
    Gem_Atelier.updateFilters()
end

Gem_Atelier.onQualityFilter = function(option)
    Gem_Atelier.activeQualityFilter = option
    Gem_Atelier.updateFilters()
end

Gem_Atelier.onAffinityFilter = function(option)
    Gem_Atelier.activeAffinityFilter = option
    Gem_Atelier.updateFilters()
end

Gem_Atelier.reset = function()
    WheelDestiny.ActivedGemSlots = {
        [0] = { [1] = nil, [2] = nil, [3] = nil},
        [1] = { [1] = nil, [2] = nil, [3] = nil},
        [2] = { [1] = nil, [2] = nil, [3] = nil},
        [3] = { [1] = nil, [2] = nil, [3] = nil}
    }

    Gem_Atelier.SelectedGem = nil
    for i = 0, 3 do
        local side = sides[i]
        local gem = Gem_Atelier.UI.vessels.base[side].gem
        local border = Gem_Atelier.UI.vessels.base[side.."Border"]

        gem:setVisible(false)
        border:setVisible(false)

        WheelDestiny.ActivedGem[i] = nil
    end

    WheelDestiny.updateGems()
    WheelDestiny.updateSockets()
    WheelDestiny.updateWheelGem()
    WheelDestiny.updateProgress(false, true)
end

Gem_Atelier.onVesselAction = function()
    local data = Gem_Atelier.SelectedGem.data
    local widget = Gem_Atelier.SelectedGem.widget
    local selected = Gem_Atelier.UI.view.selected

    local side = sides[data.object.affinity]
    if data.selected then
        Gem_Atelier.onRemoveVessel(widget, side)
        selected.placeButton:setText("Place in Vessel")

        Gem_Atelier.UI.view.selected.switchButton:setEnabled(true)
        Gem_Atelier.UI.view.selected.dismantleButton:setEnabled(true)
    else
        Gem_Atelier.onPlaceVessel(data, widget, side)
        selected.placeButton:setText("Remove from Vessel")

        Gem_Atelier.UI.view.selected.switchButton:setEnabled(false)
        Gem_Atelier.UI.view.selected.dismantleButton:setEnabled(false)
    end

    WheelDestiny.UI.main.applyButton:setEnabled(true)
    WheelDestiny.UI.main.okButton:setEnabled(true)
end

Gem_Atelier.onRemoveVessel = function(widget, side)
    local gem = Gem_Atelier.UI.vessels.base[side].gem
    local border = Gem_Atelier.UI.vessels.base[side.."Border"]

    widget.data.selected = false
    gem:setVisible(false)
    widget.affinity:setVisible(false)
    border:setVisible(false)

    WheelDestiny.ActivedGem[widget.data.object.affinity] = nil

    WheelDestiny.updateGems()
    WheelDestiny.updateSockets()
    WheelDestiny.updateWheelGem()
    WheelDestiny.updateProgress(false, true)
    Fragment_Workshop.updateActivedMods()
end

Gem_Atelier.onPlaceVessel = function(data, widget, side, load)
    if not load then
        local activedGem = WheelDestiny.ActivedGem[data.object.affinity]
        if activedGem then
            Gem_Atelier.onRemoveVessel(activedGem, side)
        end
    end

    local gem = Gem_Atelier.UI.vessels.base[side].gem
    local border = Gem_Atelier.UI.vessels.base[side.."Border"]
    
    widget.data.selected = true
    gem:setImageClip(torect(string.format("%d %d %d %d", (32 * data.details.clip), 0, 32, 32)))
    gem:setVisible(true)
    widget.affinity:setVisible(true)
    border:setVisible(true)

    WheelDestiny.ActivedGem[widget.data.object.affinity] = widget
    WheelDestiny.updateGems()
    WheelDestiny.updateSockets()
    WheelDestiny.updateWheelGem()
    WheelDestiny.updateProgress(false, true)

    if not load then
        WheelDestiny.UI.main.applyButton:setEnabled(true)
        WheelDestiny.UI.main.okButton:setEnabled(true)
        Fragment_Workshop.updateActivedMods()
    end
end

Gem_Atelier.resetBorderVessel = function()
    for _, side in pairs(sides) do
        local border = Gem_Atelier.UI.vessels.base[side.."Border"]
        border:setVisible(false)
    end
end

Gem_Atelier.onSelectGem = function(widget)
    if widget:isChecked() then
        return
    end

    local data = widget.data
    if not data then
        return
    end
    local parent = widget:getParent()
    local UI = Gem_Atelier.UI.view.selected

    for _, child in pairs(parent:getChildren()) do
        child:setChecked(false)
    end
    
    widget:setChecked(true)
    UI.gemText:setText(data.details.name)

    local side = sides[data.object.affinity]
    local vesselBorder = Gem_Atelier.UI.vessels.base[side.."Border"]
    Gem_Atelier.SelectedGem = {
        data = data,
        widget = widget
    }

    Gem_Atelier.resetBorderVessel()
    vesselBorder:setVisible(data.selected)

    if data.selected then
        UI.placeButton:setText("Remove from Vessel")
    else
        UI.placeButton:setText("Place in Vessel")
    end

    local state = WheelDestiny.state == 1
    local enabled = state and not widget.locked:isOn()

    UI.placeButton:setEnabled(state)
    UI.dismantleButton:setEnabled(enabled)
    UI.switchButton:setEnabled(enabled)

    UI.gem:setImageClip(torect(string.format("%d %d %d %d", (32 * data.details.clip), 0, 32, 32)))
    UI.affinity:setImageClip(torect(string.format("%d %d %d %d", (26 * data.object.affinity), 0, 26, 26)))
    UI.price.value:setText(Gem_Atelier.SwitchPrice[data.object.quality])

    local activedGem = WheelDestiny.ActivedGem[data.object.affinity]
    if activedGem then
        if activedGem:getId() == widget:getId() then
            UI.switchButton:setEnabled(false)
            UI.dismantleButton:setEnabled(false)
        end
    end

    UI.mods:destroyChildren()

    for i = 1, widget.data.size do
        local attribute = Gem_Atelier.getGemAttribute(i)
        local clip = data.object[attribute]
        local grade = 0

        local gem = g_ui.createWidget("GemView", UI.mods)

        gem.base.onHoverChange = function(self, hovered)
            local hover = getHoverRect(0)
            gem.hover:setImageClip(torect(string.format("%d %d %d %d", (50 * hover), 0, 50, 50)))
            gem.hover:setVisible(hovered)
        end

        gem:setEnabled(false)

        if i == 3 then
            gem.base.mod:setImageSource("/mods/game_wheel/images/icons-skillwheel-suprememods")
            gem.base.mod:setSize({ width = 35, height = 35 })
            gem.base.mod:setImageClip(torect(string.format("%d %d %d %d", (35 * clip), 0, 35, 35)))
            gem.base.mod:setMarginBottom(2)
            gem.base.mod:setMarginLeft(2)
            grade = Fragment_Workshop.GreaterFragments[clip] or 0
        else
            gem.base.mod:setImageSource("/mods/game_wheel/images/icons-skillwheel-basicmods")
            gem.base.mod:setImageClip(torect(string.format("%d %d %d %d", (30 * clip), 0, 30, 30)))
            grade = Fragment_Workshop.LesserFragments[clip] or 0
        end

        gem.base:setImageClip(torect(string.format("%d %d %d %d", (50 * grade), 0, 50, 50)))

        local descriptions = nil
        if i == 3 then
            descriptions = Fragment_Workshop.Supreme_Modifiers[clip].descriptions
        else
            descriptions = Fragment_Workshop.Basic_Modifiers[clip].descriptions
        end

        if not descriptions then
            return
        end
        
        gem.descriptions:destroyChildren()
        for _, description in ipairs(descriptions) do
            local widgetDescription = g_ui.createWidget("ModGemDescription", gem.descriptions)
            widgetDescription:setText(string.format("%s %s", description.values[grade], description.text))
        end

    end
end

Gem_Atelier.onVesselFilter = function(action)
    local affinityFilter = {
        [0] = "Top Left",
        [1] = "Top Right",
        [2] = "Bottom Left",
        [3] = "Bottom Right"
    }

    local qualityFilter = {
        [0] = "Lesser",
        [1] = "Regular",
        [2] = "Greater"
    }

    Gem_Atelier.UI.affinityFilter:setCurrentOption(affinityFilter[action])
    local widget = WheelDestiny.ActivedGem[action]
    if widget and widget.data then
        local quality = widget.data.object.quality
        Gem_Atelier.UI.qualityFilter:setCurrentOption(qualityFilter[quality])
    end
end

Gem_Atelier.onSelectPage = function(action)
    local gems = Gem_Atelier.UI.gems

    if action == 1 then
        Gem_Atelier.Info.actualPage = Gem_Atelier.Info.actualPage + 1
    else
        Gem_Atelier.Info.actualPage = Gem_Atelier.Info.actualPage - 1
    end

    for _, child in ipairs(gems:getChildren()) do
        if child.data.visible then
            if child.data.page ~= Gem_Atelier.Info.actualPage then
                child:setVisible(false)
            else
                child:setVisible(true)
            end
        end
    end
    Gem_Atelier.updatePage()
end

Gem_Atelier.updatePage = function()
    local nextButton = Gem_Atelier.UI.nextButton
    local prevButton = Gem_Atelier.UI.prevButton

    if Gem_Atelier.Info.actualPage <= 1 then
        Gem_Atelier.Info.actualPage = 1

        prevButton:setEnabled(false)
        if Gem_Atelier.Info.pages <= 1 then
            nextButton:setEnabled(false)
        else
            nextButton:setEnabled(true)
        end
    else
        prevButton:setEnabled(true)

        if Gem_Atelier.Info.actualPage >= Gem_Atelier.Info.pages then
            nextButton:setEnabled(false)
        else
            nextButton:setEnabled(true)
        end
    end

    local info = Gem_Atelier.Info
    Gem_Atelier.UI.pageCount:setText(string.format("Page %d / %d (%d Gems)", info.actualPage, info.pages, info.count))
end

Gem_Atelier.getAffinityName = function(id)
    local affinities = {
        [0] = "topLeft",
        [1] = "topRight",
        [2] = "bottomLeft",
        [3] = "bottomRight"
    }

    if not affinities[id] then
        return nil
    end

    return affinities[id]
end

Gem_Atelier.updateBalance = function()
    local gemData = Gem_Atelier.VocationGems[WheelDestiny.vocation]
    if not gemData then
        return
    end

    local revelation = Gem_Atelier.UI.revelation
    if not revelation then
        return
    end

    local lesser = WheelDestiny.Resources[81] or 0
    local medium = WheelDestiny.Resources[82] or 0
    local greater = WheelDestiny.Resources[83] or 0
    local gold = WheelDestiny.Resources[0] or 0

    for index, value in ipairs(gemData) do
        if index == 1 and revelation.first then
            local enabled = gold >= 125000
            revelation.first:setItemId(value.item)
            revelation.firstText:setText(string.format("%s\nGem (x %d)", value.name, lesser))
            revelation.firstGold.value:setEnabled(enabled)
            revelation.firstReveal:setEnabled(enabled and lesser > 0)
        elseif index == 2 and revelation.second then
            local enabled = gold >= 1000000
            revelation.second:setItemId(value.item)
            revelation.secondText:setText(string.format("%s\nGem (x %d)", value.name, medium))
            revelation.secondGold.value:setEnabled(enabled)
            revelation.secondReveal:setEnabled(enabled and medium > 0)
        elseif index == 3 and revelation.third then
            local enabled = gold >= 6000000
            revelation.third:setItemId(value.item)
            revelation.thirdText:setText(string.format("%s\nGem (x %d)", value.name, greater))
            revelation.thirdGold.value:setEnabled(enabled)
            revelation.thirdReveal:setEnabled(enabled and greater > 0)
        end
    end

    local view = Gem_Atelier.UI.view
    if view and view.selected and view.selected.price and view.selected.price.value then
        view.selected.price.value:setEnabled(gold >= 125000)
    end
end


Gem_Atelier.revealGem = function(type)
    g_game.requestWheelGemAction(1, type)
end

Gem_Atelier.dismantleGem = function()
    local widget = Gem_Atelier.SelectedGem.widget
    g_game.requestWheelGemAction(0, tonumber(widget:getId()))
end

Gem_Atelier.switchGem = function()
    local widget = Gem_Atelier.SelectedGem.widget
    g_game.requestWheelGemAction(2, tonumber(widget:getId()))
end

Gem_Atelier.updateModsGrades = function()
    local gems = Gem_Atelier.UI.gems
    for _, widget in pairs(gems:getChildren()) do
        local data = widget.data
        if data and data.visible then
            for _, child in pairs(widget.gems:getChildren()) do
                if child.quality == 3 then

                else
                    local grade = Fragment_Workshop.LesserFragments[child.clip]
                    if grade then
                        child.base:setImageClip(torect(string.format("%d %d %d %d", (50 * grade), 0, 50, 50)))
                        child.grade = grade
                    end
                end
            end
        end
    end
end

Gem_Atelier.onReceiveData = function(activedGems, revealedGems, vocation)
    if not revealedGems or not vocation then
        return
    end

    local gems = Gem_Atelier.UI.gems
    if not gems then
        return
    end

    Gem_Atelier.reset()

    Gem_Atelier.Info = {
        actualPage = 1,
        pages = 1,
        count = #revealedGems
    }

    gems:destroyChildren()
    for id, data in ipairs(revealedGems) do
        local widget = g_ui.createWidget("GemWindow", gems)
        if not (data.affinity and data.quality and Gem_Atelier.Gems[vocation] and Gem_Atelier.Gems[vocation][data.affinity] and Gem_Atelier.Gems[vocation][data.affinity][data.quality]) then
            widget:setVisible(false)
            goto continue
        end

        local details = Gem_Atelier.Gems[vocation][data.affinity][data.quality]
        local size = getGemsSize(data)

        widget.data = {
            size = size,
            details = details,
            page = Gem_Atelier.Info.pages,
            visible = true,
            selected = false,
            object = data
        }

        widget.affinity:setImageClip(torect(string.format("%d %d %d %d", (26 * data.affinity), 0, 26, 26)))
        widget.locked:setOn(data.locked == 1)

        widget.data.page = math.ceil(id / 15)
        if widget.data.page > Gem_Atelier.Info.pages then
            Gem_Atelier.Info.pages = widget.data.page
        end

        if widget.data.page ~= Gem_Atelier.Info.actualPage then
            widget:setVisible(false)
        end

        widget:setId(data.index)
        widget.gem:setImageClip(torect(string.format("%d %d %d %d", (32 * details.clip), 0, 32, 32)))
        widget.gems:setWidth((size * 53))

        for i = 1, size do
            local attribute = Gem_Atelier.getGemAttribute(i)
            local clip = data[attribute]

            local gem = g_ui.createWidget("Gem", widget.gems)
            gem:setId(i)
            gem.clip = clip
            gem.affinity = data.affinity
            gem.quality = data.quality
            gem.grade = 0

            gem.base:setImageClip(torect(string.format("%d %d %d %d", (50 * 0), 0, 50, 50)))

            local fragIndex = (i == 3) and 1 or 2
            if not Fragment_Workshop.Fragments[fragIndex][clip] then
                Fragment_Workshop.Fragments[fragIndex][clip] = 0
            end

            local modImg = (i == 3) and "icons-skillwheel-suprememods" or "icons-skillwheel-basicmods"
            local clipSize = (i == 3) and 35 or 30

            gem.base.mod:setImageSource("/mods/game_wheel/images/" .. modImg)
            gem.base.mod:setImageClip(torect(string.format("%d %d %d %d", (clipSize * clip), 0, clipSize, clipSize)))

            if i == 3 then
                gem.base.mod:setSize({ width = 35, height = 35 })
                gem.base.mod:setMarginBottom(2)
                gem.base.mod:setMarginLeft(2)
            end

            Fragment_Workshop.Fragments[fragIndex][clip] = Fragment_Workshop.Fragments[fragIndex][clip] + 1
        end
        ::continue::
    end

    for _, index in pairs(activedGems or {}) do
        local activeGem = Gem_Atelier.UI.gems:getChildById(index)
        if activeGem and activeGem.data and activeGem.data.object then
            local side = sides[activeGem.data.object.affinity]
            Gem_Atelier.onPlaceVessel(activeGem.data, activeGem, side, true)
        end
    end

    local view = Gem_Atelier.UI.view
    if view then
        if #revealedGems < 1 then
            view.selectedEmpty:setVisible(true)
            view.selected:setVisible(false)
        else
            view.selectedEmpty:setVisible(false)
            view.selected:setVisible(true)
            Gem_Atelier.onSelectGem(Gem_Atelier.UI.gems:getFirstChild())
        end

        if Gem_Atelier.SelectedGem then
            local state = WheelDestiny.state == 1
            local selectedGem = Gem_Atelier.SelectedGem.widget
            if selectedGem and selectedGem.locked then
                local enabled = state and not selectedGem.locked:isOn()
                view.selected.placeButton:setEnabled(state)
                view.selected.dismantleButton:setEnabled(enabled)
                view.selected.switchButton:setEnabled(enabled)
            end
        end
    end

    local gemData = Gem_Atelier.VocationGems[WheelDestiny.vocation]
    local revelation = Gem_Atelier.UI.revelation
    if gemData and revelation then
        for index, value in ipairs(gemData) do
            local amount = (index == 1) and WheelDestiny.Resources[81] or 0
            if index == 2 then amount = WheelDestiny.Resources[82] end
            if index == 3 then amount = WheelDestiny.Resources[83] end

            if index == 1 and revelation.first and revelation.firstText then
                revelation.first:setItemId(value.item)
                revelation.firstText:setText(string.format("%s\nGem (x %d)", value.name, amount))
            elseif index == 2 and revelation.second and revelation.secondText then
                revelation.second:setItemId(value.item)
                revelation.secondText:setText(string.format("%s\nGem (x %d)", value.name, amount))
            elseif index == 3 and revelation.third and revelation.thirdText then
                revelation.third:setItemId(value.item)
                revelation.thirdText:setText(string.format("%s\nGem (x %d)", value.name, amount))
            end
        end
    end

    Gem_Atelier.updatePage()
    WheelDestiny.updateWheelGem()
end
