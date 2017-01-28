require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/items/active/weapons/melee/meleeslash.lua"

-- Axe primary attack
-- Extends default melee attack and overrides windup and fire
AxeCleave = MeleeSlash:new()

function AxeCleave:init()
  self.stances.windup.duration = self.fireTime - self.stances.fire.duration

  MeleeSlash.init(self)
  self:setupInterpolation()
end

function AxeCleave:windup(windupProgress)
  self.weapon:setStance(self.stances.windup)

  local windupProgress = windupProgress or 0
  local bounceProgress = 0
  while self.fireMode == "primary" and (self.allowHold ~= false or windupProgress < 1) do
    if windupProgress < 1 then
      windupProgress = math.min(1, windupProgress + (self.dt / self.stances.windup.duration))
      self.weapon.relativeWeaponRotation, self.weapon.relativeArmRotation = self:windupAngle(windupProgress)
    else
      bounceProgress = math.min(1, bounceProgress + (self.dt / self.stances.windup.bounceTime))
      self.weapon.relativeWeaponRotation = self:bounceWeaponAngle(bounceProgress)
      self:setState(self.fire)
    end
    coroutine.yield()
  end

  if windupProgress >= 1.0 then
    if self.stances.preslash then
      self:setState(self.preslash)
    else
      self:setState(self.fire)
    end
  else
    self:setState(self.winddown, windupProgress)
  end
end

function AxeCleave:winddown(windupProgress)
  self.weapon:setStance(self.stances.windup)

  while windupProgress > 0 do
    if self.fireMode == "primary" then
      self:setState(self.windup, windupProgress)
      return true
    end

    windupProgress = math.max(0, windupProgress - (self.dt / self.stances.windup.duration))
    self.weapon.relativeWeaponRotation, self.weapon.relativeArmRotation = self:windupAngle(windupProgress)
    coroutine.yield()
  end
end

function AxeCleave:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  animator.setAnimationState("swoosh", "fire")
  animator.playSound("fire")
  animator.burstParticleEmitter(self.weapon.elementalType .. "swoosh")

-- ******************* FR ADDONS FOR HAMMER SWINGS
  if status.isResource("food") then
    self.foodValue = status.resource("food")
    hungerLevel = status.resource("food")
  else
    self.foodValue = 50
    hungerLevel = 50
  end
    --food defaults
  hungerMax = { pcall(status.resourceMax, "food") }
  hungerMax = hungerMax[1] and hungerMax[2]
  if status.isResource("energy") then
    self.energyValue = status.resource("energy")  --check our Food level
  else
    self.energyValue = 80
  end

  local species = world.entitySpecies(activeItem.ownerEntityId())
  -- Primary hand, or single-hand equip  
  local heldItem = world.entityHandItem(activeItem.ownerEntityId(), activeItem.hand())
  --used for checking dual-wield setups
  local opposedhandHeldItem = world.entityHandItem(activeItem.ownerEntityId(), activeItem.hand() == "primary" and "alt" or "primary")
  local randValue = math.random(100)  -- chance for projectile       
  if not self.meleeCount then self.meleeCount = 0 end
     
  if species == "floran" then  --florans use food when attacking
    if status.isResource("food") then
      status.modifyResource("food", (status.resource("food") * -0.01) )
    end
  end

  if species == "glitch" then  --glitch consume energy when wielding axes and hammers. They get increased critChance as a result
    if not self.critValueGlitch then
      self.critValueGlitch = ( math.ceil(self.energyValue/8) ) 
    end  
    if self.energyValue >= 25 then
      if status.isResource("food") then
        adjustedHunger = hungerLevel - (hungerLevel * 0.01)
        status.setResource("food", adjustedHunger)      
      end        
      status.setPersistentEffects("glitchEnergyPower", {
        { stat = "critChance", amount = self.critValueGlitch }
      })     
    end
  end
-- ***********************************************

  util.wait(self.stances.fire.duration, function()
      local damageArea = partDamageArea("swoosh")
      self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)
    end)

  self.cooldownTimer = self:cooldownTime()
end

function AxeCleave:setupInterpolation()
  for i, v in ipairs(self.stances.windup.bounceWeaponAngle) do
    v[2] = interp[v[2]]
  end
  for i, v in ipairs(self.stances.windup.weaponAngle) do
    v[2] = interp[v[2]]
  end
  for i, v in ipairs(self.stances.windup.armAngle) do
    v[2] = interp[v[2]]
  end
end

function AxeCleave:bounceWeaponAngle(ratio)
  return util.toRadians(interp.ranges(ratio, self.stances.windup.bounceWeaponAngle))
end

function AxeCleave:windupAngle(ratio)
  local weaponRotation = interp.ranges(ratio, self.stances.windup.weaponAngle)
  local armRotation = interp.ranges(ratio, self.stances.windup.armAngle)

  return util.toRadians(weaponRotation), util.toRadians(armRotation)
end

function HammerSmash:uninit()
  status.clearPersistentEffects("glitchEnergyPower")
  status.clearPersistentEffects("floranFoodPowerBonus")
  status.clearPersistentEffects("apexbonusdmg")
  self.blockCount = 0
end

