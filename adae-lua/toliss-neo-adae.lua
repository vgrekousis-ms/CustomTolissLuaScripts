-- ADAE.lua  (FlyWithLua)

-- === Constants ===
local ADAE_GROUNDSPEED_LIMIT        = 33.0
local ADAE_MASTER_CAUTION_DURATION  = 3.0
local ADAE_AUTOBRAKE_DEBOUNCE       = 0.0

-- === State ===
local previousAutobrake            = false
local aircraft_autobrake           = false
local aircraft_autobrakeDebounce   = 0.15
local aircraft_masterCautionTimer  = 0.0
local aircraft_masterCaution       = 0

local configuration_ADAE           = true


-- === Toliss detection (MUST BE HERE, BEFORE ANY dataref()) ===
local function adae_is_toliss()
    return XPLMFindDataRef("AirbusFBW/ECAMFlightPhase") ~= nil
end

if not adae_is_toliss() then
    logMsg("ADAE: Non-Toliss aircraft detected. Script disabled.")
    return
end

-- === Datarefs ===
dataref("TA321_AutoBrkLo",       "AirbusFBW/AutoBrkLo",       "readonly")
dataref("TA321_AutoBrkMed",      "AirbusFBW/AutoBrkMed",      "readonly")
dataref("TA321_AutoBrkMax",      "AirbusFBW/AutoBrkMax",      "readonly")
dataref("TA321_GSCapt",          "AirbusFBW/GSCapt",          "readonly")
dataref("TA321_GSFO",            "AirbusFBW/GSFO",            "readonly")
dataref("TA321_MasterCaut",      "AirbusFBW/MasterCaut",      "writable")
dataref("TA321_LMasterCautAnim", "AirbusFBW/LMasterCautAnim", "readonly")
dataref("TA321_RMasterCautAnim", "AirbusFBW/RMasterCautAnim", "readonly")
dataref("TA321_ECAMFlightPhase", "AirbusFBW/ECAMFlightPhase", "readonly")

dataref("KOSP_AutoBrkOff_Callout", "KOSP/settings_autobrake_off_callout", "writable")

dataref("SIM_PERIOD_DR", "sim/operation/misc/frame_rate_period", "readonly")
dataref("ACF_TAILNUM", "sim/aircraft/view/acf_tailnum", "readonly")
dataref("ACF_ICAO", "sim/aircraft/view/acf_ICAO", "readonly")

-- === Sound ===
local ADAE_SOUND_INDEX = 0

-- === ADAE Config State ===
local last_tailnum = ""
local ADAE_enabled = false
local ADAE_impose_A21N = true
local ADAE_tail_list = {}

-- === Helpers ===
local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split_csv(s)
    local t = {}
    for entry in s:gmatch("([^,]+)") do
        table.insert(t, trim(entry))
    end
    return t
end

-- === Load config file ===
local function load_ADAE_cfg()
    local SCRIPT_DIR = SCRIPT_DIRECTORY
    local CFG_PATH = SCRIPT_DIR .. "toliss-neo-adae.ini"

    local f = io.open(CFG_PATH, "r")
    if not f then
        logMsg("ADAE: no cfg file, DISABLED (" .. CFG_PATH .. ")")
        return
    end

    for line in f:lines() do
        local k, v = line:match("([^=]+)=([^=]+)")
        if k and v then
            k = trim(k)
            v = trim(v:gsub('"', ""))
            if k == "ADAE" then
                ADAE_tail_list = split_csv(v)
            end
        end
    end
    f:close()

    -- Initial evaluation
    for _, tail in ipairs(ADAE_tail_list) do
        if ACF_TAILNUM == tail then
            ADAE_enabled = true
            break
        end
    end

    if ADAE_enabled then
        logMsg("ADAE: ENABLED for tail " .. ACF_TAILNUM)
    else
        logMsg("ADAE: DISABLED for tail " .. ACF_TAILNUM)
    end
end

load_ADAE_cfg()

-- === Dynamic tail-number monitoring ===
function update_ADAE_state()
    if ACF_TAILNUM ~= last_tailnum then
        last_tailnum = ACF_TAILNUM
        ADAE_enabled = false

        for _, tail in ipairs(ADAE_tail_list) do
            if ACF_TAILNUM == tail then
                ADAE_enabled = true
                break
            end
        end

        if ADAE_enabled then
            logMsg("ADAE: ENABLED for tail " .. ACF_TAILNUM)
        else
            logMsg("ADAE: DISABLED for tail " .. ACF_TAILNUM)
        end
    end
end

-- === Force KOSP setting every frame ===
function ADAE_force_KOSP_setting()
    if ADAE_enabled then
        KOSP_AutoBrkOff_Callout = 1
    else
        KOSP_AutoBrkOff_Callout = 0
    end
end

-- === ADAE gating ===
function ADAE_CanStart()
    -- Most commonly this feature is found on A321 neos.
    if ACF_ICAO ~= "A21N" and ADAE_impose_A21N == true then return false end

    if SIM_PERIOD_DR == nil or SIM_PERIOD_DR == 0 then
        return false
    end

    if not ADAE_enabled then
        return false
    end

    return true
end

-- === Main ADAE logic ===
function ADAE()

    if not ADAE_CanStart() then return end

    local elapsed = SIM_PERIOD_DR

    if  TA321_AutoBrkLo       == nil or
        TA321_AutoBrkMed      == nil or
        TA321_AutoBrkMax      == nil or
        TA321_GSCapt          == nil or
        TA321_GSFO            == nil or
        TA321_MasterCaut      == nil or
        TA321_LMasterCautAnim == nil or
        TA321_RMasterCautAnim == nil or
        TA321_ECAMFlightPhase == nil then
        return
    end

    local AutoBrkLo  = TA321_AutoBrkLo
    local AutoBrkMed = TA321_AutoBrkMed
    local AutoBrkMax = TA321_AutoBrkMax

    if  (AutoBrkLo  == 2) or (AutoBrkMed == 2) or (AutoBrkMax == 2)
     or (AutoBrkLo  == 1) or (AutoBrkMed == 1) or (AutoBrkMax == 1) then
        aircraft_autobrake         = true
        aircraft_autobrakeDebounce = ADAE_AUTOBRAKE_DEBOUNCE
    else
        if aircraft_autobrake then
            aircraft_autobrakeDebounce = aircraft_autobrakeDebounce - elapsed
            if aircraft_autobrakeDebounce <= 0.0 then
                aircraft_autobrake = false
            end
        end
    end

    if aircraft_masterCautionTimer > 0.0 then
        local LMasterCautAnim = TA321_LMasterCautAnim
        local RMasterCautAnim = TA321_RMasterCautAnim
        local masterCautionPressed = (LMasterCautAnim > 0.0) or (RMasterCautAnim > 0.0)

        if (not masterCautionPressed) and (not aircraft_autobrake) then
            aircraft_masterCautionTimer = aircraft_masterCautionTimer - elapsed
            if aircraft_masterCautionTimer <= 0.0 then
                TA321_MasterCaut = aircraft_masterCaution
            else
                TA321_MasterCaut = 1
            end
        else
            aircraft_masterCautionTimer = 0.0
            if masterCautionPressed then
                TA321_MasterCaut = 0
            else
                TA321_MasterCaut = aircraft_masterCaution
            end
        end
    end

    if previousAutobrake then
        if not aircraft_autobrake then
            previousAutobrake = false

            local ECAMFlightPhase = TA321_ECAMFlightPhase
            local GSCapt          = TA321_GSCapt
            local GSFO            = TA321_GSFO

            if ((ECAMFlightPhase < 5) or (ECAMFlightPhase > 7))
               and ((GSCapt >= ADAE_GROUNDSPEED_LIMIT) or (GSFO >= ADAE_GROUNDSPEED_LIMIT)) then

                if configuration_ADAE then
                    if aircraft_masterCautionTimer <= 0.0 then
                        aircraft_masterCaution = TA321_MasterCaut
                        TA321_MasterCaut = 1
                    end
                    aircraft_masterCautionTimer = ADAE_MASTER_CAUTION_DURATION
                    --play_sound(ADAE_SOUND_INDEX)
                end
            end
        end
    else
        if aircraft_autobrake then
            previousAutobrake = true
        end
    end
end

-- === Frame callbacks ===
do_every_frame("update_ADAE_state()")
do_every_frame("ADAE_force_KOSP_setting()")
do_every_frame("ADAE()")

