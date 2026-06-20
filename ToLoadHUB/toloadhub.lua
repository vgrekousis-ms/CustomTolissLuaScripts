--[[
    ToLoadHUB
    Author: Manta32
    Special thanks to: Giulio Cataldo for the night spent suffering with me
    Description:
    A FlyWithLua plugin for X-Plane 12 to manage passengers and loadsheet for ToLISS airplanes.
    Features include automatic loading from SimBrief, random passenger generation, and real-time loading.

    TODO: Missing max Fuel and Cargo for A339 and A346
    License: MIT License
--]]

local toLoadHub_flight_no = "" -- normally a dataref from toliss, but, does not longer exist in toliss_airbus datarefs.
-- currenly assigned as per simbrief callsign upon fetch. fetchSimbriefFPlan

---@diagnostic disable: undefined-global
local valid_plane_icao = { A319 = true, A20N = true, A321 = true, A21N = true, A346 = true, A339 = true }

-- == CONFIGURATION DEFAULT VARIABLES ==
local toLoadHub = {
    title = "ToLoadHUB",
    version = "1.2.1-revized",
    file = "toLoadHub.ini",
    visible_main = false,
    visible_settings = false,
    visible_fuel = true,
    pax_count = 0, -- old intendedPassengerNumber
    bag_weight = 0,
    bag_count_actual = 0,
	pax_weight = 0,
	payload = 0,
	freight_added = 0,
    max_passenger = 224,
    max_cargo_fwd = 3000,
    max_cargo_aft = 5000,
    max_fuel = 20000,
    fuel_to_load = 0,
    fuel_to_load_next = os.time(),
    fuel_engines_on = nil,
    fuel_engines_off = nil,
    cargo = 0,
    error_message = nil,
    cargo_aft = 0,
    cargo_fwd = 0,
    fueling_speed_per_second = {
        refuel = 20, 
        defuel = 30
    },
    tank_num = 0,
    pax_distribution_range = {35, 60},
    cargo_fwd_distribution_range = {55, 75},
    cargo_starting_range = {45, 60},
    cargo_speeds = {0, 4, 10},
    kgPerUnit = 25,
    first_init = false,
    is_lbs = false,
    unitLabel = "KGS",
    unitTLabel = "T",
    flt_no = "",
    fuel_tank = {
        fuel1 = 0, 
        fuel2 = 0,
        fuel3 = 0,
    },
    fuel_tank_check = os.time(),
    phases = {
        is_jetway = false,
        is_refueling = false,
        is_defueling = false,
        is_ready_to_start = false,
        is_gh_started = false,
        is_pax_onboard_enabled = false,
        is_onboarding = false,
        is_pax_onboarded = false,
        is_pax_deboarded = false,
        is_cargo_started = false,
        is_cargo_onboarded = false,
        is_cargo_deboarded = false,
        is_onboarding_pause = false,
        is_onboarded = false,
        is_flying = false,
        is_landed = false,
        is_deboarding = false,
        is_deboarding_pause = false,
        is_deboarded = false,
    },
    focus_windows = {
        pax_load = false,
        pax_loaded = false,
        cargo_load = false,
        cargo_loaded = false,
        we_are_landed = false,
        pax_unload = false,
        pax_unloaded = false,
        cargo_unload = false,
        cargo_unloaded = false,
        all_unload = false,
        all_unloaded = false
    },
    fuel_dots_index = 0,
    fuel_dots_time = os.clock(),
    toggle_window = os.clock(),
    toggle_fuel = os.clock(),
    toggle_pax = os.clock(),
    boarding_secnds_per_pax = 0,
    set_default_seconds = false,
    simulate_result = false,
    simulate_fast_value = 0,
    simulate_real_value = 0,
    next_boarding_check = os.time(), -- old nextTimeBoardingCheck
    next_cargo_check = os.time(),
    wait_until_speak = os.time(),
    setWeightTime = os.time(),
    next_ready_to_start_check = os.time(),
    what_to_speak = nil,
    boarding_sound_played = false,
    deboarding_sound_played = false,
    boarding_cargo_sound_played = false,
    deboarding_cargo_sound_played = false,
    setWeightCommand = false,
    full_deboard_sound = false,
    is_onground = true,
    chocks_off_time = os.date("%H:%M"),
    chocks_on_time = os.date("%H:%M"),
    chocks_out_time = os.date("%H:%M"),
    chocks_in_time = os.date("%H:%M"),
    chocks_off_set = false,
    chocks_on_set = false,
    chocks_out_set = false,
    chocks_in_set = false,
    hoppie = {
        loadsheet_sent = false,
        loadsheet_sending = false,
        loadsheet_preliminary_ready = false,
        loadsheet_preliminary_sent = false,
        loadsheet_chocks_off_sent = false,
        loadsheet_chocks_on_sent = false,
        loadsheet_check = os.time(),
    },
    simbrief = {
        est_block = nil,
        callsign = nil,
        plan_ramp = nil,
        cargo = nil,
        pax_count = nil,
        bag_weight = nil,
        bag_count_actual = nil,
		pax_weight = nil,
		payload = nil,
        est_zfw = nil,
        total_burn = nil,
        taxi = nil,
        units = nil,
        origin = nil,
        destination = nil,
    },
    settings = {
        general = {
            debug = false,
            window_width = 400,
            window_height = 250,
            window_x = 160,
            window_y = 200,
            auto_open = true,
            auto_init = true,
            simulate_cargo = true,
            simulate_fuel = true,
            simulate_init_fuel = false,
            randomize_pax_bag_weight_per_pax = false,
            use_toliss_refuel_defuel = false,
            concourrent_cargo = false,
            pax_delayed = false,
            boarding_speed = 0,
            is_jetbridge = false,
            simulate_jdgh = false,
            automate_jetway = false,
            is_lbs = false,
            mute_init_failed_validation_sound = false,
        },
        simbrief = {
            username = "",
            auto_fetch = true,
            randomize_passenger = true,
            round_up_fuel = 1 -- 0 = off, 1 = 10, 2 = 50, 3 = 100
        },
        hoppie = {
            secret = "",
            enable_loadsheet = true,
            preliminary_loadsheet = true,
            chocks_loadsheet = true,
            utc_time = false,
            display_pax = false,
        },
        sayintentions = {
            api_key = "",
            use_sayintentions = false, -- Toggle between Hoppie and SayIntentions
            station = "OPS", -- Station name for ACARS messages
        },
        door = {
            close_boarding = true,
            close_deboarding = true,
			close_deboarding_cargo = true,
            open_boarding = 0,
            open_deboarding = 0
        }
    }
}

local loadsheetStructure = {
    new = function(self)
        local obj = {
            typeL = 0, -- 0 = preliminary, 1 = final, 2 = chocks off, 3 = chocks on
            warning = "",
            labelText = "",
            flt_no = "",
            zfw = "",
            zfwcg = "",
            gwcg = "",
            f_blk = "",
            pax = ""
        }
        setmetatable(obj, self)
        self.__index = self
        return obj
    end
}

local toloadhub_window = nil

local urls = {
    simbrief_fplan_id = "http://www.simbrief.com/api/xml.fetcher.php?userid=",
    simbrief_fplan_user = "http://www.simbrief.com/api/xml.fetcher.php?username=",
    hoppie_connect = "https://www.hoppie.nl/acars/system/connect.html"
}
local LIP = require("LIP")
local http = require("socket.http")
local ltn12 = require("ltn12")

-- SayIntentions API support
local SayIntentionsAPI = nil
local sapiClient = nil
local success, err = pcall(function()
    SayIntentionsAPI = require("SayIntentionsAPI")
    logMsg("[ToLoadHUB] SayIntentionsAPI module loaded")
end)
if not success then
    logMsg("[ToLoadHUB] WARNING: SayIntentionsAPI module not found - SayIntentions support disabled")
    logMsg("[ToLoadHUB] Error: " .. tostring(err))
end

local toLoadHub_NoPax = 0
local toLoadHub_AftCargo = 0
local toLoadHub_FwdCargo = 0
local toLoadHub_PaxDistrib = 0.5

if not SUPPORTS_FLOATING_WINDOWS then
    -- to make sure the script doesn't stop old FlyWithLua versions
    logMsg("imgui not supported by your FlyWithLua version")
    return
end

require("LuaXml")

math.randomseed(os.time())

-- == Helper Functions ==
local function animate_dots()
    if os.clock() > toLoadHub.fuel_dots_time then 
        toLoadHub.fuel_dots_index = (toLoadHub.fuel_dots_index + 1) % 6
        toLoadHub.fuel_dots_time = os.clock() + 0.2
    end
    local str = string.rep(".", toLoadHub.fuel_dots_index)
    return str .. string.rep(" ", 6 - #str)
end

local function round_up_to_unit(number)
    -- 0 = off, 1 = 10, 2 = 50, 3 = 100
    if toLoadHub.settings.simbrief.round_up_fuel == 1 then
         return math.ceil(number / 10) * 10
    elseif toLoadHub.settings.simbrief.round_up_fuel == 2 then
        return math.ceil(number / 50) * 50
    elseif toLoadHub.settings.simbrief.round_up_fuel == 3 then
        return math.ceil(number / 100) * 100
    end
    return number
end


local function convertToKgs(value)
    return value / 2.205
end

local function convertToLbs(value)
    return value * 2.205
end


local function writeInUnitLbs(value)
    if toLoadHub.is_lbs then
        return convertToKgs(value)
    else
        return value
    end
end

local function writeInUnitKg(value)
    if toLoadHub.is_lbs then
        return convertToLbs(value)
    else
        return value
    end
end

local function debug(stringToLog)
    if toLoadHub.settings.general.debug then
        logMsg(stringToLog)
    end
end

local function toBoolean(value)
    if type(value) == "string" then
        value = value:lower()
    end
    if value == "true" or value == true or value == 1 then
        return true
    end
    return false
end

local function calculateTimeWithCargo(a, b)
    local res = a / 2 + b
    return (res < a and a) or (res < b and b) or res
end

local function simulateLoadTime(pax_load_time, cargo_load_time)
    local now = 1
    local next_pax_time = pax_load_time
    local next_cargo_time = cargo_load_time

    local pax_on = 0
    local cargo_on = 0
    local cargo_start = false

    local cargo_starts_at = math.random(toLoadHub.cargo_starting_range[1], toLoadHub.cargo_starting_range[2])
    if toLoadHub.settings.general.concourrent_cargo then
        cargo_starts_at = 0
    end
    if cargo_load_time == 0 then
        cargo_on = toLoadHub.cargo
    end
    while pax_on < toLoadHub.pax_count or cargo_on < toLoadHub.cargo do
        if now >= next_pax_time and pax_on < toLoadHub.pax_count then
            if toLoadHub.phases.is_onboarded then
                -- deboarding
                pax_on = pax_on + math.random(1, 2)
                next_pax_time = now + pax_load_time + math.random(-2, 0)
            else
                -- boarding
                pax_on = pax_on + 1
                next_pax_time = now + pax_load_time + math.random(-1, 1)
            end

        end
        
        if not cargo_start and pax_on >= toLoadHub.pax_count * (cargo_starts_at / 100) then
            cargo_start = true
        end

        if cargo_start and now >= next_cargo_time and cargo_on < toLoadHub.cargo then
            cargo_on = cargo_on + toLoadHub.kgPerUnit
            next_cargo_time = now + cargo_load_time + math.random(-2, 2)
        end
        now = now + 1
    end
    return math.floor(now / 60)
end

-- == Utility Functions ==
function saveSettingsToFileToLoadHub(final)
    debug(string.format("[%s] saveSettingsToFileToLoadHub(%s)", toLoadHub.title, tostring(final)))
    LIP.save(SCRIPT_DIRECTORY .. toLoadHub.file, toLoadHub.settings)
    debug(string.format("[%s] file saved", toLoadHub.title))
end

local function readSettingsToFile()
    local file, err = io.open(SCRIPT_DIRECTORY .. toLoadHub.file, 'r')
    if not file then return end
    local f = LIP.load(SCRIPT_DIRECTORY .. toLoadHub.file)
    if not f then return end
    for section, settings in pairs(f) do
        if toLoadHub.settings[section] then
            if toLoadHub.settings[section] ~= nil then
                for key, value in pairs(settings) do
                    if toLoadHub.settings[section][key] ~= nil then
                        if type(toLoadHub.settings[section][key]) == 'boolean' then
                            toLoadHub.settings[section][key] = toBoolean(value)
                        elseif type(toLoadHub.settings[section][key]) == 'number' then
                            toLoadHub.settings[section][key] = math.floor(value)
                        else
                            toLoadHub.settings[section][key] = value
                        end
                    end
                end
            end
        end
    end
end

local function randomizePassengerBagWeightPerPaxCountToCargo(bag_count_actual, max_pax_bag_weight, freight_added)
    -- The calculation here is as per SimBrief's definition on cargo, but with randomization on the bag_weight
    -- Without randomization, the returned value should match the cargo as per simbrief ofp.
    local totalBaggageWeight = 0
    for i = 1, bag_count_actual do
        local baggageWeight = math.random(10, max_pax_bag_weight)
        totalBaggageWeight = totalBaggageWeight + baggageWeight
    end

    return totalBaggageWeight + freight_added
end

local function doRandomizePassengerBagWeightPerPaxCountToCargo()
    if toLoadHub.settings.general.randomize_pax_bag_weight_per_pax == true then
        local cargo = toLoadHub.simbrief.cargo
        local newCargo = randomizePassengerBagWeightPerPaxCountToCargo(toLoadHub.simbrief.bag_count_actual, toLoadHub.simbrief.bag_weight, toLoadHub.simbrief.freight_added)
        
        -- Update the cargo parameters
        toLoadHub.cargo = newCargo
        toLoadHub.simbrief.cargo = newCargo
        
        debug(string.format("[%s] [Random Pax Baggage Weights]\nInitial Cargo as per OFP: %.2f\nNew Cargo: %.2f", toLoadHub.title, cargo, newCargo))
    end
end

local function divideCargoFwdAft()
    local randomPercentage = math.random(toLoadHub.cargo_fwd_distribution_range[1], toLoadHub.cargo_fwd_distribution_range[2]) / 100
    -- Calculate forward and aft cargo
    toLoadHub.cargo_fwd = toLoadHub.cargo * randomPercentage
    toLoadHub.cargo_aft = toLoadHub.cargo - toLoadHub.cargo_fwd
end

local function calculateTankNumber()
    toLoadHub.tank_num = (toLoadHub_fuel_1 > 0 and 1 or 0) + (toLoadHub_fuel_2 > 0 and 1 or 0) + (toLoadHub_fuel_3 > 0 and 1 or 0)
    if toLoadHub.fuel_tank.fuel1 == toLoadHub_fuel_1 and toLoadHub_fuel_1 > 0 then toLoadHub.tank_num = toLoadHub.tank_num - 1 end
    if toLoadHub.fuel_tank.fuel2 == toLoadHub_fuel_2 and toLoadHub_fuel_2 > 0 then toLoadHub.tank_num = toLoadHub.tank_num - 1 end
    if toLoadHub.fuel_tank.fuel3 == toLoadHub_fuel_3 and toLoadHub_fuel_3 > 0  then toLoadHub.tank_num = toLoadHub.tank_num - 1 end
    if toLoadHub.fuel_tank_check < os.time() then
        toLoadHub.fuel_tank_check = os.time() + 2
        toLoadHub.fuel_tank.fuel1 = toLoadHub_fuel_1
        toLoadHub.fuel_tank.fuel2 = toLoadHub_fuel_2
        toLoadHub.fuel_tank.fuel3 = toLoadHub_fuel_3
    end
    if toLoadHub.tank_num <= 0 then toLoadHub.tank_num = 1 end
    return toLoadHub.tank_num
end

local function setIsLib()
    if toLoadHub.is_lbs then
        toLoadHub.unitLabel = "LBS"
        toLoadHub.unitTLabel = "kip"
    else
        toLoadHub.unitLabel = "KGS"
        toLoadHub.unitTLabel = "T"
    end
end

local function fetchSimbriefFPlan()
    if not toLoadHub.settings.simbrief.username or toLoadHub.settings.simbrief.username:gsub("^%s*(.-)%s*$", "%1") == "" then
        toLoadHub.error_message = "Simbrief username not set."
        debug(string.format("[%s] SimBrief username not set.", toLoadHub.title))
        return false
    end

    local response_xml, statusCode = http.request(urls.simbrief_fplan_user .. toLoadHub.settings.simbrief.username)

    if statusCode ~= 200 and statusCode ~= 400 then
        toLoadHub.error_message = "Simbrief error, please try again."
        debug(string.format("[%s] SimBrief API returned an error: [%d]", toLoadHub.title, statusCode))
        return false
    end

    local xml_data = xml.eval(response_xml)
    if not xml_data then
        toLoadHub.error_message = "Simbrief error, please try again."
        debug(string.format("[%s] XML from SimBrief not valid.", toLoadHub.title))
        return false
    end

    local status = xml_data:find("status")
    if statusCode == 400 and status and status[1] then
        toLoadHub.error_message = 'SimBrief ' .. status[1]
        debug(string.format("[%s] SimBrief code [%d] status: [%s]", toLoadHub.title, statusCode, status[1]))
        return false
    end

    if not status or status[1]  ~= "Success" then
        toLoadHub.error_message = "Simbrief error, please try again."
        debug(string.format("[%s] Simbrief Status not Success.", toLoadHub.title))
        return false
    end
    -- ICAO VERIFICATION
    local origin_tag = xml_data:find("origin")
    local origin = origin_tag:find("icao_code")
    toLoadHub.simbrief.origin = origin[1]
    if toLoadHub.simbrief.origin then
        local next_airport_index = XPLMFindNavAid( nil, nil, LATITUDE, LONGITUDE, nil, xplm_Nav_Airport)
        if next_airport_index then
            local _, _, _, _, _, _, airpICAO, airpNAME = XPLMGetNavAidInfo( next_airport_index )
            if airpICAO:lower() ~= toLoadHub.simbrief.origin:lower() then
                toLoadHub.error_message = string.format("SimBrief flight plan departure from %s \ndoes not match current location %s (%s).", toLoadHub.simbrief.origin, 
                    airpNAME, airpICAO) 
                debug(string.format("[%s] Simbrief ICAO Not matching %s -> %s", toLoadHub.title, 
                    toLoadHub.simbrief.origin, airpICAO))
                toLoadHub.simbrief.origin = nil
                return false
            end
        end
    end

    local pax_count = xml_data:find("pax_count")
    toLoadHub.pax_count = tonumber(pax_count[1])
    toLoadHub.simbrief.pax_count = toLoadHub.pax_count

    if toLoadHub.settings.simbrief.randomize_passenger then
        local r = 0.01 * math.random(95, 103)
        toLoadHub.pax_count = math.floor(toLoadHub.pax_count * r)
        if toLoadHub.pax_count > toLoadHub.max_passenger then toLoadHub.pax_count = toLoadHub.max_passenger end
    end

    local destination_tag = xml_data:find("destination")
    local destination = destination_tag:find("icao_code")
    toLoadHub.simbrief.destination = destination[1]

    local callsign = xml_data:find("callsign")
    toLoadHub.simbrief.callsign = callsign[1]
    toLoadHub_flight_no = toLoadHub.simbrief.callsign

    if toLoadHub.visible_main and toLoadHub.simbrief.origin and toLoadHub.simbrief.destination and toLoadHub.simbrief.callsign then
        float_wnd_set_title(toloadhub_window, string.format("%s - v%s | %s - %s | %s", toLoadHub.title, toLoadHub.version, toLoadHub.simbrief.origin, toLoadHub.simbrief.destination, toLoadHub.simbrief.callsign))
    end

    local est_block = xml_data:find("est_block")
    toLoadHub.simbrief.est_block = tonumber(est_block[1])

    local est_zfw = xml_data:find("est_zfw")
    toLoadHub.simbrief.est_zfw = tonumber(est_zfw[1])

    local units = xml_data:find("units")
    toLoadHub.simbrief.units = tostring(units[1])
    
    local plan_ramp = xml_data:find("plan_ramp")
    toLoadHub.simbrief.plan_ramp = tonumber(plan_ramp[1])
    toLoadHub.fuel_to_load = round_up_to_unit(toLoadHub.simbrief.plan_ramp)

    local total_burn = xml_data:find("total_burn")
    toLoadHub.simbrief.total_burn = tonumber(total_burn[1])
    local taxi = xml_data:find("taxi")
    toLoadHub.simbrief.taxi = tonumber(taxi[1])

    local cargo = xml_data:find("cargo") 		-- Simbrief calculates: cargo = (pax_count * bag_weight) + freight_added
                                                -- (or: instead of pax_count, maybe better use bag_count_actual?)
	local payload = xml_data:find("payload") 	-- Simbrief calculates: payload = (pax_count * (pax_weight + bag_weight)) + freight_added
	local freight_added = xml_data:find("freight_added")
	local bag_weight = xml_data:find("bag_weight")
	local pax_weight = xml_data:find("pax_weight")
    local bag_count_actual = xml_data:find("bag_count_actual")
    toLoadHub.bag_count_actual = tonumber(bag_count_actual[1])

     if toLoadHub.simbrief.units:lower() == 'lbs' then
        toLoadHub.is_lbs = true
        toLoadHub.cargo = convertToKgs(tonumber(cargo[1]))
		toLoadHub.payload = convertToKgs(tonumber(payload[1]))
		toLoadHub.freight_added = convertToKgs(tonumber(freight_added[1]))
		toLoadHub.pax_weight = convertToKgs(tonumber(pax_weight[1]))
		toLoadHub.bag_weight = convertToKgs(tonumber(bag_weight[1]))
    else
        toLoadHub.is_lbs = false
        toLoadHub.cargo = tonumber(cargo[1])
		toLoadHub.payload = tonumber(payload[1])
		toLoadHub.freight_added = tonumber(freight_added[1])
		toLoadHub.pax_weight = tonumber(pax_weight[1])
		toLoadHub.bag_weight = tonumber(bag_weight[1])
    end

    setIsLib()
    toLoadHub.simbrief.cargo = toLoadHub.cargo
    toLoadHub.simbrief.payload = toLoadHub.payload
	toLoadHub.simbrief.freight_added = toLoadHub.freight_added
	toLoadHub.simbrief.pax_weight = toLoadHub.pax_weight
	toLoadHub.simbrief.bag_weight = toLoadHub.bag_weight
    toLoadHub.simbrief.bag_count_actual = toLoadHub.bag_count_actual
	doRandomizePassengerBagWeightPerPaxCountToCargo()

    XPLMSpeakString("Simbrief Data Acquired")
    debug(string.format("[%s] SimBrief XML downloaded and parsed.", toLoadHub.title))
    -- TODO
end

local function setIscsTemporarySimbrief()
    toLoadHub_NoPax_XP = toLoadHub.simbrief.pax_count
    toLoadHub_AftCargo_XP = toLoadHub.cargo_aft
    toLoadHub_FwdCargo_XP = toLoadHub.cargo_fwd
end

local function isAllEngineOff()
    local engine = dataref_table("sim/flightmodel/engine/ENGN_running")
    local all_zero = true
    if engine[0] == 1 or engine[1] == 1 or engine[2] == 1 or engine[3] == 1 then
        all_zero = false
    end
    return all_zero
end

local function isAnyEngineBurningFuel()
    local engine = dataref_table("sim/flightmodel2/engines/engine_is_burning_fuel")
    local all_zero = false
    if engine[0] == 1 or engine[1] == 1 or engine[2] == 1 or engine[3] == 1 then
        all_zero = true
    end
    return all_zero
end


local function setAirplaneNumbers()
    if PLANE_ICAO == "A319" then
        toLoadHub.max_passenger = 145
        toLoadHub.max_cargo_fwd = 2268
        toLoadHub.max_cargo_aft = 4518
        toLoadHub.max_fuel = 18678
    elseif PLANE_ICAO == "A21N" then
        local a321EngineTypeIndex = dataref_table("AirbusFBW/EngineTypeIndex")
        toLoadHub.max_cargo_fwd = 5670
        toLoadHub.max_cargo_aft = 7167
        toLoadHub.max_fuel = 23157
        if a321EngineTypeIndex[0] == 0 or a321EngineTypeIndex[0] == 1 then
            toLoadHub.max_passenger = 220
        else
            toLoadHub.max_fuel = 28645
            toLoadHub.max_passenger = 244
        end
     elseif PLANE_ICAO == "A321" then
        local a321EngineTypeIndex = dataref_table("AirbusFBW/EngineTypeIndex")
        toLoadHub.max_cargo_fwd = 5670
        toLoadHub.max_cargo_aft = 7167
        toLoadHub.max_fuel = 23157
        if a321EngineTypeIndex[0] == 0 or a321EngineTypeIndex[0] == 1 then
            toLoadHub.max_passenger = 220
        else
            toLoadHub.max_passenger = 224
        end
    elseif PLANE_ICAO == "A20N" then
        toLoadHub.max_passenger = 188
        toLoadHub.max_cargo_fwd = 3402
        toLoadHub.max_cargo_aft = 6033
        toLoadHub.max_fuel = 18573
    elseif PLANE_ICAO == "A339" then
        toLoadHub.max_passenger = 375
    elseif PLANE_ICAO == "A346" then
        toLoadHub.max_passenger = 440
    end
end

local function resetAirplaneParameters(initJetway)
    toLoadHub_NoPax = 0
    toLoadHub_AftCargo = 0
    toLoadHub_FwdCargo = 0
    toLoadHub_PaxDistrib = 0.5
    toLoadHub.pax_count = 0
    toLoadHub.bag_weight = 0
    toLoadHub.bag_count_actual = 0
	toLoadHub.pax_weight = 0
	toLoadHub.payload = 0
	freight_added = 0
    toLoadHub.cargo = 0
    toLoadHub.cargo_aft = 0
    toLoadHub.cargo_fwd = 0
    toLoadHub.boarding_secnds_per_pax = 0
    toLoadHub.fuel_dots_index = 0
    toLoadHub.fuel_dots_time = os.clock()
    toLoadHub.simulate_result = false
    toLoadHub.visible_fuel = true
    toLoadHub.simulate_fast_value = 0
    toLoadHub.simulate_real_value = 0
    toLoadHub.set_default_seconds = false
    toLoadHub.boarding_secnds_per_cargo_unit = 0
    toLoadHub.next_boarding_check = os.time()
    toLoadHub.next_cargo_check = os.time()
    toLoadHub.wait_until_speak = os.time()
    toLoadHub.setWeightTime = os.time()
    toLoadHub.next_ready_to_start_check = os.time()
    toLoadHub.chocks_off_time = os.date("%H:%M:%S")
    toLoadHub.chocks_on_time = os.date("%H:%M:%S")
    toLoadHub.chocks_out_time = os.date("%H:%M:%S")
    toLoadHub.chocks_in_time = os.date("%H:%M:%S")
    toLoadHub.chocks_off_set = false
    toLoadHub.chocks_on_set = false
    toLoadHub.chocks_out_set = false
    toLoadHub.chocks_in_set = false
    toLoadHub.what_to_speak = nil
    toLoadHub.boarding_sound_played = false
    toLoadHub.deboarding_sound_played = false
    toLoadHub.boarding_cargo_sound_played = false
    toLoadHub.deboarding_cargo_sound_played = false
    toLoadHub.full_deboard_sound = false
    toLoadHub.is_onground = true
    toLoadHub.error_message = nil
    toLoadHub.fuel_engines_on = nil
    toLoadHub.fuel_engines_off = nil
    for key in pairs(toLoadHub.hoppie) do
        if key == "loadsheet_check" then
            toLoadHub.hoppie[key] = os.time()
        else
            toLoadHub.hoppie[key] = false
        end
    end
    toLoadHub.setWeightCommand = false
    toLoadHub.flt_no = ""
    toLoadHub.fuel_to_load = round_up_to_unit(writeInUnitKg(toLoadHub_m_fuel_total))
    toLoadHub.fuel_to_load_next = os.time()
    toLoadHub.tank_num = 0
    for key in pairs(toLoadHub.phases) do
        if not initJetway and key == "is_jetway" then
            -- not reset
        else
            toLoadHub.phases[key] = false
        end
    end
    for key in pairs(toLoadHub.fuel_tank) do
        toLoadHub.fuel_tank[key] = 0
    end
    toLoadHub.fuel_tank_check = os.time()
    for key in pairs(toLoadHub.focus_windows) do
        toLoadHub.focus_windows[key] = false
    end
    for key in pairs(toLoadHub.simbrief) do
        toLoadHub.simbrief[key] = nil
    end
    if not toLoadHub.first_init and toLoadHub.settings.simbrief.auto_fetch then
        fetchSimbriefFPlan()
    end
    toLoadHub.is_lbs = toLoadHub.settings.general.is_lbs
    toLoadHub.unitLabel = "KGS"
    toLoadHub.unitTLabel = "T"
    toLoadHub.first_init = true
    toLoadHub_NoPax_XP = 0
    toLoadHub_AftCargo_XP = 0
    toLoadHub_FwdCargo_XP = 0
    toLoadHub_PaxDistrib_XP = 0.5
    setIsLib()
    command_once("AirbusFBW/SetWeightAndCG")
    if toLoadHub.settings.general.simulate_fuel and toLoadHub.settings.general.simulate_init_fuel then
        toLoadHub_fuel_1 = 0
        toLoadHub_fuel_2 = 0
        toLoadHub_fuel_3 = 0
    end
    debug(string.format("[%s] Reset parameters done", toLoadHub.title))
end

local function seatBeltStatusOn()
    local seatBeltMappings = {
        A319 = function() return toLoadHub_sim_fasten_seat_belts3 > 0 end,
        A20N = function() return toLoadHub_sim_fasten_seat_belts3 > 0 end,
        A321 = function() return toLoadHub_sim_fasten_seat_belts3 > 0 end,
        A339 = function() return toLoadHub_sim_fasten_seat_belts3 > 0 end,
        A346 = function() return toLoadHub_sim_fasten_seat_belts3 > 0 end,
        A306 = function() return toLoadHub_sim_fasten_seat_belts2 > 0 end,
        A310 = function() return toLoadHub_sim_fasten_seat_belts2 > 0 end,
        A359 = function() return toLoadHub_sim_fasten_seat_belts5 > 0 end
    }
    if PLANE_ICAO == "A333" then
        if toLoadHub_sim_fasten_seat_belts4 == 2 or
           (toLoadHub_sim_fasten_seat_belts4 == 1 and ELEVATION < 3048) then
            return true
        end
        return false
    end
    if seatBeltMappings[PLANE_ICAO] then
        return seatBeltMappings[PLANE_ICAO]()
    end
    return toLoadHub_sim_fasten_seat_belts > 0
end

local function registerSetWeight()
    if not toLoadHub.setWeightCommand or toLoadHub.setWeightTime > os.time() then return end
    command_once("AirbusFBW/SetWeightAndCG")
    toLoadHub.setWeightCommand = false
end

local function setRandomNumberOfPassengers()
    local passengerDistributionGroup = math.random(0, 100)
    local ranges = {
        {2, 0.22, 0.54},
        {16, 0.54, 0.72},
        {58, 0.72, 0.87},
        {100, 0.87, 1.0} -- 1.0 = 100%
    }
    for _, range in ipairs(ranges) do
        if passengerDistributionGroup < range[1] then
            toLoadHub.pax_count = math.random(
                math.floor(toLoadHub.max_passenger * range[2]),
                math.floor(toLoadHub.max_passenger * range[3])
            )
            return
        end
    end
end

local function playChimeSound()
    if toLoadHub.what_to_speak then return end
    if toLoadHub.phases.is_pax_onboarded and not toLoadHub.phases.is_pax_deboarded then
        if toLoadHub.pax_count > 0 then
            command_once( "AirbusFBW/CheckCabin" )
            toLoadHub.what_to_speak = "Boarding Passenger Completed"
            toLoadHub.wait_until_speak = os.time() + 2
        end
        toLoadHub.boarding_sound_played = true
    end
    if toLoadHub.phases.is_pax_deboarded then
        if toLoadHub.pax_count > 0 then
            command_once( "AirbusFBW/CheckCabin" )
            toLoadHub.what_to_speak = "Deboarding Passenger Completed"
            toLoadHub.wait_until_speak = os.time() + 2
        end
        toLoadHub.deboarding_sound_played = true
    end
end

local function playCargoSound()
    if toLoadHub.what_to_speak then return end
    if toLoadHub.phases.is_cargo_onboarded and not toLoadHub.phases.is_cargo_deboarded then
        if toLoadHub.cargo > 0 then
            toLoadHub.what_to_speak = "Cargo Loading Completed"
            toLoadHub.wait_until_speak = os.time() + 2
        end
        toLoadHub.boarding_cargo_sound_played = true
    end
    if toLoadHub.phases.is_cargo_deboarded then
        if toLoadHub.cargo > 0 then
			-- TODO?
            toLoadHub.what_to_speak = "Cargo offloading Completed"
            toLoadHub.wait_until_speak = os.time() + 2
        end
        toLoadHub.deboarding_cargo_sound_played = true
    end
end

local function playFinalSound()
    if toLoadHub.what_to_speak then return end
    if toLoadHub.cargo > 0 and toLoadHub.pax_count > 0 then
        toLoadHub.what_to_speak = "Flight completed, all passengers and cargo have been deboarded."
        toLoadHub.wait_until_speak = os.time() + 2
    end
    toLoadHub.full_deboard_sound = true
end

local function isAnyDoorOpen()
    return (toLoadHub_Doors_1 and toLoadHub_Doors_1 > 0) or
           (toLoadHub_Doors_2 and toLoadHub_Doors_2 > 1) or
           (toLoadHub_Doors_6 and toLoadHub_Doors_6 > 1 and
            (PLANE_ICAO == "A321" or PLANE_ICAO == "A21N" or PLANE_ICAO == "A346" or PLANE_ICAO == "A339"))
end

local function isAnyCargoDoorOpen()
  return (toLoadHub_CargoDoors_1 and toLoadHub_CargoDoors_1 > 0)
      or (toLoadHub_CargoDoors_2 and toLoadHub_CargoDoors_2 > 0)
      or (toLoadHub_CargoDoors_3 and toLoadHub_CargoDoors_3 > 0)
end


local function allDoorsOpen()
    return (toLoadHub_Doors_1 and toLoadHub_Doors_1 > 0) and ((toLoadHub_Doors_2 and toLoadHub_Doors_2 > 1) or
           (toLoadHub_Doors_6 and toLoadHub_Doors_6 > 1 and
             (PLANE_ICAO == "A321" or PLANE_ICAO == "A21N" or PLANE_ICAO == "A346" or PLANE_ICAO == "A339")))
end

local function areAllDoorsClosed()
    if PLANE_ICAO == "A321" or PLANE_ICAO == "A21N" or PLANE_ICAO == "A346" or PLANE_ICAO == "A339" then
        return toLoadHub_Doors_6 == 0 and toLoadHub_Doors_1 == 0 and toLoadHub_Doors_2 == 0
    else
        return toLoadHub_Doors_1 == 0 and toLoadHub_Doors_2 == 0
    end
end

local function monitorJetWay(force)
    if not toLoadHub.settings.general.automate_jetway then return end
    if force and not toLoadHub.phases.is_jetway then
        toLoadHub.phases.is_jetway = true
        command_once("sim/ground_ops/jetway")
        return
    end
    if not toLoadHub.phases.is_jetway and toLoadHub_Doors_1 == 2 then
        command_once("sim/ground_ops/jetway")
        toLoadHub.phases.is_jetway = true
    elseif toLoadHub.phases.is_jetway and toLoadHub_Doors_1 == 0 and not toLoadHub.phases.is_landed then
        command_once("sim/ground_ops/jetway")
        toLoadHub.phases.is_jetway = false
    end
end

local function openDoors(boarding)
    local setVal = boarding and toLoadHub.settings.door.open_boarding or toLoadHub.settings.door.open_deboarding
    toLoadHub_Doors_1 = 2
    if toLoadHub.settings.general.is_jetbridge and PLANE_ICAO == "A319" or PLANE_ICAO == "A20N" then return end
    if setVal > 1 then
        toLoadHub_Doors_2 = 2
        if PLANE_ICAO == "A321" or PLANE_ICAO == "A21N" or PLANE_ICAO == "A346" or PLANE_ICAO == "A339" then
            toLoadHub_Doors_6 = 2
        end
    end
end

local function closeDoors(boarding)
    if not toLoadHub.settings.door.close_boarding and boarding then return end
    if not toLoadHub.settings.door.close_deboarding and not boarding then return end

    toLoadHub_Doors_1 = 0
    toLoadHub_Doors_2 = 0
    if PLANE_ICAO == "A321" or PLANE_ICAO == "A21N" or PLANE_ICAO == "A346" or PLANE_ICAO == "A339" then
        toLoadHub_Doors_6 = 0
    end
end

-- Comprehensive AC power check

local function is_ac_powered()
	return (GPU_ON == 1 or APU_GEN == 1)
end

local function closeDoorsCargo()
	if not is_ac_powered() then return end
    toLoadHub_CargoDoors_1 = 0
    toLoadHub_CargoDoors_2 = 0
    toLoadHub_CargoDoors_3 = 0
end

local function openDoorsCargo()
	if not is_ac_powered() then return end
    toLoadHub_CargoDoors_1 = 2
    toLoadHub_CargoDoors_2 = 2
    toLoadHub_CargoDoors_3 = 2
end

local function openDoorsCatering()
    toLoadHub_CateringDoors_1 = 2
    toLoadHub_CateringDoors_2 = 2
end

local function closeDoorsCatering()
    toLoadHub_CateringDoors_1 = 0
    toLoadHub_CateringDoors_2 = 0
end

local function startProcedure(is_boarding, door_setting, message)
    openDoors(is_boarding)
    toLoadHub.wait_until_speak = os.time()
    toLoadHub.next_boarding_check = os.time()
    toLoadHub.next_cargo_check = os.time()
    toLoadHub.phases[is_boarding and "is_onboarding" or "is_deboarding"] = true
    toLoadHub.what_to_speak = message
end

local function focusOnToLoadHub()
    if not toLoadHub.visible_main and not toLoadHub.visible_settings then
        openToLoadHubWindow(true)
    elseif not toLoadHub.visible_main and toLoadHub.visible_settings then
        toLoadHub.visible_settings = false
        toLoadHub.visible_main = true
        openToLoadHubWindow(false)
    end
end

local function isPaxCanStart()
    return not toLoadHub.settings.general.pax_delayed or toLoadHub.phases.is_pax_onboard_enabled
end

local function isNoPaxInRangeForCargo()
    if toLoadHub.settings.general.concourrent_cargo or toLoadHub.settings.general.pax_delayed then
        return true
    else
        return toLoadHub_NoPax >= toLoadHub.pax_count * (math.random(toLoadHub.cargo_starting_range[1], toLoadHub.cargo_starting_range[2]) / 100)
    end
end

local function addingCargoFwdAft()
    local someChanges = false
    if toLoadHub_AftCargo < toLoadHub.cargo_aft then
        toLoadHub_AftCargo = math.min(toLoadHub_AftCargo + (toLoadHub.kgPerUnit * (math.random(40, 60) / 100)), toLoadHub.cargo_aft)
        someChanges = true
    end
    if toLoadHub_FwdCargo < toLoadHub.cargo_fwd then
        toLoadHub_FwdCargo = math.min(toLoadHub_FwdCargo + (toLoadHub.kgPerUnit * (math.random(40, 60) / 100)), toLoadHub.cargo_fwd)
        someChanges = true
    end
    return someChanges
end

local function removingCargoFwdAft()
    local someChanges = false
    if toLoadHub_AftCargo > 0 then
        toLoadHub_AftCargo = math.max(toLoadHub_AftCargo - toLoadHub.kgPerUnit, 0)
        someChanges = true
    end
    if toLoadHub_FwdCargo > 0 then
        toLoadHub_FwdCargo = math.max(toLoadHub_FwdCargo - toLoadHub.kgPerUnit, 0)
        someChanges = true
    end
    return someChanges
end

local function formatRowLoadSheet(label, value, digit)
    return label .. string.rep(".", digit - #label - #tostring(value)) .. tostring(" @" .. value .. "@ ")
end

local function toZulu(hhmm)
    local h, m = hhmm:match("^(%d%d):(%d%d)$")
    if not h then return hhmm end
    -- build a time table in local time
    local t = os.time{
        year  = os.date("*t").year,
        month = os.date("*t").month,
        day   = os.date("*t").day,
        hour  = tonumber(h),
        min   = tonumber(m),
        sec   = 0
    }
    return os.date("!%H%MZ", t)
end

local function sendLoadsheetViaSayIntentions(data, loadSheetContent, requireResponse)
    if not sapiClient then
        toLoadHub.error_message = "SayIntentions client not initialized."
        debug(string.format("[%s] SayIntentions client not initialized.", toLoadHub.title))
        return false
    end

    debug(string.format("[%s] Sending loadsheet via SayIntentions", toLoadHub.title))
    debug(string.format("[%s] Flight: %s, Content length: %d", toLoadHub.title, data.flt_no, #loadSheetContent))

    -- Determine station (origin + station name)
    local station = toLoadHub.settings.sayintentions.station or "OPS"
    if toLoadHub.simbrief.origin then
        station = toLoadHub.simbrief.origin .. " " .. station
    end

	local respCode = (requireResponse == 1) and "WU" or "NE"

    -- Send via SayIntentions API (as telex message)
    local response, err = sapiClient:sendACARSMessage(
        loadSheetContent,
		toLoadHub.simbrief.origin,
        respCode, -- No response expected
        "telex", -- Message type
		1 -- Rephrase
		
    )

    -- IMMEDIATELY set flags to prevent retry loop - do this BEFORE any error handling
    logMsg("[ToLoadHUB] Setting sent flags to prevent retry (typeL=" .. data.typeL .. ")")
    if data.typeL == 0 then toLoadHub.hoppie.loadsheet_preliminary_sent = true end
    if data.typeL == 1 then toLoadHub.hoppie.loadsheet_sent = true end
    if data.typeL == 2 then toLoadHub.hoppie.loadsheet_chocks_off_sent = true end
    if data.typeL == 3 then toLoadHub.hoppie.loadsheet_chocks_on_sent = true end

    if err then
        local errorMsg = "SayIntentions API Error: " .. tostring(err)
        toLoadHub.error_message = errorMsg
        debug(string.format("[%s] SayIntentions ERROR: %s", toLoadHub.title, tostring(err)))
        debug(string.format("[%s] Station: %s", toLoadHub.title, station))
        debug(string.format("[%s] Message (first 300 chars): %s", toLoadHub.title, loadSheetContent:sub(1, 300)))
        debug(string.format("[%s] API Key length: %d", toLoadHub.title, #toLoadHub.settings.sayintentions.api_key))

        -- Force log message to show even if debug is off
        logMsg("[ToLoadHUB] SAYINTENTIONS ERROR: " .. tostring(err))
        logMsg("[ToLoadHUB] Check your API key and network connection")

        return false
    end

    debug(string.format("[%s] SayIntentions raw response type: %s", toLoadHub.title, type(response)))

    -- Log the actual response for debugging
    logMsg("[ToLoadHUB] === SayIntentions Response Debug ===")
    logMsg("[ToLoadHUB] Response type: " .. type(response))

    if type(response) == "table" then
        logMsg("[ToLoadHUB] Response is a table with fields:")
        for k, v in pairs(response) do
            logMsg(string.format("[ToLoadHUB]   %s = %s (type: %s)", k, tostring(v), type(v)))
        end
    elseif type(response) == "string" then
        logMsg("[ToLoadHUB] Response is string: " .. response:sub(1, 200))
    else
        logMsg("[ToLoadHUB] Response is: " .. tostring(response))
    end
    logMsg("[ToLoadHUB] === End Response Debug ===")

    -- Flags already set above to prevent retries

    -- Check for success (case-insensitive)
    local statusStr = nil
    if response and type(response) == "table" then
        statusStr = response.status or response.Status or response.STATUS
    end

    if statusStr and string.upper(tostring(statusStr)) == "OK" then
        debug(string.format("[%s] SayIntentions loadsheet sent successfully", toLoadHub.title))
        logMsg("[ToLoadHUB] Loadsheet sent via SayIntentions successfully!")
        return true
    else
        local errorDetail = "Unknown error"
        if response then
            if type(response) == "table" then
                errorDetail = response.error or response.message or "No error details in response"
            else
                errorDetail = "Invalid response format: " .. tostring(response)
            end
        else
            errorDetail = "No response from API"
        end

        toLoadHub.error_message = "SayIntentions Error: " .. errorDetail
        debug(string.format("[%s] SayIntentions error - marking as sent to prevent retry spam", toLoadHub.title))
        logMsg("[ToLoadHUB] SayIntentions error: " .. errorDetail)
        return false
    end
end

local function sendLoadsheetToToliss(data)
    if not getmetatable(data) == loadsheetStructure then return end
    if toLoadHub.hoppie.loadsheet_check > os.time() or toLoadHub.hoppie.loadsheet_sending then return end

    toLoadHub.hoppie.loadsheet_sending = true
    debug(string.format("[%s] Starting Loadsheet %s composition.", toLoadHub.title, data.labelText))

    local useSayIntentions = toLoadHub.settings.sayintentions.use_sayintentions

    -- Validate credentials
    if useSayIntentions then
        if not toLoadHub.settings.sayintentions.api_key or toLoadHub.settings.sayintentions.api_key:gsub("^%s*(.-)%s*$", "%1") == "" then
            toLoadHub.error_message = "SayIntentions API key not set."
            debug(string.format("[%s] SayIntentions API key not set.", toLoadHub.title))
            toLoadHub.hoppie.loadsheet_sending = false
            return false
        end
        if not sapiClient then
            toLoadHub.error_message = "SayIntentions client not available."
            debug(string.format("[%s] SayIntentions client not available.", toLoadHub.title))
            toLoadHub.hoppie.loadsheet_sending = false
            return false
        end
    else
        if not toLoadHub.settings.hoppie.secret or toLoadHub.settings.hoppie.secret:gsub("^%s*(.-)%s*$", "%1") == "" then
            toLoadHub.error_message = "Hoppie secret not set."
            debug(string.format("[%s] Hoppie secret not set.", toLoadHub.title))
            toLoadHub.hoppie.loadsheet_sending = false
            return false
        end
    end

    --------------------------------------------------------------------
    -- BUILD FULL LOADSHEET (HOPPIE FORMAT)
    --------------------------------------------------------------------
    local loadSheetContent = ""

    if data.typeL < 2 then
        loadSheetContent = "/data2/1" .. tostring(toLoadHub.version:gsub("[%.a]", "")) .. "//NE/" .. table.concat({
            "Loadsheet " .. data.labelText .. " " .. os.date((toLoadHub.settings.hoppie.utc_time and "!" or "") .. "%H:%M"),
            formatRowLoadSheet("ZFW",  data.zfw, 9),
            formatRowLoadSheet("GWCG", data.gwcg, 9),
            formatRowLoadSheet("F.BLK", data.f_blk, 9),
        }, "\n")

        if toLoadHub.settings.hoppie.display_pax and data.pax ~= "" then
            loadSheetContent = loadSheetContent .. "\n" .. formatRowLoadSheet("PAX", data.pax, 9)
        end

        if data.warning ~= "" then
            loadSheetContent = loadSheetContent .. "\n" .. formatRowLoadSheet("@WARN!@ F.BLK EXP.", data.warning, 22)
        end

    elseif data.typeL == 2 then
        loadSheetContent = "/data2/2" .. tostring(toLoadHub.version:gsub("[%.a]", "")) .. "//NE/" .. table.concat({
            "ACTUAL TIMES @-@ " .. os.date((toLoadHub.settings.hoppie.utc_time and "!" or "") .. "%H:%M"),
            formatRowLoadSheet("Chock out", toLoadHub.chocks_out_time, 22),
            formatRowLoadSheet("Take off", toLoadHub.chocks_off_time, 22),
        }, "\n")

    elseif data.typeL == 3 then
        local consumption = (writeInUnitKg(toLoadHub.fuel_engines_on)
            - (toLoadHub.simbrief.total_burn + toLoadHub.simbrief.taxi))
            - writeInUnitKg(toLoadHub.fuel_engines_off)

        local lblSaving = "As Planned"
        if consumption < 0 then
            lblSaving = "Save @" .. string.format("%d",consumption) .. "@ " .. toLoadHub.unitLabel
        elseif consumption > 0 then
            lblSaving = "Exceed @+" .. string.format("%d",consumption) .. "@ " .. toLoadHub.unitLabel
        end

        loadSheetContent = "/data2/3" .. tostring(toLoadHub.version:gsub("[%.a]", "")) .. "//NE/" .. table.concat({
            "ARRIVAL TIMES @-@ " .. os.date((toLoadHub.settings.hoppie.utc_time and "!" or "") .. "%H:%M"),
            formatRowLoadSheet("Landing", toLoadHub.chocks_on_time, 22),
            formatRowLoadSheet("Chock in", toLoadHub.chocks_in_time, 22),
            "Fuel Info: " .. lblSaving,
        }, "\n")
    end

    debug(string.format("[%s] Loadsheet content composed, flt_no: %s", toLoadHub.title, tostring(data.flt_no)))

    --------------------------------------------------------------------
    -- SAYINTENTIONS COMPRESSED LOADSHEET (128-char safe)
    --------------------------------------------------------------------
	local requireResponse = 0
    if useSayIntentions then
		
			local t = toLoadHub.settings.hoppie.utc_time
			and os.date("!%H%MZ")   -- UTC Zulu format
			or  os.date("%H:%M")    -- Local time


		-- round to 1 decimal
		local function r1(x)
			return string.format("%.1f", tonumber(x) or 0)
		end

		if data.typeL < 2 then
			requireResponse = 1 -- Most likely a loadsheet, may require pilot response/approval
			
			--loadSheetContent = "DEBUG TEXT IN COLOR @BLUE@"
			
			-- PRELIM / FINAL
			loadSheetContent = string.format(
				"LOADSHEET %s %s ZFW @%s@ GWCG @%s@ FUEL @%s@ PAX @%s@ DEST @LGAV@",
				data.labelText,      -- PRELIM or FINAL
				t,
				r1(data.zfw),
				data.gwcg,
				tostring(data.f_blk),
				tostring(data.pax)
			)
			print("[SI-LOADSHEET] >>> " .. loadSheetContent .. "; REQUIRE RESPONSE: ".. tostring(requireResponse))

		elseif data.typeL == 2 then
		-- CHOCKS OUT (OOOI OUT)
			loadSheetContent = string.format(
			"OOOI OUT @%s@ OUT @%s@ OFF @%s@",
			t,
			toZulu(toLoadHub.chocks_out_time),
			toZulu(toLoadHub.chocks_off_time)
			)

		elseif data.typeL == 3 then
			-- CHOCKS IN (OOOI IN)
			local consumption = (writeInUnitKg(toLoadHub.fuel_engines_on)
			- (toLoadHub.simbrief.total_burn + toLoadHub.simbrief.taxi))
			- writeInUnitKg(toLoadHub.fuel_engines_off)

			loadSheetContent = string.format(
			"OOOI IN @%s@ ON @%s@ IN @%s@ FUEL @%s@",
			t,
			toZulu(toLoadHub.chocks_on_time),
			toZulu(toLoadHub.chocks_in_time),
			tostring(consumption)
			)
	end

    -- final safety trim
    --loadSheetContent = loadSheetContent:sub(1, 120)
	--loadSheetContent = loadSheetContent:sub(1, 120):gsub("@$", "")

end

    --------------------------------------------------------------------
    -- ROUTE TO PROVIDER
    --------------------------------------------------------------------
    if useSayIntentions then
        local success = sendLoadsheetViaSayIntentions(data, loadSheetContent, requireResponse)
        toLoadHub.hoppie.loadsheet_sending = false
        toLoadHub.hoppie.loadsheet_check = os.time() + 5
		requireResponse = 0
        return success
    else
        -- Hoppie original code
        local payload = string.format("logon=%s&from=%s&to=%s&type=%s&packet=%s",
            toLoadHub.settings.hoppie.secret,
            toLoadHub.title,
            data.flt_no,
            'cpdlc',
            loadSheetContent:gsub("\n", "%%0A")
        )

        local resp, code = http.request{
            url = urls.hoppie_connect,
            method = "POST",
            headers = {
                ["Content-Type"] = "application/x-www-form-urlencoded",
                ["Content-Length"] = tostring(#payload),
            },
            source = ltn12.source.string(payload),
        }

        debug(string.format("[%s] Hoppie returning code %s.", toLoadHub.title, tostring(code)))
        debug(string.format("[%s] Hoppie response: %s.", toLoadHub.title, tostring(resp)))

        if code == 200 and data.typeL == 0 then toLoadHub.hoppie.loadsheet_preliminary_sent = true end
        if code == 200 and data.typeL == 1 then toLoadHub.hoppie.loadsheet_sent = true end
        if code == 200 and data.typeL == 2 then toLoadHub.hoppie.loadsheet_chocks_off_sent = true end
        if code == 200 and data.typeL == 3 then toLoadHub.hoppie.loadsheet_chocks_on_sent = true end

        if code ~= 200 then toLoadHub.error_message = "Hoppie returned an error. Please check your secret value." end
        toLoadHub.hoppie.loadsheet_sending = false
    end
end

local function sendLoadsheetToToliss_default(data)
    if not getmetatable(data) == loadsheetStructure then return end
    if toLoadHub.hoppie.loadsheet_check > os.time() or toLoadHub.hoppie.loadsheet_sending then return end

    -- IMMEDIATELY mark as sending to prevent multiple calls in the same frame
    toLoadHub.hoppie.loadsheet_sending = true

    debug(string.format("[%s] Starting Loadsheet %s composition.", toLoadHub.title, data.labelText))

    -- Check which provider to use
    local useSayIntentions = toLoadHub.settings.sayintentions.use_sayintentions

    -- Validate credentials based on provider
    if useSayIntentions then
        if not toLoadHub.settings.sayintentions.api_key or toLoadHub.settings.sayintentions.api_key:gsub("^%s*(.-)%s*$", "%1") == "" then
            toLoadHub.error_message = "SayIntentions API key not set."
            debug(string.format("[%s] SayIntentions API key not set.", toLoadHub.title))
            toLoadHub.hoppie.loadsheet_sending = false
            return false
        end
        if not sapiClient then
            toLoadHub.error_message = "SayIntentions client not available."
            debug(string.format("[%s] SayIntentions client not available.", toLoadHub.title))
            toLoadHub.hoppie.loadsheet_sending = false
            return false
        end
    else
        if not toLoadHub.settings.hoppie.secret or toLoadHub.settings.hoppie.secret == nil or toLoadHub.settings.hoppie.secret:gsub("^%s*(.-)%s*$", "%1") == "" then
            toLoadHub.error_message = "Hoppie secret not set."
            debug(string.format("[%s] Hoppie secret not set.", toLoadHub.title))
            toLoadHub.hoppie.loadsheet_sending = false
            return false
        end
    end

    local loadSheetContent = ""
    if data.typeL < 2 then
        loadSheetContent = "/data2/1" .. tostring(toLoadHub.version:gsub("[%.a]", "")) .. "//NE/" .. table.concat({
            "Loadsheet " .. data.labelText .. " " .. os.date((toLoadHub.settings.hoppie.utc_time and "!" or "") .. "%H:%M"),
            formatRowLoadSheet("ZFW",  data.zfw, 9),
            --formatRowLoadSheet("ZFWCG", data.zfwcg, 9), -- TODO: ZFWCG acars line disabled
            formatRowLoadSheet("GWCG", data.gwcg, 9),
            formatRowLoadSheet("F.BLK", data.f_blk, 9),
        }, "\n")
        if toLoadHub.settings.hoppie.display_pax and data.pax ~= "" then
            loadSheetContent = loadSheetContent .. "\n" .. formatRowLoadSheet("PAX", data.pax, 9)
        end
        if data.warning ~= "" then
            loadSheetContent = loadSheetContent .. "\n" .. formatRowLoadSheet("@WARN!@ F.BLK EXP.", data.warning, 22)
        end
    elseif data.typeL == 2 then
        loadSheetContent = "/data2/2" .. tostring(toLoadHub.version:gsub("[%.a]", "")) .. "//NE/" .. table.concat({
            "ACTUAL TIMES @-@ " .. os.date((toLoadHub.settings.hoppie.utc_time and "!" or "") .. "%H:%M"),
            formatRowLoadSheet("Chock out", toLoadHub.chocks_out_time, 22),
            formatRowLoadSheet("Take off", toLoadHub.chocks_off_time, 22),
        }, "\n")
    elseif data.typeL == 3 then
        local consumption = (writeInUnitKg(toLoadHub.fuel_engines_on) - (toLoadHub.simbrief.total_burn + toLoadHub.simbrief.taxi)) - writeInUnitKg(toLoadHub.fuel_engines_off)
        local lblSaving = "As Planned"
        if consumption < 0 then
            lblSaving = "Save @" .. string.format("%d",consumption) .. "@ " .. toLoadHub.unitLabel
        elseif consumption > 0 then
            lblSaving = "Exceed @+" ..  string.format("%d",consumption) .. "@ " .. toLoadHub.unitLabel
        end
        loadSheetContent = "/data2/3" .. tostring(toLoadHub.version:gsub("[%.a]", "")) .. "//NE/" .. table.concat({
            "ARRIVAL TIMES @-@ " .. os.date((toLoadHub.settings.hoppie.utc_time and "!" or "") .. "%H:%M"),
            formatRowLoadSheet("Landing", toLoadHub.chocks_on_time, 22),
            formatRowLoadSheet("Chock in", toLoadHub.chocks_in_time, 22),
            "Fuel Info: " .. lblSaving,
        }, "\n")
    end

    debug(string.format("[%s] Loadsheet content composed, flt_no: %s", toLoadHub.title, tostring(data.flt_no)))

    -- Route to appropriate provider
    if useSayIntentions then
        -- Send via SayIntentions
        local success = sendLoadsheetViaSayIntentions(data, loadSheetContent)
        toLoadHub.hoppie.loadsheet_sending = false
        -- Set timer to prevent repeated sends
        toLoadHub.hoppie.loadsheet_check = os.time() + 5
        return success
    else
        -- Send via Hoppie (original code)
        local payload = string.format("logon=%s&from=%s&to=%s&type=%s&packet=%s",
            toLoadHub.settings.hoppie.secret,
            toLoadHub.title,
            data.flt_no,
            'cpdlc', 
            loadSheetContent:gsub("\n", "%%0A")
        )

        local resp, code = http.request{
            url = urls.hoppie_connect,
            method = "POST",
            headers = {
                ["Content-Type"] = "application/x-www-form-urlencoded",
                ["Content-Length"] = tostring(#payload),
            },
            source = ltn12.source.string(payload),
        }
        debug(string.format("[%s] Hoppie returning code %s.", toLoadHub.title, tostring(code)))
        debug(string.format("[%s] Hoppie url: %s.", toLoadHub.title, tostring(urls.hoppie_connect)))
        debug(string.format("[%s] Hoppie response: %s.", toLoadHub.title, tostring(resp)))
        debug(string.format("[%s] Hoppie payload: %s.", toLoadHub.title, tostring(payload)))
        debug(string.format("[%s] Hoppie fulldata: %s.", toLoadHub.title, tostring(data)))

        if code == 200 and data.typeL == 0 then toLoadHub.hoppie.loadsheet_preliminary_sent = true end
        if code == 200 and data.typeL == 1 then toLoadHub.hoppie.loadsheet_sent = true end
        if code == 200 and data.typeL == 2 then toLoadHub.hoppie.loadsheet_chocks_off_sent = true end
        if code == 200 and data.typeL == 3 then toLoadHub.hoppie.loadsheet_chocks_on_sent = true end

        if code ~= 200 then toLoadHub.error_message = "Hoppie returned an error. Please check your secret value." end
        toLoadHub.hoppie.loadsheet_sending = false
    end
end

-- == X-Plane Functions ==
function openToLoadHubWindow(isNew)
    if isNew then
        toloadhub_window = float_wnd_create(toLoadHub.settings.general.window_width, toLoadHub.settings.general.window_height, 1, true)
        float_wnd_set_position(toloadhub_window, toLoadHub.settings.general.window_x, toLoadHub.settings.general.window_y)
    end
    if toLoadHub.simbrief.origin and toLoadHub.simbrief.destination then
        float_wnd_set_title(toloadhub_window, string.format("%s - v%s | %s - %s", toLoadHub.title, toLoadHub.version,
         toLoadHub.simbrief.origin, toLoadHub.simbrief.destination))
    else
        float_wnd_set_title(toloadhub_window, string.format("%s - v%s", toLoadHub.title, toLoadHub.version))
    end
    float_wnd_set_imgui_builder(toloadhub_window, "viewToLoadHubWindow")
    float_wnd_set_onclose(toloadhub_window, "closeToLoadHubWindow")
    toLoadHub.visible_main = true
end

function openToLoadHubSettingsWindow()
    float_wnd_set_title(toloadhub_window, string.format("%s - Settings", toLoadHub.title))
    float_wnd_set_imgui_builder(toloadhub_window, "viewToLoadHubWindowSettings")
    float_wnd_set_onclose(toloadhub_window, "closeToLoadHubWindow")
    toLoadHub.visible_main = true
end

function closeToLoadHubWindow()
    saveSettingsToFileToLoadHub(true)
    toLoadHub.visible_main = false
    toLoadHub.visible_settings = false
end

function viewToLoadHubWindow()

    if not float_wnd_is_vr(toloadhub_window) then
        local wLeft, wTop, wRight, wBottom = float_wnd_get_geometry(toloadhub_window)
        toLoadHub.settings.general.window_height = wTop - wBottom
        toLoadHub.settings.general.window_width = wRight - wLeft
    else
        local vrwinWidth, vrwinHeight = float_wnd_get_geometry(toloadhub_window)
        toLoadHub.settings.general.window_height = vrwinHeight
        toLoadHub.settings.general.window_width = vrwinWidth
    end 

    if toLoadHub.error_message ~= nil then
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF6666FF)
        imgui.TextUnformatted(toLoadHub.error_message)
        imgui.PopStyleColor()
        if imgui.Button("Ok!") then
            toLoadHub.error_message = nil
        end
        imgui.Separator()
        imgui.Spacing()
    end

    -- In Air
    if toLoadHub_onground_any < 1 then
        if toLoadHub.phases.is_onboarded and not toLoadHub.phases.is_deboarding then
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF6AE079)
            imgui.TextUnformatted("Have a nice flight!")
            imgui.PopStyleColor()
        else 
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF95FFF8)
            imgui.TextUnformatted("You cannot board while in flight.")
            imgui.PopStyleColor()
        end
    end

    -- First Init in case
    if toLoadHub_onground_any > 0 and not toLoadHub.first_init then -- Not auto init, and plane not set to zero: RETURN
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF7F7F7F)
        imgui.TextUnformatted("ToLoadHUB not auto initiated, please initiate.")
        imgui.PopStyleColor()
        if imgui.Button("Init", 100, 30) then
            resetAirplaneParameters(true)
        end
        return
    end

    -- Fuel Section
    if toLoadHub_onground_any > 0 and toLoadHub.settings.general.simulate_fuel and toLoadHub_beacon_lights_on == 0 then
        local temp_window_size = imgui.GetWindowSize()
        if temp_window_size ~= nil and toLoadHub.visible_fuel then
            if (toLoadHub.settings.general.use_toliss_refuel_defuel == false) then
                imgui.TextUnformatted(string.format("Fuel in Tank: %.0f " .. toLoadHub.unitLabel, writeInUnitKg(toLoadHub_m_fuel_total)))
            else
                imgui.TextUnformatted("Use ISCS to plan your fuel")
                imgui.TextUnformatted(string.format("Fuel in Tank: %.0f " .. toLoadHub.unitLabel, writeInUnitKg(toLoadHub_m_fuel_total)))
                imgui.TextUnformatted("Required fuel: ")
                imgui.SameLine(120)
                local fuelNumberChanged, newFuelNumber = imgui.InputInt("##fuel", math.floor(toLoadHub.fuel_to_load), 100)
                if fuelNumberChanged then
                    toLoadHub.fuel_to_load = math.max(100, math.min(tonumber(newFuelNumber), toLoadHub.max_fuel))
                end
            end

            
            imgui.PushStyleColor(imgui.constant.Col.FrameBg, 0xFF272727) -- bacground
            imgui.PushStyleColor(imgui.constant.Col.PlotHistogram, 0xFF007F00) -- bar color
            imgui.ProgressBar((writeInUnitKg(toLoadHub_m_fuel_total) / toLoadHub.max_fuel), temp_window_size -16    , 20)
            imgui.PopStyleColor()
            imgui.PopStyleColor()

            if (toLoadHub.settings.general.use_toliss_refuel_defuel == false) then
                local labelFuel = toLoadHub.fuel_to_load > writeInUnitKg(toLoadHub_m_fuel_total) and "Refueling" or "Defueling"
                if not toLoadHub.phases.is_refueling and not toLoadHub.phases.is_defueling then
                    imgui.TextUnformatted("Requested fuel: ")
                    imgui.SameLine(120)
                    local fuelNumberChanged, newFuelNumber = imgui.InputInt("##fuel", math.floor(toLoadHub.fuel_to_load), 100)
                    if fuelNumberChanged then
                        --toLoadHub.fuel_to_load = 0 --math.max(100, math.min(tonumber(newFuelNumber), toLoadHub.max_fuel))
                    end

                    if (toLoadHub.fuel_to_load - writeInUnitKg(toLoadHub_m_fuel_total) >= toLoadHub.fueling_speed_per_second.refuel) or (writeInUnitKg(toLoadHub_m_fuel_total) - toLoadHub.fuel_to_load >= toLoadHub.fueling_speed_per_second.defuel) then
                        if toloadHub.settings.general.use_toliss_refuel_defuel == false 
                        then
                        if imgui.Button("Start " .. labelFuel) then
                            if toLoadHub.fuel_to_load > writeInUnitKg(toLoadHub_m_fuel_total) then
                                toLoadHub.phases.is_defueling = false
                                toLoadHub.phases.is_refueling = true
                            else
                                toLoadHub.phases.is_defueling = true
                                toLoadHub.phases.is_refueling = false
                            end
                        end
                        imgui.SameLine(150)
                    end
                end
                if imgui.Button("Close") then
                    toLoadHub.visible_fuel = false
                end
                else
                    imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFEBCE87)
                    imgui.TextUnformatted(labelFuel .. " to " .. string.format("%d ", toLoadHub.fuel_to_load) .. animate_dots())
                    imgui.PopStyleColor()
                end
                if seatBeltStatusOn() then
                    imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF6666FF)
                    imgui.TextUnformatted("Warning: seat belt signs on.")
                    imgui.PopStyleColor()
                end
            else
            end
            imgui.Separator()
            imgui.Spacing()
        end
    end


    -- Starting Onboarding and Passenger/Cargo Selection
    if toLoadHub_onground_any > 0 and not toLoadHub.phases.is_onboarded and not toLoadHub.phases.is_onboarding then
        local passengeraNumberChanged, newPassengerNumber = imgui.SliderInt("Passengers number", toLoadHub.pax_count, 0, toLoadHub.max_passenger, "Value: %d")
        if passengeraNumberChanged then
            toLoadHub.pax_count = newPassengerNumber
            toLoadHub.simulate_result = false
        end
        local cargoNumberChanged, newCargoNumber = imgui.SliderInt("Cargo " .. toLoadHub.unitLabel, writeInUnitKg(toLoadHub.cargo), 0, writeInUnitKg(toLoadHub.max_cargo_aft + toLoadHub.max_cargo_aft), "Value: %d")
        if cargoNumberChanged then
            toLoadHub.cargo = writeInUnitLbs(newCargoNumber)
            toLoadHub.simulate_result = false
        end

        if imgui.Button("Request Simbrief") then
            fetchSimbriefFPlan()
            toLoadHub.simulate_result = false
        end
        imgui.SameLine(155)
        --if imgui.Button("Set random passenger number") then
        --    setRandomNumberOfPassengers()
        --    toLoadHub.simulate_result = false
        --end
        if not toLoadHub.visible_fuel and toLoadHub.settings.general.simulate_fuel and toLoadHub_beacon_lights_on == 0 then
            if imgui.Button("Fuel Management") then
                toLoadHub.visible_fuel = true
            end
        end

        if (toLoadHub.pax_count > 0 or toLoadHub.cargo > 0) then
            if isAnyDoorOpen() or toLoadHub.settings.door.open_boarding > 0 then
                imgui.Separator()
                imgui.Spacing()
                local isLblCargo = toLoadHub.settings.general.pax_delayed and " Cargo" or ""
                if imgui.Button("Start Boarding" .. isLblCargo .. (not isAnyDoorOpen() and toLoadHub.settings.door.open_boarding > 0 and " (Auto Open Doors)" or "")) then
                    toLoadHub_PaxDistrib = math.random(toLoadHub.pax_distribution_range[1], toLoadHub.pax_distribution_range[2]) / 100
                    startProcedure(true, toLoadHub.settings.door.open_boarding, "Boarding Started")
                end
                if not allDoorsOpen() then
                    if imgui.RadioButton("Airstair", not toLoadHub.settings.general.is_jetbridge) then
                        toLoadHub.settings.general.is_jetbridge = false
                        toLoadHub.simulate_result = false
                    end
                    imgui.SameLine(100)
                    if imgui.RadioButton("Jetbridge", toLoadHub.settings.general.is_jetbridge) then
                        toLoadHub.settings.general.is_jetbridge = true
                        toLoadHub.simulate_result = false
                    end
                end
            else
                imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF95FFF8)
                imgui.TextUnformatted("Open the doors to start the boarding.")
                imgui.PopStyleColor()
            end
        elseif toLoadHub.pax_count <= 0 or toLoadHub.cargo <= 0 then
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF95FFF8)
            imgui.TextUnformatted("Please add at least one passenger or some cargo.")
            imgui.PopStyleColor()
        end
    end

    -- Boarding started but Passenger are not boarding by setting
    if toLoadHub.phases.is_onboarding and toLoadHub.settings.general.pax_delayed and not toLoadHub.phases.is_pax_onboard_enabled then
        if imgui.Button("Start Boarding Passenger") then
            toLoadHub.phases.is_pax_onboard_enabled = true
        end
    end

    -- Onboarding Phase
    if toLoadHub.phases.is_onboarding and not toLoadHub.phases.is_onboarding_pause and not toLoadHub.phases.is_onboarded then
        if toLoadHub.pax_count > 0 and not toLoadHub.phases.is_pax_onboarded and (not toLoadHub.settings.general.pax_delayed or toLoadHub.phases.is_pax_onboard_enabled) then
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF95FFF8)
            imgui.TextUnformatted(string.format("Boarding in progress %s / %s boarded", math.floor(toLoadHub_NoPax), toLoadHub.pax_count))
            imgui.PopStyleColor()
        elseif toLoadHub.pax_count > 0 and toLoadHub.phases.is_pax_onboarded then
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFFFD700)
            imgui.TextUnformatted(string.format("Passenger boarded %s", toLoadHub_NoPax))
            imgui.PopStyleColor()
        elseif not toLoadHub.settings.general.pax_delayed or toLoadHub.phases.is_pax_onboard_enabled then
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF88C0D0)
            imgui.TextUnformatted(string.format("No passenger to board"))
            imgui.PopStyleColor()
        end
        if toLoadHub.cargo > 0 and not toLoadHub.phases.is_cargo_onboarded then
            if toLoadHub.phases.is_cargo_started then
                imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF95FFF8)
                imgui.TextUnformatted(string.format("Cargo in progress:"))
                imgui.Spacing()
                imgui.SameLine(50)
                imgui.TextUnformatted(string.format("FWD %.2f %s / %.2f %s loaded", writeInUnitKg(toLoadHub_FwdCargo) / 1000, toLoadHub.unitTLabel, writeInUnitKg(toLoadHub.cargo_fwd) / 1000, toLoadHub.unitTLabel))
                imgui.Spacing()
                imgui.SameLine(50)
                imgui.TextUnformatted(string.format("AFT %.2f %s / %.2f %s loaded", writeInUnitKg(toLoadHub_AftCargo) / 1000, toLoadHub.unitTLabel, writeInUnitKg(toLoadHub.cargo_aft) / 1000, toLoadHub.unitTLabel))
                imgui.PopStyleColor()
            else
                imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF88C0D0)
                imgui.TextUnformatted(string.format("Cargo loading has not started yet."))
                imgui.PopStyleColor()
            end
        elseif toLoadHub.cargo > 0 and toLoadHub.phases.is_cargo_onboarded then
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFFFD700)
            imgui.TextUnformatted(string.format("Cargo loaded %.2f %s", writeInUnitKg((toLoadHub_AftCargo + toLoadHub_FwdCargo) / 1000), toLoadHub.unitTLabel ))
            imgui.PopStyleColor()
        else
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF88C0D0)
            imgui.TextUnformatted(string.format("No extra cargo to load"))
            imgui.PopStyleColor()
        end

        if imgui.Button("Pause Boarding") then
            toLoadHub.phases.is_onboarding_pause = true
        end
    end

    -- Onboarding Phase Pause
    if toLoadHub.phases.is_onboarding and toLoadHub.phases.is_onboarding_pause and not toLoadHub.phases.is_onboarded then
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFFFD700)
        if toLoadHub.pax_count > 0 and not toLoadHub.phases.is_pax_onboarded then
            imgui.TextUnformatted(string.format("Remaining passengers to board: %s / %s", toLoadHub.pax_count-math.floor(toLoadHub_NoPax), toLoadHub.pax_count))
        end
        if toLoadHub.cargo > 0 and not toLoadHub.phases.is_cargo_onboarded then
            imgui.TextUnformatted(string.format("Remaining cargo to load: %.2f %s / %.2f %s", writeInUnitKg((toLoadHub.cargo - (toLoadHub_FwdCargo + toLoadHub_AftCargo))) / 1000, toLoadHub.unitTLabel, writeInUnitKg(toLoadHub.cargo) / 1000, toLoadHub.unitTLabel))
        end
        imgui.PopStyleColor()
        if imgui.Button("Resume Boarding") then
            toLoadHub.phases.is_onboarding_pause = false
        end
        imgui.SameLine(150)
        if imgui.Button("Reset") then
            resetAirplaneParameters(false)
        end
    end

    -- Omboarded Phase (Boarding Complete), Ready for deboarding
    if toLoadHub_onground_any > 0 and toLoadHub.phases.is_onboarded and not toLoadHub.phases.is_deboarding then
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFFFD700)
        if toLoadHub.pax_count > 0 then
            imgui.TextUnformatted(string.format("Passenger boarded %s", toLoadHub_NoPax))
        end
        if toLoadHub.cargo > 0 then
            imgui.TextUnformatted(string.format("Cargo loaded %.2f %s", writeInUnitKg((toLoadHub_AftCargo + toLoadHub_FwdCargo)) / 1000, toLoadHub.unitTLabel))
        end
        imgui.PopStyleColor()

        if isAnyDoorOpen() or toLoadHub.settings.door.open_deboarding > 0 then
            if seatBeltStatusOn() then
                imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF6666FF)
                imgui.TextUnformatted("Deboarding unavailable with seat belt signs on.")
                imgui.PopStyleColor()
                imgui.Spacing()
                imgui.Spacing()
                imgui.SameLine(235)
            else
                if imgui.Button("Start Deboarding" .. (not isAnyDoorOpen() and toLoadHub.settings.door.open_boarding > 0 and " (Auto Open Doors)" or "")) then
                    startProcedure(false, toLoadHub.settings.door.open_deboarding, "Deboarding Started")
                end
                if not allDoorsOpen() then
                    if imgui.RadioButton("Airstair", not toLoadHub.settings.general.is_jetbridge) then
                        toLoadHub.settings.general.is_jetbridge = false
                    end
                    imgui.SameLine(100)
                    if imgui.RadioButton("Jetbridge", toLoadHub.settings.general.is_jetbridge) then
                        toLoadHub.settings.general.is_jetbridge = true
                    end
                end
                imgui.SameLine(300)
            end
        else
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF95FFF8)
            imgui.TextUnformatted("Open the doors to start the deboarding.")
            imgui.PopStyleColor()
            imgui.Spacing()
            imgui.Spacing()
            imgui.SameLine(235)
        end
        if imgui.Button("Reset") then
            resetAirplaneParameters(false)
        end
    end

     -- Deboarding Phase
    if toLoadHub.phases.is_deboarding and not toLoadHub.phases.is_deboarding_pause and not toLoadHub.phases.is_deboarded then
        if toLoadHub_NoPax > 0 and not toLoadHub.phases.is_pax_deboarded then
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF95FFF8)
            imgui.TextUnformatted(string.format("Deboarding in progress %s / %s deboarded", math.floor(toLoadHub.pax_count - toLoadHub_NoPax), toLoadHub.pax_count))
            imgui.PopStyleColor()
        elseif toLoadHub_NoPax == 0 and toLoadHub.phases.is_pax_deboarded then
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFFFD700)
            imgui.TextUnformatted("Passenger deboarded")
            imgui.PopStyleColor()
        else
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF88C0D0)
            imgui.TextUnformatted(string.format("No passenger to deboard"))
            imgui.PopStyleColor()
        end

        if toLoadHub_FwdCargo + toLoadHub_AftCargo > 0 and not toLoadHub.phases.is_cargo_deboarded then
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF95FFF8)
            imgui.TextUnformatted(string.format("Cargo offloading in progress:"))
            imgui.Spacing()
            imgui.SameLine(50)
            imgui.TextUnformatted(string.format("FWD %.2f %s / %.2f %s offloaded", writeInUnitKg(toLoadHub.cargo_fwd - toLoadHub_FwdCargo) / 1000, toLoadHub.unitTLabel, writeInUnitKg(toLoadHub.cargo_fwd) / 1000, toLoadHub.unitTLabel))
            imgui.Spacing()
            imgui.SameLine(50)
            imgui.TextUnformatted(string.format("AFT %.2f %s / %.2f %s offloaded", writeInUnitKg(toLoadHub.cargo_aft - toLoadHub_AftCargo) / 1000, toLoadHub.unitTLabel, writeInUnitKg(toLoadHub.cargo_aft) / 1000, toLoadHub.unitTLabel))
            imgui.PopStyleColor()
        elseif toLoadHub_FwdCargo + toLoadHub_AftCargo == 0 and toLoadHub.phases.is_cargo_deboarded then
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFFFD700)
            imgui.TextUnformatted("Cargo offloaded")
            imgui.PopStyleColor()
        else
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF88C0D0)
            imgui.TextUnformatted(string.format("No cargo to offload"))
            imgui.PopStyleColor()
        end
        if imgui.Button("Pause Deboarding") then
            toLoadHub.phases.is_deboarding_pause = true
        end
    end

     -- Deboarding Phase Pause
    if toLoadHub.phases.is_deboarding and toLoadHub.phases.is_deboarding_pause and not toLoadHub.phases.is_deboarded then
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFFFD700)
        if toLoadHub_NoPax > 0 then
            imgui.TextUnformatted(string.format("Remaining passengers to deboard: %s / %s", toLoadHub_NoPax, toLoadHub.pax_count))
        end
        if toLoadHub_FwdCargo + toLoadHub_AftCargo > 0 then
            imgui.TextUnformatted(string.format("Remaining cargo to offload: %.2f %s / %.2f %s", writeInUnitKg(toLoadHub_FwdCargo + toLoadHub_AftCargo) / 1000, toLoadHub.unitTLabel, writeInUnitKg(toLoadHub.cargo) / 1000, toLoadHub.unitTLabel))
        end
        imgui.PopStyleColor()
        if imgui.Button("Resume Deboarding") then
            toLoadHub.phases.is_deboarding_pause = false
        end
        imgui.SameLine(150)
        if imgui.Button("Reset") then
            resetAirplaneParameters(false)
        end
    end

    -- Deboarded Phase (Deboard Complete), Ready for a new flight!
    if toLoadHub.phases.is_deboarded then
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF87CEFA)
        imgui.TextUnformatted("Deboarding and cargo offloaded have been completed!")
        imgui.PopStyleColor()
        imgui.Spacing()
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFFFD700)
        imgui.PopStyleColor()
		
		-- TODO?

        if imgui.Button("Flight completed! Reset") then
            resetAirplaneParameters(false)
        end
    end

    -- Time Selector for passengers
    if toLoadHub_onground_any > 0 and (toLoadHub.pax_count > 0 or toLoadHub.cargo > 0) and
       ((not toLoadHub.phases.is_onboarded and (not toLoadHub.phases.is_onboarding or toLoadHub.phases.is_onboarding_pause)) or
       (toLoadHub.phases.is_onboarded and not toLoadHub.phases.is_deboarded and (not toLoadHub.phases.is_deboarding or toLoadHub.phases.is_deboarding_pause))) then
        local generalSpeed = 3

        if allDoorsOpen() then
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF6AE079)
            imgui.TextUnformatted("Both doors are open and in use.")
            imgui.PopStyleColor()
            generalSpeed = 2
            toLoadHub.set_default_seconds = false
        elseif areAllDoorsClosed() and
            ((toLoadHub.settings.door.open_boarding > 1 and not toLoadHub.phases.is_onboarded) or
            (toLoadHub.settings.door.open_deboarding > 1 and toLoadHub.phases.is_onboarded)) then
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF6AE079)
            imgui.TextUnformatted("All passenger doors will be operated.")
            imgui.PopStyleColor()
            generalSpeed = 2
            toLoadHub.set_default_seconds = false
        elseif toLoadHub.settings.general.is_jetbridge and isAnyDoorOpen() then
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF6AE079)
            imgui.TextUnformatted("Jetbridge attached.")
            imgui.PopStyleColor()
            generalSpeed = 2
            toLoadHub.set_default_seconds = false
        end

        if isAnyDoorOpen() or (toLoadHub.settings.door.open_boarding > 0 and not toLoadHub.phases.is_onboarded) or
           (toLoadHub.settings.door.open_deboarding > 0  and toLoadHub.phases.is_onboarded) then
            local fastModeMinutes = toLoadHub.simulate_fast_value
            local realModeMinutes = toLoadHub.simulate_real_value

            if not toLoadHub.simulate_result then
                toLoadHub.simulate_result = true
                fastModeMinutes = simulateLoadTime(generalSpeed, 0)
                realModeMinutes = simulateLoadTime(generalSpeed *2, 0)
                if toLoadHub.settings.general.simulate_cargo then
                    local fastModeCargoMinutes = simulateLoadTime(generalSpeed, toLoadHub.cargo_speeds[2])
                    local realModeCargoMinutes = simulateLoadTime(generalSpeed *2, toLoadHub.cargo_speeds[3])
                    fastModeMinutes = calculateTimeWithCargo(fastModeMinutes, fastModeCargoMinutes)
                    realModeMinutes = calculateTimeWithCargo(realModeMinutes, realModeCargoMinutes)
                end
                toLoadHub.simulate_fast_value = fastModeMinutes
                toLoadHub.simulate_real_value = realModeMinutes
            end

            local labelFast = fastModeMinutes < 1
                and "Fast (less than a minute)"
                or string.format("Fast (%d minute%s)", fastModeMinutes, fastModeMinutes > 1 and "s" or "")
            local labelReal = realModeMinutes < 1
                and "Real (less than a minute)"
                or string.format("Real (%d minute%s)", realModeMinutes, realModeMinutes > 1 and "s" or "")

            if not toLoadHub.set_default_seconds then
                toLoadHub.set_default_seconds = true
                if toLoadHub.settings.general.boarding_speed == 1 then
                    toLoadHub.boarding_secnds_per_pax = generalSpeed
                    toLoadHub.boarding_secnds_per_cargo_unit = toLoadHub.cargo_speeds[2]
                end
                if toLoadHub.settings.general.boarding_speed == 2 then
                    toLoadHub.boarding_secnds_per_pax = generalSpeed * 2
                    toLoadHub.boarding_secnds_per_cargo_unit = toLoadHub.cargo_speeds[3]
                end
            end

            if imgui.RadioButton("Instant", toLoadHub.settings.general.boarding_speed == 0) then
                toLoadHub.simulate_result = false
                toLoadHub.settings.general.boarding_speed = 0
                toLoadHub.boarding_secnds_per_pax = 0
                toLoadHub.boarding_secnds_per_cargo_unit = toLoadHub.cargo_speeds[1]
            end

            if imgui.RadioButton(labelFast, toLoadHub.settings.general.boarding_speed == 1) then
                toLoadHub.simulate_result = false
                toLoadHub.settings.general.boarding_speed = 1
                toLoadHub.boarding_secnds_per_pax = generalSpeed
                toLoadHub.boarding_secnds_per_cargo_unit = toLoadHub.cargo_speeds[2]
            end

            if imgui.RadioButton(labelReal, toLoadHub.settings.general.boarding_speed == 2) then
                toLoadHub.simulate_result = false
                toLoadHub.settings.general.boarding_speed = 2
                toLoadHub.boarding_secnds_per_pax = generalSpeed * 2
                toLoadHub.boarding_secnds_per_cargo_unit = toLoadHub.cargo_speeds[3]
            end
        end
    end

    -- Settings Menu Button
    if not toLoadHub.visible_settings and not toLoadHub.phases.is_onboarding then
        imgui.Separator()
        imgui.Spacing()
        imgui.SameLine((toLoadHub.settings.general.window_width)-125)
        if imgui.Button("Settings", 100, 30) then
            toLoadHub.visible_settings = true
            toLoadHub.visible_main = false
            openToLoadHubSettingsWindow()
        end
    end
end

function viewToLoadHubWindowSettings()
    if not float_wnd_is_vr(toloadhub_window) then
        local wLeft, wTop, wRight, wBottom = float_wnd_get_geometry(toloadhub_window)
        toLoadHub.settings.general.window_height = wTop - wBottom
        toLoadHub.settings.general.window_width = wRight - wLeft
    else
        local vrwinWidth, vrwinHeight = float_wnd_get_geometry(toloadhub_window)
        toLoadHub.settings.general.window_height = vrwinHeight
        toLoadHub.settings.general.window_width = vrwinWidth
    end

    imgui.SameLine((toLoadHub.settings.general.window_width/2)-75)
    if imgui.Button("Back to ToLoad HUB", 140, 30) then
        toLoadHub.visible_settings = false
        toLoadHub.visible_main = true
        openToLoadHubWindow(false)
    end
    local setSave = false
    imgui.Separator()
    imgui.Spacing()

    -- General Settings
    imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF95FFF8)
    imgui.TextUnformatted("General Settings:")
    imgui.PopStyleColor()

    local changed, newval
    changed, newval = imgui.Checkbox("Auto Open ToLoad Hub Window", toLoadHub.settings.general.auto_open)
    if changed then toLoadHub.settings.general.auto_open , setSave = newval, true end

    changed, newval = imgui.Checkbox("Automatically initialize airplane", toLoadHub.settings.general.auto_init)
    if changed then toLoadHub.settings.general.auto_init , setSave = newval, true end

    changed, newval = imgui.Checkbox("Simulate Fuel", toLoadHub.settings.general.simulate_fuel)
    if changed then toLoadHub.settings.general.simulate_fuel , setSave = newval, true end
    
    if toLoadHub.settings.general.simulate_fuel then
        changed, newval = imgui.Checkbox("When initializing, reset the fuel to an empty tank", toLoadHub.settings.general.simulate_init_fuel)
        if changed then toLoadHub.settings.general.simulate_init_fuel , setSave = newval, true end
    end

    changed, newval = imgui.Checkbox("Simulate Cargo", toLoadHub.settings.general.simulate_cargo)
    if changed then toLoadHub.settings.general.simulate_cargo , setSave = newval, true end

    if not toLoadHub.settings.general.pax_delayed then
        changed, newval = imgui.Checkbox("Load cargo with pax boarding", toLoadHub.settings.general.concourrent_cargo)
        if changed then toLoadHub.settings.general.concourrent_cargo , setSave = newval, true end
    end

    changed, newval = imgui.Checkbox("Starting with loading cargo", toLoadHub.settings.general.pax_delayed)
    if changed then toLoadHub.settings.general.pax_delayed , setSave = newval, true end

    changed, newval = imgui.Checkbox("Use Imperial Units", toLoadHub.settings.general.is_lbs)
    if changed then toLoadHub.settings.general.is_lbs , setSave = newval, true end
    if toLoadHub.simbrief.units == nil then
        toLoadHub.is_lbs = toLoadHub.settings.general.is_lbs
        setIsLib()
    end

    imgui.SetWindowFontScale(0.8)
    imgui.TextUnformatted("SimBrief has priority over this value.")
    imgui.TextUnformatted("- If SimBrief plan is set to KGS, the units are metric.")
    imgui.TextUnformatted("- If SimBrief plan is set to POUNDS, the units are imperial.")
    imgui.SetWindowFontScale(1.0)
    imgui.Spacing()

    if XPLMFindCommand("jd/ghd/driveup") ~= nil and XPLMFindCommand("jd/ghd/driveavay") ~= nil then
        changed, newval = imgui.Checkbox("Auto Start and Stop JD Ground Hanling", toLoadHub.settings.general.simulate_jdgh)
        if changed then toLoadHub.settings.general.simulate_jdgh , setSave = newval, true end
    end

    changed, newval = imgui.Checkbox("Auto Jetway Management", toLoadHub.settings.general.automate_jetway)
    if changed then toLoadHub.settings.general.automate_jetway , setSave = newval, true end
    
    changed, newval = imgui.Checkbox("Mute the 'Invalid Airplane' message for ToloadHUB", toLoadHub.settings.general.mute_init_failed_validation_sound)
    if changed then toLoadHub.settings.general.mute_init_failed_validation_sound , setSave = newval, true end

    changed, newval = imgui.Checkbox("Debug Mode", toLoadHub.settings.general.debug)
    if changed then toLoadHub.settings.general.debug , setSave = newval, true end
    imgui.Separator()
    imgui.Spacing()

    -- SimBrief Settings
    imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF95FFF8)
    imgui.TextUnformatted("SimBrief Settings:")
    imgui.PopStyleColor()

    imgui.TextUnformatted("Username:")
    changed, newval = imgui.InputText("##username", toLoadHub.settings.simbrief.username, 50)
    if changed then toLoadHub.settings.simbrief.username , setSave = newval, true end

    --changed, newval = imgui.Checkbox("Auto Fetch at beginning", toLoadHub.settings.simbrief.auto_fetch)
    --if changed then toLoadHub.settings.simbrief.auto_fetch , setSave = newval, true end
    toLoadHub.settings.simbrief.auto_fetch = false -- Remove this line if the above lines are to be used.

    changed, newval = imgui.Checkbox("Randomize Baggage Weight Per Pax", toLoadHub.settings.general.randomize_pax_bag_weight_per_pax)
	if changed then toLoadHub.settings.general.randomize_pax_bag_weight_per_pax = newval end

    changed, newval = imgui.Checkbox("Use ToLiss Refuel/Defuel", toLoadHub.settings.general.use_toliss_refuel_defuel)
	if changed then toLoadHub.settings.general.use_toliss_refuel_defuel = newval end

    --changed, newval = imgui.Checkbox("Randomize Passenger", toLoadHub.settings.simbrief.randomize_passenger)
    --if changed then toLoadHub.settings.simbrief.randomize_passenger , setSave = newval, true end
    toLoadHub.settings.simbrief.randomize_passenger = false -- Remove this line if the above lines are to be used.

    if (toLoadHub.settings.general.use_toliss_refuel_defuel == false) then
        
    
    
        imgui.TextUnformatted("Round up the fuel:")
        if imgui.RadioButton("No##roundup", toLoadHub.settings.simbrief.round_up_fuel == 0) then
            toLoadHub.settings.simbrief.round_up_fuel = 0
            setSave = true
        end
        imgui.SameLine(55)
        if imgui.RadioButton("10 units##roundup", toLoadHub.settings.simbrief.round_up_fuel == 1) then
            toLoadHub.settings.simbrief.round_up_fuel = 1
            setSave = true
        end
        imgui.SameLine(143)
        if imgui.RadioButton("50 units##roundup", toLoadHub.settings.simbrief.round_up_fuel == 2) then
            toLoadHub.settings.simbrief.round_up_fuel = 2
            setSave = true
        end
        imgui.SameLine(230)
        if imgui.RadioButton("100 units##roundup", toLoadHub.settings.simbrief.round_up_fuel == 3) then
            toLoadHub.settings.simbrief.round_up_fuel = 3
            setSave = true
        end

        
    end

    imgui.Separator()
    imgui.Spacing()

    -- Hoppie Settings
    imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF95FFF8)
    imgui.TextUnformatted("Hoppie Settings:")
    imgui.PopStyleColor()

    changed, newval = imgui.Checkbox("Enable Loadsheet", toLoadHub.settings.hoppie.enable_loadsheet)
    if changed then toLoadHub.settings.hoppie.enable_loadsheet , setSave = newval, true end

    changed, newval = imgui.Checkbox("Preliminary Loadsheet Only for Long-haul (+7hrs)", toLoadHub.settings.hoppie.preliminary_loadsheet)
    if changed then toLoadHub.settings.hoppie.preliminary_loadsheet , setSave = newval, true end

    changed, newval = imgui.Checkbox("Loadsheet for chocks on and off", toLoadHub.settings.hoppie.chocks_loadsheet)
    if changed then toLoadHub.settings.hoppie.chocks_loadsheet , setSave = newval, true end

    changed, newval = imgui.Checkbox("Display Loadsheet in UTC", toLoadHub.settings.hoppie.utc_time)
    if changed then toLoadHub.settings.hoppie.utc_time , setSave = newval, true end

    changed, newval = imgui.Checkbox("Display Pax In Loadsheet", toLoadHub.settings.hoppie.display_pax)
    if changed then toLoadHub.settings.hoppie.display_pax , setSave = newval, true end

    imgui.TextUnformatted("Secret:")
    local masked_secret = string.rep("*", #toLoadHub.settings.hoppie.secret)
    changed, newval = imgui.InputText("##secret", masked_secret, 80)
    if changed then toLoadHub.settings.hoppie.secret , setSave = newval, true end
    imgui.SetWindowFontScale(0.8)
    imgui.TextUnformatted("The secret can be found by registering at:")
    imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFEBCE87)
    imgui.TextUnformatted("https://www.hoppie.nl/acars/system/register.html")
    imgui.PopStyleColor()
    imgui.TextUnformatted("received via email and used as your logon code.")
    imgui.SetWindowFontScale(1.0)

    imgui.Separator()
    imgui.Spacing()

    -- SayIntentions Settings
    imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF95FFF8)
    imgui.TextUnformatted("SayIntentions ACARS Provider:")
    imgui.PopStyleColor()

    changed, newval = imgui.Checkbox("Use SayIntentions instead of Hoppie", toLoadHub.settings.sayintentions.use_sayintentions)
    if changed then 
        toLoadHub.settings.sayintentions.use_sayintentions , setSave = newval, true 
        -- Re-initialize client if needed
        if newval and toLoadHub.settings.sayintentions.api_key ~= "" and SayIntentionsAPI then
            --XPLMSpeakString("SayIntentions enabled. Please ensure your API key is valid.")
            sapiClient = SayIntentionsAPI.new(toLoadHub.settings.sayintentions.api_key)
            --XPLMSpeakString("SayIntentions client initialized with API key.")
            logMsg("[ToLoadHUB] SayIntentions client initialized")
        end
    end

    imgui.TextUnformatted("API Key:")
    local masked_apikey = string.rep("*", #toLoadHub.settings.sayintentions.api_key)
    changed, newval = imgui.InputText("##sapikey", masked_apikey, 80)
    if changed then 
        toLoadHub.settings.sayintentions.api_key , setSave = newval, true 
        -- Re-initialize client if SayIntentions is enabled
        if toLoadHub.settings.sayintentions.use_sayintentions and SayIntentionsAPI then
            sapiClient = SayIntentionsAPI.new(newval)
            logMsg("[ToLoadHUB] SayIntentions client re-initialized with new API key")
        end
    end

    imgui.TextUnformatted("Station Name:")
    changed, newval = imgui.InputText("##sapistation", toLoadHub.settings.sayintentions.station, 32)
    if changed then toLoadHub.settings.sayintentions.station , setSave = newval, true end

    imgui.SetWindowFontScale(0.8)
    imgui.TextUnformatted("Get your API key from SayIntentions.AI")
    imgui.TextUnformatted("Station will be prefixed with airport code (e.g., KJFK OPS)")
    imgui.SetWindowFontScale(1.0)

    imgui.Separator()
    imgui.Spacing()

    -- Door Settings
    imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF95FFF8)
    imgui.TextUnformatted("Door Settings:")
    imgui.PopStyleColor()

    changed, newval = imgui.Checkbox("Close Doors after Boarding", toLoadHub.settings.door.close_boarding)
    if changed then toLoadHub.settings.door.close_boarding , setSave = newval, true end

    changed, newval = imgui.Checkbox("Close Doors after Deboarding", toLoadHub.settings.door.close_deboarding)
    if changed then toLoadHub.settings.door.close_deboarding , setSave = newval, true end

	changed, newval = imgui.Checkbox("Close Cargo Doors after Deboarding", toLoadHub.settings.door.close_deboarding_cargo)
    if changed then toLoadHub.settings.door.close_deboarding_cargo , setSave = newval, true end
	
    imgui.TextUnformatted("Auto Open Doors before Boarding:")
    if imgui.RadioButton("No##boarding", toLoadHub.settings.door.open_boarding == 0) then
        toLoadHub.settings.door.open_boarding = 0
        toLoadHub.simulate_result = false
        setSave = true
    end
    imgui.SameLine(55)
    if imgui.RadioButton("Yes, Front Door Only##boarding", toLoadHub.settings.door.open_boarding == 1) then
        toLoadHub.settings.door.open_boarding = 1
        setSave = true
        toLoadHub.simulate_result = false
    end
    imgui.SameLine(230)
    if imgui.RadioButton("Yes, All Doors##boarding", toLoadHub.settings.door.open_boarding == 2) then
        toLoadHub.settings.door.open_boarding = 2
        toLoadHub.simulate_result = false
        setSave = true
    end
    imgui.Spacing()

    imgui.TextUnformatted("Auto Open Doors before Deboarding:")
    if imgui.RadioButton("No##deboarding", toLoadHub.settings.door.open_deboarding == 0) then
        toLoadHub.settings.door.open_deboarding = 0
        toLoadHub.simulate_result = false
        setSave = true
    end
    imgui.SameLine(55)
    if imgui.RadioButton("Yes, Front Door Only##deboarding", toLoadHub.settings.door.open_deboarding == 1) then
        toLoadHub.settings.door.open_deboarding = 1
        toLoadHub.simulate_result = false
        setSave = true
    end
    imgui.SameLine(230)
    if imgui.RadioButton("Yes, All Doors##deboarding", toLoadHub.settings.door.open_deboarding == 2) then
        toLoadHub.settings.door.open_deboarding = 2
        toLoadHub.simulate_result = false
        setSave = true
    end

    if not float_wnd_is_vr(toloadhub_window) then
        imgui.Separator()
        imgui.Spacing()
        if imgui.Button("Save current window position", 140, 30) then
            local wLeft, wTop, wRight, wBottom = float_wnd_get_geometry(toloadhub_window)
            local scrLeft, scrTop, scrRight, scrBottom = XPLMGetScreenBoundsGlobal()
            toLoadHub.settings.general.window_x = math.max(scrLeft, wLeft - scrLeft)
            toLoadHub.settings.general.window_y = math.max(scrBottom, wBottom - scrBottom)
            setSave = true
        end
    end

    if setSave then
        saveSettingsToFileToLoadHub(false)
        setSave = false
    end
end

function loadToloadHubWindow()
    if not toLoadHub.visible_main then
        openToLoadHubWindow(true)
    end
end

function toggleToloadHubWindow()
    if os.clock() < toLoadHub.toggle_window then return end
    toLoadHub.toggle_window = os.clock() + 1
    if toLoadHub.visible_main or toLoadHub.visible_settings then
        float_wnd_destroy(toloadhub_window)
    else
        loadToloadHubWindow()
    end
end

function resetPositionToloadHubWindow()
    toLoadHub.settings.general.window_x = 160
    toLoadHub.settings.general.window_y = 200
    toLoadHub.settings.general.window_width = 400
    toLoadHub.settings.general.window_height = 250
    if toLoadHub.visible_main or toLoadHub.visible_settings then 
        float_wnd_set_position(toloadhub_window, toLoadHub.settings.general.window_x, toLoadHub.settings.general.window_y)
    else
        loadToloadHubWindow()
    end
    
end

function startRefuelingDeboardingOrWindow()
    if os.clock() < toLoadHub.toggle_fuel then return end
    toLoadHub.toggle_fuel = os.clock() + 1
    if toLoadHub_onground_any > 0 and toLoadHub.settings.general.simulate_fuel and toLoadHub_beacon_lights_on == 0 then
        if not toLoadHub.phases.is_refueling and not toLoadHub.phases.is_defueling then
            if (toLoadHub.fuel_to_load - writeInUnitKg(toLoadHub_m_fuel_total) >= toLoadHub.fueling_speed_per_second.refuel) or 
               (writeInUnitKg(toLoadHub_m_fuel_total) - toLoadHub.fuel_to_load >= toLoadHub.fueling_speed_per_second.defuel) then
                local message = toLoadHub.fuel_to_load > writeInUnitKg(toLoadHub_m_fuel_total) and "Refueling" or "Defueling"
                if toLoadHub.fuel_to_load > writeInUnitKg(toLoadHub_m_fuel_total) then
                    toLoadHub.phases.is_defueling = false
                    toLoadHub.phases.is_refueling = true
                else
                    toLoadHub.phases.is_defueling = true
                    toLoadHub.phases.is_refueling = false
                end
                toLoadHub.wait_until_speak = os.time()
                toLoadHub.what_to_speak = message .. " Started"
            else
                toLoadHub.wait_until_speak = os.time()
                toLoadHub.what_to_speak = "Fuel loaded as planned"   
            end
        else
            toLoadHub.wait_until_speak = os.time()
            toLoadHub.what_to_speak = "Refuelling not available"  
        end    
    end
end

function startBoardingDeboardingOrWindow()
    if os.clock() < toLoadHub.toggle_pax then return end
    toLoadHub.toggle_pax = os.clock() + 1
    local is_open = false
    if toLoadHub_onground_any > 0 and not toLoadHub.phases.is_onboarded and not toLoadHub.phases.is_onboarding and (toLoadHub.pax_count > 0 or toLoadHub.cargo > 0) and (isAnyDoorOpen() or toLoadHub.settings.door.open_boarding > 0) then
        toLoadHub_PaxDistrib = math.random(toLoadHub.pax_distribution_range[1], toLoadHub.pax_distribution_range[2]) / 100
        startProcedure(true, toLoadHub.settings.door.open_boarding, "Boarding Started")
        is_open = true
    elseif toLoadHub_onground_any > 0 and toLoadHub.phases.is_onboarded and not toLoadHub.phases.is_deboarding and toLoadHub_onground_any > 0 and toLoadHub.phases.is_onboarded and not toLoadHub.phases.is_deboarding and (isAnyDoorOpen() or toLoadHub.settings.door.open_deboarding > 0) then
        if seatBeltStatusOn() then
            toLoadHub.wait_until_speak = os.time()
            toLoadHub.what_to_speak = "Deboarding unavailable with seat belt signs on."
        else
            startProcedure(false, toLoadHub.settings.door.open_deboarding, "Deboarding Started")
            is_open = true
        end
    else
        toLoadHub.wait_until_speak = os.time()
        toLoadHub.what_to_speak = "Procedure not available"
    end
end

function noAcPowerWarn(actionString)
	-- Optional: show/speak once with cooldown
	if not toLoadHub.next_ac_warn or toLoadHub.next_ac_warn < os.time() then
		toLoadHub.error_message = "AC power required for " .. actionString
		toLoadHub.what_to_speak = "AC power required for " .. actionString
		toLoadHub.wait_until_speak = os.time()
		toLoadHub.next_ac_warn = os.time() + 10
	end
end

-- == Main Loop Often (1 Sec) ==
function toloadHubMainLoop()
    -- All sounds played and airplane debooarded
    if not toLoadHub.what_to_speak and toLoadHub.full_deboard_sound and toLoadHub.boarding_sound_played and toLoadHub.boarding_cargo_sound_played and
       toLoadHub.deboarding_sound_played and toLoadHub.deboarding_cargo_sound_played and toLoadHub.phases.is_deboarded then
        return
    end

    local now = os.time()
    local applyChange = false

    -- Speak Onboarding/Deboarding Status after the Cabin
    if toLoadHub.what_to_speak and now > toLoadHub.wait_until_speak then
        XPLMSpeakString(toLoadHub.what_to_speak)
        toLoadHub.what_to_speak = nil
    end

    -- Initial Start if JD Ground Handling
    if not toLoadHub.phases.is_ready_to_start then
        toLoadHub.phases.is_ready_to_start = true
        toLoadHub.next_ready_to_start_check = os.time() + 30
    elseif not toLoadHub.phases.is_gh_started and not toLoadHub.phases.is_onboarding and now > toLoadHub.next_ready_to_start_check then
        toLoadHub.phases.is_gh_started = true
        if XPLMFindCommand("jd/ghd/driveup") ~= nil and XPLMFindCommand("jd/ghd/driveavay") and toLoadHub.settings.general.simulate_jdgh then
            toloadHub_jdexe = 0
            command_once( "jd/ghd/driveup" )
            openDoorsCargo()
            openDoorsCatering() -- after 45 sec minimum!
        end
    elseif toLoadHub.phases.is_ready_to_start and not toLoadHub.phases.is_gh_started and now > toLoadHub.next_ready_to_start_check - 20 and toloadHub_jdexe == 0 then
        toloadHub_jdexe = 1
    end
    -- monitor JetWay
    monitorJetWay(false)

    -- Is Refueling
    if toLoadHub.phases.is_refueling or toLoadHub.phases.is_defueling then
        local labelFuel = toLoadHub.phases.is_refueling and "Refueling" or "Defueling"
        if toLoadHub_beacon_lights_on > 0 then 
            toLoadHub.phases.is_refueling = false
            toLoadHub.wait_until_speak = os.time()
            toLoadHub.what_to_speak = labelFuel .. " halted, beacon lights activated."
            toLoadHub.visible_fuel = false
        else
            if (writeInUnitKg(toLoadHub_m_fuel_total) >= toLoadHub.fuel_to_load and toLoadHub.phases.is_refueling) or
               (writeInUnitKg(toLoadHub_m_fuel_total) <= toLoadHub.fuel_to_load and toLoadHub.phases.is_defueling) then
                toLoadHub.phases.is_refueling = false
                toLoadHub.phases.is_defueling = false
                toLoadHub.wait_until_speak = os.time()
                toLoadHub.what_to_speak = labelFuel .. " complete."
                toLoadHub.visible_fuel = false
            else
                if toLoadHub.fuel_to_load_next <= now then
                    local tank_num = calculateTankNumber()
                    if toLoadHub.phases.is_refueling then
                        local fuel_to_add = (toLoadHub.fueling_speed_per_second.refuel / tank_num)
                        if toLoadHub.fuel_to_load < writeInUnitKg(toLoadHub_m_fuel_total) + toLoadHub.fueling_speed_per_second.refuel then
                            fuel_to_add = math.max(10, ((toLoadHub.fuel_to_load - writeInUnitKg(toLoadHub_m_fuel_total)) / tank_num))
                        end
                        toLoadHub_fuel_1 = toLoadHub_fuel_1 + fuel_to_add
                        toLoadHub_fuel_2 = toLoadHub_fuel_2 + fuel_to_add
                        toLoadHub_fuel_3 = toLoadHub_fuel_3 + fuel_to_add
                    else
                        local fuel_to_remove = (toLoadHub.fueling_speed_per_second.defuel / tank_num)
                        if toLoadHub.fuel_to_load > writeInUnitKg(toLoadHub_m_fuel_total) - toLoadHub.fueling_speed_per_second.defuel then
                            fuel_to_remove = math.max(10, ((writeInUnitKg(toLoadHub_m_fuel_total)-toLoadHub.fuel_to_load) / tank_num))
                        end
                        toLoadHub_fuel_1 = toLoadHub_fuel_1 - fuel_to_remove
                        toLoadHub_fuel_2 = toLoadHub_fuel_2 - fuel_to_remove
                        toLoadHub_fuel_3 = toLoadHub_fuel_3 - fuel_to_remove
                    end
                    toLoadHub.fuel_to_load_next = os.time() + 1
                end
            end
        end
    end

    -- Fuel Start and Stop
    if toLoadHub.fuel_engines_on == nil and toLoadHub.fuel_engines_off == nil and isAnyEngineBurningFuel() then
        toLoadHub.fuel_engines_on = writeInUnitKg(toLoadHub_m_fuel_total)
    end
    if toLoadHub.phases.is_flying and toLoadHub.phases.is_landed and toLoadHub.fuel_engines_on ~= nil and toLoadHub.fuel_engines_off == nil and not isAnyEngineBurningFuel() then
        toLoadHub.fuel_engines_off = writeInUnitKg(toLoadHub_m_fuel_total)
    end

    -- Onboarding Phase and Finishing Onboarding
    if toLoadHub.phases.is_onboarding and not toLoadHub.phases.is_onboarding_pause and not toLoadHub.phases.is_onboarded and isPaxCanStart() then
        if toLoadHub_NoPax < toLoadHub.pax_count and now > toLoadHub.next_boarding_check then
            if toLoadHub.settings.general.boarding_speed == 0 then
                toLoadHub_NoPax = toLoadHub.pax_count
            else
                toLoadHub_NoPax = toLoadHub_NoPax + 1
                applyChange = true
                toLoadHub.next_boarding_check = now + toLoadHub.boarding_secnds_per_pax + math.random(-1, 1)
            end
        end
        if toLoadHub_NoPax >= toLoadHub.pax_count then
            toLoadHub.focus_windows.pax_load = true
            closeDoors(true)
        end
    end

    -- Loading and Starting Cargo
	if not toLoadHub.phases.is_cargo_started and toLoadHub.phases.is_onboarding and not toLoadHub.phases.is_onboarding_pause and isNoPaxInRangeForCargo() then
		if not is_ac_powered() then
			noAcPowerWarn('cargo door management.')
		else
			divideCargoFwdAft()
			openDoorsCargo()
			toLoadHub.phases.is_cargo_started = true
		end
	end
	
    if toLoadHub.phases.is_cargo_started and not toLoadHub.phases.is_onboarding_pause and not toLoadHub.phases.is_onboarded then
        if (toLoadHub_FwdCargo + toLoadHub_AftCargo) < toLoadHub.cargo and now > toLoadHub.next_cargo_check then
            if toLoadHub.settings.general.boarding_speed == 0 or not toLoadHub.settings.general.simulate_cargo then
                toLoadHub_FwdCargo = toLoadHub.cargo_fwd
                toLoadHub_AftCargo = toLoadHub.cargo_aft
            else
                if addingCargoFwdAft() then applyChange = true end
                toLoadHub.next_cargo_check = now + toLoadHub.boarding_secnds_per_cargo_unit + math.random(-2, 2)
            end
        end

        if (toLoadHub_FwdCargo + toLoadHub_AftCargo) >= toLoadHub.cargo then
            toLoadHub.focus_windows.cargo_load = true
			if not is_ac_powered() then
				noAcPowerWarn('cargo door management.')
			else
				closeDoorsCargo()
			end
        end
    end

    -- We Are Flying
    if not toLoadHub.phases.is_flying and not toLoadHub.phases.is_landed and toLoadHub_onground_any < 1 then
        toLoadHub.phases.is_flying = true
        toLoadHub.flt_no = toLoadHub_flight_no
    end

    -- We Are Landed for focus
    if not toLoadHub.phases.is_landed and toLoadHub.phases.is_flying and toLoadHub_onground_any > 0 and isAllEngineOff() then
        toLoadHub.phases.is_landed = true
        monitorJetWay(true)
    end

    -- Deboarding Phase and Finishing Deboarding
    if toLoadHub.phases.is_deboarding and not toLoadHub.phases.is_deboarding_pause and not toLoadHub.phases.is_deboarded then
        if toLoadHub_NoPax > 0 and now > toLoadHub.next_boarding_check then
             if toLoadHub.settings.general.boarding_speed == 0 then
                toLoadHub_NoPax = 0
            else
                toLoadHub_NoPax = toLoadHub_NoPax - math.random(1, 2)
                applyChange = true
                toLoadHub.next_boarding_check = now + toLoadHub.boarding_secnds_per_pax + math.random(-2, 0)
            end
        end
        if toLoadHub_NoPax <= 0 then
            toLoadHub.focus_windows.pax_unload = true
            closeDoors(false)
        end
		
		--#TODO? check for cargo offload completed
		if toLoadHub.settings.door.close_deboarding_cargo then
			if toLoadHub_FwdCargo <= 0 and toLoadHub_AftCargo <= 0 then
				if not is_ac_powered() then
					noAcPowerWarn('cargo door management.')
				else
					closeDoorsCargo()
				end
				closeDoorsCatering()
			end
		end
    end
	
	

    -- Unloading and Starting Cargo Deboarding Phase
    if toLoadHub.phases.is_deboarding and not toLoadHub.phases.is_deboarding_pause and not toLoadHub.phases.is_deboarded then
        -- MOD: conditionally call openDoorsCargo here
		if not toLoadHub.settings.door.close_deboarding_cargo or (toLoadHub_FwdCargo + toLoadHub_AftCargo) > 0 then 
		    if not is_ac_powered() then
				XPLMSpeakString('AC Power required for cargo door management');
				return
			else 
				openDoorsCargo() 
			end
		end 
		
        if (toLoadHub_FwdCargo + toLoadHub_AftCargo) > 0 and now > toLoadHub.next_cargo_check then
            if toLoadHub.settings.general.boarding_speed == 0 or not toLoadHub.settings.general.simulate_cargo then
                toLoadHub_FwdCargo = 0
                toLoadHub_AftCargo = 0
            else
                if removingCargoFwdAft() then applyChange = true end
                toLoadHub.next_cargo_check = now + toLoadHub.boarding_secnds_per_cargo_unit + math.random(-2, 2)
            end
        end

         if (toLoadHub_FwdCargo + toLoadHub_AftCargo) <= 0 then
            toLoadHub.focus_windows.cargo_unload = true
         end
    end


    -- Chocks Off and On
    if toLoadHub.settings.hoppie.chocks_loadsheet and toLoadHub.settings.hoppie.enable_loadsheet then
        -- Force FLight Number for landing scope
        if toLoadHub.flt_no and toLoadHub.flt_no ~= "" and toLoadHub.phases.is_flying and toLoadHub.phases.is_landed and toLoadHub_flight_no ~= toLoadHub.flt_no and not toLoadHub.hoppie.loadsheet_chocks_on_sent then
            toLoadHub_flight_no = toLoadHub.flt_no
        end

         -- Beacon for Chock Off Loadsheet --
        if not toLoadHub.chocks_out_set and toLoadHub_beacon_lights_on > 0 and toLoadHub_parking_brake_ratio <=0.1 then
            toLoadHub.chocks_out_set = true
            toLoadHub.chocks_out_time = os.date((toLoadHub.settings.hoppie.utc_time and "!" or "") .. "%H:%M")
            toLoadHub.hoppie.loadsheet_check = os.time() + 1
        end
        -- Take Off for Chock Off Loadsheet --
        if not toLoadHub.chocks_off_set and toLoadHub.is_onground and toLoadHub_onground_any < 1  then
            toLoadHub.is_onground = false
            toLoadHub.chocks_off_set = true
            toLoadHub.chocks_off_time = os.date((toLoadHub.settings.hoppie.utc_time and "!" or "") .. "%H:%M")
            toLoadHub.hoppie.loadsheet_check = os.time() + 1
        end

        -- Landing for Chock On Loadsheet --
        if toLoadHub.hoppie.loadsheet_chocks_off_sent and not toLoadHub.chocks_on_set and not toLoadHub.is_onground and toLoadHub_onground_any > 0 then
            toLoadHub.is_onground = true
            toLoadHub.chocks_on_set = true
            toLoadHub.chocks_on_time = os.date((toLoadHub.settings.hoppie.utc_time and "!" or "") .. "%H:%M")
            toLoadHub.hoppie.loadsheet_check = os.time() + 5
        end

        -- Engine Off for Chock On Loadsheet --
        if toLoadHub.hoppie.loadsheet_chocks_off_sent and not toLoadHub.chocks_in_set and toLoadHub_beacon_lights_on == 0 and isAllEngineOff() then
            toLoadHub.chocks_in_set = true
            toLoadHub.chocks_in_time = os.date((toLoadHub.settings.hoppie.utc_time and "!" or "") .. "%H:%M")
            toLoadHub.hoppie.loadsheet_check = os.time() + 5
        end

        -- Altitude Chock Off Loadsheet --
        if toLoadHub.hoppie.loadsheet_sent and not toLoadHub.hoppie.loadsheet_chocks_off_sent and toLoadHub_pressure_altitude >= 10000 then
            local data_coff = loadsheetStructure:new()
            data_coff.typeL = 2
            data_coff.labelText = "Ch. Off"
            data_coff.flt_no = toLoadHub.flt_no
            sendLoadsheetToToliss(data_coff)
        end

        -- Chock On Loadhseet --
        if toLoadHub.hoppie.loadsheet_chocks_off_sent and toLoadHub.phases.is_landed and not toLoadHub.hoppie.loadsheet_chocks_on_sent and toLoadHub.chocks_in_set then
            local data_con = loadsheetStructure:new()
            data_con.typeL = 3
            data_con.labelText = "Ch. On"
            data_con.flt_no = toLoadHub.flt_no
            sendLoadsheetToToliss(data_con)
        end
    end

    -- Focus windows --
    if toLoadHub.phases.is_pax_onboarded and not toLoadHub.focus_windows.pax_loaded then focusOnToLoadHub() toLoadHub.focus_windows.pax_loaded = true end
    if toLoadHub.phases.is_cargo_onboarded and not toLoadHub.focus_windows.cargo_loaded then focusOnToLoadHub() toLoadHub.focus_windows.cargo_loaded = true end
    if toLoadHub.phases.is_pax_deboarded and not toLoadHub.focus_windows.pax_unloaded then focusOnToLoadHub() toLoadHub.focus_windows.pax_unloaded = true end
    if toLoadHub.phases.is_landed and not toLoadHub.focus_windows.we_are_landed then focusOnToLoadHub() toLoadHub.focus_windows.we_are_landed = true end
    if toLoadHub.phases.is_cargo_deboarded and not toLoadHub.focus_windows.cargo_unloaded then focusOnToLoadHub() toLoadHub.focus_windows.cargo_unloaded = true end
    if toLoadHub.phases.is_deboarded and not toLoadHub.focus_windows.all_unloaded then focusOnToLoadHub() toLoadHub.focus_windows.all_unloaded = true end

    -- Play sound if not played yet and they should be
    if toLoadHub_NoPax >= toLoadHub.pax_count and not toLoadHub.boarding_sound_played and toLoadHub.phases.is_pax_onboarded then playChimeSound() end
    if (toLoadHub_FwdCargo + toLoadHub_AftCargo) >= toLoadHub.cargo and not toLoadHub.boarding_cargo_sound_played and toLoadHub.phases.is_cargo_onboarded then playCargoSound() end
    if toLoadHub_NoPax <= 0 and not toLoadHub.deboarding_sound_played and toLoadHub.phases.is_pax_deboarded then playChimeSound() end
    if (toLoadHub_FwdCargo + toLoadHub_AftCargo) <= 0 and not toLoadHub.deboarding_cargo_sound_played and toLoadHub.phases.is_cargo_deboarded then playCargoSound() end
    if toLoadHub_NoPax <= 0 and not toLoadHub.full_deboard_sound and (toLoadHub_FwdCargo + toLoadHub_AftCargo) <= 0 and toLoadHub.phases.is_deboarded then playFinalSound() end

    -- Compliting the Onboarding process (Cargo + Passengers)
    if not toLoadHub.phases.is_pax_onboarded and toLoadHub_NoPax >= toLoadHub.pax_count and toLoadHub.phases.is_onboarding then
        toLoadHub.phases.is_pax_onboarded = true
        applyChange = true
    end
    if not toLoadHub.phases.is_cargo_onboarded and (toLoadHub_FwdCargo + toLoadHub_AftCargo) >= toLoadHub.cargo and toLoadHub.phases.is_onboarding then
        toLoadHub.phases.is_cargo_onboarded = true
        applyChange = true
    end
    if not toLoadHub.phases.is_onboarded and toLoadHub.phases.is_pax_onboarded and toLoadHub.phases.is_cargo_onboarded and toLoadHub.phases.is_onboarding then
        toLoadHub.phases.is_onboarded = true
        applyChange = true
         if XPLMFindCommand("jd/ghd/driveup") ~= nil and XPLMFindCommand("jd/ghd/driveavay") ~= nil and toLoadHub.settings.general.simulate_jdgh then
            command_once( "jd/ghd/driveavay" )
            closeDoorsCatering()
        end
        toLoadHub.hoppie.loadsheet_check = os.time() + 5
    end

    -- Compliting the Deboarding process (Cargo + Passengers)
    if not toLoadHub.phases.is_pax_deboarded and toLoadHub_NoPax <= 0 and toLoadHub.phases.is_deboarding then
        toLoadHub.phases.is_pax_deboarded = true
        applyChange = true
    end
    if not toLoadHub.phases.is_cargo_deboarded and (toLoadHub_FwdCargo + toLoadHub_AftCargo) <= 0 and toLoadHub.phases.is_deboarding then
        toLoadHub.phases.is_cargo_deboarded = true
        applyChange = true
    end
    if not toLoadHub.phases.is_deboarded and toLoadHub_NoPax <= 0 and (toLoadHub_FwdCargo + toLoadHub_AftCargo) <= 0 and toLoadHub.phases.is_deboarding then
        toLoadHub.phases.is_deboarded = true
        applyChange = true
    end

    -- Applying change if needed
    if applyChange then
        toLoadHub_NoPax_XP = toLoadHub_NoPax
        toLoadHub_PaxDistrib_XP = toLoadHub_PaxDistrib
        toLoadHub_FwdCargo_XP = writeInUnitKg(toLoadHub_FwdCargo)
        toLoadHub_AftCargo_XP = writeInUnitKg(toLoadHub_AftCargo)
        toLoadHub.setWeightCommand = true
        toLoadHub.setWeightTime = os.time() + 2
    end

    if not toLoadHub.hoppie.loadsheet_sent and toLoadHub.settings.hoppie.enable_loadsheet and toLoadHub.phases.is_onboarded and not toLoadHub.phases.is_refueling and not toLoadHub.phases.is_defueling then
        local data_f = loadsheetStructure:new()
        data_f.typeL = 1
        data_f.labelText = "@Final@"
        data_f.flt_no = toLoadHub_flight_no
        if toLoadHub_zfw == nil then
            data_f.zfw = string.format("%.1f", writeInUnitKg(toLoadHub_m_total - toLoadHub_m_fuel_total)/1000)
        else
            data_f.zfw = string.format("%.1f", writeInUnitKg(toLoadHub_zfw)/1000)
        end
        if toLoadHub_zfwCG == nil then
            data_f.zfwcg = "--.-"
        else
            data_f.zfwcg = string.format("%.1f",toLoadHub_zfwCG)
        end
        if toLoadHub.settings.hoppie.display_pax then
            data_f.pax = string.format(toLoadHub.pax_count)
        end
        data_f.gwcg = string.format("%.1f",toLoadHub_currentCG)
        data_f.f_blk = string.format("%.1f",writeInUnitKg(toLoadHub_m_fuel_total)/1000)
        if toLoadHub.simbrief.plan_ramp ~= nil and writeInUnitKg(toLoadHub_m_fuel_total) + 80 < toLoadHub.simbrief.plan_ramp then
            data_f.warning = string.format("%.1f",toLoadHub.simbrief.plan_ramp/1000)
        end
        sendLoadsheetToToliss(data_f)
    end

    if toLoadHub_onground_any > 0 and (not toLoadHub.settings.hoppie.preliminary_loadsheet or toLoadHub.simbrief.est_block ~=nil and toLoadHub.simbrief.est_block/60 > 420) and not toLoadHub.hoppie.loadsheet_preliminary_sent and toLoadHub.settings.hoppie.enable_loadsheet and toLoadHub.simbrief.callsign ~= nil and toLoadHub.simbrief.callsign == toLoadHub_flight_no then
        if not toLoadHub.hoppie.loadsheet_preliminary_ready then
            toLoadHub.hoppie.loadsheet_check = os.time() + 3
            toLoadHub.hoppie.loadsheet_preliminary_ready = true
        end
        local data_p = loadsheetStructure:new()
        divideCargoFwdAft()
        setIscsTemporarySimbrief()
        data_p.typeL = 0
        data_p.labelText = "Prelim."
        data_p.zfw = string.format("%.1f", toLoadHub.simbrief.est_zfw/1000)
        if toLoadHub_blockZfwCG == nil then
            data_p.zfwcg = "--.-"
        else
            data_p.zfwcg = string.format("%.1f", toLoadHub_blockZfwCG)
        end
        if toLoadHub_blockCG == nil then
            data_p.gwcg = "--.-"
        else
            data_p.gwcg = string.format("%.1f", toLoadHub_blockCG)
        end
        if toLoadHub.settings.hoppie.display_pax then
            data_p.pax = string.format(toLoadHub.simbrief.pax_count)
        end
        data_p.f_blk = string.format("%.1f",toLoadHub.simbrief.plan_ramp/1000)
        data_p.flt_no = toLoadHub_flight_no
        sendLoadsheetToToliss(data_p)
    end
    registerSetWeight()
end

-- == Main code ==
debug(string.format("[%s] Version %s initialized.", toLoadHub.title, toLoadHub.version))
readSettingsToFile()
if not valid_plane_icao[PLANE_ICAO] then
    if not toLoadHub.settings.general.mute_init_failed_validation_sound then
        XPLMSpeakString("Invalid Airplane for the ToLoad Hub Plugin")
    end
    debug(string.format("[%s] Not Compatible with %s.", toLoadHub.title, tostring(PLANE_ICAO)))
    toLoadHub = nil
    loadsheetStructure = nil
    toloadhub_window = nil
    urls = nil
    LIP = nil
    http = nil
    ltn12 = nil
    return
end

dataref("toLoadHub_NoPax_XP", "AirbusFBW/NoPax", "writeable")
dataref("toLoadHub_PaxDistrib_XP", "AirbusFBW/PaxDistrib", "writeable")
dataref("toLoadHub_AftCargo_XP", "AirbusFBW/AftCargo", "writeable")
dataref("toLoadHub_FwdCargo_XP", "AirbusFBW/FwdCargo", "writeable")

dataref("toLoadHub_Doors_1", "AirbusFBW/PaxDoorModeArray", "writeable", 0)
dataref("toLoadHub_Doors_2", "AirbusFBW/PaxDoorModeArray", "writeable", 2)
dataref("toLoadHub_Doors_6", "AirbusFBW/PaxDoorModeArray", "writeable", 6)
dataref("toLoadHub_CargoDoors_1", "AirbusFBW/CargoDoorModeArray", "writeable", 0)
dataref("toLoadHub_CargoDoors_2", "AirbusFBW/CargoDoorModeArray", "writeable", 1)
dataref("toLoadHub_CargoDoors_3", "AirbusFBW/CargoDoorModeArray", "writeable", 2)
dataref("toLoadHub_CateringDoors_1", "AirbusFBW/PaxDoorModeArray", "writeable", 1)
dataref("toLoadHub_CateringDoors_2", "AirbusFBW/PaxDoorModeArray", "writeable", 3)

dataref("GPU_ON", "sim/cockpit/electrical/gpu_on", "readonly")
dataref("APU_GEN", "sim/cockpit2/electrical/APU_generator_on", "readonly")



if XPLMFindDataRef("toliss_airbus/iscsinterface/currentCG") then
    dataref("toLoadHub_currentCG", "toliss_airbus/iscsinterface/currentCG", "readonly")
elseif XPLMFindDataRef("AirbusFBW/CGLocationPercent") then
    dataref("toLoadHub_currentCG", "AirbusFBW/CGLocationPercent", "readonly")
end


if XPLMFindDataRef("toliss_airbus/iscsinterface/zfw") then
    dataref("toLoadHub_zfw", "toliss_airbus/iscsinterface/zfw", "readonly")
else
    toLoadHub_zfw = nil
end

if XPLMFindDataRef("toliss_airbus/iscsinterface/zfwCG") then
    dataref("toLoadHub_zfwCG", "toliss_airbus/iscsinterface/zfwCG", "readonly")
elseif XPLMFindDataRef("toliss_airbus/init/ZFWCG") then
    dataref("toLoadHub_zfwCG", "toliss_airbus/init/ZFWCG", "readonly")
else
    toLoadHub_zfwCG = nil
end

if XPLMFindDataRef("toliss_airbus/iscsinterface/blockZfwCG") then
    dataref("toLoadHub_blockZfwCG", "toliss_airbus/iscsinterface/blockZfwCG", "readonly")
elseif XPLMFindDataRef("toliss_airbus/iscsinterface/zfwCG") then
    dataref("toLoadHub_blockZfwCG", "toliss_airbus/init/ZFWCG", "readonly")
else
    toLoadHub_blockZfwCG = nil
end

if XPLMFindDataRef("toliss_airbus/iscsinterface/blockCG") then
    dataref("toLoadHub_blockCG", "toliss_airbus/iscsinterface/blockCG", "readonly")
else
    toLoadHub_blockCG = nil
end
dataref("toLoadHub_m_total", "sim/flightmodel/weight/m_total", "readonly")
dataref("toLoadHub_m_fuel_total", "sim/flightmodel/weight/m_fuel_total", "readonly")

--dataref("toLoadHub_flight_no", "toliss_airbus/init/flight_no", "writeable")

dataref("toLoadHub_pressure_altitude", "sim/flightmodel2/position/pressure_altitude", "readonly")
dataref("toLoadHub_beacon_lights_on", "sim/cockpit/electrical/beacon_lights_on", "readonly")
dataref("toLoadHub_parking_brake_ratio", "sim/cockpit2/controls/parking_brake_ratio", "readonly")
dataref("toLoadHub_onground_any", "sim/flightmodel/failures/onground_any", "readonly")

-- Seat belts
dataref("toLoadHub_sim_fasten_seat_belts", "sim/cockpit/switches/fasten_seat_belts", "readonly")
toLoadHub_sim_fasten_seat_belts = XPLMFindDataRef("sim/cockpit/switches/fasten_seat_belts") and dataref("toLoadHub_sim_fasten_seat_belts", "sim/cockpit/switches/fasten_seat_belts", "readonly") or 0
toLoadHub_sim_fasten_seat_belts2 = XPLMFindDataRef("sim/cockpit2/switches/fasten_seat_belts") and dataref("toLoadHub_sim_fasten_seat_belts2", "sim/cockpit2/switches/fasten_seat_belts", "readonly") or 0
toLoadHub_sim_fasten_seat_belts3 = XPLMFindDataRef("AirbusFBW/SeatBeltSignsOn") and dataref("toLoadHub_sim_fasten_seat_belts3", "AirbusFBW/SeatBeltSignsOn", "readonly") or 0
toLoadHub_sim_fasten_seat_belts4 = XPLMFindDataRef("laminar/A333/switches/fasten_seatbelts") and dataref("toLoadHub_sim_fasten_seat_belts4", "laminar/A333/switches/fasten_seatbelts", "readonly") or 0
toLoadHub_sim_fasten_seat_belts5 = XPLMFindDataRef("1-sim/12/switch") and dataref("toLoadHub_sim_fasten_seat_belts5", "1-sim/12/switch", "readonly") or 0


-- Electrical
local ac_bus_volts = XPLMFindDataRef("sim/cockpit2/electrical/bus_volts")
  and dataref_table("sim/cockpit2/electrical/bus_volts") or nil

local gen_on = XPLMFindDataRef("sim/cockpit2/electrical/generator_on")
  and dataref_table("sim/cockpit2/electrical/generator_on") or nil

local apu_gen_on = XPLMFindDataRef("sim/cockpit2/electrical/APU_generator_on")
  and dataref_table("sim/cockpit2/electrical/APU_generator_on") or nil

if XPLMFindDataRef("sim/cockpit/electrical/gpu_on") then
  dataref("toLoadHub_gpu_on", "sim/cockpit/electrical/gpu_on", "readonly")
else
  toLoadHub_gpu_on = 0
end



-- fuel section
if XPLMFindDataRef("sim/flightmodel/weight/m_fuel1") then
    dataref("toLoadHub_fuel_1", "sim/flightmodel/weight/m_fuel1", "writable")
else
    toLoadHub_fuel_1 = nil
end
if XPLMFindDataRef("sim/flightmodel/weight/m_fuel2") then
    dataref("toLoadHub_fuel_2", "sim/flightmodel/weight/m_fuel2", "writable")
else
    toLoadHub_fuel_2 = nil
end
if XPLMFindDataRef("sim/flightmodel/weight/m_fuel3") then
    dataref("toLoadHub_fuel_3", "sim/flightmodel/weight/m_fuel3", "writable")
else
    toLoadHub_fuel_3 = nil
end

-- JD Section
if XPLMFindDataRef("jd/ghd/execute") then
    dataref("toloadHub_jdexe","jd/ghd/execute", "writeable")
else
    toloadHub_jdexe = 0
end

setAirplaneNumbers()

-- Initialize SayIntentions client if module is available
logMsg("[ToLoadHUB] Checking SayIntentions initialization...")
logMsg("[ToLoadHUB] SayIntentionsAPI module available: " .. tostring(SayIntentionsAPI ~= nil))
logMsg("[ToLoadHUB] API key set: " .. tostring(toLoadHub.settings.sayintentions.api_key ~= nil and toLoadHub.settings.sayintentions.api_key ~= ""))
if toLoadHub.settings.sayintentions.api_key then
    logMsg("[ToLoadHUB] API key length: " .. #toLoadHub.settings.sayintentions.api_key)
end

if SayIntentionsAPI and toLoadHub.settings.sayintentions.api_key and toLoadHub.settings.sayintentions.api_key ~= "" then
    sapiClient = SayIntentionsAPI.new(toLoadHub.settings.sayintentions.api_key)
    logMsg("[ToLoadHUB] SayIntentions client initialized with API key")
    XPLMSpeakString("SayIntentions enabled. API key is set.")
else
    if SayIntentionsAPI and toLoadHub.settings.sayintentions.use_sayintentions then
        logMsg("[ToLoadHUB] WARNING: SayIntentions enabled but API key not set")
        XPLMSpeakString("SayIntentions enabled. Please ensure your API key is valid.")
    end
end

if toLoadHub.settings.general.auto_init then
    resetAirplaneParameters(true)
end

if toLoadHub.settings.simbrief.auto_fetch then
    fetchSimbriefFPlan()
end
add_macro("ToLoad Hub - Main Window", "loadToloadHubWindow()")
add_macro("ToLoad Hub - Reset Window Position", "resetPositionToloadHubWindow()")

create_command("FlyWithLua/TOLOADHUB/Toggle_toloadhub", "Toggle ToLoadHUB window", "toggleToloadHubWindow()", "", "")
create_command("FlyWithLua/TOLOADHUB/ResetPosition_toloadhub", "Reset Position ToLoadHUB window", "resetPositionToloadHubWindow()", "", "")
create_command("FlyWithLua/TOLOADHUB/Start_Boarding", "Start Boarding/Deboarding", "startBoardingDeboardingOrWindow()", "", "")
create_command("FlyWithLua/TOLOADHUB/Start_Refuel_Defuel", "Start Refueling/Defueling", "startRefuelingDeboardingOrWindow()", "", "")

do_often("toloadHubMainLoop()")

monitorJetWay(true)

if toLoadHub.settings.general.auto_open then
    loadToloadHubWindow()
end
do_on_exit("saveSettingsToFileToLoadHub(true)")
debug(string.format("[%s] Plugin fully loaded.", toLoadHub.title))
