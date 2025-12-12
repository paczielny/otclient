if not ImbuementSelection then
  ImbuementSelection = {
    pickItem = nil,
  }
end

ImbuementSelection.__index = ImbuementSelection

local m_interface = modules.game_interface

local self = ImbuementSelection
function ImbuementSelection.startUp()
  self.pickItem = g_ui.createWidget('UIWidget')
  self.pickItem:setVisible(false)
  self.pickItem:setFocusable(false)
  self.pickItem.onMouseRelease = self.onChooseItemMouseRelease
end

function ImbuementSelection:shutdown()
  if self.pickItem then
    self.pickItem:destroy()
    self.pickItem = nil
  end
end

function ImbuementSelection:selectItem()
  if not self.pickItem then
    self:startUp()
  end

  if g_ui.isMouseGrabbed() then return end
  
  self.pickItem:grabMouse()
  g_mouse.pushCursor('target')
end

function ImbuementSelection.onChooseItemMouseRelease(widget, mousePosition, mouseButton)
  local item = nil
  if mouseButton == MouseLeftButton then
    local clickedWidget = m_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
    if clickedWidget then
      if clickedWidget:getClassName() == 'UIGameMap' then
        local tile = clickedWidget:getTile(mousePosition)
        if tile then
          local thing = tile:getTopMoveThing()
          if thing and thing:isItem() then
            item = thing
          end
        end
      elseif clickedWidget:getClassName() == 'UIItem' and not clickedWidget:isVirtual() then
        item = clickedWidget:getItem()
      end
    end
  end

  if item and item:isPickupable() then
    -- Enviamos la petición. La ventana SOLO se abrirá si el servidor responde y t_imbui.lua lo valida.
    g_game.selectImbuementItem(item:getId(), item:getPosition(), item:getStackPos())
  else
    modules.game_textmessage.displayFailureMessage(tr('Sorry, not possible.'))
    -- Si el clic fue inválido (suelo vacío), restauramos la ventana para no trabar al jugador
    Imbuement:show()
  end

  self.pickItem:ungrabMouse()
  g_mouse.popCursor('target')
  return true
end