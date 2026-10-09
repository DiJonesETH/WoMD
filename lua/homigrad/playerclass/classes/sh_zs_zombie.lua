-- Классы зараженных режима Zombie Survival: bruiser (танк), agile (быстрый), metaboliser (хилер)
--
-- NPC-модели (models/Zombie/*.mdl) не содержат костей игрока (Bip01_Neck1 и др.), на которых в homigrad держатся камера,
-- удары и организм. Поэтому игрок физически остается на игровой модели zombie_classic (она скрыта материалом "NULL",
-- см. hg.renderOverride), а ванильная модель без хедкрабов рисуется на клиенте поверх нее через EF_BONEMERGE.
--
-- Тела и клешни (вьюмодели от 11k) взяты из Zombie Survival (github.com/JetBoom/zombiesurvival, лицензия JBGM,
-- см. LICENSE_zombiesurvival_content.txt): zombie_classic_hbfix, встроенная в GMod player/zombie_fast и Poison.mdl из HL2.

ZS_BASE_MODEL = "models/zcity/player/zombie_classic.mdl"

-- множитель урона когтей (у headcrabzombie 5): слабый тупой урон
ZS_CLAW_DAMAGE_MUL = 2.5

ZS_ZOMBIE_CLASSES = {
	zs_bruiser = {
		key = "bruiser",
		name = "Bruiser",
		desc = "Tank. Slow, takes much less damage, heavy claws.",
		model = "models/Zombie/Poison.mdl",
		viewModel = "models/weapons/v_pza.mdl",
		viewModelFOV = 47,
		viewModelHiddenBones = {"ValveBiped.HC5_Bodybox"}, -- хедкраб в руке
		sounds = {
			steps = {"npc/zombie_poison/pz_left_foot1.wav", "npc/zombie_poison/pz_right_foot1.wav"},
			pain = {"npc/zombie_poison/pz_pain1.wav", "npc/zombie_poison/pz_pain2.wav", "npc/zombie_poison/pz_pain3.wav"},
			death = {"npc/zombie_poison/pz_die1.wav", "npc/zombie_poison/pz_die2.wav"},
			idle = {"npc/zombie_poison/pz_idle2.wav", "npc/zombie_poison/pz_idle3.wav", "npc/zombie_poison/pz_idle4.wav", "npc/zombie_poison/pz_alert1.wav", "npc/zombie_poison/pz_alert2.wav"},
		},
		color = Color(50, 110, 230),
		speed = 0.85,
		damageTaken = 0.6,
		meleeMul = 1.35,
		clawsName = "Bruiser Claws",
	},
	zs_agile = {
		key = "agile",
		name = "Agile",
		desc = "Fast. Runs and swings quickly, but is fragile.",
		model = "models/player/zombie_fast.mdl",
		viewModel = "models/weapons/v_fza.mdl",
		viewModelFOV = 70,
		sounds = {
			steps = {"npc/fast_zombie/foot1.wav", "npc/fast_zombie/foot2.wav", "npc/fast_zombie/foot3.wav", "npc/fast_zombie/foot4.wav"},
			pain = {"NPC_FastZombie.Pain"},
			death = {"NPC_FastZombie.Die"},
			idle = {"npc/fast_zombie/idle1.wav", "npc/fast_zombie/idle2.wav", "npc/fast_zombie/idle3.wav", "npc/fast_zombie/fz_alert_close1.wav", "npc/fast_zombie/fz_frenzy1.wav"},
		},
		color = Color(220, 50, 50),
		speed = 1.3,
		damageTaken = 1.25,
		meleeMul = 0.85,
		clawsName = "Agile Claws",
	},
	zs_metaboliser = {
		key = "metaboliser",
		name = "Metaboliser",
		desc = "Healer. Slowly mends itself and nearby infected.",
		model = "models/player/zombie_classic_hbfix.mdl",
		viewModel = "models/weapons/v_zombiearms.mdl",
		viewModelFOV = 70,
		sounds = {
			steps = {"npc/zombie/foot1.wav", "npc/zombie/foot2.wav", "npc/zombie/foot3.wav"},
			scuffs = {"npc/zombie/foot_slide1.wav", "npc/zombie/foot_slide2.wav", "npc/zombie/foot_slide3.wav"},
			pain = {"npc/zombie/zombie_pain1.wav", "npc/zombie/zombie_pain2.wav", "npc/zombie/zombie_pain3.wav", "npc/zombie/zombie_pain4.wav", "npc/zombie/zombie_pain5.wav", "npc/zombie/zombie_pain6.wav"},
			death = {"npc/zombie/zombie_die1.wav", "npc/zombie/zombie_die2.wav", "npc/zombie/zombie_die3.wav"},
			idle = {"npc/zombie/zombie_voice_idle1.wav", "npc/zombie/zombie_voice_idle2.wav", "npc/zombie/zombie_voice_idle3.wav", "npc/zombie/zombie_voice_idle4.wav", "npc/zombie/zombie_alert1.wav", "npc/zombie/zombie_alert2.wav", "npc/zombie/zombie_alert3.wav"},
		},
		color = Color(60, 200, 80),
		speed = 1,
		damageTaken = 1,
		meleeMul = 0.9,
		clawsName = "Metaboliser Claws",
		healRadius = 300,
	},
}

ZS_ZOMBIE_CLASS_ORDER = {"zs_bruiser", "zs_agile", "zs_metaboliser"}

-- Боссы: отдельный вид зараженных, не класс на выбор (sv_zs_boss.lua). Навыков у них нет.
ZS_BOSS_CLASSES = {
	zs_gonome = {
		key = "gonome",
		name = "Gonome",
		model = "", -- модель гонома рисует cl_zs_boss.lua (скелет HL1 не надевается через bonemerge)
		-- руки от первого лица - как у agile
		viewModel = ZS_ZOMBIE_CLASSES.zs_agile.viewModel,
		viewModelFOV = ZS_ZOMBIE_CLASSES.zs_agile.viewModelFOV,
		viewModelHiddenBones = ZS_ZOMBIE_CLASSES.zs_agile.viewModelHiddenBones,
		sounds = {
			steps = ZS_ZOMBIE_CLASSES.zs_bruiser.sounds.steps,
			pain = {"vj_hlr/gsrc/npc/gonome/gonome_pain1.wav", "vj_hlr/gsrc/npc/gonome/gonome_pain2.wav", "vj_hlr/gsrc/npc/gonome/gonome_pain3.wav", "vj_hlr/gsrc/npc/gonome/gonome_pain4.wav"},
			death = {"vj_hlr/gsrc/npc/gonome/gonome_death2.wav", "vj_hlr/gsrc/npc/gonome/gonome_death3.wav", "vj_hlr/gsrc/npc/gonome/gonome_death4.wav"},
			idle = {"vj_hlr/gsrc/npc/gonome/gonome_idle1.wav", "vj_hlr/gsrc/npc/gonome/gonome_idle2.wav", "vj_hlr/gsrc/npc/gonome/gonome_idle3.wav"},
		},
		color = Color(200, 170, 40),
		speed = 1,
		damageTaken = 1,
		meleeMul = 2,
		clawsName = "Gonome Claws",
		boss = true,
		modelScale = 1.18, -- скрытая модель вырастает до роста гонома (~85): хитбоксы покрывают всю его фигуру
	},
}

function ZS_ClassInfo(class)
	return ZS_ZOMBIE_CLASSES[class] or ZS_BOSS_CLASSES[class]
end

function ZS_IsZombie(ply)
	return IsValid(ply) and ZS_ClassInfo(ply.PlayerClassName) ~= nil
end

-- босс-гоном (gamemodes/zcity/gamemode/modes/zombiesurvival/sv_zs_boss.lua): зараженный с NWBool ZS_Boss
function ZS_IsBoss(ply)
	return IsValid(ply) and ply:IsPlayer() and ply:GetNWBool("ZS_Boss", false)
end

-- навыки дерева класса (режим Zombie Survival), синхронизируются через NWBool
function ZS_HasSkill(ply, id)
	-- у босса нет навыков класса, которым он был
	if IsValid(ply) and ply.PlayerClassName and ZS_BOSS_CLASSES[ply.PlayerClassName] then return false end

	return IsValid(ply) and ply:GetNWBool("ZS_Skill_" .. id, false)
end

local clr_zombie = Color(90, 20, 20)

-- приставки к никам зараженных: "<приставка> <ник игрока>"
ZS_NAME_PREFIXES = {
	zs_bruiser = {"Tanky", "Meaty", "Massive", "Colossal", "Armored"},
	zs_agile = {"Rapid", "Ambusher", "Volatile", "Carnivore"},
	zs_metaboliser = {"Bacterial", "Fungi", "Rotten", "Poisoned"},
}

local allClasses = table.Copy(ZS_ZOMBIE_CLASSES)
for className, info in pairs(ZS_BOSS_CLASSES) do allClasses[className] = info end

for className, info in pairs(allClasses) do
	local CLASS = player.RegClass(className)

	CLASS.CanUseDefaultPhrase = false
	CLASS.CanEmitRNDSound = false
	CLASS.CanUseGestures = false
	CLASS.NoGloves = true

	function CLASS.On(self)
		if CLIENT then return end

		local prefixes = ZS_NAME_PREFIXES[className]
		self:SetNWString("PlayerName", prefixes and (prefixes[math.random(#prefixes)] .. " " .. self:Nick()) or info.name)
		self:SetNetVar("Accessories", "")

		self:SetModel(ZS_BASE_MODEL)
		self:SetSubMaterial()
		self:SetMaterial("NULL")
		self:SetSkin(0)
		self:SetBodyGroups("00000000000000000000")
		self:SetPlayerColor(clr_zombie:ToVector())
		self:SetNWString("ZS_Visual", info.model)

		self.MeleeDamageMul = info.meleeMul

		hg.SetArmorRestrictions(self, {all = true})

		if not self:HasWeapon("weapon_hands_sh") then
			self:Give("weapon_hands_sh")
		end
		self:SelectWeapon("weapon_hands_sh")

		-- эффекты навыков после того, как homigrad выставит хитбокс игрока при спавне (у босса навыков нет)
		if info.boss then
			-- пули попадают по хитбоксам модели, масштаб модели сеть передает сама (хулл движения не трогаем)
			self:SetModelScale(info.modelScale or 1, 0)
			return
		end

		timer.Simple(0.2, function()
			if IsValid(self) and self.PlayerClassName == className then
				hook.Run("ZS_ApplySkillEffects", self)
			end
		end)
	end

	function CLASS.Off(self)
		if CLIENT then return end

		if info.boss then self:SetModelScale(1, 0) end

		self:SetMaterial("")
		self:SetNWString("ZS_Visual", "")
		self.MeleeDamageMul = nil

		hook.Run("ZS_ClearSkillEffects", self)

		hg.ClearArmorRestrictions(self)
	end

	function CLASS.Think(self)
		if CLIENT then return end

		if self:GetMaterial() ~= "NULL" then
			self:SetMaterial("NULL")
		end

		-- зараженные дерутся только руками, кулаки всегда подняты
		local wep = self:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() ~= "weapon_hands_sh" then
			if not self:HasWeapon("weapon_hands_sh") then
				self:Give("weapon_hands_sh")
			end
			self:SelectWeapon("weapon_hands_sh")
		elseif IsValid(wep) and wep.GetFists and not wep:GetFists() and not (wep.GetCarrying and wep:GetCarrying()) then
			wep:SetFists(true)
		end

		local org = self.organism
		if not org then return end

		org.stamina["max"] = self.zs_StaminaMax or 200
		org.stamina["range"] = self.zs_StaminaMax or 200

		if org.consciousness <= 0.3 then
			org.consciousness = 1
			org.needotrub = false
		end

		org.jawdislocation = false
		org.llegdislocation = false
		org.rlegdislocation = false
		org.rarmdislocation = false
		org.larmdislocation = false
	end
end

function ZS_ZombieSound(ply, kind)
	local info = ZS_ClassInfo(ply.PlayerClassName)
	local list = info and info.sounds and info.sounds[kind]
	return list and list[math.random(#list)]
end

-- фразы и стоны звучат голосом зомби своего класса
hook.Add("HG_ReplacePhrase", "ZS_ZombiePhrases", function(ply, phrase, muffed, pitch)
	if ZS_IsZombie(ply) then
		local inpain = ply.organism and ply.organism.pain > 30
		local phr = ZS_ZombieSound(ply, inpain and "pain" or "idle")
		if not phr or not string.EndsWith(phr, ".wav") then phr = ZS_ZombieSound(ply, "idle") end

		return ply, phr, not inpain, pitch
	end
end)

hook.Add("HG_CanThoughts", "ZS_ZombieThoughts", function(ply)
	if ZS_IsZombie(ply) then
		return false
	end
end)

-- зараженные не теряют сознание (lua/homigrad/organism/tier_1/sv_organism.lua)
hook.Add("HG_CanBeUnconscious", "ZS_ZombieNoUnconscious", function(ply)
	if ZS_IsZombie(ply) then return false end
end)

hook.Add("PlayerCanPickupWeapon", "ZS_ZombiePickup", function(ply, ent)
	if ZS_IsZombie(ply) and ent:GetClass() ~= "weapon_hands_sh" then
		return false
	end
end)

-- зараженные не обыскивают контейнеры и трупы (E+M2 у них занято способностями)
hook.Add("ZB_CanLootInventory", "ZS_ZombieLoot", function(ply, ent)
	if ZS_IsZombie(ply) then
		return ply, ent, false
	end
end)

-- зараженные не открывают двери (выбить дверь когтями по-прежнему можно)
hook.Add("PlayerUse", "ZS_ZombieDoors", function(ply, ent)
	if ZS_IsZombie(ply) and IsValid(ent) and hgIsDoor and hgIsDoor(ent) then
		return false
	end
end)

hook.Add("CanPlayerEnterVehicle", "ZS_ZombieVehicle", function(ply, ent)
	if ZS_IsZombie(ply) then
		return false
	end
end)

hook.Add("PlayerCanLegAttack", "ZS_ZombieKick", function(ply)
	if ZS_IsZombie(ply) then
		return false
	end
end)

hook.Add("HG_MovementCalc_2", "ZS_ZombieSpeed", function(mul, ply, cmd, mv)
	if not ZS_IsZombie(ply) then return end

	local info = ZS_ClassInfo(ply.PlayerClassName)
	mul[1] = info.speed * ply:GetNWFloat("ZS_SpeedMul", 1) * (ply:IsSprinting() and 1.2 or 0.9)

	if ply.SpeedGainMul ~= 70 then
		ply.SpeedGainMul = 70
	end
end)

hook.Add("CalcMainActivity", "ZS_ZombieAnims", function(ply, vel)
	if not ZS_IsZombie(ply) then return end

	-- босс: скрытая модель стоит прямо, чтобы ее хитбоксы совпадали с моделью гонома (cl_zs_boss.lua)
	local info = ZS_ClassInfo(ply.PlayerClassName)
	if info.boss then
		local anim = vel:Length2DSqr() > 400 and ACT_HL2MP_RUN or ACT_HL2MP_IDLE
		if not ply:IsOnGround() and ply:GetMoveType() ~= MOVETYPE_NOCLIP then anim = ACT_HL2MP_JUMP_SLAM end

		return anim, -1
	end

	local anim = ACT_HL2MP_RUN_ZOMBIE
	if vel:LengthSqr() <= 0 then
		anim = ACT_HL2MP_IDLE_ZOMBIE
	elseif ply.PlayerClassName == "zs_agile" and vel:Length2DSqr() >= 40000 then
		anim = ACT_HL2MP_RUN_ZOMBIE_FAST
	end
	if ply:IsFlagSet(FL_ANIMDUCKING) then
		anim = ACT_HL2MP_WALK_CROUCH_ZOMBIE_01
	end
	if not ply:IsOnGround() and ply:GetMoveType() ~= MOVETYPE_NOCLIP then
		anim = ACT_HL2MP_JUMP_SLAM
	end

	return anim, -1
end)

if SERVER then
	-- шаги ванильного зомби своего класса; навык "стопные наросты" делает их беззвучными
	hook.Add("HG_PlayerFootstep", "ZS_ZombieFootsteps", function(ply, pos, foot)
		if not ZS_IsZombie(ply) or not ply:Alive() then return end
		if ZS_HasSkill(ply, "foot_growths") then return true end

		local info = ZS_ClassInfo(ply.PlayerClassName)
		local sounds = info.sounds or {}
		local chr = hg.GetCurrentCharacter(ply)
		local list = sounds.steps

		if sounds.scuffs and math.random() < 0.15 then
			list = sounds.scuffs
		end

		if list then
			local snd = (#list == 2 and list[foot == 0 and 1 or 2]) or list[math.random(#list)]
			chr:EmitSound(snd, (ply:Crouching() or ply:KeyDown(IN_WALK)) and 60 or 70, math.random(95, 105))
		end

		return true
	end)

	-- боль и смерть голосом своего класса
	hook.Add("HomigradDamage", "ZS_ZombiePainSound", function(ent, dmgInfo)
		local ply = IsValid(ent) and (ent:IsPlayer() and ent or hg.RagdollOwner(ent))
		if not ZS_IsZombie(ply) or not ply:Alive() then return end
		if (ply.zs_NextPainSound or 0) > CurTime() then return end

		local snd = ZS_ZombieSound(ply, "pain")
		if not snd then return end

		ply.zs_NextPainSound = CurTime() + math.Rand(0.5, 0.9)
		hg.GetCurrentCharacter(ply):EmitSound(snd, 75, math.random(95, 105))
	end)

	hook.Add("DoPlayerDeath", "ZS_ZombieDeathSound", function(ply)
		if not ZS_IsZombie(ply) then return end

		local snd = ZS_ZombieSound(ply, "death")
		if snd then ply:EmitSound(snd, 80, math.random(95, 105)) end
	end)

	resource.AddFile("models/player/zombie_classic_hbfix.mdl")
	resource.AddFile("models/weapons/v_zombiearms.mdl")
	resource.AddFile("models/weapons/v_fza.mdl")
	resource.AddFile("models/weapons/v_pza.mdl")

	for _, mat in ipairs({
		"models/weapons/v_zombiearms/zombie_classic_sheet", "models/weapons/v_zombiearms/ghoulsheet",
		"models/weapons/v_fza/fast_zombie_sheet",
		"models/weapons/v_pza/poisonzombie_sheet", "models/weapons/v_pza/blackcrab_sheet", "models/weapons/v_pza/hairs",
	}) do
		resource.AddFile("materials/" .. mat .. ".vmt")
	end

	for _, tex in ipairs({
		"models/weapons/v_zombiearms/zombie_classic_sheet_normal", "models/weapons/v_fza/fast_zombie_sheet_normal",
		"models/weapons/v_pza/poisonzombie_sheet_normal", "models/weapons/v_pza/blackcrab_sheet_normal",
	}) do
		resource.AddSingleFile("materials/" .. tex .. ".vtf")
	end

	hook.Add("ZB_CanLootInventory", "ZS_ZombieLoot", function(ply, ent, canloot)
		if ZS_IsZombie(ply) then
			return ply, ent, false
		end
	end)

	-- регдолл (падение или смерть) получает ту же ванильную модель поверх
	hook.Add("Ragdoll_Create", "ZS_ZombieRagdollVisual", function(ply, ragdoll)
		if not IsValid(ply) or not IsValid(ragdoll) or not ZS_IsZombie(ply) then return end

		ragdoll:SetMaterial("NULL")
		ragdoll:SetNWString("ZS_Visual", ply:GetNWString("ZS_Visual"))
		ragdoll:SetNWBool("ZS_Black", ply:GetNWBool("ZS_Black", false))
		ragdoll:SetNWBool("ZS_Gray", ply:GetNWBool("ZS_Gray", false))
		ragdoll:SetNWBool("ZS_Green", ply:GetNWBool("ZS_Green", false))
		ragdoll:SetNWBool("ZS_BigArms", ply:GetNWBool("ZS_BigArms", false))
	end)

	-- живучесть класса
	hook.Add("PreHomigradDamage", "ZS_ZombieDamageTaken", function(ent, dmgInfo)
		local ply = IsValid(ent) and (ent:IsPlayer() and ent or hg.RagdollOwner(ent))
		if not ZS_IsZombie(ply) then return end

		dmgInfo:ScaleDamage(ZS_ClassInfo(ply.PlayerClassName).damageTaken * (ply.zs_DamageTakenMul or 1))
	end)

	local function HealOrganism(org, amount)
		org.blood = math.Approach(org.blood, 5000, amount * 60)
		org.pain = math.max((org.pain or 0) - amount * 2, 0)

		for _, wound in pairs(org.wounds or {}) do
			wound[1] = math.max(wound[1] - amount * 0.6, 0)
		end

		for _, wound in pairs(org.arterialwounds or {}) do
			wound[1] = math.max(wound[1] - amount * 0.6, 0)
		end

		org.internalBleed = math.max((org.internalBleed or 0) - amount * 0.6, 0)
	end

	-- хилер раз в секунду лечит себя и зараженных рядом
	local nextHeal = 0
	hook.Add("Think", "ZS_MetaboliserHeal", function()
		if nextHeal > CurTime() then return end
		nextHeal = CurTime() + 1

		local radius = ZS_ZOMBIE_CLASSES.zs_metaboliser.healRadius

		for _, healer in player.Iterator() do
			if not healer:Alive() or healer.PlayerClassName ~= "zs_metaboliser" then continue end

			for _, ply in ipairs(ents.FindInSphere(healer:GetPos(), radius)) do
				if ply:IsPlayer() and ply:Alive() and ZS_IsZombie(ply) and ply.organism then
					HealOrganism(ply.organism, 1)
				end
			end
		end
	end)
else
	local hg_thirdperson = GetConVar("hg_thirdperson")

	local function ApplyVisual(ent, mdl, visual)
		if not IsValid(visual) or string.lower(visual:GetModel() or "") ~= string.lower(mdl) then
			if IsValid(visual) then visual:Remove() end

			visual = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
			if not IsValid(visual) then return end

			for i = 1, visual:GetNumBodyGroups() - 1 do
				visual:SetBodygroup(i, 0) -- без хедкрабов
			end
		end

		if visual:GetParent() ~= ent then
			visual:SetPos(ent:GetPos())
			visual:SetParent(ent)
			visual:AddEffects(EF_BONEMERGE)
			visual:AddEffects(EF_BONEMERGE_FASTCULL)
		end

		return visual
	end

	local tracked = {}
	local nextScan = 0
	local colBlack = Color(12, 12, 12)
	local colGray = Color(140, 140, 140)
	local colGreen = Color(90, 200, 70)
	local colFrozen = Color(150, 200, 255)
	local vecNormal, vecBigArms = Vector(1, 1, 1), Vector(1.35, 1.35, 1.35)
	local armBones = {
		"ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand",
		"ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand",
	}

	local function ScanVisuals()
		for _, ent in player.Iterator() do
			if ent:GetNWString("ZS_Visual", "") ~= "" then tracked[ent] = tracked[ent] or false end
		end

		for _, ent in ipairs(ents.FindByClass("prop_ragdoll")) do
			if ent:GetNWString("ZS_Visual", "") ~= "" then tracked[ent] = tracked[ent] or false end
		end
	end

	-- ванильная модель поверх скрытой игровой модели; свою модель в первом лице не рисуем
	hook.Add("Think", "ZS_ZombieVisuals", function()
		if nextScan < CurTime() then
			nextScan = CurTime() + 0.5
			ScanVisuals()
		end

		for ent, visual in pairs(tracked) do
			if not IsValid(ent) or ent:GetNWString("ZS_Visual", "") == "" then
				if IsValid(visual) then visual:Remove() end
				tracked[ent] = nil
			end
		end

		for ent, oldVisual in pairs(tracked) do
			local visual = ApplyVisual(ent, ent:GetNWString("ZS_Visual"), oldVisual)
			tracked[ent] = visual or false
			if not IsValid(visual) then continue end

			local hide = ent:IsDormant()

			if ent:IsPlayer() then
				hide = hide or not ent:Alive() or IsValid(ent.FakeRagdoll)
				hide = hide or (ent == LocalPlayer() and GetViewEntity() == ent and not (hg_thirdperson and hg_thirdperson:GetBool()))
			end

			visual:SetNoDraw(hide)

			-- автолиз: гниющая черная плоть, фибродисплазия: костная серая
			if ent:GetNWFloat("ZS_FrozenUntil", 0) > CurTime() then
				-- заморожен азотной гранатой
				visual:SetColor(colFrozen)
			elseif ent:GetNWBool("ZS_Black", false) then
				visual:SetColor(colBlack)
			elseif ent:GetNWBool("ZS_Gray", false) then
				visual:SetColor(colGray)
			elseif ent:GetNWBool("ZS_Green", false) then
				visual:SetColor(colGreen)
			else
				visual:SetColor(color_white)
			end

			-- анаболический форсаж: увеличенные руки от третьего лица
			local armScale = ent:GetNWBool("ZS_BigArms", false) and vecBigArms or vecNormal
			if visual.zs_ArmScale ~= armScale then
				visual.zs_ArmScale = armScale

				for _, boneName in ipairs(armBones) do
					local bone = visual:LookupBone(boneName)
					if bone then visual:ManipulateBoneScale(bone, armScale) end
				end
			end
		end
	end)

	-- клешни от первого лица: вьюмодель класса рисуется поверх кадра с собственными анимациями
	local claws = {model = nil, seq = nil, seqStart = 0, loop = true, class = nil}
	local vecHidden = Vector(0, 0, 0)

	local function PlayClawSequence(name, loop)
		local vm = claws.model
		if not IsValid(vm) then return end

		local seq = vm:LookupSequence(name)
		if not seq or seq < 0 then return end

		vm:ResetSequence(seq)
		claws.seq = seq
		claws.seqStart = CurTime()
		claws.loop = loop
	end

	local function UpdateClawModel(info)
		if IsValid(claws.model) and claws.class == info then return claws.model end

		if IsValid(claws.model) then claws.model:Remove() end

		local vm = ClientsideModel(info.viewModel, RENDERGROUP_OPAQUE)
		if not IsValid(vm) then return end

		vm:SetNoDraw(true)

		for _, boneName in ipairs(info.viewModelHiddenBones or {}) do
			local bone = vm:LookupBone(boneName)
			if bone then vm:ManipulateBoneScale(bone, vecHidden) end
		end

		claws.model = vm
		claws.class = info

		PlayClawSequence("draw", false)

		return vm
	end

	hook.Add("ZS_ClawSwing", "ZS_ClawViewModel", function(ply)
		if ply ~= LocalPlayer() or not IsValid(claws.model) then return end

		local hits = {}
		for _, name in ipairs({"hitcenter1", "hitcenter2"}) do
			if claws.model:LookupSequence(name) >= 0 then hits[#hits + 1] = name end
		end

		if #hits > 0 then
			PlayClawSequence(hits[math.random(#hits)], false)
		end
	end)

	hook.Add("Player Spawn", "ZS_ClawViewModelDraw", function(ply)
		if ply == LocalPlayer() and IsValid(claws.model) then
			PlayClawSequence("draw", false)
		end
	end)

	hook.Add("Post Pre Post Processing", "ZS_ClawViewModel", function()
		local ply = LocalPlayer()
		if not IsValid(ply) or not ply:Alive() or not ZS_IsZombie(ply) then return end
		if GetViewEntity() ~= ply or IsValid(ply.FakeRagdoll) or (hg_thirdperson and hg_thirdperson:GetBool()) then return end

		local info = ZS_ClassInfo(ply.PlayerClassName)
		local vm = UpdateClawModel(info)
		if not IsValid(vm) then return end

		-- блок правой кнопкой показываем замахом altfire, иначе возвращаемся в idle
		local wep = ply:GetActiveWeapon()
		local blocking = IsValid(wep) and wep.GetBlocking and wep:GetBlocking()
		local seqName = vm:GetSequenceName(claws.seq or 0)

		if blocking and seqName ~= "altfire" then
			PlayClawSequence("altfire", false)
		end

		local duration = math.max(vm:SequenceDuration(claws.seq or 0), 0.01)
		local frac = (CurTime() - claws.seqStart) / duration

		if frac >= 1 and not claws.loop and not blocking then
			PlayClawSequence("idle01", true)
			frac = 0
		end

		vm:SetCycle(claws.loop and frac % 1 or math.min(frac, 1))

		local view = render.GetViewSetup()

		cam.Start3D(view.origin, view.angles, info.viewModelFOV, 0, 0, ScrW(), ScrH(), 1, 100)
			cam.IgnoreZ(true)
				vm:SetPos(view.origin)
				vm:SetAngles(view.angles)
				vm:SetupBones()

				-- фибродисплазия: серые костные клешни
				if ply:GetNWBool("ZS_Gray", false) then
					render.SetColorModulation(0.55, 0.55, 0.55)
					vm:DrawModel()
					render.SetColorModulation(1, 1, 1)
				else
					vm:DrawModel()
				end
			cam.IgnoreZ(false)
		cam.End3D()
	end)

	-- у модели зомби голова опущена вперед, камеру переносим к верху торса (как у headcrabzombie)
	hook.Add("HGAddView", "ZS_ZombieView", function(ply, origin, angles)
		if not ply:Alive() or not ZS_IsZombie(ply) then return end

		local spine = ply:LookupBone("ValveBiped.Bip01_Spine4")
		if not spine then return end

		local mat = ply:GetBoneMatrix(spine)
		if not mat then return end

		local spineAng = mat:GetAngles()
		origin = origin + spineAng:Right() * -8 + spineAng:Forward() * -2

		return ply, origin, angles
	end)
end
