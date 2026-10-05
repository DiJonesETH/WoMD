-- Ящики снабжения выживших режима Zombie Survival (выпадают из аирдропа):
-- предмет weapon_zs_box_* ставится на землю и превращается в zs_supply_box

ZS_SUPPLY_BOXES = {
	arsenal = {
		name = "Арсенальный ящик",
		model = "models/props/de_prodigy/ammo_can_01.mdl",
		color = Color(255, 255, 255),
		weapon = "weapon_zs_box_arsenal",
		desc = "Раз в 2 минуты выдает 3 магазина к оружию в руках",
	},
	medical = {
		name = "Медицинский ящик",
		model = "models/Items/item_item_crate.mdl",
		color = Color(220, 40, 40),
		weapon = "weapon_zs_box_medical",
		desc = "Раз в 2 минуты выдает 3 случайных медицинских предмета",
	},
	tech = {
		name = "Технический ящик",
		model = "models/props/cs_militia/footlocker01_closed.mdl",
		color = Color(240, 200, 30),
		weapon = "weapon_zs_box_tech",
		desc = "Раз в 2 минуты выдает скотч, молоток и 32 гвоздя",
	},
}

ZS_SUPPLY_BOX_RADIUS = 262 -- 5 метров: ближе такой же ящик поставить нельзя
ZS_SUPPLY_BOX_COOLDOWN = 120

ZS_MEDICAL_ITEMS = {
	"weapon_medkit_sh",
	"weapon_bandage_sh",
	"weapon_bigbandage_sh",
	"weapon_tourniquet",
	"weapon_painkillers",
	"weapon_bloodbag",
	"weapon_morphine",
	"weapon_adrenaline",
}

if SERVER then
	-- сообщения о перезарядке/повторном использовании показываются игроку один раз за жизнь
	function ZS_NotifyOnce(ply, key, text)
		ply.zs_NotifiedOnce = ply.zs_NotifiedOnce or {}
		if ply.zs_NotifiedOnce[key] then return end

		ply.zs_NotifiedOnce[key] = true

		if ply.Notify then ply:Notify(text, 0, "zs_" .. key, 3) else ply:ChatPrint(text) end
	end

	hook.Add("PlayerSpawn", "ZS_NotifyOnceReset", function(ply)
		ply.zs_NotifiedOnce = nil
	end)
end

-- можно ли поставить ящик этого типа в точку (нет такого же ящика в радиусе 5 метров)
function ZS_CanPlaceSupplyBox(boxType, pos)
	for _, ent in ipairs(ents.FindByClass("zs_supply_box")) do
		if ent:GetBoxType() == boxType and ent:GetPos():Distance(pos) < ZS_SUPPLY_BOX_RADIUS then
			return false
		end
	end

	return true
end
