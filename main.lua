-- https://github.com/JstHope/PalCaptureCounter (discord: jsthop3)

CAPTURE_LIST = {}
function update_capture_list()
    CAPTURE_LIST = {
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
function register_Gauge_Handle()
    RegisterHook("/Game/Pal/Blueprint/UI/NPCHPGauge/WBP_PalNPCHPGauge.WBP_PalNPCHPGauge_C:BindFromHandle", function(self, handler)
        local CharacterID = handler:get():TryGetIndividualParameter().SaveParameter.CharacterID:ToString()
        local eg = self.a.WBP_EnemyGauge
        if eg:IsValid() then
            if eg.Text_Name:GetFullName() ~= nil then
                if CAPTURE_LIST[CharacterID] ~= nil then
                    eg.Text_Name:SetText_GDKInternal(1,tostring(CharacterID) .. string.format(" [%s/10] ", CAPTURE_LIST[CharacterID]))
                else
                    eg.Text_Name:SetText_GDKInternal(1,CharacterID .. " [0/10] ")
                end
            end
        end
    end)
end

RegisterHook("/Script/Pal.PalCharacterParameterComponent:SetIsCapturedProcessing", function(self)
    update_capture_list()
end)

RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(Context, NewPawn)
    print("[PalCaptureCounter] INIT......")
    register_Gauge_Handle()
    RegisterHook("/Game/Pal/Blueprint/System/BP_PalGameInstance.BP_PalGameInstance_C:OnCompleteSetup", function(Context)
        print("[PalCaptureCounter] First update CAPTURE_LIST......")
        update_capture_list()
    end)
end)
