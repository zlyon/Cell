local _, Cell = ...
local L = Cell.L
local F = Cell.funcs
local P = Cell.pixelPerfectFuncs

local aboutTab = Cell.CreateFrame("CellOptionsFrame_AboutTab", Cell.frames.optionsFrame, nil, nil, true)
Cell.frames.aboutTab = aboutTab
aboutTab:SetAllPoints(Cell.frames.optionsFrame)
aboutTab:Hide()

local authorText, specialThanksText
local translatorsTextCN, translatorsTextKR, translatorsTextPT, translatorsTextDE, translatorsTextRU, translatorsTextFR, translatorsTextES, translatorsTextIT
local UpdateFont

-------------------------------------------------
-- description
-------------------------------------------------
local descriptionPane
local function CreateDescriptionPane()
    descriptionPane = Cell.CreateTitledPane(aboutTab, "Cell", 422, 120)
    descriptionPane:SetPoint("TOPLEFT", aboutTab, "TOPLEFT", 5, -5)

    local changelogsBtn = Cell.CreateButton(descriptionPane, L["Changelogs"], "accent", {100, 17})
    changelogsBtn:SetPoint("TOPRIGHT")
    changelogsBtn:SetScript("OnClick", function()
        F.CheckWhatsNew(true)
    end)

    local snippetsBtn = Cell.CreateButton(descriptionPane, L["Code Snippets"], "accent", {120, 17})
    snippetsBtn:SetPoint("TOPRIGHT", changelogsBtn, "TOPLEFT", 1, 0)
    snippetsBtn:SetScript("OnClick", function()
        F.ShowCodeSnippets()
    end)

    local descText = descriptionPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    descText:SetPoint("TOPLEFT", 5, -27)
    descText:SetPoint("RIGHT", -10, 0)
    descText:SetJustifyH("LEFT")
    descText:SetSpacing(5)
    descText:SetText(L["ABOUT"])
end


-------------------------------------------------
-- author
-------------------------------------------------
local function CreateAuthorPane()
    local authorPane = Cell.CreateTitledPane(aboutTab, L["Author"], 205, 50)
    authorPane:SetPoint("TOPLEFT", aboutTab, "TOPLEFT", 5, -185)

    authorText = authorPane:CreateFontString(nil, "OVERLAY")
    authorText:SetPoint("TOPLEFT", 5, -27)
    authorText.font = "Interface\\AddOns\\Cell\\Media\\Fonts\\font.ttf"
    authorText.size = 12
    UpdateFont(authorText)

    authorText:SetText("篠崎-影之哀伤 (CN)")
end

-------------------------------------------------
-- slash
-------------------------------------------------
local function CreateSlashPane()
    local slashPane = Cell.CreateTitledPane(aboutTab, L["Slash Commands"], 205, 50)
    slashPane:SetPoint("TOPLEFT", aboutTab, "TOPLEFT", 222, -185)

    local commandText = slashPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    commandText:SetPoint("TOPLEFT", 5, -27)
    commandText:SetText("/cell")
end

-------------------------------------------------
-- translators
-------------------------------------------------
local function CreateTranslatorsPane()
    local translatorsPane = Cell.CreateTitledPane(aboutTab, L["Translators"], 422, 120)
    translatorsPane:SetPoint("TOPLEFT", aboutTab, "TOPLEFT", 5, -240)

    -- zhTW
    translatorsTextCN = translatorsPane:CreateFontString(nil, "OVERLAY")
    translatorsTextCN.font = UNIT_NAME_FONT_CHINESE
    translatorsTextCN.size = 13
    UpdateFont(translatorsTextCN)

    translatorsTextCN:SetPoint("TOPLEFT", 5, -27)
    translatorsTextCN:SetSpacing(5)
    translatorsTextCN:SetJustifyH("LEFT")
    translatorsTextCN:SetText("|cff999999zhTW:|r RainbowUI, BNS333, Mili")

    -- koKR
    translatorsTextKR = translatorsPane:CreateFontString(nil, "OVERLAY")
    translatorsTextKR.font = UNIT_NAME_FONT_KOREAN
    translatorsTextKR.size = 12
    UpdateFont(translatorsTextKR)

    translatorsTextKR:SetPoint("TOPLEFT", translatorsTextCN, 215, 0)
    translatorsTextKR:SetSpacing(5)
    translatorsTextKR:SetJustifyH("LEFT")
    translatorsTextKR:SetText("|cff999999koKR:|r 007bb, netaras")

    -- ptBR
    translatorsTextPT = translatorsPane:CreateFontString(nil, "OVERLAY")
    translatorsTextPT.font = UNIT_NAME_FONT_ROMAN
    translatorsTextPT.size = 12
    UpdateFont(translatorsTextPT)

    translatorsTextPT:SetPoint("TOPLEFT", translatorsTextCN, "BOTTOMLEFT", 0, -6)
    translatorsTextPT:SetSpacing(5)
    translatorsTextPT:SetJustifyH("LEFT")
    translatorsTextPT:SetText("|cff999999ptBR:|r cathtail")

    -- deDE
    translatorsTextDE = translatorsPane:CreateFontString(nil, "OVERLAY")
    translatorsTextDE.font = UNIT_NAME_FONT_ROMAN
    translatorsTextDE.size = 12
    UpdateFont(translatorsTextDE)

    translatorsTextDE:SetPoint("TOPLEFT", translatorsTextPT, 215, 0)
    translatorsTextDE:SetSpacing(5)
    translatorsTextDE:SetJustifyH("LEFT")
    translatorsTextDE:SetText("|cff999999deDE:|r CheersItsJulian")

    -- ruRU
    translatorsTextRU = translatorsPane:CreateFontString(nil, "OVERLAY")
    translatorsTextRU.font = UNIT_NAME_FONT_ROMAN
    translatorsTextRU.size = 12
    UpdateFont(translatorsTextRU)

    translatorsTextRU:SetPoint("TOPLEFT", translatorsTextPT, "BOTTOMLEFT", 0, -6)
    translatorsTextRU:SetSpacing(5)
    translatorsTextRU:SetJustifyH("LEFT")
    translatorsTextRU:SetText("|cff999999ruRU:|r KnewOne, Lucenn, MORROSION")

    -- frFR
    translatorsTextFR = translatorsPane:CreateFontString(nil, "OVERLAY")
    translatorsTextFR.font = UNIT_NAME_FONT_ROMAN
    translatorsTextFR.size = 12
    UpdateFont(translatorsTextFR)

    translatorsTextFR:SetPoint("TOPLEFT", translatorsTextRU, "BOTTOMLEFT", 0, -6)
    translatorsTextFR:SetSpacing(5)
    translatorsTextFR:SetJustifyH("LEFT")
    translatorsTextFR:SetText("|cff999999frFR:|r epino46, elated_kalam86")

    -- itIT
    translatorsTextIT = translatorsPane:CreateFontString(nil, "OVERLAY")
    translatorsTextIT.font = UNIT_NAME_FONT_ROMAN
    translatorsTextIT.size = 12
    UpdateFont(translatorsTextIT)

    translatorsTextIT:SetPoint("TOPLEFT", translatorsTextFR, 215, 0)
    translatorsTextIT:SetSpacing(5)
    translatorsTextIT:SetJustifyH("LEFT")
    translatorsTextIT:SetText("|cff999999itIT:|r CeleDev")

    -- esES / esMX
    translatorsTextES = translatorsPane:CreateFontString(nil, "OVERLAY")
    translatorsTextES.font = UNIT_NAME_FONT_ROMAN
    translatorsTextES.size = 12
    UpdateFont(translatorsTextES)

    translatorsTextES:SetPoint("TOPLEFT", translatorsTextFR, "BOTTOMLEFT", 0, -6)
    translatorsTextES:SetSpacing(5)
    translatorsTextES:SetJustifyH("LEFT")
    translatorsTextES:SetText("|cff999999esES:|r Zurent, maylisdalan, F3R_Lv72    |cff999999esMX:|r maylisdalan")
end

-------------------------------------------------
-- special thanks
-------------------------------------------------
local function CreateSpecialThanksPane()
    local specialThanksPane = Cell.CreateTitledPane(aboutTab, L["Special Thanks"], 422, 120)
    specialThanksPane:SetPoint("TOPLEFT", aboutTab, "TOPLEFT", 5, -375)

    specialThanksText = specialThanksPane:CreateFontString(nil, "OVERLAY")
    specialThanksText.font = UNIT_NAME_FONT_CHINESE
    specialThanksText.size = 13
    UpdateFont(specialThanksText)

    specialThanksText:SetPoint("TOPLEFT", 5, -27)
    specialThanksText:SetPoint("RIGHT", -5, 0)
    specialThanksText:SetSpacing(5)
    specialThanksText:SetJustifyH("LEFT")
    specialThanksText:SetText(
        "|cfffb6f92露露缇娅, Reat TV, 钛锬, Floofe, warbaby, zlyon|r\n"..
        "|cffff0000Wago:|r Ora\n"..
        "|cffff3333YouTube:|r AutomaticJak, JFunkGaming, yumytv\n"..
        "|cff5662f6Discord:|r |cff7fff00clankz.|r, |cff7fff00DreadMesh|r, |cff7fff00Missgunst|r, |cff00ffffVollmerino|r, aba, BinarySunshine, Bruds, Gharr, honeyhoney, leaKsi, Serghei, swirl, Xepheris"
    )
end

-------------------------------------------------
-- links
-------------------------------------------------
local links = {}
local function CreateLink(parent, id, icon, onEnter)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    P.Size(f, 34, 34)
    f:SetBackdrop({bgFile = Cell.vars.whiteTexture})
    f:SetBackdropColor(0, 0, 0, 1)

    links[id] = f

    f.icon = f:CreateTexture(nil, "ARTWORK")
    P.Point(f.icon, "TOPLEFT", 1, -1)
    P.Point(f.icon, "BOTTOMRIGHT", -1, 1)
    f.icon:SetTexture(icon)

    f:SetScript("OnEnter", function()
        f:SetBackdropColor(Cell.GetAccentColorRGB())
        for  _id, _f in pairs(links) do
            if _id ~= id then
                _f:SetBackdropColor(0, 0, 0, 1)
            end
        end
        if onEnter then onEnter() end
    end)

    f:SetScript("OnHide", function()
        f:SetBackdropColor(0, 0, 0, 1)
    end)

    return f
end

local function CreateLinksPane()
    local linksPane = Cell.CreateTitledPane(aboutTab, L["Links"], 422, 100)
    linksPane:SetPoint("TOPLEFT", aboutTab, "TOPLEFT", 5, -535)

    local current

    local linksEB = Cell.CreateEditBox(linksPane, 412, 20)
    linksEB:SetPoint("TOPLEFT", 5, -27)
    linksEB:SetText("https://github.com/zlyon/Cell")
    linksEB:SetScript("OnTextChanged", function(self, userChanged)
        if userChanged then
            linksEB:SetText(current)
            linksEB:HighlightText()
        end
        linksEB:SetCursorPosition(0)
    end)
    linksEB:SetScript("OnMouseUp", function(self)
        linksEB:HighlightText()
    end)

    --! github
    local github = CreateLink(linksPane, "github", "Interface\\AddOns\\Cell\\Media\\Links\\github.tga", function()
        current = "https://github.com/zlyon/Cell"
        linksEB:SetText(current)
        linksEB:ClearFocus()
    end)
    github:SetPoint("TOPLEFT", linksEB, "BOTTOMLEFT", 0, -7)

    linksEB:SetScript("OnShow", function()
        github:GetScript("OnEnter")()
    end)

    --! curseforge
    local curseforge = CreateLink(linksPane, "curseforge", "Interface\\AddOns\\Cell\\Media\\Links\\curseforge.tga", function()
        current = "https://www.curseforge.com/wow/addons/cell"
        linksEB:SetText(current)
        linksEB:ClearFocus()
    end)
    curseforge:SetPoint("TOPLEFT", github, "TOPRIGHT", 7, 0)

    --! wago
    local wago = CreateLink(linksPane, "wago", "Interface\\AddOns\\Cell\\Media\\Links\\wago.tga", function()
        current = "https://addons.wago.io/addons/cell"
        linksEB:SetText(current)
        linksEB:ClearFocus()
    end)
    wago:SetPoint("TOPLEFT", curseforge, "TOPRIGHT", 7, 0)

    --! discord
    local discord = CreateLink(linksPane, "discord", "Interface\\AddOns\\Cell\\Media\\Links\\discord.tga", function()
        current = "https://discord.gg/9PSe3fKQGJ"
        linksEB:SetText(current)
        linksEB:ClearFocus()
    end)
    discord:SetPoint("TOPLEFT", wago, "TOPRIGHT", 7, 0)

    --! kook
    local kook = CreateLink(linksPane, "kook", "Interface\\AddOns\\Cell\\Media\\Links\\kook.tga", function()
        current = "https://kook.top/q4T7yp"
        linksEB:SetText(current)
        linksEB:ClearFocus()
    end)
    kook:SetPoint("TOPLEFT", discord, "TOPRIGHT", 7, 0)

    --! 网易DD
    local dd = CreateLink(linksPane, "dd", "Interface\\AddOns\\Cell\\Media\\Links\\dd.png", function()
        current = "https://dd.163.com/i/8PRkYzhnAE"
        linksEB:SetText(current)
        linksEB:ClearFocus()
    end)
    dd:SetPoint("TOPLEFT", kook, "TOPRIGHT", 7, 0)

    --! 新手盒子
    local wclbox = CreateLink(linksPane, "wclbox", "Interface\\AddOns\\Cell\\Media\\Links\\wclbox.png", function()
        current = "https://www.wclbox.com/share/AMy47t4htw5"
        linksEB:SetText(current)
        linksEB:ClearFocus()
    end)
    wclbox:SetPoint("TOPLEFT", dd, "TOPRIGHT", 7, 0)

end

-------------------------------------------------
-- import & export
-------------------------------------------------
local function CreateImportExportPane()
    -- placed near the top so profile import is easy to find (was too far down / easy to miss)
    local iePane = Cell.CreateTitledPane(aboutTab, L["Import & Export All Settings"], 422, 50)
    iePane:SetPoint("TOPLEFT", aboutTab, "TOPLEFT", 5, -130)

    local importBtn = Cell.CreateButton(iePane, L["Import"], "accent-hover", {134, 20})
    importBtn:SetPoint("TOPLEFT", 5, -27)
    importBtn:SetScript("OnClick", F.ShowImportFrame)
    importBtn:SetTexture("Interface\\AddOns\\Cell\\Media\\Icons\\import", {16, 16}, {"LEFT", 2, 0})

    local exportBtn = Cell.CreateButton(iePane, L["Export"], "accent-hover", {134, 20})
    exportBtn:SetPoint("TOPLEFT", importBtn, "TOPRIGHT", 5, 0)
    exportBtn:SetScript("OnClick", F.ShowExportFrame)
    exportBtn:SetTexture("Interface\\AddOns\\Cell\\Media\\Icons\\export", {16, 16}, {"LEFT", 2, 0})

    local backupBtn = Cell.CreateButton(iePane, L["Backups"], "accent-hover", {134, 20})
    backupBtn:SetPoint("TOPLEFT", exportBtn, "TOPRIGHT", 5, 0)
    backupBtn:SetScript("OnClick", F.ShowBackupFrame)
    backupBtn:SetTexture("Interface\\AddOns\\Cell\\Media\\Icons\\backup", {16, 16}, {"LEFT", 2, 0})
end

-------------------------------------------------
-- functions
-------------------------------------------------
local init
local function ShowTab(tab)
    if tab == "about" then
        if not init then
            init = true
            CreateDescriptionPane()
            CreateAuthorPane()
            CreateSlashPane()
            CreateSpecialThanksPane()
            CreateTranslatorsPane()
            CreateLinksPane()
            CreateImportExportPane()
        end
        aboutTab:Show()
        descriptionPane:SetTitle("Cell "..(Cell.version or "?"))
    else
        aboutTab:Hide()
    end
end
Cell.RegisterCallback("ShowOptionsTab", "AboutTab_ShowTab", ShowTab)

UpdateFont = function(fs)
    if not fs then return end

    fs:SetFont(fs.font, fs.size + CellDB["appearance"]["optionsFontSizeOffset"], "")
    fs:SetTextColor(1, 1, 1, 1)
    fs:SetShadowColor(0, 0, 0)
    fs:SetShadowOffset(1, -1)
end

function Cell.UpdateAboutFont()
    UpdateFont(authorText)
    UpdateFont(translatorsTextCN)
    UpdateFont(translatorsTextKR)
    UpdateFont(translatorsTextPT)
    UpdateFont(translatorsTextDE)
    UpdateFont(translatorsTextRU)
    UpdateFont(translatorsTextFR)
    UpdateFont(translatorsTextES)
    UpdateFont(specialThanksText)
end