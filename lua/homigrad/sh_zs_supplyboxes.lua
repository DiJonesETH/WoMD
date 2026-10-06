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

-- Магазины ящиков снабжения. Цены в очках выжившего: пассивно 1 очко в секунду (~240 за волну с подготовкой),
-- 50 очков за убийство зараженного. Пистолет - примерно 2 минуты, лучшая винтовка - около 4 волн.
-- kind: weapon (по умолчанию) | ammo_held (2 магазина к оружию в руках) | ammo (amount патронов типа ammo) | electrodes
ZS_SHOPS = {
	arsenal = {
		{name = "Pistols", ammoPrice = 30, items = {
			{class = "weapon_makarov", price = 100},
			{class = "weapon_glock17", price = 120},
			{class = "weapon_m9beretta", price = 130},
			{class = "weapon_hk_usp", price = 140},
			{class = "weapon_px4beretta", price = 140},
			{class = "weapon_cz75", price = 150},
			{class = "weapon_revolver2", price = 250},
			{class = "weapon_deagle", price = 300},
		}},
		{name = "Shotguns", ammoPrice = 50, items = {
			{class = "weapon_doublebarrel_short", price = 250},
			{class = "weapon_doublebarrel", price = 280},
			{class = "weapon_remington870", price = 400},
			{class = "weapon_xm1014", price = 650},
		}},
		{name = "Rifles", ammoPrice = 70, items = {
			{class = "weapon_mp5", price = 450},
			{class = "weapon_kar98", price = 450},
			{class = "weapon_mp7", price = 500},
			{class = "weapon_sks", price = 500},
			{class = "weapon_draco", price = 600},
			{class = "weapon_ar15", price = 700},
			{class = "weapon_akm", price = 750},
			{class = "weapon_sr25", price = 900},
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
		{name = "Ammo", items = {
			{id = "ammo_held", kind = "ammo_held", name = "2 magazines for the weapon in your hands", icon = "icon16/box.png", priceText = "30-70"},
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

-- цена 2 магазинов к оружию в руках: по категории этого оружия в арсенале
function ZS_HeldAmmoPrice(wep)
	if not IsValid(wep) then return end

	for _, cat in ipairs(ZS_SHOPS.arsenal) do
		if cat.ammoPrice then
			for _, item in ipairs(cat.items) do
				if item.class == wep:GetClass() then return cat.ammoPrice end
			end
		end
	end

	if wep:GetPrimaryAmmoType() >= 0 and wep:GetMaxClip1() > 0 then return 60 end
end

function ZS_GetSurvivorPoints(ply)
	return ply:GetNWInt("ZS_SPoints", 0)
end
