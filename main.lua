-- https://github.com/JstHope/PalCaptureCounter (discord: jsthop3)
local PAL_DATA = require("pal_data")
local config = require("config")

function findObjectByPalName(fileName)
    for i, obj in ipairs(PAL_DATA) do
        if obj.FileName == fileName then
            return obj
        end
    end
    return nil -- return nil if no object with the given PalName is found
end

CAPTURE_LIST = {}
function update_capture_list()
    CAPTURE_LIST = {}
    local records = FindAllOf("BP_PalPlayerRecordData_C")
    if records then
        for Index, record in pairs(records) do
            local items = record.PalCaptureCount.Items
            items:ForEach(function(index, elem_wrapper)
                local palrec = elem_wrapper:get()
                CAPTURE_LIST[palrec.Key:ToString()] = tostring(palrec.Value)
            end)
        end
    end
end

function add_count_to_pal(handler, WBP_PalNPCHPGauge_C)
    local CharacterID = string.gsub(handler:TryGetIndividualParameter().SaveParameter.CharacterID:ToString(), "^BOSS_",
        "")
    local eg = WBP_PalNPCHPGauge_C.WBP_EnemyGauge
    local PalObject = findObjectByPalName(CharacterID)
    -- If PalObject is nil, return from the function
    if PalObject == nil then
        print("[PalCaptureCounter] no PalObject found for " .. CharacterID)
        return
    end

    local PalName = PalObject.PalName
    -- print the length of CAPTURE_LIST
    local CaughtCounter = tonumber(CAPTURE_LIST[CharacterID]) or 0
    if eg:IsValid() then
        if eg.Text_Name:GetFullName() ~= nil then
            -- If always_show_count is true, always show the counter
            if config.always_show_count then
                eg.Text_Name:SetText_GDKInternal(1, PalName .. string.format(" [%s/10] ", CaughtCounter))
            else
                -- else only show the counter if the number of captures is less than 10
                if CaughtCounter < 10 then
                    eg.Text_Name:SetText_GDKInternal(1, PalName .. string.format(" [%s/10] ", CaughtCounter))
                end
            end
        end
    end
end

function register_Gauge_Handle()
    RegisterHook("/Game/Pal/Blueprint/UI/NPCHPGauge/WBP_PalNPCHPGauge.WBP_PalNPCHPGauge_C:BindFromHandle",
        function(self, handler)
            local handler_ = handler.a
            local WBP_PalNPCHPGauge_C = self.WBP_PalNPCHPGauge_C

            ExecuteAsync(function()
                add_count_to_pal(handler_, WBP_PalNPCHPGauge_C)
            end)
        end)
end

RegisterHook("/Script/Pal.PalCharacterParameterComponent:SetIsCapturedProcessing", function()
    update_capture_list()
end)

RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
    print("[PalCaptureCounter] INIT......")
    register_Gauge_Handle()
    RegisterHook("/Game/Pal/Blueprint/System/BP_PalGameInstance.BP_PalGameInstance_C:OnCompleteSetup", function()
        print("[PalCaptureCounter] First update CAPTURE_LIST......")
        update_capture_list()
    end)
end)