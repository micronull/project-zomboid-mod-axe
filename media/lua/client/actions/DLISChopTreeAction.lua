--***********************************************************
--**                    THE INDIE STONE                    **
--***********************************************************

DLISChopTreeAction = ISBaseTimedAction:derive("DLISChopTreeAction")

function DLISChopTreeAction:isValid()
	return (self.tree ~= nil and self.tree:getObjectIndex() >= 0 and
			self.character:CanAttack() and
			self.character:getPrimaryHandItem() ~= nil and
            (self.character:getPrimaryHandItem():getType() == "MakeshiftAxe" or self.character:getPrimaryHandItem():getType() == "WornMakeshiftAxe" or self.character:getPrimaryHandItem():getType() == "BluntMakeshiftAxe"))
end

function DLISChopTreeAction:update()

    self.axe:setJobDelta(self:getJobDelta());
	self.character:PlayAnim("Attack_" .. self.axe:getSwingAnim())
	local val = self.axe:getSwingTime()
	if self.axe:isUseEndurance() then
		local moodleLevel = self.character:getMoodles():getMoodleLevel(MoodleType.Endurance)
		if moodleLevel == 1 then val = val * 1.1
		elseif moodleLevel == 2 then val = val * 1.2
		elseif moodleLevel == 3 then val = val * 1.3
		elseif moodleLevel == 4 then val = val * 1.4 end
	end
	if val < self.axe:getMinimumSwingTime() then
		val = self.axe:getMinimumSwingTime()
	end
	val = val * self.axe:getSpeedMod(self.character)
	local AttackDelayMax = val * 0.6
	local numFrames = self.character:getSpriteDef():getFrameCount()
	local perFrame = numFrames / 60 / AttackDelayMax
	self.character:getSpriteDef():setFrameSpeedPerFrame(perFrame * 2)
	
	self.character:setIgnoreMovementForDirection(false)
	self.character:faceThisObject(self.tree)
	self.character:setIgnoreMovementForDirection(true)

	local AttackDelayUse = 0.3 * numFrames
	if self.spriteFrame < AttackDelayUse and self.character:getSpriteDef():getFrame() >= AttackDelayUse then
		self.tree:WeaponHit(self.character, self.axe)
		if self.tree:getObjectIndex() < 0 then
			self.character:PlayAnimUnlooped("Attack_" .. self.axe:getSwingAnim())
		end
		self:useEndurance()
		if ZombRand(self.axe:getConditionLowerChance() * 2 + self.character:getMaintenanceMod() * 2) == 0 then
			self.axe:setCondition(self.axe:getCondition() - 1)
            ISWorldObjectContextMenu.checkWeapon(self.character);
		else
			self.character:getXp():AddXP(Perks.BladeMaintenance, 1)
		end
	end
	self.spriteFrame = self.character:getSpriteDef():getFrame()
--	self:setJobDelta(1 - self.tree:getHealth() / self.tree:getMaxHealth())
end

function DLISChopTreeAction:start()
    self.axe = self.character:getPrimaryHandItem()
    self.action:setTime((self.tree:getHealth() / self.axe:getTreeDamage()) * 55)
    self.axe:setJobType(getText("ContextMenu_Chop_Tree"));
    self.axe:setJobDelta(0.0);
    self.character:PlayAnim("Attack_" .. self.axe:getSwingAnim())
    self.spriteFrame = self.character:getSpriteDef():getFrame()
end

function DLISChopTreeAction:stop()
	if self.character:getPrimaryHandItem() and self.character:getPrimaryHandItem() == self.axe then
		self.character:PlayAnimUnlooped("Attack_" .. self.axe:getSwingAnim())
	else
		self.character:PlayAnim("Idle")
	end
	self.character:setIgnoreMovementForDirection(false)
    ISBaseTimedAction.stop(self)
    self.axe:setJobDelta(0.0);
end

function DLISChopTreeAction:perform()
    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self)
    self.axe:setJobDelta(0.0);

	if self.character:getPrimaryHandItem() and self.character:getPrimaryHandItem() == self.axe then
		self.character:PlayAnimUnlooped("Attack_" .. self.axe:getSwingAnim())
	else
		self.character:PlayAnim("Idle")
	end
	self.character:setIgnoreMovementForDirection(false)
end

function DLISChopTreeAction:useEndurance()
	if self.axe:isUseEndurance() then
		local use = self.axe:getWeight() * self.axe:getFatigueMod(self.character) * self.character:getFatigueMod() * self.axe:getEnduranceMod() * 0.1
		local useChargeDelta = 1.0
		use = use * useChargeDelta * 0.041
		if self.axe:isTwoHandWeapon() and self.character:getSecondaryHandItem() ~= self.axe then
			use = use + self.axe:getWeight() / 1.5 / 10 / 20
		end
		self.character:getStats():setEndurance(self.character:getStats():getEndurance() - use)
	end
end

function DLISChopTreeAction:new(character, tree)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.tree = tree
	o.stopOnWalk = true
	o.stopOnRun = true
	o.maxTime = 300
	o.spriteFrame = 0
    o.caloriesModifier = 8;
	return o
end


DLChopTreeMenu = {};

DLChopTreeMenu.clearFetch = function()
	tree = nil
end

DLChopTreeMenu.doMenu = function(player, context, worldobjects, test)
	DLChopTreeMenu.clearFetch();
    for i,v in ipairs(worldobjects) do
		if instanceof(v, "IsoTree") and tree == nil then
			tree = v
			local axe = (getSpecificPlayer(player):getInventory():getBestCondition("MakeshiftAxe") or getSpecificPlayer(player):getInventory():getBestCondition("WornMakeshiftAxe") or getSpecificPlayer(player):getInventory():getBestCondition("BluntMakeshiftAxe"))
			local originalAxe = (getSpecificPlayer(player):getInventory():getBestCondition("Axe") or getSpecificPlayer(player):getInventory():getBestCondition("AxeStone"))
			if axe and axe:getCondition() > 0 and (originalAxe == nil or originalAxe:getCondition() == 0) then
				if test == true then return true; end
				context:addOption(getText("ContextMenu_Chop_Tree"), worldobjects, DLChopTreeMenu.onChopTree, getSpecificPlayer(player), tree)
			end
		end
    end
end

DLChopTreeMenu.onChopTree = function(worldobjects, player, tree)
	if tree:getObjectIndex() == -1 then return end
	if luautils.walkAdj(player, tree:getSquare()) then
		local handItem = player:getPrimaryHandItem()
		if not handItem or (handItem:getType() ~= "MakeshiftAxe" and handItem:getType() ~= "WornMakeshiftAxe" and handItem:getType() ~= "BluntMakeshiftAxe") then
			handItem = (player:getInventory():getBestCondition("MakeshiftAxe") or player:getInventory():getBestCondition("WornMakeshiftAxe") or player:getInventory():getBestCondition("BluntMakeshiftAxe"))
			if not handItem or handItem:getCondition() <= 0 then return end
			local primary = true
			local twoHands = not player:getSecondaryHandItem()
			ISTimedActionQueue.add(ISEquipWeaponAction:new(player, handItem, 50, primary, twoHands))
		end
		ISTimedActionQueue.add(DLISChopTreeAction:new(player, tree))
	end
end

Events.OnPreFillWorldObjectContextMenu.Add(DLChopTreeMenu.doMenu);