-- Турели выживших Zombie Survival (спецпредметы технического ящика и аирдропа).
-- Предмет weapon_zs_turret_* ставится как ящик снабжения (weapon_zs_supplybox.lua) и превращается в zs_turret.
-- Турель медленно наводится на грудь зараженного в секторе 180 градусов, у нее есть лазерный прицел.
-- По E открывается окно: прочность, аккумулятор, боезапас; все это покупается за очки выжившего.
-- После покупки боезапаса турель перезаряжается reload секунд.

ZS_TURRET_MODEL = "models/combine_turrets/floor_turret.mdl"

ZS_TURRET_REPAIR_PRICE = 80 -- полная починка
ZS_TURRET_BATTERY_PRICE = 60 -- полная зарядка аккумулятора

-- range - дальность в юнитах (1 м ~ 52.5), fireDelay - пауза между выстрелами (темп огня оружия-образца), cockDelay - через сколько после выстрела
-- звучит взвод (дробовик, антиматериальная), ammo - имя патронов homigrad (урон и пробитие берутся из него)
ZS_TURRETS = {
	turret_smg = {
		range = 525, -- 10 м
		name = "SMG Turret",
		ammo = "9x19 mm Parabellum",
		maxAmmo = 250,
		reload = 10,
		fireDelay = 0.07, -- MP5
		spread = 0.025,
		sound = "zcitysnd/sound/weapons/mp5k/mp5k_fp.wav",
		ammoPrice = 120,
		price = 900,
		color = Color(120, 200, 255),
	},
	turret_shotgun = {
		range = 525, -- 10 м
		name = "Shotgun Turret",
		ammo = "12/70 gauge",
		maxAmmo = 60,
		reload = 15,
		fireDelay = 1, -- выстрел и автоматический взвод, как у помпового дробовика
		cockDelay = 0.45,
		cockSound = "weapons/shotgun/shotgun_cock.wav",
		spread = 0.06,
		sound = "zcitysnd/sound/weapons/firearms/shtg_remington870/remington_fire_01.wav",
		ammoPrice = 120,
		price = 1000,
		color = Color(255, 170, 80),
	},
	turret_rifle = {
		range = 1050, -- 20 м
		name = "Assault Turret",
		ammo = "5.56x45 mm",
		maxAmmo = 200,
		reload = 20,
		fireDelay = 0.063, -- M4A1
		spread = 0.015,
		sound = "m16a4/m16a4_fp.wav",
		ammoPrice = 160,
		price = 1300,
		color = Color(140, 230, 120),
	},
	turret_amr = {
		range = 2625, -- 50 м
		name = "Anti-Materiel Turret",
		ammo = "12.7x108 mm",
		maxAmmo = 20,
		reload = 30,
		fireDelay = 5, -- одиночный выстрел, затем 5 секунд взвода
		cockDelay = 2.5,
		cockSound = "weapons/shotgun/shotgun_cock.wav",
		cockPitch = 70,
		spread = 0.002,
		sound = "homigrad/weapons/rifle/loud_awp.wav",
		ammoPrice = 200,
		price = 1600,
		color = Color(230, 90, 90),
	},
}

ZS_TURRET_ORDER = {"turret_smg", "turret_shotgun", "turret_rifle", "turret_amr"}

-- турели ставятся как ящики снабжения и продаются в техническом ящике
for _, id in ipairs(ZS_TURRET_ORDER) do
	local cfg = ZS_TURRETS[id]
	cfg.weapon = "weapon_zs_" .. id

	if ZS_SUPPLY_BOXES then
		ZS_SUPPLY_BOXES[id] = {
			name = cfg.name,
			model = ZS_TURRET_MODEL,
			color = cfg.color,
			weapon = cfg.weapon,
			entity = "zs_turret",
			desc = "An automatic turret (" .. cfg.ammo .. ", " .. cfg.maxAmmo .. " rounds). It slowly aims at the chest of infected in a 180 degree arc in front of it. Press E on it to repair it, charge its battery and buy ammo",
		}
	end
end

if ZS_SHOPS and ZS_SHOPS.tech then
	local items = {}
	for _, id in ipairs(ZS_TURRET_ORDER) do
		local cfg = ZS_TURRETS[id]
		items[#items + 1] = {id = cfg.weapon, class = cfg.weapon, kind = "weapon", price = cfg.price}
	end

	ZS_SHOPS.tech[#ZS_SHOPS.tech + 1] = {name = "Turrets", items = items}
end
