local _, Cell = ...

-------------------------------------------------
-- URF Forever -> Cell click-casting migration
-------------------------------------------------
-- The Chinese URF Forever release used to ship under the same addon folder (Cell), so its
-- saved variables file is the very same Cell.lua -- but the variable inside was URFDB. This
-- build only declared CellDB, which meant the first save after upgrading wiped the old data.
-- Cell.toc therefore declares URFDB as well, and this module copies the click-casting bindings
-- (URF "bindingSets") over to Cell's "clickCastings" once, on the first login.
--
-- Rules:
--   * only fills in what the player does not already have in Cell -- never overwrites a binding
--   * URF rules that Cell cannot express (macro text, target conditions, stop/stopTargeting)
--     are skipped instead of being turned into something else
--   * nothing is written when URFDB is not loaded, so a later login can still pick it up

local VERSION = 2
local MODIFIER_ORDER = { "alt", "ctrl", "shift", "meta" }

-- URF action -> Cell general action. Everything else is either handled below or unsupported.
local GENERAL_ACTIONS = {
    target = "target",
    togglemenu = "togglemenu",
    menuOOC = "togglemenu_nocombat",
    focus = "focus",
    assist = "assist",
}

local function NormalizedModifiers(value)
    if type(value) ~= "string" or value == "" then return "" end
    local seen = {}
    for modifier in value:gmatch("[^%-]+") do
        seen[modifier:lower()] = true
    end
    local ordered = {}
    for _, modifier in ipairs(MODIFIER_ORDER) do
        if seen[modifier] then ordered[#ordered + 1] = modifier end
    end
    return table.concat(ordered, "-")
end

-- URF stores a rule as {button = "2", modifiers = "shift"} or {key = "R", modifiers = "alt"}.
-- Cell stores the attribute key itself: "shift-type2", "type-shiftR", "ctrl-type-SCROLLUP".
local function BuildBindKey(rule)
    local modifiers = NormalizedModifiers(rule.modifiers)
    local key = rule.key
    if type(key) == "string" and key ~= "" then
        if key == "MOUSEWHEELUP" then
            return modifiers ~= "" and (modifiers .. "-type-SCROLLUP") or "type-SCROLLUP"
        elseif key == "MOUSEWHEELDOWN" then
            return modifiers ~= "" and (modifiers .. "-type-SCROLLDOWN") or "type-SCROLLDOWN"
        end
        local plain = modifiers ~= "" and (modifiers:gsub("%-", "") .. key) or key
        return "type-" .. plain
    end
    local button = tonumber(rule.button)
    if not button or button < 1 or button > 31 or button % 1 ~= 0 then return nil end
    if modifiers ~= "" then return modifiers .. "-type" .. button end
    return "type" .. button
end

local function ConvertRule(rule)
    if type(rule) ~= "table" then return nil end
    local bindKey = BuildBindKey(rule)
    if not bindKey then return nil end
    -- Cell has no per-binding target condition; keep only rules that work on any target.
    local reaction = rule.reaction
    if reaction and reaction ~= "any" then return nil end

    local action = rule.action
    if action == "spell" then
        local value = tonumber(rule.value)
        if not value then return nil end
        local rank = tonumber(rule.rank)
        if rank and rank > 0 then value = tostring(value) .. ":" .. rank end
        return { bindKey, "spell", value }
    elseif action == "item" then
        local value = tonumber(rule.value)
        if not value then return nil end
        return { bindKey, "item", value }
    end
    local general = GENERAL_ACTIONS[action]
    if general then return { bindKey, general } end
    return nil
end

-- URF keeps common bindings plus one list per specialization. The three classic trees are one
-- pseudo-spec there, so everything is folded into a single keyed list (later entries win, which
-- is the same way URF resolves them).
local function CollectRules(collection)
    local ordered, index = {}, {}

    local function add(list)
        if type(list) ~= "table" then return end
        for _, rule in ipairs(list) do
            local converted = ConvertRule(rule)
            if converted then
                local key = converted[1]
                if index[key] then
                    ordered[index[key]] = converted
                else
                    index[key] = #ordered + 1
                    ordered[#ordered + 1] = converted
                end
            end
        end
    end

    add(collection.common)
    if type(collection.specs) == "table" then
        local specIDs = {}
        for specID in pairs(collection.specs) do specIDs[#specIDs + 1] = specID end
        table.sort(specIDs, function(a, b) return tostring(a) < tostring(b) end)
        for _, specID in ipairs(specIDs) do add(collection.specs[specID]) end
    end

    return ordered
end

-- Append the rules the list does not have yet; returns how many were added.
local function MergeRules(list, rules)
    local existing = {}
    for _, rule in ipairs(list) do existing[rule[1]] = true end
    local added = 0
    for _, rule in ipairs(rules) do
        if not existing[rule[1]] then
            existing[rule[1]] = true
            list[#list + 1] = rule
            added = added + 1
        end
    end
    return added
end

-- A rule is a 2- or 3-element array, so a shallow copy per element is enough.
local function CopyRules(rules)
    local copy = {}
    for i, rule in ipairs(rules) do
        copy[i] = { rule[1], rule[2], rule[3] }
    end
    return copy
end

-- Spec IDs this build derives for a class (retail IDs used as stable keys).
local function SpecIDsFor(class)
    local fn = Cell.funcs and Cell.funcs.GetSpecListForClass
    local specs = fn and fn(class)
    local ids = {}
    if type(specs) == "table" then
        for _, spec in ipairs(specs) do
            if type(spec) == "table" and type(spec[1]) == "number" then
                ids[#ids + 1] = spec[1]
            end
        end
    end
    return ids
end

local function FindURFBindingSets()
    local profiles = URFDB and URFDB.profiles
    local profile
    if type(profiles) == "table" then
        profile = profiles[URFDB.active or "Default"]
        if not (type(profile) == "table" and type(profile.bindingSets) == "table") then
            for _, candidate in pairs(profiles) do
                if type(candidate) == "table" and type(candidate.bindingSets) == "table" then
                    profile = candidate
                    break
                end
            end
        end
    end
    if type(profile) == "table" and type(profile.bindingSets) == "table" then
        return profile.bindingSets
    end
    return URFDB and URFDB.bindingSets
end

local function AddonLoaded(name)
    local api = C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
    if not api then return false end
    local ok, loaded = pcall(api, name)
    return ok and loaded
end

local function Migrate()
    if type(CellDB) ~= "table" then return end
    local mark = CellDB.urfMigration
    if type(mark) == "table" and type(mark.version) == "number" and mark.version >= VERSION then
        return
    end

    local sets = FindURFBindingSets()
    if type(sets) ~= "table" then return end -- URFDB not loaded (old addon gone) -- try again next login

    local clickCastings = CellDB.clickCastings
    if type(clickCastings) ~= "table" then
        clickCastings = {}
        CellDB.clickCastings = clickCastings
    end

    local added, classes = 0, 0
    for class, collection in pairs(sets) do
        if type(class) == "string" and type(collection) == "table" then
            local rules = CollectRules(collection)
            if #rules > 0 then
                local target = clickCastings[class]
                if type(target) ~= "table" then
                    target = {
                        common = {},
                        useCommon = true,
                        alwaysTargeting = { common = "disabled" },
                        smartResurrection = collection.smartResurrection or "disabled",
                    }
                    clickCastings[class] = target
                end

                -- URF only ever had the client's single pseudo-spec (1486/1484/...), and the old
                -- saved file still carries a bucket under that number. This build never reads it,
                -- so every class gets its bindings written to "common" plus a bucket per spec the
                -- build derives -- otherwise "use a profile per spec" would show an empty list.
                if type(target.common) ~= "table" then target.common = {} end
                if type(target.alwaysTargeting) ~= "table" then
                    target.alwaysTargeting = { common = "disabled" }
                end

                -- "added" only counts what common did not have yet -- the per-spec buckets below
                -- are copies of it, so counting them too would quadruple the number in chat.
                local newKeys = MergeRules(target.common, rules)
                local specIDs = SpecIDsFor(class)
                if #specIDs == 0 then
                    -- Unknown class token: fall back to whatever numeric buckets already exist.
                    for key, value in pairs(target) do
                        if type(key) == "number" and type(value) == "table" then
                            MergeRules(value, rules)
                        end
                    end
                else
                    for _, specID in ipairs(specIDs) do
                        local list = target[specID]
                        if type(list) ~= "table" then
                            target[specID] = CopyRules(target.common)
                        else
                            MergeRules(list, rules)
                        end
                        if target.alwaysTargeting[specID] == nil then
                            target.alwaysTargeting[specID] = "disabled"
                        end
                    end
                end
                added = added + newKeys
                classes = classes + 1
                if target.smartResurrection == nil then
                    target.smartResurrection = collection.smartResurrection or "disabled"
                end
            end
        end
    end

    CellDB.urfMigration = CellDB.urfMigration or {}
    CellDB.urfMigration.version = VERSION
    CellDB.urfMigration.clickCastings = classes > 0 and "imported" or "empty"
    CellDB.urfMigration.bindings = added
    CellDB.urfMigration.at = date("%Y-%m-%d %H:%M:%S")

    if classes > 0 then
        if added > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Cell|r 已从 URF Forever 迁移点击施法绑定：新增 " .. added
                .. " 条（检查了 " .. classes .. " 个职业）。")
            if Cell.Fire then pcall(Cell.Fire, "UpdateClickCastings") end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Cell|r 已核对 URF Forever 的 " .. classes
                .. " 个职业点击施法：Cell 里现有的绑定已经一致，无需改动。")
        end
    end

    if AddonLoaded("URFForever") then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Cell|r 检测到旧的 URF Forever 仍在启用：两套框体会重复显示，请在插件列表中禁用或删除它（配置已经迁移，不会丢）。")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    -- Wait for Cell's own defaults and per-class click-casting tables to be built first.
    C_Timer.After(6, function()
        local ok, err = pcall(Migrate)
        if not ok then
            -- Never leave the player with a silent failure: this is the only place that knows
            -- whether the old bindings came across.
            DEFAULT_CHAT_FRAME:AddMessage("|cffff7777Cell URF 迁移出错：|r" .. tostring(err))
        end
    end)
end)

-------------------------------------------------
-- /cellmig -- print what the migration can see (support aid)
-------------------------------------------------
local function PrintState()
    local function out(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        local line = table.concat(parts, " ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Cell|r " .. line)
        -- Also on screen: chat tabs are easy to miss (EllesmereUI keeps several).
        if UIErrorsFrame then UIErrorsFrame:AddMessage(line, 1, 1, 0.4, 8) end
    end

    out("URFDB =", type(URFDB))
    if type(URFDB) == "table" then
        local profiles = 0
        if type(URFDB.profiles) == "table" then
            for _ in pairs(URFDB.profiles) do profiles = profiles + 1 end
        end
        out("active =", tostring(URFDB.active), "profiles =", profiles)
        local classes = {}
        local sets = FindURFBindingSets()
        if type(sets) == "table" then
            for class in pairs(sets) do classes[#classes + 1] = tostring(class) end
        end
        out("bindingSets =", #classes > 0 and table.concat(classes, "/") or "none")
    end

    local mark = CellDB and CellDB.urfMigration
    out("marker =", mark and tostring(mark.version) or "nil",
        "bindings =", mark and tostring(mark.bindings) or "-",
        "state =", mark and tostring(mark.clickCastings) or "-")

    local class = Cell.vars and Cell.vars.playerClass
    local castings = class and CellDB and CellDB.clickCastings and CellDB.clickCastings[class]
    if type(castings) == "table" then
        out(class, "common =", #(castings.common or {}))
        for _, specID in ipairs(SpecIDsFor(class)) do
            local list = castings[specID]
            out(" spec", specID, "=", type(list) == "table" and #list or "nil")
        end
    else
        out("clickCastings 空")
    end
end

SLASH_CELLMIG1 = "/cellmig"
SlashCmdList["CELLMIG"] = function()
    local ok, err = pcall(PrintState)
    if not ok then DEFAULT_CHAT_FRAME:AddMessage("|cffff7777/cellmig: |r" .. tostring(err)) end
end
