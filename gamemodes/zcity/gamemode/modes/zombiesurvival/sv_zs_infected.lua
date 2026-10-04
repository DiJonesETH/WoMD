local MODE = MODE

-- Классы зараженных, скилл-очки, поедание трупов и дерево навыков

local TEAM_SURVIVORS = 0

util.AddNetworkString("zs_openclassmenu")
util.AddNetworkString("zs_chooseclass")
util.AddNetworkString("zs_buyskill")
util.AddNetworkString("zs_skills")

local Infected = {}
MODE.Infected = Infected

local function IsZSRound()
	local mode = CurrentRound()
	return mode and mode.name == "zs"
end

local function SendSkills(ply)
	net.Start("zs_skills")
		net.WriteTable(ply.zs_Skills or {})
	net.Send(ply)
end

local function GrantSkill(ply, id)
	ply.zs_Skills = ply.zs_Skills or {}
	ply.zs_Skills[id] = true
	ply:SetNWBool("ZS_Skill_" .. id, true)

	local tree = MODE.SkillTrees[ply.zs_Class]
	local skill = tree and tree[id]

	if skill and skill.OnBuy then
		skill.OnBuy(ply)
	end

	hook.Run("ZS_ApplySkillEffects", ply)
	SendSkills(ply)
end

function Infected.ClearSkills(ply)
	for id in pairs(MODE:GetAllSkillIds()) do
		ply:SetNWBool("ZS_Skill_" .. id, false)
	end

	ply.zs_Skills = {}
	hook.Run("ZS_ClearSkillEffects", ply)
end

function Infected.Reset()
	for _, ply in player.Iterator() do
		ply.zs_Class = nil
		Infected.ClearSkills(ply)
		hook.Run("ZS_RoundReset", ply)
		ply.zs_EatTarget = nil

		ply:SetNWString("ZS_Class", "")
		ply:SetNWInt("ZS_Points", 0)
		ply:SetNWEntity("ZS_EatTarget", NULL)
		ply:SetNWFloat("ZS_EatEnd", 0)

		SendSkills(ply)
	end
end

function Infected.AddPoints(ply, amount)
	amount = math.floor(amount)
	if amount <= 0 then return end

	ply:SetNWInt("ZS_Points", ply:GetNWInt("ZS_Points", 0) + amount)
end

function Infected.SetClass(ply, class)
	if not ZS_ZOMBIE_CLASSES[class] then return end

	ply.zs_Class = class
	ply:SetNWString("ZS_Class", class)

	-- стартовые навыки класса (например, аутофагия у agile)
	for id, skill in SortedPairs(MODE.SkillTrees[class] or {}) do
		if skill.auto then
			GrantSkill(ply, id)
		end
	end
end

-- true, если класс уже выбран; иначе открывает игроку меню выбора (боты выбирают случайно)
function Infected.EnsureClass(ply)
	if ply.zs_Class then return true end

	if ply:IsBot() then
		Infected.SetClass(ply, ZS_ZOMBIE_CLASS_ORDER[math.random(#ZS_ZOMBIE_CLASS_ORDER)])
		return true
	end

	net.Start("zs_openclassmenu")
	net.Send(ply)

	return false
end

-- выбор класса перманентный на весь подраунд
net.Receive("zs_chooseclass", function(len, ply)
	local class = net.ReadString()

	if not IsZSRound() or ply.zs_Class then return end
	if not ZS_ZOMBIE_CLASSES[class] then return end
	if ply:Team() == TEAM_SURVIVORS or ply:Team() == TEAM_SPECTATOR then return end

	Infected.SetClass(ply, class)

	local info = ZS_ZOMBIE_CLASSES[class]
	zb.GiveRole(ply, info.name, info.color)
end)

net.Receive("zs_buyskill", function(len, ply)
	local skillId = net.ReadString()

	if not IsZSRound() or not ply.zs_Class then return end

	ply.zs_Skills = ply.zs_Skills or {}

	local points = ply:GetNWInt("ZS_Points", 0)
	if not MODE:CanLearnSkill(ply.zs_Skills, ply.zs_Class, skillId, points) then return end

	local skill = MODE.SkillTrees[ply.zs_Class][skillId]
	ply:SetNWInt("ZS_Points", points - (skill.cost or 0))

	GrantSkill(ply, skillId)
	ply:EmitSound("npc/zombie/zombie_alert" .. math.random(3) .. ".wav", 70)
end)

-- 1 очко за 1 хп урона по выжившему
function MODE:HomigradDamage(ent, dmgInfo)
	if zb.ROUND_STATE ~= 1 then return end

	local attacker = dmgInfo:GetAttacker()
	if not ZS_IsZombie(attacker) or not attacker:Alive() then return end

	local victim = IsValid(ent) and (ent:IsPlayer() and ent or hg.RagdollOwner(ent))
	if not IsValid(victim) or not victim:IsPlayer() or victim == attacker then return end
	if victim:Team() ~= TEAM_SURVIVORS or not victim:Alive() then return end

	Infected.AddPoints(attacker, dmgInfo:GetDamage() * self.PointsPerDamage)
end

-- регдоллы погибших игроков можно съесть один раз
function Infected.MarkCorpse(ply)
	timer.Simple(0.1, function()
		if not IsValid(ply) then return end

		local ragdoll = IsValid(ply.RagdollDeath) and ply.RagdollDeath or ply:GetNWEntity("RagdollDeath")
		if not IsValid(ragdoll) or ragdoll.zs_Eaten then return end

		ragdoll.zs_Corpse = true
		ragdoll:SetNWBool("ZS_Corpse", true)
	end)
end

local function IsEdibleCorpse(ent)
	return IsValid(ent) and ent:GetClass() == "prop_ragdoll" and ent.zs_Corpse and not ent.zs_Eaten
end

local function CorpseDistance(ply, ragdoll)
	local eye = ply:EyePos()
	local best = eye:Distance(ragdoll:GetPos())

	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local phys = ragdoll:GetPhysicsObjectNum(i)

		if IsValid(phys) then
			best = math.min(best, eye:Distance(phys:GetPos()))
		end
	end

	return best
end

local function FindCorpse(mode, ply)
	local eye = ply:EyePos()
	local aim = ply:GetAimVector()

	local tr = util.TraceLine({
		start = eye,
		endpos = eye + aim * mode.EatDistance,
		filter = {ply, ply.FakeRagdoll},
		mask = MASK_SHOT,
	})

	if IsEdibleCorpse(tr.Entity) then
		return tr.Entity
	end

	local best, bestDot

	for _, ent in ipairs(ents.FindInSphere(eye, mode.EatDistance)) do
		if not IsEdibleCorpse(ent) then continue end

		local dot = aim:Dot((ent:GetPos() - eye):GetNormalized())

		if dot > 0.6 and (not bestDot or dot > bestDot) then
			best, bestDot = ent, dot
		end
	end

	return best
end

-- труп превращается в скелет: новый регдолл с позами костей старого
local function SkeletonizeCorpse(mode, ragdoll)
	local skeleton = ents.Create("prop_ragdoll")
	if not IsValid(skeleton) then return end

	skeleton:SetModel(mode.SkeletonModel)
	skeleton:SetPos(ragdoll:GetPos())
	skeleton:SetAngles(ragdoll:GetAngles())
	skeleton:Spawn()
	skeleton:Activate()
	skeleton:SetCollisionGroup(COLLISION_GROUP_WEAPON)

	for i = 0, skeleton:GetPhysicsObjectCount() - 1 do
		local phys = skeleton:GetPhysicsObjectNum(i)
		if not IsValid(phys) then continue end

		local boneName = skeleton:GetBoneName(skeleton:TranslatePhysBoneToBone(i))
		local srcBone = boneName and ragdoll:LookupBone(boneName)

		if srcBone then
			local srcPhys = ragdoll:GetPhysicsObjectNum(ragdoll:TranslateBoneToPhysBone(srcBone))

			if IsValid(srcPhys) then
				phys:SetPos(srcPhys:GetPos())
				phys:SetAngles(srcPhys:GetAngles())
			else
				local pos, ang = ragdoll:GetBonePosition(srcBone)

				if pos then
					phys:SetPos(pos)
					phys:SetAngles(ang)
				end
			end
		end

		phys:EnableMotion(true)
		phys:Wake()
	end

	skeleton.zs_Eaten = true
	skeleton:SetNWBool("ZS_Eaten", true)

	ragdoll.zs_Eaten = true
	ragdoll:Remove()

	return skeleton
end

local function StopEating(ply)
	if IsValid(ply.zs_EatTarget) and ply.zs_EatTarget.zs_EatenBy == ply then
		ply.zs_EatTarget.zs_EatenBy = nil
	end

	ply.zs_EatTarget = nil
	ply:SetNWEntity("ZS_EatTarget", NULL)
	ply:SetNWFloat("ZS_EatEnd", 0)
end

local eatSounds = {
	"npc/barnacle/barnacle_crunch2.wav",
	"npc/barnacle/barnacle_crunch3.wav",
	"physics/flesh/flesh_squishy_impact_hard1.wav",
	"physics/flesh/flesh_squishy_impact_hard2.wav",
	"physics/flesh/flesh_squishy_impact_hard3.wav",
	"physics/flesh/flesh_squishy_impact_hard4.wav",
}

-- поедание: удерживать E, глядя на труп, EatTime секунд
local function EatThink(mode, ply)
	local target = ply.zs_EatTarget

	local canEat = zb.ROUND_STATE == 1 and ply:Alive() and ZS_IsZombie(ply) and ply:KeyDown(IN_USE) and not IsValid(ply.FakeRagdoll)

	if not canEat then
		if target then StopEating(ply) end
		return
	end

	if target then
		if not IsEdibleCorpse(target) or target.zs_EatenBy ~= ply or CorpseDistance(ply, target) > mode.EatDistance + 20 then
			StopEating(ply)
			return
		end

		if (ply.zs_NextEatSound or 0) < CurTime() then
			ply.zs_NextEatSound = CurTime() + math.Rand(0.6, 1)
			target:EmitSound(eatSounds[math.random(#eatSounds)], 65, math.random(90, 110))
		end

		if ply:GetNWFloat("ZS_EatEnd", 0) <= CurTime() then
			StopEating(ply)
			SkeletonizeCorpse(mode, target)

			Infected.AddPoints(ply, mode.PointsPerCorpse)
			ply:EmitSound("npc/zombie/zombie_voice_idle" .. math.random(14) .. ".wav", 70)

			if ply.organism then
				ply.organism.blood = math.Approach(ply.organism.blood, 5000, 500)
			end
		end

		return
	end

	local corpse = FindCorpse(mode, ply)
	if not corpse or (IsValid(corpse.zs_EatenBy) and corpse.zs_EatenBy ~= ply) then return end

	corpse.zs_EatenBy = ply
	ply.zs_EatTarget = corpse
	ply:SetNWEntity("ZS_EatTarget", corpse)
	ply:SetNWFloat("ZS_EatEnd", CurTime() + mode.EatTime)
end

MODE.LastEatThink = 0

function MODE:Think()
	if self.LastEatThink > CurTime() then return end
	self.LastEatThink = CurTime() + 0.1

	for _, ply in player.Iterator() do
		if ply.zs_EatTarget or (ZS_IsZombie(ply) and ply:KeyDown(IN_USE)) then
			EatThink(self, ply)
		end
	end
end

hook.Add("PlayerInitialSpawn", "ZS_SyncInfected", function(ply)
	ply.zs_Skills = {}
	ply:SetNWInt("ZS_Points", 0)
	ply:SetNWString("ZS_Class", "")
end)

-- zb_givezombiepoints <количество> [ник] - выдать скилл-очки зараженного (себе, если ник не указан)
concommand.Add("zb_givezombiepoints", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsAdmin() then
		ply:ChatPrint("You don't have access")
		return
	end

	local amount = tonumber(args[1])
	if not amount then
		local msg = "Usage: zb_givezombiepoints <amount> [player]"
		if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
		return
	end

	local targets = {}

	if args[2] then
		targets = player.GetListByName(args[2])
	elseif IsValid(ply) then
		targets = {ply}
	end

	for _, target in ipairs(targets) do
		target:SetNWInt("ZS_Points", math.max(target:GetNWInt("ZS_Points", 0) + math.floor(amount), 0))

		local msg = "Zombie skill points of " .. target:Nick() .. ": " .. target:GetNWInt("ZS_Points", 0)
		if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
	end
end)
