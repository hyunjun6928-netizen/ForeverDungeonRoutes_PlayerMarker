local ADDON = ...

-- Player Marker for Forever Dungeon Routes (an unofficial plugin; Forever Dungeon Routes is by
-- Checkov23): the player's marker inside dungeons, on that addon's map.
--
-- Forever Dungeon Routes draws the player on its map wherever the game tells the position
-- (DR:LocatePlayer, MapView's UpdateGroup). Inside dungeons the game tells none, so the marker
-- never shows there. This plugin fills that gap with what the game does tell:
--   * the room the player is in (DR.Room, from the subzone text): the marker sits in its middle;
--   * a boss fight starts or ends: the player stands at that boss of the route;
--   * the player came in through a loading screen: they stand where the route starts.
-- Between these the last place stays, drawn faint once the game stops naming the room or the
-- player has walked on for a while. It is an estimate, as exact as a room.
--
-- Nothing of the addon is changed on disk: the plugin wraps DR.LocatePlayer and looks at the marker
-- after MapView's UpdateGroup has drawn it. Any error in here switches the plugin off and the addon
-- runs on as its author wrote it.

local DR = ForeverDungeonRoutes
-- the addon as this plugin knows it (1.2.x); with anything else it stays out of the way
if type(DR) ~= "table" or type(DR.LocatePlayer) ~= "function" or type(DR.On) ~= "function"
	or type(DR.MapView) ~= "table" or type(DR.MapView.UpdateGroup) ~= "function" or type(DR.Room) ~= "table"
	or type(DR.Print) ~= "function" or not DR.L or not hooksecurefunc then
	return
end
-- once only (the same file can also sit inside the addon's own folder)
if DR.PlayerMarker then return end
DR.PlayerMarker = ADDON

local L = DR.L
if GetLocale() == "koKR" then
	L["Player marker switched off after an error: %s"] = "내 위치 표시를 껐습니다 (오류): %s"
end

-- A place taken from a boss fight or the entrance counts as left behind after this many seconds of
-- walking (about 40 yards on foot).
local WALK_LIMIT = 6
-- A loading screen can take a while; an entry counts as fresh this long after the world was left.
local ZONING_FRESH = 600
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"

local broken = false -- an error happened: hand out only what the addon itself knows
local served         -- the estimate the last DR:LocatePlayer handed out (nil: the addon's own answer)
local zoning         -- GetTime() when the world was last left in this session: a loading screen is under way
local moving, movingSince, walked = false, nil, 0

local function fail(err)
	if broken then return end
	broken = true
	served = nil
	DR:Print(L["Player marker switched off after an error: %s"], tostring(err))
end

-- Runs fn; an error switches the plugin off instead of reaching the addon.
local function guard(fn, ...)
	if broken or not DR.cdb then return end
	local ok, err = pcall(fn, ...)
	if not ok then fail(err) end
end

-- The estimate -------------------------------------------------------------------------------------
-- store().estimate = { key, kind, ref, floor, u, v, drive, stale }
--   kind   "room" (ref: the room's English name), "boss" (ref: stop index) or "door"
--   drive  the map may turn to the estimate's level by itself: true while the game still tells the
--          place (the named room, a fight under way, a fresh entry); false once it is only the last
--          place seen, which shows on its own level but does not pull the map there
--   stale  left behind: drawn faint


-- Where the estimate is kept, so that it is still there after /reload: the plugin's own saved
-- variable (per character). As a file inside the addon's folder it has none of its own and uses
-- the addon's.
local function store()
	if ADDON == "ForeverDungeonRoutes" then return DR.cdb end
	if type(ForeverDungeonRoutesPlayerMarkerDB) ~= "table" then
		ForeverDungeonRoutesPlayerMarkerDB = {}
	end
	return ForeverDungeonRoutesPlayerMarkerDB
end

local function get()
	local e = DR.cdb and store().estimate
	if e and DR.currentKey and e.key == DR.currentKey then return e end
	return nil
end

local function set(key, kind, ref, floor, u, v, drive)
	if not key or not floor or not u or not v then return end
	store().estimate = { key = key, kind = kind, ref = ref, floor = floor, u = u, v = v, drive = drive and true or false }
	walked = 0
	movingSince = moving and GetTime() or nil
end

local function leaveBehind(e)
	e.stale, e.drive = true, false
end

-- The middle of a room; on the level given if the room lies there, else on the level that shows
-- most of it (the same choice the addon makes for its map).
local function placeInRoom(key, room, floorHint)
	local floor = floorHint and DR.Room:OnFloor(room, floorHint) and floorHint or DR.Room:MainFloor(room)
	local u, v = DR.Room:Center(room, floor)
	set(key, "room", room.name, floor, u, v, true)
end

-- The game names a room (or none any more).
local function onRoom(room)
	local key = DR.currentKey
	if not key then return end
	local e = get()
	if room then
		-- a fight or the entrance in this very room placed the player more exactly: that holds until
		-- they walk on
		if e and e.kind ~= "room" and not e.stale and DR.Room:At(key, e.floor, e.u, e.v) == room then return end
		placeInRoom(key, room, e and e.floor)
	elseif e and e.kind == "room" then
		leaveBehind(e)
	end
end

-- The stop of the active route a reported fight belongs to (the last one with last = true: two
-- bosses of a route can be one fight). Returns the stop and its index.
local function stopFor(key, encounterID, encounterName, last)
	local route = key and DR:GetActiveRoute(key)
	if not route then return nil end
	local found, foundIndex
	for index, stop in ipairs(route.stops) do
		local match = false
		if stop.encounters then
			for _, id in ipairs(stop.encounters) do
				if id == encounterID then match = true end
			end
		elseif encounterName and (stop.name == encounterName or DR.LocText(stop, "name") == encounterName) then
			match = true
		end
		if match and stop.floor and stop.x and stop.y then
			found, foundIndex = stop, index
			if not last then break end
		end
	end
	return found, foundIndex
end

-- A boss fight started (drive: the map may follow) or ended with a kill.
local function atBoss(encounterID, encounterName, killed)
	encounterID, encounterName = DR.Safe(encounterID), DR.Safe(encounterName)
	if type(encounterID) ~= "number" then return end
	if type(encounterName) ~= "string" then encounterName = nil end
	local key = DR.currentKey
	if not key then return end
	local stop, index = stopFor(key, encounterID, encounterName, killed)
	if not stop then
		-- a boss of another wing of the instance: the addon switches to that wing with the kill, and
		-- the place is ready for it then
		for _, wing in ipairs(DR:GetDungeonsForInstance(DR.currentInstanceID)) do
			if wing.key ~= key and not stop then
				stop, index = stopFor(wing.key, encounterID, encounterName, killed)
				if stop then key = wing.key end
			end
		end
	end
	if stop then
		set(key, "boss", index, stop.floor, stop.x, stop.y, not killed)
	end
end

-- Where the routes of a dungeon start. With two doors (Maraudon, Stratholme) nobody knows which
-- one the player took.
local function entrance(key)
	local doors = {}
	for _, route in ipairs(DR:GetBuiltInRoutes(key)) do
		local first
		for _, path in ipairs(route.paths or {}) do
			if path.kind == "main" and path.pts and #path.pts >= 2 and (not first or (path.t0 or 0) < (first.t0 or 0)) then
				first = path
			end
		end
		if first then
			local known = false
			for _, door in ipairs(doors) do
				if door.floor == first.floor and math.abs(door.x - first.pts[1]) + math.abs(door.y - first.pts[2]) < 0.03 then
					known = true
				end
			end
			if not known then
				doors[#doors + 1] = { floor = first.floor, x = first.pts[1], y = first.pts[2] }
			end
		end
	end
	if #doors == 1 then return doors[1] end
	return nil
end

-- The addon found the dungeon the player is in (or that they left).
local function onDungeon(key)
	local db = store()
	if not key then
		db.estimate = nil
		return
	end
	local fresh = zoning ~= nil and (GetTime() - zoning) < ZONING_FRESH
	zoning = nil
	local old = db.estimate
	if fresh then
		-- through a loading screen from outside: the player stands at the entrance
		db.estimate = nil
		local door = entrance(key)
		if door then
			set(key, "door", nil, door.floor, door.x, door.y, true)
		end
	elseif old and old.key ~= key then
		db.estimate = nil -- another wing; after login or /reload the place of before holds
	end
	local room = DR.Room:Get()
	if room then
		onRoom(room)
	end
end

-- Walking on: a place from a fight or the entrance does not hold for long.
local function walkedFor()
	local total = walked
	if moving and movingSince then
		total = total + (GetTime() - movingSince)
	end
	return total
end

local function checkWalk()
	local e = get()
	if not e or e.stale or e.kind == "room" then return end
	if walkedFor() < WALK_LIMIT then return end
	local room = DR.Room:Get()
	if room then
		placeInRoom(e.key, room, e.floor)
	else
		leaveBehind(e)
	end
end

-- What the map gets to know ------------------------------------------------------------------------

-- The estimate for a call of DR:LocatePlayer, or nil where the map should not show one.
local function estimateFor(key, preferredFloor)
	local e = get()
	if not e or e.key ~= key then return nil end
	if e.kind == "room" and not e.stale and preferredFloor and preferredFloor ~= e.floor then
		-- a room that lies on several map levels shows on the level the map is on
		local room = DR.Room:Get()
		if room and room.name == e.ref and DR.Room:OnFloor(room, preferredFloor) then
			local u, v = DR.Room:Center(room, preferredFloor)
			if u then
				e.floor, e.u, e.v = preferredFloor, u, v
			end
		end
	end
	if e.drive or preferredFloor == e.floor then return e end
	return nil
end

local locate = DR.LocatePlayer
-- Where the player is: dungeon key, floor and map coordinates. The addon's own answer where the
-- game reveals the position; inside dungeons the estimate.
function DR:LocatePlayer(preferredFloor)
	local key, floor, u, v = locate(self, preferredFloor)
	served = nil
	if broken or floor or not key or not self.cdb then
		return key, floor, u, v
	end
	local ok, e = pcall(estimateFor, key, preferredFloor)
	if not ok then
		fail(e)
		return key
	end
	if not e then return key end
	served = e
	return key, e.floor, e.u, e.v
end

-- The marker: the addon's own dot and ring; a soft wave around it while the place is current, faint
-- once it is left behind.
local function style(view)
	local player = view.player
	if not player then return end
	local e = player:IsShown() and served or nil
	if not e then
		if player.EstimateWave then
			player.EstimatePulse:Stop()
			player.EstimateWave:Hide()
			player:SetAlpha(1)
		end
		return
	end
	if not player.EstimateWave then
		local wave = player:CreateTexture(nil, "BACKGROUND")
		wave:SetTexture(MEDIA .. "ring")
		wave:SetSize(46, 46)
		wave:SetPoint("CENTER", 0, 0)
		wave:SetVertexColor(1, 0.9, 0.4)
		local pulse = wave:CreateAnimationGroup()
		local grow = pulse:CreateAnimation("Scale")
		grow:SetScaleFrom(0.35, 0.35)
		grow:SetScaleTo(1.1, 1.1)
		grow:SetOrigin("CENTER", 0, 0)
		grow:SetDuration(1.3)
		local fade = pulse:CreateAnimation("Alpha")
		fade:SetFromAlpha(0.9)
		fade:SetToAlpha(0)
		fade:SetDuration(1.3)
		pulse:SetLooping("REPEAT")
		player.EstimateWave, player.EstimatePulse = wave, pulse
	end
	if e.stale then
		player:SetAlpha(0.5)
		player.EstimatePulse:Stop()
		player.EstimateWave:Hide()
	else
		player:SetAlpha(1)
		player.EstimateWave:Show()
		if not player.EstimatePulse:IsPlaying() then
			player.EstimatePulse:Play()
		end
	end
end

hooksecurefunc(DR.MapView, "UpdateGroup", function(view)
	if broken then return end
	local ok, err = pcall(style, view)
	if not ok then fail(err) end
end)

-- What happens in the game ---------------------------------------------------------------------------

DR:On("ROOM_CHANGED", function(room) guard(onRoom, room) end)
DR:On("DUNGEON_CHANGED", function(key) guard(onDungeon, key) end)
-- The addon reports a kill before it ticks the boss off. Right away the fight's place stops pulling
-- the map: with the tick the addon turns the map to the level of the next boss, and that is to
-- stay. The place itself is set anew a moment later, after the addon has ticked the boss off and,
-- for a boss of another wing, switched to that wing.
DR:On("BOSS_KILLED", function(encounterID, encounterName)
	guard(function()
		local e = get()
		if e and e.kind == "boss" then
			e.drive = false
		end
	end)
	C_Timer.After(0, function() guard(atBoss, encounterID, encounterName, true) end)
end)

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("ENCOUNTER_START")
-- not every client knows these two; without them a place from a fight holds until the next room
pcall(frame.RegisterEvent, frame, "PLAYER_STARTED_MOVING")
pcall(frame.RegisterEvent, frame, "PLAYER_STOPPED_MOVING")
frame:SetScript("OnEvent", function(_, event, arg1, arg2)
	if event == "PLAYER_LEAVING_WORLD" then
		zoning = GetTime()
	elseif event == "ENCOUNTER_START" then
		guard(atBoss, arg1, arg2, false)
	elseif event == "PLAYER_STARTED_MOVING" then
		moving, movingSince = true, GetTime()
	elseif event == "PLAYER_STOPPED_MOVING" then
		if moving and movingSince then
			walked = walked + (GetTime() - movingSince)
		end
		moving, movingSince = false, nil
		guard(checkWalk)
	end
end)

local sinceTick = 0
frame:SetScript("OnUpdate", function(_, elapsed)
	sinceTick = sinceTick + elapsed
	if sinceTick < 0.5 then return end
	sinceTick = 0
	if moving and DR.currentKey then
		guard(checkWalk)
	end
end)
