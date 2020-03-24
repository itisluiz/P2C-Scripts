-- AIMWARE lua script for stealing dropped weapons
-- By Nyanpasu!
-- Version 1.0

-- Set open buy menu open on use to 0
client.SetConVar("cl_use_opens_buy_menu", 0, 0)

---- Global variables
local enum_weaponList =
{
	-- From https://tf2b.com/itemlist.php?gid=730
	[1] = {name = "Desert Eagle", slot = 2},
	[2] = {name = "Dual Berettas", slot = 2},
	[3] = {name = "Five-SeveN", slot = 2},
	[4] = {name = "Glock-18", slot = 2},
	[7] = {name = "AK-47", slot = 1},
	[8] = {name = "AUG", slot = 1},
	[9] = {name = "AWP", slot = 1},
	[10] = {name = "FAMAS", slot = 1},
	[11] = {name = "G3SG1", slot = 1},
	[13] = {name = "Galil AR", slot = 1},
	[14] = {name = "M249", slot = 1},
	[16] = {name = "M4A4", slot = 1},
	[17] = {name = "MAC-10", slot = 1},
	[19] = {name = "P90", slot = 1},
	[23] = {name = "MP5-SD", slot = 1},
	[24] = {name = "UMP-45", slot = 1},
	[25] = {name = "XM1014", slot = 1},
	[26] = {name = "PP-Bizon", slot = 1},
	[27] = {name = "MAG-7", slot = 1},
	[28] = {name = "Negev", slot = 1},
	[29] = {name = "Sawed-Off", slot = 1},
	[30] = {name = "Tec-9", slot = 2},
	[32] = {name = "P2000", slot = 2},
	[33] = {name = "MP7", slot = 1},
	[34] = {name = "MP9", slot = 1},
	[35] = {name = "Nova", slot = 1},
	[36] = {name = "P250", slot = 2},
	[38] = {name = "SCAR-20", slot = 1},
	[39] = {name = "SG 553", slot = 1},
	[40] = {name = "SSG 08", slot = 1},
	[60] = {name = "M4A1-S", slot = 1},
	[61] = {name = "USP-S", slot = 2},
	[63] = {name = "CZ75-Auto", slot = 2},
	[64] = {name = "R8 Revolver"; slot = 2}
}

local weapon_stealPlan =
{
	inAction = false,
	position = {0, 0, 0}
}

-- Engine misc
local h_localPlayer = entities.GetLocalPlayer()
local str_serverIP = engine.GetServerIP()
local b_inGame = false
local vec_shootPos = {0, 0, 0}
-- Round status
local i_roundStartTime = 0
local b_isFreezetime = false
-- Fonts / Colors
local font_icon = draw.CreateFont("Wingdings", 50, 50)
local font_esp = draw.CreateFont("smallfonts", 13, 13)
-- Customizable
local const_maxPickupDistance = 140
---- GUI

-- AIMWARE window
local ref_aimwareWindow = gui.Reference("MENU")
local ref_misc_general_extra = gui.Reference("MISC", "GENERAL", "Extra")
local ref_mainGroupbox = gui.Groupbox(ref_misc_general_extra, "Weapon Stealer")
local ref_activeMultiBox = gui.Multibox(ref_mainGroupbox, "Active")
gui.Checkbox(ref_activeMultiBox, "msc_weaponstealer_onalways", "Always", 0)
gui.Checkbox(ref_activeMultiBox, "msc_weaponstealer_onfreeze", "On freeze-time", 1)
gui.Keybox(ref_mainGroupbox, "msc_weaponstealer_key", "Steal Key", 0)
--gui.Slider(ref_mainGroupbox, "msc_weaponstealer_smooth", "Smooth", 0, 0, 30) Don't feel like it right now...
gui.Combobox(ref_mainGroupbox, "msc_weaponstealer_visuals", "Visual information", "Detailed", "Minimalistic", "None")
gui.Checkbox(ref_mainGroupbox, "msc_weaponstealer_preferences", "Show Preferences List", 0)

gui.ColorEntry("clr_weaponstealer_cangrab", "Weapon Stealer Grabbable", 255, 255, 255, 255)
gui.ColorEntry("clr_weaponstealer_cantgrab", "Weapon Stealer Not Grabbable", 255, 0, 0, 255)

-- Preferences window
local ref_prefWindow = gui.Window("wnd_weaponstealerpref", "Weapon Stealer Preferences", 50, 50, 350, 850)
local ref_prefGroupbox = gui.Groupbox(ref_prefWindow, "Higher means more priority", 10, 45, 350 - 20, 850 - 85)
gui.Text(ref_prefWindow, "Choose each weapon's priority")
for id, weapon in pairs(enum_weaponList) do
	gui.Slider(ref_prefGroupbox, "msc_weaponstealer_priority_" .. id, weapon.name, 2.5, 0, 5)
end

---- Main

local function centeredTextShadow(x, y, text)
	local width, height = draw.GetTextSize(text)
	draw.TextShadow(x - width / 2, y - height / 2, text)
	
	return {width, height}
end

local function colorMix(firstColor, secondColor, coefficient)
	coefficient = math.max(math.min(coefficient , 1), 0)
	complementarCoefficient = 1 - coefficient
	
	local red = firstColor[1] * coefficient + secondColor[1] * complementarCoefficient
	local green = firstColor[2] * coefficient + secondColor[2] * complementarCoefficient
	local blue = firstColor[3] * coefficient + secondColor[3] * complementarCoefficient
	local alpha = firstColor[4] * coefficient + secondColor[4] * complementarCoefficient
	return red, green, blue, alpha
end

local function onFrame_manager()
	
	-- Manage globals
	h_localPlayer = entities.GetLocalPlayer()
	str_serverIP = engine.GetServerIP()
	
	-- Validate game
	if (h_localPlayer ~= nil and str_serverIP ~= nil) then
		b_inGame = true
	else
		b_inGame = false
	end
	
	-- Managing that happens ingame
	if b_inGame then
		-- Shoot pos
		vec_shootPos = {vector.Add({h_localPlayer:GetAbsOrigin()}, {0, 0, h_localPlayer:GetPropFloat("localdata", "m_vecViewOffset[2]")})}	
		
		-- Could have used just events, but I'd rather do it this way as of now
		if (globals.CurTime() <= i_roundStartTime + client.GetConVar("mp_freezetime")) then
			b_isFreezetime = true
		else 
			b_isFreezetime = false
		end
	end
	
	-- Manage windows visibility
	if (ref_aimwareWindow:IsActive() and gui.GetValue("msc_weaponstealer_preferences")) then
		ref_prefWindow:SetActive(1)
	else
		ref_prefWindow:SetActive(0)
	end

end
callbacks.Register("Draw", onFrame_manager)

local function onEvent_manager(event)
	-- Round start event
	if (event:GetName() == "round_poststart") then
		i_roundStartTime = globals.CurTime()
	end

end
client.AllowListener("round_poststart")
callbacks.Register("FireGameEvent", onEvent_manager)

local function onFrame_main()
	-- In game and good to go?
	if b_inGame and h_localPlayer:IsAlive() then
		
		if gui.GetValue("msc_weaponstealer_onalways") or (b_isFreezetime and gui.GetValue("msc_weaponstealer_onfreeze")) or (gui.GetValue("msc_weaponstealer_key") > 0 and input.IsButtonDown(gui.GetValue("msc_weaponstealer_key")))then
			
			-- Iterate through all weapons
			for key, weapon in pairs(entities.FindByClass("CWeaponCSBase")) do	
				
				-- Check if it has no owner (is dropped) and it is present in the enum and priority isn't 0
				if weapon:GetPropEntity("m_hOwner") == nil and enum_weaponList[weapon:GetWeaponID()] ~= nil and gui.GetValue("msc_weaponstealer_priority_" .. weapon:GetWeaponID()) > 0 then
					local weapon_pos = {weapon:GetAbsOrigin()}
					local weapon_distance = vector.Distance(vec_shootPos, weapon_pos)
					local weapon_rayTrace = select(2, engine.TraceLine( vec_shootPos[1], vec_shootPos[2], vec_shootPos[3], weapon_pos[1], weapon_pos[2], weapon_pos[3], 0x4001))
					local weapon_priority = math.floor(gui.GetValue("msc_weaponstealer_priority_" .. weapon:GetWeaponID()) * 10) / 10 -- Only use 1 decimal case
					local weapon_slot = enum_weaponList[weapon:GetWeaponID()].slot
					local weapon_desired = false
					local weapon_inRange = true

					-- Check if the gun is visible
					if not (weapon_rayTrace < 0.995) then
						
						if weapon_distance > const_maxPickupDistance then
							weapon_inRange = false
						end
						
						-- Check if we want to steal itemlist, iterate through all our weapons
						local hasSlot_1 = false
						local hasSlot_2 = false
						for localWeaponIterator = 0, 63 do
							local localweapon = h_localPlayer:GetPropEntity("m_hMyWeapons", localWeaponIterator)
							
							if localweapon ~= nil and enum_weaponList[localweapon:GetWeaponID()] ~= nil then
								local localweapon_slot = enum_weaponList[localweapon:GetWeaponID()].slot
								local localweapon_priority = math.floor(gui.GetValue("msc_weaponstealer_priority_" .. localweapon:GetWeaponID()) * 10) / 10 -- Only use 1 decimal case
								
								if localweapon_slot == 1 then
									hasSlot_1 = true
								elseif localweapon_slot == 2 then
									hasSlot_2 = true
								end
								
								if localweapon_slot == weapon_slot and weapon_priority > localweapon_priority then
									weapon_desired = true
									break
								end	
								
							end
						end
						
						-- Of course we want a weapon if we don't have one!
						if (weapon_slot == 1 and not hasSlot_1) or (weapon_slot == 2 and not hasSlot_2) then
							weapon_desired = true
						end
						
						-- Send the request to pocket it
						if weapon_inRange and weapon_desired then
							weapon_stealPlan.position = weapon_pos
							weapon_stealPlan.inAction = true
						end
						
						-- Visuals
						if gui.GetValue("msc_weaponstealer_visuals") < 2 then
							local weapon_toScreenX, weapon_toScreenY = client.WorldToScreen(weapon_pos[1], weapon_pos[2], weapon_pos[3])
							
							if weapon_toScreenX ~= nil then	
								-- Minimalistic
								if weapon_desired then
									draw.SetFont(font_icon)
									
									if weapon_inRange then
										draw.Color(gui.GetValue("clr_weaponstealer_cangrab"))
									else
										draw.Color(gui.GetValue("clr_weaponstealer_cantgrab"))
									end
									
									centeredTextShadow(weapon_toScreenX, weapon_toScreenY, "I") -- "I" is the hand character on wingdings
								end
								
								-- Detailed
								if gui.GetValue("msc_weaponstealer_visuals") == 0 then
									
									local heightOffset = 25
									if not weapon_desired then
										draw.SetFont(font_icon)
										if weapon_inRange then
											draw.Color(gui.GetValue("clr_weaponstealer_cangrab"))
										else
											draw.Color(gui.GetValue("clr_weaponstealer_cantgrab"))
										end
										
										centeredTextShadow(weapon_toScreenX, weapon_toScreenY, "s") -- "s" is the thingy character on wingdings
									end
									draw.SetFont(font_esp)
									heightOffset = heightOffset + centeredTextShadow(weapon_toScreenX, weapon_toScreenY + heightOffset, "Distance: " .. math.floor(weapon_distance * 10) / 10 .. " units")[2]
									centeredTextShadow(weapon_toScreenX, weapon_toScreenY + heightOffset, "Priority: " .. weapon_priority .. " / 5.0")
								
								end
									
								
							end
						
						end
					end

				end
			end
		
		
		end

	end

end
callbacks.Register("Draw", onFrame_main)

local function onCreateMove_stealGun(cmd)
	if weapon_stealPlan.inAction then
		local vector_toWeapon = {vector.Subtract( weapon_stealPlan.position, vec_shootPos)}
		local angle_toWeapon = {vector.Angles(vector_toWeapon)}
		-- Snap to gun
		cmd:SetViewAngles( angle_toWeapon[1], angle_toWeapon[2], 0)
		
		-- Force use
		if globals.TickCount() % 12 > 0 then -- Don't try every 12 ticks to prevent hangups
			cmd:SetButtons(cmd:GetButtons() | (1 << 5))
		end
		weapon_stealPlan.inAction = false
	end
	
end
callbacks.Register("CreateMove", onCreateMove_stealGun)
