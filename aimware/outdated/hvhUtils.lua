---- Lua HvH Utilities by Nyanpasu!
---- Version 1.0

-- Github
local this_scriptname = GetScriptName()
local this_version = "1.0"
local this_autoupdate = true
local git_version = "https://raw.githubusercontent.com/itisluiz/aimware_hvhutils/master/version.txt"
local git_repository = "https://raw.githubusercontent.com/itisluiz/aimware_hvhutils/master/HvHutils.lua"
---------

-- Auto Update
if this_autoupdate then
	if gui.GetValue("lua_allow_http") and gui.GetValue("lua_allow_cfg") then
		local this_latestversion = http.Get(git_version)
		if this_version ~= this_latestversion then
			local this_file = file.Open(this_scriptname, "w")
			this_file:Write(http.Get(git_repository))
			this_file:Close()
			print(this_scriptname .. ": Updated from " .. this_version .. " to " .. this_latestversion)
			print(this_scriptname .. ": Reload script for the update to take effect")
		else
			print(this_scriptname .. ": Script is up-to-date")
		end
	else
		print(this_scriptname .. ": Please enable Lua HTTP and Lua script/config editing to check for updates")
	end
end
--------------

-- Constants
local font_hud = draw.CreateFont("Small Fonts", 15, 15)
local font_icon = draw.CreateFont("Webdings", 24, 24)
local list_rbotweapons = 
{
	["SHARED"] = "shared",	
	["PISTOL"] = "pistol",
	["REVOLVER"] = "revolver",
	["SMG"] = "smg",
	["RIFLE"] = "rifle",
	["SHOTGUN"] = "shotgun",
	["SCOUT"] = "scout",
	["A. SNIPER"] = "autosniper",
	["SNIPER"] = "sniper",
	["LMG"] = "lmg";
}
local list_hitboxes =
{
	["head"] = {1},
	["neck"] = {1},
	["chest"] = {2},
	["stomach"] = {3},
	["pelvis"] = {3},
	["arms"] = {4, 5},
	["legs"] = {6, 7};
}
------------

-- Persistent Variables
local ent_LocalPlayer = entities.GetLocalPlayer()
local str_ServerIP = engine.GetServerIP()
local vec2_ScreenSize = {0, 0}
local vec2_ScreenCenter = {0, 0}
local bool_inGame = false
local str_LocalWeaponType = nil
local vec3_LocalShootPos = {0, 0, 0}
local ent_aimbotTarget = nil
local list_manualDamageCache = {}
local list_wallbangDamageCache = {}
-----------------------

-- GUI
local ref_rage_main_extra = gui.Reference("RAGE", "MAIN", "Extra")
gui.Text(ref_rage_main_extra, "Min Damage Override")
gui.Keybox(ref_rage_main_extra, "rbot_dmgoverride_up", "Override Up", 0)
gui.Keybox(ref_rage_main_extra, "rbot_dmgoverride_down", "Override Down", 0)

local ref_vis_msc_assistance = gui.Reference("VISUALS", "MISC", "Assistance")
--local multiref_vis_msc_assistance = gui.Multibox(ref_vis_msc_assistance, "Draw Ragebot Settings")
--gui.Checkbox(multiref_vis_msc_assistance, "esp_rbot_hitchance", "Hit Chance", 1)
--gui.Checkbox(multiref_vis_msc_assistance, "esp_rbot_mindamage", "Min Damage", 1)

for key_index, str_rbotweapon in pairs(list_rbotweapons) do
	local ref_rage_weapon_rbotweapon = gui.Reference("RAGE", "WEAPON", key_index, "Accuracy")
	gui.Slider(ref_rage_weapon_rbotweapon, string.format("rbot_%s_dmgoverride_up", str_rbotweapon), "Min Damage Override Up", 75, 0, 100)
	gui.Slider(ref_rage_weapon_rbotweapon, string.format("rbot_%s_dmgoverride_down", str_rbotweapon), "Min Damage Override Down", 5, 0, 100)
	gui.Checkbox(ref_rage_weapon_rbotweapon, string.format("rbot_%s_dmgoverride_legscan", str_rbotweapon), "Force Leg Hitscan on Override Down", 0)
	gui.Checkbox(ref_rage_weapon_rbotweapon, string.format("rbot_%s_dmgoverride_wallbang_enable", str_rbotweapon), "Use Wallbang Min Damage", 0)
	gui.Slider(ref_rage_weapon_rbotweapon, string.format("rbot_%s_dmgoverride_wallbang", str_rbotweapon), "Min Damage Wallbang", 10, 0, 100)
end

------

local function info_weaponType(ent_weapon)
    
	-- Nil check the weapon
    if ent_weapon == nil then
        return nil
    end
	
	local int_weaponType = ent_weapon:GetWeaponType()
    local str_weaponName = ent_weapon:GetName()
	
	-- Nil check weapon's properties
    if int_weaponType == nil or str_weaponName == nil then
        return nil
    end
	
	-- Get special weapons by their names
    if string.find(str_weaponName, "revolver") then
        return list_rbotweapons["REVOLVER"]
    end
    if string.find(str_weaponName, "ssg08") then
        return list_rbotweapons["SCOUT"]
    end
    if string.find(str_weaponName, "awp") then
        return list_rbotweapons["SNIPER"]
    end
    if string.find(str_weaponName, "scar20") or string.find(str_weaponName, "g3sg1") then
        return list_rbotweapons["A. SNIPER"]
    end
	
	-- Get generic weapon by their type
    if int_weaponType == 1 then
        return list_rbotweapons["PISTOL"]
    end
    if int_weaponType == 2 then
        return list_rbotweapons["SMG"]
    end
    if int_weaponType == 3 then
        return list_rbotweapons["RIFLE"]
    end
    if int_weaponType == 4 then
        return list_rbotweapons["SHOTGUN"]
    end
	
	-- No weapon type 5 since we already checked for all sniper rifles
	
	if int_weaponType == 6 then
        return list_rbotweapons["LMG"]
    end

    return nil
end

-- Callbacks
local function onFrame_gatherdata()
	-- Get local player
	ent_LocalPlayer = entities.GetLocalPlayer()
	
	-- Get server ip
	str_ServerIP = engine.GetServerIP()
	
	-- Get screen size and center
	vec2_ScreenSize = {draw.GetScreenSize()}
	vec2_ScreenCenter = {vec2_ScreenSize[1] / 2, vec2_ScreenSize[2] / 2}
	
	-- Check for game
	if ent_LocalPlayer == nil or str_ServerIP == nil then
		if bool_inGame then
			bool_inGame = false
		end
		
		ent_aimbotTarget = nil
		return
	end
	
	-- Set inGame variable
	bool_inGame = true
	
	-- Get local weapon
	str_LocalWeaponType = info_weaponType(ent_LocalPlayer:GetPropEntity("m_hActiveWeapon"))
	
	-- Get local shootpos (m_vecViewOffset[0] gets all 3 vector components despite the indexing)
	vec3_LocalShootPos = {vector.Add({ent_LocalPlayer:GetAbsOrigin()}, {ent_LocalPlayer:GetPropVector("localdata", "m_vecViewOffset[0]")})}
end
callbacks.Register("Draw", onFrame_gatherdata)

local function onTarget_aimbotTarget(Entity)
	-- Set the new aimbot target
	ent_aimbotTarget = Entity
	
end
callbacks.Register("AimbotTarget", onTarget_aimbotTarget)

local function onFrame_damageOverride()
	
	-- Check for game
	if not bool_inGame then
		return
	end
	
	-- Check for firearm
	if str_LocalWeaponType == nil or str_LocalWeaponType == "" then
		return
	end
	
	-- Check if shared config
	if gui.GetValue("rbot_sharedweaponcfg") then
		str_LocalWeaponType = "shared"
	end
	
	-- Check if up key is bound
	if gui.GetValue("rbot_dmgoverride_up") ~= nil and gui.GetValue("rbot_dmgoverride_up") ~= 0 then
		
		-- Check if it's pressed
		if input.IsButtonDown(gui.GetValue("rbot_dmgoverride_up")) then
			
			-- Cancel force leg hitscan
			for key_index, str_setting in pairs(list_manualDamageCache) do
				if string.find(key_index, "hitbox_legs") then
					gui.SetValue(key_index, str_setting)
					list_manualDamageCache[key_index] = nil
				end
			end
		
			-- Cache the current value if not yet done
			if list_manualDamageCache[string.format("rbot_%s_mindamage", str_LocalWeaponType)] == nil then
				list_manualDamageCache[string.format("rbot_%s_mindamage", str_LocalWeaponType)] = gui.GetValue(string.format("rbot_%s_mindamage", str_LocalWeaponType))
			end
			
			-- Set mindamage up
			gui.SetValue(string.format("rbot_%s_mindamage", str_LocalWeaponType), gui.GetValue(string.format("rbot_%s_dmgoverride_up", str_LocalWeaponType)))
			
			return
		end
		
	end
	
	-- Check if down key is bound
	if gui.GetValue("rbot_dmgoverride_down") ~= nil and gui.GetValue("rbot_dmgoverride_down") ~= 0 then
		
		-- Check if it's pressed
		if input.IsButtonDown(gui.GetValue("rbot_dmgoverride_down")) then
			
			-- Cache the current value if not yet done
			if list_manualDamageCache[string.format("rbot_%s_mindamage", str_LocalWeaponType)] == nil then
				list_manualDamageCache[string.format("rbot_%s_mindamage", str_LocalWeaponType)] = gui.GetValue(string.format("rbot_%s_mindamage", str_LocalWeaponType))	
			end
			
			-- Check for force leg hitscan
			if list_manualDamageCache[string.format("rbot_%s_hitbox_legs", str_LocalWeaponType)] == nil then
				list_manualDamageCache[string.format("rbot_%s_hitbox_legs", str_LocalWeaponType)] = gui.GetValue(string.format("rbot_%s_hitbox_legs", str_LocalWeaponType))
			end
			
			-- Set mindamage down
			gui.SetValue(string.format("rbot_%s_mindamage", str_LocalWeaponType), gui.GetValue(string.format("rbot_%s_dmgoverride_down", str_LocalWeaponType)))
			
			-- Check for force leg hitscan
			if gui.GetValue(string.format("rbot_%s_dmgoverride_legscan", str_LocalWeaponType)) then
				-- Set leg hitscan
				gui.SetValue(string.format("rbot_%s_hitbox_legs", str_LocalWeaponType), 1)
			end
			
			return
		end
		
	end
	
	-- Reset values to cache
	for key_index, str_setting in pairs(list_manualDamageCache) do
		gui.SetValue(key_index, str_setting)
		list_manualDamageCache[key_index] = nil
	end

end
callbacks.Register("Draw", onFrame_damageOverride)

local function onFrame_damageWallbang()

	-- Check for game
	if not bool_inGame then
		return
	end
	
	-- Check for target
	if ent_aimbotTarget == nil then
		return
	end
	
	-- Check for firearm
	if str_LocalWeaponType == nil or str_LocalWeaponType == "" then
		return
	end
	
	-- Check if shared config
	if gui.GetValue("rbot_sharedweaponcfg") then
		str_LocalWeaponType = "shared"
	end
	
	-- Check for enabled
	if not gui.GetValue(string.format("rbot_%s_dmgoverride_wallbang_enable", str_LocalWeaponType)) then
			-- Reset values to cache
			for key_index, str_setting in pairs(list_wallbangDamageCache) do
				print(key_index)
				gui.SetValue(key_index, str_setting)
				list_wallbangDamageCache[key_index] = nil
			end
		return
	end
	
	-- Check if not manually damage overriding
	for key_index, str_setting in pairs(list_manualDamageCache) do
		return
	end
	
	-- Setup the list that holds enabled hitgroups
	local list_usedHitgroups = {}
	local str_hitboxPath = string.format("rbot_%s_hitbox_", str_LocalWeaponType)
	
	-- Check enabled hitgroups
	for key_hitbox, list_hitgroups in pairs(list_hitboxes) do
		
		-- Is the hitgroup enabled
		if gui.GetValue(str_hitboxPath .. key_hitbox) then
		
			-- For each hitgroup that corresponds
			for key_hitgroup = 1, #list_hitgroups do
				
				-- And lastly, check if value is already in the used hitgroups array
				local bool_isUsed = false
				
				for key_usedhHitgroup = 1, #list_usedHitgroups do
					if list_hitgroups[key_hitgroup] == list_usedHitgroups[key_usedhHitgroup] then
						bool_isUsed = true
					end
				end
				
				-- Insert the new hitgroup
				if not bool_isUsed then
					table.insert(list_usedHitgroups, list_hitgroups[key_hitgroup])
				end
				
			end
			
		end
		
	end
	
	-- Now for ray tracing
	local bool_isVisible = false
	
	for key_usedhHitgroup = 1, #list_usedHitgroups do
		local vec3_hitgroupPos = {ent_aimbotTarget:GetHitboxPosition(list_usedHitgroups[key_usedhHitgroup])}

		if engine.TraceLine(vec3_LocalShootPos[1], vec3_LocalShootPos[2], vec3_LocalShootPos[3], vec3_hitgroupPos[1], vec3_hitgroupPos[2], vec3_hitgroupPos[3], 0x1) == 0 then
			bool_isVisible = true
			break
		end
	end
	
	-- Set the wallbang min damage
	if not bool_isVisible then
		-- Cache the current value if not yet done
		if list_wallbangDamageCache[string.format("rbot_%s_mindamage", str_LocalWeaponType)] == nil then
			list_wallbangDamageCache[string.format("rbot_%s_mindamage", str_LocalWeaponType)] = gui.GetValue(string.format("rbot_%s_mindamage", str_LocalWeaponType))
		end
		
		-- Set mindamage
		gui.SetValue(string.format("rbot_%s_mindamage", str_LocalWeaponType), gui.GetValue(string.format("rbot_%s_dmgoverride_wallbang", str_LocalWeaponType)))
	else
		-- Reset values to cache
		for key_index, str_setting in pairs(list_wallbangDamageCache) do
			gui.SetValue(key_index, str_setting)
			list_wallbangDamageCache[key_index] = nil
		end
	end
	

end
callbacks.Register("Draw", onFrame_damageWallbang)
