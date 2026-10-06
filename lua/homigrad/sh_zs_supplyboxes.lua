-- Ящики снабжения выживших режима Zombie Survival (выпадают из аирдропа):
-- предмет weapon_zs_box_* ставится на землю и превращается в zs_supply_box

-- Постройки выживших режима Zombie Survival (выпадают из аирдропа как спецпредметы):
-- предмет weapon_zs_box_* ставится на землю и превращается в энтити entity (по умолчанию zs_supply_box).
-- Ящики снабжения открывают магазин, где выжившие тратят очки (SURVIVOR POINTS, sv_zs_survivors.lua).
ZS_SUPPLY_BOXES = {
	arsenal = {
		name = "Arsenal Box",
		model = "models/props/de_prodigy/ammo_can_01.mdl",
		color = Color(255, 255, 255),
		weapon = "weapon_zs_box_arsenal",
		desc = "A shop with pistols, shotguns, rifles, melee weapons and ammo for survivor points",
	},
	medical = {
		name = "Medical Box",
		model = "models/Items/item_item_crate.mdl",
		color = Color(220, 40, 40),
		weapon = "weapon_zs_box_medical",
		desc = "A shop with medical supplies for survivor points",
	},
	tech = {
		name = "Tech Box",
		model = "models/props/cs_militia/footlocker01_closed.mdl",
		color = Color(240, 200, 30),
		weapon = "weapon_zs_box_tech",
		desc = "A shop with nails, electrodes, duct tape and tools for survivor points",
	},
	incinerator = {
		name = "Corpse Incinerator",
		model = "models/props_c17/oildrum001.mdl",
		color = Color(200, 90, 40),
		weapon = "weapon_zs_box_incinerator",
		entity = "zs_incinerator",
		desc = "A barrel for burning corpses. Fuel it with gas cylinders and canisters, then throw in two corpses: they burn for 100 seconds",
	},
}

ZS_SUPPLY_BOX_RADIUS = 262 -- 5 метров: ближе такую же постройку поставить нельзя
ZS_SHOP_DISTANCE = 150 -- дальше от ящика магазин закрывается

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

-- можно ли поставить постройку этого типа в точку (нет такой же в радиусе 5 метров)
function ZS_CanPlaceSupplyBox(boxType, pos)
	local info = ZS_SUPPLY_BOXES[boxType]

	for _, ent in ipairs(ents.FindByClass(info and info.entity or "zs_supply_box")) do
		if ent:GetBoxType() == boxType and ent:GetPos():Distance(pos) < ZS_SUPPLY_BOX_RADIUS then
			return false
		end
	end

	return true
end

-- Магазины ящиков снабжения. Цены в очках выжившего: пассивно 1 очко в 2 секунды (~120 за волну с подготовкой),
-- 50 очков за убийство зараженного. Вкладки оружия повторяют категории Q-меню Z-City (SWEP.Category).
-- kind: weapon (по умолчанию) | armor | ammo_held (патроны к оружию в руках) | ammo (amount патронов типа ammo) | electrodes
-- ammoPrice/ammoShells у категории: цена патронов к оружию из нее; ammoShells - сколько патронов дается вместо 2 магазинов
ZS_SHOPS = {
	arsenal = {
		{name = "Pistols", ammoPrice = 30, items = {
			{class = "weapon_makarov", price = 160},
			{class = "weapon_glock17", price = 180},
			{class = "weapon_m9beretta", price = 190},
			{class = "weapon_hk_usp", price = 210},
			{class = "weapon_px4beretta", price = 210},
			{class = "weapon_cz75", price = 220},
			{class = "weapon_revolver2", price = 350},
			{class = "weapon_deagle", price = 450},
			{class = "weapon_draco", price = 700},
		}},
		{name = "Machine-Pistols", ammoPrice = 60, items = {
			{class = "weapon_skorpion", price = 450},
			{class = "weapon_uzi", price = 500},
			{class = "weapon_mac11", price = 500},
			{class = "weapon_tmp", price = 600},
			{class = "weapon_mp5", price = 650},
			{class = "weapon_mp7", price = 750},
			{class = "weapon_vector", price = 850},
			{class = "weapon_p90", price = 900},
		}},
		{name = "Shotguns", ammoPrice = 50, ammoShells = 7, items = {
			{class = "weapon_doublebarrel_short", price = 350},
			{class = "weapon_doublebarrel", price = 400},
			{class = "weapon_toz106", price = 450},
			{class = "weapon_remington870", price = 600},
			{class = "weapon_m590a1", price = 650},
			{class = "weapon_spas12", price = 800},
			{class = "weapon_xm1014", price = 950},
			{class = "weapon_saiga12", price = 1000},
		}},
		{name = "Carbines", ammoPrice = 70, items = {
			{class = "weapon_ruger", price = 550},
			{class = "weapon_mini14", price = 750},
			{class = "weapon_vpo136", price = 900},
			{class = "weapon_ar15", price = 1000},
		}},
		{name = "Assault Rifles", ammoPrice = 80, items = {
			{class = "weapon_ak74u", price = 1000},
			{class = "weapon_akm", price = 1100},
			{class = "weapon_ak74", price = 1100},
			{class = "weapon_m16a2", price = 1100},
			{class = "weapon_m4a1", price = 1250},
			{class = "weapon_hk416", price = 1350},
		}},
		{name = "Sniper Rifles", ammoPrice = 70, items = {
			{class = "weapon_winchester", price = 550},
			{class = "weapon_mosin", price = 600},
			{class = "weapon_kar98", price = 650},
			{class = "weapon_sks", price = 700},
			{class = "weapon_svd", price = 1200},
			{class = "weapon_sr25", price = 1300},
		}},
		{name = "Melee", items = {
			{class = "weapon_pocketknife", price = 40},
			{class = "weapon_pan", price = 50},
			{class = "weapon_leadpipe", price = 60},
			{class = "weapon_bat", price = 70},
			{class = "weapon_hatchet", price = 90},
			{class = "weapon_hg_crowbar", price = 90},
			{class = "weapon_tomahawk", price = 100},
			{class = "weapon_hg_shovel", price = 100},
			{class = "weapon_hg_axe", price = 150},
			{class = "weapon_hg_sledgehammer", price = 180},
		}},
		{name = "Armor", items = {
			{id = "helmet2", kind = "armor", armor = "helmet2", price = 120},
			{id = "helmet3", kind = "armor", armor = "helmet3", price = 250},
			{id = "helmet1", kind = "armor", armor = "helmet1", price = 350},
			{id = "helmet5", kind = "armor", armor = "helmet5", price = 400},
			{id = "vest6", kind = "armor", armor = "vest6", price = 250},
			{id = "vest3", kind = "armor", armor = "vest3", price = 400},
			{id = "vest4", kind = "armor", armor = "vest4", price = 550},
			{id = "vest1", kind = "armor", armor = "vest1", price = 750},
		}},
		{name = "Ammo", items = {
			{id = "ammo_held", kind = "ammo_held", name = "Ammo for the weapon in your hands", icon = "icon16/box.png", priceText = "30-80"},
		}},
	},
	medical = {
		{name = "Medicine", items = {
			{class = "weapon_bandage_sh", price = 30},
			{class = "weapon_tourniquet", price = 40},
			{class = "weapon_painkillers", price = 40},
			{class = "weapon_bigbandage_sh", price = 50},
			{class = "weapon_morphine", price = 80},
			{class = "weapon_adrenaline", price = 90},
			{class = "weapon_bloodbag", price = 100},
			{class = "weapon_medkit_sh", price = 120},
		}},
	},
	tech = {
		{name = "Materials", items = {
			{id = "nails", kind = "ammo", ammo = "Nails", amount = 16, name = "16 nails", icon = "icon16/wrench.png", price = 40},
			{id = "electrodes", kind = "electrodes", amount = 5, name = "5 welding electrodes", icon = "icon16/lightning.png", price = 50},
			{class = "weapon_ducttape", price = 60},
		}},
		{name = "Tools", items = {
			{class = "weapon_hammer", price = 60},
			{class = "weapon_hg_crowbar", price = 90},
			{class = "weapon_hg_sledgehammer", price = 180},
			{class = "weapon_zs_arcwelder", price = 250},
		}},
	},
}

-- id товара: класс оружия или свой id
for _, shop in pairs(ZS_SHOPS) do
	for _, cat in ipairs(shop) do
		for _, item in ipairs(cat.items) do
			item.id = item.id or item.class
			item.kind = item.kind or "weapon"
		end
	end
end

function ZS_FindShopItem(boxType, id)
	for _, cat in ipairs(ZS_SHOPS[boxType] or {}) do
		for _, item in ipairs(cat.items) do
			if item.id == id then return item, cat end
		end
	end
end

-- патроны к оружию в руках: цена и количество по категории этого оружия в арсенале
-- (2 магазина, у дробовиков - ammoShells патронов); возвращает price, amount
function ZS_HeldAmmoPrice(wep)
	if not IsValid(wep) or wep:GetPrimaryAmmoType() < 0 or wep:GetMaxClip1() <= 0 then return end

	local amount = wep:GetMaxClip1() * 2

	for _, cat in ipairs(ZS_SHOPS.arsenal) do
		if cat.ammoPrice then
			for _, item in ipairs(cat.items) do
				if item.class == wep:GetClass() then return cat.ammoPrice, cat.ammoShells or amount end
			end
		end
	end

	return 60, amount
end

function ZS_GetSurvivorPoints(ply)
	return ply:GetNWInt("ZS_SPoints", 0)
end
