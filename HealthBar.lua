local obs = obslua

local textFile, interval, debug -- OBS settings
local activeId = 0 -- active timer id
local current = {} -- current values to compare with text file

local allParam = {}
allParam.max = {default = 100}
allParam.min = {default = 0}
allParam.current = {default = 100}
allParam.currentP = {default = 100}
allParam.marker = {default = 0}
allParam.markerP = {default = 0}
allParam.wounds = {default = 0}


-- called when an update to the text file is detected
local function update(i, k, v)
	if debug then obs.script_log(obs.LOG_INFO, string.format("HealthBar: %s has changed to %s", k, v)) end
	
	k = string.lower(k)
	if debug then obs.script_log(obs.LOG_INFO, string.format("HealthBar: split2 to: %s, %s", i,k)) end
	
	if k == "aktuell" or k == "current" then
		allParam.current[i] = tonumber(v)
	elseif k == "wunden" or k == "wounds" then 
		allParam.wounds[i] = tonumber(v)
	elseif k == "marker" or k == "mark" then 
		allParam.marker[i] = tonumber(v)
	elseif k == "max" or k == "maximum" then 
		allParam.max[i] = tonumber(v)
	elseif k == "min" or k == "minimum" then 
		allParam.min[i] = tonumber(v)
	end
	
	if not allParam.current[i] then allParam.current[i] = 0 end
	if not allParam.min[i] then allParam.min[i] = 0 end
	if not allParam.max[i] then allParam.max[i] = 0 end
	if not allParam.marker[i] then allParam.marker[i] = 0 end
	
	if i ~= "" then
		allParam.currentP[i] = (allParam.current[i]-allParam.min[i])*100 / (allParam.max[i] - allParam.min[i])
		if allParam.currentP[i] >100 then allParam.currentP[i] = 100 end
		allParam.markerP[i] = (allParam.marker[i]-allParam.min[i])*100 / (allParam.max[i] - allParam.min[i])
	end
end


local function checkFile(id)
	-- if the script has reloaded then stop any old timers
	if (id < activeId) then
		obs.remove_current_callback()
		return
	end

	if debug then obs.script_log(obs.LOG_INFO, string.format("HealthBar: (%d) Checking text file...(%d)", id, interval)) end
	local f, err = io.open(textFile, "rb")
	if f then
		local line
		for line in f:lines() do
			-- check for key=value
			local i, k, v = line:match("^([^:]+):([^=]+)%=(.+)$")
			if debug then obs.script_log(obs.LOG_INFO, string.format("HealthBar: split to: %s %s, %s", i, k,v)) end
			if k and v then
				update(i, k, v)
			end
		end
		f:close()
	else
		if debug then obs.script_log(obs.LOG_INFO, string.format("HealthBar: Error reading text file : ", err)) end
	end
	
end

----------------------------------------------------------
-- Script management functions

-- called on startup
function script_load(settings)
end


-- called on unload
function script_unload()
end




-- return description shown to user
function script_description()
	return "provides an \"Health Bar\" Source controlled by an text file"
end


-- define properties that user can change
function script_properties()
	local props = obs.obs_properties_create()
	obs.obs_properties_add_path(props, "textFile", "Text File", obs.OBS_PATH_FILE, "", nil)
	obs.obs_properties_add_int(props, "interval", "Interval (ms)", 1000, 20000, 500)
	obs.obs_properties_add_bool(props, "debug", "Debug")
	return props
end


-- set default values
function script_defaults(settings)
	obs.obs_data_set_default_string(settings, "textFile", "")
	obs.obs_data_set_default_int(settings, "interval", 1000)
	obs.obs_data_set_default_bool(settings, "debug", false)
end


-- save additional data not set by user
function script_save(settings)
  obs.obs_save_sources()
end


local function init()
	-- increase the timer id - old timers will be cancelled
	activeId = activeId + 1	
	obs.script_log(obs.LOG_INFO, string.format("HealthBar: Init ID=%d",activeId))
	-- only proceed if there is a text file selected
	if not textFile then return nil end

	-- read the file 

	-- start the timer to check the text file
	local id = activeId
	obs.timer_add(function() checkFile(id) end, interval)
	obs.script_log(obs.LOG_INFO, string.format("HealthBar: global Text monitor started"))
end

-- called when settings changed
function script_update(settings)
	textFile = obs.obs_data_get_string(settings, "textFile")
	interval = obs.obs_data_get_int(settings, "interval")
	debug = obs.obs_data_get_bool(settings, "debug")
	init()
end


----------------------------------------------------------
-- Source management functions
source_def = {}
source_def.id = "HealthBar_source"
source_def.output_flags = bit.bor(obs.OBS_SOURCE_VIDEO, obs.OBS_SOURCE_CUSTOM_DRAW)

function image_source_load(image, file)
	obs.obs_enter_graphics();
	obs.gs_image_file_free(image);
	obs.obs_leave_graphics();

	obs.gs_image_file_init(image, file);

	obs.obs_enter_graphics();
	obs.gs_image_file_init_texture(image);
	obs.obs_leave_graphics();

	if not image.loaded then
		print("failed to load texture " .. file);
	end
end

source_def.get_name = function()
	return "Health Bar"
end

-- called upon settings change
local function set_bar_color(data)
		if 		data.Color == "green" then data.bar = data.greenbar
		elseif	data.Color == "blue"  then data.bar = data.bluebar
		else data.bar = data.redbar
		end
end

source_def.update = function(data, settings)
	data.tID 			= obs.obs_data_get_string(settings, "tID")
	data.Typ 			= obs.obs_data_get_string(settings, "lTyp")
	data.Color			= obs.obs_data_get_string(settings, "lColor")
	data.WoundTyp		= obs.obs_data_get_string(settings, "lWoundTyp")
	data.Woundposition	= obs.obs_data_get_string(settings, "lWoundposition")
	data.WoundGap		= 10
	
	if data.tID:find("[:=]") then
		data.tID = data.tID:gsub("[:=]","-")
		obs.obs_data_set_string (settings, "tID", data.tID)
	end

	if data.WoundTyp == "slash" then
		data.woundMarker = data.woundSlash
		data.XWoundDistance = data.woundMarker.cx-10
	elseif data.WoundTyp == "bigslash" then
		data.woundMarker = data.woundBigSlash
		data.XWoundDistance = data.woundMarker.cx-100
	else
		data.woundMarker = data.woundHeart
		data.XWoundDistance = data.woundMarker.cx+10
	end


	if data.Typ == "bowl" then 
		data.width = data.bowl.cx
		data.height = data.bowl.cy
	elseif data.Typ == "bar" then
		set_bar_color(data)
		data.width = data.backdrop.cx
		data.height = data.backdrop.cy + data.WoundGap + data.woundMarker.cy
	elseif data.Typ == "onlybar" then
		set_bar_color(data)
		data.width = data.backdrop.cx
		data.height = data.backdrop.cy
	elseif data.Typ == "wounds" then 
		data.width = 400
		data.height = data.woundMarker.cy
	end
	if data.height<100 then data.height = 100 end
	if data.width<200 then data.width = 200 end


	if data.Woundposition == "above" then
		data.YOffset = data.WoundGap+data.woundMarker.cy
		data.YWoundPosition = 0
	else
		data.YOffset = 0
		data.YWoundPosition = data.height-data.WoundGap-data.woundMarker.cy
	end

end


function prop_change_callback(props, property, settings)
	local typ = obs.obs_data_get_string(settings, "lTyp")

	obs.obs_property_set_visible(obs.obs_properties_get(props, "lColor"), 			typ == "bar" or typ == "onlybar" or typ=="bowl" )
	obs.obs_property_set_visible(obs.obs_properties_get(props, "lWoundTyp"), 		typ == "bar" or typ == "wounds" )
	obs.obs_property_set_visible(obs.obs_properties_get(props, "lWoundposition"), 	typ == "bar" )

	return true
end 

-- defines the source specific settings dialog
source_def.get_properties = function(data)
	local props = obs.obs_properties_create()
	
	local tID = obs.obs_properties_add_text(props, "tID", "ID (optional)", obs.OBS_TEXT_DEFAULT)
	obs.obs_property_set_long_description(tID, "The individial ID of the bar/bowl.If you set this property, you can control multiple bars/bowls in one control file with key like ID:current=5.")
	obs.obs_property_set_modified_callback (tID, prop_change_callback)
	
	local lTyp = obs.obs_properties_add_list(props, "lTyp", "Type of the Bar", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(lTyp, "Bar + Wounds", "bar")
	obs.obs_property_list_add_string(lTyp, "Bar", "onlybar")
--	obs.obs_property_list_add_string(lTyp, "Bowl", "bowl")
	obs.obs_property_list_add_string(lTyp, "Only wounds", "wounds")
	obs.obs_property_set_long_description(lTyp, "The Type of the Bar displayed.")
	obs.obs_property_set_modified_callback(lTyp, prop_change_callback)
	
	local lColor = obs.obs_properties_add_list(props, "lColor", "Color of the bar/liquid", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(lColor, "Red", "red")
	obs.obs_property_list_add_string(lColor, "Green", "green")
	obs.obs_property_list_add_string(lColor, "Blue", "blue")
	obs.obs_property_set_long_description(lColor, "The color of the health bar or liquid in the health bowl.")
	obs.obs_property_set_modified_callback(lColor, prop_change_callback)
	
	local lWoundTyp = obs.obs_properties_add_list(props, "lWoundTyp", "Wound Type", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(lWoundTyp, "Broken heart symbol", "heart")
	obs.obs_property_list_add_string(lWoundTyp, "\"realistic\" Slash", "slash")
	obs.obs_property_list_add_string(lWoundTyp, "Big slash", "bigslash")
	obs.obs_property_set_long_description(lWoundTyp, "Which type of wounds do you want displayed?.")
	obs.obs_property_set_modified_callback (lWoundTyp, prop_change_callback)

	local lWoundposition = obs.obs_properties_add_list(props, "lWoundposition", "Display Wounds", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(lWoundposition, "Above the Bar", "above")
	obs.obs_property_list_add_string(lWoundposition, "Below the Bar", "below")
	obs.obs_property_set_long_description(lWoundposition, "Set the Position of the wound display relative to the health bar.")
	obs.obs_property_set_modified_callback(lWoundposition, prop_change_callback)
	
	obs.obs_properties_apply_settings(props, settings)
	
	return props
end

source_def.get_defaults = function(settings) 
   obs.obs_data_set_default_string(settings, "lTyp", "bar")
   obs.obs_data_set_default_string(settings, "lColor", "red")
   obs.obs_data_set_default_string(settings, "lWoundTyp", "heart")
   obs.obs_data_set_default_string(settings, "lWoundposition", "below")
end


source_def.create = function(settings, source)
	local data = {}
	
	data.backdrop = obs.gs_image_file()
	data.bar = obs.gs_image_file()
	data.redbar = obs.gs_image_file()
	data.greenbar = obs.gs_image_file()
	data.bluebar = obs.gs_image_file()
	data.markerbar = obs.gs_image_file()
	data.woundHeart = obs.gs_image_file()
	data.woundSlash = obs.gs_image_file()
	data.woundBigSlash = obs.gs_image_file()
	data.woundMarker = obs.gs_image_file()
	data.bowl = obs.gs_image_file()
	data.redliquid = obs.gs_image_file()
	
	local p = script_path()
	image_source_load(data.backdrop, 		p .. "img/BackgroundBar.png")
	image_source_load(data.redbar, 			p .. "img/RedBar.png")
	image_source_load(data.greenbar, 		p .. "img/GreenBar.png")
	image_source_load(data.bluebar, 		p .. "img/BlueBar.png")
	image_source_load(data.markerbar, 		p .. "img/Marker.png")
	image_source_load(data.woundHeart, 		p .. "img/WoundHeart.png")
	image_source_load(data.woundSlash, 		p .. "img/WoundSlash.png")
	image_source_load(data.woundBigSlash, 	p .. "img/WoundBigSlash.png")
	image_source_load(data.bowl, 			p .. "img/Bowl.png")
	image_source_load(data.redliquid, 		p .. "img/RedLiquid.png")
	
	data.tID = ""
	data.Typ = "bar"
	data.bar = data.redbar
	data.woundMarker = data.woundHeart
	data.width = 0
	data.height = 0
	data.YOffset = 0
	data.WoundGap = 0
	data.YWoundOffset = 0
	data.YWoundPosition = 0
	data.XWoundDistance = data.woundMarker.cx+10
	
	obs.obs_source_update(source, settings)
	
	return data
end

source_def.destroy = function(data)
	obs.obs_enter_graphics();
	obs.gs_image_file_free(data.backdrop);
	obs.gs_image_file_free(data.bar);
	obs.gs_image_file_free(data.redbar);
	obs.gs_image_file_free(data.greenbar);
	obs.gs_image_file_free(data.bluebar);
	obs.gs_image_file_free(data.markerbar);
	obs.gs_image_file_free(data.woundMarker);
	obs.gs_image_file_free(data.bowl);
	obs.gs_image_file_free(data.redliquid);
	
	obs.obs_leave_graphics();
end

-- called during render
source_def.video_render = function(data, effect)
	
	if not data.backdrop then return; end;
	if not data.backdrop.texture then return; end;
	local tID = data.tID

	effect = obs.obs_get_base_effect(obs.OBS_EFFECT_DEFAULT)

	obs.gs_blend_state_push()
	obs.gs_reset_blend_state()

	while obs.gs_effect_loop(effect, "Draw") do
		-- draw lifepoint display
		if data.Typ == "bowl" then
				obs.obs_source_draw(data.redliquid.texture, 16, 16+data.YOffset, data.redliquid.cx, data.redliquid.cy, false);
				obs.obs_source_draw(data.bowl.texture, 0, data.YOffset, data.bowl.cx, data.bowl.cy, false);
		elseif data.Typ == "bar" or data.Typ == "onlybar" then
			obs.obs_source_draw(data.backdrop.texture, 0, data.YOffset, data.backdrop.cx, data.backdrop.cy, false);
			if allParam.currentP[tID] then if allParam.currentP[tID] > 0 and allParam.currentP[tID] <= 100 then obs.obs_source_draw(data.bar.texture, 10, 15+data.YOffset, 1210*allParam.currentP[tID]/100 , data.bar.cy, false); end end
			if allParam.markerP[tID] then if (allParam.markerP[tID] > 0) and (allParam.markerP[tID] < 100) then obs.obs_source_draw(data.markerbar.texture, 1210*allParam.markerP[tID]/100, 11+data.YOffset, data.markerbar.cx , data.markerbar.cy, false); end end
		end
		-- draw wounds
		if allParam.wounds[tID] then
			if allParam.wounds[tID] > 0 and (data.Typ == "bar" or data.Typ == "wounds") then
				for i = 0, allParam.wounds[tID]-1, 1
				do
					obs.obs_source_draw(data.woundMarker.texture, 11+(i*data.XWoundDistance), data.YWoundPosition, data.woundMarker.cx , data.woundMarker.cy, false);
				end
			end
		end
	end
	obs.gs_blend_state_pop()
end

source_def.get_width = function(data)
	return data.width
end

source_def.get_height = function(data)
	return data.height
end


obs.obs_register_source(source_def)