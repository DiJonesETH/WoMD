MODE.name = "zs"

-- Аирдроп выживших: сирена (текст оповещения сервер пишет в чат, sv_zs_airdrop.lua)

net.Receive("zs_airdrop", function()
	surface.PlaySound("ambient/alarms/klaxon1.wav")
end)
