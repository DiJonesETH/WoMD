MODE.name = "zs"

-- Аирдроп выживших: оповещение в чате

local colAirdrop = Color(255, 70, 50)

net.Receive("zs_airdrop", function()
	surface.PlaySound("ambient/alarms/klaxon1.wav")
	chat.AddText(colAirdrop, "[Airdrop] ", color_white, "Груз сброшен! Ищите красный сигнальный огонь. Ящик исчезнет через 2 минуты.")
end)
