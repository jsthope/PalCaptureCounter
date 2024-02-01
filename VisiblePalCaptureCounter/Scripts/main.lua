-- https://github.com/JstHope/PalCaptureCounter (discord: jsthop3)
local config = require("config")

local pal_utility = nil
local capture_count = {}
local gauge_list = {}
local gauge_list_mutex = false

local reglist = {}
local hooked=false
local inited=false


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
        -- print("[VPCC-UpdateGauges] updating " .. characterIdStr .. "...")

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
    -- print("[VPCC-UpdateGauges] updated.")
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

    -- print(string.format("[VPCC-Bind] %s", enemyGauge.Text_WorkName:GetFullName()))
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

    -- print(string.format("[VPCC-Unbind] %s", address))
end

function Init()
    ExecuteAsync(function()
        LoadPalUtility()
        UpdatePalCaptureCount()
    end)

    reglist[0], reglist[1] = RegisterHook(
        "/Game/Pal/Blueprint/UI/WBP_PlayerUI.WBP_PlayerUI_C:OnCapturedPal", function (self, CaptureInfo)
        ExecuteAsync(function()
            -- print(string.format("[VPCC-OnCapturedPal called]"))
            UpdatePalCaptureCount()
            UpdateGauges()
        end)
    end)

    reglist[2], reglist[3] = RegisterHook(
        "/Game/Pal/Blueprint/UI/NPCHPGauge/WBP_PalNPCHPGauge.WBP_PalNPCHPGauge_C:BindFromHandle", function (self, handler)
        local targetHandle = handler:get()
        local widget = self:get()

        ExecuteAsync(function()
            DetourBindFromHandle(widget,targetHandle)
        end)
    end)


    reglist[4], reglist[5] = RegisterHook(
        "/Game/Pal/Blueprint/UI/NPCHPGauge/WBP_PalNPCHPGauge.WBP_PalNPCHPGauge_C:Unbind", function (self)
        local widget = self:get()

        ExecuteAsync(function()
            DetourUnbind(widget)
        end)
    end)
end

function UnInit() -- dont work
    UnregisterHook("/Game/Pal/Blueprint/UI/WBP_PlayerUI.WBP_PlayerUI_C:OnCapturedPal", reglist[0], reglist[1])
    UnregisterHook("/Game/Pal/Blueprint/UI/NPCHPGauge/WBP_PalNPCHPGauge.WBP_PalNPCHPGauge_C:BindFromHandle", reglist[2], reglist[3])
    UnregisterHook("/Game/Pal/Blueprint/UI/NPCHPGauge/WBP_PalNPCHPGauge.WBP_PalNPCHPGauge_C:Unbind", reglist[4], reglist[5])
end


RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(Context)
    if not hooked then
        hooked=true
        ExecuteWithDelay(5000,function()
            ExecuteInGameThread(function()
                RegisterHook("/Game/Pal/Blueprint/UI/UserInterface/ESCMenu/WBP_MenuESC.WBP_MenuESC_C:ConfirmReturnTitle",function()
                    inited=false
                    if #reglist ~= 0 then
                        UnInit()
                        reglist={}
                        capture_count = {}
                        gauge_list = {}
                        gauge_list_mutex = false
                    end
                end)
            end)
        end)
    end
    if not inited then
        inited=true
        ExecuteWithDelay(6000,function()
            ExecuteInGameThread(function()
                Init()
            end)
        end)
    end
end)
