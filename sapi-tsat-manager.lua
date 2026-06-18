-- ============================================================================
-- SayIntentions TSAT/CPDLC Manager
-- Sends realistic TELEX/CPDLC messages with departure times from SimBrief
-- ============================================================================

if not SUPPORTS_FLOATING_WINDOWS then
    logMsg("[SAPI-TSAT] ImGui not supported, script disabled")
    return
end

logMsg("[SAPI-TSAT] Starting script initialization...")

-- ============================================================================
-- Load Required Modules
-- ============================================================================

local SayIntentionsAPI, SimBriefClient

local success, err = pcall(function()
    SayIntentionsAPI = require("SayIntentionsAPI")
    logMsg("[SAPI-TSAT] SayIntentionsAPI module loaded")
end)

if not success then
    logMsg("[SAPI-TSAT] ERROR: Failed to load SayIntentionsAPI: " .. tostring(err))
    return
end

local success, err = pcall(function()
    SimBriefClient = require("SimBriefClient")
    logMsg("[SAPI-TSAT] SimBriefClient module loaded")
end)

if not success then
    logMsg("[SAPI-TSAT] ERROR: Failed to load SimBriefClient: " .. tostring(err))
    return
end

-- ============================================================================
-- Configuration
-- ============================================================================

local CONFIG = {
    -- SayIntentions API Key (empty = will try to load from flight.json)
    SAPI_API_KEY = "",

    -- SimBrief credentials (enter your username OR user ID)
    SIMBRIEF_USERNAME = "",
    SIMBRIEF_USER_ID = "",

    -- Window settings
    WINDOW_WIDTH = 600,
    WINDOW_HEIGHT = 400,

    -- Debug mode
    DEBUG = true
}

-- ============================================================================
-- State Management
-- ============================================================================

local state = {
    -- API clients
    sapiClient = nil,
    simbriefClient = nil,

    -- Window state
    windowOpen = false,

    -- Flight plan data
    flightPlan = nil,
    flightPlanLoaded = false,
    flightPlanError = nil,

    -- TSAT calculation
    tsatOffset = 10, -- Minutes before scheduled departure
    calculatedTSAT = nil,

    -- UI state
    apiKeyInput = "",
    simbriefUsernameInput = "",
    simbriefUserIdInput = "",
    customMessageInput = "",
    selectedStation = "OPS",
    selectedMessageType = "telex",

    -- Status
    lastStatus = "",
    lastStatusTime = 0
}

-- ============================================================================
-- Initialization
-- ============================================================================

--- Initialize API clients
local function initClients()
    -- Initialize SayIntentions API
    state.sapiClient = SayIntentionsAPI:new(CONFIG.SAPI_API_KEY)
    state.sapiClient:setDebug(CONFIG.DEBUG)

    -- Initialize SimBrief client
    state.simbriefClient = SimBriefClient:new(CONFIG.SIMBRIEF_USERNAME, CONFIG.SIMBRIEF_USER_ID)
    state.simbriefClient:setDebug(CONFIG.DEBUG)

    -- Initialize input fields
    state.apiKeyInput = CONFIG.SAPI_API_KEY
    state.simbriefUsernameInput = CONFIG.SIMBRIEF_USERNAME
    state.simbriefUserIdInput = CONFIG.SIMBRIEF_USER_ID

    logMsg("[SAPI-TSAT] Clients initialized")
end

--- Set status message
local function setStatus(message)
    state.lastStatus = message
    state.lastStatusTime = os.clock()
    if CONFIG.DEBUG then
        logMsg("[SAPI-TSAT] " .. message)
    end
end

-- ============================================================================
-- SimBrief Integration
-- ============================================================================

--- Fetch flight plan from SimBrief
local function fetchFlightPlan()
    setStatus("Fetching SimBrief flight plan...")

    local fp, err = state.simbriefClient:fetchFlightPlan(true)

    if err then
        state.flightPlanError = err
        state.flightPlanLoaded = false
        setStatus("Error: " .. err)
        return false
    end

    state.flightPlan = fp
    state.flightPlanLoaded = true
    state.flightPlanError = nil
    setStatus("Flight plan loaded: " .. (fp.origin or "????") .. " to " .. (fp.destination or "????"))

    return true
end

--- Calculate TSAT from scheduled time
local function calculateTSAT()
    if not state.flightPlan or not state.flightPlan.offBlockTime then
        return nil
    end

    local scheduledTime = state.flightPlan.offBlockTime

    -- Parse time (format: HHmm)
    if not scheduledTime or scheduledTime == "" then
        return nil
    end

    -- For simplicity, just format as-is (would need proper time math for real offset)
    -- Format: TSAT HHMMZ
    return scheduledTime .. "Z"
end

-- ============================================================================
-- CPDLC/TELEX Message Functions
-- ============================================================================

--- Send TSAT message via SayIntentions
local function sendTSATMessage()
    if not state.flightPlanLoaded or not state.flightPlan then
        setStatus("Error: No flight plan loaded")
        return false
    end

    local tsat = calculateTSAT()
    if not tsat then
        setStatus("Error: Could not calculate TSAT")
        return false
    end

    -- Build message
    local origin = state.flightPlan.origin or "????"
    local destination = state.flightPlan.destination or "????"
    local callsign = state.flightPlan.callsign or "FLIGHT"
    local gate = state.flightPlan.departureGate or "RAMP"

    local message = string.format(
        "STARTUP APPROVAL\n%s %s-%s\nTSAT %s\nGATE %s\nCTC GND READY",
        callsign,
        origin,
        destination,
        tsat,
        gate
    )

    -- Station ID (e.g., "KJFK OPS", "DISPATCH")
    local fromStation = origin .. " " .. state.selectedStation

    setStatus("Sending TSAT message...")

    -- Send via SayIntentions API
    local response, err = state.sapiClient:sendACARSMessage(
        message,
        fromStation,
        "WU", -- Wilco/Unable response code
        state.selectedMessageType
    )

    if err then
        setStatus("Error sending message: " .. err)
        return false
    end

    setStatus("TSAT message sent successfully!")
    return true
end

--- Send custom CPDLC/TELEX message
local function sendCustomMessage()
    if state.customMessageInput == "" then
        setStatus("Error: Message is empty")
        return false
    end

    local origin = "XXXX"
    if state.flightPlanLoaded and state.flightPlan then
        origin = state.flightPlan.origin or "XXXX"
    end

    local fromStation = origin .. " " .. state.selectedStation

    setStatus("Sending custom message...")

    local response, err = state.sapiClient:sendACARSMessage(
        state.customMessageInput,
        fromStation,
        "NE", -- No response expected
        state.selectedMessageType
    )

    if err then
        setStatus("Error sending message: " .. err)
        return false
    end

    setStatus("Custom message sent successfully!")
    return true
end

-- ============================================================================
-- ImGui Window
-- ============================================================================

-- ============================================================================
-- ImGui Window
-- ============================================================================

local wnd = nil
local wnd_width = 700
local wnd_height = 600

function drawWindow(wnd_id)
    -- ========================================================================
    -- Configuration Section
    -- ========================================================================

    imgui.TextUnformatted("=== Configuration ===")
    imgui.Separator()
    imgui.Spacing()

    -- SayIntentions API Key
    imgui.TextUnformatted("SayIntentions API Key:")
    imgui.PushItemWidth(300)
    local changed, newKey = imgui.InputText("##apikey", state.apiKeyInput, 256)
    if changed then
        state.apiKeyInput = newKey
    end
    imgui.PopItemWidth()

    imgui.SameLine()
    if imgui.Button("Set API Key", 120, 20) then
        state.sapiClient:setApiKey(state.apiKeyInput)
        CONFIG.SAPI_API_KEY = state.apiKeyInput
        setStatus("API key updated")
    end

    imgui.Spacing()

    -- SimBrief credentials
    imgui.TextUnformatted("SimBrief Username:")
    imgui.PushItemWidth(200)
    local changed, newUsername = imgui.InputText("##sbusername", state.simbriefUsernameInput, 256)
    if changed then
        state.simbriefUsernameInput = newUsername
    end
    imgui.PopItemWidth()

    imgui.TextUnformatted("SimBrief User ID:")
    imgui.PushItemWidth(200)
    local changed, newUserId = imgui.InputText("##sbuserid", state.simbriefUserIdInput, 256)
    if changed then
        state.simbriefUserIdInput = newUserId
    end
    imgui.PopItemWidth()

    imgui.SameLine()
    if imgui.Button("Set Credentials", 120, 20) then
        if state.simbriefUsernameInput ~= "" then
            state.simbriefClient:setUsername(state.simbriefUsernameInput)
            CONFIG.SIMBRIEF_USERNAME = state.simbriefUsernameInput
        end
        if state.simbriefUserIdInput ~= "" then
            state.simbriefClient:setUserId(state.simbriefUserIdInput)
            CONFIG.SIMBRIEF_USER_ID = state.simbriefUserIdInput
        end
        setStatus("SimBrief credentials updated")
    end

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    -- ========================================================================
    -- SimBrief Flight Plan Section
    -- ========================================================================

    imgui.TextUnformatted("=== SimBrief Flight Plan ===")
    imgui.Separator()
    imgui.Spacing()

    if imgui.Button("Fetch Flight Plan", 150, 30) then
        fetchFlightPlan()
    end

    imgui.SameLine()

    -- Display status
    if state.flightPlanLoaded then
        imgui.PushStyleColor(imgui.constant.Col.Text, 0, 1, 0, 1)
        imgui.TextUnformatted("Loaded")
        imgui.PopStyleColor()
    elseif state.flightPlanError then
        imgui.PushStyleColor(imgui.constant.Col.Text, 1, 0, 0, 1)
        imgui.TextUnformatted("Error: " .. state.flightPlanError)
        imgui.PopStyleColor()
    else
        imgui.PushStyleColor(imgui.constant.Col.Text, 0.5, 0.5, 0.5, 1)
        imgui.TextUnformatted("No flight plan loaded")
        imgui.PopStyleColor()
    end

    -- Display flight plan details
    if state.flightPlanLoaded and state.flightPlan then
        imgui.Spacing()

        local fp = state.flightPlan

        imgui.TextUnformatted("Callsign: " .. (fp.callsign or "N/A"))
        imgui.TextUnformatted("Route: " .. (fp.origin or "????") .. " -> " .. (fp.destination or "????"))
        imgui.TextUnformatted("Aircraft: " .. (fp.aircraftType or "N/A"))
        imgui.TextUnformatted("Off-Block: " .. (fp.estimatedOff or fp.scheduledOff or "N/A"))
        imgui.TextUnformatted("Cruise: FL" .. (fp.cruiseAltitude or "000"))
    end

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    -- ========================================================================
    -- TSAT Message Section
    -- ========================================================================

    imgui.TextUnformatted("=== Send TSAT Message ===")
    imgui.Separator()
    imgui.Spacing()

    if not state.flightPlanLoaded then
        imgui.PushStyleColor(imgui.constant.Col.Text, 1, 0.5, 0, 1)
        imgui.TextUnformatted("Load flight plan first")
        imgui.PopStyleColor()
    else
        if imgui.Button("Send TSAT Message", 200, 35) then
            sendTSATMessage()
        end

        imgui.SameLine()
        imgui.TextUnformatted("Station:")
        imgui.SameLine()
        imgui.PushItemWidth(100)
        local changed, newStation = imgui.InputText("##station", state.selectedStation, 64)
        if changed then
            state.selectedStation = newStation
        end
        imgui.PopItemWidth()
    end

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    -- ========================================================================
    -- Status Bar
    -- ========================================================================

    local statusColor = {0.7, 0.7, 0.7, 1}
    if state.lastStatus:find("Error") then
        statusColor = {1, 0, 0, 1}
    elseif state.lastStatus:find("success") then
        statusColor = {0, 1, 0, 1}
    end

    imgui.PushStyleColor(imgui.constant.Col.Text, statusColor[1], statusColor[2], statusColor[3], statusColor[4])
    imgui.TextUnformatted("Status: " .. state.lastStatus)
    imgui.PopStyleColor()
end

-- ============================================================================
-- FlyWithLua Integration
-- ============================================================================

--- Toggle window visibility (MUST BE GLOBAL for commands to work)
function sapi_tsat_toggle_window()
    if wnd then
        float_wnd_destroy(wnd)
        wnd = nil
        logMsg("[SAPI-TSAT] Window closed")
    else
        wnd = float_wnd_create(wnd_width, wnd_height, 1, true)
        float_wnd_set_title(wnd, "SayIntentions TSAT/CPDLC")
        float_wnd_set_imgui_builder(wnd, "drawWindow")
        logMsg("[SAPI-TSAT] Window opened")
    end
end

--- Main loop callback (not needed with float_wnd)
function draw_sapi_tsat_window()
    -- Empty - float_wnd handles drawing
end

-- ============================================================================
-- Initialization
-- ============================================================================

logMsg("[SAPI-TSAT] Initializing clients...")
initClients()
logMsg("[SAPI-TSAT] Clients initialized successfully")

-- Create command (for keyboard binding)
create_command("FlyWithLua/sapi_tsat/toggle_window", "Toggle SayIntentions TSAT/CPDLC Window", "sapi_tsat_toggle_window()", "", "")
logMsg("[SAPI-TSAT] Command registered: FlyWithLua/sapi_tsat/toggle_window")

-- Create menu item
add_macro("SayIntentions TSAT/CPDLC", "sapi_tsat_toggle_window()", "", "deactivate")
logMsg("[SAPI-TSAT] Macro added to menu")

-- DO NOT register do_every_draw - float_wnd handles it
-- do_every_draw("draw_sapi_tsat_window()")

-- DO NOT AUTO-OPEN - can crash X-Plane
-- state.windowOpen = true

logMsg("[SAPI-TSAT] ========================================")
logMsg("[SAPI-TSAT] Script loaded successfully!")
logMsg("[SAPI-TSAT] Access via: Plugins > FlyWithLua > Macros > SayIntentions TSAT/CPDLC")
logMsg("[SAPI-TSAT] Or bind key to command: FlyWithLua/sapi_tsat/toggle_window")
logMsg("[SAPI-TSAT] ========================================")

setStatus("Ready - Configure credentials and load flight plan")
