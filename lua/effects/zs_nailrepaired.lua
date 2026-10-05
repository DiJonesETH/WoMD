-- Искры починки баррикады (порт эффекта nailrepaired из JetBoom/zombiesurvival)
function EFFECT:Init(data)
	local pos = data:GetOrigin()
	local norm = data:GetNormal()
	local magnitude = data:GetMagnitude()
	local norepair = magnitude == 0

	local emitter = ParticleEmitter(pos)
	if not emitter then return end

	for _ = 1, math.random(16, 24) do
		local particle = emitter:Add("sprites/glow04_noz", pos)
		if particle then
			particle:SetVelocity((norm + VectorRand()):GetNormalized() * math.Rand(8, 24))
			particle:SetAirResistance(8)
			if norepair then
				particle:SetColor(255, 0, 0)
				particle:SetEndSize(2)
			else
				particle:SetColor(0, 255, 0)
				particle:SetEndSize(math.Rand(2, 3) * math.max(magnitude, 0.1))
			end
			particle:SetDieTime(math.Rand(0.2, 0.5))
			particle:SetStartSize(0)
			particle:SetStartAlpha(255)
			particle:SetEndAlpha(0)
			particle:SetRoll(math.Rand(0, 360))
			particle:SetRollDelta(math.Rand(-8, 8))
		end
	end

	emitter:Finish()
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
