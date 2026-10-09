-- Облако жидкого азота: белесо-голубой холодный пар, быстро расходится и тает
local colors = {Color(215, 235, 255), Color(190, 220, 255), Color(235, 245, 255)}

function EFFECT:Init(data)
	local pos = data:GetOrigin()
	local radius = data:GetRadius() > 0 and data:GetRadius() or 220

	local emitter = ParticleEmitter(pos)
	if not emitter then return end

	for _ = 1, 48 do
		local dir = VectorRand()
		dir.z = math.abs(dir.z) * 0.4
		dir:Normalize()

		local particle = emitter:Add("particle/smokesprites_000" .. math.random(9), pos)
		if particle then
			local col = colors[math.random(#colors)]
			particle:SetVelocity(dir * math.Rand(radius * 1.2, radius * 2.2))
			particle:SetAirResistance(220)
			particle:SetGravity(Vector(0, 0, -30))
			particle:SetDieTime(math.Rand(1.2, 2.2))
			particle:SetStartAlpha(200)
			particle:SetEndAlpha(0)
			particle:SetStartSize(math.Rand(20, 40))
			particle:SetEndSize(math.Rand(90, 140))
			particle:SetRoll(math.Rand(0, 360))
			particle:SetRollDelta(math.Rand(-1, 1))
			particle:SetColor(col.r, col.g, col.b)
			particle:SetCollide(true)
		end
	end

	-- ледяные искорки
	for _ = 1, 24 do
		local particle = emitter:Add("effects/spark", pos)
		if particle then
			particle:SetVelocity(VectorRand() * math.Rand(100, 300))
			particle:SetAirResistance(100)
			particle:SetDieTime(math.Rand(0.4, 0.8))
			particle:SetStartAlpha(255)
			particle:SetEndAlpha(0)
			particle:SetStartSize(math.Rand(1, 2))
			particle:SetEndSize(0)
			particle:SetColor(170, 220, 255)
		end
	end

	emitter:Finish()

	local light = DynamicLight(math.random(10000, 20000))
	if light then
		light.pos = pos
		light.r, light.g, light.b = 150, 200, 255
		light.brightness = 2
		light.decay = 600
		light.size = radius
		light.dietime = CurTime() + 0.5
	end
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
