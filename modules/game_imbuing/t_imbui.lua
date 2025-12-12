-- === FUNCIONES DE AYUDA GLOBALES ===
function comma_value(n)
    if not n then return "0" end
    local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
    return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

if not string.capitalize then
    function string.capitalize(str)
        return (str:gsub("^%l", string.upper))
    end
end

function getItemNameById(itemId)
    local itemType = g_things.getThingType(itemId, ThingCategoryItem)
    if itemType and itemType.getName then
        return itemType:getName()
    end
    return "Unknown Item"
end

function getFramePosition(frameIndex, frameWidth, frameHeight, columns)
    local realIndex = frameIndex - 1 
    local row = math.floor(realIndex / columns)
    local col = realIndex % columns
    local x = col * frameWidth
    local y = row * frameHeight
    return string.format("%d %d", x, y)
end

function getPlayerBalance()
    local player = g_game.getLocalPlayer()
    if not player then return 0 end
    local bankGold = player:getResourceBalance(1) or 0
    local inventoryGold = player:getResourceBalance(0) or 0
    return bankGold + inventoryGold
end

function getPlayerItemCount(itemId)
    local player = g_game.getLocalPlayer()
    if not player then return 0 end
    local total = 0
    for i=1, 10 do 
        local item = player:getInventoryItem(i)
        if item and item:getId() == itemId then
            total = total + item:getCount()
        end
    end
    return total
end
-- ===================================

if not Imbuement then
  Imbuement = {
    window = nil,
    selectItemOrScroll = nil,
    scrollImbue = nil,
    selectImbue = nil,
    clearImbue = nil,
    messageWindow = nil,
    bankGold = 0,
    inventoryGold = 0,
  }
  Imbuement.__index = Imbuement
end

Imbuement.MessageDialog = {
  ImbuementSuccess = 0,
  ImbuementError = 1,
  ImbuementRollFailed = 2,
  ImbuingStationNotFound = 3,
  ClearingCharmSuccess = 10,
  ClearingCharmError = 11,
  PreyMessage = 20,
  PreyError = 21,
}

local self = Imbuement

function Imbuement.init()
  self.window = g_ui.displayUI('t_imbui')
  self:hide()

  ImbuementSelection:startUp()

  self.selectItemOrScroll = self.window:recursiveGetChildById('selectItemOrScroll')
  self.scrollImbue = self.window:recursiveGetChildById('scrollImbue')
  self.selectImbue = self.window:recursiveGetChildById('selectImbue')
  self.clearImbue = self.window:recursiveGetChildById('clearImbue')

  connect(g_game, {
    onGameStart = self.offline,
    onGameEnd = self.offline,
    onOpenImbuementWindow = self.onOpenImbuementWindow,
    onImbuementItem = self.onImbuementItem,
    onImbuementScroll = self.onImbuementScroll,
    onResourceBalance = self.onResourceBalance,
    onCloseImbuementWindow = self.offline,
    onMessageDialog = self.onMessageDialog,
  })
end

function Imbuement.terminate()
  disconnect(g_game, {
    onGameStart = self.offline,
    onGameEnd = self.offline,
    onOpenImbuementWindow = self.onOpenImbuementWindow,
    onImbuementItem = self.onImbuementItem,
    onImbuementScroll = self.onImbuementScroll,
    onResourceBalance = self.onResourceBalance,
    onCloseImbuementWindow = self.offline,
    onMessageDialog = self.onMessageDialog,
  })

  if self.messageWindow then
    self.messageWindow:destroy()
    self.messageWindow = nil
  end

  if ImbuementItem then ImbuementItem:shutdown() end
  if ImbuementSelection then ImbuementSelection:shutdown() end
  if ImbuementScroll then ImbuementScroll:shutdown() end

  if self.selectItemOrScroll then self.selectItemOrScroll:destroy(); self.selectItemOrScroll = nil end
  if self.scrollImbue then self.scrollImbue:destroy(); self.scrollImbue = nil end
  if self.selectImbue then self.selectImbue:destroy(); self.selectImbue = nil end
  if self.clearImbue then self.clearImbue:destroy(); self.clearImbue = nil end
  if self.window then self.window:destroy(); self.window = nil end
end

function Imbuement.online()
 self:hide()
 if self.messageWindow then
   self.messageWindow:destroy()
   self.messageWindow = nil
 end
end

function Imbuement.offline()
  self:hide()
  if ImbuementItem then ImbuementItem:shutdown() end
  if ImbuementScroll then ImbuementScroll:shutdown() end
  if self.messageWindow then
    self.messageWindow:destroy()
    self.messageWindow = nil
  end
end

function Imbuement.show()
  self.window:show(true)
  self.window:raise()
  self.window:focus()
  if self.messageWindow then
    self.messageWindow:destroy()
    self.messageWindow = nil
  end
end

function Imbuement.hide()
  self.window:hide()
end

function Imbuement.close()
  if g_game.isOnline() then
    g_game.closeImbuingWindow()
  end
  self.window:hide()
end

function Imbuement:toggleMenu(menu)
  for key, value in pairs(self) do
    if type(value) ~= 'userdata' or key == 'window' then
      goto continue
    end

    if key == menu then
      value:show()
    else
      value:hide()
    end
    ::continue::
  end
end

function Imbuement.onOpenImbuementWindow()
  self:show()
  local total = getPlayerBalance()
  if self.window.contentPanel and self.window.contentPanel.gold and self.window.contentPanel.gold.text then
      self.window.contentPanel.gold.text:setText(comma_value(total))
  end
  self:toggleMenu("selectItemOrScroll")
end

function Imbuement.onImbuementItem(arg1, arg2, arg3, arg4, arg5, arg6)
    local itemId = arg1
    local tier = 0
    local slots = 0
    local activeSlots = {}
    local availableImbuements = {}
    local needItemsList = {}

    if type(arg3) == 'table' or (arg3 == nil and type(arg2) == 'number') then
        tier = 0 
        slots = tonumber(arg2) or 0
        activeSlots = arg3 or {}
        availableImbuements = arg4
        needItemsList = arg5
    else
        tier = arg2
        slots = tonumber(arg3) or 0
        activeSlots = arg4 or {}
        availableImbuements = arg5
        needItemsList = arg6
    end

    -- [FIX PARA QUE NO SE ABRA LA VENTANA]
    if slots <= 0 then
        modules.game_textmessage.displayFailureMessage(tr("This item is not imbuable."))
        -- Forzamos ocultar la ventana y volver al menú principal (Pick Item)
        self:show() 
        self:toggleMenu("selectItemOrScroll") 
        return
    end

    local needItemsMap = {}
    if needItemsList then
        for _, item in pairs(needItemsList) do
            local id = item.getId and item:getId() or item['id']
            local count = item.getCount and item:getCount() or item['count'] or 0
            if id then
                needItemsMap[id] = count
            end
        end
    end

    self:show()
    self:toggleMenu("selectImbue")
    ImbuementItem.setup(itemId, tier, slots, activeSlots, availableImbuements, needItemsMap)
end

function Imbuement.onImbuementScroll(availableImbuements, needItemsList)
    local needItemsMap = {}
    if needItemsList then
        for _, item in pairs(needItemsList) do
            local id = item.getId and item:getId() or item['id']
            local count = item.getCount and item:getCount() or item['count'] or 0
            if id then
                needItemsMap[id] = count
            end
        end
    end

    self:show()
    self:toggleMenu("scrollImbue")
    ImbuementScroll.setup(availableImbuements, needItemsMap)
end

function Imbuement.onSelectItem()
  self:hide()
  ImbuementSelection:selectItem()
end

function Imbuement.onSelectScroll()
   g_game.selectImbuementScroll()
end

function Imbuement.onResourceBalance(type, balance)
  local total = getPlayerBalance()
  if self.window.contentPanel and self.window.contentPanel.gold and self.window.contentPanel.gold.text then
      self.window.contentPanel.gold.text:setText(comma_value(total))
  end
end

function Imbuement.onMessageDialog(type, content)
  if type > Imbuement.MessageDialog.ImbuingStationNotFound or not self.window:isVisible() then
    return
  end

  self:hide()
  
  if self.messageWindow then
    self.messageWindow:destroy()
    self.messageWindow = nil
  end

  local function confirm()
      self.messageWindow:destroy()
      self.messageWindow = nil
      Imbuement.show()
  end

  self.messageWindow = displayGeneralBox(tr('Message Dialog'), content,
    { { text=tr('Ok'), callback=confirm },
    }, confirm, confirm)
end