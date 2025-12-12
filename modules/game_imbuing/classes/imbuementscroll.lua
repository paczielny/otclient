if not ImbuementScroll then
  ImbuementScroll = {
    window = nil,
    itemId = 51442,
    confirmWindow = nil,
    availableImbuements = {},
    needItems = {}
  }
end

ImbuementScroll.__index = ImbuementScroll

local self = ImbuementScroll
function ImbuementScroll.setup(availableImbuements, needItems)
    self.availableImbuements = availableImbuements or {}
    self.needItems = needItems or {}

    self.window = Imbuement.scrollImbue

    local itemWidget = self.window:recursiveGetChildById("itemScroll")
    if itemWidget then
        itemWidget:setItemId(self.itemId)
        itemWidget:setImageSmooth(true)
        itemWidget:setItemCount(1)
    end

    self.onSelectSlotImbue()
end

function ImbuementScroll:shutdown()
    self.window = nil
    self.confirmWindow = nil
    self.availableImbuements = {}
    self.needItems = {}
end

function ImbuementScroll.onSelectSlotImbue()
    self.selectBaseType('powerfullButton')
    self.window:recursiveGetChildById('imbuementsDetails'):setVisible(false)
end

function ImbuementScroll.selectBaseType(selectedButtonId)
    local qualityAndImbuementContent = self.window:recursiveGetChildById("qualityAndImbuementContent")
    if not qualityAndImbuementContent then return end

    local intricateButton = qualityAndImbuementContent.intricateButton
    local powerfullButton = qualityAndImbuementContent.powerfullButton

    local baseImbuement = 1
    for _, button in pairs({intricateButton, powerfullButton}) do
        button:setOn(button:getId() == selectedButtonId)
        if button:getId() == selectedButtonId then
            baseImbuement = button.baseImbuement or 1
        end
    end

    local imbuementsList = self.window:recursiveGetChildById("imbuementsList")
    imbuementsList:destroyChildren()

    local imbuementsDetails = self.window:recursiveGetChildById("imbuementsDetails")
    imbuementsDetails:setVisible(false)

    local groupToType = {
        ["Basic"] = 0, ["basic"] = 0, [1] = 0, ["1"] = 0,
        ["Intricate"] = 1, ["intricate"] = 1, [2] = 1, ["2"] = 1,
        ["Powerful"] = 2, ["powerful"] = 2, [3] = 2, ["3"] = 2
    }

    local visibleIcons = 0
    local iconWidth = 72
    local selected = false

    for id, imbuement in pairs(self.availableImbuements) do
        local currentType = imbuement.type
        if currentType == nil and imbuement.group then
            currentType = groupToType[imbuement.group]
        end

        if currentType == baseImbuement then
            local widget = g_ui.createWidget("SlotImbuing", imbuementsList)
            widget:setId(tostring(id))
            widget.resource:setImageSource("/images/game/imbuing/imbuement-icons-64")
            
            if imbuement.imageId then
                -- [FIX] 12 Columnas
                widget.resource:setImageClip(getFramePosition(imbuement.imageId + 21, 64, 64, 21) .. " 64 64")
            end

            if not selected then
                ImbuementScroll.selectImbuementWidget(widget, imbuement)
                selected = true
            end

            widget.onClick = function()
                ImbuementScroll.selectImbuementWidget(widget, imbuement)
            end
            visibleIcons = visibleIcons + 1
        end
    end
    
    local newWidth = visibleIcons * iconWidth
    if newWidth > 680 then newWidth = 680 end
    if newWidth < 70 then newWidth = 70 end
    imbuementsList:setWidth(newWidth)
end

-- Esta función debe estar antes de ser llamada
function ImbuementScroll.onSelectImbuement(widget)
    local imbuementId = tonumber(widget:getId())
    local imbuement = self.availableImbuements[imbuementId]
    if not imbuement then
        return
    end

    local imbuementReqPanel = self.window:recursiveGetChildById("imbuementReqPanel")
    if imbuementReqPanel then
        imbuementReqPanel.title:setText(string.format('Imbue Blank Scroll with "%s"', imbuement.name))
    end
    local itensDetails = self.window:recursiveGetChildById("itensDetails")
    if itensDetails then
        itensDetails:setText("")
    end
end

function ImbuementScroll.selectImbuementWidget(widget, imbuement)
    if self.lastselectedwidget then
        self.lastselectedwidget:setBorderWidth(1)
        self.lastselectedwidget:setBorderColorTop("#797979")
        self.lastselectedwidget:setBorderColorLeft("#797979")
        self.lastselectedwidget:setBorderColorRight("#2e2e2e")
        self.lastselectedwidget:setBorderColorBottom("#2e2e2e")
    end
    self.lastselectedwidget = widget
    widget:setBorderWidth(1)
    widget:setBorderColor("white")

    -- [FIX] Llamada explícita
    ImbuementScroll.onSelectImbuement(widget)

    local imbuementsDetails = self.window:recursiveGetChildById("imbuementsDetails")
    if imbuementsDetails then
        imbuementsDetails:setVisible(true)
        imbuementsDetails:setText(imbuement.description or "")
    end

    local requiredItems = self.window:recursiveGetChildById("requiredItems")
    local hasRequiredItems = true
    if requiredItems then
        for i = 1, 4 do
            local itemWidget = requiredItems:getChildById("item"..i)
            if itemWidget then
                local source = imbuement.sources[i]
                if source then
                    itemWidget.item:setItemId(source.item:getId())
                    itemWidget:setVisible(true)
                    
                    local reqCount = source.item.getCount and source.item:getCount() or source.item['count'] or 1
                    local reqId = source.item.getId and source.item:getId() or source.item['id']
                    
                    local playerItemCount = self.needItems[reqId] or 0
                    
                    itemWidget.count:setText(playerItemCount .."/" .. reqCount)
                    
                    if playerItemCount >= reqCount then
                        itemWidget.count:setColor("#c0c0c0")
                    else
                        hasRequiredItems = false
                        itemWidget.count:setColor("#ff5555")
                    end

                    itemWidget.onHoverChange = function(widget, hovered)
                        local itensDetails = self.window:recursiveGetChildById("itensDetails")
                        if hovered then
                            if playerItemCount >= reqCount then
                                itensDetails:setText(string.format("The imbuement you have selected requires %s.", source.description))
                            else
                                itensDetails:setText(string.format("The imbuement requires %s. Unfortunately you do not own the needed amount.", source.description))
                            end
                        else
                            if itensDetails then
                                itensDetails:setText("")
                            end
                        end
                    end
                else
                    itemWidget:setVisible(false)
                end
            end
        end
    end

    local costPanel = self.window:recursiveGetChildById("costPanel")
    if costPanel then
        local cost = imbuement.cost or 0
        costPanel.cost:setText(comma_value(cost))
        
        local player = g_game.getLocalPlayer()
        local playerBank = player:getResourceBalance(1)
        local playerInventory = player:getResourceBalance(0)
        local balance = playerBank + playerInventory

        if balance < cost then
            hasRequiredItems = false
        end

        costPanel.cost:setColor(balance < cost and "#ff5555" or "#c0c0c0")
    end

    local imbuescrollApply = self.window:recursiveGetChildById("imbuescrollApply")
    if imbuescrollApply then
        imbuescrollApply:setEnabled(hasRequiredItems)
        if not hasRequiredItems then
           imbuescrollApply:setImageSource("/images/game/imbuing/imbue_empty")
           imbuescrollApply:setImageClip("0 0 128 66")
        else
            imbuescrollApply:setImageSource("/images/game/imbuing/imbue_green")
        end

        imbuescrollApply.onHoverChange = function(widget, hovered, itemName, hasItem)
            local itensDetails = self.window:recursiveGetChildById("itensDetails")
            if hovered then
                itensDetails:setText(tr("Apply the selected imbuement. This will consume the required astral sources and gold."))
            else
                if itensDetails then
                    itensDetails:setText("")
                end
            end
        end

        imbuescrollApply.onClick = function()
            if self.confirmWindow then
                self.confirmWindow:destroy()
                self.confirmWindow = nil
            end

            Imbuement.hide()

            local function confirm()
                g_game.applyImbuement(0, imbuement.id, false)
                self.confirmWindow:destroy()
                self.confirmWindow = nil
                Imbuement.show()
            end

            local function cancelFunc()
                if self.confirmWindow then
                    self.confirmWindow:destroy()
                    self.confirmWindow = nil
                end
                Imbuement.show()
            end

            self.confirmWindow = displayGeneralBox(tr('Confirm Imbuing'), tr("You are about to imbue your item with \"%s\". This will consume the required astral sources and %s\ngold coins. Do you wish to proceed?", string.capitalize(imbuement.name), comma_value(imbuement.cost)),
            { { text=tr('Yes'), callback=confirm },
                { text=tr('No'), callback=cancelFunc },
            }, confirm, cancelFunc)
        end
    end
end