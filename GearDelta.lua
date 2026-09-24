local tooltip = GameTooltip
local L = GetLocale() == "deDE" and {
    title = "GEAR DELTA",
    current = "Aktuell: %s",
    proposed = "Neu: %s",
    together = "Zusammen angelegt: %s",
    comparison = "Vergleich %d",
    gain = "GEWINN",
    loss = "VERLUST",
} or {
    title = "GEAR DELTA",
    current = "Equipped: %s",
    proposed = "New: %s",
    together = "If equipped together: %s",
    comparison = "Comparison %d",
    gain = "GAIN",
    loss = "LOSE",
}

local activeLink
local waitingFor = {}
local eventFrame = CreateFrame("Frame")

local function accessible(value)
    return canaccessvalue(value)
end

local function field(object, key)
    if not accessible(object) or type(object) ~= "table" then
        return nil
    end
    local value = object[key]
    if accessible(value) then
        return value
    end
end

local function requestItem(link)
    local itemID = C_Item.GetItemInfoInstant(link)
    if accessible(itemID) and type(itemID) == "number" then
        waitingFor[itemID] = true
        C_Item.RequestLoadItemDataByID(link)
    end
end

local function linkFor(reference)
    if not accessible(reference) then
        return nil
    end
    if type(reference) == "string" then
        return reference
    end
    local guid = field(reference, "guid")
    if type(guid) == "string" then
        local link = C_Item.GetItemLinkByGUID(guid)
        if accessible(link) and type(link) == "string" then
            return link
        end
    end
    local link = field(reference, "hyperlink")
    if type(link) == "string" and link ~= "" then
        return link
    end
end

local function displayedItem(data)
    local guid = field(data, "guid")
    local hyperlink = field(data, "hyperlink")
    if type(guid) == "string" then
        local link = C_Item.GetItemLinkByGUID(guid)
        if accessible(link) and type(link) == "string" then
            return link, { guid = guid }
        end
    end
    if type(hyperlink) == "string" and hyperlink ~= "" then
        return hyperlink, { hyperlink = hyperlink }
    end
end

local function resolveLinks(references)
    local links = {}
    for _, reference in ipairs(references) do
        local link = linkFor(reference)
        if not link then
            return nil
        end
        links[#links + 1] = link
    end
    return links
end

local function itemNames(links)
    local names = {}
    for _, link in ipairs(links) do
        local name = C_Item.GetItemInfo(link)
        if not accessible(name) or type(name) ~= "string" then
            requestItem(link)
            return nil
        end
        names[#names + 1] = name
    end
    return table.concat(names, " + ")
end

local function statKeyAllowed(key)
    return type(key) == "string" and
        (key:match("^ITEM_MOD_") or key:match("^RESISTANCE%d+_NAME$"))
end

local function statLabel(key)
    local label = _G[key]
    if accessible(label) and type(label) == "string" and label ~= "" and not label:find("%%") then
        return label
    end
    return key:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", ""):gsub("_", " ")
end

local function totalStats(links)
    local total = {}
    for _, link in ipairs(links) do
        local cached = C_Item.IsItemDataCachedByID(link)
        if not accessible(cached) then
            return nil
        end
        if not cached then
            requestItem(link)
            return nil
        end
        local stats = C_Item.GetItemStats(link)
        if not accessible(stats) then
            return nil
        end
        stats = stats or {}
        if type(stats) ~= "table" then
            return nil
        end
        for key, amount in pairs(stats) do
            if not accessible(key) or not accessible(amount) then
                return nil
            end
            if statKeyAllowed(key) and type(amount) == "number" then
                total[key] = (total[key] or 0) + amount
            end
        end
    end
    return total
end

local function changes(newStats, oldStats)
    local gain, loss = {}, {}
    for key in pairs(newStats) do
        oldStats[key] = oldStats[key] or 0
    end
    for key, oldAmount in pairs(oldStats) do
        local delta = (newStats[key] or 0) - oldAmount
        if delta ~= 0 then
            local entry = { label = statLabel(key), amount = delta }
            local group = delta > 0 and gain or loss
            group[#group + 1] = entry
        end
    end
    local function byLabel(a, b)
        return a.label < b.label
    end
    table.sort(gain, byLabel)
    table.sort(loss, byLabel)
    return gain, loss
end

local function comparisonCases(item, info)
    local primary = field(info, "item")
    local additional = field(info, "additionalItems")
    local method = field(info, "method")
    if not primary or type(additional) ~= "table" then
        return nil
    end

    local methods = Enum.TooltipComparisonMethod
    method = method or methods.Single
    if method == methods.Single then
        if #additional > 1 then
            return nil
        end
        local cases = { { old = { primary }, new = { item } } }
        if additional[1] then
            cases[#cases + 1] = { old = { additional[1] }, new = { item } }
        end
        return cases
    end
    if method == methods.WithBothHands then
        if #additional > 1 then
            return nil
        end
        local old = { primary }
        if additional[1] then
            old[#old + 1] = additional[1]
        end
        return { { old = old, new = { item } } }
    end
    if method == methods.WithBagMainHandItem or method == methods.WithBagOffHandItem then
        if #additional ~= 1 then
            return nil
        end
        return { { old = { primary }, new = { item, additional[1] }, together = true } }
    end
end

local function prepareCase(case, index)
    local oldLinks = resolveLinks(case.old)
    local newLinks = resolveLinks(case.new)
    if not oldLinks or not newLinks then
        return
    end
    local oldNames = itemNames(oldLinks)
    local newNames = itemNames(newLinks)
    local oldStats = totalStats(oldLinks)
    local newStats = totalStats(newLinks)
    if not oldNames or not newNames or not oldStats or not newStats then
        return
    end
    local gain, loss = changes(newStats, oldStats)
    if #gain == 0 and #loss == 0 then
        return
    end

    return {
        index = index,
        oldNames = oldNames,
        newNames = newNames,
        gain = gain,
        loss = loss,
        together = case.together,
    }
end

local function renderCase(view, multiple)
    if multiple then
        tooltip:AddLine(L.comparison:format(view.index), 1, 0.82, 0)
    end
    tooltip:AddLine(L.current:format(view.oldNames), 0.75, 0.75, 0.75, true)
    tooltip:AddLine((view.together and L.together or L.proposed):format(view.newNames), 0.75, 0.75, 0.75, true)
    if #view.gain > 0 then
        tooltip:AddLine(L.gain, 0.4, 0.9, 0.4)
        for _, entry in ipairs(view.gain) do
            tooltip:AddLine(("+%g %s"):format(entry.amount, entry.label), 0.4, 0.9, 0.4)
        end
    end
    if #view.loss > 0 then
        tooltip:AddLine(L.loss, 0.95, 0.45, 0.45)
        for _, entry in ipairs(view.loss) do
            tooltip:AddLine(("%g %s"):format(entry.amount, entry.label), 0.95, 0.45, 0.45)
        end
    end
end

local function onItemTooltip(currentTooltip, data)
    if currentTooltip ~= tooltip or currentTooltip:GetPrimaryTooltipData() ~= data then
        return
    end
    local link, item = displayedItem(data)
    wipe(waitingFor)
    activeLink = nil
    if not link then
        return
    end
    local equippable = C_Item.IsEquippableItem(link)
    if not accessible(equippable) or not equippable then
        return
    end
    activeLink = link
    local info = C_TooltipComparison.GetItemComparisonInfo(item)
    if not accessible(info) or type(info) ~= "table" then
        return
    end
    local cases = comparisonCases(item, info)
    if not cases then
        return
    end
    local views = {}
    for index, case in ipairs(cases) do
        local view = prepareCase(case, index)
        if view then
            views[#views + 1] = view
        end
    end
    if #views == 0 then
        return
    end
    currentTooltip:AddLine(" ")
    currentTooltip:AddLine(L.title, 1, 0.82, 0)
    for index, view in ipairs(views) do
        if index > 1 then
            currentTooltip:AddLine(" ")
        end
        renderCase(view, #cases > 1)
    end
end

local function refreshActiveTooltip()
    if not activeLink or not tooltip:IsShown() then
        return
    end
    local data = tooltip:GetPrimaryTooltipData()
    local link = data and displayedItem(data)
    if link == activeLink and tooltip.RefreshDataNextUpdate then
        tooltip:RefreshDataNextUpdate()
    end
end

eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
eventFrame:SetScript("OnEvent", function(_, event, itemID, success)
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        refreshActiveTooltip()
    elseif waitingFor[itemID] then
        waitingFor[itemID] = nil
        if success then
            refreshActiveTooltip()
        end
    end
end)

tooltip:HookScript("OnHide", function()
    activeLink = nil
    wipe(waitingFor)
end)

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItemTooltip)
