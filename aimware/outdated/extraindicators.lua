local dpi_scale = gui.GetValue("dpi_scale")

local font_main = draw.CreateFont("Tahoma Bold", math.floor(15 * dpi_scale), math.floor(15 * dpi_scale))
local font_value = draw.CreateFont("Small Fonts Bold", math.floor(11 * dpi_scale), math.floor(11 * dpi_scale))

-- Script --------
local cur_scriptname = GetScriptName()
local cur_version = "1.1.1"
local git_version = "https://raw.githubusercontent.com/itisluiz/aimware_extraindicators/master/version.txt"
local git_repository = "https://raw.githubusercontent.com/itisluiz/aimware_extraindicators/master/extraindicators.lua"
------------------

-- UI Elements --
local ref_vis_msc_selfextra = gui.Reference("VISUALS", "MISC", "Yourself Extra")

local wnd_dragger = gui.Window("wnd_extraindicators_dragger", "Extra Indicators Dragger", 10, 300, 160, 30)

local chb_dragger = gui.Checkbox(ref_vis_msc_selfextra, "vis_extraindicators_dragger", "Dragger", 0)
local cob_infomode = gui.Combobox(ref_vis_msc_selfextra,"vis_extraindicators_infomode", "Extra Indicators Mode", "Off", "Simple Information", "All Information")
-----------------

-- Configurable --
local size_infoBox = {120, 25}
------------------

-- Global Variables ---
local Choking = false
local ChokeStart = 0
-----------------------

local ang_client = {0, 0, 0}
local ang_server = {0, 0, 0}

-- Check for updates
local function git_update()
	if cur_version ~= http.Get(git_version) then
		local this_script = file.Open(cur_scriptname, "w")
		this_script:Write(http.Get(git_repository))
		this_script:Close()
		print("[Lua Scripting] " .. cur_scriptname .. " has updated itself from version " .. cur_version .. " to " .. http.Get(git_version))
		print("[Lua Scripting] Please reload " .. cur_scriptname)
	else
		print("[Lua Scripting] " .. cur_scriptname .. " is up-to-date")
	end
end

-- Functions from EssentialsNP so the script can stay standalone
local function drawCircle(Position, Radius)
    for degrees = 1, 360, 1 do
        local thisPoint = nil
        local lastPoint = nil

        if Position[3] == nil then
            thisPoint = {
                Position[1] + math.sin(math.rad(degrees)) * Radius,
                Position[2] + math.cos(math.rad(degrees)) * Radius
            }
            lastPoint = {
                Position[1] + math.sin(math.rad(degrees - 1)) * Radius,
                Position[2] + math.cos(math.rad(degrees - 1)) * Radius
            }
        else
            thisPoint = {
                client.WorldToScreen(
                    Position[1] + math.sin(math.rad(degrees)) * Radius,
                    Position[2] + math.cos(math.rad(degrees)) * Radius,
                    Position[3]
                )
            }
            lastPoint = {
                client.WorldToScreen(
                    Position[1] + math.sin(math.rad(degrees - 1)) * Radius,
                    Position[2] + math.cos(math.rad(degrees - 1)) * Radius,
                    Position[3]
                )
            }
        end

        if thisPoint[1] ~= nil and thisPoint[2] ~= nil and lastPoint[1] ~= nil and lastPoint[2] ~= nil then
            draw.Line(thisPoint[1], thisPoint[2], lastPoint[1], lastPoint[2])
        end
    end
end

local function drawInfo(Position, TextArray, ColorArray)
    local txt_concat = ""

    for i = 1, #TextArray do
        txt_concat = txt_concat .. TextArray[i]
    end

    local w_text, h_text = draw.GetTextSize(txt_concat)
    w_text = w_text / 2

    for index, text in pairs(TextArray) do
        draw.Color(ColorArray[index][1], ColorArray[index][2], ColorArray[index][3], ColorArray[index][4])
        draw.TextShadow(Position[1] - w_text, Position[2] - h_text / 2, text)
        w_text = w_text - select(1, draw.GetTextSize(text))
    end

    draw.Color(255, 255, 255, 255)
end

local function drawInfoBox(Position, Size, Title, Color, ColorTitle)
    draw.Color(0, 0, 0, 150)

    draw.FilledRect(Position[1], Position[2], Position[1] + (Size[1] * dpi_scale), Position[2] + (Size[2] * dpi_scale))

    draw.Color(50, 50, 50, 255)

    draw.OutlinedRect(
        Position[1],
        Position[2],
        Position[1] + (Size[1] * dpi_scale),
        Position[2] + (Size[2] * dpi_scale)
    )

    draw.Color(Color[1], Color[2], Color[3], Color[4])
    draw.Line(Position[1], Position[2], Position[1] + (Size[1] * dpi_scale) - 1, Position[2])

    draw.SetFont(font_main)
    local w_title, h_title = draw.GetTextSize(Title)

    if ColorTitle ~= nil then
        draw.Color(ColorTitle[1], ColorTitle[2], ColorTitle[3], ColorTitle[4])
    else
        draw.Color(255, 255, 255, 255)
    end

    draw.TextShadow(Position[1] + 5, Position[2] + 5, Title)

    draw.Color(255, 255, 255, 255)

    return {
        Position[1] + w_title + 10,
        Position[2] + 4 + h_title / 2,
        Position[1] + (Size[1] * dpi_scale),
        Position[2] + (Size[2] * dpi_scale)
    }
end

local function drawProgress(Position, Size, Progress, Color, Value, ColorValue, Mark)
    Progress = math.max(math.min(Progress, 1), 0)

    draw.Color(0, 0, 0, 150)
    draw.FilledRect(Position[1], Position[2], Position[1] + Size[1], Position[2] + (Size[2] * dpi_scale))

    draw.Color(Color[1], Color[2], Color[3], Color[4])
    draw.FilledRect(Position[1], Position[2], Position[1] + (Size[1] * Progress), Position[2] + (Size[2] * dpi_scale))

    if Mark ~= nil then
        Mark = math.max(math.min(Mark, 0.975), 0.025)
        draw.Color(255, 255, 255, 255)
        draw.Line(
            Position[1] + ((Size[1] * dpi_scale) * Mark) - 1,
            Position[2],
            Position[1] + ((Size[1] * dpi_scale) * Mark) - 1,
            Position[2] + (Size[2] * dpi_scale) - 1
        )
    end

    draw.Color(50, 50, 50, 255)
    draw.OutlinedRect(Position[1], Position[2], Position[1] + Size[1], Position[2] + (Size[2] * dpi_scale))

    if Value ~= nil then
        if ColorValue ~= nil then
            draw.Color(ColorValue[1], ColorValue[2], ColorValue[3], ColorValue[4])
        else
            draw.Color(255, 255, 255, 255)
        end
        draw.SetFont(font_value)
        local w_value, h_value = draw.GetTextSize(Value)
        draw.TextShadow(
            Position[1] + (Size[1] * Progress) - w_value / 2,
            Position[2] - h_value / 2 + (Size[2] * dpi_scale) / 2,
            Value
        )
    end

    draw.Color(255, 255, 255, 255)
end

local function colorGradient(Coefficient, ColorA, ColorB)
    Coefficient = (math.max(math.min(Coefficient, 1), 0))

    local red = math.floor(Coefficient * ColorB[1]) + ((1 - Coefficient) * ColorA[1])
    local green = math.floor(Coefficient * ColorB[2]) + ((1 - Coefficient) * ColorA[2])
    local blue = math.floor(Coefficient * ColorB[3]) + ((1 - Coefficient) * ColorA[3])
    local alpha = math.floor(Coefficient * ColorB[4]) + ((1 - Coefficient) * ColorA[4])

    return red, green, blue, alpha
end

local function OnFrameMain()
    if chb_dragger:GetValue() then -- For some reason, setting SetActive directly to chb_dragger doesn't work
        wnd_dragger:SetActive(1)
    else
        wnd_dragger:SetActive(0)
    end

    local LocalPlayer = entities.GetLocalPlayer()

    if LocalPlayer == nil then
        return
    end

    local clr_main = {gui.GetValue("clr_gui_window_header_tab2")}

    -- World Display

    if cob_infomode:GetValue() == 2 then
        for index, molly in pairs(entities.FindByClass("CInferno")) do
            if molly ~= nil then
				if molly:GetPropEntity("m_hOwnerEntity") ~= nil then
					local pos_molly = {molly:GetAbsOrigin()}
					local wts_molly = {client.WorldToScreen(pos_molly[1], pos_molly[2], pos_molly[3] + 60)}
					local str_molly_team
					local clr_molly_team = {255, 255, 255, 255}
		
					if gui.GetValue("esp_teambasedcolors") then
						if molly:GetPropEntity("m_hOwnerEntity"):GetTeamNumber() == LocalPlayer:GetTeamNumber() then
							clr_molly_team = {gui.GetValue("clr_chams_ct_vis")}
						else
							clr_molly_team = {gui.GetValue("clr_chams_t_vis")}
						end
					else
						if molly:GetPropEntity("m_hOwnerEntity"):GetTeamNumber() == 3 then
							clr_molly_team = {gui.GetValue("clr_chams_ct_vis")}
						elseif molly:GetPropEntity("m_hOwnerEntity"):GetTeamNumber() == 2 then
							clr_molly_team = {gui.GetValue("clr_chams_t_vis")}
						end
					end
					
					if molly:GetPropEntity("m_hOwnerEntity"):GetTeamNumber() == LocalPlayer:GetTeamNumber() then
						draw.SetFont(font_value)
						str_molly_team = "Team"
						if wts_molly[1] ~= nil then
							local friendlyfire = client.GetConVar("mp_friendlyfire") + client.GetConVar("mp_teammates_are_enemies")
							if friendlyfire > 0 then
								drawInfo(
									{wts_molly[1], wts_molly[2] + (15 * dpi_scale)},
									{"Friendly Fire is ", "ON"},
									{{255, 255, 255, 255}, {255, 0, 0, 255}}
								)
							else
								drawInfo(
									{wts_molly[1], wts_molly[2] + (15 * dpi_scale)},
									{"Friendly Fire is ", "OFF"},
									{{255, 255, 255, 255}, {0, 255, 0, 255}}
								)
							end
						end
					else
						str_molly_team = "Enemy"
					end

					draw.SetFont(font_main)

					if wts_molly[1] ~= nil then
						drawInfo(wts_molly, {str_molly_team, " Molotov"}, {clr_molly_team, {255, 255, 255, 255}})
					end
				end
            end
        end
    end

    -- HUD Display
    local pos_window = {
        select(1, gui.GetValue("wnd_extraindicators_dragger")),
        select(2, gui.GetValue("wnd_extraindicators_dragger")) + 35 * dpi_scale
    }

    if cob_infomode:GetValue() == 2 and LocalPlayer:IsAlive() then
        local count_chokedpackets = 0
        if Choking then
            count_chokedpackets = globals.TickCount() - (ChokeStart - 1)
        end

        local ibox_packets = drawInfoBox(pos_window, size_infoBox, "Packets", clr_main)
        drawProgress(
            ibox_packets,
            {ibox_packets[3] - ibox_packets[1] - 5, 5},
            count_chokedpackets / 15,
            {255, 255, 255, 255},
            math.floor(count_chokedpackets)
        )

        pos_window[2] = pos_window[2] + (30 * dpi_scale)
    end

    if cob_infomode:GetValue() == 2 and LocalPlayer:IsAlive() then
        local delta_lby = LocalPlayer:GetPropFloat("m_flLowerBodyYawTarget") - ang_server[2]
        local clr_lby = {255, 0, 0, 255}

        if delta_lby > 180 then
            delta_lby = delta_lby - 360
        elseif delta_lby < -180 then
            delta_lby = delta_lby + 360
        end

        if math.abs(delta_lby) >= 35 then
            clr_lby = {0, 255, 0, 255}
        end

        local ibox_lowerbody = drawInfoBox(pos_window, size_infoBox, "LBY", clr_main)

        drawProgress(
            ibox_lowerbody,
            {ibox_lowerbody[3] - ibox_lowerbody[1] - 5, 5},
            math.abs(delta_lby) / 35,
            clr_lby,
            math.floor(math.abs(delta_lby)),
            clr_lby
        )

        pos_window[2] = pos_window[2] + (30 * dpi_scale)
    end

    if cob_infomode:GetValue() >= 1 and LocalPlayer:IsAlive() then
        local latency = entities.GetPlayerResources():GetPropInt("m_iPing", LocalPlayer:GetIndex())
        local cvar_maxunlag = client.GetConVar("sv_maxunlag")
        local clr_latencycolor = {colorGradient(latency / (cvar_maxunlag * 1000), {0, 255, 0, 255}, {255, 0, 0, 255})}
        local Mark = nil

        if gui.GetValue("msc_fakelatency_enable") then
            Mark = gui.GetValue("msc_fakelatency_amount") / cvar_maxunlag
        end

        local ibox_latency = drawInfoBox(pos_window, size_infoBox, "Ping", clr_main)

        drawProgress(
            ibox_latency,
            {ibox_latency[3] - ibox_latency[1] - 5, 5},
            latency / (cvar_maxunlag * 1000),
            clr_latencycolor,
            latency,
            clr_latencycolor,
            Mark
        )

        pos_window[2] = pos_window[2] + (30 * dpi_scale)
    end

    if cob_infomode:GetValue() >= 1 and entities.FindByClass("CPlantedC4")[1] ~= nil then
        local ent_c4 = entities.FindByClass("CPlantedC4")[1]

        if ent_c4:GetPropBool("m_bBombTicking") then
            local pos_c4 = {ent_c4:GetAbsOrigin()}
            local str_c4
            local pos_sitea = {entities.GetPlayerResources():GetPropVector("m_bombsiteCenterA")}
            local pos_siteb = {entities.GetPlayerResources():GetPropVector("m_bombsiteCenterB")}
            
            if vector.Distance(pos_sitea, pos_c4) < vector.Distance(pos_siteb, pos_c4) then
                str_c4 = "Bomb A"
            else
                str_c4 = "Bomb B"
            end

            local ibox_bomb = drawInfoBox(pos_window, size_infoBox, str_c4, clr_main)

            if ent_c4:GetPropEntity("m_hBombDefuser") == nil then
                local c4time = math.max(ent_c4:GetPropFloat("m_flC4Blow") - globals.CurTime(), 0)
                local c4fuse = ent_c4:GetPropFloat("m_flTimerLength")
                drawProgress(
                    ibox_bomb,
                    {ibox_bomb[3] - ibox_bomb[1] - 5, 5},
                    c4time / c4fuse,
                    {255, 100, 0, 255},
                    math.floor(c4time)
                )
            else
                local c4time = math.max(ent_c4:GetPropFloat("m_flDefuseCountDown") - globals.CurTime(), 0)
                local c4fuse = ent_c4:GetPropFloat("m_flDefuseLength")
                drawProgress(
                    ibox_bomb,
                    {ibox_bomb[3] - ibox_bomb[1] - 5, 5},
                    c4time / c4fuse,
                    {0, 100, 255, 255},
                    math.floor(c4time)
                )
            end

            pos_window[2] = pos_window[2] + (30 * dpi_scale)
        end
    end

end

local function OnCreateMoveMain(UserCmd)
    if cob_infomode:GetValue() == 2 then
        if UserCmd:GetSendPacket() then
            if Choking then
                Choking = false
            end

            ang_client = {UserCmd:GetViewAngles()}

            if globals.TickCount() > ChokeStart + 2 then
                ang_server = {UserCmd:GetViewAngles()}
            end
        else
            if not Choking then
                Choking = true
                ChokeStart = globals.TickCount()
            end

            ang_server = {UserCmd:GetViewAngles()}
        end
    end
end

callbacks.Register("Draw", OnFrameMain)
callbacks.Register("CreateMove", OnCreateMoveMain)

if gui.GetValue("lua_allow_http") and gui.GetValue("lua_allow_cfg") then
	git_update()
else
	print("[Lua Scripting] Please enable Lua HTTP and Lua script/config editing to check for updates")
end

-- ~ Nyanpasu!
