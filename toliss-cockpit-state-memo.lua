-- XP12 Cockpit State Memorizer (FlyWithLua)
-- Vas Edition — Fully Optimized

----------------------------------------------------
-- TOLISS DETECTION
----------------------------------------------------
local function tm_is_toliss()
    return XPLMFindDataRef("AirbusFBW/ECAMFlightPhase") ~= nil
end

local function is_valid_toliss_aircraft()
    local icao = PLANE_ICAO
    return icao == "A318" or icao == "A319" or icao == "A320" or icao == "A321"
end

if not tm_is_toliss() then return end
if not is_valid_toliss_aircraft() then return end



----------------------------------------------------
-- TAIL FREEZE
----------------------------------------------------
dataref("PLANE_TAIL", "sim/aircraft/view/acf_tailnum", "readonly")

local tail_initialized = false
local TAIL_ID = ""
local tail_start_time = os.clock()

function update_tail_number()
    if tail_initialized then return end

    -- Toliss sets tail 0.5–2 seconds after load
    if PLANE_TAIL ~= nil and PLANE_TAIL ~= "" then
        TAIL_ID = PLANE_TAIL
        tail_initialized = true
        logMsg("[STATE] Tail number detected and frozen: " .. TAIL_ID)
        return
    end

    -- Fallback if Toliss never sets a tail (blank livery)
    if os.clock() - tail_start_time > 5 then
        TAIL_ID = PLANE_ICAO .. "_NOTAIL"
        tail_initialized = true
        logMsg("[STATE] Tail number missing, using fallback: " .. TAIL_ID)
    end
end

----------------------------------------------------
-- EXCLUSION HELPER
----------------------------------------------------
local function is_excluded(r)
    if not r.excluded_icao or r.excluded_icao == "" then return false end
    if type(r.excluded_icao) == "string" then return r.excluded_icao == PLANE_ICAO end
    if type(r.excluded_icao) == "table" then
        for _, icao in ipairs(r.excluded_icao) do
            if icao == PLANE_ICAO then return true end
        end
    end
    return false
end

----------------------------------------------------
-- CONFIG: SCALAR DATAREFS
----------------------------------------------------
local tracked_refs = {
    { name = "AirbusFBW/NWSnAntiSkid", var = "NWSnAntiSkid", type = "int" },

    -- WX panel
    { name = "AirbusFBW/WXSwitchMode",       var = "WXSwitchMode",      type = "int" },
    { name = "AirbusFBW/WXRadarTilt",        var = "WXRadarTilt",       type = "float" },
    { name = "AirbusFBW/WXSwitchPWS",        var = "WXSwitchPWS",       type = "int" },
    { name = "AirbusFBW/WXSwitchMultiscan",  var = "WXSwitchMultiscan", type = "int" },
    { name = "AirbusFBW/WXRadarGain",        var = "WXRadarGain",       type = "float" },

    -- Floods
    { name = "AirbusFBW/PedestalFloodBrightnessLevel", var = "PedFlood",   type = "float" },
    { name = "AirbusFBW/PanelFloodBrightnessLevel",    var = "PanelFlood", type = "float" },
    { name = "AirbusFBW/OHPBrightnessLevel",           var = "OHPFlood",   type = "float" },
    -- Cockpit Floods
    { name = "ckpt/fcu/lights/left/anim", var = "FCULightLeft",  type = "float" },
    { name = "ckpt/fcu/lights/right/anim", var = "FCULightRight", type = "float" },


    -- ND brightness
    { name = "AirbusFBW/WXAlphaND1", var = "WXAlphaND1", type = "float" },
    { name = "AirbusFBW/WXAlphaND2", var = "WXAlphaND2", type = "float" },

    -- EFIS
    { name = "AirbusFBW/NDrangeCapt", var = "NDrangeCapt", type = "int" },
    { name = "AirbusFBW/NDrangeFO",   var = "NDrangeFO",   type = "int" },

    { name = "ckpt/fcu/roseLeft/anim",  var = "roseLeftAnim",  type = "int" },
    { name = "ckpt/fcu/roseRight/anim", var = "roseRightAnim", type = "int" },
    { name = "ckpt/fcu/adf1Left/anim",  var = "adf1LeftAnim",  type = "int" },
    { name = "ckpt/fcu/adf2Left/anim",  var = "adf2LeftAnim",  type = "int" },
    { name = "ckpt/fcu/adf2Right/anim", var = "adf2RightAnim", type = "int" },
    { name = "ckpt/fcu/adf1Right/anim", var = "adf1RightAnim", type = "int" },

    -- OVH
    { name = "AirbusFBW/EconFlowSel", var = "EconFlowSel", type = "int", excluded_icao = "A319" },
    { name = "AirbusFBW/PackFlowSel", var = "PackFlowSel", type = "int" },
    { name = "AirbusFBW/LandElev",    var = "LandElev",    type = "float" },
    { name = "AirbusFBW/AudioSwitching", var = "AudioSwitching", type = "int" },
    { name = "ckpt/oh/wiperRight/anim", var = "wiperRightAnim", type = "int" },
    { name = "ckpt/oh/wiperLeft/anim",  var = "wiperLeftAnim",  type = "int" },
    { name = "ckpt/oh/domeLight/anim",  var = "domeLightAnim",  type = "int" },

    -- Pedestal switching
    { name = "AirbusFBW/DMCSwitching",      var = "DMCSwitching",      type = "int" },
    { name = "AirbusFBW/ECAMNDSwitching",   var = "ECAMNDSwitching",   type = "int" },
    { name = "AirbusFBW/AttitudeSwitching", var = "AttitudeSwitching", type = "int" },
    { name = "AirbusFBW/AirDataSwitching",  var = "AirDataSwitching",  type = "int" },
}

----------------------------------------------------
-- ARRAY DATAREFS
----------------------------------------------------
local dr_brightness = nil
local dr_throttle = nil
local dr_adirs = nil

local brightness_ready = false
local throttle_ready = false
local adirs_ready = false

----------------------------------------------------
-- SAVE PATH
----------------------------------------------------
local acf = string.gsub(AIRCRAFT_FILENAME, "[^%w_%-]", "_")
local save_path = nil

----------------------------------------------------
-- RUNTIME
----------------------------------------------------
local ref_handles = {}
local init_done = false

local autoload_done = false
local autoload_started = false
local autoload_start_time = 0

----------------------------------------------------
-- INIT
----------------------------------------------------
function try_init()
    if init_done == true then return end
    if not tail_initialized then return end

    -- Build save path
    if save_path == nil then
        save_path = SCRIPT_DIRECTORY .. "cockpit_state_" .. TAIL_ID .. "_" .. acf .. ".cfg"
        logMsg("[STATE] Save path initialized: " .. save_path)
    end

    -- Arrays
    if not brightness_ready then
        dr_brightness = dataref_table("AirbusFBW/DUBrightness")
        if dr_brightness and dr_brightness[0] ~= nil then brightness_ready = true end
    end

    if not throttle_ready then
        dr_throttle = dataref_table("AirbusFBW/throttle_input")
        if dr_throttle and dr_throttle[0] ~= nil then throttle_ready = true end
    end

    if not adirs_ready then
        dr_adirs = dataref_table("AirbusFBW/ADIRUSwitchArray")
        if dr_adirs and dr_adirs[0] ~= nil then adirs_ready = true end
    end

    -- Scalar refs
    for _, r in ipairs(tracked_refs) do
        if not ref_handles[r.name] and not is_excluded(r) then
            dataref(r.var, r.name, "writable")
            ref_handles[r.name] = r.var
        end
    end

    init_done = true
end

----------------------------------------------------
-- SAVE
----------------------------------------------------
function save_state()
    if save_path == nil then
        logMsg("[STATE] save_state() aborted: save_path is nil")
        return
    end

    local f = io.open(save_path, "w")
    if not f then return end

    if brightness_ready then
        for i = 0, 7 do f:write("DUBRIGHT_" .. i .. "=" .. dr_brightness[i] .. "\n") end
    end

    if throttle_ready then
        for i = 0, 3 do f:write("THROTTLE_" .. i .. "=" .. dr_throttle[i] .. "\n") end
    end

    if adirs_ready then
        for i = 0, 2 do f:write("ADIRS_" .. i .. "=" .. dr_adirs[i] .. "\n") end
    end

    for _, r in ipairs(tracked_refs) do
        if not is_excluded(r) then
            local v = _G[ref_handles[r.name]]
            if v ~= nil then f:write(r.name .. "=" .. v .. "\n") end
        end
    end

    f:close()
end

----------------------------------------------------
-- LOAD
----------------------------------------------------
function load_state()
    if save_path == nil then
        logMsg("[STATE] load_state() aborted: save_path is nil")
        return false
    end

    local f = io.open(save_path, "r")
    if not f then return false end

    for line in f:lines() do
        local key, val = line:match("([^=]+)=([^=]+)")
        if key and val then
            local num = tonumber(val)

            if key:find("DUBRIGHT_") then
                local idx = tonumber(key:match("_(%d+)"))
                if idx and dr_brightness and dr_brightness[idx] ~= nil then dr_brightness[idx] = num end
            end

            if key:find("THROTTLE_") then
                local idx = tonumber(key:match("_(%d+)"))
                if idx and dr_throttle and dr_throttle[idx] ~= nil then dr_throttle[idx] = num end
            end

            if key:find("ADIRS_") then
                local idx = tonumber(key:match("_(%d+)"))
                if idx and dr_adirs and dr_adirs[idx] ~= nil then dr_adirs[idx] = num end
            end

            local varname = ref_handles[key]
            if varname and num ~= nil then _G[varname] = num end
        end
    end

    f:close()
    return true
end

----------------------------------------------------
-- AUTOLOAD (5 seconds after ready)
----------------------------------------------------
function delayed_autoload()
    if save_path == nil then return end
    if autoload_done then return end

    if not autoload_started then
        autoload_started = true
        autoload_start_time = os.clock()
        return
    end

    if os.clock() - autoload_start_time > 5 then
        load_state()
        autoload_done = true
        logMsg("[STATE] Autoload executed after 5 seconds")
    end
end

----------------------------------------------------
-- SCHEDULERS
----------------------------------------------------
do_often("update_tail_number()")
do_often("try_init()")
do_often("delayed_autoload()")
do_on_exit("save_state()")
--do_on_new_plane("delayed_autoload()")

----------------------------------------------------
-- COMMANDS
----------------------------------------------------
create_command("vas/state/save", "Save cockpit state", "save_state()", "", "")
create_command("vas/state/load", "Load cockpit state", "load_state()", "", "")
