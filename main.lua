-- https://github.com/JstHope/PalCaptureCounter (discord: jsthop3)
local config = require("config")

local pal_utility = nil
local capture_count = {}
local gauge_list = {}
local gauge_list_mutex = false

function UpdatePalCaptureCount()
    local raw_capture_count = pal_utility:GetLocalRecordData(FindFirstOf("PalPlayerCharacter")).PalCaptureCount.Items
    if not raw_capture_count:IsValid() then
        ExecuteWithDelay(1000, UpdatePalCaptureCount)
        return
    end

    raw_capture_count:ForEach(function(index, elem)
        local lua_elem = elem:get()
        capture_count[lua_elem.Key:ToString()] = lua_elem.Value
    end)

    -- print("[UpdatePalCaptureCount] updated.")
end

function LoadPalUtility()
    pal_utility = StaticFindObject("/Script/Pal.Default__PalUtility")
    if not pal_utility:IsValid() then
        ExecuteWithDelay(1000, LoadPalUtility)
        return
    end

    -- print("[PalUtility] loaded.")
end

function UpdateGauges()
    if gauge_list_mutex then
        ExecuteWithDelay(200, UpdateGauges)
        return
    end

    for key in pairs(gauge_list) do
        local enemyGauge = gauge_list[key].gauge
        local characterIdStr = gauge_list[key].char_id

        if enemyGauge ~= nil and characterIdStr ~= nil then
            if capture_count[characterIdStr] ~= nil then
                if config.always_show_count or capture_count[characterIdStr] < 10 then
                    enemyGauge.Text_WorkName:SetText_GDKInternal(1,
                        string.format("(%s/10)\n", tostring(capture_count[characterIdStr])))
                end
            else
                enemyGauge.Text_WorkName:SetText_GDKInternal(1, string.format("(0/10)\n"))
            end
        end
    end
end

function DetourOnCapturedPal(self, CaptureInfo)
    ExecuteAsync(function()
        UpdatePalCaptureCount()
        UpdateGauges()
    end)

    -- print(string.format("[OnCapturedPal] %s", CaptureInfo:get().CharacterID:ToString()))
end

function DetourBindFromHandle(widget, individualHandle)
    if widget:GetFullName() == nil then
        return
    end

    local enemyGauge = widget.WBP_EnemyGauge
    if enemyGauge:GetFullName() == nil then
        return
    end

    if individualHandle:GetFullName() == nil then
        return
    end

    local individualParameter = individualHandle:TryGetIndividualParameter()
    if individualParameter:GetFullName() == nil then
        return
    end

    local individualSaveParameter = individualParameter.SaveParameter
    if individualSaveParameter:GetFullName() == nil then
        return
    end

    local owner_uid = individualSaveParameter.OwnerPlayerUId
    if owner_uid.A ~= 0 or owner_uid.B ~= 0 or owner_uid.C ~= 0 or owner_uid.D ~= 0 then
        return
    end

    local characterId = individualSaveParameter.CharacterID
    if characterId == nil then
        return
    end

    gauge_list_mutex = true
    local characterIdStr = string.gsub(characterId:ToString(), "^BOSS_", "")

    local address = string.format("%016X", enemyGauge:GetAddress())

    if enemyGauge ~= nil and characterIdStr ~= nil then
        if capture_count[characterIdStr] ~= nil then
            if config.always_show_count or capture_count[characterIdStr] < 10 then
                enemyGauge.Text_WorkName:SetText_GDKInternal(1,
                    string.format("(%s/10)\n", tostring(capture_count[characterIdStr])))
            end
        else
            enemyGauge.Text_WorkName:SetText_GDKInternal(1, string.format("(0/10)\n"))
        end
    end

    gauge_list[address] = { gauge = enemyGauge, char_id = characterIdStr }
    gauge_list_mutex = false

    -- print(string.format("[Bind] %s", enemyGauge.Text_WorkName:GetFullName()))
end

function DetourUnbind(widget)
    if widget:GetFullName() == nil then
        return
    end

    local enemyGauge = widget.WBP_EnemyGauge
    if enemyGauge:GetFullName() == nil then
        return
    end

    gauge_list_mutex = true

    local address = string.format("%016X", enemyGauge:GetAddress())

        gauge_list[address] = nil
        gauge_list_mutex = false

    -- print(string.format("[Unbind] %s", address))
end

function Init()
    LoadPalUtility()

    UpdatePalCaptureCount()

    RegisterHook(
        "/Game/Pal/Blueprint/UI/WBP_PlayerUI.WBP_PlayerUI_C:OnCapturedPal",
        DetourOnCapturedPal)

    RegisterHook(
        "/Game/Pal/Blueprint/UI/NPCHPGauge/WBP_PalNPCHPGauge.WBP_PalNPCHPGauge_C:BindFromHandle", function (self, handler)
        local targetHandle = handler:get()
        local widget = self:get()

        ExecuteAsync(function()
            DetourBindFromHandle(widget,targetHandle)
        end)
    end)


    RegisterHook(
        "Function /Game/Pal/Blueprint/UI/NPCHPGauge/WBP_PalNPCHPGauge.WBP_PalNPCHPGauge_C:Unbind", function (self)
        local widget = self:get()

        ExecuteAsync(function()
            DetourUnbind(widget)
        end)
    end)
end

RegisterHook(
    "/Script/Engine.PlayerController:ClientRestart",
    function()
        Init()
    end)
