function gadget:GetInfo()
   return {
      name = "ShardLua",
      desc = "Shard by AF for Spring Lua",
      author = "eronoobos, based on gadget by raaar, and original AI by AF",
      date = "April 2016",
      license = "whatever",
      layer = 999999,
      enabled = true,
   }
end

-- globals
ShardSpringLua = true -- this is the AI Boot gadget, so we're in Spring Lua
VFS.Include("luarules/gadgets/ai/preload/globals.lua")

-- fake os object
os = shard_include("spring_lua/fakeos")

-- missing math function
function math.mod(number1, number2)
	return number1 % number2
end
math.fmod = math.mod

shard_include("behaviourfactory")
shard_include("unit")
shard_include("module")
shard_include("modules")

-- Shard object
Shard = shard_include("spring_lua/shard")
Shard.AIs = {}
Shard.AIsByTeamID = {}
local AIs = Shard.AIs

-- fake api object
api = shard_include("spring_lua/fakeapi")

-- localization
local spEcho = Spring.Echo
local spGetTeamList = Spring.GetTeamList
local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamLuaAI = Spring.GetTeamLuaAI
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetTeamStartPosition = Spring.GetTeamStartPosition
local spGetTeamUnits = Spring.GetTeamUnits
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitTeam = Spring.GetUnitTeam

--SYNCED CODE
if (gadgetHandler:IsSyncedCode()) then

function gadget:Initialize()

	local numberOfmFAITeams = 0
	local teamList = spGetTeamList()

	for i=1,#teamList do
		local id = teamList[i]
		local _,_,_,isAI,side,allyId = spGetTeamInfo(id)
        
		--spEcho("Player " .. teamList[i] .. " is " .. side .. " AI=" .. tostring(isAI))

		---- adding AI
		if (isAI) then
			local aiInfo = spGetTeamLuaAI(id)
			if (string.sub(aiInfo,1,8) == "ShardLua") then
				numberOfmFAITeams = numberOfmFAITeams + 1
				spEcho("Player " .. teamList[i] .. " is " .. aiInfo)
				-- add AI object
				thisAI = VFS.Include("LuaRules/Gadgets/ai/AI.lua")
				thisAI.id = id
				thisAI.allyId = allyId
				thisAI:Init()
				AIs[#AIs+1] = thisAI
				Shard.AIsByTeamID[id] = thisAI
			else
				spEcho("Player " .. teamList[i] .. " is another type of lua AI!")
			end
		end
	end

	-- add allied teams for each AI
	for _,thisAI in ipairs(AIs) do
		alliedTeamIds = {}
		enemyTeamIds = {}
		for i=1,#teamList do
			if (spAreTeamsAllied(thisAI.id,teamList[i])) then
				alliedTeamIds[teamList[i]] = true
			else
				enemyTeamIds[teamList[i]] = true
			end
		end
		-- spEcho("AI "..thisAI.id.." : allies="..#alliedTeamIds.." enemies="..#enemyTeamIds)
		thisAI.alliedTeamIds = alliedTeamIds
		thisAI.enemyTeamIds = enemyTeamIds
	end

	-- catch up to started game
	if Spring.GetGameFrame() > 1 then
		self:GameStart()
	end

	-- catch up to current units
	for _,uId in ipairs(spGetAllUnits()) do
		self:UnitCreated(uId, Spring.GetUnitDefID(uId), Spring.GetUnitTeam(uId))
	end
end

function gadget:GameStart() 
    -- Initialise AIs
    for _,thisAI in ipairs(AIs) do
        local _,_,_,isAI,side = spGetTeamInfo(thisAI.id)
		thisAI.side = side
		local x,y,z = spGetTeamStartPosition(thisAI.id)
		thisAI.startPos = {x,y,z}
    end
end


function gadget:GameFrame(n) 

	-- for each AI...
    for _,thisAI in ipairs(AIs) do
        
        -- update sets of unit ids : own, friendlies, enemies
		thisAI.ownUnitIds = {}
        thisAI.friendlyUnitIds = {}
        thisAI.enemyUnitIds = {}

        for _,uId in ipairs(spGetAllUnits()) do
        	if (spGetUnitTeam(uId) == thisAI.id) then
        		thisAI.ownUnitIds[uId] = true
        	elseif (thisAI.alliedTeamIds[spGetUnitTeam(uId)] or spGetUnitTeam(uId) == thisAI.id) then
        		thisAI.friendlyUnitIds[uId] = true
        	else
        		thisAI.enemyUnitIds[uId] = true
        	end
        end 
	
		-- run AI game frame update handlers
		ai = thisAI
		game = thisAI.game
		map = thisAI.map
		thisAI:Update()
    end
end


function gadget:UnitCreated(unitId, unitDefId, teamId, builderId) 
	-- for each AI...
	local unit = Shard:shardify_unit(unitId)
    for _,thisAI in ipairs(AIs) do
    	if Spring.GetUnitTeam(unitId) == thisAI.id then
	    	ai = thisAI
	    	game = thisAI.game
			map = thisAI.map
			thisAI.map.buildsite.UnitCreated(unitId, unitDefId, teamId)
	    	thisAI:UnitCreated(unit)
	    end
		-- thisAI:UnitCreated(unitId, unitDefId, teamId, builderId)
	end
end

function gadget:UnitDestroyed(unitId, unitDefId, teamId, attackerId, attackerDefId, attackerTeamId) 
	-- for each AI...
	local unit = Shard:shardify_unit(unitId)
	if unit then
		for _,thisAI in ipairs(AIs) do
			ai = thisAI
			game = thisAI.game
			map = thisAI.map
			thisAI.map.buildsite.UnitDestroyed(unitId, unitDefId, teamId)
			thisAI:UnitDead(unit)
			-- thisAI:UnitDestroyed(unitId, unitDefId, teamId, attackerId, attackerDefId, attackerTeamId)
		end
		Shard:unshardify_unit(self.engineUnit)
	end
end


function gadget:UnitDamaged(unitId, unitDefId, unitTeamId, damage, paralyzer, weaponDefId, projectileId, attackerId, attackerDefId, attackerTeamId)
	-- for each AI...
	local unit = Shard:shardify_unit(unitId)
	if unit then
		local attackerUnit = Shard:shardify_unit(attackerId)
		local damageObj = Shard:shardify_damage(damage, weaponDefId, paralyzer)
	    for _,thisAI in ipairs(AIs) do
	    	ai = thisAI
	    	game = thisAI.game
			map = thisAI.map
	    	thisAI:UnitDamaged(unit, attackerUnit, damageObj)
			-- thisAI:UnitDamaged(unitId, unitDefId, unitTeamId, attackerId, attackerDefId, attackerTeamId)
		end	
	end
end

function gadget:UnitIdle(unitId, unitDefId, teamId) 
	-- for each AI...
	local unit = Shard:shardify_unit(unitId)
	if unit then
	    for _,thisAI in ipairs(AIs) do
	    	ai = thisAI
	    	game = thisAI.game
			map = thisAI.map
	    	thisAI:UnitIdle(unit)
			-- thisAI:UnitIdle(unitId, unitDefId, teamId)
		end
	end
end


function gadget:UnitFinished(unitId, unitDefId, teamId) 
	-- for each AI...
	local unit = Shard:shardify_unit(unitId)
	if unit then
	    for _,thisAI in ipairs(AIs) do
			-- thisAI:UnitFinished(unitId, unitDefId, teamId)
			ai = thisAI
			game = thisAI.game
			map = thisAI.map
			thisAI:UnitBuilt(unit)
		end
	end
end

function gadget:UnitTaken(unitId, unitDefId, teamId, newTeamId) 
	-- for each AI...
	local unit = Shard:shardify_unit(unitId)
	if unit then
	    for _,thisAI in ipairs(AIs) do
	    	ai = thisAI
	    	game = thisAI.game
			map = thisAI.map
			thisAI.map.buildsite.UnitDestroyed(unitId, unitDefId, teamId)
			thisAI:UnitTaken(unitId, unitDefId, teamId, newTeamId)
		end
	end
end

function gadget:UnitGiven(unitId, unitDefId, teamId, oldTeamId) 
	-- for each AI...
    for _,thisAI in ipairs(AIs) do
    	ai = thisAI
    	game = thisAI.game
		map = thisAI.map
		thisAI.map.buildsite.UnitCreated(unitId, unitDefId, teamId)
		thisAI:UnitTaken(unitId, unitDefId, teamId, oldTeamId)
	end
end

function gadget:FeatureDestroyed(featureID)
	Shard:unshardify_feature(featureID)
end

function gadget:GameID(gameID)
	if Shard then
		Shard.gameID = gameID
		local rseed = 0
		local unpacked = VFS.UnpackU8(gameID, 1, string.len(gameID))
		for i, part in ipairs(unpacked) do
			-- local mult = 256 ^ (#unpacked-i)
			-- rseed = rseed + (part*mult)
			rseed = rseed + part
		end
		-- Spring.Echo("randomseed", rseed)
		Shard.randomseed = rseed
	end
end

--UNSYNCED CODE
else





end


