-- Ящики снабжения выживших режима Zombie Survival (выпадают из аирдропа):
-- предмет weapon_zs_box_* ставится на землю и превращается в zs_supply_box

-- Постройки выживших режима Zombie Survival (выпадают из аирдропа как спецпредметы):
-- предмет weapon_zs_box_* ставится на землю и превращается в энтити entity (по умолчанию zs_supply_box).
-- Ящики снабжения открывают магазин, где выжившие тратят очки (SURVIVOR POINTS, sv_zs_survivors.lua).
ZS_SUPPLY_BOXES = {
	arsenal = {
		{name = "Melee", items = {
			{class = "weapon_pocketknife", price = 40},
			{class = "weapon_bat", price = 60},
			{class = "weapon_buck200knife", price = 80},
			{class = "weapon_hg_crowbar", price = 100},
			{class = "weapon_hg_spear_pro", price = 130},
			{class = "weapon_hg_axe", price = 160},
			{class = "weapon_hg_sledgehammer", price = 190},
			{class = "weapon_hg_machete", price = 220},
		}},
		{name = "Pistols", ammoPrice = 30, items = {
			{class = "weapon_flintlock", price = 160},
			{class = "weapon_p22", price = 190},
			{class = "weapon_makarov", price = 220},
			{class = "weapon_px4beretta", price = 250},
			{class = "weapon_browninghp", price = 280},
			{class = "weapon_revolver2", price = 320},
			{class = "weapon_glock17", price = 360},
			{class = "weapon_revolver357", price = 400},
			{class = "weapon_ab10", price = 440},
			{class = "weapon_tec9", price = 480},
			{class = "weapon_glock18c", price = 530},
			{class = "weapon_deagle", price = 600},
		}},
		{name = "Shotguns", ammoPrice = 50, ammoShells = 7, items = {
			{class = "weapon_doublebarrel_short", price = 350},
			{class = "weapon_doublebarrel", price = 400},
			{class = "weapon_toz106", price = 450},
			{class = "weapon_m590a1", price = 550},
			{class = "weapon_saiga12", price = 650},
			{class = "weapon_ks23", price = 750},
			{class = "weapon_xm1014", price = 850},
			{class = "weapon_spas12", price = 950},
		}},
		{name = "Carbines", ammoPrice = 60, items = {
			{class = "weapon_musket", price = 450},
			{class = "weapon_ruger", price = 500},
			{class = "weapon_mosin", price = 550},
			{class = "weapon_kar98", price = 600},
			{class = "weapon_ar_pistol", price = 650},
			{class = "weapon_dracovska", price = 700},
			{class = "weapon_sks", price = 750},
			{class = "weapon_mini14", price = 850},
			{class = "weapon_vpo209", price = 950},
			{class = "weapon_ar15", price = 1050},
		}},
		{name = "PDW", ammoPrice = 60, items = {
			{class = "weapon_skorpion", price = 600},
			{class = "weapon_uzi", price = 650},
			{class = "weapon_mp5", price = 700},
			{class = "weapon_mac11", price = 750},
			{class = "weapon_tmp", price = 800},
			{class = "weapon_vector", price = 900},
			{class = "weapon_p90", price = 1000},
		}},
		{name = "Assault Rifles", ammoPrice = 80, items = {
			{class = "weapon_akmwreked", price = 900},
			{class = "weapon_ac556", price = 1000},
			{class = "weapon_ak74u", price = 1100},
			{class = "weapon_ak74", price = 1200},
			{class = "weapon_m16a2", price = 1300},
			{class = "weapon_hk416", price = 1400},
		}},
		{name = "Marksman Rifles", ammoPrice = 90, items = {
			{class = "weapon_svd", price = 1200},
			{class = "weapon_sr25", price = 1400},
			{class = "weapon_m98b", price = 1600},
		}},
		{name = "Optics", items = {
			{id = "holo1", kind = "attachment", att = "holo1", price = 120},
			{id = "holo6", kind = "attachment", att = "holo6", price = 150},
			{id = "optic11", kind = "attachment", att = "optic11", price = 250},
			{id = "optic2", kind = "attachment", att = "optic2", price = 300},
		}},
		{name = "Suppressors", items = {
			{id = "supressor6", kind = "attachment", att = "supressor6", price = 80},
			{id = "supressor3", kind = "attachment", att = "supressor3", price = 200},
			{id = "supressor8", kind = "attachment", att = "supressor8", price = 250},
			{id = "supressor5", kind = "attachment", att = "supressor5", price = 300},
		}},
		{name = "Special", ammoPrice = 40, items = {
			{class = "weapon_zs_nitrogen_grenade", price = 250},
			{class = "weapon_hg_bow", price = 300},
			{class = "weapon_hg_crossbow", price = 500},
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
			{id = "ammo_held", kind = "ammo_held", name = "Ammo for the weapon in your hands", icon = "icon16/box.png", priceText = "30-90"},
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
