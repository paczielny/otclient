local function formatPrice(value)
    if value < 10000 then
        return tostring(value):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "").. " k"
    elseif value < 1000000 then
        return string.format("%.1fk", value / 1000):gsub("%.0", "")
    else
        return string.format("%.1fkk", value / 1000000):gsub("%.0", "")
    end
end

Fragment_Workshop.onReceiveData = function(lesserFragments, greaterFragments)
    Fragment_Workshop.reset()
    for _, data in pairs(lesserFragments) do
        Fragment_Workshop.LesserFragments[data.bonusId] = data.grade
    end

    for _, data in pairs(lesserFragments) do
        Fragment_Workshop.GreaterFragments[data.bonusId] = data.grade
    end

    local vocation = WheelDestiny.vocation
    local mods = Fragment_Workshop.UI.mods

    Fragment_Workshop.Info = {
        actualPage = 1,
        pages = 1,
        count = 1
    }

    mods:destroyChildren()
    for i = 0, #Fragment_Workshop.Supreme_Modifiers do
        local data = Fragment_Workshop.Supreme_Modifiers[i]
        if data.vocations[vocation] then
            local widget = g_ui.createWidget("FragmentWindow", mods)
            local grade = Fragment_Workshop.GreaterFragments[i] or 0

            widget:setId(string.format("%d_%d", 3, i))
            widget.base.mod:setImageClip(torect(string.format("%d %d %d %d", (i * 35), 0, 35, 35)))

            widget.base.mod:setMarginBottom(2)
            widget.base.mod:setMarginLeft(3)

            widget.data = {
                clip = i,
                filter = 3,
                object = data,
                page = nil,
                visible = true,
                grade = grade
            }

            if grade > 0 then
                widget.base:setImageClip(torect(string.format("%d %d %d %d", (50 * grade), 0, 50, 50)))
            end

            local size = Fragment_Workshop.Fragments[1][i]
            if size and size > 0 then
                widget.count:setText(string.format("x %d", size))
                widget.count:setVisible(true)
            end

            widget.data.page = math.ceil(Fragment_Workshop.Info.count / 30)
            if widget.data.page > Fragment_Workshop.Info.pages then
                Fragment_Workshop.Info.pages = widget.data.page
            end

            if widget.data.page ~= Fragment_Workshop.Info.actualPage then
                widget:setVisible(false)
            end

            Fragment_Workshop.Info.count = Fragment_Workshop.Info.count + 1
        end
    end

    for i = 0, #Fragment_Workshop.Basic_Modifiers do
        local data = Fragment_Workshop.Basic_Modifiers[i]
        if not data.disabled then
            local widget = g_ui.createWidget("FragmentWindow", mods)
            local grade = Fragment_Workshop.LesserFragments[i] or 0

            widget:setId(string.format("%d_%d", 2, i))
            widget.base.mod:setImageSource("/mods/game_wheel/images/icons-skillwheel-basicmods")
            widget.base.mod:setImageClip(torect(string.format("%d %d %d %d", (30 * i), 0, 30, 30)))
            widget.base.mod:setSize({ width = 30, height = 30 })
            widget.base.mod:setMarginBottom(0)
            widget.base.mod:setMarginLeft(0)
    
            widget.data = {
                clip = i,
                filter = 2,
                object = data,
                page = nil,
                visible = true,
                grade = grade
            }

            if grade > 0 then
                widget.base:setImageClip(torect(string.format("%d %d %d %d", (50 * grade), 0, 50, 50)))
            end

            local size = Fragment_Workshop.Fragments[2][i]
            if size and size > 0 then
                widget.count:setText(string.format("x %d", size))
                widget.count:setVisible(true)
            end
    
            widget.data.page = math.ceil(Fragment_Workshop.Info.count / 30)
            if widget.data.page > Fragment_Workshop.Info.pages then
                Fragment_Workshop.Info.pages = widget.data.page
            end
    
            if widget.data.page ~= Fragment_Workshop.Info.actualPage then
                widget:setVisible(false)
            end
    
            Fragment_Workshop.Info.count = Fragment_Workshop.Info.count + 1
        end
    end

    Fragment_Workshop.onSelectMod(mods:getFirstChild())
    Fragment_Workshop.Info.count = Fragment_Workshop.Info.count -1
    Fragment_Workshop.updatePage()
    Fragment_Workshop.updateActivedMods()
    Gem_Atelier.updateModsGrades()
end

Fragment_Workshop.onSelectMod = function(widget)
    local view = Fragment_Workshop.UI.grade
    if widget then
        local parent = widget:getParent()
        local data = widget.data
        local grade = 0
        local type = 1

        for _, child in pairs(parent:getChildren()) do
            child:setChecked(false)
        end
    
        widget:setChecked(true)
        view.selectedEmpty:setVisible(false)
        view.selected:setVisible(true)

		if data then
			view.selected.name:setText(data.object.name)
		
			for i = 1, 4 do
				local descriptions = view.selected["descriptions"..i]
				local tier = view.selected["tier"..i]

				if data.filter == 3 then
					tier.mod:setImageSource("/mods/game_wheel/images/icons-skillwheel-suprememods")
					tier.mod:setImageClip(torect(string.format("%d %d %d %d", (data.clip * 35), 0, 35, 35)))
					tier.mod:setSize({ width = 35, height = 35 })
					tier.mod:setMarginBottom(2)
					tier.mod:setMarginLeft(3)
					view.fragment.icon:setImageSource("/mods/game_wheel/images/icon-fragments-greater")
					grade = Fragment_Workshop.GreaterFragments[data.clip] or 0
					type = 2
				else
					tier.mod:setImageSource("/mods/game_wheel/images/icons-skillwheel-basicmods")
					tier.mod:setImageClip(torect(string.format("%d %d %d %d", (30 * data.clip), 0, 30, 30)))
					tier.mod:setSize({ width = 30, height = 30 })
					tier.mod:setMarginBottom(0)
					tier.mod:setMarginLeft(0)
					view.fragment.icon:setImageSource("/mods/game_wheel/images/icon-fragments-lesser")
					grade = Fragment_Workshop.LesserFragments[data.clip] or 0
				end

				if grade == 3 then
					view.enchance:setVisible(false)
					view.gold:setVisible(false)
					view.fragment:setVisible(false)
				else
					local price = Fragment_Workshop.getGradePrice(type, grade)
					local fragments = Fragment_Workshop.getGradeFragments(type, grade)
					local state = WheelDestiny.state == 1
					local enabled = false
					
					local gold = WheelDestiny.Resources[0]
					local lesser = WheelDestiny.Resources[84]
					local greater = WheelDestiny.Resources[85]
					
					view.gold.value:setText(formatPrice(price))
					
					view.gold.value:setEnabled(gold > price)
					enabled = gold > price
					
					local availableFragments = (type == 1) and lesser or greater
					if availableFragments > fragments then
						view.fragment.value:setEnabled(true)
						enabled = true
					else
						enabled = false
					end
					
					view.enchance:setEnabled(state)
					view.enchance:setEnabled(enabled)

					view.enchance:setVisible(true)
					view.gold:setVisible(true)
					view.fragment:setVisible(true)
				end

				if (grade + 1) >= i then
					tier:setEnabled(true)
					view.selected["backdrop"..i]:setChecked(true)

					if view.selected["line"..(i - 1)] then
						view.selected["line"..(i - 1)]:setChecked(true)
					end
				else
					tier:setEnabled(false)
					view.selected["backdrop"..i]:setChecked(false)
					if view.selected["line"..(i - 1)] then
						view.selected["line"..(i - 1)]:setChecked(false)
					end
				end

				descriptions:destroyChildren()
				for _, object in ipairs(data.object.descriptions) do
					local label = g_ui.createWidget("ModGemDescription", descriptions)
					label:setText(string.format("%s %s", object.values[i -1], object.text))
					label:setTextAutoResize(true)
					if i ~= (grade + 1) then
						label:setEnabled(false)
					end
				end
			end
			Fragment_Workshop.SelectedMod = {
				clip = data.clip,
				grade = grade
			}
		end
    else
        view.selectedEmpty:setVisible(true)
        view.selected:setVisible(false)
        Fragment_Workshop.SelectedMod = nil
    end
end

Fragment_Workshop.updatePage = function()
    local nextButton = Fragment_Workshop.UI.nextButton
    local prevButton = Fragment_Workshop.UI.prevButton

    if Fragment_Workshop.Info.actualPage <= 1 then
        Fragment_Workshop.Info.actualPage = 1

        prevButton:setEnabled(false)
        if Fragment_Workshop.Info.pages <= 1 then
            nextButton:setEnabled(false)
        else
            nextButton:setEnabled(true)
        end
    else
        prevButton:setEnabled(true)

        if Fragment_Workshop.Info.actualPage >= Fragment_Workshop.Info.pages then
            nextButton:setEnabled(false)
        else
            nextButton:setEnabled(true)
        end
    end

    local info = Fragment_Workshop.Info
    Fragment_Workshop.UI.pageCount:setText(string.format("Page %d / %d (%d Mods)", info.actualPage, info.pages, info.count))
end

Fragment_Workshop.onSelectPage = function(action)
    local mods = Fragment_Workshop.UI.mods

    if action == 1 then
        Fragment_Workshop.Info.actualPage = Fragment_Workshop.Info.actualPage + 1
    else
        Fragment_Workshop.Info.actualPage = Fragment_Workshop.Info.actualPage - 1
    end

    for _, child in ipairs(mods:getChildren()) do
        if child.data.visible then
            if child.data.page ~= Fragment_Workshop.Info.actualPage then
                child:setVisible(false)
            else
                child:setVisible(true)
            end
        end
    end

    Fragment_Workshop.updatePage()
end

Fragment_Workshop.getGradePrice = function(type, grade)
    local values = {
        [1] = {
            [0] = 2000,
            [1] = 5000,
            [2] = 30000000
        },
        [2] = {
            [0] = 5000,
            [1] = 12000000,
            [2] = 75000000
        }
    }

    return values[type][grade]
end

Fragment_Workshop.getGradeFragments = function(type, grade)
    local values = {
        [1] = {
            [0] = 5,
            [1] = 15,
            [2] = 30
        },
        [2] = {
            [0] = 5,
            [1] = 15,
            [2] = 30
        }
    }

    return values[type][grade]
end

Fragment_Workshop.onFilter = function(option)
    if not Fragment_Workshop.UI then
        return
    end
    local mods = Fragment_Workshop.UI.mods
    local showAll = option == 1
    local first = nil

    for _, widget in pairs(mods:getChildren()) do
        if showAll then
            if not first then
                first = widget
            end

            widget:setVisible(true)
            widget.data.visible = true
        else
            if widget.data.filter == option then
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
    end

    local count = 0
    local widgetsPerPage = 30
    Fragment_Workshop.Info.pages = 1
    Fragment_Workshop.Info.actualPage = 1

    for _, child in ipairs(mods:getChildren()) do
        if child.data.visible then
            count = count + 1
            child.data.page = math.ceil(count / widgetsPerPage)
    
            if child.data.page > Fragment_Workshop.Info.pages then
                Fragment_Workshop.Info.pages = child.data.page
            end
        end

        if child.data.page ~= Fragment_Workshop.Info.actualPage then
            child:setVisible(false)
        end
    end

    Fragment_Workshop.onSelectMod(first)

    Fragment_Workshop.Info.count = count
    Fragment_Workshop.updatePage()
end

Fragment_Workshop.updateActivedMods = function()
    local mods = Fragment_Workshop.UI.mods

    for _, widget in pairs(mods:getChildren()) do
        if widget.data.visible then
            widget.actived:setVisible(false)
        end
    end

    for _, object in pairs(WheelDestiny.ActivedGem) do
        local data = object.data
        for i = 1, data.size do
            local attribute = Gem_Atelier.getGemAttribute(i)
            local clip = data.object[attribute]
            local widget = nil
    
            if i > 2 then
                widget = mods:getChildById(string.format("%d_%d", 3, clip))
            else
                widget = mods:getChildById(string.format("%d_%d", 2, clip))
            end
            
            if widget then
                widget.actived:setVisible(true)
            end
        end
    end
end

Fragment_Workshop.enchanceMod = function()
    local data = Fragment_Workshop.SelectedMod
    if not data then
        return
    end

    g_game.requestWheelGemAction(4, data.grade,  data.clip)
end

Fragment_Workshop.reset = function()
    Fragment_Workshop.LesserFragments = {}
    Fragment_Workshop.GreaterFragments = {}
    Fragment_Workshop.Fragments = {
        [1] = {},
        [2] = {}
    }
end

Fragment_Workshop.updateBalance = function()
    local lesser = WheelDestiny.Resources[84]
    local greater = WheelDestiny.Resources[85]

    WheelDestiny.UI.main.lesserFragmentsBalance.value:setText(lesser)
    WheelDestiny.UI.main.greaterFragmentsBalance.value:setText(greater)
end
