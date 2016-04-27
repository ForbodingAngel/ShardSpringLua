function gadget:GetInfo()
   return {
      name = "ShardAI",
      desc = "Shard AI by AF",
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
			if (string.sub(aiInfo,1,7) == "ShardAI") then
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

	-- catch up to current units
	for _,thisAI in ipairs(AIs) do
		for _,uId in ipairs(spGetAllUnits()) do
			self:UnitCreated(uId)
			self:UnitFinished(uId)
		end
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
	local unit = Shard:GetUnit(unitId)
    for _,thisAI in ipairs(AIs) do
    	ai = thisAI
    	game = thisAI.game
		map = thisAI.map
    	thisAI:UnitCreated(unit)
		-- thisAI:UnitCreated(unitId, unitDefId, teamId, builderId)
	end
end

function gadget:UnitDestroyed(unitId, unitDefId, teamId, attackerId, attackerDefId, attackerTeamId) 
	-- for each AI...
	local unit = Shard:GetUnit(unitId)
	if unit then
		for _,thisAI in ipairs(AIs) do
			ai = thisAI
			game = thisAI.game
			map = thisAI.map
			thisAI:UnitDestroyed(unit)
			-- thisAI:UnitDestroyed(unitId, unitDefId, teamId, attackerId, attackerDefId, attackerTeamId)
		end
	end
end


function gadget:UnitDamaged(unitId, unitDefId, unitTeamId, damage, paralyzer, weaponDefId, projectileId, attackerId, attackerDefId, attackerTeamId)
	-- for each AI...
	local unit = Shard:GetUnit(unitId)
	if unit then
	    for _,thisAI in ipairs(AIs) do
	    	ai = thisAI
	    	game = thisAI.game
			map = thisAI.map
	    	thisAI:UnitDamaged(unit)
			-- thisAI:UnitDamaged(unitId, unitDefId, unitTeamId, attackerId, attackerDefId, attackerTeamId)
		end	
	end
end

function gadget:UnitIdle(unitId, unitDefId, teamId) 
	-- for each AI...
	local unit = Shard:GetUnit(unitId)
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
	local unit = Shard:GetUnit(unitId)
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
	local unit = Shard:GetUnit(unitId)
	if unit then
	    for _,thisAI in ipairs(AIs) do
	    	ai = thisAI
	    	game = thisAI.game
			map = thisAI.map
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
		thisAI:UnitTaken(unitId, unitDefId, teamId, oldTeamId)
	end
end

function gadget:GameID(gameID)

end

--UNSYNCED CODE
else





end

