-- Avatar ESP for aimware by Nyanpasu!
-- Version 0.1

-- STEAM WEB API KEY --
local g_webAPIkey = ""
-----------------------

-- Default avatars --
local g_defaultTerrorist = nil
local g_defaultCounterterrorist = nil

-- Global variables --
local g_playerAvatar = {} -- For each ent index [steamID], avatarTexture
local g_localPlayer = entities.GetLocalPlayer()
local g_serverIP = engine.GetServerIP()
local g_inGame = false

-- Miscellaneous --
local function resetAvatars() g_playerAvatar = {} end
http.Get("http://i.imgur.com/z30yywm.png", function(httpData) g_defaultTerrorist = draw.CreateTexture(common.DecodePNG( httpData )) end ) -- Get T bot avatar
http.Get("http://i.imgur.com/uXVL7GZ.png", function(httpData) g_defaultCounterterrorist = draw.CreateTexture(common.DecodePNG( httpData )) end ) -- Get CT bot avatar
local function communityID(steamID)
	parts = {}
	steamID = steamID:gsub("STEAM_", "")
	for part in (steamID..":"):gmatch("(%d+)"..":") do
        table.insert(parts, tonumber(part))
    end
	return (1 << 56) | (1048577 << 32) | (parts[3] << 1) | parts[2]
end
local function getXMLNode(xml, node)
	return xml:match("<" .. node .. ">(.+)</" .. node .. ">")
end


-- GUI --
local ref_misc_general_extra = gui.Reference("MISC", "GENERAL", "Extra")
local ref_settingsGroupbox = gui.Groupbox(ref_misc_general_extra, "Avatar ESP")
gui.Combobox(ref_settingsGroupbox, "msc_avataresp_definition", "Avatar Definition", "Standard", "Medium", "High")
gui.Checkbox(ref_settingsGroupbox, "msc_avataresp_frame", "Avatar Frame", 1)
gui.Checkbox(ref_settingsGroupbox, "msc_avataresp_distfade", "Fade on Distance", 1)
gui.Button(ref_settingsGroupbox, "Refresh Avatars", resetAvatars)

-- Main --
local function onFrame_manager()
	-- Refresh globals --
	g_localPlayer = entities.GetLocalPlayer()
	g_serverIP = engine.GetServerIP()
	
	-- isGame --
	if (g_localPlayer ~= nil and g_serverIP ~= nil) then
		g_inGame = true
	else
		g_inGame = false
	end
	
	-- inGame --
	if not g_inGame then
		resetAvatars()
	end
	
end
callbacks.Register("Draw", onFrame_manager)

local function onESP_main(ESPBuilder)
	local espEntity = ESPBuilder:GetEntity()
	
	if not g_inGame then
		return
	end
	
	-- Is player entity?
	if espEntity:GetClass() ~= "CCSPlayer" then
		return
	end
	
	local playerInfo = client.GetPlayerInfo( espEntity:GetIndex() )
	
	-- Is GOTV?
	if playerInfo["IsGOTV"] then
		return
	end
	
	local steamID64 = communityID(playerInfo["SteamID"])
	local x1, y1, x2, y2 = ESPBuilder:GetRect()
	
	-- Request the player's avatar
	if not playerInfo["IsBot"] and g_playerAvatar[steamID64] == nil then
		
		local definition = "avatar"
		
		if gui.GetValue("msc_avataresp_definition") == 1 then
			definition = "avatarmedium"
		elseif gui.GetValue("msc_avataresp_definition") == 2 then
			definition = "avatarfull"
		end
	
		g_playerAvatar[steamID64] = false
		http.Get("http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0001/?format=xml&key=" .. g_webAPIkey .. "&steamids=" .. steamID64, function(httpData) 
			http.Get(getXMLNode(httpData, definition), function(jpgData) g_playerAvatar[steamID64] = draw.CreateTexture(common.DecodeJPEG(jpgData)) end) end )
		
	end
	
	
	if gui.GetValue("msc_avataresp_frame") then
		draw.SetTexture(nil)
		
		if espEntity:GetTeamNumber() == 2 then
			draw.Color(gui.GetValue("clr_esp_box_t_vis"))
		else
			draw.Color(gui.GetValue("clr_esp_box_ct_vis"))
		end
		
		draw.OutlinedRect((x1 + x2) / 2 - 16, y1 - 46, (x1 + x2) / 2 + 16, y1 - 14)
	
	end
	
	if g_playerAvatar[steamID64] ~= false then
		draw.SetTexture(g_playerAvatar[steamID64])
	end
	
	
	-- Is bot or avatar isn't loaded yet?
	if playerInfo["IsBot"] or g_playerAvatar[steamID64] == false then
		if espEntity:GetTeamNumber() == 2 then
			draw.SetTexture(g_defaultTerrorist)
		else
			draw.SetTexture(g_defaultCounterterrorist)
		end
	end
	
	if gui.GetValue("msc_avataresp_distfade") and g_localPlayer:IsAlive() then
		dist = vector.Distance({g_localPlayer:GetAbsOrigin()}, {espEntity:GetAbsOrigin()})
		multiplier = math.max(0.15, math.min(1, 500/dist) )	
		draw.Color(255, 255, 255, 255 * multiplier)
	else
		draw.Color(255, 255, 255, 255)
	end


	draw.FilledRect((x1 + x2) / 2 - 15, y1 - 45, (x1 + x2) / 2 + 15, y1 - 15)


end
callbacks.Register("DrawESP", onESP_main)