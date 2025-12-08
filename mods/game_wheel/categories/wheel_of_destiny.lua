WheelDestiny.Unlocked = function(id)
    if not WheelDestiny.Slots[id] then
        return
    end
    if table.empty(WheelDestiny.Slots[id].brothers) then
        return true
    else
        for _, brother in ipairs(WheelDestiny.Slots[id].brothers) do
            if WheelDestiny.UI.main.wheel.base.front:getChildById(brother).value == WheelDestiny.Slots[brother].max then
                return true
            end
        end
    end
    return false
end

WheelDestiny.GetSideIdByName = function(id)
    local sides = {
        ["topLeft"] = 0,
        ["topRight"] = 1,
        ["bottomLeft"] = 2,
        ["bottomRight"] = 3,
    }

    if not sides[id] then
        return nil
    end

    return sides[id]
end

WheelDestiny.GetGemGrade = function(grade)
    local grades = {
        [0] = "I",
        [1] = "II",
        [2] = "III",
        [3] = "IV"
    }

    return grades[grade]
end

WheelDestiny.GetVesselLevel = function(affinity)
    local levels = {
        [0] = "Sealed",
        [1] = "Dormant",
        [2] = "Awakened",
        [3] = "Radiant"
    }

    local count = 0
    for slot, data in pairs(WheelDestiny.GemSlots) do
        if affinity == data.affinity then
            local max = WheelDestiny.Slots[slot].max
            local value = WheelDestiny.UI.main.wheel.base.front:getChildById(slot).value

            if value >= max then
                count = count + 1
            end
        end
    end

    return count, levels[count]
end

WheelDestiny.GetSideBySlot = function(id)
    for side, data in pairs(WheelDestiny.Sides) do
        for _, child in pairs(data.child) do
            if child == id then
                return side
            end
        end
    end

    return nil
end

WheelDestiny.GetSlotById = function(id)
    return WheelDestiny.UI.main.wheel.base.front:getChildById(id)
end

WheelDestiny.SetSlotPoints = function(id, points)
    local slot = WheelDestiny.GetSlotById(id)
    local side = WheelDestiny.GetSideBySlot(id)

    slot.value = points
    slot.full:setImageSource(string.format("/mods/game_wheel/images/area/%s/%d", id, slot.value))
    WheelDestiny.sidePoints[side].points = WheelDestiny.sidePoints[side].points + points
end

WheelDestiny.CheckCircle = function(list, index, click)
    local widget = list[index]

    if widget:getId() ~= "front" and widget:getId() ~= "vocation" then
        if widget.value and widget.value:isValidArea(click) then
            WheelDestiny.selectCircle(widget)
            return
        end

        if widget.socketHover:isValidArea(click) then
            WheelDestiny.selectGem(widget)
            return
        end
    end

    if index + 1 > #list then
        return
    end

    WheelDestiny.CheckCircle(list, index + 1, click)
end

WheelDestiny.isChanged = function()
    for i, slot in ipairs(WheelDestiny.Slots) do
        local slot = WheelDestiny.GetSlotById(i)
        if slot.value ~= WheelDestiny.slots[i] then
            return true
        end
    end
    return false
end

WheelDestiny.Check = function(list, index, click)
    local widget = list[index]

    if widget:getId() ~= "base" then
        if widget.unlocked:isValidArea(click) then
            WheelDestiny.select(widget)
            return
        end
    end

    if index + 1 > #list then
        WheelDestiny.CheckCircle(WheelDestiny.UI.main.wheel.base:getChildren(), 1, click)
        return
    end
    
    WheelDestiny.Check(list, index + 1, click)
end


WheelDestiny.onParseWheelOfDestiny = function(data, slots)
    local rotation = {
        [1] = 0,
        [2] = 180,
        [3] = 90,
        [4] = 270
    }

     local backdrops = {
        [1] = "/mods/game_wheel/images/backdrop_knight",
        [2] = "/mods/game_wheel/images/backdrop_paladin",
        [3] = "/mods/game_wheel/images/backdrop_sorcerer",
        [4] = "/mods/game_wheel/images/backdrop_druid",
        [5] = "/mods/game_wheel/images/backdrop_monk"
    }

    local sides = {"topLeft", "topRight", "bottomLeft", "bottomRight"}

    for _, side in pairs(sides) do
        WheelDestiny.sidePoints[side].points = 0
    end

    WheelDestiny.availablePoints = data.points
    for i, v in ipairs(slots) do
        WheelDestiny.SetSlotPoints(i, v)
        WheelDestiny.availablePoints = WheelDestiny.availablePoints - v
    end

    if data.state ~= 1 then
        WheelDestiny.UI.main.resetButton:setEnabled(false)
    else
        WheelDestiny.UI.main.resetButton:setEnabled(true)
    end

    WheelDestiny.UI.main.applyButton:setEnabled(false)
    WheelDestiny.UI.main.okButton:setEnabled(false)

    WheelDestiny.changeOption(WheelDestiny.UI.main.wheel.test.buttons.information, true)

    -- WheelDestiny.UI.main.wheel.base.vocation:setRotation(rotation[data.vocation])
    if backdrops[data.vocation] then
        WheelDestiny.UI.main.wheel.base.vocation:setImageSource(backdrops[data.vocation])
    end
    WheelDestiny.state = data.state
    WheelDestiny.slots = slots
    WheelDestiny.vocation = data.vocation
    WheelDestiny.totalPoints = data.points

    WheelDestiny.selected = nil
    WheelDestiny.resetSelected()
    WheelDestiny.resetCircleSelected()
    WheelDestiny.update()
    WheelDestiny.updateWheelGem()

	WheelDestiny.UpdateCurrentPreset()
end

WheelDestiny.send = function(hide)
    local slots = {}
    for i,_ in ipairs(WheelDestiny.Slots) do
        slots[i] = WheelDestiny.GetSlotById(i).value
    end

    local gems = {}
    for i = 0, 3 do
        local gem = WheelDestiny.ActivedGem[i]
        if gem then
            gems[i] = gem:getId()
        else
            gems[i] = -1
        end
    end

    g_game.requestSaveWheelOfDestiny(slots, gems)
    if hide then
        WheelDestiny.Toggle()
    end
end

WheelDestiny.updateImages = function()
    for _, widget in ipairs(WheelDestiny.UI.main.wheel.base.front:getChildren()) do
        if widget:getId() ~= "base" then
            if not widget.value then
                widget.value = 0
            end

            local unlock = widget.unlocked
            local id = tonumber(widget:getId())
            widget.onMouseMove = function(self, mousePos)
                if unlock:isValidArea(mousePos) then
                    WheelDestiny.disable()
                    widget.hover:setVisible(true)
                    WheelDestiny.hoverVerify = true
                    WheelDestiny.hoverWidget = widget
                end
            end

            widget.onClick = function(self, pos)
                local parent = self:getParent()

                if not unlock:isValidArea(pos) then
                    WheelDestiny.Check(parent:getChildren(), 1, pos)
                else
                    WheelDestiny.select(self)
                end
            end

            widget.onMouseRelease = function(self, pos, mouseButton)
                local parent = self:getParent()

                if mouseButton == MouseRightButton then
                    if not unlock:isValidArea(pos) then
                        WheelDestiny.Check(parent:getChildren(), 1, pos)
                    else
                        WheelDestiny.select(self)
                    end

                    if WheelDestiny.Unlocked(tonumber(WheelDestiny.selected:getId())) then
                        if WheelDestiny.selected.value > 0 then
                            WheelDestiny.decrementButton(true)
                        else
                            WheelDestiny.incrementButton(true)
                        end

                        if WheelDestiny.GemSlots[tonumber(WheelDestiny.selected:getId())] then
                            WheelDestiny.updateSockets()
                            WheelDestiny.updateWheelGem()
                        end
                    end
                end
            end

            local slot = WheelDestiny.Slots[id]
            if slot and slot.perk and not table.empty(slot.perk) then
                local vocationPerk = slot.perk[WheelDestiny.vocation]
                if vocationPerk and vocationPerk.mediumClip and vocationPerk.smallClip then
                    local mediumClip = 30 * vocationPerk.mediumClip
                    local smallClip = 16 * vocationPerk.smallClip

                    local affinity
                    local data = WheelDestiny.GemSlots[tonumber(widget:getId())]
                    if data then
                        affinity = data.affinity
                    end

                    if widget and widget.mediumPerk and widget.mediumPerk.smallPerk then
                        if not WheelDestiny.ActivedGem[affinity] then
                            widget.mediumPerk:setImageClip(torect(string.format("%d 0 30 30", mediumClip)))
                            widget.mediumPerk.smallPerk:setImageClip(torect(string.format("%d 0 16 16", smallClip)))
                        end
                    end
                end
            end
        end
    end

    for side, data in pairs(WheelDestiny.Sides) do
        local widget = WheelDestiny.UI.main.wheel.base and WheelDestiny.UI.main.wheel.base[side]

        if widget and data and data.perks and WheelDestiny.vocation and data.perks[WheelDestiny.vocation] then
            local perkData = data.perks[WheelDestiny.vocation]
            local largeClip = perkData.largeClip and (34 * perkData.largeClip) or 0

            if widget.perk then
                widget.perk:setImageClip(torect(string.format("%d 0 34 34", largeClip)))
            end

            widget.onMouseMove = function(self, mousePos)
                if widget.value and widget.value:isValidArea(mousePos) then
                    WheelDestiny.disable()
                    if widget.hover then widget.hover:setVisible(true) end
                    WheelDestiny.hoverVerify = true
                    WheelDestiny.hoverWidget = widget
                end

                if widget.socketHover and widget.socketHover:isValidArea(mousePos) then
                    WheelDestiny.disable()
                    widget.socketHover:setVisible(true)
                    WheelDestiny.hoverVerify = true
                    if widget.gem then
                        WheelDestiny.hoverWidget = widget.gem
                    end
                end
            end
        end
    end

end

WheelDestiny.update = function()
    if WheelDestiny.preview then
        WheelDestiny.UI:setText('Wheel of Destiny - Preview')
        WheelDestiny.UI.main.applyButton:setVisible(false)
        WheelDestiny.UI.main.okButton:setVisible(false)
        WheelDestiny.UI.main.resetButton:setVisible(false)
        WheelDestiny.totalPoints = 0
        WheelDestiny.availablePoints = 0
    else
        WheelDestiny.UI:setText('Wheel of Destiny')
        WheelDestiny.UI.main.applyButton:setVisible(true)
        WheelDestiny.UI.main.okButton:setVisible(true)
        WheelDestiny.UI.main.resetButton:setVisible(true)
    end

    WheelDestiny.verifyButtons()
    WheelDestiny.verifySlots()
    WheelDestiny.updateProgress()
    WheelDestiny.updateDedications()
    WheelDestiny.updateConvictions()
    WheelDestiny.updateRevelations()
    WheelDestiny.verifyPerks()
    WheelDestiny.updatePerks()
    WheelDestiny.updateImages()
    WheelDestiny.updateSockets()
end

WheelDestiny.reset = function()
    for _, widget in ipairs(WheelDestiny.UI.main.wheel.base.front:getChildren()) do
        if widget:getId() ~= "base" then
            widget.value = 0
            widget.full:setImageSource(string.format("/mods/game_wheel/images/area/%s/%d", widget:getId(), widget.value))
        end
    end

    WheelDestiny.availablePoints = WheelDestiny.totalPoints
    WheelDestiny.resetCircles()
    WheelDestiny.update()
    WheelDestiny.UI.main.applyButton:setEnabled(WheelDestiny.isChanged())
    WheelDestiny.UI.main.okButton:setEnabled(WheelDestiny.isChanged())
end

WheelDestiny.updateRevelations = function()
    local UI = WheelDestiny.UI.main.wheel.revelation
    if not UI then return end

    local function getStage(side)
        local sideData = WheelDestiny.sidePoints[side]
        local usedPoints = sideData and sideData.points or 0
        if usedPoints >= 1000 then
            return 3
        elseif usedPoints < 250 then
            return 0
        elseif usedPoints < 500 then
            return 1
        else
            return 2
        end
    end

    local function format(side)
        local stage = getStage(side)
        return stage == 0 and "Locked" or string.format("Stage %d", stage)
    end

    local buff = {
        [0] = 0,
        [1] = 4,
        [2] = 9,
        [3] = 20
    }

    local damage = 0
    local healing = 0

    local function safeSet(index, side)
        local sideData = WheelDestiny.Sides[side]
        local text = sideData and sideData.perks and sideData.perks[WheelDestiny.vocation] and sideData.perks[WheelDestiny.vocation].revelation or "N/A"
        if UI[index] then UI[index]:setText(text) end
        if UI[index .. "_value"] then UI[index .. "_value"]:setText(format(side)) end
        local stage = getStage(side)
        damage = damage + buff[stage]
        healing = healing + buff[stage]
    end

    safeSet("1", "bottomRight")
    safeSet("2", "bottomLeft")
    safeSet("3", "topRight")
    safeSet("4", "topLeft")

    if UI["5_value"] then
        UI["5_value"]:setText(string.format("+%d", damage))
    end
end

WheelDestiny.updateConvictions = function()
    local UI = WheelDestiny.UI.main.wheel.conviction
    if not UI or not UI.descriptions then
        print("Erro: UI ou UI.descriptions estão nil em updateConvictions")
        return
    end

    UI.descriptions:destroyChildren()
    local convictions = {}

    for id, data in ipairs(WheelDestiny.Slots) do
        local widget = WheelDestiny.GetSlotById(id)

        if widget and widget.value and data and data.max and widget.value >= data.max then
            local vocationPerks = data.perk and data.perk[WheelDestiny.vocation]
            if vocationPerks and vocationPerks.convictions then
                for _, v in ipairs(vocationPerks.convictions) do
                    if v.priority then
                        convictions[v.priority] = convictions[v.priority] or {}

                        if v.quantity then
                            local text = v.text
                            if v.priority == 2 then
                                text = v.text:match("%a+$")
                            end
                            convictions[v.priority][text] = (convictions[v.priority][text] or 0) + v.quantity
                        else
                            convictions[v.priority][v.text] = id
                        end
                    end
                end
            end
        end
    end

    local first = true
    local resistances = true
    for i, descriptions in pairs(convictions) do
        for text, v in pairs(descriptions) do
            if i == 2 then
                if resistances then
                    local resistance = g_ui.createWidget("ConvictionLabel", UI.descriptions)
                    resistance.text:setText("Ressistances: ")
                    resistance.text:setMarginLeft(3)
                    resistance.text:setColor('#C0C0C0')
                    resistance:setMarginTop(5)
                    resistances = false
                end

                local label = g_ui.createWidget("ConvictionLabel", UI.descriptions)
                label:setMarginLeft(10)
                label:setMarginTop(2)
                label.text:setColor('#C0C0C0')
                local setText = text
                if setText:len() > 20 then
                    setText = text:sub(1, 17) .. "..."
                end
                label.text:setText(setText)
                label.text:setTextAutoResize(true)

                label.value:setColor('#C0C0C0')
                label.value:setMarginRight(15)
                label.value:setText(string.format("+%d%%", v))
            else
                local label = g_ui.createWidget("ConvictionLabel", UI.descriptions)

                local function format(str)
                    local augmentedPos = str:find("Augmented")
                    local newlinePos = str:find("\n")
                    if augmentedPos and (not newlinePos or augmentedPos < newlinePos) then
                        return str:gsub("Augmented", "Aug.")
                    elseif newlinePos then
                        return str:sub(1, newlinePos - 1)
                    else
                        return str
                    end
                end

                local setText = text
                if setText:len() > 20 then
                    setText = text:sub(1, 17) .. "..."
                end

                label.text:setText(format(setText))
                label.text:setTextAutoResize(true)
                label.text:setColor('#C0C0C0')

                if i == 1 then
                    label.infoIcon:setVisible(true)
                end

                if i == 1 or i == 3 then
                    label.value:setColor('#C0C0C0')
                    label.value:setMarginRight(20)
                    label.value:setMarginTop(-1)
                    if i == 3 then
                        label.value:setText(string.format("+%.2f%%", v))
                    elseif text and text:find("Skill") then
                        label.value:setText(string.format("+%d", v))
                    else
                        label.value:setText("I")
                    end
                end
            end
        end
    end
end

WheelDestiny.updateDedications = function()
    local UI = WheelDestiny.UI.main.wheel.dedication

    local attributes = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0
    }

    for id, data in ipairs(WheelDestiny.Slots) do
        local child = WheelDestiny.UI.main.wheel.base.front:getChildById(id)
        local value = child and child.value or 0

        if data.perk and data.perk[WheelDestiny.vocation] and data.perk[WheelDestiny.vocation].dedications then
            for _, v in ipairs(data.perk[WheelDestiny.vocation].dedications) do
                if attributes[v.text] ~= nil then
                    attributes[v.text] = attributes[v.text] + (v.quantity * value)
                end
            end
        end
    end

    for i, v in ipairs(attributes) do
        local sum = v > 0 and "+" or ""
        if i == 1 then
            UI.hitpoints:setText(string.format("%s%d", sum, v))
        elseif i == 2 then
            UI.mana:setText(string.format("%s%d", sum, v))
        elseif i == 3 then
            UI.capacity:setText(string.format("%s%d", sum, v))
        elseif i == 4 then
            UI.mitigation:setText(v > 0 and string.format("+%.2f%%", v) or "0%")
        end
    end
end


WheelDestiny.changeOption = function(self, force)
    if self:isChecked() and not force then
        return
    end
    local identifier = {
        ["information"] = "presets",
        ["presets"] = "information"
    }
    local brother = self:getParent()[identifier[self:getId()]]
    if brother:isChecked() then
        brother:setChecked(false)
        if brother.larged then
            brother:setWidth(34)
            brother.larged = false
            brother.text:setVisible(false)
            brother:setIconOffsetX(3)
            brother:setIconOffsetY(0)
        end
    end
    self:setChecked(true)
    if not self.larged then
        self:setWidth(self.expandW)
        self.larged = true
        self:setIconOffsetX(5)
        self:setIconOffsetY(2)
        self.text:setVisible(true)
    end

    local isPresset = (self:getId() == "presets")
    WheelDestiny.UI.main.wheel.test.presetBox:setVisible(isPresset)
    WheelDestiny.UI.main.wheel.test.defaultBox:setVisible(not isPresset)
    WheelDestiny.UI.main.wheel.test.informationBox:setVisible(false)
end

WheelDestiny.resetSelected = function()
    local slots = WheelDestiny.UI.main.wheel.base.selectors.front
    for i = 1, slots:getChildCount() do
        local child = slots:getChildByIndex(i)
        if child:getId() ~= "base" then
            child.selected:setVisible(false)
        end
    end
end

WheelDestiny.resetGemSelected = function()
    for side, data in pairs(WheelDestiny.Sides) do
        local widget = WheelDestiny.UI.main.wheel.base[side]
        widget.socketMark:setVisible(false)
    end
end

WheelDestiny.resetCircleSelected = function()
    for side, data in pairs(WheelDestiny.Sides) do
        local widget = WheelDestiny.UI.main.wheel.base[side]
        widget.selected:setVisible(false)
    end
end

WheelDestiny.verifySlots = function()
    for _, widget in ipairs(WheelDestiny.UI.main.wheel.base.front:getChildren()) do
        if widget:getId() ~= "base" then
            local id = tonumber(widget:getId())
            local value = widget.value
            widget.unlocked:setVisible(WheelDestiny.Unlocked(id))
        end
    end

    WheelDestiny.UI.main.wheel.selection.points:setText(string.format("%d / %d", WheelDestiny.availablePoints,
        WheelDestiny.totalPoints))
end

WheelDestiny.resetCircles = function()
    local sides = {
        ["topLeft"] = "TL",
        ["topRight"] = "TR",
        ["bottomLeft"] = "BL",
        ["bottomRight"] = "BR"
    }

    for side, prefix in pairs(sides) do
        WheelDestiny.sidePoints[side].points = 0
        WheelDestiny.UI.main.wheel.base[side].base:setImageSource(string.format(
            '/mods/game_wheel/images/backdrop_skillwheel_largebonus_front%d_%s', 0, prefix))
        WheelDestiny.UI.main.wheel.base[side].value:setImageSource(string.format('/mods/game_wheel/images/area/circle/%s/%d', side, 0))
    end
end

WheelDestiny.updatePerks = function()
    local sides = {"topLeft", "topRight", "bottomLeft", "bottomRight"}

    for _, side in pairs(sides) do
        local usedPoints = WheelDestiny.sidePoints[side].points

        local stage
        local positionInStage
        local backdrop = {
            ["topLeft"] = "TL",
            ["topRight"] = "TR",
            ["bottomLeft"] = "BL",
            ["bottomRight"] = "BR"
        }

        if usedPoints < 250 then
            stage = 0
            positionInStage = usedPoints % 250
        elseif usedPoints < 500 then
            stage = 1
            positionInStage = usedPoints % 250
        else
            stage = 2
            positionInStage = usedPoints % 500
        end

        if stage == 2 then
            positionInStage = math.floor(positionInStage / 2)
        end

        if usedPoints == 1000 then
            stage = 3
        end

        if stage == 3 then
            WheelDestiny.UI.main.wheel.base[side].value:setImageSource(string.format('/mods/game_wheel/images/area/circle/%s/max', side))
        else
            WheelDestiny.UI.main.wheel.base[side].value:setImageSource(
                string.format('/mods/game_wheel/images/area/circle/%s/%d', side, positionInStage))
        end

        WheelDestiny.UI.main.wheel.base[side].stage = stage
        WheelDestiny.UI.main.wheel.base[side].base:setImageSource(string.format(
            '/mods/game_wheel/images/backdrop_skillwheel_largebonus_front%d_%s', stage, backdrop[side]))
    end
end

WheelDestiny.verifyPerks = function()
    local widget = WheelDestiny.selected
    if not widget then
        return
    end

    local side = WheelDestiny.GetSideBySlot(tonumber(widget:getId()))
    local usedPoints = WheelDestiny.sidePoints[side].points
    local stage
    local positionInStage
    local backdrop = {
        ["topLeft"] = "TL",
        ["topRight"] = "TR",
        ["bottomLeft"] = "BL",
        ["bottomRight"] = "BR"
    }

    if usedPoints < 250 then
        stage = 0
        positionInStage = usedPoints % 250
    elseif usedPoints < 500 then
        stage = 1
        positionInStage = usedPoints % 250
    else
        stage = 2
        positionInStage = usedPoints % 500
    end

    if stage == 2 then
        positionInStage = math.floor(positionInStage / 2)
    end

    if usedPoints == 1000 then
        stage = 3
    end

    if stage == 3 then
        WheelDestiny.UI.main.wheel.base[side].value:setImageSource(string.format('/mods/game_wheel/images/area/circle/%s/max', side))
    else
        WheelDestiny.UI.main.wheel.base[side].value:setImageSource(
            string.format('/mods/game_wheel/images/area/circle/%s/%d', side, positionInStage))
    end

    WheelDestiny.UI.main.wheel.base[side].stage = stage
    WheelDestiny.UI.main.wheel.base[side].base:setImageSource(string.format(
        '/mods/game_wheel/images/backdrop_skillwheel_largebonus_front%d_%s', stage, backdrop[side]))
end

WheelDestiny.verifyButtons = function()
    if not WheelDestiny.selected or not WheelDestiny.Slots[tonumber(WheelDestiny.selected:getId())] then
        return
    end
    local id = tonumber(WheelDestiny.selected:getId())
    local value = WheelDestiny.selected.value

    local ui = WheelDestiny.UI.main.wheel.selection.selected
    local max = WheelDestiny.Slots[id].max
    local min = WheelDestiny.Slots[id].min

    if value >= max or not WheelDestiny.Unlocked(id) or WheelDestiny.availablePoints <= 0 then
        ui.maxButton:setEnabled(false)
        ui.oneButton:setEnabled(false)
    else
        ui.maxButton:setEnabled(true)
        ui.oneButton:setEnabled(true)
    end

    if value <= min or not WheelDestiny.Unlocked(id) then
        ui.maxNegativeButton:setEnabled(false)
        ui.negativeOnebutton:setEnabled(false)
    else
        ui.maxNegativeButton:setEnabled(true)
        ui.negativeOnebutton:setEnabled(true)
    end
end

WheelDestiny.incrementButton = function(full)
    if WheelDestiny.state == 0 then
        return
    end

    local widget = WheelDestiny.selected
    if not widget then
        return
    end

    local id = tonumber(widget:getId())
    local side = WheelDestiny.GetSideBySlot(id)

    if not side then
        g_logger.error("Side not found.")
        return
    end

    local remaining = WheelDestiny.Slots[id].max - widget.value
    local pointsToAdd = full and math.min(WheelDestiny.availablePoints, remaining) or math.min(1, remaining)
    widget.value = widget.value + pointsToAdd
    WheelDestiny.usedPoints = WheelDestiny.usedPoints + pointsToAdd
    WheelDestiny.sidePoints[side].points = WheelDestiny.sidePoints[side].points + pointsToAdd
    WheelDestiny.availablePoints = WheelDestiny.availablePoints - pointsToAdd

    if WheelDestiny.selectedHover:getId() == widget:getId() then
        WheelDestiny.updateHoverInformation(true)
    end

    widget.full:setImageSource(string.format("/mods/game_wheel/images/area/%s/%d", id, widget.value))
    WheelDestiny.update()
    WheelDestiny.UI.main.applyButton:setEnabled(WheelDestiny.isChanged())
    WheelDestiny.UI.main.okButton:setEnabled(WheelDestiny.isChanged())
end

WheelDestiny.decrementButton = function(full)
    if WheelDestiny.state == 0 or WheelDestiny.state == 2 then
        return
    end

    local widget = WheelDestiny.selected
    if not widget then
        return
    end

    local id = tonumber(widget:getId())
    local side = WheelDestiny.GetSideBySlot(id)

    local function canRemoveSlot(id)
        if table.empty(WheelDestiny.Slots[id].depedency) then
            return true
        end

        local dependencies = WheelDestiny.Slots[id].depedency

        local brotherDependency = 0
        local verify = 0
        for _, dependency in ipairs(dependencies) do
            local brother = WheelDestiny.GetSlotById(dependency)

            if brother.value == 0 then
                brotherDependency = brotherDependency + 1
            end

            if table.size(WheelDestiny.Slots[id].depedency) == brotherDependency then
                return true
            else
                local count = 0
                for _, v in pairs(WheelDestiny.Slots[dependency].brothers) do
                    local subBrother = WheelDestiny.GetSlotById(v)
                    if subBrother.value >= WheelDestiny.Slots[v].max then
                        count = count + 1
                    end

                    if table.size(WheelDestiny.Slots[v].brothers) > 3 and count > 1 then
                        verify = verify + 1
                    end
                end

                local tolerance = {
                    [4] = 2,
                    [3] = 2,
                    [2] = 1,
                    [1] = 1
                }

                local size = tolerance[table.size(WheelDestiny.Slots[dependency].brothers)]
                if count > size then
                    verify = verify + 1
                    count = 0
                end

                if verify >= table.size(WheelDestiny.Slots[id].depedency) then
                    return true
                end
            end
        end

        return false
    end

    if not canRemoveSlot(id) then
        return
    end

    if not side then
        g_logger.error("Side not found.")
        return
    end

    local pointsToRemove = full and widget.value or 1
    widget.value = widget.value - pointsToRemove
    WheelDestiny.usedPoints = WheelDestiny.usedPoints - pointsToRemove
    WheelDestiny.sidePoints[side].points = WheelDestiny.sidePoints[side].points - pointsToRemove
    WheelDestiny.availablePoints = WheelDestiny.availablePoints + pointsToRemove

    if WheelDestiny.selectedHover:getId() == widget:getId() then
        WheelDestiny.updateHoverInformation(true)
    end

    widget.full:setImageSource(string.format("/mods/game_wheel/images/area/%s/%d", id, widget.value))
    WheelDestiny.update()
    WheelDestiny.UI.main.applyButton:setEnabled(WheelDestiny.isChanged())
    WheelDestiny.UI.main.okButton:setEnabled(WheelDestiny.isChanged())
end

WheelDestiny.select = function(widget)
    local parent = widget:getParent()
    local id = widget:getId()
    local base = parent.base

    if not WheelDestiny.UI.main.wheel.selection.selected:isVisible() then
        WheelDestiny.UI.main.wheel.selection.selected:setVisible(true)
    end

    parent:moveChildToIndex(widget, parent:getChildCount())
    parent:moveChildToIndex(base, parent:getChildCount() - 1)

    WheelDestiny.resetGemSelected()
    WheelDestiny.resetSelected()
    WheelDestiny.resetCircleSelected()
    
    widget.selected:setVisible(false)
    WheelDestiny.selected = widget

    local selectBase = WheelDestiny.UI.main.wheel.base.selectors.front:getChildById(id)
    selectBase.selected:setVisible(true)

    WheelDestiny.verifyButtons()
    WheelDestiny.updateProgress()
end

WheelDestiny.selectCircle = function(widget)
    if not WheelDestiny.UI.main.wheel.selection.selected:isVisible() then
        WheelDestiny.UI.main.wheel.selection.selected:setVisible(true)
    end

    WheelDestiny.resetGemSelected()
    WheelDestiny.resetCircleSelected()
    WheelDestiny.resetSelected()
    widget.selected:setVisible(true)
    WheelDestiny.selected = widget

    WheelDestiny.updateProgress(true)
end

WheelDestiny.selectGem = function(widget)
    if not WheelDestiny.UI.main.wheel.selection.selected:isVisible() then
        WheelDestiny.UI.main.wheel.selection.selected:setVisible(true)
    end

    WheelDestiny.resetGemSelected()
    WheelDestiny.resetCircleSelected()
    WheelDestiny.resetSelected()
    widget.socketMark:setVisible(true)
    WheelDestiny.selected = widget

    WheelDestiny.updateProgress(false, true)
end

WheelDestiny.updateHoverInformation = function(force)
    local widget = WheelDestiny.hoverWidget
    local circles = {"topLeft", "topRight", "bottomLeft", "bottomRight"}

    if not force then
        if not widget or widget == WheelDestiny.selectedHover then
            return
        end
    end

    local UI = WheelDestiny.UI.main.wheel.test.informationBox

    if not widget then
        return
    end

    if table.contains(circles, widget:getId()) then
        local stage = widget.stage and widget.stage or 0
        local points = WheelDestiny.sidePoints[widget:getId()].points

        UI.dedication:setVisible(false)
        UI.conviction:setVisible(false)
        UI.revelation:setVisible(true)
        UI.bottomText:setVisible(false)
        UI.gem:setVisible(false)
        UI.progress:setVisible(true)

        local limits = {
            [0] = 250,
            [1] = 500,
            [2] = 1000,
            [3] = 1000
        }

        local rect = {
            x = 0,
            y = 0,
            width = (((points > limits[stage]) and limits[stage] or points) / limits[stage]) * 190,
            height = 12
        }
        if points >= 0 and rect.width < 1 then
            UI.progress.fill:setVisible(false)
        else
            UI.progress.fill:setVisible(true)
        end

        UI.progress.fill:setImageRect(rect)
        UI.progress.fill:setImageClip(rect)

        if points >= 1000 then
            UI.progress.fill:setImageSource("/mods/game_wheel/images/fill-completed")
        else
            UI.progress.fill:setImageSource("/mods/game_wheel/images/fill")
        end

        UI.progress.value:setText(string.format("%d / %d", points, limits[stage]))

        if stage == 0 then
            UI.revelation.stage:setText("Locked")
            UI.revelation.text:setColor('#707070')
        else
            UI.revelation.stage:setText(string.format("Stage %d", stage))
            UI.revelation.text:setColor('#C0C0C0')
        end

        UI.revelation.text:setText(WheelDestiny.Sides[widget:getId()].perks[WheelDestiny.vocation].text)
    elseif widget:getId() == "gem" then
        UI.dedication:setVisible(false)
        UI.conviction:setVisible(false)
        UI.revelation:setVisible(false)
        UI.bottomText:setVisible(false)
        UI.progress:setVisible(false)
        UI.gem:setVisible(true)
        UI.gem.descriptions:destroyChildren()
        
        local affinity = WheelDestiny.GetSideIdByName(widget:getParent():getId())
        local gem = WheelDestiny.ActivedGem[affinity]

        local level, stage = WheelDestiny.GetVesselLevel(affinity)
        if level <= 0 then
            UI.gem.vessel:setText(string.format("%s Vessel (VR 0)", stage))
        else
            UI.gem.vessel:setText(string.format("%s Vessel (VR %s)", stage, WheelDestiny.GetGemGrade(level -1)))
        end
        
        if level >= 3 then
            UI.gem.attribute:setEnabled(true)
        else
            UI.gem.attribute:setEnabled(false)
        end

        if not gem then
            UI.gem.name:setText("Vessel contains no gem")
            UI.gem.attribute:setVisible(false)
            return
        end

        local spaceDescription = false
        for i = 1, gem.data.size do
            if i == 3 then

            else
                local attribute = Gem_Atelier.getGemAttribute(i)
                local clip = gem.data.object[attribute]
                local grade = Fragment_Workshop.LesserFragments[clip] or 0

                local descriptions = Fragment_Workshop.Basic_Modifiers[clip].descriptions
                for _, object in ipairs(descriptions) do
                    local label = g_ui.createWidget("Label", UI.gem.descriptions)
                    label:setText(string.format("%s %s (%s)", object.values[grade], object.text, WheelDestiny.GetGemGrade(grade)))
                    label:setEnabled(false)

                    local activedGems = WheelDestiny.ActivedGemSlots[affinity]
                    for _, value in pairs(activedGems) do
                        if value then
                            if value.clip == clip then
                                label:setEnabled(true)
                            end
                        end
                    end

                    if spaceDescription then
                        label:setMarginTop(5)
                        spaceDescription = false
                    end

                end
            end
            spaceDescription = true
        end

        UI.gem.attribute:setVisible(true)
        UI.gem.name:setText(gem.data.details.name)
    else
        UI.dedication:setVisible(true)
        UI.conviction:setVisible(true)
        UI.bottomText:setVisible(true)
        UI.revelation:setVisible(false)
        UI.progress:setVisible(true)
        UI.gem:setVisible(false)

        local id = tonumber(widget:getId())
        local slot = WheelDestiny.Slots[id]
        local max = slot.max

        local rect = {
            x = 0,
            y = 0,
            width = (((widget.value > max) and max or widget.value) / max) * 190,
            height = 12
        }
        if widget.value >= 0 and rect.width < 1 then
            UI.progress.fill:setVisible(false)
        else
            UI.progress.fill:setVisible(true)
        end

        UI.progress.fill:setImageRect(rect)
        UI.progress.fill:setImageClip(rect)

        if widget.value >= max then
            UI.progress.fill:setImageSource("/mods/game_wheel/images/fill-completed")
        else
            UI.progress.fill:setImageSource("/mods/game_wheel/images/fill")
        end

        if UI.progress and UI.progress.value and widget and widget.value and max then
            UI.progress.value:setText(string.format("%d / %d", widget.value, max))
        end

        if UI.dedication and UI.dedication.descriptions then
            UI.dedication.descriptions:destroyChildren()
        end

        local slotPerk = slot and slot.perk and slot.perk[WheelDestiny.vocation]
        if not slotPerk or not slotPerk.dedications then
            return
        end

        

        for i, data in ipairs(slot.perk[WheelDestiny.vocation].dedications) do
            local label = g_ui.createWidget("Label", UI.dedication.descriptions)
            label:setId(i)

            local percent = ""
            if data.percent then
                percent = "%"
            end

            local attributes = {
                [1] = "Hit Points",
                [2] = "Mana",
                [3] = "Capacity",
                [4] = "Mitigation Multiplier"
            }

            local formattedQuantity
            local text = attributes[data.text]
            if widget.value == 0 then
                formattedQuantity = string.format("+%d%s %s", data.quantity * widget.value, percent, text)
            elseif data.quantity == math.floor(data.quantity) then
                formattedQuantity = string.format("+%d%s %s", data.quantity * widget.value, percent, text)
            else
                formattedQuantity = string.format("+%.2f%s %s", data.quantity * widget.value, percent, text)
            end

            label:setText(formattedQuantity)

            if i == 1 then
                label:addAnchor(AnchorTop, "parent", AnchorTop)
                label:addAnchor(AnchorLeft, "parent", AnchorLeft)
                label:setMarginTop(3)
            else
                label:addAnchor(AnchorTop, "prev", AnchorBottom)
                label:addAnchor(AnchorLeft, "prev", AnchorLeft)
            end
            label:setTextAutoResize(true)

            if widget.value <= 0 then
                label:setColor('#707070')
            else
                label:setColor('#C0C0C0')
            end
        end
        UI.conviction.descriptions:destroyChildren()
        --BottomCov
        for i, data in ipairs(slot.perk[WheelDestiny.vocation].convictions) do
            local label = g_ui.createWidget("ConvictionLabel", UI.conviction.descriptions)
            label:setId(i)
            label:setFont("pVerdana Bold-11px")

            local hasAugmentation = data.augmentation and data.augmentation or nil
            local percent = ""
            if data.percent then
                percent = "%"
            end

            local icon = ""
            if data.augmentation then
                icon = "   :"
            end

            if data.quantity then
                local formattedQuantity
                if math.floor(data.quantity) == data.quantity then
                    formattedQuantity = string.format("+%d%s %s", data.quantity, percent, data.text)
                else
                    formattedQuantity = string.format("+%.2f%s %s", data.quantity, percent, data.text)
                end
                if formattedQuantity:len() >= 165 then
                    formattedQuantity = formattedQuantity:sub(1, 160) .. "..."
                end
                label:setText(formattedQuantity)
            else
                local setText = string.format("%s%s", icon, data.text)
                if setText:len() >= 165 then
                    setText = setText:sub(1, 160) .. "..."
                end
                label:setText(setText)
            end

            if i > 1 then
                label:setColor('#707070')
                if hasAugmentation then
                    local icon = g_ui.createWidget("UIWidget", label)
                    local otherUnlocked = false
                    local augBrother = WheelDestiny.GetSlotById(hasAugmentation)
                    if augBrother.value >= WheelDestiny.Slots[hasAugmentation].max then
                        otherUnlocked = true
                    end

                    local augmentations = {
                        [1] = "/mods/game_wheel/images/icon-augmentation1-inactive",
                        [2] = "/mods/game_wheel/images/icon-augmentation2-inactive"
                    }
                    icon:setImageSource(augmentations[data.augmentation])
                    if otherUnlocked then
                        if data.augmentation ~= 1 and widget.value >= slot.max then
                            icon:setImageSource('/mods/game_wheel/images/icon-augmentation2-active')
                            label:setColor('#C0C0C0')
                        end

                        if data.augmentation ~= 2 and otherUnlocked then
                            icon:setImageSource('/mods/game_wheel/images/icon-augmentation1-active')
                            label:setColor('#C0C0C0')
                        end
                    else
                        if data.augmentation ~= 2 and widget.value >= slot.max then
                            icon:setImageSource('/mods/game_wheel/images/icon-augmentation1-active')
                            label:setColor('#C0C0C0')
                        end

                        if data.augmentation ~= 1 and otherUnlocked then
                            icon:setImageSource('/mods/game_wheel/images/icon-augmentation2-active')
                            label:setColor('#C0C0C0')
                        end
                    end

                    icon:addAnchor(AnchorTop, "parent", AnchorTop)
                    icon:addAnchor(AnchorLeft, "parent", AnchorLeft)
                    icon:setMarginTop(2)
                end
            end
            -- label:setTextAutoResize(true)
            label:setTextAlign(AlignLeft)
            label:setTextWrap(true)
            label:setTextVerticalAutoResize(true)
            label:setMarginTop(1)

            if hasAugmentation then
            else
                if widget.value <= 0 then
                    label:setColor('#707070')
                else
                    label:setColor('#C0C0C0')
                end
            end
        end
    end

    WheelDestiny.selectedHover = widget
end

WheelDestiny.ToggleSelectionButtons = function(show)
    local UI = WheelDestiny.UI.main.wheel.selection.selected

    UI.maxNegativeButton:setVisible(show)
    UI.negativeOnebutton:setVisible(show)
    UI.maxButton:setVisible(show)
    UI.oneButton:setVisible(show)
end

WheelDestiny.updateProgress = function(isCircle, isGem)
    local widget = WheelDestiny.selected
    if not widget then
        return
    end

    local UI = WheelDestiny.UI.main.wheel.selection.selected
    if isCircle then
        local stage = widget.stage and widget.stage or 0
        local points = WheelDestiny.sidePoints[widget:getId()].points

        UI.dedication:setVisible(false)
        UI.conviction:setVisible(false)
        UI.revelation:setVisible(true)
        UI.progress:setVisible(true)
        UI.gem:setVisible(false)
        WheelDestiny.ToggleSelectionButtons(true)

        local limits = {
            [0] = 250,
            [1] = 500,
            [2] = 1000,
            [3] = 1000
        }

        local rect = {
            x = 0,
            y = 0,
            width = (((points > limits[stage]) and limits[stage] or points) / limits[stage]) * 190,
            height = 14
        }
        if points >= 0 and rect.width < 1 then
            UI.progress.fill:setVisible(false)
        else
            UI.progress.fill:setVisible(true)
        end

        UI.progress.fill:setImageRect(rect)
        UI.progress.fill:setImageClip(rect)

        if points >= 1000 then
            UI.progress.fill:setImageSource("/mods/game_wheel/images/fill-completed")
        else
            UI.progress.fill:setImageSource("/mods/game_wheel/images/fill")
        end

        UI.progress.value:setText(string.format("%d / %d", points, limits[stage]))

        if stage == 0 then
            UI.revelation.stage:setText("Locked")
            UI.revelation.text:setColor('#707070')
        else
            UI.revelation.stage:setText(string.format("Stage %d", stage))
            UI.revelation.text:setColor('#C0C0C0')
        end

        UI.revelation.text:setText(WheelDestiny.Sides[widget:getId()].perks[WheelDestiny.vocation].text)
    elseif isGem then
        UI.dedication:setVisible(false)
        UI.conviction:setVisible(false)
        UI.revelation:setVisible(false)
        UI.progress:setVisible(false)
        WheelDestiny.ToggleSelectionButtons(false)
        UI.gem:setVisible(true)
        UI.gem.descriptions:destroyChildren()
        
        local affinity = WheelDestiny.GetSideIdByName(widget:getId())
        local gem = WheelDestiny.ActivedGem[affinity]

        local level, stage = WheelDestiny.GetVesselLevel(affinity)
        if level <= 0 then
            UI.gem.vessel:setText(string.format("%s Vessel (VR 0)", stage))
        else
            UI.gem.vessel:setText(string.format("%s Vessel (VR %s)", stage, WheelDestiny.GetGemGrade(level -1)))
        end
        
        if level >= 3 then
            UI.gem.attribute:setEnabled(true)
        else
            UI.gem.attribute:setEnabled(false)
        end

        if not gem then
            UI.gem.name:setText("Vessel contains no gem")
            UI.gem.attribute:setVisible(false)
            return
        end

        local spaceDescription = false
        for i = 1, gem.data.size do
            if i == 3 then

            else
                local attribute = Gem_Atelier.getGemAttribute(i)
                local clip = gem.data.object[attribute]
                local grade = Fragment_Workshop.LesserFragments[clip] or 0

                local descriptions = Fragment_Workshop.Basic_Modifiers[clip].descriptions
                for _, object in ipairs(descriptions) do
                    local label = g_ui.createWidget("Label", UI.gem.descriptions)
                    label:setText(string.format("%s %s (%s)", object.values[grade], object.text, WheelDestiny.GetGemGrade(grade)))
                    label:setEnabled(false)

                    local activedGems = WheelDestiny.ActivedGemSlots[affinity]
                    for _, value in pairs(activedGems) do
                        if value then
                            if value.clip == clip then
                                label:setEnabled(true)
                            end
                        end
                    end

                    if spaceDescription then
                        label:setMarginTop(5)
                        spaceDescription = false
                    end

                end
            end
            spaceDescription = true
        end

        UI.gem.attribute:setVisible(true)
        UI.gem.name:setText(gem.data.details.name)
    else
        UI.dedication:setVisible(true)
        UI.conviction:setVisible(true)
        UI.revelation:setVisible(false)
        UI.progress:setVisible(true)
        UI.gem:setVisible(false)
        WheelDestiny.ToggleSelectionButtons(true)

        local id = tonumber(widget:getId())
        if not id then
            return
        end

        local slot = WheelDestiny.Slots[id]
        if not slot then
            return
        end

        local max = slot.max or 1 -- evita divisão por zero

        local value = widget.value or 0
        local rect = {
            x = 0,
            y = 0,
            width = ((value > max and max or value) / max) * 192,
            height = 12
        }

        if value >= 0 and rect.width < 1 then
            UI.progress.fill:setVisible(false)
        else
            UI.progress.fill:setVisible(true)
        end

        UI.progress.fill:setImageRect(rect)
        UI.progress.fill:setImageClip(rect)

        if value >= max then
            UI.progress.fill:setImageSource("/mods/game_wheel/images/fill-completed")
        else
            UI.progress.fill:setImageSource("/mods/game_wheel/images/fill")
        end


        UI.progress.value:setText(string.format("%d / %d", widget.value, max))

        local hasMit = false
        local tooltip = "Per promotion point:"

        UI.dedication.descriptions:destroyChildren()
        for i, data in ipairs(slot.perk[WheelDestiny.vocation].dedications) do
            local label = g_ui.createWidget("Label", UI.dedication.descriptions)
            label:setId(i)

            local percent = ""
            if data.percent then
                percent = "%"
            end

            local formattedQuantity
            local text = WheelDestiny.Dedications[data.text].text

            if data.text == WDMit then
                hasMit = true
            end

            if widget.value == 0 then
                formattedQuantity = string.format("+%d%s %s", data.quantity * widget.value, percent, text)
            elseif data.quantity == math.floor(data.quantity) then
                formattedQuantity = string.format("+%d%s %s", data.quantity * widget.value, percent, text)
            else
                formattedQuantity = string.format("+%.2f%s %s", data.quantity * widget.value, percent, text)
            end
            tooltip = tooltip .. "\n+" .. (data.quantity or 1) .. " " .. text
            label:setText(formattedQuantity)

            if i == 1 then
                label:addAnchor(AnchorTop, "parent", AnchorTop)
                label:addAnchor(AnchorLeft, "parent", AnchorLeft)
                label:setMarginTop(3)
            else
                label:addAnchor(AnchorTop, "prev", AnchorBottom)
                label:addAnchor(AnchorLeft, "prev", AnchorLeft)
            end
            label:setTextAutoResize(true)

            if widget.value <= 0 then
                label:setColor('#707070')
            else
                label:setColor('#C0C0C0')
            end
        end

        if hasMit then
            tooltip = "Increases your mitigation multiplicatively\n\n" .. tooltip
        end

        UI.dedication.info:setTooltipAlign(AlignTopLeft)
        UI.dedication.info:setTooltip(tooltip)
        
        UI.conviction.descriptions:destroyChildren()

        local hasAug = false
        --TopConv
        for i, data in ipairs(slot.perk[WheelDestiny.vocation].convictions) do
            local label = g_ui.createWidget("UIWidget", UI.conviction.descriptions)
            label:setId(i)
            label:setFont("Verdana Bold-11px-wheel")
            label:setTextAlign(AlignLeft)
            label:setTextWrap(true)
            label:setTextVerticalAutoResize(true)

            local hasAugmentation = data.augmentation and data.augmentation or nil
            hasAug = hasAugmentation
            local percent = ""
            if data.percent then
                percent = "%"
            end
            local text = data.text

            local icon = ""
            if data.augmentation then
                icon = "   :"
                text = " " .. text
            end

            if data.quantity then
                local formattedQuantity
                if math.floor(data.quantity) == data.quantity then
                    formattedQuantity = string.format("+%d%s %s", data.quantity, percent, text)
                else
                    formattedQuantity = string.format("+%.2f%s %s", data.quantity, percent, text)
                end
                label:setText(formattedQuantity)
            else
                if #text > 85 then
                    text = text:sub(1, 85) .. "..."
                end

                label:setText(string.format("%s%s", icon, text))
            end

            if i > 1 then
                label:setColor('#707070')

                if hasAugmentation then
                    local icon = g_ui.createWidget("UIWidget", label)

                    local otherUnlocked = false
                    local augBrother = WheelDestiny.GetSlotById(hasAugmentation)
                    if augBrother.value >= WheelDestiny.Slots[hasAugmentation].max then
                        otherUnlocked = true
                    end

                    local augmentations = {
                        [1] = "/mods/game_wheel/images/icon-augmentation1-inactive",
                        [2] = "/mods/game_wheel/images/icon-augmentation2-inactive"
                    }

                    icon:setImageSource(augmentations[data.augmentation])

                    if otherUnlocked then
                        if data.augmentation ~= 1 and widget.value >= slot.max then
                            icon:setImageSource('/mods/game_wheel/images/icon-augmentation2-active')
                            label:setColor('#C0C0C0')
                        end

                        if data.augmentation ~= 2 and otherUnlocked then
                            icon:setImageSource('/mods/game_wheel/images/icon-augmentation1-active')
                            label:setColor('#C0C0C0')
                        end
                    else
                        if data.augmentation ~= 2 and widget.value >= slot.max then
                            icon:setImageSource('/mods/game_wheel/images/icon-augmentation1-active')
                            label:setColor('#C0C0C0')
                        end

                        if data.augmentation ~= 1 and otherUnlocked then
                            icon:setImageSource('/mods/game_wheel/images/icon-augmentation2-active')
                            label:setColor('#C0C0C0')
                        end
                    end

                    icon:addAnchor(AnchorTop, "parent", AnchorTop)
                    icon:addAnchor(AnchorLeft, "parent", AnchorLeft)
                    icon:setMarginTop(2)
                end
            end
            label:setTextVerticalAutoResize(true)
            label:setMarginTop(1)

            if not hasAugmentation then
                if widget.value <= 0 then
                    label:setColor('#707070')
                else
                    label:setColor('#C0C0C0')
                end
            end
        end

        UI.conviction.info:setTooltipAlign(AlignTopLeft)

        if hasAug then
            UI.conviction.info:setTooltip(WheelDestiny.MediumPerkInfos.AugGeneralInfo)
        else
            UI.conviction.info:setTooltip(WheelDestiny.MediumPerkInfos.GeneralInfo)
        end
    end
end

WheelDestiny.updateGems = function()
    local UI = WheelDestiny.UI.main.wheel.base
    local sides = {
        [0] = "topLeft",
        [1] = "topRight",
        [2] = "bottomLeft",
        [3] = "bottomRight"
    }

    for i = 0, 3 do
        local side = sides[i]
        local widget = WheelDestiny.ActivedGem[i]

        if widget and widget.data then
            UI[side].gem:setVisible(true)
            UI[side].gem:setImageClip(torect(string.format("%d %d %d %d", (32 * widget.data.details.clip), 0, 32, 32)))
        else
            UI[side].gem:setVisible(false)
        end
    end
end

WheelDestiny.updateWheelGem = function()
    for id, data in pairs(WheelDestiny.GemSlots) do
        local gem = WheelDestiny.ActivedGem[data.affinity]
        local widget = WheelDestiny.GetSlotById(id)
        if widget then
            local max = WheelDestiny.Slots[id].max
            if widget.value >= max and gem then
                local alreadyAssigned = false
                for i = 1, 3 do
                    if WheelDestiny.ActivedGemSlots[data.affinity][i] and 
                       WheelDestiny.ActivedGemSlots[data.affinity][i].id == id then
                        alreadyAssigned = true
                        break
                    end
                end

                if not alreadyAssigned then
                    for i = 1, 3 do
                        if not WheelDestiny.ActivedGemSlots[data.affinity][i] then

                            local attribute = Gem_Atelier.getGemAttribute(i)
                            local clip = gem.data.object[attribute]

                            if clip then
                                WheelDestiny.ActivedGemSlots[data.affinity][i] = {
                                    id = id,
                                    clip = clip
                                }
    
                                if i ~= 3 then
                                    widget.mediumPerk:setImageSource("/mods/game_wheel/images/icons-skillwheel-basicmods")
                                    widget.mediumPerk:setSize({ width = 30, height = 30 })
                                    widget.mediumPerk:setImageClip(torect(string.format("%d 0 30 30", 30 * clip)))
                                else
                                    widget.mediumPerk:setImageSource("/mods/game_wheel/images/icons-skillwheel-suprememods")
                                    widget.mediumPerk:setSize({ width = 35, height = 35 })
                                    widget.mediumPerk:setImageClip(torect(string.format("%d 0 35 35", 35 * clip)))
                                end
                            end
                            break
                        end
                    end
                end
            else
                for i = 1, 3 do
                    if WheelDestiny.ActivedGemSlots[data.affinity][i] and 
                       WheelDestiny.ActivedGemSlots[data.affinity][i].id == id then

                        WheelDestiny.ActivedGemSlots[data.affinity][i] = nil
                        widget.mediumPerk:setImageSource("/mods/game_wheel/images/icons-skillwheel-mediumperks")
                        local mediumClip = 30 * WheelDestiny.Slots[id].perk[WheelDestiny.vocation].mediumClip
                        widget.mediumPerk:setImageClip(torect(string.format("%d 0 30 30", mediumClip)))
                        widget.mediumPerk:setSize({ width = 30, height = 30 })
                        break
                    end
                end
            end
        end
    end
end

WheelDestiny.updateSockets = function()
    local values = {
        [0] = 0,
        [1] = 0,
        [2] = 0,
        [3] = 0
    }

    for id, data in pairs(WheelDestiny.GemSlots) do
        local slot = WheelDestiny.UI.main.wheel.base.front:getChildById(id)
        if slot then
            local max = WheelDestiny.Slots[id].max
            if slot.value >= max then
                values[data.affinity] = values[data.affinity] + 1
            end
        end
    end

    for side, value in pairs(values) do
        local affinity = Gem_Atelier.getAffinityName(side)
        local gemSocket = Gem_Atelier.UI.vessels.base[affinity.."Socket"]
        local widget = WheelDestiny.UI.main.wheel.base[affinity]
        local disabled = WheelDestiny.ActivedGem[side] == nil
        
        local socketData = WheelDestiny.SocketsTier[side][value]

        if value > 0 then
            widget:setChecked(true)
            gemSocket:setVisible(true)
            widget.socket:setVisible(true)

            if disabled then
                gemSocket:setImageClip(torect(string.format("%d %d %d %d", (34 * socketData.disabled), 0, 34, 34)))
                widget.socket:setImageClip(torect(string.format("%d %d %d %d", (34 * socketData.disabled), 0, 34, 34)))
            else
                local quality = WheelDestiny.ActivedGem[side].data.object.quality
                if value > quality then
                    gemSocket:setImageClip(torect(string.format("%d %d %d %d", (34 * socketData.disabled), 0, 34, 34)))
                    widget.socket:setImageClip(torect(string.format("%d %d %d %d", (34 * socketData.disabled), 0, 34, 34)))
                else
                    gemSocket:setImageClip(torect(string.format("%d %d %d %d", (34 * socketData.enabled), 0, 34, 34)))
                    widget.socket:setImageClip(torect(string.format("%d %d %d %d", (34 * socketData.enabled), 0, 34, 34)))
                end
                
            end
        else
            widget:setChecked(false)
            gemSocket:setVisible(false)
            widget.socket:setVisible(false)
        end        
    end
end

WheelDestiny.updateBalance = function()
    local gold = WheelDestiny.Resources[0]
    local value = comma_value(gold)
    WheelDestiny.UI.main.goldBalance.value:setText(value)
end

WheelDestiny.onChangeGem = function()
    local widget = WheelDestiny.selected
    local side = WheelDestiny.GetSideIdByName(widget:getId())
    if not side then
        return
    end

    local gem = WheelDestiny.ActivedGem[side]
    WheelDestiny.changeHome(WheelDestiny.UI.buttons.gemButton, true)
    if gem then
        Gem_Atelier.onVesselFilter(side)
    else
        Gem_Atelier.UI.affinityFilter:setCurrentOption("All Affinities")
        Gem_Atelier.UI.qualityFilter:setCurrentOption("All Qualities")
    end
end

WheelDestiny.Toggle = function(Forced)
    if WheelDestiny.UI:isVisible() then
        WheelDestiny.UI:hide()
        WheelDestiny.Button:setOn(false)
        WheelDestiny.UI:unlock()
        return true
    end

    if Forced then
        WheelDestiny.preview = not g_game.getLocalPlayer():isPromoted()

        if not WheelDestiny.preview then
            WheelDestiny.UI:show()
            WheelDestiny.Button:setOn(true)
            WheelDestiny.UI:lock()
        else
            local confirmWindow = nil

            local function yesCallback()
                if confirmWindow then
                    confirmWindow:destroy()
                    confirmWindow = nil
                    WheelDestiny.UI:show()
                end

            end

            local function noCallback()
                if confirmWindow then
                    confirmWindow:destroy()
                    confirmWindow = nil
                end
            end

            if not confirmWindow then
                confirmWindow = displayGeneralBox(tr('Info'), tr(
                    'To be able to use the Wheel of Destiny, a character must be at least level 51, be promoted and have active\nPremium Time.\n\nClick on "Ok" to see a preview of the Wheel of Destiny for your vocation.'),
                    {
                        {
                            text = tr('Ok'),
                            callback = yesCallback
                        },
                        {
                            text = tr('Cancel'),
                            callback = noCallback
                        },
                        anchor = AnchorHorizontalCenter
                    }, yesCallback, noCallback)
            end
        end
        Fragment_Workshop.reset()
        g_game.requestWheelOfDestiny()
    end
end

WheelDestiny.ShowNewPreset = function(isImport)
    WheelDestiny.UI:hide()
    WheelDestiny.UI:unlock()
    WheelDestiny.PresetNew:show()
    WheelDestiny.PresetNew:lock()

    if isImport then
        WheelDestiny.SelectedNewPresetRadio:selectWidget(WheelDestiny.PresetNew.contentPanel.import)
    else
        WheelDestiny.SelectedNewPresetRadio:selectWidget(WheelDestiny.PresetNew.contentPanel.useEmpty)
    end

    WheelDestiny.PresetNew.contentPanel.presetName:clearText()
    WheelDestiny.PresetNew.contentPanel.presetCode:clearText()
    
end

WheelDestiny.HideNewPreset = function()
    WheelDestiny.PresetNew:unlock()
    WheelDestiny.PresetNew:hide()
    WheelDestiny.UI:show()
    WheelDestiny.UI:lock()
end

WheelDestiny.ShowRenamePreset = function()
    WheelDestiny.UI:hide()
    WheelDestiny.UI:unlock()
    WheelDestiny.PresetRename:show()
    WheelDestiny.PresetRename:lock()

    WheelDestiny.PresetRename.contentPanel.presetName:setText(WheelDestiny.currentPreset.presetName)
end

WheelDestiny.HideRenamePreset = function()
    WheelDestiny.PresetRename:unlock()
    WheelDestiny.PresetRename:hide()
    WheelDestiny.UI:show()
    WheelDestiny.UI:lock()
end

WheelDestiny.PresetInit = function()
    WheelDestiny.SelectedNewPresetRadio = UIRadioGroup.create()
    WheelDestiny.SelectedNewPresetRadio:addWidget(WheelDestiny.PresetNew.contentPanel.useEmpty)
    WheelDestiny.SelectedNewPresetRadio:addWidget(WheelDestiny.PresetNew.contentPanel.copyPreset)
    WheelDestiny.SelectedNewPresetRadio:addWidget(WheelDestiny.PresetNew.contentPanel.import)
    WheelDestiny.SelectedNewPresetRadio:selectWidget(WheelDestiny.PresetNew.contentPanel.import)
    WheelDestiny.SelectedNewPresetRadio.onSelectionChange = WheelDestiny.OnNewPresetSelectionChange


    WheelDestiny.PresetNew.contentPanel.presetName.onTextChange = function(self, text, oldText)
        WheelDestiny.SelectedNewPresetRadio:selectWidget(WheelDestiny.PresetNew.contentPanel.import)
        local code = WheelDestiny.ValidadeImportCode(text)
        if #code == 0 then
            WheelDestiny.PresetNew.contentPanel.importTooltip:setVisible(true)
            WheelDestiny.PresetNew.contentPanel.importTooltip:setTooltip(code)
            WheelDestiny.PresetNew.contentPanel.ok:setEnabled(false)
            return
        end

        WheelDestiny.PresetNew.contentPanel.importTooltip:setVisible(false)
        WheelDestiny.PresetNew.contentPanel.ok:setEnabled(WheelDestiny.CheckPresetName(WheelDestiny.PresetNew.contentPanel.presetName:getText()))
    end
end

WheelDestiny.OnImportConfig = function(base64Data)
    if not base64Data or base64Data == "" then
        return {}
    end

    if not base64.isValidBase64(base64Data) then
        return {}
    end

    local decodedData = base64.decode(base64Data)
    local points = string.unpack_custom("I2", decodedData)

    local pointInvested = {}
    local equipedGems = {}

    local index = 3
    local usedPoints = 0

    while index <= #decodedData do
        local value = string.unpack_custom("I1", decodedData:sub(index, index))

        if WheelDestiny.points then
            if usedPoints + value > WheelDestiny.points then
                value = WheelDestiny.points - usedPoints
                if value < 0 then
                value = 0
                end
            end
        end

        table.insert(pointInvested, value)
        usedPoints = usedPoints + value 
        index = index + 1

        if index >= 39 then
            break
        end
    end

	while index <= #decodedData do
		local value = string.unpack_custom("I1", decodedData:sub(index, index))
		table.insert(equipedGems, value)
		index = index + 1
	end

	if usedPoints > points or #pointInvested ~= 36 or #equipedGems ~= 4 then
		return {}
	end

	return { maxPoints = points, usedPoints = usedPoints, pointInvested = pointInvested, equipedGems = equipedGems }
end

WheelDestiny.ValidadeImportCode = function(code)
	if not code or #code < 3 then
		return "Export code does not match a valid Wheel of Destiny."
	end

	local vocationId = tonumber(code:sub(1, 2)) or 0
	local base64Data = code:sub(3)

	local currentVocation = getVocationSt(vocationId)
	if currentVocation ~= getVocationSt(vocation) then
		return "Export code does not match the character's vocation."
	end

	if not base64.isValidBase64(base64Data) or table.empty(WheelDestiny.OnImportConfig(base64Data)) then
		return "Export code does not match a valid Wheel of Destiny."
	end
	return ""
end

WheelDestiny.CheckPresetName = function(text)
    for _, data in pairs(WheelDestiny.InternalPreset) do
        if data.presetName == text then
            return false
        end
    end
    return #text > 1
end

WheelDestiny.OnNewPresetSelectionChange = function()
    local selectedOption = WheelDestiny.SelectedNewPresetRadio:getSelectedWidget()
    if not selectedOption then
        return true
    end

    local presetName = WheelDestiny.PresetNew.contentPanel.presetName:getText()
    local isValid = WheelDestiny.CheckPresetName(presetName)
    
    if selectedOption == WheelDestiny.PresetNew.contentPanel.import then
        local presetCode = WheelDestiny.PresetNew.contentPanel.presetCode:getText()
        local checkCode = (#WheelDestiny.ValidadeImportCode(presetCode) > 0)
        WheelDestiny.PresetNew.contentPanel.ok:setEnabled(isValid and checkCode)
        return
    end

    WheelDestiny.PresetNew.contentPanel.ok:setEnabled(isValid)
end

WheelDestiny.ExportCode = function()
    if WheelDestiny.ExportCodeWindow then
        WheelDestiny.ExportCodeWindow:destroy()
    end

    WheelDestiny.UI:hide()
    WheelDestiny.UI:unlock()

    local codeButton = function()
        if WheelDestiny.ExportCodeWindow then
            WheelDestiny.ExportCodeWindow:unlock()
            WheelDestiny.ExportCodeWindow:destroy()
            WheelDestiny.ExportCodeWindow = nil
        end

        WheelDestiny.UI:show()
        WheelDestiny.UI:lock()
        WheelDestiny.OnExportConfig()
        return true
    end

    local cancelButton = function()
        if WheelDestiny.ExportCodeWindow then
            WheelDestiny.ExportCodeWindow:unlock()
            WheelDestiny.ExportCodeWindow:destroy()
            WheelDestiny.ExportCodeWindow = nil
        end

        WheelDestiny.UI:show()
        WheelDestiny.UI:lock()
        return false
    end

    WheelDestiny.ExportCodeWindow = displayGeneralBox('Copy to Clipboard', tr("Copy export code or URL of the planner to clipboard."),
    {
        { text=tr('Code'), callback=codeButton },
        { text=tr('URL'), callback=nil, disabled=true },
        { text=tr('Cancel'), callback=cancelButton }
    }, confirm, deny)

    WheelDestiny.ExportCodeWindow:lock()
end

WheelDestiny.OnExportConfig = function()

end

WheelDestiny.UpdateCurrentPreset = function()
    if not WheelDestiny.currentPreset then
        return
    end
end