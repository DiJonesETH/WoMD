MODE.name = "zs"

-- Аирдроп выживших: оповещение в чате

local colAirdrop = Color(255, 70, 50)

net.Receive("zs_airdrop", function()
	surface.PlaySound("ambient/alarms/klaxon1.wav")
	chat.AddText(colAirdrop, "[Airdrop] ", color_white, "Supplies dropped! Look for the red flare. The crate disappears in 2 minutes.")
end)
