Prey = {}


preyWindow = nil
preyButton = nil
preyTracker = nil
local preyTrackerButton
local msgWindow
local bankGold = 0
local inventoryGold = 0
local rerollPrice = 0
local bonusRerolls = 0

local timeUntilFreeRerollSlots = {0, 0, 0}
local bestiaryDataCache = {}

function requestBestiaryData(raceId)
    if g_game.requestBestiarySearch then
        g_game.requestBestiarySearch(raceId)
    end
end

function getBestiaryData(raceId)
    return bestiaryDataCache[raceId]
end

function cacheBestiaryData(raceId, data)
    bestiaryDataCache[raceId] = data
end

function onBestiaryMonsterData(data)
    if data and data.id then
        local raceId = data.id
        local bestiaryData = {
            raceId = raceId,
            difficulty = data.difficulty or nil,
            thirdDifficulty = data.thirdDifficulty or 0,
            secondUnlock = data.secondUnlock or 0,
            lastProgressKillCount = data.lastProgressKillCount or 0,
            killCounter = data.killCounter or 0,
            currentLevel = data.currentLevel or 0
        }
        
        cacheBestiaryData(raceId, bestiaryData)
        updateAmountOptionsForRaceId(raceId)
    end
end

function isBestiaryCompleted(raceId)
    local bestiaryData = getBestiaryData(raceId)
    if bestiaryData and bestiaryData.currentLevel then
        return bestiaryData.currentLevel >= 3
    end
    return false
end

local function getBaseAmountForRaceId(raceId)
    local firstKills = _G['taskHuntingFirstKills']
    if firstKills and #firstKills > 0 then
        local amount = firstKills[1]
        return amount
    end
    return 25
end

function updateAmountOptionsForRaceId(raceId)

    for slot = 0, 2 do
        local taskHuntingSlot = getTaskHuntingSlot(slot)
        if taskHuntingSlot and taskHuntingSlot.inactive then
            local rerollList = taskHuntingSlot.inactive:getChildById('rerollList')
            local monsterList = taskHuntingSlot.inactive:getChildById('monsterList')

            if rerollList then
                for _, child in pairs(rerollList:getChildren()) do
                    if child.raceId == raceId and child:isChecked() then
                        updateAmountPanel(taskHuntingSlot, slot, raceId, 'inactiveAmount3x3', 'amountOption1_3x3', 'amountOption2_3x3')
                        return
                    end
                end
            end

            if monsterList then
                local selectedRaceId = _G['selectedPreyRace_' .. slot]
                if selectedRaceId == raceId then
                    updateAmountPanel(taskHuntingSlot, slot, raceId, 'inactiveAmount', 'amountOption1', 'amountOption2')
                    return
                end
            end
        end
    end
end

local PREY_BONUS_DAMAGE_BOOST = 0
local PREY_BONUS_DAMAGE_REDUCTION = 1
local PREY_BONUS_XP_BONUS = 2
local PREY_BONUS_IMPROVED_LOOT = 3
local PREY_BONUS_NONE = 4

local PREY_ACTION_LISTREROLL = 0
local PREY_ACTION_BONUSREROLL = 1
local PREY_ACTION_MONSTERSELECTION = 2
local PREY_ACTION_REQUEST_ALL_MONSTERS = 3
local PREY_ACTION_CHANGE_FROM_ALL = 4
local PREY_ACTION_LOCK_PREY = 5
local PREY_ACTION_CANCEL = 6
local PREY_ACTION_CLAIM = 7

local TASK_HUNTING_ACTION_LISTREROLL = 0
local TASK_HUNTING_ACTION_REWARDSREROLL = 1
local TASK_HUNTING_ACTION_LISTALL_CARDS = 2
local TASK_HUNTING_ACTION_MONSTERSELECTION = 3
local TASK_HUNTING_ACTION_CANCEL = 4
local TASK_HUNTING_ACTION_CLAIM = 5



function getSlotTypeBySlotNumber(slot)
    local slotType = getSlotTypeByCurrentTab(slot)
    return slotType
end

function calculateHTPPoints(stars, difficulty, requiredKills)
    local baseHTP = 0
    
    if difficulty == "easy" then
        if stars == 1 then baseHTP = 10
        elseif stars == 2 then baseHTP = 12
        elseif stars == 3 then baseHTP = 14
        elseif stars == 4 then baseHTP = 16
        elseif stars == 5 then baseHTP = 19
        end
    elseif difficulty == "medium" then
        if stars == 1 then baseHTP = 40
        elseif stars == 2 then baseHTP = 48
        elseif stars == 3 then baseHTP = 58
        elseif stars == 4 then baseHTP = 70
        elseif stars == 5 then baseHTP = 96
        end
    elseif difficulty == "hard" then
        if stars == 1 then baseHTP = 160
        elseif stars == 2 then baseHTP = 192
        elseif stars == 3 then baseHTP = 230
        elseif stars == 4 then baseHTP = 276
        elseif stars == 5 then baseHTP = 456
        end
    end

    local isUpgraded = false
    if requiredKills >= 50 and requiredKills <= 99 then
        isUpgraded = true 
    elseif requiredKills >= 200 and requiredKills <= 399 then
        isUpgraded = true
    elseif requiredKills >= 800 then
        isUpgraded = true
    end

    if isUpgraded then
        baseHTP = baseHTP * 2
    end
    
    return baseHTP
end


function getSlotTypeByCurrentTab(slot)
    if preyWindow then
        local prey1Panel = preyWindow:getChildById('prey1Panel')
        local prey2Panel = preyWindow:getChildById('prey2Panel')
        
        local prey1Visible = prey1Panel and prey1Panel:isVisible()
        local prey2Visible = prey2Panel and prey2Panel:isVisible()
        
        if prey1Visible then
            return "prey"
        elseif prey2Visible then
            return "taskhunting"
        end
    end
    
    return "prey"
end

function executePreyAction(slot, action, ...)
    local slotType = getSlotTypeBySlotNumber(slot)
    
    if slotType == "taskhunting" then
        local taskAction = action
        if action == PREY_ACTION_LISTREROLL then
            taskAction = TASK_HUNTING_ACTION_LISTREROLL
        elseif action == PREY_ACTION_BONUSREROLL then
            taskAction = TASK_HUNTING_ACTION_REWARDSREROLL
        elseif action == PREY_ACTION_MONSTERSELECTION then
            taskAction = TASK_HUNTING_ACTION_MONSTERSELECTION
        elseif action == PREY_ACTION_REQUEST_ALL_MONSTERS then
            taskAction = TASK_HUNTING_ACTION_LISTALL_CARDS
        elseif action == PREY_ACTION_CHANGE_FROM_ALL then
            taskAction = TASK_HUNTING_ACTION_MONSTERSELECTION
        elseif action == PREY_ACTION_LOCK_PREY then
            taskAction = TASK_HUNTING_ACTION_CANCEL
        elseif action == PREY_ACTION_CANCEL then
            taskAction = TASK_HUNTING_ACTION_CANCEL
        elseif action == PREY_ACTION_CLAIM then
            taskAction = TASK_HUNTING_ACTION_CLAIM
        end
        
        if g_game.taskHuntingAction then
        local raceId = select(1, ...) or 0
        return g_game.taskHuntingAction(slot, taskAction, false, raceId)
        else
            return false
        end
    elseif slotType == "prey" then
        return g_game.preyAction(slot, action, ...)
    else
        return false
    end
end

local preyDescription = {}



function comma_value(n)
    local left, num, right = string.match(n, '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

function format_gold(amount)
    if not amount or amount == 0 then
        return "0"
    end
    local num = tonumber(amount) or 0

    if num >= 1000000 then
        local kk = num / 1000000
        local formatted_kk = comma_value(string.format("%.2f", kk))
        return formatted_kk .. "kk"
    elseif num >= 1000 then
        local k = num / 1000
        local formatted_k = comma_value(string.format("%.2f", k))
        return formatted_k .. "k"
    else
        return comma_value(tostring(num))
    end
end

function isRerollFree(slot)
    if not slot or slot < 0 or slot > 5 then
        g_logger.error("isRerollFree: invalid slot " .. tostring(slot))
        return false
    end
    
    local timeLeft = timeUntilFreeRerollSlots[slot + 1]
    local isFree = timeLeft == 0
    
    return isFree
end

function filterCreatures(slot, searchText)
    if not _G['preyRaceData_' .. slot] then
        return
    end
    
    local searchLower = string.lower(searchText or '')
    
    for i, raceData in ipairs(_G['preyRaceData_' .. slot]) do
        if raceData.label then
            raceData.label:setVisible(false)
        end
    end
    
    for i, raceData in ipairs(_G['preyRaceData_' .. slot]) do
        if raceData.label then
            if searchText == '' or string.find(string.lower(raceData.name), searchLower, 1, true) then
                raceData.label:setVisible(true)
            end
        end
    end
end

function filterTaskHuntingCreatures(slot, searchText)
    if not _G['taskHuntingRaceData_' .. slot] then
        return
    end
    
    local searchLower = string.lower(searchText or '')
    
    for i, raceData in ipairs(_G['taskHuntingRaceData_' .. slot]) do
        if raceData.label then
            raceData.label:setVisible(false)
        end
    end
    
    for i, raceData in ipairs(_G['taskHuntingRaceData_' .. slot]) do
        if raceData.label then
            if searchText == '' or string.find(string.lower(raceData.name), searchLower, 1, true) then
                raceData.label:setVisible(true)
            end
        end
    end
end

function onTaskHuntingConfirm(widget)
    local slot = nil
    for tab = 1, 2 do
        local panel = preyWindow:getChildById('prey' .. tab .. 'Panel')
        if panel then
            for i = 1, 3 do
                local slotWidget = panel:getChildById('slot' .. i)
                if slotWidget then
                    local inactive = slotWidget:getChildById('inactive')
                    if inactive and inactive:isVisible() then
                        local monsterList = inactive:getChildById('monsterList')
                        local rerollList = inactive:getChildById('rerollList')
                        
                        if monsterList and monsterList:isVisible() then
                            slot = i - 1
                            break
                        elseif rerollList and rerollList:isVisible() then
                            slot = i - 1
                            break
                        end
                    end
                end
            end
            if slot then break end
        end
    end
    
    if not slot then
        return
    end
    
    local raceId = _G['selectedPreyRace_' .. slot]
    if not raceId then
        return
    end
    
    g_game.taskHuntingAction(slot, TASK_HUNTING_ACTION_MONSTERSELECTION, false, raceId)
end

_G.onTaskHuntingConfirm = onTaskHuntingConfirm
_G.onItemBoxChecked = onItemBoxChecked
_G.onTaskHuntingClaim = onTaskHuntingClaim
_G.onTaskHuntingUpgrade = onTaskHuntingUpgrade


function timeleftTranslation(timeleft, forPreyTimeleft)
    if not timeleft or timeleft == 0 then
        if forPreyTimeleft then
            return tr('infinite bonus')
        end
        return tr('Free')
    end
    
    if timeleft > 999999 then
        return tr('Free')
    end
    
    local hours = math.floor(timeleft / 3600)
    local mins = math.floor((timeleft % 3600) / 60)
    
    if hours > 0 then
        if hours > 9999 then
            return string.format('9999:59')
        end
        return string.format('%02d:%02d', hours, mins)
    else
        local secs = timeleft % 60
        return string.format('%02d:%02d', mins, secs)
    end
end

function Prey.init()
    preyWindow = g_ui.displayUI('prey')
    preyWindow:hide()
    
    preyTracker = g_ui.createWidget('PreyTracker', modules.game_interface.getRightPanel())
    preyTracker:setContentMinimumHeight(47)
    preyTracker:hide()
    Prey.reset()

    connect(g_game, {
        onUpdateBestiaryMonsterData = onBestiaryMonsterData
    })
    
    if g_game.isOnline() then
        check()
        if g_game.taskHuntingRequest then
            g_game.taskHuntingRequest()
        end
    end
    setUnsupportedSettings()
    
    if g_game then
        connect(g_game, {
            onGameStart = check,
            onGameEnd = hide,
            onResourcesBalanceChange = Prey.onResourcesBalanceChange,
            onPreyFreeRerolls = onPreyFreeRerolls,
            onPreyTimeLeft = onPreyTimeLeft,
            onPreyRerollPrice = onPreyRerollPrice,
            onPreyLocked = onPreyLocked,
            onPreyInactive = onPreyInactive,
            onPreyActive = onPreyActive,
            onPreySelection = onPreySelection,
            onPreySelectionChangeMonster = onPreySelectionChangeMonster,
            onPreyListSelection = onPreyListSelection,
            onTaskHuntingData = onTaskHuntingData,
            onTaskHuntingBasicData = onTaskHuntingBasicData,
    onTaskHuntingSelection = onTaskHuntingSelection,
            onTaskHuntingFreeRerolls = onTaskHuntingFreeRerolls,
            onTaskHuntingTimeLeft = onTaskHuntingTimeLeft,
            onTaskHuntingRerollPrice = onTaskHuntingRerollPrice,
            onTaskHuntingConfirm = onTaskHuntingConfirm,
            onTaskHuntingSelect = onTaskHuntingSelect,
            onTaskHuntingListAll = onTaskHuntingListAll,
            onTaskHuntingCancel = onTaskHuntingCancel,
            onTaskHuntingSelectionChangeMonster = onTaskHuntingSelectionChangeMonster,
            onTaskHuntingNextFreeRoll = onTaskHuntingNextFreeRoll,
            onTaskHuntingReroll = onTaskHuntingReroll,
            onTaskHuntingRerollResponse = onTaskHuntingRerollResponse,
            onTaskHuntingActive = onTaskHuntingActive,
            onTaskHuntingInactive = onTaskHuntingInactive
        })
    end
    
    setupTrackerClickHandlers()
    updateTaskHuntingPoints()
end

local descriptionTable = {
    ['shopPermButton'] = 'Go to the Store to purchase the Permanent Prey Slot. Once you have completed the purchase, you can activate a prey here, no matter if your character is on a free or a Premium account.',
    ['shopTempButton'] = 'You can activate this prey whenever your account has Premium Status.',
    ['preyWindow'] = '',
    ['noBonusIcon'] = 'This prey is not available for your character yet.\nCheck the large blue button(s) to learn how to unlock this prey slot',
    ['selectPrey'] = 'Click here to get a bonus with a higher value. The bonus for your prey will be selected randomly from one of the following: damage boost, damage reduction, bonus XP, improved loot. Your prey will be active for 2 hours hunting time again. Your prey creature will stay the same.',
    ['pickSpecificPrey'] = 'Select a specific creature from your entire prey list for 5 Prey Wildcards',
    ['rerollButton'] = 'If you like to select another prey crature, click here to get a new list with 9 creatures to choose from.\nThe newly selected prey will be active for 2 hours hunting time again.',
    ['preyCandidate'] = 'Select a new prey creature for the next 2 hours hunting time.',
    ['choosePreyButton'] = 'Click on this button to confirm selected monsters as your prey creature for the next 2 hours hunting time.'
}

function onHover(widget)
    if not preyWindow then
        return
    end
    
    if type(widget) == 'string' then
        return preyWindow.description:setText(descriptionTable[widget])
    elseif type(widget) == 'number' then
        local slot = 'slot' .. (widget + 1)
        local tracker = preyTracker.contentsPanel[slot]
        local desc = tracker.time:getTooltip()
        desc = desc:sub(1, desc:len() - 46)
        return preyWindow.description:setText(desc)
    end
    if widget:isVisible() then
        local id = widget:getId()
        local desc = descriptionTable[id]
        if desc then
            preyWindow.description:setText(desc)
        end
    end
end

function terminate()
    disconnect(g_game, {
        onGameStart = check,
        onGameEnd = hide,
        onResourcesBalanceChange = Prey.onResourcesBalanceChange,
        onPreyFreeRerolls = onPreyFreeRerolls,
        onPreyTimeLeft = onPreyTimeLeft,
        onPreyRerollPrice = onPreyRerollPrice,
        onPreyLocked = onPreyLocked,
        onPreyInactive = onPreyInactive,
        onPreyActive = onPreyActive,
        onPreySelection = onPreySelection,
        onPreySelectionChangeMonster = onPreySelectionChangeMonster,
        onPreyListSelection = onPreyListSelection,
        onTaskHuntingData = onTaskHuntingData,
        onTaskHuntingBasicData = onTaskHuntingBasicData,
        onTaskHuntingSelection = onTaskHuntingSelection,
        onTaskHuntingFreeRerolls = onTaskHuntingFreeRerolls,
        onTaskHuntingTimeLeft = onTaskHuntingTimeLeft,
        onTaskHuntingRerollPrice = onTaskHuntingRerollPrice,
        onTaskHuntingConfirm = onTaskHuntingConfirm,
        onTaskHuntingSelect = onTaskHuntingSelect,
        onTaskHuntingListAll = onTaskHuntingListAll,
        onTaskHuntingCancel = onTaskHuntingCancel,
        onTaskHuntingSelectionChangeMonster = onTaskHuntingSelectionChangeMonster,
        onTaskHuntingNextFreeRoll = onTaskHuntingNextFreeRoll,
                    onTaskHuntingReroll = onTaskHuntingReroll,
            onTaskHuntingRerollResponse = onTaskHuntingRerollResponse,
            onTaskHuntingActive = onTaskHuntingActive,
            onTaskHuntingInactive = onTaskHuntingInactive
        })

    if preyButton then
        preyButton:destroy()
    end
    if preyTrackerButton then
        preyTrackerButton:destroy()
    end
    if preyWindow then
    preyWindow:destroy()
    end
    if preyTracker then
    preyTracker:destroy()
    end
    if msgWindow then
        msgWindow:hide()
        msgWindow = nil
    end
end

local n = 0
function setUnsupportedSettings()
    if not preyWindow then
        return
    end
    
    local t = {'slot1', 'slot2', 'slot3', 'slot4', 'slot5', 'slot6'}
    
    for i, slot in pairs(t) do
        local panel = preyWindow:getChildById(slot)
        if panel then
            for j, state in pairs({panel.active, panel.inactive}) do
                if state then
                    if state.select then
                        if state.select.price and state.select.price.text then
                            state.select.price.text:setText('5')
                        end
                        if state.select.pickSpecificPrey then
                            state.select.pickSpecificPrey:setImageSource('/images/game/prey/prey_select')
                            state.select.pickSpecificPrey:enable()
                            state.select.pickSpecificPrey.onClick = function()
                                local player = g_game.getLocalPlayer()
                                if player then
                                    local wildcards = player:getResourceBalance(ResourceTypes.PREY_WILDCARDS)
                                    if wildcards < 5 then
                                        return showMessage(tr('Error'), tr('You need at least 5 Prey Wildcards to select a specific creature.') .. '\n' .. tr('You have: ') .. wildcards .. ' ' .. tr('wildcards.'))
                                    end
                                end
                                executePreyAction(i - 1, PREY_ACTION_REQUEST_ALL_MONSTERS, 0)
                            end
                        end
                    end
                end
            end
        end
    end
end

function check()
    if g_game.getFeature(GamePrey) then
        if not preyButton then
            preyButton = modules.game_mainpanel.addToggleButton('preyButton', tr('Prey Dialog'),
                                                                         '/images/options/button_preydialog', toggle)
        end
        if not preyTrackerButton then
            preyTrackerButton = modules.game_mainpanel.addToggleButton('preyTrackerButton', tr('Prey Tracker'),
                                                                                '/images/options/button_prey', toggleTracker)
        end
        
        setupTrackerClickHandlers()
    elseif preyButton then
        preyButton:destroy()
        preyButton = nil
    end
end

function setupTrackerClickHandlers()
    if not preyTracker then
        return
    end
    
    for i = 1, 6 do
        local slot = 'slot' .. i
        local tracker = preyTracker.contentsPanel[slot]
        if tracker then
            for _, element in pairs({tracker.creatureName, tracker.creature, tracker.preyType, tracker.time, tracker.noCreature}) do
                if element then
                    element.onClick = function()
                        show()
                    end
                    if element == tracker.noCreature then
                        if i <= 3 then
                        element:setTooltip('Inactive Prey. \n\nClick in this window to open the prey dialog.')
                        else
                            element:setTooltip('Inactive Task Hunting. \n\nClick in this window to open the prey dialog.')
                        end
                    else
                        element:setTooltip('Click in this window to open the prey dialog.')
                    end
                end
            end
        end
    end
end

function toggleTracker()
    if preyTracker:isVisible() then
        preyTracker:hide()
    else
        if not preyTracker:getParent() then
            local panel = modules.game_interface.findContentPanelAvailable(preyTracker, preyTracker:getMinimumHeight())
            if not panel then
                return
            end

            panel:addChild(preyTracker)
        end
        preyTracker:show()
        
        setupTrackerClickHandlers()
    end
end

function hide()
    if preyWindow then
        preyWindow:hide()
    end
    if preyTracker then
        preyTracker:hide()
    end
    if msgWindow then
        msgWindow:hide()
    end
end

function show()
    if not g_game.getFeature(GamePrey) then
        return hide()
    end
    
    if not preyWindow then
        preyWindow = g_ui.displayUI('prey')
    end
    
    preyWindow:show()
    preyWindow:raise()
    preyWindow:focus()
    
    g_game.preyRequest()
    
    g_game.taskHuntingRequest()
    
    updateTaskHuntingPoints()
    
    setupTrackerClickHandlers()
    
    if preyWindow then
        switchToTab1()
    end
end

function toggle()
    if preyWindow and preyWindow:isVisible() then
        return hide()
    end
    show()
end

function onPreyFreeRerolls(slot, timeleft)
    local prey, tab = getPreySlot(slot)
    if not prey then
        return
    end
    
    if not timeleft or timeleft < 0 or timeleft > 999999 then
        timeleft = 0
    end
    
    timeUntilFreeRerollSlots[slot + 1] = timeleft or 0
    
    local maxTimeSeconds = 5 * 60
    local percent = 0
    if timeleft and timeleft > 0 then
        percent = math.min(100, (timeleft / maxTimeSeconds) * 100)
    end
    
    local desc = timeleftTranslation(timeleft)
    
    for i, panel in pairs({prey.active, prey.inactive}) do
        if panel and panel.reroll and panel.reroll.button and panel.reroll.price and panel.reroll.price.text then
            local progressBar = panel.reroll.button.time
            local price = panel.reroll.price.text
            progressBar:setPercent(percent)
            progressBar:setText(desc)
            if timeleft == 0 then
                price:setText('Free')
                progressBar:setPercent(0)
            else
                price:setText(comma_value(rerollPrice))
            end
        end
    end
    syncFreeRerollPrices()
end

function onPreyTimeLeft(slot, timeLeft)
    preyDescription[slot] = preyDescription[slot] or {
        one = '',
        two = ''
    }
    local text = preyDescription[slot].one .. timeleftTranslation(timeLeft, true) .. preyDescription[slot].two
    
    local maxTimeSeconds = 2 * 60 * 60
    local percent = math.min((timeLeft / maxTimeSeconds) * 100, 100)
    local tracker, tabIndex = getPreyTracker(slot)
    if tracker then
        tracker.time:setPercent(percent)
        tracker.time:setTooltip(text)
        for i, element in pairs({tracker.creatureName, tracker.creature, tracker.preyType, tracker.time}) do
            element:setTooltip(text)
            element.onClick = function()
                show()
            end
        end
    end
    
    local prey, tab = getPreySlot(slot)
    if not prey then
        return
    end
    local progressbar = prey.active.creatureAndBonus.timeLeft
    local desc = timeleftTranslation(timeLeft, true)
    progressbar:setPercent(percent)
    progressbar:setText(desc)
end

function onPreyRerollPrice(price)
    rerollPrice = price
    syncFreeRerollPrices()
end

function onTaskHuntingRerollPrice(price, wildcard, directly, taskHuntingRerollPrice, taskHuntingBonusRerollPrice, taskHuntingSelectionListPrice, taskHuntingBonusRerollPrice2)
    rerollPrice = price
end

function syncFreeRerollPrices()
    if not preyWindow then
        return
    end
    local prey1Panel = preyWindow:getChildById('prey1Panel')
    if prey1Panel then
        for i = 1, 3 do
            local slot = prey1Panel:getChildById('slot' .. i)
            if slot then
                for j, state in pairs({slot.active, slot.inactive}) do
                    if state and state.reroll and state.reroll.button and state.reroll.price and state.reroll.price.text then
                        local price = state.reroll.price.text
                        local progressBar = state.reroll.button.time
                        if progressBar:getText() ~= 'Free' then
                            price:setText(comma_value(rerollPrice))
                        else
                            price:setText('Free')
                            progressBar:setPercent(0)
                        end
                    end
                end
            end
        end
    end

    local prey2Panel = preyWindow:getChildById('prey2Panel')
    if prey2Panel then
        for i = 1, 3 do
            local slot = prey2Panel:getChildById('slot' .. i)
            if slot then
                for j, state in pairs({slot.active, slot.inactive}) do
                    if state and state.reroll and state.reroll.button and state.reroll.price and state.reroll.price.text then
                        local price = state.reroll.price.text
                        local progressBar = state.reroll.button.time
                        if progressBar:getText() ~= 'Free' then
                            price:setText(comma_value(rerollPrice))
                        else
                            price:setText('Free')
                            progressBar:setPercent(0)
                        end
                    end
                end
            end
        end
    end
end

function setTimeUntilFreeReroll(slot, timeUntilFreeReroll, system)
    local prey, tab
    if system == "taskhunting" then
        prey, tab = getTaskHuntingSlot(slot)
    else
        prey, tab = getPreySlot(slot)
    end
    
    if not prey then
        return
    end
    
    if not timeUntilFreeReroll or timeUntilFreeReroll < 0 or timeUntilFreeReroll > 999999 then
        timeUntilFreeReroll = 0
    end
    
    timeUntilFreeRerollSlots[slot + 1] = timeUntilFreeReroll or 0
    
    local maxTimeSeconds = 5 * 60
    local percent = 0
    if timeUntilFreeReroll and timeUntilFreeReroll > 0 then
        percent = math.min(100, (timeUntilFreeReroll / maxTimeSeconds) * 100)
    end
    
    local desc = timeleftTranslation(timeUntilFreeReroll)
    
    for i, panel in pairs({prey.active, prey.inactive}) do
        if panel and panel.reroll and panel.reroll.button and panel.reroll.price and panel.reroll.price.text then
            local reroll = panel.reroll.button.time
            if reroll and reroll.setPercent then
            reroll:setPercent(percent)
            end
            if reroll and reroll.setText then
            reroll:setText(desc)
            end
            local price = panel.reroll.price.text
            if timeUntilFreeReroll and timeUntilFreeReroll > 0 then
                price:setText(comma_value(rerollPrice))
            else
                price:setText('Free')
                if reroll and reroll.setPercent then
                reroll:setPercent(0)
                end
            end
        end
    end
    syncFreeRerollPrices()
end

function onPreyLocked(slot, unlockState, timeUntilFreeReroll, wildcards)
    local tracker, tabIndex = getPreyTracker(slot)
    if tracker then
        tracker:hide()
        preyTracker:setContentMaximumHeight(preyTracker:getHeight() - 20)
    end
    
    local prey, tab = getPreySlot(slot)
    if not prey then
        return
    end
    prey.title:setText('Locked')
    prey.inactive:hide()
    prey.active:hide()
    prey.locked:show()
end

function onPreyInactive(slot, timeUntilFreeReroll, wildcards)
    local tracker, tabIndex = getPreyTracker(slot)
    if tracker then
        tracker.creature:hide()
        tracker.noCreature:show()
        tracker.creatureName:setText('Inactive')
        tracker.time:setPercent(0)
        tracker.preyType:setImageSource('/images/game/prey/prey_no_bonus')
        for i, element in pairs({tracker.creatureName, tracker.creature, tracker.preyType, tracker.time}) do
            element:setTooltip('Inactive Prey. \n\nClick in this window to open the prey dialog.')
            element.onClick = function()
                show()
            end
        end
    end
    
    if not timeUntilFreeReroll or timeUntilFreeReroll < 0 or timeUntilFreeReroll > 999999 then
        timeUntilFreeReroll = 0
    end
    setTimeUntilFreeReroll(slot, timeUntilFreeReroll)
    local prey, tab = getPreySlot(slot)
    if not prey then
        return
    end
    
    local searchEdit = prey.inactive:getChildById('searchEdit')
    if searchEdit then
        searchEdit:hide()
    end
    
    prey.active:hide()
    prey.locked:hide()
    prey.inactive:show()
    if prey.inactive and prey.inactive.reroll and prey.inactive.reroll.button and prey.inactive.reroll.button.rerollButton then
        local rerollButton = prey.inactive.reroll.button.rerollButton
        rerollButton:setImageSource('/images/game/prey/prey_reroll_blocked')
        rerollButton:disable()
    end
end



function setBonusGradeStars(slot, bonusType, bonusValue)
    local prey, tabIndex = getPreySlot(slot)
    
    if not prey or not prey.active or not prey.active.creatureAndBonus or not prey.active.creatureAndBonus.bonus then
        return
    end
    
    local gradePanel = prey.active.creatureAndBonus.bonus.grade

    gradePanel:destroyChildren()
    
    local goldStars = 0
    if bonusType == PREY_BONUS_DAMAGE_BOOST or bonusType == PREY_BONUS_DAMAGE_REDUCTION then
        goldStars = math.max(0, math.min(10, math.ceil((bonusValue - 5) / 2)))
    elseif bonusType == PREY_BONUS_XP_BONUS or bonusType == PREY_BONUS_IMPROVED_LOOT then
        goldStars = math.max(0, math.min(10, math.ceil((bonusValue - 10) / 3)))
    end
    
    for i = 1, 10 do
        if i <= goldStars then
            local widget = g_ui.createWidget('Star', gradePanel)
            widget.onHoverChange = function(widget, hovered)
                onHover(slot)
            end
        else
            local widget = g_ui.createWidget('NoStar', gradePanel)
            widget.onHoverChange = function(widget, hovered)
                onHover(slot)
            end
        end
    end
end

function getBigIconPath(bonusType)
    local path = '/images/game/prey/'
    if bonusType == PREY_BONUS_DAMAGE_BOOST then
        return path .. 'prey_bigdamage'
    elseif bonusType == PREY_BONUS_DAMAGE_REDUCTION then
        return path .. 'prey_bigdefense'
    elseif bonusType == PREY_BONUS_XP_BONUS then
        return path .. 'prey_bigxp'
    elseif bonusType == PREY_BONUS_IMPROVED_LOOT then
        return path .. 'prey_bigloot'
    end
end

function getSmallIconPath(bonusType)
    local path = '/images/game/prey/'
    if bonusType == PREY_BONUS_DAMAGE_BOOST then
        return path .. 'prey_damage'
    elseif bonusType == PREY_BONUS_DAMAGE_REDUCTION then
        return path .. 'prey_defense'
    elseif bonusType == PREY_BONUS_XP_BONUS then
        return path .. 'prey_xp'
    elseif bonusType == PREY_BONUS_IMPROVED_LOOT then
        return path .. 'prey_loot'
    end
end

function getBonusDescription(bonusType)
    if bonusType == PREY_BONUS_DAMAGE_BOOST then
        return 'Damage Boost'
    elseif bonusType == PREY_BONUS_DAMAGE_REDUCTION then
        return 'Damage Reduction'
    elseif bonusType == PREY_BONUS_XP_BONUS then
        return 'XP Bonus'
    elseif bonusType == PREY_BONUS_IMPROVED_LOOT then
        return 'Improved Loot'
    end
end

function getTooltipBonusDescription(bonusType, bonusValue)
    if bonusType == PREY_BONUS_DAMAGE_BOOST then
        return 'You deal +' .. bonusValue .. '% extra damage against your prey creature.'
    elseif bonusType == PREY_BONUS_DAMAGE_REDUCTION then
        return 'You take ' .. bonusValue .. '% less damage from your prey creature.'
    elseif bonusType == PREY_BONUS_XP_BONUS then
        return 'Killing your prey creature rewards +' .. bonusValue .. '% extra XP.'
    elseif bonusType == PREY_BONUS_IMPROVED_LOOT then
        return 'Your creature has a +' .. bonusValue .. '% chance to drop additional loot.'
    end
end

function capitalFormatStr(str)
    local formatted = ''
    str = string.split(str, ' ')
    for i, word in ipairs(str) do
        formatted = formatted .. ' ' .. (string.gsub(word, '^%l', string.upper))
    end
    return formatted:trim()
end



function onPreyActive(slot, currentHolderName, currentHolderOutfit, bonusType, bonusValue, bonusGrade, timeLeft,
                      timeUntilFreeReroll, wildcards)
    
    
    local tracker, tabIndex = getPreyTracker(slot, false)
    currentHolderName = capitalFormatStr(currentHolderName)
    local percent = (timeLeft / (2 * 60 * 60)) * 100
    if tracker then
        tracker.creature:show()
        tracker.noCreature:hide()
        tracker.creatureName:setText(currentHolderName)
        tracker.creature:setOutfit(currentHolderOutfit)
        tracker.preyType:setImageSource(getSmallIconPath(bonusType))
        tracker.time:setPercent(percent)
        preyDescription[slot] = preyDescription[slot] or {}
        preyDescription[slot].one = 'Creature: ' .. currentHolderName .. '\nDuration: '
        local calculatedGrade = 0
        if bonusType == PREY_BONUS_DAMAGE_BOOST or bonusType == PREY_BONUS_DAMAGE_REDUCTION then
            calculatedGrade = math.max(0, math.min(10, math.ceil((bonusValue - 5) / 2)))
        elseif bonusType == PREY_BONUS_XP_BONUS or bonusType == PREY_BONUS_IMPROVED_LOOT then
            calculatedGrade = math.max(0, math.min(10, math.ceil((bonusValue - 10) / 3)))
        end
        
        preyDescription[slot].two =
            '\nValue: ' .. calculatedGrade .. '/10' .. '\nType: ' .. getBonusDescription(bonusType) .. '\n' ..
                getTooltipBonusDescription(bonusType, bonusValue) .. '\n\nClick in this window to open the prey dialog.'
        for i, element in pairs({tracker.creatureName, tracker.creature, tracker.preyType, tracker.time}) do
            element:setTooltip(preyDescription[slot].one .. timeleftTranslation(timeLeft, true) ..
                                   preyDescription[slot].two)
            element.onClick = function()
                show()
            end
        end
    end
    
    local prey, tabIndex = getPreySlot(slot)
    
    if not prey then
        return
    end
    
    if tabIndex == 1 then
        local slotType = getSlotTypeBySlotNumber(slot)
        
        if slotType == "taskhunting" then
        end
    end
    
    prey.inactive:hide()
    prey.locked:hide()
    prey.active:show()
    prey.title:setText(currentHolderName)
    local creatureAndBonus = prey.active.creatureAndBonus
    creatureAndBonus.creature:setOutfit(currentHolderOutfit)
    
    if not timeUntilFreeReroll or timeUntilFreeReroll < 0 or timeUntilFreeReroll > 999999 then
        timeUntilFreeReroll = 0
    end
    setTimeUntilFreeReroll(slot, timeUntilFreeReroll)
    creatureAndBonus.bonus.icon:setImageSource(getBigIconPath(bonusType))
    creatureAndBonus.bonus.icon.onHoverChange = function(widget, hovered)
        onHover(slot)
    end
    setBonusGradeStars(slot, bonusType, bonusValue)
    creatureAndBonus.timeLeft:setPercent(percent)
    local formattedTime = timeleftTranslation(timeLeft)
    creatureAndBonus.timeLeft:setText(formattedTime)
    prey.active.choose.selectPrey.onClick = function()
        local player = g_game.getLocalPlayer()
        if player then
            local wildcards = player:getResourceBalance(ResourceTypes.PREY_WILDCARDS)
            if wildcards < 1 then
                return showMessage(tr('Error'), tr('You need at least 1 Prey Wildcard to use bonus reroll.') .. '\n' .. tr('You have: ') .. wildcards .. ' ' .. tr('wildcards.'))
            end
        end
        
        executePreyAction(slot, PREY_ACTION_BONUSREROLL, 0)
    end
    
    if prey.active.choose and prey.active.choose.price and prey.active.choose.price.text then
        prey.active.choose.price.text:setText('1')
    end
    
    if prey.active.autoRerollPrice and prey.active.autoRerollPrice.text then
        prey.active.autoRerollPrice.text:setText('1')
    end
    
    if prey.active.lockPreyPrice and prey.active.lockPreyPrice.text then
        prey.active.lockPreyPrice.text:setText('5')
    end

    if prey.active.select and prey.active.select.price and prey.active.select.price.text then
        prey.active.select.price.text:setText('5')
    end
    
    local player = g_game.getLocalPlayer()
    local keyAutoReroll = nil
    if player then
        keyAutoReroll = 'prey_auto_reroll_' .. player:getId() .. '_' .. slot
    end
    if prey.active.autoReroll and prey.active.autoReroll.autoRerollCheck then
        prey.active.autoReroll.autoRerollCheck:enable()
        prey.active.autoReroll.autoRerollCheck.checked = g_settings.getBoolean(keyAutoReroll, false)
        if prey.active.autoReroll.autoRerollCheck.checked then
            prey.active.autoReroll.autoRerollCheck:setImageSource('/images/ui/checkbox-yes')
        end
        prey.active.autoReroll.autoRerollCheck.onClick = function()
            if prey.active.autoReroll.autoRerollCheck.checked then
                prey.active.autoReroll.autoRerollCheck.checked = false
                prey.active.autoReroll.autoRerollCheck:setImageSource('/images/ui/checkbox')
                g_settings.set(keyAutoReroll, prey.active.autoReroll.autoRerollCheck.checked)
                return
            end
            
            if player then
                local wildcards = player:getResourceBalance(ResourceTypes.PREY_WILDCARDS)
                if wildcards < 1 then
                    return showMessage(tr('Error'), tr('You need at least 1 Prey Wildcard to use bonus reroll.') .. '\n' .. tr('You have: ') .. wildcards .. ' ' .. tr('wildcards.'))
                end
            end
            
            if prey.active.lockPrey and prey.active.lockPrey.lockPreyCheck then
                prey.active.lockPrey.lockPreyCheck.checked = false
                prey.active.lockPrey.lockPreyCheck:setImageSource('/images/ui/checkbox')
                local keyLockPrey = 'prey_lock_' .. player:getId() .. '_' .. slot
                g_settings.set(keyLockPrey, false)
            end
            
            prey.active.autoReroll.autoRerollCheck.checked = true
            prey.active.autoReroll.autoRerollCheck:setImageSource('/images/ui/checkbox-yes')
            g_settings.set(keyAutoReroll, prey.active.autoReroll.autoRerollCheck.checked)
        end
    end
    
    local keyLockPrey = nil
    if player then
        keyLockPrey = 'prey_lock_' .. player:getId() .. '_' .. slot
    end
    if prey.active.lockPrey and prey.active.lockPrey.lockPreyCheck then
        prey.active.lockPrey.lockPreyCheck:enable()
        prey.active.lockPrey.lockPreyCheck.checked = g_settings.getBoolean(keyLockPrey, false)
        if prey.active.lockPrey.lockPreyCheck.checked then
            prey.active.lockPrey.lockPreyCheck:setImageSource('/images/ui/checkbox-yes')
        end
        prey.active.lockPrey.lockPreyCheck.onClick = function()
            if prey.active.lockPrey.lockPreyCheck.checked then
                prey.active.lockPrey.lockPreyCheck.checked = false
                prey.active.lockPrey.lockPreyCheck:setImageSource('/images/ui/checkbox')
                g_settings.set(keyLockPrey, prey.active.lockPrey.lockPreyCheck.checked)
                return
            end
            
            local player = g_game.getLocalPlayer()
            if player then
                local wildcards = player:getResourceBalance(ResourceTypes.PREY_WILDCARDS)
                if wildcards < 5 then
                    return showMessage(tr('Error'), tr('You need at least 5 Prey Wildcards to lock prey.') .. '\n' .. tr('You have: ') .. wildcards .. ' ' .. tr('wildcards.'))
                end
            end
            
            if prey.active.autoReroll and prey.active.autoReroll.autoRerollCheck then
                prey.active.autoReroll.autoRerollCheck.checked = false
                prey.active.autoReroll.autoRerollCheck:setImageSource('/images/ui/checkbox')
                local keyAutoReroll = 'prey_auto_reroll_' .. player:getId() .. '_' .. slot
                g_settings.set(keyAutoReroll, false)
            end
            
            prey.active.lockPrey.lockPreyCheck.checked = true
            prey.active.lockPrey.lockPreyCheck:setImageSource('/images/ui/checkbox-yes')
            g_settings.set(keyLockPrey, prey.active.lockPrey.lockPreyCheck.checked)
            executePreyAction(slot, PREY_ACTION_LOCK_PREY, 0)
        end
    end
end

function onPreySelection(slot, names, outfits, timeUntilFreeReroll, wildcards)
    local tracker, tabIndex = getPreyTracker(slot, false)
    if tracker then
        tracker.creature:hide()
        tracker.noCreature:show()
        tracker.creatureName:setText('Inactive')
        tracker.time:setPercent(0)
        tracker.preyType:setImageSource('/images/game/prey/prey_no_bonus')
        for i, element in pairs({tracker.creatureName, tracker.creature, tracker.preyType, tracker.time}) do
            element:setTooltip('Inactive Prey. \n\nClick in this window to open the prey dialog.')
            element.onClick = function()
                show()
            end
        end
    end
    local prey, tab = getPreySlot(slot)
    
    if not timeUntilFreeReroll or timeUntilFreeReroll < 0 or timeUntilFreeReroll > 999999 then
        timeUntilFreeReroll = 0
    end
    setTimeUntilFreeReroll(slot, timeUntilFreeReroll)
    if not prey then
        return
    end
    prey.active:hide()
    prey.locked:hide()
    prey.inactive:show()
    prey.title:setText(tr('Select monster'))
    
    local searchEdit = prey.inactive:getChildById('searchEdit')
    if searchEdit then
        searchEdit:hide()
    end
    
    if prey.inactive.select then
        prey.inactive.select.onClick = function()
            executePreyAction(slot, PREY_ACTION_REQUEST_ALL_MONSTERS, 0)
        end
    end
    
    if prey.inactive.choose then
        prey.inactive.choose:show()
        if prey.inactive.choose.choosePreyButton then
            prey.inactive.choose.choosePreyButton.onClick = function()
                executePreyAction(slot, PREY_ACTION_REQUEST_ALL_MONSTERS, 0)
            end
        end
    end

    if prey.inactive.select and prey.inactive.select.price and prey.inactive.select.price.text then
        prey.inactive.select.price.text:setText('5')
    else
        if prey.inactive.select then
            if prey.inactive.select.price then
                if prey.inactive.select.price.text then
                else
                end
            else
            end
        else
        end
    end
    
end

function onPreySelectionChangeMonster(slot, names, outfits, bonusType, bonusValue, bonusGrade, timeUntilFreeReroll, wildcards)
    if not preyWindow then
        return
    end
    local slotType = getSlotTypeBySlotNumber(slot)
    if slotType == "taskhunting" then
        return onTaskHuntingSelectionChangeMonster(slot, names, outfits, bonusType, bonusValue, bonusGrade, timeUntilFreeReroll, wildcards)
    end
    
    local prey, tab = getPreySlot(slot)
    
    if not timeUntilFreeReroll or timeUntilFreeReroll < 0 or timeUntilFreeReroll > 999999 then
        timeUntilFreeReroll = 0
    end
    setTimeUntilFreeReroll(slot, timeUntilFreeReroll)
    if not prey then return end

    prey.active:hide()
    prey.locked:hide()
    prey.inactive:show()
    prey.title:setText(tr('Select monster'))

    local monsterList = prey.inactive:getChildById('monsterList')
    local rerollList = prey.inactive:getChildById('rerollList')
    local searchEdit = prey.inactive:getChildById('searchEdit')
    
    if monsterList then 
        monsterList:hide() 
        monsterList:destroyChildren()
        
        local preyScrollBar = prey.inactive:getChildById('preyScrollBar')
        if preyScrollBar then
            preyScrollBar:hide()
        end
    end
    if rerollList then 
        rerollList:show() 
        rerollList:destroyChildren()
    end
    if searchEdit then
        searchEdit:hide()
    end
    
    local list = prey.inactive:getChildById('list')
    if list then list:hide() end
    
    if prey.inactive.reroll then 
        prey.inactive.reroll:show()
    end
    if prey.inactive.select then 
        prey.inactive.select:show()
        prey.inactive.select.onClick = function()
            executePreyAction(slot, PREY_ACTION_REQUEST_ALL_MONSTERS, 0)
        end
    end
    if prey.inactive.choose then 
        prey.inactive.choose:show()
        if prey.inactive.choose.choosePreyButton then
            prey.inactive.choose.choosePreyButton.onClick = function()
                local selectedIndex = nil
                for i, child in pairs(rerollList:getChildren()) do
                    if child:isChecked() then
                        selectedIndex = child.monsterIndex
                        break
                    end
                end
                if selectedIndex then
                    return executePreyAction(slot, PREY_ACTION_MONSTERSELECTION, selectedIndex)
                else
                    return showMessage(tr('Error'), tr('Select monster to proceed.'))
                end
            end
        end
    end

    if prey.inactive.select and prey.inactive.select.price and prey.inactive.select.price.text then
        prey.inactive.select.price.text:setText('5')
    else
    end
    
    if not rerollList then
        return
    end
    
    rerollList:destroyChildren()

    for i, name in ipairs(names) do
        local box = g_ui.createWidget('TaskHuntingCreatureBox', rerollList)

        local raceId = nil
        local creatureName = nil
        
        if type(name) == "number" then
            raceId = name
            local raceData = g_things.getRaceData(raceId)
            creatureName = raceData and raceData.name or ("Monster " .. raceId)
            creatureName = capitalFormatStr(creatureName)
        else
            creatureName = capitalFormatStr(name)
            raceId = 0
        end
        
        box:setTooltip(creatureName)
        box.raceId = raceId
        
        if outfits and outfits[i] then
            box.creature:setOutfit(outfits[i])
        end
        
        box.monsterIndex = i - 1
    end
end



function onPreyListSelection(slot, races, nextFreeReroll, wildcards)
    
    if not preyWindow then
        return
    end
    
    local prey, tab = getPreySlot(slot)
    
    if not prey then 
        return 
    end



    prey.active:hide()
    prey.locked:hide()
    prey.inactive:show()
    prey.title:setText(tr('Select creature from list'))

    local monsterList = prey.inactive:getChildById('monsterList')
    local rerollList = prey.inactive:getChildById('rerollList')
    local searchEdit = prey.inactive:getChildById('searchEdit')
    
    if rerollList then 
        rerollList:hide() 
        rerollList:destroyChildren()
    end
    if monsterList then 
        monsterList:show() 
        monsterList:destroyChildren()
        
        local preyScrollBar = prey.inactive:getChildById('preyScrollBar')
        if preyScrollBar then
            preyScrollBar:show()
        end
    end
    if searchEdit then
        searchEdit:show()
        searchEdit:setText('')
    end
    
    local list = prey.inactive:getChildById('list')
    if list then list:hide() end
    
    if prey.inactive.select then 
        prey.inactive.select:hide()
    end
    if prey.inactive.reroll then 
        prey.inactive.reroll:hide()
    end
    if prey.inactive.choose then 
        prey.inactive.choose:show()
        if prey.inactive.choose.choosePreyButton then
            prey.inactive.choose.choosePreyButton.onClick = function()
                if _G['selectedPreyRace_' .. slot] then
                    return executePreyAction(slot, PREY_ACTION_CHANGE_FROM_ALL, _G['selectedPreyRace_' .. slot])
                end
                return showMessage(tr('Error'), tr('Select creature to proceed.'))
            end
        end
    end
    
    if not monsterList then
        return
    end
    
    monsterList:destroyChildren()

    if not races or #races == 0 then
        local label = g_ui.createWidget('Label', monsterList)
        label:setText("No creatures available")
        label:setColor('#FF0000')
        label:setFont('verdana-11px-monochrome')
        return
    end



    _G['preyRaces_' .. slot] = races
    _G['preyRaceData_' .. slot] = {}
    
    for i, race in ipairs(races) do
        local raceData = g_things.getRaceData(race)
        local creatureName = raceData and raceData.name or ("Race ID: " .. race)
        creatureName = capitalFormatStr(creatureName)
        _G['preyRaceData_' .. slot][i] = {
            race = race,
            name = creatureName,
            originalIndex = i,
            label = nil
        }
    end

    for i, raceData in ipairs(_G['preyRaceData_' .. slot]) do
        local label = g_ui.createWidget('Label', monsterList)
        label:setText(string.format("%3d. %s", raceData.originalIndex, raceData.name))
        label:setFont('verdana-11px-monochrome')
        label:setColor('#C0C0C0')
        label:setFocusable(true)
        
        raceData.label = label

        connect(label, {onMousePress = function(widget, mousePos, mouseButton)
            if mouseButton == MouseLeftButton then
                for _, data in pairs(_G['preyRaceData_' .. slot]) do
                    if data.label then
                        data.label:setBackgroundColor('#00000000')
                    end
                end
                widget:setBackgroundColor('#00FF0044')
                _G['selectedPreyRace_' .. slot] = raceData.race
                _G['selectedPreyIndex_' .. slot] = raceData.originalIndex - 1
                
                return true
            end
            return false
        end})
    end

    if searchEdit then
        searchEdit.onTextChange = function(widget, text)
            filterCreatures(slot, text)
        end
    end

    if prey.inactive.choose then
        prey.inactive.choose.onClick = function()
            if _G['selectedPreyRace_' .. slot] then
                return executePreyAction(slot, PREY_ACTION_CHANGE_FROM_ALL, _G['selectedPreyRace_' .. slot])
            end
            return showMessage(tr('Error'), tr('Select creature to proceed.'))
        end
    end
    
    
end

function Prey.onResourcesBalanceChange(balance, oldBalance, type)
    if type == ResourceTypes.BANK_BALANCE then
        bankGold = balance
    elseif type == ResourceTypes.GOLD_EQUIPPED then
        inventoryGold = balance
    elseif type == ResourceTypes.PREY_WILDCARDS then
        bonusRerolls = balance
    end
    local player = g_game.getLocalPlayer()
    if player then
        preyWindow.wildCards:setText(tostring(player:getResourceBalance(ResourceTypes.PREY_WILDCARDS)))
        preyWindow.gold:setText(format_gold(player:getTotalMoney()))
        updateTaskHuntingPoints()
    end
end

function onItemBoxChecked(widget)
    if not preyWindow then
        return
    end
    
    if widget:isChecked() then
        widget:setChecked(false)
        return
    end

    local foundInTaskHunting = false
    local taskHuntingSlotFound = nil
    
    for slot = 0, 2 do
        local prey, tab = getPreySlot(slot)
        if prey and prey.inactive then
            local rerollList = prey.inactive:getChildById('rerollList')
            if rerollList then
                for _, child in pairs(rerollList:getChildren()) do
                    if child ~= widget then
                        child:setChecked(false)
                    end
                end
            end
        end

        local taskHuntingSlot = getTaskHuntingSlot(slot)
        if taskHuntingSlot and taskHuntingSlot.inactive then
            local rerollList = taskHuntingSlot.inactive:getChildById('rerollList')
            if rerollList then
                for _, child in pairs(rerollList:getChildren()) do
                    if child == widget then
                        foundInTaskHunting = true
                        taskHuntingSlotFound = slot
                    elseif child ~= widget then
                        child:setChecked(false)
                    end
                end
            end
        end
    end
    widget:setChecked(true)
    if foundInTaskHunting and taskHuntingSlotFound ~= nil then
        local slot = getTaskHuntingSlot(taskHuntingSlotFound)
        if slot and slot.inactive then
            local amountPanel = slot.inactive:getChildById('inactiveAmount3x3') or slot.inactive:getChildById('inactiveAmount')
            if amountPanel then
                local opt1 = amountPanel:getChildById('amountOption1_3x3') or amountPanel:getChildById('amountOption1')
                local opt2 = amountPanel:getChildById('amountOption2_3x3') or amountPanel:getChildById('amountOption2')
                local raceId = widget.raceId or 0
                if raceId > 0 then
                    requestBestiaryData(raceId)
                end

                updateAmountOptionsForRaceId(raceId)

                local unlocked = isBestiaryCompleted(widget.raceId or 0)
                opt2:setEnabled(unlocked)
                opt1:setOn(true)
                opt2:setOn(false)
                local dot1 = opt1:getChildById('dot')
                local dot2 = opt2:getChildById('dot')
                if dot1 then dot1:setImageSource('/images/ui/icon-combopoint-filled') end
                if dot2 then dot2:setImageSource('/images/ui/icon-combopoint-empty') end
                local v1 = opt1:getChildById('value')
                _G['taskHuntingAmountChoice_' .. taskHuntingSlotFound] = tonumber(v1 and v1:getText() or '0') or 0
                opt1.onClick = function(widget)
                    if not opt1:isEnabled() then 
                        return 
                    end
                    opt1:setOn(true)
                    opt2:setOn(false)
                    local dot1 = opt1:getChildById('dot')
                    local dot2 = opt2:getChildById('dot')
                    if dot1 then dot1:setImageSource('/images/ui/icon-combopoint-filled') end
                    if dot2 then dot2:setImageSource('/images/ui/icon-combopoint-empty') end
                    local v1 = opt1:getChildById('value')
                    _G['taskHuntingAmountChoice_' .. taskHuntingSlotFound] = tonumber(v1 and v1:getText() or '0') or 0
                end
                opt2.onClick = function(widget)
                    if not opt2:isEnabled() then 
                        return 
                    end
                    opt1:setOn(false)
                    opt2:setOn(true)
                    local dot1 = opt1:getChildById('dot')
                    local dot2 = opt2:getChildById('dot')
                    if dot1 then dot1:setImageSource('/images/ui/icon-combopoint-empty') end
                    if dot2 then dot2:setImageSource('/images/ui/icon-combopoint-filled') end
                    local v2 = opt2:getChildById('value')
                    _G['taskHuntingAmountChoice_' .. taskHuntingSlotFound] = tonumber(v2 and v2:getText() or '0') or 0
                end
            end
        end
    end

    if foundInTaskHunting and taskHuntingSlotFound ~= nil then
        local slot = getTaskHuntingSlot(taskHuntingSlotFound)
        if slot and slot.inactive then
            local monsterList = slot.inactive:getChildById('monsterList')
            local rerollList = slot.inactive:getChildById('rerollList')

            if monsterList and monsterList:recursiveGetChildById(widget:getId()) then
                local amountPanel = slot.inactive:getChildById('inactiveAmount')
                if amountPanel then
                    local opt1 = amountPanel:getChildById('amountOption1')
                    local opt2 = amountPanel:getChildById('amountOption2')

                    local raceId = widget.raceId or 0
                    if raceId > 0 then
                        requestBestiaryData(raceId)
                    end

                    local bestiaryData = getBestiaryData(raceId)
                    if bestiaryData then
                        updateAmountOptionsForRaceId(raceId)
                    else
                        local v1 = opt1:getChildById('value'); if v1 then v1:setText('0') end
                        local v2 = opt2:getChildById('value'); if v2 then v2:setText('0') end
                    end
                    opt1:setOn(true)
                    opt2:setOn(false)
                    local dot1 = opt1:getChildById('dot')
                    local dot2 = opt2:getChildById('dot')
                    if dot1 then dot1:setImageSource('/images/ui/icon-combopoint-filled') end
                    if dot2 then dot2:setImageSource('/images/ui/icon-combopoint-empty') end
                    local v1 = opt1:getChildById('value')
                    _G['taskHuntingAmountChoice_' .. taskHuntingSlotFound] = tonumber(v1 and v1:getText() or '0') or 0
                end
            end
        end
    end
end

function onAmountOptionClick(widget)
    local amountPanel = widget:getParent()
    if not amountPanel then
        return
    end

    local opt1 = amountPanel:getChildById('amountOption1_3x3') or amountPanel:getChildById('amountOption1')
    local opt2 = amountPanel:getChildById('amountOption2_3x3') or amountPanel:getChildById('amountOption2')
    
    if not opt1 or not opt2 then
        return
    end

    local slot = nil
    for i = 0, 2 do
        local taskHuntingSlot = getTaskHuntingSlot(i)
        if taskHuntingSlot and taskHuntingSlot.inactive then
            local inactiveAmount = taskHuntingSlot.inactive:getChildById('inactiveAmount3x3') or taskHuntingSlot.inactive:getChildById('inactiveAmount')
            if inactiveAmount == amountPanel then
                slot = i
                break
            end
        end
    end
    
    if slot == nil then
        return
    end

    if widget == opt1 then
        if not opt1:isEnabled() then 
            return 
        end
        opt1:setOn(true)
        opt2:setOn(false)
        local dot1 = opt1:getChildById('dot')
        local dot2 = opt2:getChildById('dot')
        if dot1 then dot1:setImageSource('/images/ui/icon-combopoint-filled') end
        if dot2 then dot2:setImageSource('/images/ui/icon-combopoint-empty') end
        local v1 = opt1:getChildById('value')
        _G['taskHuntingAmountChoice_' .. slot] = tonumber(v1 and v1:getText() or '0') or 0
    elseif widget == opt2 then
        if not opt2:isEnabled() then 
            return 
        end
        opt1:setOn(false)
        opt2:setOn(true)
        local dot1 = opt1:getChildById('dot')
        local dot2 = opt2:getChildById('dot')
        if dot1 then dot1:setImageSource('/images/ui/icon-combopoint-empty') end
        if dot2 then dot2:setImageSource('/images/ui/icon-combopoint-filled') end
        local v2 = opt2:getChildById('value')
        _G['taskHuntingAmountChoice_' .. slot] = tonumber(v2 and v2:getText() or '0') or 0
    end
end

function showMessage(title, message)
    if msgWindow then
        msgWindow:hide()
    end

    msgWindow = displayInfoBox(title, message)
    msgWindow:show()
    msgWindow:raise()
    msgWindow:focus()
end

function onRerollButtonClick(widget)
    local slot = nil
    local prey1Panel = preyWindow:getChildById('prey1Panel')
    if prey1Panel then
        for i = 1, 3 do
            local prey = prey1Panel:getChildById('slot' .. i)
            if prey then
                
                if prey.inactive and prey.inactive.reroll and prey.inactive.reroll.button and prey.inactive.reroll.button.rerollButton == widget then
                    slot = i - 1
                    break
                end
                if prey.inactive and prey.inactive.reroll == widget then
                    slot = i - 1
                    break
                end
                if prey.active and prey.active.reroll == widget then
                    slot = i - 1
                    break
                end
                if prey.active and prey.active.reroll and prey.active.reroll.button and prey.active.reroll.button.rerollButton == widget then
                    slot = i - 1
                    break
                end
            end
        end
    end

    if not slot then
        local prey2Panel = preyWindow:getChildById('prey2Panel')
        if prey2Panel then
            for i = 1, 3 do
                local prey = prey2Panel:getChildById('slot' .. i)
                if prey then
                    
                    if prey.inactive and prey.inactive.reroll and prey.inactive.reroll.button and prey.inactive.reroll.button.rerollButton == widget then
                        slot = i - 1
                        break
                    end
                    if prey.inactive and prey.inactive.reroll == widget then
                        slot = i - 1
                        break
                    end

                if prey.inactiveTaskHunting and prey.inactiveTaskHunting.reroll == widget then
                    slot = i - 1
                        break
                    end
                    if prey.active and prey.active.reroll == widget then
                        slot = i - 1
                        break
                    end
                    if prey.active and prey.active.reroll and prey.active.reroll.button and prey.active.reroll.button.rerollButton == widget then
                        slot = i - 1
                        break
                    end
                end
            end
        end
    end
    
    
    if slot ~= nil then
        local slotType = getSlotTypeBySlotNumber(slot)
        
        if isRerollFree(slot) then
            executePreyAction(slot, PREY_ACTION_LISTREROLL, 0)
        else
            local player = g_game.getLocalPlayer()
            if player then
                local level = player:getLevel()
                local rerollCost = math.floor(level * 200)
                
                local bankGold = player:getResourceBalance(ResourceTypes.GOLD_COINS)
                local backpackGold = player:getResourceBalance(ResourceTypes.GOLD_EQUIPPED)
                local totalGold = bankGold + backpackGold
                
                if totalGold < rerollCost then
                    return showMessage(tr('Error'), tr("You don't have enough gold coins.") .. '\n' .. tr('Required: ') .. rerollCost .. ' ' .. tr('gold coins.') .. '\n' .. tr('Bank: ') .. bankGold .. ' | ' .. tr('Backpack: ') .. backpackGold .. ' | ' .. tr('Total: ') .. totalGold .. ' ' .. tr('gold coins.'))
                end
            end
            executePreyAction(slot, PREY_ACTION_LISTREROLL, 0)
        end
    else
    end
end

function onPickSpecificPreyClick(widget)
    local slot = nil
    local prey1Panel = preyWindow:getChildById('prey1Panel')
    if prey1Panel then
        for i = 1, 3 do
            local prey = prey1Panel:getChildById('slot' .. i)
            if prey then
                if prey.inactive then
                    if prey.inactive.select then
                        if prey.inactive.select.pickSpecificPrey then
                            if prey.inactive.select.pickSpecificPrey == widget then
                                slot = i - 1
                                break
                            end
                        end
                    end
                end
                if prey.active then
                    if prey.active.select then
                        if prey.active.select.pickSpecificPrey then
                            if prey.active.select.pickSpecificPrey == widget then
                                slot = i - 1
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    if not slot then
        local prey2Panel = preyWindow:getChildById('prey2Panel')
        if prey2Panel then
            for i = 1, 3 do
                local prey = prey2Panel:getChildById('slot' .. i)
                if prey then
                    if prey.inactive then
                        if prey.inactive.select then
                            if prey.inactive.select.pickSpecificPrey then
                                if prey.inactive.select.pickSpecificPrey == widget then
                                    slot = i - 1
                                    break
                                end
                            end
                        end
                    end
                    if prey.active then
                        if prey.active.select then
                            if prey.active.select.pickSpecificPrey then
                                if prey.active.select.pickSpecificPrey == widget then
                                    slot = i - 1
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    if slot ~= nil then
        local player = g_game.getLocalPlayer()
        if player then
            local wildcards = player:getResourceBalance(ResourceTypes.PREY_WILDCARDS)
            if wildcards < 5 then
                return showMessage(tr('Error'), tr('You need at least 5 Prey Wildcards to select a specific creature.') .. '\n' .. tr('You have: ') .. wildcards .. ' ' .. tr('wildcards.'))
            end
        end

        local prey2Panel = preyWindow:getChildById('prey2Panel')
        local isTaskHunting = false
        if prey2Panel and prey2Panel:isVisible() then
            local taskHuntingSlot = prey2Panel:getChildById('slot' .. (slot + 1))
            if taskHuntingSlot then
                if taskHuntingSlot.activeTaskHunting and taskHuntingSlot.activeTaskHunting:isVisible() then
                    isTaskHunting = true
                elseif taskHuntingSlot.inactive and taskHuntingSlot.inactive:isVisible() then
                    if taskHuntingSlot.inactive.title and taskHuntingSlot.inactive.title:getText() == "Select monster" then
                        isTaskHunting = true
                    end
                end
            else
            end
        else
        end
        
        if isTaskHunting then
            return onTaskHuntingListAll(widget)
        else
        local prey, tab = getPreySlot(slot)
        if prey then
            prey.active:hide()
            prey.locked:hide()
            prey.inactive:show()
            
            local rerollList = prey.inactive:getChildById('rerollList')
            local monsterList = prey.inactive:getChildById('monsterList')
            if rerollList then rerollList:hide() end
            if monsterList then monsterList:show() end

                if prey.inactive.select and prey.inactive.select.price and prey.inactive.select.price.text then
                    prey.inactive.select.price.text:setText('5')
                else
                end
            end
            executePreyAction(slot, PREY_ACTION_REQUEST_ALL_MONSTERS, 0)
        end
    end
end

function getPreySlot(slot)

    if slot >= 0 and slot <= 2 then
        local prey1Panel = preyWindow:getChildById('prey1Panel')
        if prey1Panel then
            local prey = prey1Panel:getChildById('slot' .. (slot + 1))
            if prey then
                return prey, 1
            end
        end

        local prey2Panel = preyWindow:getChildById('prey2Panel')
        if prey2Panel then
            local prey = prey2Panel:getChildById('slot' .. (slot + 1))
            if prey then
                return prey, 2 
            end
        end
    end
    
    return nil, nil
end

function getPreyTracker(slot, isTaskHunting)
    if slot >= 0 and slot <= 2 then
        local trackerSlot = slot + 1
        
        if isTaskHunting then
            trackerSlot = slot + 4
        end
        
        local tracker = preyTracker.contentsPanel['slot' .. trackerSlot]
        if tracker then
            return tracker, isTaskHunting and 2 or 1
        end
    end
    
    return nil, nil
end

function getTaskHuntingSlot(slot)
    if slot >= 0 and slot <= 2 then
        local prey2Panel = preyWindow:getChildById('prey2Panel')
        if prey2Panel then
            local prey = prey2Panel:getChildById('slot' .. (slot + 1))
            if prey then
                return prey, 2
            end
        end
    end
    
    return nil, nil
end

function Prey.reset()
    if preyWindow then
        preyWindow:destroy()
        preyWindow = nil
    end
    
    if preyTracker then
        preyTracker:destroy()
        preyTracker = nil
    end
    
    preyWindow = g_ui.displayUI('prey')
    preyWindow:hide()
    
    preyTracker = g_ui.createWidget('PreyTracker', modules.game_interface.getRootPanel())
    preyTracker:hide()
    
    Prey.initPrey1()
    Prey.initPrey2()
end

function Prey.initPrey1()
    local prey1Panel = preyWindow:getChildById('prey1Panel')
    if not prey1Panel then
        return
    end
    
    for i = 1, 3 do
        local slot = prey1Panel:getChildById('slot' .. i)
        if slot then
            local active = slot:getChildById('active')
            local locked = slot:getChildById('locked')
            local inactive = slot:getChildById('inactive')
            local title = slot:getChildById('title')
            
            if active and locked and inactive and title then
                locked:hide()
                title:setText('Slot ' .. i)
            end
        end
    end
end

function Prey.initPrey2()
    local prey2Panel = preyWindow:getChildById('prey2Panel')
    if not prey2Panel then
        return
    end
    
    for i = 1, 3 do
        local slot = prey2Panel:getChildById('slot' .. i)
        if slot then
            local active = slot:getChildById('active')
            local locked = slot:getChildById('locked')
            local inactive = slot:getChildById('inactive')
            local exhausted = slot:getChildById('exhausted')
            local title = slot:getChildById('title')
            
            if active and locked and inactive and exhausted and title then
                locked:hide()
                exhausted:hide()
                title:setText('Slot ' .. i .. ' (Task Hunting)')
                slot.exhausted = exhausted
            end
        end
    end
end

function switchToTab1()
    if preyWindow then
        local prey1Panel = preyWindow:getChildById('prey1Panel')
        local prey2Panel = preyWindow:getChildById('prey2Panel')
        local preyTabBar = preyWindow:getChildById('preyTabBar')
        
        
        if preyTabBar then
            local prey1Tab = preyTabBar:getChildById('prey1Tab')
            local prey2Tab = preyTabBar:getChildById('prey2Tab')
            
            
            if prey1Panel and prey2Panel and prey1Tab and prey2Tab then
            prey1Panel:show()
            prey2Panel:hide()
                prey1Tab:setOn(true)
                prey2Tab:setOn(false)
            else
        end
        else
        end
    else
    end
end

function switchToTab2()
    if preyWindow then
        local prey1Panel = preyWindow:getChildById('prey1Panel')
        local prey2Panel = preyWindow:getChildById('prey2Panel')
        local preyTabBar = preyWindow:getChildById('preyTabBar')
        
        
        if preyTabBar then
            local prey1Tab = preyTabBar:getChildById('prey1Tab')
            local prey2Tab = preyTabBar:getChildById('prey2Tab')
            
            
            if prey1Panel and prey2Panel and prey1Tab and prey2Tab then
            prey1Panel:hide()
            prey2Panel:show()
                prey1Tab:setOn(false)
                prey2Tab:setOn(true)
            else
        end
        else
        end
    else
    end
end

function onTaskHuntingBasicData(preys, options, firstKills, secondKills)
    _G['taskHuntingFirstKills'] = firstKills
    _G['taskHuntingSecondKills'] = secondKills
end

function onTaskHuntingData(slot, state, ...)

    local argCount = select('#', ...)

    local taskHuntingSlot = getTaskHuntingSlot(slot)
    if not taskHuntingSlot then
        return
    end

    prey = taskHuntingSlot

    if not taskHuntingSlot.active or not taskHuntingSlot.inactive or not taskHuntingSlot.locked or 
       not taskHuntingSlot.activeTaskHunting or not taskHuntingSlot.inactiveTaskHunting then
        return
    end

    if state == 0 then
        if argCount >= 2 then
            local unlocked, nextFreeRoll = ...
            local tracker, tabIndex = getPreyTracker(slot, true)
            if tracker then
                tracker.creature:hide()
                tracker.noCreature:show()
                tracker.creatureName:setText('Locked')
                tracker.time:setPercent(0)
                tracker.preyType:hide()
                local tooltipText = 'Locked Task Hunting. \n\nClick in this window to open the prey dialog.'
                for i, element in pairs({tracker.creatureName, tracker.creature, tracker.time}) do
                    element:setTooltip(tooltipText)
                    element.onClick = function()
                        show()
                    end
                end
            end

            taskHuntingSlot.active:hide()
            taskHuntingSlot.inactive:hide()
            taskHuntingSlot.locked:show()
            taskHuntingSlot.title:setText('Locked')

            local activeHtpPanel = taskHuntingSlot.activeTaskHunting:getChildById('activeHtpPoints')
            if activeHtpPanel then
                activeHtpPanel:hide()
            end

            setTimeUntilFreeReroll(slot, nextFreeRoll, "taskhunting")
        end
        
    elseif state == 1 then
        if argCount >= 1 then
            local nextFreeRoll = ...
            local tracker, tabIndex = getPreyTracker(slot, true)
            if tracker then
                tracker.creature:hide()
                tracker.noCreature:show()
                tracker.creatureName:setText('Inactive')
                tracker.time:setPercent(0)
                tracker.preyType:hide()
                local tooltipText = 'Inactive Task Hunting. \n\nClick in this window to open the prey dialog.'
                for i, element in pairs({tracker.creatureName, tracker.creature, tracker.time}) do
                    element:setTooltip(tooltipText)
                    element.onClick = function()
                        show()
                    end
                end
            end

            taskHuntingSlot.active:hide()
            taskHuntingSlot.locked:hide()
            taskHuntingSlot.inactive:hide()
            taskHuntingSlot.activeTaskHunting:hide()
            taskHuntingSlot.inactiveTaskHunting:show()

            local activeHtpPanel = taskHuntingSlot.activeTaskHunting:getChildById('activeHtpPoints')
            if activeHtpPanel then
                activeHtpPanel:hide()
            end

            setTimeUntilFreeReroll(slot, nextFreeRoll, "taskhunting")
            onTaskHuntingInactive(slot, nextFreeRoll)
        end
        
    elseif state == 2 then
        if argCount >= 1 then
            local creatures = ...

            taskHuntingSlot.active:hide()
            taskHuntingSlot.locked:hide()
            taskHuntingSlot.inactive:show()
            taskHuntingSlot.activeTaskHunting:hide()
            taskHuntingSlot.inactiveTaskHunting:hide()
            taskHuntingSlot.title:setText(tr('Select monster'))

            local inactiveAmount = taskHuntingSlot.inactive:getChildById('inactiveAmount')
            if inactiveAmount then inactiveAmount:hide() end

            local activeHtpPanel = taskHuntingSlot.activeTaskHunting:getChildById('activeHtpPoints')
            if activeHtpPanel then
                activeHtpPanel:hide()
            end

            if taskHuntingSlot.inactive.reroll then 
                taskHuntingSlot.inactive.reroll:show()
            end
            if taskHuntingSlot.inactive.select then 
                taskHuntingSlot.inactive.select:show()
            end
            if taskHuntingSlot.inactive.choose then 
                taskHuntingSlot.inactive.choose:show()
                if taskHuntingSlot.inactive.choose.choosePreyButton then
                    taskHuntingSlot.inactive.choose.choosePreyButton.onClick = function()
                        local rerollList = taskHuntingSlot.inactive:getChildById('rerollList')
                        if rerollList then
                            for _, child in pairs(rerollList:getChildren()) do
                                if child:isChecked() then
                                    local raceId = child.raceId
                                    local amountChoice = rawget(_G, 'taskHuntingAmountChoice_' .. slot)
                                    if not amountChoice or amountChoice == 0 then
                                        return showMessage(tr('Error'), tr('Select Amount first.'))
                                    end

                                    local baseAmount = 0
                                    local amountPanel = taskHuntingSlot.inactive:getChildById('inactiveAmount3x3')
                                    if amountPanel then
                                        local opt1 = amountPanel:getChildById('amountOption1_3x3')
                                        if opt1 then
                                            local v1 = opt1:getChildById('value')
                                            baseAmount = tonumber(v1 and v1:getText() or '0') or 0
                                        end
                                    end
                                    local upgrade = (amountChoice > baseAmount) 
                                    g_game.taskHuntingAction(slot, TASK_HUNTING_ACTION_MONSTERSELECTION, upgrade, raceId)
                                    return
                                end
                            end
                        end
                    end
                end
            end

            local rerollList = taskHuntingSlot.inactive:getChildById('rerollList')
            if rerollList then
        
                rerollList:show()
                rerollList:setVisible(true)
                rerollList:destroyChildren()

                local searchEdit = taskHuntingSlot.inactive:getChildById('searchEdit')
                if searchEdit then
                    searchEdit:hide()
                end

                local preyScrollBar = taskHuntingSlot.inactive:getChildById('preyScrollBar')
                if preyScrollBar then
                    preyScrollBar:hide()
                end

                local taskData = {slot = slot, creatures = creatures}

                if argCount >= 3 then
                    local raceIds = select(2, ...)
                    local unlockedStatuses = select(3, ...)
                    local nextFreeRoll = select(4, ...)
                    
                    if type(raceIds) == "table" then
                        taskData.raceIds = raceIds
                        taskData.unlockedStatuses = unlockedStatuses
                        taskData.nextFreeRoll = nextFreeRoll
                        _G['taskHuntingSelectionData_' .. slot] = { raceIds = raceIds, unlockedStatuses = unlockedStatuses }
                end
            end
                    
                setupSelectionHuntingSlot(taskHuntingSlot, taskData)
                if taskHuntingSlot.inactive.confirm then
                    taskHuntingSlot.inactive.confirm.onClick = function()
                        onTaskHuntingConfirm(taskHuntingSlot.inactive.confirm)
                    end
                end
            end
        end
        
    elseif state == 3 then
        if argCount >= 4 then
            local creatures, raceIds, unlocked, nextFreeRoll = ...
            local taskHuntingSlot = getTaskHuntingSlot(slot)
            if taskHuntingSlot then
            else
            end
            _G['taskHuntingSelectionData_' .. slot] = { raceIds = raceIds, unlockedStatuses = unlocked }
            onTaskHuntingSelectionChangeMonster(slot, raceIds, nil, nil, nil, nextFreeRoll, nil)

            local taskHuntingSlot = getTaskHuntingSlot(slot)
            if taskHuntingSlot and taskHuntingSlot.inactive then
                local inactiveAmount = taskHuntingSlot.inactive:getChildById('inactiveAmount')
                if inactiveAmount then inactiveAmount:show() end
                local inactiveAmount3x3 = taskHuntingSlot.inactive:getChildById('inactiveAmount3x3')
                if inactiveAmount3x3 then inactiveAmount3x3:hide() end
            end
            if taskHuntingSlot.inactive.confirm then
                taskHuntingSlot.inactive.confirm.onClick = function()
                    local monsterList = taskHuntingSlot.inactive:getChildById('monsterList')
                    local amountPanel = taskHuntingSlot.inactive:getChildById('inactiveAmount3x3') or taskHuntingSlot.inactive:getChildById('inactiveAmount')
                    local choice = rawget(_G, 'taskHuntingAmountChoice_' .. slot)
                    if not choice or choice == 0 then
                        return showMessage(tr('Error'), tr('Select Amount first.'))
                    end

                    local baseAmount = 0
                    local opt1 = amountPanel:getChildById('amountOption1')
                    if opt1 then
                        local v1 = opt1:getChildById('value')
                        baseAmount = tonumber(v1 and v1:getText() or '0') or 0
                    end
                    local upgrade = (choice > baseAmount)
                    
                    if monsterList then
                        for _, child in pairs(monsterList:getChildren()) do
                            if child:getBackgroundColor() == '#00FF0044' then
                                local raceId = child.raceId
                                g_game.taskHuntingAction(slot, TASK_HUNTING_ACTION_MONSTERSELECTION, upgrade, raceId)
                                return
                            end
                        end
                    end
                end
            end
            setTimeUntilFreeReroll(slot, nextFreeRoll, "taskhunting")
        else
        end
        
    elseif state == 4 then
        
        if argCount >= 6 then
            local raceId, upgraded, requiredKills, currentKills, stars, nextFreeRoll = ...

            _G['taskHuntingRequiredKills_' .. slot] = requiredKills

            local tracker, tabIndex = getPreyTracker(slot, true)
            if tracker then

                local raceData = g_things.getRaceData(raceId)
                local creatureName = raceData and raceData.name or ("Monster " .. raceId)
                creatureName = capitalFormatStr(creatureName)

                local outfit
                if raceData and raceData.outfit then
                    outfit = raceData.outfit
                else
                    local fallbackLooktype = math.min(raceId % 1000, 500)
                    outfit = {type = fallbackLooktype, head = 0, body = 0, legs = 0, feet = 0}
                end

                tracker.creature:show()
                tracker.noCreature:hide()
                tracker.creatureName:setText(creatureName)
                tracker.creature:setOutfit(outfit)
                tracker.preyType:hide()

                local percent = (currentKills / requiredKills) * 100
                tracker.time:setPercent(percent)

                local tooltipText = 'Task Hunting: ' .. creatureName .. '\nProgress: ' .. currentKills .. '/' .. requiredKills .. 
                                   '\nStars: ' .. stars .. '/5' .. '\n\nClick in this window to open the prey dialog.'
                
                for i, element in pairs({tracker.creatureName, tracker.creature, tracker.time}) do
                    element:setTooltip(tooltipText)
                    element.onClick = function()
                        show()
                    end
                end
            end

            taskHuntingSlot.inactive:hide()
            taskHuntingSlot.locked:hide()
            taskHuntingSlot.active:hide()
            taskHuntingSlot.activeTaskHunting:show()
            taskHuntingSlot.inactiveTaskHunting:hide()

            local activeHtpPanel = taskHuntingSlot.activeTaskHunting:getChildById('activeHtpPoints')
            if activeHtpPanel then
                activeHtpPanel:show()
            else
            end

            if taskHuntingSlot.activeTaskHunting.creatureAndBonus and taskHuntingSlot.activeTaskHunting.creatureAndBonus.creature then
                local raceData = g_things.getRaceData(raceId)
                if raceData then
                    if raceData.outfit then
                    taskHuntingSlot.activeTaskHunting.creatureAndBonus.creature:setOutfit(raceData.outfit)
                    else
                        local fallbackLooktype = math.min(raceId % 1000, 500)
                        local fallbackOutfit = {type = fallbackLooktype, head = 0, body = 0, legs = 0, feet = 0}
                        taskHuntingSlot.activeTaskHunting.creatureAndBonus.creature:setOutfit(fallbackOutfit)
                    end
                else
                    local fallbackLooktype = math.min(raceId % 1000, 500)
                    local fallbackOutfit = {type = fallbackLooktype, head = 0, body = 0, legs = 0, feet = 0}
                    taskHuntingSlot.activeTaskHunting.creatureAndBonus.creature:setOutfit(fallbackOutfit)
                end
            end

            local creatureName = "Unknown Creature"
            local raceData = g_things.getRaceData(raceId)
            if raceData and raceData.name then
                creatureName = raceData.name
                local words = {}
                for word in creatureName:gmatch("%S+") do
                    table.insert(words, word:sub(1,1):upper() .. word:sub(2):lower())
                end
                creatureName = table.concat(words, " ")
            end
            taskHuntingSlot.title:setText(creatureName)

            if taskHuntingSlot.activeTaskHunting.progress and taskHuntingSlot.activeTaskHunting.progress.killsLabel then
                taskHuntingSlot.activeTaskHunting.progress.killsLabel:setText("Kills: " .. currentKills .. "/" .. requiredKills)
            else
            end

            if taskHuntingSlot.activeTaskHunting.progress and taskHuntingSlot.activeTaskHunting.progress.killsProgress then
                local percent = (currentKills / requiredKills) * 100
                taskHuntingSlot.activeTaskHunting.progress.killsProgress:setPercent(percent)
            else
            end
            
            local bonusPanel = taskHuntingSlot.activeTaskHunting.creatureAndBonus.bonus
            if bonusPanel then
                bonusPanel:destroyChildren()
                for i = 1, 5 do
                        if i <= stars then
                        local widget = g_ui.createWidget('Star', bonusPanel)
                        widget:setId('star' .. i)
                        widget:show()
                        else
                        local widget = g_ui.createWidget('NoStar', bonusPanel)
                        widget:setId('star' .. i)
                        widget:show()
                        end
                    end
                bonusPanel:show()
                for i, child in pairs(bonusPanel:getChildren()) do
                end
            end

            local activeHtpPanel = taskHuntingSlot.activeTaskHunting:getChildById('activeHtpPoints')
            if activeHtpPanel then
                local activeHtpText = activeHtpPanel:getChildById('activeHtpPointsText')
                if activeHtpText then
                    local difficulty = "easy"
                    if requiredKills >= 400 then
                        difficulty = "hard"
                    elseif requiredKills >= 100 then
                        difficulty = "medium"
                    end
                    
                    local htpPoints = calculateHTPPoints(stars, difficulty, requiredKills)
                    activeHtpText:setText(tostring(htpPoints))
                    activeHtpPanel:show()
                else
                end
            else
            end

            if taskHuntingSlot.activeTaskHunting.confirm then
                if currentKills >= requiredKills then
                    taskHuntingSlot.activeTaskHunting.confirm:show()
                else
                    taskHuntingSlot.activeTaskHunting.confirm:hide()
                end
            else
            end

            if taskHuntingSlot.activeTaskHunting.cancel then
                if currentKills < requiredKills then
                    taskHuntingSlot.activeTaskHunting.cancel:show()

                    local cancelPrice = taskHuntingSlot.activeTaskHunting.cancel.price
                    if cancelPrice then
                        local player = g_game.getLocalPlayer()
                        if player then
                            local level = player:getLevel()
                            local cancelCost = math.floor(level * 200)
                            local formattedCost = string.format("%d", cancelCost):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
                            cancelPrice:setText(formattedCost)
                        else
                            cancelPrice:setText("100")
                        end
                    else
                    end
                else
                    taskHuntingSlot.activeTaskHunting.cancel:hide()
                end
            else
            end

            if taskHuntingSlot.activeTaskHunting.upgrade then
                if currentKills < requiredKills then
                    taskHuntingSlot.activeTaskHunting.upgrade:show()
                    taskHuntingSlot.activeTaskHunting.upgrade:setVisible(true)

                    local upgradePrice = taskHuntingSlot.activeTaskHunting.upgrade.upgradePrice
                    if upgradePrice then
                        upgradePrice:setText("1")
                    else
                    end
                else
                    taskHuntingSlot.activeTaskHunting.upgrade:hide()
                end
            else
            end

            if taskHuntingSlot.activeTaskHunting.finish then
                if currentKills < requiredKills then
                    taskHuntingSlot.activeTaskHunting.finish:show()
                    taskHuntingSlot.activeTaskHunting.finish:setEnabled(false)
                    if taskHuntingSlot.activeTaskHunting.finish.finishButton then
                        taskHuntingSlot.activeTaskHunting.finish.finishButton:setImageSource('/images/game/prey/preyhuntingtask-finish-disabled')
                    end
                else
                    taskHuntingSlot.activeTaskHunting.finish:hide()
                end
            else
            end
            setTimeUntilFreeReroll(slot, nextFreeRoll, "taskhunting")
        end
        
    elseif state == 5 then
        if argCount >= 6 then
            local raceId, upgraded, requiredKills, currentKills, rarity, nextFreeRoll = ...

            taskHuntingSlot.active:hide()
            taskHuntingSlot.locked:hide()
            taskHuntingSlot.inactive:hide()
            taskHuntingSlot.activeTaskHunting:show()
            taskHuntingSlot.inactiveTaskHunting:hide()
            taskHuntingSlot.title:setText('Completed')

            local activeHtpPanel = taskHuntingSlot.activeTaskHunting:getChildById('activeHtpPoints')
            if activeHtpPanel then
                activeHtpPanel:show()

                local activeHtpText = activeHtpPanel:getChildById('activeHtpPointsText')
                if activeHtpText then
                    local difficulty = "easy"
                    if requiredKills >= 400 then
                        difficulty = "hard"
                    elseif requiredKills >= 100 then
                        difficulty = "medium"
                    end
                    
                    local htpPoints = calculateHTPPoints(rarity, difficulty, requiredKills)
                    activeHtpText:setText(tostring(htpPoints))
                else
                end
                
            end

            if taskHuntingSlot.activeTaskHunting.creatureAndBonus and taskHuntingSlot.activeTaskHunting.creatureAndBonus.creature then
                local raceData = g_things.getRaceData(raceId)
                if raceData then
                    if raceData.outfit then
                        taskHuntingSlot.activeTaskHunting.creatureAndBonus.creature:setOutfit(raceData.outfit)
                    else
                        local fallbackLooktype = math.min(raceId % 1000, 500)
                        local fallbackOutfit = {type = fallbackLooktype, head = 0, body = 0, legs = 0, feet = 0}
                        taskHuntingSlot.activeTaskHunting.creatureAndBonus.creature:setOutfit(fallbackOutfit)
                    end
                else
                    local fallbackLooktype = math.min(raceId % 1000, 500)
                    local fallbackOutfit = {type = fallbackLooktype, head = 0, body = 0, legs = 0, feet = 0}
                    taskHuntingSlot.activeTaskHunting.creatureAndBonus.creature:setOutfit(fallbackOutfit)
                end
            end

            if taskHuntingSlot.activeTaskHunting.creatureAndBonus and taskHuntingSlot.activeTaskHunting.creatureAndBonus.bonus then
                local bonusPanel = taskHuntingSlot.activeTaskHunting.creatureAndBonus.bonus
                if bonusPanel then
                    bonusPanel:destroyChildren()
                    for i = 1, 5 do
                        if i <= rarity then
                            local widget = g_ui.createWidget('Star', bonusPanel)
                            widget:setId('star' .. i)
                            widget:show()
                        else
                            local widget = g_ui.createWidget('NoStar', bonusPanel)
                            widget:setId('star' .. i)
                            widget:show()
                        end
                    end
                    bonusPanel:show()
                else
                end
            else
            end

            if taskHuntingSlot.activeTaskHunting.progress and taskHuntingSlot.activeTaskHunting.progress.killsLabel then
                taskHuntingSlot.activeTaskHunting.progress.killsLabel:setText("Kills: " .. requiredKills .. "/" .. requiredKills)
            else
            end

            if taskHuntingSlot.activeTaskHunting.progress and taskHuntingSlot.activeTaskHunting.progress.killsProgress then
                taskHuntingSlot.activeTaskHunting.progress.killsProgress:setPercent(100)
            else
            end

            if taskHuntingSlot.activeTaskHunting.finish then
                taskHuntingSlot.activeTaskHunting.finish:show()
                taskHuntingSlot.activeTaskHunting.finish:setEnabled(true)

                if taskHuntingSlot.activeTaskHunting.finish.finishButton then
                    taskHuntingSlot.activeTaskHunting.finish.finishButton:setImageSource('/images/game/prey/preyhuntingtask-finish')
                end
                
            else
            end

            if taskHuntingSlot.activeTaskHunting.cancel then
                taskHuntingSlot.activeTaskHunting.cancel:hide()
            end

            if taskHuntingSlot.activeTaskHunting.upgrade then
                taskHuntingSlot.activeTaskHunting.upgrade:show()

                local upgradePrice = taskHuntingSlot.activeTaskHunting.upgrade.upgradePrice
                if upgradePrice then
                    upgradePrice:setText("1")
                else
                end
                
            end

            setTimeUntilFreeReroll(slot, nextFreeRoll, "taskhunting")
            scheduleEvent(updateTaskHuntingPoints, 500)
        end
        
    elseif state == 6 then
        if argCount >= 1 then
            local nextFreeRoll = ...
            taskHuntingSlot.active:hide()
            taskHuntingSlot.locked:hide()
            taskHuntingSlot.inactive:hide()
            taskHuntingSlot.activeTaskHunting:hide()
            taskHuntingSlot.inactiveTaskHunting:hide()
            taskHuntingSlot.exhausted:show()
            taskHuntingSlot.title:setText('Exhausted')

            setTimeUntilFreeReroll(slot, nextFreeRoll, "taskhunting")
            
        end
    end
end

function onTaskHuntingReroll(widget)
    local slot = getSlotFromWidget(widget)
    if slot then
        if g_game.taskHuntingAction then
            g_game.taskHuntingAction(slot, TASK_HUNTING_ACTION_LISTREROLL, false, 0)
        else
        end
    end
end

function onTaskHuntingCancel(widget)

    local slot = getSlotFromWidget(widget)
    if slot then
    else
        for tab = 1, 2 do
            local panel = preyWindow:getChildById('prey' .. tab .. 'Panel')
            if panel then
                for i = 1, 3 do
                    local slotWidget = panel:getChildById('slot' .. i)
                    if slotWidget then
                        local activeTaskHunting = slotWidget:getChildById('activeTaskHunting')
                        if activeTaskHunting and activeTaskHunting:isVisible() then
                            slot = i - 1
                            break
                        end
                    end
                end
                if slot then break end
            end
        end
    end
    
    if slot then
        if g_game.taskHuntingAction then
            g_game.taskHuntingAction(slot, TASK_HUNTING_ACTION_CANCEL, false, 0)
        else
        end
    else
    end
end

function onTaskHuntingUpgrade(widget)

    local slot = getSlotFromWidget(widget)
    if slot then
    else
        for tab = 1, 2 do
            local panel = preyWindow:getChildById('prey' .. tab .. 'Panel')
            if panel then
                for i = 1, 3 do
                    local slotWidget = panel:getChildById('slot' .. i)
                    if slotWidget then
                        local activeTaskHunting = slotWidget:getChildById('activeTaskHunting')
                        if activeTaskHunting and activeTaskHunting:isVisible() then
                            slot = i - 1
                            break
                        end
                    end
                end
                if slot then break end
            end
        end
    end
    
    if slot then
        
        local player = g_game.getLocalPlayer()
        if player then
            local wildcards = player:getResourceBalance(ResourceTypes.PREY_WILDCARDS)
            if wildcards >= 1 then

                local taskHuntingSlot = getTaskHuntingSlot(slot)
                if taskHuntingSlot and taskHuntingSlot.activeTaskHunting and taskHuntingSlot.activeTaskHunting:isVisible() then
                    local bonusPanel = taskHuntingSlot.activeTaskHunting.creatureAndBonus.bonus
                    if bonusPanel then
                        local currentStars = 0
                        for _, child in pairs(bonusPanel:getChildren()) do
                            if child:getClassName() == "UIWidget" and child:getId() and child:getId():match("star%d+") then
                                if child:getStyleName() == "Star" then
                                    currentStars = currentStars + 1
                                end
                            end
                        end

                        if currentStars < 5 then
                            local newStars = currentStars + 1
                            bonusPanel:destroyChildren()

                            for i = 1, 5 do
                                if i <= newStars then
                                    local widget = g_ui.createWidget('Star', bonusPanel)
                                    widget:setId('star' .. i)
                                    widget:show()
                                else
                                    local widget = g_ui.createWidget('NoStar', bonusPanel)
                                    widget:setId('star' .. i)
                                    widget:show()
                                end
                            end
                            bonusPanel:show()
                            local activeHtpPanel = taskHuntingSlot.activeTaskHunting:getChildById('activeHtpPoints')
                            if activeHtpPanel then
                                local activeHtpText = activeHtpPanel:getChildById('activeHtpPointsText')
                                if activeHtpText then
                                    local progressPanel = taskHuntingSlot.activeTaskHunting.progress
                                    local killsLabel = progressPanel and progressPanel:getChildById('killsLabel')
                                    local requiredKills = 50
                                    
                                    if killsLabel then
                                        local killsText = killsLabel:getText()
                                        local _, killsEnd = killsText:find("Kills: %d+/")
                                        if killsEnd then
                                            local killsStr = killsText:sub(killsEnd + 1)
                                            requiredKills = tonumber(killsStr) or 50
                                        end
                                    end

                                    local difficulty = "easy"
                                    if requiredKills >= 400 then
                                        difficulty = "hard"
                                    elseif requiredKills >= 100 then
                                        difficulty = "medium"
                                    end
                                    
                                    local htpPoints = calculateHTPPoints(newStars, difficulty, requiredKills)
                                    activeHtpText:setText(tostring(htpPoints))
                                    local oldHTP = 0
                                    if currentStars > 0 then
                                        oldHTP = calculateHTPPoints(currentStars, difficulty, requiredKills)
                                    end
                                else
                                end
                            end

                            if preyWindow and preyWindow.wildCards then
                                local newWildcards = wildcards - 1
                                preyWindow.wildCards:setText(tostring(newWildcards))
                            end

                            if g_game.taskHuntingAction then
                                g_game.taskHuntingAction(slot, TASK_HUNTING_ACTION_REWARDSREROLL, true, 0)
                            else
                            end
                        else
                        end
                    else
                    end
                else
                end
            else
            end
        end
    else
    end
end

function onTaskHuntingSelection(slot, names, outfits, timeUntilFreeReroll, wildcards)
    
    if not preyWindow then
        return
    end
    
    local taskHuntingSlot = getTaskHuntingSlot(slot)
    if not taskHuntingSlot then
        return
    end
    
    if not timeUntilFreeReroll or timeUntilFreeReroll < 0 or timeUntilFreeReroll > 999999 then
        timeUntilFreeReroll = 0
    end
        setTimeUntilFreeReroll(slot, timeUntilFreeReroll, "taskhunting")
    
    taskHuntingSlot.active:hide()
    taskHuntingSlot.locked:hide()
    taskHuntingSlot.inactive:show()
    taskHuntingSlot.activeTaskHunting:hide()
    taskHuntingSlot.inactiveTaskHunting:hide()
    taskHuntingSlot.title:setText(tr('Select monster'))
    
    local searchEdit = taskHuntingSlot.inactive:getChildById('searchEdit')
    if searchEdit then
        searchEdit:hide()
    end
    
    if taskHuntingSlot.inactive.select then
        taskHuntingSlot.inactive.select.onClick = function()
            if g_game.taskHuntingAction then
                executePreyAction(slot, PREY_ACTION_REQUEST_ALL_MONSTERS, 0)
            end
        end
    end

    if taskHuntingSlot.inactive.choose then
        taskHuntingSlot.inactive.choose:show()
        if taskHuntingSlot.inactive.choose.choosePreyButton then
            taskHuntingSlot.inactive.choose.choosePreyButton.onClick = function()
                local rerollList = taskHuntingSlot.inactive:getChildById('rerollList')
                if rerollList then
                    for _, child in pairs(rerollList:getChildren()) do
                        if child:isChecked() then
                            local raceId = child.raceId
                            g_game.taskHuntingAction(slot, TASK_HUNTING_ACTION_MONSTERSELECTION, false, raceId)
                            return
                        end
                    end
                end
            end
        end
    end

end

function onTaskHuntingSelectionChangeMonster(slot, names, outfits, bonusType, bonusValue, bonusGrade, timeUntilFreeReroll, wildcards)
    
    if not preyWindow then
        return
    end
    
    local taskHuntingSlot = getTaskHuntingSlot(slot)
    if not taskHuntingSlot then
        return
    end
    
    if not timeUntilFreeReroll or timeUntilFreeReroll < 0 or timeUntilFreeReroll > 999999 then
        timeUntilFreeReroll = 0
    end
    setTimeUntilFreeReroll(slot, timeUntilFreeReroll, "taskhunting")

    taskHuntingSlot.active:hide()
    taskHuntingSlot.locked:hide()
    taskHuntingSlot.inactive:show()
    taskHuntingSlot.activeTaskHunting:hide()
    taskHuntingSlot.inactiveTaskHunting:hide()

    if taskHuntingSlot.exhausted then
        taskHuntingSlot.exhausted:hide()
    end
    
    taskHuntingSlot.title:setText(tr('Select monster'))

    local monsterList = taskHuntingSlot.inactive:getChildById('monsterList')
    local rerollList = taskHuntingSlot.inactive:getChildById('rerollList')
    local searchEdit = taskHuntingSlot.inactive:getChildById('searchEdit')
    local amountTop = taskHuntingSlot.inactive:getChildById('inactiveAmount')
    local amount3x3 = taskHuntingSlot.inactive:getChildById('inactiveAmount3x3')

    if searchEdit then
        searchEdit:show()
        searchEdit:setText('')
    end

    local inactiveAmount = taskHuntingSlot.inactive:getChildById('inactiveAmount')
    if inactiveAmount then inactiveAmount:show() end
    local inactiveAmount3x3 = taskHuntingSlot.inactive:getChildById('inactiveAmount3x3')
    if inactiveAmount3x3 then inactiveAmount3x3:hide() end

    if monsterList then 
        monsterList:show() 
        monsterList:destroyChildren()

        local preyScrollBar = taskHuntingSlot.inactive:getChildById('preyScrollBar')
        if preyScrollBar then
            preyScrollBar:show()
        end
        if amountTop then amountTop:show() end
        if amount3x3 then amount3x3:hide() end
    end

    if rerollList then 
        rerollList:hide() 
        rerollList:destroyChildren()
    end
    
    local list = taskHuntingSlot.inactive:getChildById('list')
    if list then list:hide() end
    
    if taskHuntingSlot.inactive.reroll then 
        taskHuntingSlot.inactive.reroll:show()
    end
    if taskHuntingSlot.inactive.select then 
        taskHuntingSlot.inactive.select:show()
        taskHuntingSlot.inactive.select.onClick = function()
            if g_game.taskHuntingAction then
                g_game.taskHuntingAction(slot, TASK_HUNTING_ACTION_LISTALL_CARDS, false, 0)
            else
            end
        end
    end
    if taskHuntingSlot.inactive.choose then 
        taskHuntingSlot.inactive.choose:show()
        if taskHuntingSlot.inactive.choose.choosePreyButton then
            taskHuntingSlot.inactive.choose.choosePreyButton.onClick = function()
                local raceId = nil
                local selectedWidget = nil

                for i, child in pairs(rerollList:getChildren()) do
                    if child:isChecked() then
                        raceId = child.raceId
                        selectedWidget = child
                        break
                    end
                end

                if not raceId and monsterList then
                    for i, child in pairs(monsterList:getChildren()) do
                        if child:isChecked() then
                            raceId = child.raceId
                            selectedWidget = child
                            break
                        end
                    end
                end
                
                if raceId then
                    local amountChoice = rawget(_G, 'taskHuntingAmountChoice_' .. slot)
                    if not amountChoice or amountChoice == 0 then
                        return showMessage(tr('Error'), tr('Select Amount first.'))
                    end

                    local baseAmount = 0
                    local amountPanel = taskHuntingSlot.inactive:getChildById('inactiveAmount')
                    if amountPanel then
                        local opt1 = amountPanel:getChildById('amountOption1')
                        if opt1 then
                            local v1 = opt1:getChildById('value')
                            baseAmount = tonumber(v1 and v1:getText() or '0') or 0
                        end
                    end
                    local upgrade = (amountChoice > baseAmount)

                    g_game.taskHuntingAction(slot, TASK_HUNTING_ACTION_MONSTERSELECTION, upgrade, raceId)
                else
                    return showMessage(tr('Error'), tr('Select monster to proceed.'))
                end
            end
        end
    end
    
    if not monsterList then
        return
    end
    
    monsterList:destroyChildren()

    _G['taskHuntingRaceData_' .. slot] = {}
    

    for i, raceId in ipairs(names) do
        local raceData = g_things.getRaceData(raceId)
        local creatureName = raceData and raceData.name or ("Monster " .. raceId)
        creatureName = capitalFormatStr(creatureName)
        
        local label = g_ui.createWidget('Label', monsterList)
        label:setText(string.format("%3d. %s", i, creatureName))
        label:setFont('verdana-11px-monochrome')
        label:setColor('#C0C0C0')
        label:setFocusable(true)

        label.raceId = raceId
        label.creatureName = creatureName

        local bestiaryData = getBestiaryData(raceId)
        local difficulty = bestiaryData and bestiaryData.difficulty or 1
        local stars = string.rep("★", difficulty) .. string.rep("☆", 5 - difficulty)

        local firstKills = _G['taskHuntingFirstKills']
        local secondKills = _G['taskHuntingSecondKills']
        local text1 = "25"
        local text2 = "50"
        
        if bestiaryData and bestiaryData.difficulty and firstKills and secondKills then
            local diff = bestiaryData.difficulty
            local index = 1
            if diff <= 1 then
                index = 1
            elseif diff <= 3 then
                index = 6
            else
                index = 11
            end
            
            if firstKills[index] then text1 = tostring(firstKills[index]) end
            if secondKills[index] then text2 = tostring(secondKills[index]) end
        end

        local baseHTP = calculateHTPPoints(difficulty, difficulty, tonumber(text1))
        local upgradedHTP = calculateHTPPoints(difficulty, difficulty, tonumber(text2))

        local tooltipText = string.format(
            "%s\n" ..
            "Difficulty: %s\n" ..
            "Kill Amount: %s / %s\n" ..
            "HTP Reward: %d / %d points",
            creatureName,
            stars,
            text1,
            text2,
            baseHTP,
            upgradedHTP
        )
        label:setTooltip(tooltipText)
        _G['taskHuntingRaceData_' .. slot][i] = {
            raceId = raceId,
            name = creatureName,
            originalIndex = i,
            label = label
        }
        
        connect(label, {onMousePress = function(widget, mousePos, mouseButton)
            if mouseButton == MouseLeftButton then
                for _, child in pairs(monsterList:getChildren()) do
                    if child ~= widget then
                        child:setBackgroundColor('#00000000')
                    end
                end
                widget:setBackgroundColor('#00FF0044')
                _G['selectedPreyRace_' .. slot] = raceId
                _G['selectedPreyIndex_' .. slot] = i - 1
                if amountTop then
                    local opt1 = amountTop:getChildById('amountOption1')
                    local opt2 = amountTop:getChildById('amountOption2')

                    updateAmountOptionsForRaceId(raceId)
                    local unlocked = false
                    local data = rawget(_G, 'taskHuntingSelectionData_' .. slot)
                    if data and data.unlockedStatuses then
                        local idx1 = i
                        if data.unlockedStatuses[idx1] ~= nil then
                            unlocked = data.unlockedStatuses[idx1]
                        end
                    end
                    opt2:setEnabled(unlocked)
                    opt1:setOn(true)
                    opt2:setOn(false)
                    local dot1 = opt1:getChildById('dot')
                    local dot2 = opt2:getChildById('dot')
                    if dot1 then dot1:setImageSource('/images/ui/icon-combopoint-filled') end
                    if dot2 then dot2:setImageSource('/images/ui/icon-combopoint-empty') end
                    local v1 = opt1:getChildById('value')
                    _G['taskHuntingAmountChoice_' .. slot] = tonumber(v1 and v1:getText() or '0') or 0
                    opt1.onClick = function(widget)
                        if not opt1:isEnabled() then 
                            return 
                        end
                        opt1:setOn(true)
                        opt2:setOn(false)
                        local dot1 = opt1:getChildById('dot')
                        local dot2 = opt2:getChildById('dot')
                        if dot1 then dot1:setImageSource('/images/ui/icon-combopoint-filled') end
                        if dot2 then dot2:setImageSource('/images/ui/icon-combopoint-empty') end
                        local v1 = opt1:getChildById('value')
                        _G['taskHuntingAmountChoice_' .. slot] = tonumber(v1 and v1:getText() or '0') or 0
                    end
                    opt2.onClick = function(widget)
                        if not opt2:isEnabled() then 
                            return 
                        end
                        opt1:setOn(false)
                        opt2:setOn(true)
                        local dot1 = opt1:getChildById('dot')
                        local dot2 = opt2:getChildById('dot')
                        if dot1 then dot1:setImageSource('/images/ui/icon-combopoint-empty') end
                        if dot2 then dot2:setImageSource('/images/ui/icon-combopoint-filled') end
                        local v2 = opt2:getChildById('value')
                        _G['taskHuntingAmountChoice_' .. slot] = tonumber(v2 and v2:getText() or '0') or 0
                    end
                end
                return true
            end
            return false
        end})
    end

    if searchEdit then
        searchEdit.onTextChange = function(widget, text)
            filterTaskHuntingCreatures(slot, text)
        end
    end

    if taskHuntingSlot.inactive.choose then
        taskHuntingSlot.inactive.choose:show()
        if taskHuntingSlot.inactive.choose.choosePreyButton then
            taskHuntingSlot.inactive.choose.choosePreyButton.onClick = function()
                local monsterList = taskHuntingSlot.inactive:getChildById('monsterList')
                local rerollList = taskHuntingSlot.inactive:getChildById('rerollList')
                local raceId = nil

                if monsterList and monsterList:isVisible() then

                    raceId = _G['selectedPreyRace_' .. slot]
                    if raceId then
                    end
                end

                if not raceId and rerollList and rerollList:isVisible() then
                    for _, child in pairs(rerollList:getChildren()) do
                        if child:isChecked() then
                            raceId = child.raceId
                            break
                        end
                    end
                end
                
                if raceId then
                    local choice = rawget(_G, 'taskHuntingAmountChoice_' .. slot) or 0
                    local baseAmount = 0
                    local amountPanel = nil
                    if monsterList and monsterList:isVisible() then
                        amountPanel = taskHuntingSlot.inactive:getChildById('inactiveAmount')
                    elseif rerollList and rerollList:isVisible() then
                        amountPanel = taskHuntingSlot.inactive:getChildById('inactiveAmount3x3')
                    end
                    
                    if amountPanel then
                        local opt1 = amountPanel:getChildById('amountOption1')
                        if opt1 then
                            local v1 = opt1:getChildById('value')
                            baseAmount = tonumber(v1 and v1:getText() or '0') or 0
                        end
                    end
                    local upgrade = (choice > baseAmount)
                    g_game.taskHuntingAction(slot, TASK_HUNTING_ACTION_MONSTERSELECTION, upgrade, raceId)
                else
                    return showMessage(tr('Error'), tr('Select monster to proceed.'))
                end
            end
        end
    end
end

function onTaskHuntingNextFreeRoll(slot, nextFreeRoll)
    setTimeUntilFreeReroll(slot, nextFreeRoll, "taskhunting")
end

function onTaskHuntingActive(slot, raceId, upgraded, requiredKills, currentKills, stars, nextFreeRoll)
    _G['taskHuntingRequiredKills_' .. slot] = requiredKills

    local taskHuntingSlot = getTaskHuntingSlot(slot)
    if not taskHuntingSlot then
        return
    end

    local tracker, tabIndex = getPreyTracker(slot, true)
    if tracker then
        local raceData = g_things.getRaceData(raceId)
        local creatureName = raceData and raceData.name or ("Monster " .. raceId)
        creatureName = capitalFormatStr(creatureName)

        local outfit
        if raceData and raceData.outfit then
            outfit = raceData.outfit
        else
            local fallbackLooktype = math.min(raceId % 1000, 500)
            outfit = {type = fallbackLooktype, head = 0, body = 0, legs = 0, feet = 0}
        end

        tracker.creature:show()
        tracker.noCreature:hide()
        tracker.creatureName:setText(creatureName)
        tracker.creature:setOutfit(outfit)
        tracker.preyType:hide()

        local percent = (currentKills / requiredKills) * 100
        tracker.time:setPercent(percent)

        local tooltipText = 'Task Hunting: ' .. creatureName .. '\nProgress: ' .. currentKills .. '/' .. requiredKills .. 
                           '\nStars: ' .. stars .. '/5' .. '\n\nClick in this window to open the prey dialog.'
        
        for i, element in pairs({tracker.creatureName, tracker.creature, tracker.time}) do
            element:setTooltip(tooltipText)
            element.onClick = function()
                show()
            end
        end
    end

    taskHuntingSlot.active:hide()
    taskHuntingSlot.locked:hide()
    taskHuntingSlot.inactive:hide()
    taskHuntingSlot.activeTaskHunting:show()
    taskHuntingSlot.inactiveTaskHunting:hide()

    local activeAmountPanel = taskHuntingSlot.activeTaskHunting:getChildById('activeAmount')
    if activeAmountPanel then
        activeAmountPanel:hide()
    end

    if taskHuntingSlot.activeTaskHunting.creatureAndBonus and taskHuntingSlot.activeTaskHunting.creatureAndBonus.creature then
            local outfit = {lookType = raceId, lookHead = 0, lookBody = 0, lookLegs = 0, lookFeet = 0}
        taskHuntingSlot.activeTaskHunting.creatureAndBonus.creature:setOutfit(outfit)
        end

    if taskHuntingSlot.activeTaskHunting.progress and taskHuntingSlot.activeTaskHunting.progress.killsLabel then
        taskHuntingSlot.activeTaskHunting.progress.killsLabel:setText("Kills: " .. currentKills .. "/" .. requiredKills)
    end

    if taskHuntingSlot.activeTaskHunting.progress and taskHuntingSlot.activeTaskHunting.progress.killsProgress then
        local percent = (currentKills / requiredKills) * 100
        taskHuntingSlot.activeTaskHunting.progress.killsProgress:setPercent(percent)
        end

    if taskHuntingSlot.activeTaskHunting.creatureAndBonus then
        if taskHuntingSlot.activeTaskHunting.creatureAndBonus.bonus then
            for i = 1, 5 do
                local star = taskHuntingSlot.activeTaskHunting.creatureAndBonus.bonus:getChildById('star' .. i)
                if star then
                    if i <= stars then
                        star:setImageSource('/images/game/prey/prey_star')
                    else
                        star:setImageSource('/images/game/prey/prey_nostar')
                end
            end
        end

            local htpLabel = taskHuntingSlot.activeTaskHunting.creatureAndBonus.bonus:getChildById('htpPoints')
            if htpLabel then
                local difficulty = "easy"
                if requiredKills >= 400 then
                    difficulty = "hard"
                elseif requiredKills >= 100 then
                    difficulty = "medium"
                end
                
                local htpPoints = calculateHTPPoints(stars, difficulty, requiredKills)
                htpLabel:setText("HTP: " .. htpPoints)
            end
        end
    else
        for i = 1, 5 do
            local star = taskHuntingSlot.activeTaskHunting:getChildById('star' .. i)
            if star then
                if i <= stars then
                    star:setImageSource('/images/game/prey/prey_star')
                else
                    star:setImageSource('/images/game/prey/prey_nostar')
                end
            end
        end

        local htpLabel = taskHuntingSlot.activeTaskHunting:getChildById('htpPoints')
        if htpLabel then
            local difficulty = "easy"
            if requiredKills >= 400 then
                difficulty = "hard"
            elseif requiredKills >= 100 then
                difficulty = "medium"
            end
            
            local htpPoints = calculateHTPPoints(stars, difficulty, requiredKills)
            htpLabel:setText("HTP: " .. htpPoints)
        end
    end

    if taskHuntingSlot.activeTaskHunting.confirm then
        if currentKills >= requiredKills then
            taskHuntingSlot.activeTaskHunting.confirm:show()
        else
            taskHuntingSlot.activeTaskHunting.confirm:hide()
            end
        end

    if taskHuntingSlot.activeTaskHunting.cancel then
        if currentKills < requiredKills then
            taskHuntingSlot.activeTaskHunting.cancel:show()
    else
            taskHuntingSlot.activeTaskHunting.cancel:hide()
        end
    end

    setTimeUntilFreeReroll(slot, nextFreeRoll, "taskhunting")
end

function onTaskHuntingInactive(slot, nextFreeRoll)
        local taskHuntingSlot = getTaskHuntingSlot(slot)
        if not taskHuntingSlot then
            return
        end

        taskHuntingSlot.active:hide()
        taskHuntingSlot.locked:hide()
        taskHuntingSlot.inactive:hide()
        taskHuntingSlot.activeTaskHunting:hide()
        taskHuntingSlot.inactiveTaskHunting:show()
        taskHuntingSlot.exhausted:hide()
        taskHuntingSlot.title:setText(tr('Exhausted'))

    if taskHuntingSlot.inactiveTaskHunting.rerollButton then 
        taskHuntingSlot.inactiveTaskHunting.rerollButton:show()

        local rerollButton = taskHuntingSlot.inactiveTaskHunting.rerollButton
        
        if rerollButton and rerollButton.button then
            if rerollButton.button.time then
                if nextFreeRoll and nextFreeRoll > 0 then
                    if rerollButton.button.time.setPercent then
                        rerollButton.button.time:setPercent(100)
                    end
                    if rerollButton.button.time.setText then
                        rerollButton.button.time:setText(timeleftTranslation(nextFreeRoll))
                    end
                else
                    if rerollButton.button.time.setPercent then
                        rerollButton.button.time:setPercent(0)
                    end
                    if rerollButton.button.time.setText then
                        rerollButton.button.time:setText("Free")
                    end
                end
            end
        end
        
        if rerollButton and rerollButton.rerollPrice then
            local player = g_game.getLocalPlayer()
            if player then
                local level = player:getLevel()
                local rerollCost = math.floor(level * 200)
                local formattedCost = string.format("%d", rerollCost):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
                if rerollButton.rerollPrice.setText then
                    rerollButton.rerollPrice:setText(formattedCost)
                end
            end
        else
        end
    end
    
    if taskHuntingSlot.inactiveTaskHunting.selectButton then 
        taskHuntingSlot.inactiveTaskHunting.selectButton:show()
    end
    if taskHuntingSlot.inactiveTaskHunting.chooseButton then 
        taskHuntingSlot.inactiveTaskHunting.chooseButton:show()
    end

    local rerollList = taskHuntingSlot.inactiveTaskHunting:getChildById('rerollList')
    if rerollList then
        rerollList:hide()
    end

    if taskHuntingSlot.inactiveTaskHunting and taskHuntingSlot.inactiveTaskHunting.rerollButton then
        setTimeUntilFreeReroll(slot, nextFreeRoll, "taskhunting")
    end
end

function onTaskHuntingClaim(widget)
    local slot = getSlotFromWidget(widget)
    if slot then

        if g_game.taskHuntingAction then
            g_game.taskHuntingAction(slot, TASK_HUNTING_ACTION_CLAIM, false, 0)
            scheduleEvent(updateTaskHuntingPoints, 1000)
        else
        end
    end
end

function onTaskHuntingSelect(widget)
    local slot = getSlotFromWidget(widget)
    if slot then
        if g_game.taskHuntingAction then
            g_game.taskHuntingAction(slot, TASK_HUNTING_ACTION_LISTALL_CARDS, false, 0)
        else
        end
    end
end

function onTaskHuntingListAll(widget)
    local slot = getSlotFromWidget(widget)
    if slot then

        local player = g_game.getLocalPlayer()
        if player then
            local wildcards = player:getResourceBalance(ResourceTypes.PREY_WILDCARDS)
            if wildcards < 5 then
                return showMessage(tr('Error'), tr('You need at least 5 Prey Wildcards to view the full monster list.') .. '\n' .. tr('You have: ') .. wildcards .. ' ' .. tr('wildcards.'))
            end
        end
        if g_game.taskHuntingAction then
            g_game.taskHuntingAction(slot, TASK_HUNTING_ACTION_LISTALL_CARDS, false, 0)
        else
        end
    else
    end
end

function getSlotFromWidget(widget)
    for tab = 1, 2 do
        local panel = preyWindow:getChildById('prey' .. tab .. 'Panel')
        if panel then
            for i = 1, 3 do
                local slot = panel:getChildById('slot' .. i)
                if slot then
                    local foundWidget = slot:recursiveGetChildById(widget:getId())
                    if foundWidget then
                        if foundWidget == widget then
                        return i - 1
                        else
                        end
                    end
                end
            end
        end
    end
    return nil
end

function init()
    Prey.init()
end

function getTaskHuntingPoints()
    if g_game.getTaskHuntingPoints then
        return g_game.getTaskHuntingPoints()
    else
        return 0
    end
end

function updateTaskHuntingPoints()
    if not preyWindow then
        return
    end
    
    local points = getTaskHuntingPoints()
    local pointsWidget = preyWindow:getChildById("taskHuntingPoints")
    if pointsWidget then
        local textWidget = pointsWidget:getChildById("pointsText")
        if textWidget then
            textWidget:setText(tostring(points))
        end
    end
end

function onResourceBalance(resourceType, value)
    if resourceType == "taskHunting" then
        if g_game.setTaskHuntingPoints then
            g_game.setTaskHuntingPoints(value)
        end
        updateTaskHuntingPoints()
    end
end

function setupSelectionHuntingSlot(slot, taskData)
    
    if slot.inactive.title then
        slot.inactive.title:setText("Select Monster")
    end
    if not slot.inactive then
        return
    end
    
    local rerollList = slot.inactive:getChildById('rerollList')
    local inactiveAmount3x3 = slot.inactive:getChildById('inactiveAmount3x3')
    local monsterList = slot.inactive:getChildById('monsterList')

    if monsterList then
        monsterList:hide()
    end
    if rerollList then
        rerollList:show()
        if inactiveAmount3x3 then
            inactiveAmount3x3:show()
        end
    end
    
    if rerollList and taskData.creatures then
        for _, child in pairs(rerollList:getChildren()) do
            child:hide()
        end

        if taskData.raceIds and type(taskData.raceIds) == "table" then
            for i, raceId in ipairs(taskData.raceIds) do
                local box = g_ui.createWidget('PreyCreatureBox', rerollList)

                    local selectionData = _G['taskHuntingSelectionData_' .. tostring(slot)]
                    
                    if selectionData and selectionData.unlockedStatuses and selectionData.raceIds then
                        local raceIndex = nil
                        for i, id in ipairs(selectionData.raceIds) do
                            if id == raceId then
                                raceIndex = i
                                break
                            end
                        end

                        if raceIndex and selectionData.unlockedStatuses[raceIndex] then
                            local unlocked = selectionData.unlockedStatuses[raceIndex]
                            if unlocked >= 2 then
                                defaultKills = 400
                            elseif unlocked == 1 then
                                defaultKills = 100
                            else
                                defaultKills = 25
                            end
                        end
                    end

                local raceData = g_things.getRaceData(raceId)
                local monsterName = raceData and raceData.name or ("Monster " .. raceId)
                monsterName = capitalFormatStr(monsterName)
                box:setTooltip(monsterName)
                
                box.monsterIndex = i - 1
                box.raceId = raceId

                if box.creature then
                    if raceData and raceData.outfit then
                        box.creature:setOutfit(raceData.outfit)
                    else
                        local fallbackLooktype = math.min(raceId % 1000, 500)
                        box.creature:setOutfit({type = fallbackLooktype, head = 0, body = 0, legs = 0, feet = 0})
                    end
                end
            end

            local amountPanel = slot.inactive:getChildById('inactiveAmount3x3') or slot.inactive:getChildById('inactiveAmount')
            if amountPanel then
                local opt1 = amountPanel:getChildById('amountOption1_3x3') or amountPanel:getChildById('amountOption1')
                local opt2 = amountPanel:getChildById('amountOption2_3x3') or amountPanel:getChildById('amountOption2')
                if opt1 and opt2 then
                    local v1 = opt1:getChildById('value'); if v1 then v1:setText('0') end
                    local v2 = opt2:getChildById('value'); if v2 then v2:setText('0') end

                    local unlocked = false
                    if taskData.unlockedStatuses and taskData.unlockedStatuses[1] ~= nil then
                        unlocked = taskData.unlockedStatuses[1]
                    end
                    opt2:setEnabled(unlocked)
                    opt1:setOn(false)
                    opt2:setOn(false)
                    local dot1 = opt1:getChildById('dot'); if dot1 then dot1:setImageSource('/images/ui/icon-combopoint-empty') end
                    local dot2 = opt2:getChildById('dot'); if dot2 then dot2:setImageSource('/images/ui/icon-combopoint-empty') end
                    _G['taskHuntingAmountChoice_' .. taskData.slot] = 0
                    opt1.onClick = function(widget)
                        if not opt1:isEnabled() then return end
                        opt1:setOn(true)
                        opt2:setOn(false)
                        local v1 = opt1:getChildById('value')
                        _G['taskHuntingAmountChoice_' .. taskData.slot] = tonumber(v1 and v1:getText() or '0') or 0
                        local dot1 = opt1:getChildById('dot'); if dot1 then dot1:setImageSource('/images/ui/icon-combopoint-filled') end
                        local dot2 = opt2:getChildById('dot'); if dot2 then dot2:setImageSource('/images/ui/icon-combopoint-empty') end
                    end
                    opt2.onClick = function(widget)
                        if not opt2:isEnabled() then return end
                        opt1:setOn(false)
                        opt2:setOn(true)
                        local v2 = opt2:getChildById('value')
                        _G['taskHuntingAmountChoice_' .. taskData.slot] = tonumber(v2 and v2:getText() or '0') or 0
                        local dot1 = opt1:getChildById('dot'); if dot1 then dot1:setImageSource('/images/ui/icon-combopoint-empty') end
                        local dot2 = opt2:getChildById('dot'); if dot2 then dot2:setImageSource('/images/ui/icon-combopoint-filled') end
                    end
                    _G['taskHuntingAmountChoice_' .. taskData.slot] = 0
                    amountPanel:show()
                end
            end
        else
            for i = 1, taskData.creatures do
                local box = g_ui.createWidget('PreyCreatureBox', rerollList)
                local outfit = {lookType = 6 + i, lookHead = 0, lookBody = 0, lookLegs = 0, feet = 0}
                if box.creature then
                    box.creature:setOutfit(outfit)
                end
                
                box.monsterIndex = i - 1
                box.raceId = 6 + i
                box:setTooltip(capitalFormatStr("Monster " .. (6 + i)))
            end
        end
    end

    if slot.inactive.choose and slot.inactive.choose.choosePreyButton then
        if taskData and taskData.slot and taskData.slot >= 0 then
            slot.inactive.choose.choosePreyButton:setImageSource('/images/game/prey/preyhuntingtask-select')
        else
            slot.inactive.choose.choosePreyButton:setImageSource('/images/game/prey/prey_choose')
        end
    end

    if slot.inactive.select and slot.inactive.select.pickSpecificPrey then
        slot.inactive.select.pickSpecificPrey.onClick = function()

            local player = g_game.getLocalPlayer()
            if player then
                local wildcards = player:getResourceBalance(ResourceTypes.PREY_WILDCARDS)
                if wildcards < 5 then
                    g_logger.warning("Not enough wildcards: " .. wildcards .. " < 5")
                    return showMessage(tr('Error'), tr('You need at least 5 Prey Wildcards to select a specific creature.') .. '\n' .. tr('You have: ') .. wildcards .. ' ' .. tr('wildcards.'))
                end
            end

            if g_game.taskHuntingAction then
                local result = g_game.taskHuntingAction(taskData.slot, TASK_HUNTING_ACTION_LISTALL_CARDS, false, 0)
            else
                g_logger.error("g_game.taskHuntingAction is not available!")
            end
        end

        slot.inactive.select.pickSpecificPrey:setImageSource('/images/game/prey/prey_select')
        slot.inactive.select.pickSpecificPrey:enable()
        
        if slot.inactive.select.price and slot.inactive.select.price.text then
            slot.inactive.select.price.text:setText('5')
        end
    end
end

function onMonsterHover(widget)
    if not widget then return end

    if not widget:isChecked() then
        if preyWindow then
            local description = preyWindow:getChildById('description')
            if description then
                description:setText('')
            end
        end
        return
    end

    local raceId = widget.raceId
    if not raceId or raceId == 0 then
        local creature = widget:getChildById('creature')
        if creature and creature.raceId then
            raceId = creature.raceId
        end
    end

    if not raceId or raceId == 0 then 
        if preyWindow then
            local description = preyWindow:getChildById('description')
            if description then
                description:setText('')
            end
        end
        return 
    end

    local raceData = g_things.getRaceData(raceId)
    if not raceData then 
        if preyWindow then
            local description = preyWindow:getChildById('description')
            if description then
                description:setText('')
            end
        end
        return 
    end

    local monsterName = raceData.name or "Unknown Monster"
    monsterName = capitalFormatStr(monsterName)

    local bestiaryData = getBestiaryData(raceId)
    local difficulty = bestiaryData and bestiaryData.difficulty or 1
    local firstKills = _G['taskHuntingFirstKills']
    local secondKills = _G['taskHuntingSecondKills']
    local text1 = nil
    local text2 = nil

    if bestiaryData and bestiaryData.difficulty and firstKills and secondKills then
        local diff = bestiaryData.difficulty
        local index = 1
        if diff <= 1 then
            index = 1
        elseif diff <= 3 then
            index = 6
        else
            index = 11
        end

        if firstKills[index] then text1 = tostring(firstKills[index]) end
        if secondKills[index] then text2 = tostring(secondKills[index]) end
    end

    local selectedAmount = nil
    local slot = nil

    for i = 0, 2 do
        local taskHuntingSlot = getTaskHuntingSlot(i)
        if taskHuntingSlot and taskHuntingSlot.inactive then
            local rerollList = taskHuntingSlot.inactive:getChildById('rerollList')
            local monsterList = taskHuntingSlot.inactive:getChildById('monsterList')
            
            if rerollList and rerollList:recursiveGetChildById(widget:getId()) then
                slot = i
                selectedAmount = _G['taskHuntingAmountChoice_' .. slot] or 0
                break
            elseif monsterList and monsterList:recursiveGetChildById(widget:getId()) then
                slot = i
                selectedAmount = _G['taskHuntingAmountChoice_' .. slot] or 0
                break
            end
        end
    end

    local minHtpPoints = 0
    local maxHtpPoints = 0
    if bestiaryData and bestiaryData.difficulty then
        local difficultyStr = "easy"
        if difficulty <= 1 then
            difficultyStr = "easy"
        elseif difficulty <= 3 then
            difficultyStr = "medium"
        else
            difficultyStr = "hard"
        end
        minHtpPoints = calculateHTPPoints(1, difficultyStr, 25)
        maxHtpPoints = calculateHTPPoints(5, difficultyStr, 25)
    end

    local descriptionText
    if selectedAmount and selectedAmount > 0 then
        descriptionText = string.format(
            "Creature: %s\n" ..
            "Amount: %d\n" ..
            "Hunting Task Points: %d - %d points",
            monsterName,
            selectedAmount,
            minHtpPoints,
            maxHtpPoints
        )
    else
        descriptionText = string.format(
            "Creature: %s\n" ..
            "Data not available",
            monsterName
        )
    end

    if preyWindow then
        local description = preyWindow:getChildById('description')
        if description then
            description:setText(descriptionText)
        end
    end
end

modules.game_prey = {
    show = show,
    hide = hide,
    onHover = onHover,
    onMonsterHover = onMonsterHover,
    onRerollButtonClick = onRerollButtonClick,
    onPickSpecificPreyClick = onPickSpecificPreyClick,
    onItemBoxChecked = onItemBoxChecked,
    switchToTab1 = switchToTab1,
    switchToTab2 = switchToTab2,
    onTaskHuntingData = onTaskHuntingData,
    onTaskHuntingBasicData = onTaskHuntingBasicData,
    onTaskHuntingFreeRerolls = onTaskHuntingFreeRerolls,
    onTaskHuntingTimeLeft = onTaskHuntingTimeLeft,
    onTaskHuntingRerollPrice = onTaskHuntingRerollPrice,
    onTaskHuntingConfirm = onTaskHuntingConfirm,
    onTaskHuntingSelect = onTaskHuntingSelect,
    onTaskHuntingListAll = onTaskHuntingListAll,
    onTaskHuntingCancel = onTaskHuntingCancel,
    onTaskHuntingUpgrade = onTaskHuntingUpgrade,
    onTaskHuntingClaim = onTaskHuntingClaim,
    onTaskHuntingSelectionChangeMonster = onTaskHuntingSelectionChangeMonster,
    onTaskHuntingNextFreeRoll = onTaskHuntingNextFreeRoll,
    onTaskHuntingRerollPrice = onTaskHuntingRerollPrice,
    onTaskHuntingReroll = onTaskHuntingReroll,
    onTaskHuntingRerollResponse = onTaskHuntingRerollResponse,
    onTaskHuntingActive = onTaskHuntingActive,
    onTaskHuntingInactive = onTaskHuntingInactive,
    getTaskHuntingPoints = getTaskHuntingPoints,
    updateTaskHuntingPoints = updateTaskHuntingPoints,
    onResourceBalance = onResourceBalance
}

function updateAmountPanel(taskHuntingSlot, slot, raceId, panelId, opt1Id, opt2Id)
    local amountPanel = taskHuntingSlot.inactive:getChildById(panelId) or taskHuntingSlot.inactive:getChildById('inactiveAmount')
    if not amountPanel then 
        return 
    end
    
    local opt1 = amountPanel:getChildById(opt1Id) or amountPanel:getChildById('amountOption1')
    local opt2 = amountPanel:getChildById(opt2Id) or amountPanel:getChildById('amountOption2')
    if not opt1 or not opt2 then 
        return 
    end

    local firstKills = _G['taskHuntingFirstKills']
    local secondKills = _G['taskHuntingSecondKills']
    local bestiaryData = getBestiaryData(raceId)
    if bestiaryData and bestiaryData.difficulty and firstKills and secondKills then
        local difficulty = bestiaryData.difficulty
        local index = 1
        if difficulty <= 1 then
            index = 1
        elseif difficulty <= 3 then
            index = 6
        else
            index = 11
        end
        
        if firstKills[index] then text1 = tostring(firstKills[index]) end
        if secondKills[index] then text2 = tostring(secondKills[index]) end
    else
        requestBestiaryData(raceId)
    end

    local v1 = opt1:getChildById('value'); if v1 then v1:setText(text1) end
    local v2 = opt2:getChildById('value'); if v2 then v2:setText(text2) end
    local unlocked = isBestiaryCompleted(raceId)
    opt2:setEnabled(unlocked)
    opt1:setOn(true)
    opt2:setOn(false)
    local dot1 = opt1:getChildById('dot')
    local dot2 = opt2:getChildById('dot')
    if dot1 then dot1:setImageSource('/images/ui/icon-combopoint-filled') end
    if dot2 then dot2:setImageSource('/images/ui/icon-combopoint-empty') end
    local v1 = opt1:getChildById('value')
    _G['taskHuntingAmountChoice_' .. slot] = tonumber(v1 and v1:getText() or '0') or 0
    opt1.onClick = function(widget)
        if not opt1:isEnabled() then return end
        opt1:setOn(true)
        opt2:setOn(false)
        local dot1 = opt1:getChildById('dot')
        local dot2 = opt2:getChildById('dot')
        if dot1 then dot1:setImageSource('/images/ui/icon-combopoint-filled') end
        if dot2 then dot2:setImageSource('/images/ui/icon-combopoint-empty') end
        local v1 = opt1:getChildById('value')
        _G['taskHuntingAmountChoice_' .. slot] = tonumber(v1 and v1:getText() or '0') or 0
    end
    opt2.onClick = function(widget)
        if not opt2:isEnabled() then return end
        opt1:setOn(false)
        opt2:setOn(true)
        local dot1 = opt1:getChildById('dot')
        local dot2 = opt2:getChildById('dot')
        if dot1 then dot1:setImageSource('/images/ui/icon-combopoint-empty') end
        if dot2 then dot2:setImageSource('/images/ui/icon-combopoint-filled') end
        local v2 = opt2:getChildById('value')
        _G['taskHuntingAmountChoice_' .. slot] = tonumber(v2 and v2:getText() or '0') or 0
    end
end
