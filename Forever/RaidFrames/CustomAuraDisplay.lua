local _, Cell = ...
local F = Cell.funcs
local I = Cell.iFuncs

local INIT_VERSION = 35
local BUILD = select(4, GetBuildInfo())
-- Forever reports a low build number but has the AuraContainer API (verified in-game), same engine display as Retail 12.1.
local SUPPORTED = (Cell.isRetail and BUILD >= 120100) or Cell.isForever == true

local SUPPORTED_TYPES = {
    icon = true, icons = true, color = true, border = true,
    text = true, bar = true, bars = true, rect = true,
    texture = true, overlay = true, block = true, blocks = true,
    glow = true,
}

local HARD_EXCLUDE_SPELLS = {
    [225788] = true,
    [186404] = true,
}

local stateByButton = setmetatable({}, { __mode = "k" })
local cachedConfigs
local featureReady
local buildQueue = {}
local buildQueued = setmetatable({}, { __mode = "k" })
local buildTicker

local function EnsureAuraContainerLoaded()
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
end

local function ProbeSupported()
    if featureReady ~= nil then return featureReady end
    if not SUPPORTED then
        featureReady = false
        return false
    end
    EnsureAuraContainerLoaded()
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    if not ok or not container then
        featureReady = false
        return false
    end
    pcall(function()
        container:Hide()
        container:SetParent(UIParent)
        container:SetAlpha(0)
    end)
    featureReady = type(container.AddAuraGroup) == "function"
        and type(container.SetUnit) == "function"
        and type(container.SetEnabled) == "function"
    return featureReady
end

local function IsOverlayType(cfgType)
    return cfgType == "color" or cfgType == "border" or cfgType == "overlay" or cfgType == "glow"
end

local function IsSingleSlot(cfgType)
    return cfgType ~= "icons" and cfgType ~= "bars" and cfgType ~= "blocks"
end

local function GetElementSize(cfg)
    if IsOverlayType(cfg.type) then
        return 1, 1
    end
    if cfg.type == "text" then
        local s = (type(cfg.font) == "table" and cfg.font[2]) or 12
        return s, s
    end
    local w = (cfg.size and cfg.size[1]) or 13
    local h = (cfg.size and cfg.size[2]) or w
    return w, h
end

local function AuraEntrySpellId(k, v)
    if type(v) == "table" then
        local n = tonumber(v[1])
        if n and n > 0 then return n end
        return
    end
    local n = tonumber(v)
    if n and n > 0 then return n end
    n = tonumber(k)
    if n and n > 0 then return n end
end

local function IsSupportedCustomCfg(t)
    if not (t and t.enabled) then return false end
    if t.auraType ~= "buff" and t.auraType ~= "debuff" then return false end
    if t.name == "Healers" then return false end
    if not SUPPORTED_TYPES[t.type] then return false end
    if type(t.indicatorName) ~= "string" or not t.indicatorName:find("^indicator") then return false end
    if type(t.auras) ~= "table" then return false end
    local hasSpell = false
    for k, v in pairs(t.auras) do
        if AuraEntrySpellId(k, v) then
            hasSpell = true
            break
        end
    end
    return hasSpell
end

local function RefreshCachedConfigs()
    local list = {}
    local layout = Cell.vars.currentLayoutTable
    if layout and layout.indicators then
        for _, t in ipairs(layout.indicators) do
            if IsSupportedCustomCfg(t) then
                list[#list + 1] = t
            end
        end
    end
    cachedConfigs = list
    return list
end

local function BuildSpellMap(auras)
    local map = {}
    if type(auras) ~= "table" then return map end
    for k, v in pairs(auras) do
        local n = AuraEntrySpellId(k, v)
        if n then
            map[n] = true
            -- Forever: also match the other known ranks of this spell (each rank has its own ID)
            if F.GetSameNameSpellIDs then
                for _, id in ipairs(F.GetSameNameSpellIDs(n)) do map[id] = true end
            end
        end
    end
    local alts = Cell.AuraBlacklist and Cell.AuraBlacklist.AlternateSpellIDs
    if type(alts) == "table" then
        for altId, primaryId in pairs(alts) do
            if map[primaryId] then
                map[altId] = true
            elseif map[altId] then
                map[primaryId] = true
            end
        end
    end
    return map
end

local function SpellMapCount(map)
    local n = 0
    for _ in pairs(map) do n = n + 1 end
    return n
end

local function BuildExcludeSpellMap()
    local map = {}
    for id in pairs(HARD_EXCLUDE_SPELLS) do
        map[id] = true
    end

    local function addId(id)
        id = tonumber(id)
        if id and id > 0 then
            map[id] = true
        end
    end

    local function addAuraBlacklistTable(tbl)
        if type(tbl) ~= "table" then return end
        for spellId, entry in pairs(tbl) do
            if type(spellId) == "number" then
                if entry == true then
                    addId(spellId)
                elseif type(entry) == "table" and (entry.combat or entry.ooc) then
                    addId(spellId)
                end
            elseif type(entry) == "number" then
                addId(entry)
            end
        end
    end

    if CellDB and CellDB["auraBlacklist"] then
        addAuraBlacklistTable(CellDB["auraBlacklist"]["buffs"])
        addAuraBlacklistTable(CellDB["auraBlacklist"]["HELPFUL"])
    end

    local alts = Cell.AuraBlacklist and Cell.AuraBlacklist.AlternateSpellIDs
    if type(alts) == "table" then
        for altId, primaryId in pairs(alts) do
            if map[primaryId] then
                addId(altId)
            elseif map[altId] then
                addId(primaryId)
            end
        end
    end

    return map
end

local function BuildFilter(castBy, auraType)
    local base = (auraType == "debuff") and "HARMFUL" or "HELPFUL"
    if castBy == "anyone" or castBy == "others" then
        return base
    end
    return base .. "|PLAYER"
end

local function ResolveUnit(unitButton)
    local unit = F.BD(unitButton).states and (F.BD(unitButton).states.displayedUnit or F.BD(unitButton).states.unit)
    if type(unit) == "string" and unit ~= "" then
        return unit
    end
    local attr = unitButton.GetAttribute and unitButton:GetAttribute("unit")
    if type(attr) == "string" and attr ~= "" then
        return attr
    end
end

local function StyleFont(fs, fontCfg, defaultSize)
    local font, size, outline, shadow
    if type(fontCfg) == "table" then
        font, size, outline, shadow = fontCfg[1], fontCfg[2], fontCfg[3], fontCfg[4]
    end
    size = size or defaultSize or 11
    local flags = "OUTLINE"
    if outline == "None" or outline == "" then
        flags = ""
    elseif outline == "Monochrome Outline" then
        flags = "OUTLINE,MONOCHROME"
    elseif outline == "Monochrome" then
        flags = "MONOCHROME"
    end
    local path = GameFontNormal:GetFont()
    if font and F.GetFont then
        local ok, resolved = pcall(F.GetFont, font)
        if ok and type(resolved) == "string" and resolved ~= "" then
            path = resolved
        end
    end
    if not pcall(fs.SetFont, fs, path, size, flags) then
        pcall(fs.SetFontObject, fs, GameFontNormalSmall)
    end
    if shadow then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
    else
        fs:SetShadowOffset(0, 0)
    end
    fs:SetTextColor(1, 1, 1, 1)
end

local function GetCellDurationFormatter()
    return F.GetAuraDurationFormatter and F.GetAuraDurationFormatter() or nil
end

local function ShouldShowDuration(cfg)
    local v = cfg and cfg.showDuration
    if v == false or v == nil or v == 0 then
        return false
    end
    return true
end

local function UnpackColor(c, fallback)
    fallback = fallback or { 0, 1, 0, 1 }
    if type(c) ~= "table" then
        return fallback[1], fallback[2], fallback[3], fallback[4] or 1
    end
    return c[1] or fallback[1], c[2] or fallback[2], c[3] or fallback[3], c[4] or fallback[4] or 1
end

local function GetCfgColor(cfg, fallback)
    local colors = cfg and cfg.colors
    if type(colors) ~= "table" then
        return UnpackColor(nil, fallback)
    end
    if type(colors[1]) == "table" then
        return UnpackColor(colors[1], fallback)
    end
    if type(colors[1]) == "string" and type(colors[2]) == "table" then
        return UnpackColor(colors[2], fallback)
    end
    return UnpackColor(nil, fallback)
end

local function GetSpellTexture(spellId)
    if C_Spell and C_Spell.GetSpellTexture then
        local tex = C_Spell.GetSpellTexture(spellId)
        if tex then return tex end
    end
    local _, icon = F.GetSpellInfo(spellId)
    return icon
end

local function AddTextureColorKey(map, key, color)
    if key == nil or key == "" then return end
    map[key] = color
    if type(key) ~= "string" then
        map[tostring(key)] = color
    end
end

local function BuildTextureColorMap(auras)
    local map, first = {}, nil
    if type(auras) ~= "table" then return map, first end
    for k, v in pairs(auras) do
        local id, color
        if type(v) == "table" then
            id = tonumber(v[1])
            if type(v[2]) == "table" then color = v[2] end
        else
            id = AuraEntrySpellId(k, v)
        end
        if id and color then
            first = first or color
            AddTextureColorKey(map, GetSpellTexture(id), color)
            local _, icon = F.GetSpellInfo(id)
            AddTextureColorKey(map, icon, color)
            if C_Spell and C_Spell.GetSpellInfo then
                local info = C_Spell.GetSpellInfo(id)
                if type(info) == "table" then
                    AddTextureColorKey(map, info.iconID, color)
                    AddTextureColorKey(map, info.originalIconID, color)
                end
            end
        end
    end
    return map, first
end

local function ResolveIconTexture(button, fallback)
    if button and button.GetIcon then
        local ok, tex = pcall(button.GetIcon, button)
        if ok and tex then return tex end
    end
    return fallback
end

-- Re-init can run again on an already-hooked (pooled/reused) icon or button -- hooksecurefunc has
-- no "unhook", so a naive re-call would stack a new hook on top of the old one every time, each
-- carrying its own stale texMap/apply closure, all firing on every future update. Hook exactly
-- once per object and just repoint its state to the latest texMap/apply on every call instead.
local function HookIconColor(icon, texMap, firstColor, apply, button)
    if not apply then return end

    if icon then
        icon._cellColorState = icon._cellColorState or {}
        local state = icon._cellColorState
        state.texMap, state.firstColor, state.apply = texMap, firstColor, apply
        if not icon._cellColorHooked then
            icon._cellColorHooked = true
            local function onTex(_, tex)
                local s = icon._cellColorState
                if not s then return end
                s.apply((s.texMap and tex and s.texMap[tex]) or (s.texMap and tex and s.texMap[tostring(tex)]) or s.firstColor)
            end
            hooksecurefunc(icon, "SetTexture", onTex)
            if icon.SetAtlas then
                hooksecurefunc(icon, "SetAtlas", onTex)
            end
        end
    end

    -- Belt and braces: some AuraButton templates update their icon by calling SetIcon(button, ...)
    -- again per aura rather than mutating the texture object we handed it, which the hooks above
    -- would never see. Catch that case too by hooking the button's own SetIcon directly.
    if button and button.SetIcon then
        button._cellColorState2 = button._cellColorState2 or {}
        local state2 = button._cellColorState2
        state2.texMap, state2.firstColor, state2.apply = texMap, firstColor, apply
        if not button._cellColorHooked then
            button._cellColorHooked = true
            hooksecurefunc(button, "SetIcon", function(_, iconValue)
                local s = button._cellColorState2
                if not s then return end
                local tex = iconValue
                if type(tex) == "table" and tex.GetTexture then
                    tex = tex:GetTexture()
                end
                s.apply((s.texMap and tex and s.texMap[tex]) or (s.texMap and tex and s.texMap[tostring(tex)]) or s.firstColor)
            end)
        end
    end
end

local function AttachHiddenIcon(button)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetAlpha(0)
    pcall(button.SetIcon, button, icon)
    return icon
end

local function ResolveBarOrientation(orientation)
    if orientation == "horizontal" or orientation == nil then
        return "left-to-right"
    end
    if orientation == "vertical" then
        return "top-to-bottom"
    end
    return orientation
end

local function DurationBarOpts(remaining)
    local barOpts = {}
    local dirEnum = Enum and Enum.StatusBarTimerDirection
    if dirEnum then
        if remaining ~= false and dirEnum.RemainingTime then
            barOpts.direction = dirEnum.RemainingTime
        elseif dirEnum.ElapsedTime then
            barOpts.direction = dirEnum.ElapsedTime
        end
    end
    if Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate then
        barOpts.interpolation = Enum.StatusBarInterpolation.Immediate
    end
    return barOpts
end

local function AttachDurationBar(button, orientation, r, g, b, a, bgr, bgg, bgb, bga)
    orientation = ResolveBarOrientation(orientation)
    local bar = CreateFrame("StatusBar", nil, button)
    bar:SetAllPoints(button)
    bar:EnableMouse(false)
    if orientation == "vertical" or orientation == "top-to-bottom" or orientation == "bottom-to-top" then
        bar:SetOrientation("VERTICAL")
        -- SetOrientation alone only changes which edge grows -- without this, the fill texture
        -- stays oriented for a horizontal bar and a vertical one renders wrong/invisible.
        if bar.SetRotatesTexture then
            bar:SetRotatesTexture(true)
        end
    else
        bar:SetOrientation("HORIZONTAL")
        if bar.SetRotatesTexture then
            bar:SetRotatesTexture(false)
        end
    end
    -- matches the legacy preview bar's convention (Indicators/Base.lua, bar:SetOrientation) --
    -- this used to be the inverted condition, which made every direction (and the settings-panel
    -- preview, which uses that legacy bar) run backwards from what was selected.
    bar:SetReverseFill(orientation == "right-to-left" or orientation == "bottom-to-top")
    bar:SetStatusBarTexture(Cell.vars.whiteTexture or Cell.vars.texture)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(bgr or 0.07, bgg or 0.07, bgb or 0.07, bga or 0.9)
    bar:SetStatusBarColor(r or 0, g or 1, b or 0, a or 1)
    pcall(button.SetDurationBar, button, bar, DurationBarOpts(true))
    return bar
end

local function AttachStackAndDuration(button, cfg, host, animFrame, skipDurationBind)
    host = host or button
    local textHost = CreateFrame("Frame", nil, host)
    textHost:SetAllPoints(host)
    textHost:EnableMouse(false)
    local baseLevel = (animFrame and animFrame.GetFrameLevel and animFrame:GetFrameLevel())
        or (button.GetFrameLevel and button:GetFrameLevel())
        or 1
    textHost:SetFrameLevel(baseLevel + 10)

    if cfg.showStack ~= false then
        local stack = textHost:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        local fontCfg = cfg.font and cfg.font[1]
        local point = (type(fontCfg) == "table" and fontCfg[5]) or "TOPRIGHT"
        local ox = (type(fontCfg) == "table" and fontCfg[6]) or 2
        local oy = (type(fontCfg) == "table" and fontCfg[7]) or 1
        stack:ClearAllPoints()
        stack:SetPoint(point, textHost, point, ox, oy)
        stack:SetJustifyH("RIGHT")
        StyleFont(stack, fontCfg, 11)
        if type(fontCfg) == "table" and type(fontCfg[8]) == "table" then
            stack:SetTextColor(fontCfg[8][1] or 1, fontCfg[8][2] or 1, fontCfg[8][3] or 1, fontCfg[8][4] or 1)
        else
            stack:SetTextColor(1, 1, 1, 1)
        end
        button._cellStackFS = stack
        pcall(button.SetApplicationCount, button, stack, {})
    else
        local stack = textHost:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        stack:Hide()
        button._cellStackFS = stack
        pcall(button.SetApplicationCount, button, stack, {})
    end

    local showDuration = ShouldShowDuration(cfg)
    if not showDuration and cfg.duration and cfg.duration[1] then
        showDuration = true
    end
    if showDuration then
        local duration = textHost:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        local fontCfg = (cfg.font and cfg.font[2]) or cfg.font
        local point = (type(fontCfg) == "table" and fontCfg[5]) or "BOTTOMRIGHT"
        local ox = (type(fontCfg) == "table" and fontCfg[6]) or 2
        local oy = (type(fontCfg) == "table" and fontCfg[7]) or -1
        duration:ClearAllPoints()
        duration:SetPoint(point, textHost, point, ox, oy)
        duration:SetJustifyH("RIGHT")
        StyleFont(duration, fontCfg, 11)
        if type(fontCfg) == "table" and type(fontCfg[8]) == "table" then
            duration:SetTextColor(fontCfg[8][1] or 1, fontCfg[8][2] or 1, fontCfg[8][3] or 1, fontCfg[8][4] or 1)
        else
            duration:SetTextColor(1, 1, 1, 1)
        end
        button._cellDurationFS = duration
        if not skipDurationBind then
            F.BindAuraDurationText(button, duration, GetCellDurationFormatter(), cfg.auras)
        end
    end
    return textHost
end


local function ResolveAnimationStyle(cfg)
    if type(cfg) == "table" and type(cfg.animationStyle) == "string" then
        local s = cfg.animationStyle
        if s == "none" or s == "vertical" or s == "clock" then
            return s
        end
    end
    if type(cfg) == "table" and cfg.showAnimation == false then
        return "none"
    end
    if type(cfg) == "table" and cfg.type == "rect" then
        return "none"
    end
    return "clock"
end

local function AttachInvisibleCooldown(button)
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:EnableMouse(false)
    cooldown:SetHideCountdownNumbers(true)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetSwipeColor(0, 0, 0, 0)
    pcall(button.SetDurationCooldown, button, cooldown)
    return cooldown
end

local function AttachDurationAnimation(button, cfg)
    local style = ResolveAnimationStyle(cfg)
    if style == "none" then
        return AttachInvisibleCooldown(button)
    elseif style == "vertical" and type(button.SetDurationBar) == "function" then
        local bar = CreateFrame("StatusBar", nil, button)
        bar:SetAllPoints(button)
        bar:EnableMouse(false)
        bar:SetOrientation("VERTICAL")
        bar:SetReverseFill(true)
        bar:SetStatusBarTexture(Cell.vars.whiteTexture)
        local barTex = bar:GetStatusBarTexture()
        if barTex then
            barTex:SetVertexColor(0, 0, 0, 0.77)
        end
        pcall(button.SetDurationBar, button, bar, DurationBarOpts(false))
        return bar
    end

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:EnableMouse(false)
    cooldown:SetHideCountdownNumbers(true)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetReverse(true)
    if Cell.vars and Cell.vars.whiteTexture then
        cooldown:SetSwipeTexture(Cell.vars.whiteTexture)
        cooldown:SetSwipeColor(0, 0, 0, 0.77)
    end
    pcall(button.SetDurationCooldown, button, cooldown)
    return cooldown
end

local function AnchorColorOverlay(tex, unitButton, cfg)
    local anchor = (cfg and cfg.anchor) or "healthbar-current"
    local w = F.BD(unitButton).widgets
    tex:ClearAllPoints()
    if anchor == "healthbar-current" and w and w.healthBar then
        tex:SetAllPoints(w.healthBar:GetStatusBarTexture())
    elseif anchor == "healthbar-loss" and w and w.healthBarLoss then
        tex:SetAllPoints(w.healthBarLoss)
    elseif anchor == "healthbar-entire" and w and w.healthBar then
        tex:SetAllPoints(w.healthBar)
    else
        local inset = CELL_BORDER_SIZE or 1
        tex:SetPoint("TOPLEFT", unitButton, "TOPLEFT", inset, -inset)
        tex:SetPoint("BOTTOMRIGHT", unitButton, "BOTTOMRIGHT", -inset, inset)
    end
end

local function ApplyColorOverlay(solidTex, gradientTex, cfg, unitButton)
    local colors = cfg and cfg.colors
    if type(colors) ~= "table" then
        solidTex:SetVertexColor(1, 0, 0.4, 1)
        solidTex:Show()
        gradientTex:Hide()
        return
    end

    local kind = colors[1]
    if kind == "gradient-vertical" or kind == "gradient-horizontal" then
        local c1, c2 = colors[2], colors[3]
        if type(c1) == "table" and type(c2) == "table" then
            local dir = (kind == "gradient-vertical") and "VERTICAL" or "HORIZONTAL"
            gradientTex:SetGradient(dir,
                CreateColor(c1[1] or 1, c1[2] or 0, c1[3] or 0, c1[4] or 1),
                CreateColor(c2[1] or 0, c2[2] or 0, c2[3] or 0, c2[4] or 1))
        end
        gradientTex:Show()
        solidTex:Hide()
        return
    end

    local r, g, b, a = 1, 0, 0.4, 1
    if kind == "class-color" then
        r, g, b = F.GetClassColor(F.BD(unitButton).states and F.BD(unitButton).states.class)
        r, g, b, a = r or 1, g or 1, b or 1, 1
    elseif kind == "change-over-time" and type(colors[4]) == "table" then
        r, g, b, a = colors[4][1], colors[4][2], colors[4][3], colors[4][4] or 1
    elseif type(colors[2]) == "table" then
        r, g, b, a = colors[2][1], colors[2][2], colors[2][3], colors[2][4] or 1
    end
    solidTex:SetVertexColor(r, g, b, a)
    solidTex:Show()
    gradientTex:Hide()
end

local function MakeInitColorButton(cfg, unitButton)
    return function(button)
        pcall(button.SetSize, button, 0.001, 0.001)
        F.SetupEngineAuraButtonMouse(button, true)

        local dummy = button:CreateTexture(nil, "ARTWORK")
        dummy:SetAllPoints(button)
        dummy:SetColorTexture(0, 0, 0, 0)
        pcall(button.SetIcon, button, dummy)

        local solidTex = button:CreateTexture(nil, "ARTWORK", nil, 3)
        solidTex:SetTexture(Cell.vars.texture or Cell.vars.whiteTexture)
        AnchorColorOverlay(solidTex, unitButton, cfg)

        local gradientTex = button:CreateTexture(nil, "ARTWORK", nil, 3)
        gradientTex:SetTexture(Cell.vars.whiteTexture)
        AnchorColorOverlay(gradientTex, unitButton, cfg)

        ApplyColorOverlay(solidTex, gradientTex, cfg, unitButton)

        local health = F.BD(unitButton).widgets and F.BD(unitButton).widgets.healthBar
        local base = (health and health.GetFrameLevel and health:GetFrameLevel())
            or (unitButton.GetFrameLevel and unitButton:GetFrameLevel())
            or 1
        pcall(button.SetFrameLevel, button, base + (cfg.frameLevel or 1))
    end
end

local function GetBorderColor(cfg)
    local auras = cfg and cfg.auras
    if type(auras) == "table" then
        -- pairs, not ipairs: the "track any spell" entry lives at key 0
        for _, v in pairs(auras) do
            if type(v) == "table" and type(v[2]) == "table" then
                local c = v[2]
                return c[1] or 1, c[2] or 0, c[3] or 0, c[4] or 1
            end
        end
    end
    return 1, 0, 0, 1
end

local function MakeInitBorderButton(cfg, unitButton)
    return function(button)
        pcall(button.SetSize, button, 0.001, 0.001)
        F.SetupEngineAuraButtonMouse(button, true)

        local icon = AttachHiddenIcon(button)

        local inset = CELL_BORDER_SIZE or 1
        local thickness = cfg.thickness or 2
        local texMap, firstColor = BuildTextureColorMap(cfg.auras)
        local r, g, b, a = GetBorderColor(cfg)

        -- Anchored to the health bar, not the whole unit frame, so it doesn't wrap
        -- the power bar too (same reasoning as the Dispels border/overlay fix) -- unless the
        -- user opted into wrapping the whole frame via the "Wrap whole frame" checkbox.
        -- cfg.wrapWholeFrame is stamped into MakeParkKey, so toggling it forces a full
        -- container rebuild and this closure re-runs for every currently-shown button too.
        local anchorFrame = (not cfg.wrapWholeFrame and F.BD(unitButton).widgets and F.BD(unitButton).widgets.healthBar) or unitButton

        local tex = button:CreateTexture(nil, "ARTWORK", nil, 3)
        tex:SetTexture(Cell.vars.whiteTexture)
        tex:SetVertexColor(r, g, b, a)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", inset, -inset)
        tex:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", -inset, inset)

        -- recolor to match whichever aura is actually showing, like bar/block do
        HookIconColor(ResolveIconTexture(button, icon), texMap, firstColor or { r, g, b, a }, function(color)
            if not color then return end
            tex:SetVertexColor(UnpackColor(color, { r, g, b, a }))
        end, button)

        local mask = button:CreateMaskTexture()
        mask:SetTexture(Cell.vars.emptyTexture, "CLAMPTOWHITE", "CLAMPTOWHITE")
        mask:ClearAllPoints()
        mask:SetPoint("TOPLEFT", tex, "TOPLEFT", thickness, -thickness)
        mask:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", -thickness, thickness)
        tex:AddMaskTexture(mask)

        local tex2 = button:CreateTexture(nil, "ARTWORK", nil, 2)
        tex2:SetColorTexture(0, 0, 0, 1)
        tex2:ClearAllPoints()
        tex2:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", inset, -inset)
        tex2:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", -inset, inset)

        local mask2 = button:CreateMaskTexture()
        mask2:SetTexture(Cell.vars.emptyTexture, "CLAMPTOWHITE", "CLAMPTOWHITE")
        mask2:ClearAllPoints()
        mask2:SetPoint("TOPLEFT", tex2, "TOPLEFT", thickness + inset, -(thickness + inset))
        mask2:SetPoint("BOTTOMRIGHT", tex2, "BOTTOMRIGHT", -(thickness + inset), thickness + inset)
        tex2:AddMaskTexture(mask2)

        -- "Fade out over time" (uniform alpha fade) was tried twice and never worked reliably --
        -- see the UpdateIndicators callback below for why cfg.fadeOut is ignored here.
        --
        -- Duration Bar: a colored bar that sweeps across the border, using the plain
        -- SetDurationBar fill (confirmed working -- no color/alpha curve needed at all, just a
        -- constant SetStatusBarColor).
        if cfg.durationBar then
            local durationBar = CreateFrame("StatusBar", nil, button)
            durationBar:SetAllPoints(tex)
            durationBar:EnableMouse(false)
            durationBar:SetStatusBarTexture(Cell.vars.whiteTexture)
            durationBar:SetReverseFill(cfg.durationBarReverse == true)
            local c = cfg.color or { 1, 1, 1, 1 }
            durationBar:SetStatusBarColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
            local barTex = durationBar:GetStatusBarTexture()
            if barTex then
                barTex:AddMaskTexture(mask)
            end
            pcall(button.SetDurationBar, button, durationBar, DurationBarOpts(true))
        end

        local host = F.BD(unitButton).widgets and F.BD(unitButton).widgets.highLevelFrame or unitButton
        local base = (host.GetFrameLevel and host:GetFrameLevel())
            or (unitButton.GetFrameLevel and unitButton:GetFrameLevel())
            or 1
        pcall(button.SetFrameLevel, button, base + (cfg.frameLevel or 10))
    end
end

local function MakeInitTextButton(cfg)
    return function(button)
        local size = (type(cfg.font) == "table" and cfg.font[2]) or 12
        pcall(button.SetSize, button, size, size)
        F.SetupEngineAuraButtonMouse(button, cfg.showTooltip ~= true, cfg)
        AttachHiddenIcon(button)

        local text = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        text:SetPoint("CENTER", 1, 0)
        StyleFont(text, cfg.font, size)
        local r, g, b, a = GetCfgColor(cfg, { 0, 1, 0, 1 })
        text:SetTextColor(r, g, b, a)

        local showDuration = cfg.duration and cfg.duration[1]
        local showStack = not (cfg.stack and cfg.stack[1] == false)
        if showDuration then
            F.BindAuraDurationText(button, text, GetCellDurationFormatter(), cfg.auras)
            local stack = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            stack:SetPoint("TOPRIGHT", 2, 1)
            StyleFont(stack, cfg.font, size)
            stack:SetTextColor(r, g, b, a)
            pcall(button.SetApplicationCount, button, stack, {})
            stack:SetShown(showStack)
        elseif showStack then
            pcall(button.SetApplicationCount, button, text, {})
        end
    end
end

local function MakeInitRectButton(cfg)
    return function(button)
        local sizeW = (cfg.size and cfg.size[1]) or 11
        local sizeH = (cfg.size and cfg.size[2]) or 4
        pcall(button.SetSize, button, sizeW, sizeH)
        F.SetupEngineAuraButtonMouse(button, cfg.showTooltip ~= true, cfg)
        AttachHiddenIcon(button)

        local r, g, b, a = GetCfgColor(cfg, { 0, 1, 0, 1 })
        local fill = button:CreateTexture(nil, "ARTWORK")
        fill:SetAllPoints(button)
        fill:SetColorTexture(r, g, b, a)

        local br, bg, bb, ba = 0, 0, 0, 1
        if type(cfg.colors) == "table" and type(cfg.colors[4]) == "table" then
            br, bg, bb, ba = UnpackColor(cfg.colors[4], { 0, 0, 0, 1 })
        end
        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints(button)
        border:SetColorTexture(br, bg, bb, ba)
        local mask = button:CreateMaskTexture()
        mask:SetTexture(Cell.vars.emptyTexture or "Interface\\Buttons\\WHITE8X8", "CLAMPTOWHITE", "CLAMPTOWHITE")
        mask:SetPoint("TOPLEFT", border, "TOPLEFT", 1, -1)
        mask:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -1, 1)
        border:AddMaskTexture(mask)

        local animFrame = AttachDurationAnimation(button, cfg)
        AttachStackAndDuration(button, cfg, button, animFrame)
    end
end

local function MakeInitBarButton(cfg)
    return function(button)
        local sizeW = (cfg.size and cfg.size[1]) or 18
        local sizeH = (cfg.size and cfg.size[2]) or 4
        pcall(button.SetSize, button, sizeW, sizeH)
        F.SetupEngineAuraButtonMouse(button, cfg.showTooltip ~= true, cfg)
        local icon = AttachHiddenIcon(button)

        local bgr, bgg, bgb, bga = 0.07, 0.07, 0.07, 0.9
        if type(cfg.colors) == "table" and type(cfg.colors[5]) == "table" then
            bgr, bgg, bgb, bga = UnpackColor(cfg.colors[5], { 0.07, 0.07, 0.07, 0.9 })
        end
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(button)
        bg:SetColorTexture(bgr, bgg, bgb, bga)

        local r, g, b, a = GetCfgColor(cfg, { 0, 1, 0, 1 })
        local texMap, firstColor = BuildTextureColorMap(cfg.auras)
        if firstColor then
            r, g, b, a = UnpackColor(firstColor, { r, g, b, a })
        end
        local fillOrientation = (cfg.type == "bar" or cfg.type == "bars") and (cfg.orientation or "horizontal") or "horizontal"
        local bar = AttachDurationBar(button, fillOrientation, r, g, b, a, bgr, bgg, bgb, bga)
        HookIconColor(ResolveIconTexture(button, icon), texMap, firstColor or { r, g, b, a }, function(color)
            if not (bar and color) then return end
            local cr, cg, cb, ca = UnpackColor(color, { r, g, b, a })
            bar:SetStatusBarColor(cr, cg, cb, ca)
        end, button)

        AttachStackAndDuration(button, cfg, button, bar)
    end
end

local function MakeInitBlockButton(cfg)
    return function(button)
        local sizeW = (cfg.size and cfg.size[1]) or 10
        local sizeH = (cfg.size and cfg.size[2]) or 10
        pcall(button.SetSize, button, sizeW, sizeH)
        F.SetupEngineAuraButtonMouse(button, cfg.showTooltip ~= true, cfg)
        local icon = AttachHiddenIcon(button)

        local texMap, firstColor = BuildTextureColorMap(cfg.auras)
        local r, g, b, a
        if cfg.type == "blocks" then
            r, g, b, a = UnpackColor(firstColor, { 0, 1, 0, 1 })
        else
            r, g, b, a = GetCfgColor(cfg, { 0, 1, 0, 1 })
        end
        local fill = button:CreateTexture(nil, "ARTWORK")
        fill:SetAllPoints(button)
        fill:SetColorTexture(r, g, b, a)

        local br, bg, bb, ba = 0, 0, 0, 1
        if type(cfg.colors) == "table" and type(cfg.colors[5]) == "table" then
            br, bg, bb, ba = UnpackColor(cfg.colors[5], { 0, 0, 0, 1 })
        end
        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints(button)
        border:SetColorTexture(br, bg, bb, ba)
        local mask = button:CreateMaskTexture()
        mask:SetTexture(Cell.vars.emptyTexture or "Interface\\Buttons\\WHITE8X8", "CLAMPTOWHITE", "CLAMPTOWHITE")
        mask:SetPoint("TOPLEFT", border, "TOPLEFT", 1, -1)
        mask:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -1, 1)
        border:AddMaskTexture(mask)

        if cfg.type == "blocks" then
            HookIconColor(ResolveIconTexture(button, icon), texMap, firstColor or { r, g, b, a }, function(color)
                if not color then return end
                fill:SetColorTexture(UnpackColor(color, { r, g, b, a }))
            end, button)
        end

        local animFrame = AttachDurationAnimation(button, cfg)
        AttachStackAndDuration(button, cfg, button, animFrame)
    end
end

local function MakeInitTextureButton(cfg, unitButton)
    return function(button)
        local sizeW = (cfg.size and cfg.size[1]) or 16
        local sizeH = (cfg.size and cfg.size[2]) or 16
        pcall(button.SetSize, button, sizeW, sizeH)
        F.SetupEngineAuraButtonMouse(button, cfg.showTooltip ~= true, cfg)
        AttachHiddenIcon(button)

        local tex = button:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(button)
        local texTbl = cfg.texture
        if type(texTbl) == "table" and texTbl[1] then
            local path = texTbl[1]
            if type(path) == "string" and strfind(strlower(path), "^interface") then
                tex:SetTexture(path)
            else
                tex:SetAtlas(path)
            end
            if texTbl[2] then
                tex:SetRotation((texTbl[2] or 0) * math.pi / 180)
            end
            if type(texTbl[3]) == "table" then
                tex:SetVertexColor(UnpackColor(texTbl[3], { 1, 1, 1, 1 }))
            end
        else
            tex:SetColorTexture(1, 1, 1, 1)
        end
    end
end

local function MakeInitOverlayButton(cfg, unitButton)
    return function(button)
        pcall(button.SetSize, button, 0.001, 0.001)
        F.SetupEngineAuraButtonMouse(button, true)
        AttachHiddenIcon(button)

        local health = F.BD(unitButton).widgets and F.BD(unitButton).widgets.healthBar
        local r, g, b, a = GetCfgColor(cfg, { 0, 0.61, 1, 0.55 })

        local bar = CreateFrame("StatusBar", nil, button)
        if health then
            bar:SetAllPoints(health)
        else
            bar:SetAllPoints(unitButton)
        end
        bar:EnableMouse(false)
        bar:SetStatusBarTexture(Cell.vars.whiteTexture or Cell.vars.texture)
        local orientation = ResolveBarOrientation(cfg.orientation)
        if orientation == "top-to-bottom" or orientation == "bottom-to-top" then
            bar:SetOrientation("VERTICAL")
            -- SetOrientation alone only changes which edge grows -- without this, the fill
            -- texture stays oriented for a horizontal bar and a vertical one renders wrong.
            if bar.SetRotatesTexture then
                bar:SetRotatesTexture(true)
            end
        else
            bar:SetOrientation("HORIZONTAL")
            if bar.SetRotatesTexture then
                bar:SetRotatesTexture(false)
            end
        end
        -- matches the legacy preview bar's convention (Indicators/Base.lua, bar:SetOrientation) --
        -- this used to be the inverted condition, which made every direction (and the
        -- settings-panel preview, which uses that legacy bar) run backwards from what was
        -- selected.
        bar:SetReverseFill(orientation == "right-to-left" or orientation == "bottom-to-top")
        local barTex = bar:GetStatusBarTexture()
        if barTex then
            barTex:SetVertexColor(r, g, b, a)
        end
        local parent = health or unitButton
        local base = (parent.GetFrameLevel and parent:GetFrameLevel()) or 1
        pcall(bar.SetFrameLevel, bar, base + (cfg.frameLevel or 1) + 55)
        pcall(button.SetDurationBar, button, bar, DurationBarOpts(true))
    end
end

local function MakeInitGlowButton(cfg, unitButton)
    return function(button)
        pcall(button.SetSize, button, 0.001, 0.001)
        F.SetupEngineAuraButtonMouse(button, true)
        AttachHiddenIcon(button)

        -- "color-alpha" writes to cfg.color (a flat {r,g,b,a} table), same as the Border
        -- indicator's Duration Bar color -- NOT cfg.colors (plural, GetCfgColor's field),
        -- which is the multi-slot table used by Bar/Block/Text/Rect instead.
        local c = cfg.color or { 1, 0.85, 0.1, 1 }
        local r, g, b, a = c[1] or 1, c[2] or 0.85, c[3] or 0.1, c[4] or 1

        -- glows the whole frame (like Border), not just the health bar
        local glowFrame = CreateFrame("Frame", nil, button)
        glowFrame:EnableMouse(false)
        glowFrame:SetAllPoints(unitButton)
        local base = (unitButton.GetFrameLevel and unitButton:GetFrameLevel()) or 1
        pcall(glowFrame.SetFrameLevel, glowFrame, base + (cfg.frameLevel or 1) + 55)

        if F.StartEngineGlow then
            F.StartEngineGlow(glowFrame, cfg.glowStyle, r, g, b, a)
        end
    end
end

local function MakeInitAuraButton(cfg)
    return function(button)
        local sizeW = (cfg.size and cfg.size[1]) or 13
        local sizeH = (cfg.size and cfg.size[2]) or sizeW
        pcall(button.SetSize, button, sizeW, sizeH)
        F.SetupEngineAuraButtonMouse(button, cfg.showTooltip ~= true, cfg)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(button)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button:SetIcon(icon)

        local animFrame = AttachDurationAnimation(button, cfg)

        local textHost = CreateFrame("Frame", nil, button)
        textHost:SetAllPoints(button)
        textHost:EnableMouse(false)
        local baseLevel = (animFrame and animFrame.GetFrameLevel and animFrame:GetFrameLevel())
            or (button.GetFrameLevel and button:GetFrameLevel())
            or 1
        textHost:SetFrameLevel(baseLevel + 10)
        button._cellAuraTextHost = textHost

        local stack = textHost:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        stack:SetJustifyH("RIGHT")
        button._cellStackFS = stack
        pcall(button.SetApplicationCount, button, stack, {})
        stack:SetShown(cfg.showStack ~= false)

        if ShouldShowDuration(cfg) then
            local duration = textHost:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            duration:SetJustifyH("RIGHT")
            button._cellDurationFS = duration
            F.BindAuraDurationText(button, duration, GetCellDurationFormatter(), cfg.auras)
        end

        F.RestyleEngineAuraButtonFonts(button, cfg, StyleFont)
    end
end

-- 按钮的初始绘制：按 cfg.type 选用引擎自己的 MakeInit*Button。
-- 引擎路径和自绘路径都走这里，样式永远只有一个来源（插件原有实现 + cfg）。
local function BuildInitFrame(cfg, unitButton)
    if cfg.type == "color" then
        return MakeInitColorButton(cfg, unitButton)
    elseif cfg.type == "border" then
        return MakeInitBorderButton(cfg, unitButton)
    elseif cfg.type == "text" then
        return MakeInitTextButton(cfg)
    elseif cfg.type == "rect" then
        return MakeInitRectButton(cfg)
    elseif cfg.type == "bar" or cfg.type == "bars" then
        return MakeInitBarButton(cfg)
    elseif cfg.type == "block" or cfg.type == "blocks" then
        return MakeInitBlockButton(cfg)
    elseif cfg.type == "texture" then
        return MakeInitTextureButton(cfg, unitButton)
    elseif cfg.type == "overlay" then
        return MakeInitOverlayButton(cfg, unitButton)
    elseif cfg.type == "glow" then
        return MakeInitGlowButton(cfg, unitButton)
    end
    return MakeInitAuraButton(cfg)
end

local function ResolveContainerParent(unitButton, cfg)
    if cfg and (cfg.type == "border" or cfg.type == "glow") and F.BD(unitButton).widgets and F.BD(unitButton).widgets.highLevelFrame then
        return F.BD(unitButton).widgets.highLevelFrame
    end
    if cfg and cfg.type == "overlay" and F.BD(unitButton).widgets and F.BD(unitButton).widgets.healthBar then
        return F.BD(unitButton).widgets.healthBar
    end
    if F.BD(unitButton).widgets and F.BD(unitButton).widgets.indicatorFrame then
        return F.BD(unitButton).widgets.indicatorFrame
    end
    return unitButton
end

local function HideLegacy(unitButton, indicatorName)
    local ind = F.BD(unitButton).indicators and indicatorName and F.BD(unitButton).indicators[indicatorName]
    if not ind then return end
    if ind.StopGlow then
        pcall(ind.StopGlow, ind)
    end
    ind:Hide(true)
    if ind.SetAlpha then ind:SetAlpha(0) end
end

local function ShowLegacy(unitButton, indicatorName)
    local ind = F.BD(unitButton).indicators and indicatorName and F.BD(unitButton).indicators[indicatorName]
    if not ind then return end
    if ind.SetAlpha then ind:SetAlpha(1) end
end

local function StampCfgValue(v, depth)
    depth = depth or 0
    if depth > 3 then
        return ""
    end
    local t = type(v)
    if t == "table" then
        local parts = {}
        for i = 1, 8 do
            if v[i] ~= nil then
                parts[#parts + 1] = StampCfgValue(v[i], depth + 1)
            end
        end
        return table.concat(parts, ",")
    end
    if t == "boolean" then
        return v and "1" or "0"
    end
    if v == nil then
        return ""
    end
    return tostring(v)
end

local function MakeParkKey(cfg)
    local sizeW, sizeH = GetElementSize(cfg)
    return F.AuraParkKey(
        cfg.indicatorName,
        INIT_VERSION,
        cfg.type,
        cfg.auraType,
        sizeW,
        sizeH,
        ResolveAnimationStyle(cfg),
        cfg.showDuration,
        cfg.showStack ~= false,
        cfg.showTooltip,
        cfg.showAnimation,
        F.StampAuraFont(cfg.font),
        -- cfg.colors used to be stamped directly (StampCfgValue(cfg.colors)) -- but its color
        -- pickers fire on every drag tick just like the Duration Bar one, so a direct live stamp
        -- rebuilt on every tick and tripped the rebuild-loop circuit breaker. Same debounced
        -- counter fix as _durationBarGen below.
        cfg._colorsGen,
        -- per-spell colors (bars/blocks/border) live inside cfg.auras, which otherwise isn't part of
        -- this key at all -- without this, editing a color reuses the old pooled/parked button
        -- instead of rebuilding. A plain counter bumped only on an actual "auras" edit (see below).
        cfg._auraColorGen,
        -- same idea for Duration Bar + its color -- bumped only after the setting has SETTLED
        -- (debounced in the UpdateIndicators callback below), not on every drag tick of the color
        -- picker: bumping on every tick forced a rebuild per tick, which is what tripped the
        -- rebuild-loop circuit breaker the first time this was tried. cfg.fadeOut, unlike this
        -- one, is unused/ignored above and deliberately stays out of this key entirely.
        cfg._durationBarGen,
        cfg.texture,
        cfg.thickness,
        cfg.wrapWholeFrame,
        -- NOTE: the widget writes to cfg.orientation (its settingsTable key "barOrientation" gets
        -- remapped to "orientation" before saving -- see Indicators.lua), and MakeInitBarButton
        -- below reads cfg.orientation too. cfg.barOrientation itself is never actually written by
        -- anything, so stamping it here was a dead, always-nil field -- the park key never
        -- differed when orientation changed, so switching direction needed a manual /reload
        -- before it took effect.
        cfg.orientation,
        StampCfgValue(cfg.duration),
        StampCfgValue(cfg.stack),
        StampCfgValue(cfg.glowOptions)
    )
end

local function DestroyContainer(st)
    if not (st and st.container) then return end
    st.parks = st.parks or {}
    F.ParkAuraContainer(st.parks, st.parkKey, st.container)
    st.container = nil
    st.boundUnit = nil
    st.parkKey = nil
end

local function AnchorContainer(container, unitButton, cfg)
    local sizeW, sizeH = GetElementSize(cfg)
    local spacingX = (cfg.spacing and cfg.spacing[1]) or 0
    local spacingY = (cfg.spacing and cfg.spacing[2]) or 0
    local num = IsSingleSlot(cfg.type) and 1 or (cfg.num or 5)
    local numPerLine = math.max(1, cfg.numPerLine or num)
    local pos = cfg.position or { "TOPRIGHT", "button", "TOPRIGHT", 0, 3 }
    local point = pos[1] or "TOPRIGHT"
    local relative = pos[2]
    local relativePoint = pos[3] or point
    local x, y = pos[4] or 0, pos[5] or 0

    local relativeTo = unitButton
    if relative == "healthBar" and F.BD(unitButton).widgets and F.BD(unitButton).widgets.healthBar then
        relativeTo = F.BD(unitButton).widgets.healthBar
    end

    local orientation = cfg.orientation or "left-to-right"
    local vertical = (orientation == "top-to-bottom" or orientation == "bottom-to-top")

    --! 容器矩形必须等于指示器的真实占位。
    --! 这里长期写成 SetSize(1, 1)，流式布局就失去了参照系：元素虽然能画出来（关裁剪后），
    --! 但整组会从 1x1 的角上按生长方向甩出去，位置不可控，遇到靠边/单槽的配置就整组
    --! 飞到框体外面或被相邻框体压住，表现就是"配置全对、按钮也初始化了，但什么都看不见"。
    --! 现在容器 = 组的总宽高，元素在容器内部排布，位置由容器矩形唯一决定。
    local totalW, totalH
    if vertical then
        totalW = sizeW
        totalH = num * sizeH + math.max(num - 1, 0) * spacingY
    else
        local lines = math.max(1, math.ceil(num / numPerLine))
        totalW = numPerLine * sizeW + math.max(numPerLine - 1, 0) * spacingX
        totalH = lines * sizeH + math.max(lines - 1, 0) * spacingY
    end
    if not (totalW > 0) then totalW = 1 end
    if not (totalH > 0) then totalH = 1 end

    container:ClearAllPoints()
    container:SetPoint(point, relativeTo, relativePoint, x, y)
    container:SetSize(totalW, totalH)
    -- 元素已经全部落在容器内，裁剪开关保持关闭只是为了不误伤溢出 1px 的边框/发光。
    if container.SetClipsChildren then
        pcall(container.SetClipsChildren, container, false)
    end
    if container.EnableMouse then
        pcall(container.EnableMouse, container, false)
    end

    -- 流式布局的起始角只由排列方向决定，与配置的锚点角无关：
    -- 容器本身就是一块矩形区域，内容从它的左上/右上角开始往里填。
    local flowAnchor = "TOPLEFT"
    if orientation == "right-to-left" then
        flowAnchor = "TOPRIGHT"
    elseif orientation == "bottom-to-top" then
        flowAnchor = "BOTTOMLEFT"
    end
    if container.SetFlowLayoutAnchorPoint then
        pcall(container.SetFlowLayoutAnchorPoint, container, flowAnchor)
    end

    local FD = AnchorUtil and AnchorUtil.FlowDirection
    if FD and container.SetFlowLayoutGrowthDirection then
        local h, v = FD.Right, FD.Down
        if orientation == "right-to-left" then
            h, v = FD.Left, FD.Down
        elseif orientation == "top-to-bottom" then
            h, v = FD.Right, FD.Down
        elseif orientation == "bottom-to-top" then
            h, v = FD.Right, FD.Up
        end
        pcall(container.SetFlowLayoutGrowthDirection, container, h, v)
    end
    if container.SetFlowLayoutMaximumLineSize then
        pcall(container.SetFlowLayoutMaximumLineSize, container, totalW + 0.4)
    end

    local groupKey = cfg.indicatorName
    if container.HasAuraGroup and container:HasAuraGroup(groupKey) and container.SetAuraGroupLayout then
        pcall(container.SetAuraGroupLayout, container, groupKey, {
            elementWidth = sizeW,
            elementHeight = sizeH,
            elementSpacing = spacingX,
            lineSpacing = spacingY,
        })
    end

    -- 容器现在挂在 UIParent 下，层级必须跟着单位框体算，否则会被框体压住。
    local okLvl, wantLvl = pcall(function()
        return (unitButton:GetFrameLevel() or 0) + (cfg.frameLevel or 5)
    end)
    if okLvl and type(wantLvl) == "number" then
        pcall(container.SetFrameLevel, container, wantLvl)
    end
end

local function CustomTuneOpts(cfg)
    local sizeW, sizeH = GetElementSize(cfg)
    local spacingX = (cfg.spacing and cfg.spacing[1]) or 0
    local spacingY = (cfg.spacing and cfg.spacing[2]) or 0
    local maxCount = IsSingleSlot(cfg.type) and 1 or (cfg.num or 5)
    local opts = {
        maxFrameCount = maxCount,
        candidateFilters = {
            includeSpellIDs = BuildSpellMap(cfg.auras),
            excludeSpellIDs = BuildExcludeSpellMap(),
        },
        layout = {
            elementWidth = sizeW,
            elementHeight = sizeH,
            elementSpacing = spacingX,
            lineSpacing = spacingY,
        },
    }
    if AuraContainerSortMethod and AuraContainerSortMethod.Default then
        opts.sortMethod = AuraContainerSortMethod.Default
    end
    if AuraContainerSortDirection and AuraContainerSortDirection.Normal then
        opts.sortDirection = AuraContainerSortDirection.Normal
    end
    return opts
end

local function ApplyCustomTuning(container, cfg)
    if not (container and cfg) then return end
    F.ApplyAuraGroupTuning(container, cfg.indicatorName, BuildFilter(cfg.castBy, cfg.auraType), CustomTuneOpts(cfg))
    F.RestyleAuraContainerFonts(container, cfg, StyleFont)
end

local function CreateCustomContainer(unitButton, cfg, existing)
    local spellMap = BuildSpellMap(cfg.auras)
    if SpellMapCount(spellMap) == 0 then
        return nil, "empty spell list"
    end

    --! 父级必须是 UIParent（或其它顶层可见框），不能挂在框体内部的 indicatorFrame 上。
    --! AuraContainer 是 C 侧的新引擎，挂在单位框体这种会被 SecureGroupHeader 重排/隐藏的
    --! 子框下面时整组不渲染，且不报任何错。HealersAuraDisplay（同一客户端上确定工作）就是
    --! 用 UIParent 当父级 + 锚点指向框体的写法。锚定仍走 unitButton，位置一点不差。
    local parent = UIParent
    local container = existing
    if container then
        pcall(function()
            container:SetAlpha(1)
            container:SetParent(parent)
        end)
    else
        EnsureAuraContainerLoaded()
        local ok, created = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
        if not ok or not created then
            return nil, tostring(created)
        end
        container = created
    end

    local filter = BuildFilter(cfg.castBy, cfg.auraType)
    local unit = ResolveUnit(unitButton) or "player"
    local groupKey = cfg.indicatorName
    local groupOpts = CustomTuneOpts(cfg)

    AnchorContainer(container, unitButton, cfg)

    if existing then
        pcall(function() F.ApplyAuraGroupTuning(container, groupKey, filter, groupOpts) end)
    else
        local initFrame = BuildInitFrame(cfg, unitButton)
        local rawInit = initFrame
        groupOpts.initializeFrame = function(button)
            if not F.InitEngineAuraButtonOnce(button) then
                return
            end
            local ok, err = pcall(rawInit, button)
            if not ok and not Cell.vars._customAuraInitWarned then
                Cell.vars._customAuraInitWarned = true
                F.Print("|cFFFF7D7DCustom indicator setup failed:|r " .. tostring(err))
            end
        end
        local addOk, addErr = pcall(container.AddAuraGroup, container, groupKey, filter, groupOpts)
        if not addOk then
            F.QuiesceAuraContainer(container)
            return nil, tostring(addErr)
        end
    end

    AnchorContainer(container, unitButton, cfg)
    -- Forever: the client's AuraContainer can come up disabled (EllesmereUI, the proven
    -- on-client reference, explicitly SetEnabled(true)s every container it assigns).
    -- Without this the group exists, matches nothing, and prints no errors -- a fully
    -- dark indicator. Enable before binding the unit.
    if container.SetEnabled then
        pcall(container.SetEnabled, container, true)
    end
    pcall(container.SetUnit, container, unit)
    if container.UpdateAllAuras then
        pcall(container.UpdateAllAuras, container)
    end
    return container
end

function I.ForEachCustomAuraContainer(func)
    if not func then return end
    for _, map in pairs(stateByButton) do
        if type(map) == "table" then
            for _, st in pairs(map) do
                if st and st.container then
                    func(st.container)
                end
            end
        end
    end
end

local function DriveContainer(unitButton, cfg, enable)
    local map = stateByButton[unitButton]
    local st = map and map[cfg.indicatorName]
    if not (st and st.container and cfg) then return end
    if Cell.funcs.IsEditModeOpen and Cell.funcs.IsEditModeOpen() then
        return
    end
    local unit = ResolveUnit(unitButton)
    ApplyCustomTuning(st.container, cfg)
    AnchorContainer(st.container, unitButton, cfg)
    if enable then
        -- match the create/park lifecycle (Quiesce disables on park): re-enable here so a
        -- re-acquired parked container or one disabled at runtime comes back alive.
        if st.container.SetEnabled then
            pcall(st.container.SetEnabled, st.container, true)
        end
        -- parking zeroes the alpha (see QuiesceAuraContainer); a container that came back from
        -- the pool without passing through CreateCustomContainer's re-parent branch would stay
        -- fully transparent -- an invisible indicator with zero errors.
        pcall(st.container.SetAlpha, st.container, 1)
        st.container:Show()
        if unit and st.boundUnit ~= unit then
            pcall(st.container.SetUnit, st.container, unit)
            st.boundUnit = unit
        end
        if st.container.UpdateAllAuras then
            pcall(st.container.UpdateAllAuras, st.container)
        end
        HideLegacy(unitButton, cfg.indicatorName)
    else
        st.container:Hide()
        if st.container.SetEnabled then
            pcall(st.container.SetEnabled, st.container, false)
        end
        st.boundUnit = nil -- force a fresh SetUnit on the next enable (SetEnabled may unbind)
        ShowLegacy(unitButton, cfg.indicatorName)
    end
end

local function EnsureIndicatorContainer(unitButton, cfg, allowCreate)
    if not ProbeSupported() then return false end
    local map = stateByButton[unitButton]
    if not map then
        map = {}
        stateByButton[unitButton] = map
    end
    local name = cfg.indicatorName
    local st = map[name]
    if not st then
        st = {}
        map[name] = st
    end

    if st.createFailed and st.failedVersion == INIT_VERSION then
        return false
    end
    if st.createFailed and st.failedVersion ~= INIT_VERSION then
        st.createFailed = nil
        st.failedVersion = nil
    end

    if st.container then
        local now = GetTime()
        local want = MakeParkKey(cfg)
        local mismatched = st.parkKey ~= want or st.initVersion ~= INIT_VERSION or not st.container:GetParent()
        if mismatched then
            -- Circuit breaker: something (still being tracked down) can make the park key compare
            -- unequal to itself between two back-to-back syncs, causing an endless destroy/rebuild
            -- loop that freezes the client. If this container was JUST rebuilt a moment ago, don't
            -- destroy it again -- ride out the stale key rather than fight a busy-loop.
            if st.lastBuildTime and (now - st.lastBuildTime) < 0.5 then
                st.rapidRebuilds = (st.rapidRebuilds or 0) + 1
                if st.rapidRebuilds > 3 then
                    if not st.rebuildLoopWarned then
                        st.rebuildLoopWarned = true
                        F.Print("|cFFFF7D7DCustom AuraContainer:|r suppressed a rebuild loop for '"..tostring(name).."'")
                    end
                    mismatched = false
                end
            else
                st.rapidRebuilds = 0
                st.rebuildLoopWarned = nil
            end
        end
        if mismatched then
            DestroyContainer(st)
        end
    end

    if st.container then
        return true
    end
    if not allowCreate then
        return false
    end

    local want = MakeParkKey(cfg)
    st.parks = st.parks or {}
    local existing = F.AcquireParkedAuraContainer(st.parks, want, ResolveContainerParent(unitButton, cfg))
    local container, err = CreateCustomContainer(unitButton, cfg, existing)
    if not container then
        if existing then
            F.ParkAuraContainer(st.parks, want, existing)
        end
        st.createFailed = true
        st.failedVersion = INIT_VERSION
        if not Cell.vars._customAuraDisplayWarned then
            Cell.vars._customAuraDisplayWarned = true
            F.Print("|cFFFF7D7DCustom AuraContainer failed:|r " .. tostring(err))
        end
        return false
    end
    st.container = container
    st.parkKey = want
    st.boundUnit = ResolveUnit(unitButton)
    st.initVersion = INIT_VERSION
    st.createFailed = nil
    st.failedVersion = nil
    st.lastBuildTime = GetTime()
    return true
end

local EnqueueBuild

-- 自绘模式开关：true = 不创建 AuraContainer，直接用普通 Frame 画（实现见文件后部）。
local SIMPLE_MODE = true
local SimpleSyncButton -- 前向声明：建队列时就要调用，函数体在后面

local function PumpBuildQueue()
    buildTicker = nil
    local b = table.remove(buildQueue, 1)
    while b do
        buildQueued[b] = nil
        if F.BD(b)._indicatorsReady then
            break
        end
        b = table.remove(buildQueue, 1)
    end
    if not b then return end

    if SIMPLE_MODE then
        if SimpleSyncButton then SimpleSyncButton(b) end
    else
        local list = cachedConfigs or RefreshCachedConfigs()
        for i = 1, #list do
            local cfg = list[i]
            if EnsureIndicatorContainer(b, cfg, true) then
                DriveContainer(b, cfg, true)
            end
        end
    end

    if #buildQueue > 0 and not buildTicker then
        buildTicker = C_Timer.After(0, PumpBuildQueue)
    end
end

EnqueueBuild = function(unitButton)
    if not unitButton or buildQueued[unitButton] then return end
    buildQueued[unitButton] = true
    buildQueue[#buildQueue + 1] = unitButton
    if not buildTicker then
        buildTicker = C_Timer.After(0, PumpBuildQueue)
    end
end

--! ===========================================================================
--! 自绘路径：引擎路线（AuraContainer）在本客户端上能建、能初始化按钮，
--! 但自定义指示器的容器始终不出像素（尺寸/父级/锚点/裁剪/过滤器都试过）。
--! 这里不再依赖它：用普通 Frame + 纯色纹理直接画，光环数据取自框体自己维护的
--! _debuffs_cache / _buffs_cache —— 内置减益图标（6788 能正常显示）用的就是这份。
--! ===========================================================================
local simpleByButton = setmetatable({}, { __mode = "k" })

local function SimplePosition(unitButton, cfg)
    local pos = cfg.position or { "TOPRIGHT", "button", "TOPRIGHT", 0, 3 }
    local relativeTo = unitButton
    if pos[2] == "healthBar" and F.BD(unitButton).widgets and F.BD(unitButton).widgets.healthBar then
        relativeTo = F.BD(unitButton).widgets.healthBar
    end
    local point = pos[1] or "TOPRIGHT"
    return point, relativeTo, pos[3] or point, pos[4] or 0, pos[5] or 0
end

-- 普通 Frame 冒充引擎按钮：把只存在于 C 侧按钮上的几个方法接管成「记下对象」。
-- 这样引擎自己的 MakeInit*Button 能照原样跑完 —— 尺寸、填充色、描边、遮罩、
-- 扫秒动画全部由插件原有实现决定，这里一个字都不改样式。
local function SimpleStub(frame)
    frame.SetIcon = function(self, tex) self._simpleIcon = tex end
    frame.GetIcon = function(self) return self._simpleIcon end
    frame.SetApplicationCount = function(self, fs)
        self._simpleStackFS = self._simpleStackFS or fs
    end
    frame.SetDurationCooldown = function(self, cd) self._simpleAnim = cd end
    frame.SetDurationBar = function(self, bar) self._simpleAnim = bar end
end

--! 帧的身份不能只看 indicatorName。类型（色块 / 图标）、尺寸、颜色、动画样式这些
--! 都是 init 时烘进贴图里的，改完配置却复用同一个旧帧，就会出现「选的是色块，
--! 显示的还是技能图标」——旧帧是上一次按图标建出来的。MakeParkKey 已经把这些字段
--! 全算进 key 里了（引擎路径本来就靠它判断要不要重建），这里直接借它当身份。
local function SimpleKey(cfg)
    return (cfg.indicatorName or "?") .. "\1" .. MakeParkKey(cfg)
end

local function SimpleEnsure(unitButton, cfg)
    local map = simpleByButton[unitButton]
    if not map then
        map = {}
        simpleByButton[unitButton] = map
    end
    local key = SimpleKey(cfg)
    local f = map[key]
    if not f then
        -- 父级用 indicatorFrame：内置减益/文字/图标都挂在这里，是本客户端上确认
        -- 可以正常渲染的层级；锚点仍然指向单位框体，位置不受影响。
        local parent = (F.BD(unitButton).widgets and F.BD(unitButton).widgets.indicatorFrame) or unitButton
        f = CreateFrame("Frame", nil, parent)
        SimpleStub(f)
        local initFrame = BuildInitFrame(cfg, unitButton)
        local ok = pcall(initFrame, f)
        if not ok then
            -- 引擎绘制没跑通时兜个纯色块，保证至少能看见，而不是静默空白。
            local fill = f:CreateTexture(nil, "ARTWORK")
            fill:SetAllPoints(f)
            local r, g, b, a = GetCfgColor(cfg, { 1, 0, 0, 1 })
            fill:SetColorTexture(r, g, b, a)
        end
        f:Hide()
        map[key] = f
        f._simpleKey = key
    end

    if IsOverlayType(cfg.type) then
        -- 染色/边框/高光这类是整框覆盖的，锚点不由 position 决定
        f:ClearAllPoints()
        f:SetAllPoints(unitButton)
    else
        local point, relativeTo, relativePoint, x, y = SimplePosition(unitButton, cfg)
        f:ClearAllPoints()
        f:SetPoint(point, relativeTo, relativePoint, x, y)
    end
    if f.SetFrameLevel then
        local ok, lv = pcall(function()
            return (unitButton:GetFrameLevel() or 0) + (cfg.frameLevel or 5)
        end)
        if ok and type(lv) == "number" then
            pcall(f.SetFrameLevel, f, lv)
        end
    end
    return f
end

-- 在框体自己的光环缓存里找候选 spellId。缓存由 Cell 在 UNIT_AURA 时维护，
-- 内置减益图标（能正常显示 6788）用的就是这一份数据。
-- 本客户端的 aura 字段可能是 secret 值，直接比较会抛错，必须先判定再比较。
local function SimpleAuraHit(aura, wanted, castBy)
    if type(aura) ~= "table" then return nil end
    -- 不要因为整条 aura 带 _hasSecrets 就跳过：那通常只是持续时间等字段加密，
    -- 而 spellId 本身可读（Cell 的减益列表就是靠 spellId 匹配的）。
    local id = aura.spellId
    if id == nil or not F.IsValueNonSecret(id) then return nil end
    if not wanted[id] then return nil end
    if castBy == "me" or castBy == "others" then
        local src = aura.sourceUnit
        local mine
        if src ~= nil and F.IsValueNonSecret(src) then
            mine = (src == "player" or src == "pet")
        end
        -- 来源读不出来时不参与过滤：宁可多显示，也不要漏掉
        if mine ~= nil then
            if castBy == "me" and not mine then return nil end
            if castBy == "others" and mine then return nil end
        end
    end
    return id, aura
end

local function SimpleMatch(unitButton, cfg)
    local bd = F.BD(unitButton)
    local wanted = BuildSpellMap(cfg.auras)
    local isDebuff = (cfg.auraType == "debuff")

    local cache = isDebuff and bd._debuffs_cache or bd._buffs_cache
    if type(cache) == "table" then
        for _, aura in next, cache do
            local id, hit = SimpleAuraHit(aura, wanted, cfg.castBy)
            if id then return id, hit end
        end
    end

    -- 换单位的第一帧缓存可能还没建好，直接问一次客户端兜底。
    local unit = ResolveUnit(unitButton)
    if type(unit) == "string" and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local filter = isDebuff and "HARMFUL" or "HELPFUL"
        for i = 1, 40 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
            if not ok or not aura then break end
            local id, hit = SimpleAuraHit(aura, wanted, cfg.castBy)
            if id then return id, hit end
        end
    end
    return nil
end

-- 只负责「喂数据」：把匹配到的光环内容（图标 / 剩余时间 / 层数 / 文字）送进
-- 引擎 init 建好的那些元素里。视觉样式一概不碰。
local function SimpleUpdate(unitButton, cfg)
    local f = SimpleEnsure(unitButton, cfg)
    local t = cfg.type
    local id, aura = SimpleMatch(unitButton, cfg)
    if id == nil then
        f:Hide()
        return
    end

    if t == "icon" or t == "icons" then
        local icon = f._simpleIcon
        if icon and icon.SetTexture then
            local tex = (aura and aura.icon) or GetSpellTexture(id)
            pcall(icon.SetTexture, icon, tex or "Interface\\Icons\\INV_Misc_QuestionMark")
        end
    elseif t == "text" then
        local fs = f._simpleStackFS
        local name = aura and aura.name
        if fs and fs.SetText and name ~= nil and F.IsValueNonSecret(name) then
            pcall(fs.SetText, fs, name)
        end
        f:Show()
        return
    end

    -- 剩余时间：方块 / 图标 / 条共用，喂给引擎建好的 cooldown 或状态条。
    local anim = f._simpleAnim
    if anim and aura then
        if type(anim.SetCooldown) == "function" then
            local exp, dur = aura.expirationTime, aura.duration
            local okCd = false
            if exp ~= nil and dur ~= nil then
                okCd = pcall(anim.SetCooldown, anim, exp - dur, dur)
            end
            if not okCd then pcall(anim.Clear, anim) end
        end
    end

    -- 层数
    local stackFS = f._simpleStackFS
    if stackFS and stackFS.SetText then
        local n = aura and aura.applications
        if n ~= nil and F.IsValueNonSecret(n) and n > 1 then
            pcall(stackFS.SetText, stackFS, tostring(n))
        else
            pcall(stackFS.SetText, stackFS, "")
        end
    end

    f:Show()
end

-- 取消勾选后必须立刻消失：同步只遍历「当前启用」的配置，以前没有任何代码去碰那些
-- 已经从配置里消失的帧，所以红块要等 /reload 才没。
local function SimpleHideIndicator(unitButton, indicatorName)
    local map = simpleByButton[unitButton]
    if not map then return end
    -- 帧按「名字 + 配置签名」存（同一个指示器换类型会留下新旧两个 key），
    -- 所以按前缀收，不能只查名字。
    local prefix = indicatorName .. "\1"
    for key, f in pairs(map) do
        if key:sub(1, #prefix) == prefix then
            f:Hide()
        end
    end
end

function SimpleSyncButton(unitButton)
    local list = cachedConfigs or RefreshCachedConfigs()
    local seen
    for i = 1, #list do
        local cfg = list[i]
        if cfg.indicatorName then
            seen = seen or {}
            seen[SimpleKey(cfg)] = true
        end
        SimpleUpdate(unitButton, cfg)
        HideLegacy(unitButton, cfg.indicatorName)
    end
    -- 收尾：这一轮没配置的帧说明已被取消勾选/删除，当场隐藏（原来会一直留在屏幕上
    -- 直到重载）。
    local map = simpleByButton[unitButton]
    if map then
        for name, f in pairs(map) do
            if not (seen and seen[name]) then
                f:Hide()
            end
        end
    end
end

local simpleDriver = CreateFrame("Frame")
simpleDriver:RegisterEvent("UNIT_AURA")
simpleDriver:RegisterEvent("GROUP_ROSTER_UPDATE")
simpleDriver:RegisterEvent("PLAYER_ENTERING_WORLD")
simpleDriver:RegisterEvent("PLAYER_REGEN_ENABLED")
simpleDriver:SetScript("OnEvent", function(_, event, unit)
    if not SIMPLE_MODE then return end
    if not (cachedConfigs and #cachedConfigs > 0) then
        cachedConfigs = nil
        RefreshCachedConfigs()
    end
    local function apply()
        if event == "UNIT_AURA" and type(unit) == "string" then
            F.IterateAllUnitButtons(function(b)
                if F.BD(b)._indicatorsReady and ResolveUnit(b) == unit then SimpleSyncButton(b) end
            end, true)
        else
            F.IterateAllUnitButtons(function(b)
                if F.BD(b)._indicatorsReady then SimpleSyncButton(b) end
            end, true)
        end
    end
    -- Cell 的框体缓存也在 UNIT_AURA 里刷新，延后一帧保证读到的是新数据。
    C_Timer.After(0, apply)
end)

local function SyncButton(unitButton, allowCreate)
    if not unitButton or not F.BD(unitButton)._indicatorsReady then return end
    if SIMPLE_MODE then
        SimpleSyncButton(unitButton)
        return
    end
    -- Cache-aware like PumpBuildQueue above -- this runs once per button on
    -- every roster reshuffle, and the config only changes when the layout does.
    local list = cachedConfigs or RefreshCachedConfigs()
    if allowCreate == nil then
        allowCreate = true
    end

    local seen = {}
    local needsBuild = false
    for i = 1, #list do
        local cfg = list[i]
        local name = cfg.indicatorName
        seen[name] = true
        if EnsureIndicatorContainer(unitButton, cfg, false) then
            DriveContainer(unitButton, cfg, true)
        else
            needsBuild = true
        end
    end

    if needsBuild and allowCreate then
        EnqueueBuild(unitButton)
    end

    local map = stateByButton[unitButton]
    if map then
        for name, st in pairs(map) do
            if not seen[name] then
                if not InCombatLockdown() then
                    DestroyContainer(st)
                elseif st.container then
                    st.container:Hide()
                end
                ShowLegacy(unitButton, name)
                local ind = F.BD(unitButton).indicators and F.BD(unitButton).indicators[name]
                if ind and (ind.indicatorType == "color" or ind.indicatorType == "border"
                    or ind.indicatorType == "glow" or ind.indicatorType == "overlay"
                    or ind.indicatorType == "texture") then
                    ind:Hide()
                end
            end
        end
    end
end

function I.ShouldSkipLegacyCustom(indicatorTable)
    if not ProbeSupported() or not indicatorTable then
        return false
    end
    if IsSupportedCustomCfg(indicatorTable) then
        return true
    end
    if indicatorTable.name == "Healers" then
        return false
    end
    return SUPPORTED_TYPES[indicatorTable.type] and true or false
end

function I.CustomAuraDisplayActive()
    return ProbeSupported()
end

function I.SyncCustomAuraDisplays(unitButton)
    if not SUPPORTED then return end
    SyncButton(unitButton, true)
end

function I.UpdateCustomAuraDisplays(unitButton)
    if not SUPPORTED then return end
    SyncButton(unitButton, true)
end

-- 设置面板里勾选/取消自定义指示器要当场生效（用户实测：勾了要 /reload 才出现，
-- 取消了要 /reload 才消失）。原因不在数据层——配置本来就写进了布局表——而是这一层
-- 只在下一次光环事件/重载时才重建，勾选这个动作本身没有触发它。
function I.RefreshCustomIndicatorFrames(indicatorName, enabled)
    if not SUPPORTED or type(indicatorName) ~= "string" then return end
    if not indicatorName:find("^indicator") then return end
    cachedConfigs = nil

    if not SIMPLE_MODE then
        F.IterateAllUnitButtons(function(b)
            SyncButton(b, true)
        end, true)
        return
    end

    local list = enabled and RefreshCachedConfigs() or nil
    F.IterateAllUnitButtons(function(b)
        if not F.BD(b)._indicatorsReady then return end
        if not enabled then
            SimpleHideIndicator(b, indicatorName)
            return
        end
        for i = 1, #list do
            local cfg = list[i]
            if cfg.indicatorName == indicatorName then
                SimpleUpdate(b, cfg)
                HideLegacy(b, indicatorName)
                break
            end
        end
    end, true)
end

-- spreads the restyle over a few buttons per frame to avoid tripping
-- WoW's "script ran too long" limit on a full raid
local function ChunkedSyncAllButtons()
    local queue = {}
    local queued = {}
    F.IterateAllUnitButtons(function(b)
        if b and not queued[b] then
            queued[b] = true
            queue[#queue + 1] = b
        end
    end, true)
    if #queue == 0 then return end
    local idx = 1
    local function step()
        local budget = 4
        while budget > 0 and idx <= #queue do
            SyncButton(queue[idx], true)
            idx = idx + 1
            budget = budget - 1
        end
        if idx <= #queue then
            C_Timer.After(0, step)
        end
    end
    step()
end

function I.RefreshAllCustomAuraDisplays()
    if not SUPPORTED then return end
    cachedConfigs = nil
    ChunkedSyncAllButtons()
end

local function RebuildAllCustomAuraDisplays()
    if not SUPPORTED then return end
    cachedConfigs = nil
    F.IterateAllUnitButtons(function(b)
        local map = stateByButton[b]
        if map then
            for _, st in pairs(map) do
                DestroyContainer(st)
            end
        end
        EnqueueBuild(b)
    end, true)
end

local durationBarBumpTimer
local colorsBumpTimer

if SUPPORTED then
    Cell.RegisterCallback("UpdateIndicators", "CustomAuraDisplay_UpdateIndicators", function(layout, indicatorName, setting, value)
        if not layout or not indicatorName or not tostring(indicatorName):find("^indicator") then
            if not layout or not indicatorName then
                C_Timer.After(0, I.RefreshAllCustomAuraDisplays)
            end
            return
        end
        -- Checkbox widgets ("checkbutton4:durationBar" etc.) fire the event with the literal
        -- string "checkbutton" as `setting` and the REAL field name as the next argument
        -- (`value`) instead -- unlike every other widget type, which fires the real field name
        -- directly as `setting`. Normalize so the checks below work either way.
        local realSetting = setting
        if setting == "checkbutton" and (value == "durationBar" or value == "durationBarReverse") then
            realSetting = value
        end
        if setting == "auras" then
            -- bump a per-indicator counter so MakeParkKey sees a real, stable change and forces a
            -- rebuild (picking up the new color) -- only on an actual edit, never spontaneously
            local layoutTable = Cell.vars.currentLayoutTable
            local indicators = layoutTable and layoutTable.indicators
            if indicators then
                for i = 1, #indicators do
                    if indicators[i].indicatorName == indicatorName then
                        indicators[i]._auraColorGen = (indicators[i]._auraColorGen or 0) + 1
                        break
                    end
                end
            end
        elseif realSetting == "durationBar" or realSetting == "durationBarReverse" or realSetting == "color" or realSetting == "glowStyle" then
            -- Debounced: the color picker fires on every drag tick, and this used to bump
            -- (and rebuild) on every single one of those -- fast enough to trip the
            -- rebuild-loop circuit breaker while just dragging the color slider. Wait for
            -- things to settle, then bump once and refresh once.
            if durationBarBumpTimer then
                durationBarBumpTimer:Cancel()
            end
            durationBarBumpTimer = C_Timer.NewTimer(0.4, function()
                durationBarBumpTimer = nil
                local layoutTable = Cell.vars.currentLayoutTable
                local indicators = layoutTable and layoutTable.indicators
                if indicators then
                    for i = 1, #indicators do
                        if indicators[i].indicatorName == indicatorName then
                            indicators[i]._durationBarGen = (indicators[i]._durationBarGen or 0) + 1
                            break
                        end
                    end
                end
                I.RefreshAllCustomAuraDisplays()
            end)
        elseif setting == "colors" then
            -- Same drag-tick rebuild-storm risk as the Duration Bar color above -- the "colors"
            -- color pickers (Normal/Border/Background) fire on every drag tick too. Debounced
            -- the same way, into its own counter.
            if colorsBumpTimer then
                colorsBumpTimer:Cancel()
            end
            colorsBumpTimer = C_Timer.NewTimer(0.4, function()
                colorsBumpTimer = nil
                local layoutTable = Cell.vars.currentLayoutTable
                local indicators = layoutTable and layoutTable.indicators
                if indicators then
                    for i = 1, #indicators do
                        if indicators[i].indicatorName == indicatorName then
                            indicators[i]._colorsGen = (indicators[i]._colorsGen or 0) + 1
                            break
                        end
                    end
                end
                I.RefreshAllCustomAuraDisplays()
            end)
        end
        if setting == "create" or setting == "remove"
            or setting == "auras" or setting == "position" or setting == "size"
            or setting == "num" or setting == "numPerLine" or setting == "orientation"
            or setting == "spacing" or setting == "castBy" or setting == "enabled"
            or setting == "frameLevel" or setting == "showAnimation" or setting == "animationStyle"
            or setting == "showDuration" or setting == "showStack" or setting == "showTooltip"
            or setting == "checkbutton" or setting == "font"
            or setting == "type" or setting == "auraType"
            or setting == "colors" or setting == "anchor" or setting == "thickness"
            or setting == "glowOptions" or setting == "texture" or setting == "fadeOut"
            or setting == "smooth" or setting == "maxValue" or setting == "duration"
            or setting == "stack" or setting == "barOrientation" then
            C_Timer.After(0, I.RefreshAllCustomAuraDisplays)
        end
    end)

    Cell.RegisterCallback("UpdateLayout", "CustomAuraDisplay_UpdateLayout", function()
        C_Timer.After(0, I.RefreshAllCustomAuraDisplays)
    end)

    Cell.RegisterCallback("UpdateAppearance", "CustomAuraDisplay_UpdateAppearance", function(which)
        if which == nil or which == "icon" or which == "reset" then
            C_Timer.After(0, I.RefreshAllCustomAuraDisplays)
        end
    end)

    local boot = CreateFrame("Frame")
    boot:RegisterEvent("PLAYER_ENTERING_WORLD")
    boot:RegisterEvent("PLAYER_REGEN_DISABLED")
    boot:RegisterEvent("PLAYER_REGEN_ENABLED")
    boot:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(0.5, I.RefreshAllCustomAuraDisplays)
            return
        end
        -- entering combat doesn't make anything stale -- only leaving does
        if event == "PLAYER_REGEN_DISABLED" then
            return
        end
        ChunkedSyncAllButtons()
    end)
end
