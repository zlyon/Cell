local _, Cell = ...
---@type CellFuncs
local F = Cell.funcs
---@class CellUnitButtonFuncs
local I = Cell.iFuncs
local L = Cell.L

-------------------------------------------------
-- custom indicator
-------------------------------------------------
function I.GetDefaultCustomIndicatorTable(name, indicatorName, type, auraType)
    local t
    if type == "icon" then
        t = {
            ["name"] = name,
            ["indicatorName"] = indicatorName,
            ["type"] = type,
            ["enabled"] = true,
            ["position"] = {"TOPRIGHT", "button", "TOPRIGHT", 0, 3},
            ["frameLevel"] = 5,
            ["size"] = {13, 13},
            ["font"] = {
                {"Cell " .. _G.DEFAULT, 11, "Outline", false, "TOPRIGHT", 2, 1, {1, 1, 1}},
                {"Cell " .. _G.DEFAULT, 11, "Outline", false, "BOTTOMRIGHT", 2, -1, {1, 1, 1}},
            },
            ["showStack"] = true,
            ["showDuration"] = false,
            ["showAnimation"] = true,
            ["auraType"] = auraType,
            ["auras"] = {},
            ["glowOptions"] = {"None", {0.95, 0.95, 0.32, 1}}
        }
    elseif type == "text" then
        t = {
            ["name"] = name,
            ["indicatorName"] = indicatorName,
            ["type"] = type,
            ["enabled"] = true,
            ["position"] = {"TOPRIGHT", "button", "TOPRIGHT", 0, 3},
            ["frameLevel"] = 5,
            ["font"] = {"Cell " .. _G.DEFAULT, 12, "Outline", false},
            ["colors"] = {{0, 1, 0, 1}, {false, 0.5, {1, 1, 0, 1}}, {false, 3, {1, 0, 0, 1}}},
            ["auraType"] = auraType,
            ["auras"] = {},
            ["duration"] = {
                true, -- show duration
                false, -- round up duration
                0, -- decimal
            },
            ["stack"] = {
                true, -- show stack
                false, -- circled stack nums
            },
        }
    elseif type == "bar" then
        t = {
            ["name"] = name,
            ["indicatorName"] = indicatorName,
            ["type"] = type,
            ["enabled"] = true,
            ["position"] = {"BOTTOMRIGHT", "button", "TOPRIGHT", 0, -1},
            ["frameLevel"] = 5,
            ["size"] = {18, 4},
            ["colors"] = {{0, 1, 0, 1}, {false, 0.5, {1, 1, 0, 1}}, {false, 3, {1, 0, 0, 1}}, {0, 0, 0, 1}, {0.07, 0.07, 0.07, 0.9}},
            ["orientation"] = "horizontal",
            ["font"] = {
                {"Cell " .. _G.DEFAULT, 11, "Outline", false, "LEFT", 1, 0, {1, 1, 1}},
                {"Cell " .. _G.DEFAULT, 11, "Outline", false, "RIGHT", -1, 0, {1, 1, 1}},
            },
            ["showStack"] = false,
            ["showDuration"] = false,
            ["maxValue"] = {false, 10, true},
            ["auraType"] = auraType,
            ["auras"] = {},
            ["glowOptions"] = {"None", {0.95, 0.95, 0.32, 1}}
        }
    elseif type == "bars" then
        t = {
            ["name"] = name,
            ["indicatorName"] = indicatorName,
            ["type"] = type,
            ["enabled"] = true,
            ["position"] = {"TOPRIGHT", "button", "TOPRIGHT", 0, 0},
            ["frameLevel"] = 5,
            ["size"] = {18, 4},
            ["num"] = 3,
            ["numPerLine"] = 3,
            ["orientation"] = "top-to-bottom",
            ["spacing"] = {-1, -1},
            ["font"] = {
                {"Cell " .. _G.DEFAULT, 11, "Outline", false, "TOPRIGHT", 2, 1, {1, 1, 1}},
                {"Cell " .. _G.DEFAULT, 11, "Outline", false, "BOTTOMRIGHT", 2, -1, {1, 1, 1}},
            },
            ["showStack"] = false,
            ["showDuration"] = false,
            ["maxValue"] = {false, 10, true},
            ["auraType"] = auraType,
            ["auras"] = {},
            ["glowOptions"] = {"None", {0.95, 0.95, 0.32, 1}}
        }
    elseif type == "rect" then
        t = {
            ["name"] = name,
            ["indicatorName"] = indicatorName,
            ["type"] = type,
            ["enabled"] = true,
            ["position"] = {"TOPRIGHT", "button", "TOPRIGHT", 0, 2},
            ["frameLevel"] = 5,
            ["size"] = {11, 4},
            ["colors"] = {{0, 1, 0, 1}, {false, 0.5, {1, 1, 0, 1}}, {false, 3, {1, 0, 0, 1}}, {0, 0, 0, 1}},
            ["font"] = {
                {"Cell " .. _G.DEFAULT, 11, "Outline", false, "LEFT", 1, 0, {1, 1, 1}},
                {"Cell " .. _G.DEFAULT, 11, "Outline", false, "RIGHT", -1, 0, {1, 1, 1}},
            },
            ["showStack"] = false,
            ["showDuration"] = false,
            ["animationStyle"] = "none",
            ["auraType"] = auraType,
            ["auras"] = {},
            ["glowOptions"] = {"None", {0.95, 0.95, 0.32, 1}}
        }
    elseif type == "icons" then
        t = {
            ["name"] = name,
            ["indicatorName"] = indicatorName,
            ["type"] = type,
            ["enabled"] = true,
            ["position"] = {"TOPRIGHT", "button", "TOPRIGHT", 0, 3},
            ["frameLevel"] = 5,
            ["size"] = {13, 13},
            ["num"] = 5,
            ["numPerLine"] = 5,
            ["orientation"] = "right-to-left",
            ["spacing"] = {0, 0},
            ["font"] = {
                {"Cell " .. _G.DEFAULT, 11, "Outline", false, "TOPRIGHT", 2, 1, {1, 1, 1}},
                {"Cell " .. _G.DEFAULT, 11, "Outline", false, "BOTTOMRIGHT", 2, -1, {1, 1, 1}},
            },
            ["showStack"] = true,
            ["showDuration"] = false,
            ["showAnimation"] = true,
            ["auraType"] = auraType,
            ["auras"] = {},
            ["glowOptions"] = {"None", {0.95, 0.95, 0.32, 1}}
        }
    elseif type == "color" then
        t = {
            ["name"] = name,
            ["indicatorName"] = indicatorName,
            ["type"] = type,
            ["enabled"] = true,
            ["anchor"] = "healthbar-current",
            ["frameLevel"] = 1,
            ["colors"] = {"gradient-vertical", {1, 0, 0.4, 1}, {0, 0, 0, 1}, {0, 1, 0, 1}, {0.5, {1, 1, 0, 1}}, {3, {1, 0, 0, 1}}},
            ["auraType"] = auraType,
            ["auras"] = {},
        }
    elseif type == "texture" then
        t = {
            ["name"] = name,
            ["indicatorName"] = indicatorName,
            ["type"] = type,
            ["enabled"] = true,
            ["position"] = {"TOP", "button", "TOP", 0, 0},
            ["size"] = {16, 16},
            ["frameLevel"] = 10,
            ["texture"] = {"Interface\\AddOns\\Cell\\Media\\Shapes\\circle_blurred.tga", 0, {1, 1, 1, 1}},
            ["auraType"] = auraType,
            ["auras"] = {},
            ["fadeOut"] = true,
        }
    elseif type == "glow" then
        t = {
            ["name"] = name,
            ["indicatorName"] = indicatorName,
            ["type"] = type,
            ["enabled"] = true,
            ["frameLevel"] = 1,
            ["auraType"] = auraType,
            ["auras"] = {},
            ["glowOptions"] = {"Pixel", {0.95, 0.95, 0.32, 1}, 9, 0.25, 8, 2},
            ["fadeOut"] = true,
        }
    elseif type == "overlay" then
        t = {
            ["name"] = name,
            ["indicatorName"] = indicatorName,
            ["type"] = type,
            ["enabled"] = true,
            ["smooth"] = false,
            ["frameLevel"] = 1,
            ["colors"] = {{0, 0.61, 1, 0.55}, {false, 0.5, {1, 1, 0, 0.5}}, {false, 3, {1, 0, 0, 0.5}}},
            ["orientation"] = "horizontal",
            ["auraType"] = auraType,
            ["auras"] = {},
        }
    elseif type == "block" then
        t = {
            ["name"] = name,
            ["indicatorName"] = indicatorName,
            ["type"] = type,
            ["enabled"] = true,
            ["position"] = {"TOPRIGHT", "button", "TOPRIGHT", 0, 3},
            ["frameLevel"] = 5,
            ["size"] = {10, 10},
            ["colors"] = {"duration", {0, 1, 0, 1}, {false, 0.5, {1, 1, 0, 1}}, {false, 3, {1, 0, 0, 1}}, {0, 0, 0, 1}},
            ["font"] = {
                {"Cell " .. _G.DEFAULT, 11, "Outline", false, "TOPRIGHT", 2, 1, {1, 1, 1}},
                {"Cell " .. _G.DEFAULT, 11, "Outline", false, "BOTTOMRIGHT", 2, -1, {1, 1, 1}},
            },
            ["showStack"] = false,
            ["showDuration"] = false,
            ["animationStyle"] = "clock",
            ["auraType"] = auraType,
            ["auras"] = {},
            ["glowOptions"] = {"None", {0.95, 0.95, 0.32, 1}}
        }
    elseif type == "blocks" then
        t = {
            ["name"] = name,
            ["indicatorName"] = indicatorName,
            ["type"] = type,
            ["enabled"] = true,
            ["position"] = {"TOPRIGHT", "button", "TOPRIGHT", 0, 3},
            ["frameLevel"] = 5,
            ["size"] = {10, 10},
            ["num"] = 5,
            ["numPerLine"] = 5,
            ["orientation"] = "right-to-left",
            ["spacing"] = {-1, -1},
            ["font"] = {
                {"Cell " .. _G.DEFAULT, 11, "Outline", false, "TOPRIGHT", 2, 1, {1, 1, 1}},
                {"Cell " .. _G.DEFAULT, 11, "Outline", false, "BOTTOMRIGHT", 2, -1, {1, 1, 1}},
            },
            ["showStack"] = false,
            ["showDuration"] = false,
            ["animationStyle"] = "clock",
            ["auraType"] = auraType,
            ["auras"] = {},
            ["glowOptions"] = {"None", {0.95, 0.95, 0.32, 1}}
        }
    elseif type == "border" then
        t = {
            ["name"] = name,
            ["indicatorName"] = indicatorName,
            ["type"] = type,
            ["enabled"] = true,
            ["thickness"] = 2,
            ["frameLevel"] = 10,
            ["auraType"] = auraType,
            ["auras"] = {},
            ["fadeOut"] = true,
        }
    elseif type == "highlightDebuffs" then
        t = {
            ["name"] = name,
            ["indicatorName"] = indicatorName,
            ["type"] = type,
            ["enabled"] = true,
            ["position"] = {"CENTER", "button", "CENTER", 0, 3},
            ["frameLevel"] = 20,
            ["size"] = {22, 22},
            ["num"] = 3,
            ["showDuration"] = true,
            ["showStack"] = true,
            ["animationStyle"] = "clock",
            ["font"] = {
                {"Cell " .. _G.DEFAULT, 11, "Outline", false, "TOPRIGHT", 2, 1, {1, 1, 1}},
                {"Cell " .. _G.DEFAULT, 11, "Outline", false, "BOTTOMRIGHT", 2, -1, {1, 1, 1}},
            },
            ["orientation"] = "left-to-right",
            ["filterClasses"] = {["bossaura"] = true},
            ["auraType"] = "debuff",
            ["auras"] = {},
        }
        auraType = "debuff"
    end

    if auraType == "buff" then
        t["castBy"] = "me"
        if Cell.isRetail then
            t["trackByName"] = false
        else
            t["trackByName"] = true
        end
    else
        t["castBy"] = "anyone"
    end

    return t
end

-------------------------------------------------
-- weakened soul (Weakened Soul, debuff 6788)
-- Forever-only: retail removed this debuff in Dragonflight
-------------------------------------------------
function I.GetDefaultWeakenedSoulIndicator()
    return {
        ["name"] = L["Weakened Soul"],
        ["indicatorName"] = "indicator1",
        ["type"] = "block",
        ["enabled"] = false,
        ["position"] = {"BOTTOMRIGHT", "button", "BOTTOMRIGHT", 0, 3},
        ["frameLevel"] = 5,
        ["size"] = {10, 10},
        ["colors"] = {"duration", {1, 0, 0, 1}, {false, 0.5, {1, 1, 0, 1}}, {false, 3, {1, 0, 0, 1}}, {0, 0, 0, 1}},
        ["font"] = {
            {"Cell " .. _G.DEFAULT, 11, "Outline", false, "TOPRIGHT", 2, 1, {1, 1, 1}},
            {"Cell " .. _G.DEFAULT, 11, "Outline", false, "BOTTOMRIGHT", 2, -1, {1, 1, 1}},
        },
        ["showStack"] = false,
        ["showDuration"] = false,
        ["animationStyle"] = "clock",
        ["auraType"] = "debuff",
        ["auras"] = {6788},
        ["castBy"] = "anyone",
        ["glowOptions"] = {"None", {0.95, 0.95, 0.32, 1}},
    }
end

-------------------------------------------------
-- weakened soul: seed once per layout + revision sync
-------------------------------------------------
-- Rules:
--   * a layout is seeded ONCE and remembered; if the user deletes the entry afterwards it
--     is not put back on the next update -- deleting it is their call;
--   * a layout where the user built his own indicator tracking 6788 is left alone;
--   * if we later change the shipped definition, the change is applied to layouts that
--     still carry our entry only (see WS_REV below); the user's position and on/off state
--     are never touched.
-- `force` = manual /cell ws path: re-seeds layouts the user deleted. Returns seeded/updated.
function F.SeedWeakenedSoul(force)
    local WS_REV = 2

    local wsdb = CellDB["weakenedSoulSeed"]
    if type(wsdb) ~= "table" then
        wsdb = {}
        CellDB["weakenedSoulSeed"] = wsdb
    end
    if type(wsdb["seeded"]) ~= "table" then wsdb["seeded"] = {} end
    if type(wsdb["rev"]) ~= "number" then wsdb["rev"] = 1 end

    -- 9.9.10 shape: a single global flag, no per-layout record. Everything that existed back
    -- then had been seeded, so treat the layouts present now as already seeded once.
    if CellDB["addedWeakenedSoulIndicator"] and not wsdb["legacyMigrated"] then
        for layoutName in pairs(CellDB["layouts"]) do
            wsdb["seeded"][layoutName] = true
        end
        wsdb["legacyMigrated"] = true
    end

    local function TracksWS(ind)
        if type(ind["auras"]) ~= "table" then return false end
        for _, id in pairs(ind["auras"]) do
            if id == 6788 then return true end
        end
        return false
    end

    -- Our block is recognised by what it holds, not by its key: the key is a plain
    -- "indicatorN" slot shared with user-created indicators, so matching on it would mistake
    -- a user's own indicator for ours.
    local function IsOurWSBlock(ind)
        if ind["type"] ~= "block" or not TracksWS(ind) then return false end
        return ind["name"] == L["Weakened Soul"] or ind["name"] == "灵魂虚弱"
    end

    local seeded, updated = 0, 0
    for layoutName, layout in pairs(CellDB["layouts"]) do
        local indicators = layout["indicators"]
        if type(indicators) == "table" and #indicators > 0 then
            local ours, userHas = nil, false
            for _, ind in ipairs(indicators) do
                if IsOurWSBlock(ind) then
                    ours = ours or ind
                elseif TracksWS(ind) then
                    userHas = true
                end
            end

            if ours then
                wsdb["seeded"][layoutName] = true
                -- rev 2 is only the zhCN name fix ("灵魂虚弱" -> "虚弱灵魂"), kept
                -- idempotent so an old profile gets corrected without anything else moving
                if (tonumber(ours["_wsRev"]) or 1) < WS_REV then
                    ours["name"] = L["Weakened Soul"]
                    ours["_wsRev"] = WS_REV
                    updated = updated + 1
                end
            elseif userHas then
                -- configured by the user himself: hands off, but never seed on top of it
                wsdb["seeded"][layoutName] = true
            elseif force or not wsdb["seeded"][layoutName] then
                local t = I.GetDefaultWeakenedSoulIndicator()
                t["_wsRev"] = WS_REV
                tinsert(indicators, t)
                wsdb["seeded"][layoutName] = true
                seeded = seeded + 1
            end
        end
    end

    wsdb["rev"] = WS_REV
    return seeded, updated
end

-------------------------------------------------
-- dispels: custom debuff type color
-------------------------------------------------
function I.GetDebuffTypeColor(debuffType)
    if issecretvalue and issecretvalue(debuffType) then return 0, 0, 0 end
    if debuffType and CellDB["debuffTypeColor"][debuffType] then
        return CellDB["debuffTypeColor"][debuffType]["r"], CellDB["debuffTypeColor"][debuffType]["g"],
            CellDB["debuffTypeColor"][debuffType]["b"]
    else
        return 0, 0, 0
    end
end

function I.SetDebuffTypeColor(debuffType, r, g, b)
    if debuffType and CellDB["debuffTypeColor"][debuffType] then
        CellDB["debuffTypeColor"][debuffType]["r"] = r
        CellDB["debuffTypeColor"][debuffType]["g"] = g
        CellDB["debuffTypeColor"][debuffType]["b"] = b
    end
end

-- with the standard Blizzard debuff type colors
local CellDebuffTypeColorFallback = {
    ["none"]    = {r = 0.80, g = 0.00, b = 0.00},
    ["Magic"]   = {r = 0.20, g = 0.60, b = 1.00},
    ["Curse"]   = {r = 0.60, g = 0.00, b = 1.00},
    ["Disease"] = {r = 0.60, g = 0.40, b = 0.00},
    ["Poison"]  = {r = 0.00, g = 0.60, b = 0.00},
    [""]        = {r = 0.80, g = 0.00, b = 0.00},
}

function I.ResetDebuffTypeColor()
    -- copy from WoW global if available, otherwise use local fallback
    local source = DebuffTypeColor or CellDebuffTypeColorFallback
    CellDB["debuffTypeColor"] = F.Copy(source)
    -- add Bleed
    CellDB["debuffTypeColor"]["Bleed"] = {r = 1, g = 0.2, b = 0.6}
    -- add cleu
    -- CellDB["debuffTypeColor"].cleu = {r=0, g=1, b=1}
end