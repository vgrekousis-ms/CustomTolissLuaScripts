-- ============================================================================
-- SimBrief API Client for FlyWithLua NG
-- Fetches flight plan data from SimBrief
-- Documentation: https://www.simbrief.com/system/api.php
-- ============================================================================

local SimBriefClient = {}
SimBriefClient.__index = SimBriefClient

-- ============================================================================
-- Configuration
-- ============================================================================

local SIMBRIEF_API_URL = "https://www.simbrief.com/api/xml.fetcher.php"

-- ============================================================================
-- Utility Functions
-- ============================================================================

--- URL encode a string
local function urlEncode(str)
    if str then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w %-%_%.])",
            function(c)
                return string.format("%%%02X", string.byte(c))
            end)
        str = string.gsub(str, " ", "+")
    end
    return str
end

--- Make HTTP GET request
local function httpGet(url)
    local http = require("socket.http")
    local ltn12 = require("ltn12")

    local response_body = {}
    local res, code, response_headers, status = http.request{
        url = url,
        method = "GET",
        sink = ltn12.sink.table(response_body)
    }

    if code == 200 then
        return true, table.concat(response_body)
    else
        return false, "HTTP " .. tostring(code) .. ": " .. (status or "Unknown error")
    end
end

--- Parse JSON response
local function parseJSON(jsonString)
    -- Try to load dkjson from Modules/json/dkjson.lua
    local dkjson = nil
    local success = false

    -- Try standard require path for FlyWithLua Modules folder
    success, dkjson = pcall(require, "json.dkjson")

    if not success then
        -- Try direct dkjson
        success, dkjson = pcall(require, "dkjson")
    end

    if success and dkjson then
        local obj, pos, err = dkjson.decode(jsonString, 1, nil)
        if err then
            return nil, "JSON decode error: " .. tostring(err)
        end
        return obj
    else
        return nil, "No JSON parser available. Last error: " .. tostring(dkjson)
    end
end

-- ============================================================================
-- Constructor
-- ============================================================================

--- Create a new SimBrief client
-- @param username string SimBrief username (optional, can be set later)
-- @param userId string SimBrief user ID (optional, alternative to username)
-- @return table SimBrief client instance
function SimBriefClient:new(username, userId)
    local instance = {
        username = username or "",
        userId = userId or "",
        lastError = nil,
        lastFetchTime = 0,
        cachedFlightPlan = nil,
        debug = false
    }
    setmetatable(instance, SimBriefClient)
    return instance
end

--- Set SimBrief username
function SimBriefClient:setUsername(username)
    self.username = username
end

--- Set SimBrief user ID
function SimBriefClient:setUserId(userId)
    self.userId = userId
end

--- Enable/disable debug output
function SimBriefClient:setDebug(enabled)
    self.debug = enabled
end

--- Get last error message
function SimBriefClient:getLastError()
    return self.lastError
end

-- ============================================================================
-- API Methods
-- ============================================================================

--- Fetch flight plan from SimBrief
-- @param forceRefresh boolean Force refresh even if cached (optional)
-- @return table Flight plan data, or nil on error
-- @return string Error message if failed
function SimBriefClient:fetchFlightPlan(forceRefresh)
    -- Check if we have credentials
    if (not self.username or self.username == "") and (not self.userId or self.userId == "") then
        self.lastError = "No SimBrief username or user ID configured"
        return nil, self.lastError
    end

    -- Use cached data if available and not forcing refresh
    local currentTime = os.time()
    if not forceRefresh and self.cachedFlightPlan and (currentTime - self.lastFetchTime) < 60 then
        if self.debug then
            print("[SimBrief] Using cached flight plan")
        end
        return self.cachedFlightPlan, nil
    end

    -- Build API URL
    local url = SIMBRIEF_API_URL .. "?"
    if self.userId and self.userId ~= "" then
        url = url .. "userid=" .. urlEncode(self.userId)
    else
        url = url .. "username=" .. urlEncode(self.username)
    end
    url = url .. "&json=1"

    if self.debug then
        print("[SimBrief] Fetching: " .. url)
    end

    -- Make request
    local success, response = httpGet(url)

    if not success then
        self.lastError = response
        return nil, response
    end

    -- Parse the response
    local flightPlan = self:_parseFlightPlan(response)

    if not flightPlan then
        self.lastError = "Failed to parse SimBrief response: " .. (self.lastError or "Unknown error")
        return nil, self.lastError
    end

    -- Cache the result
    self.cachedFlightPlan = flightPlan
    self.lastFetchTime = currentTime
    self.lastError = nil

    return flightPlan, nil
end

--- Parse SimBrief JSON response
function SimBriefClient:_parseFlightPlan(jsonString)
    -- Parse JSON
    local data, err = parseJSON(jsonString)
    if not data then
        self.lastError = "JSON parse error: " .. tostring(err)
        return nil
    end

    -- Check for API errors
    if data.fetch and data.fetch.status == "Error" then
        self.lastError = "SimBrief API error"
        return nil
    end

    local plan = {}

    -- Basic flight info from origin and destination
    if data.origin then
        plan.origin = data.origin.icao_code
        plan.originName = data.origin.name
        plan.departureRunway = data.origin.plan_rwy
        plan.originMetar = data.origin.metar
    end

    if data.destination then
        plan.destination = data.destination.icao_code
        plan.destinationName = data.destination.name
        plan.arrivalRunway = data.destination.plan_rwy
        plan.destinationMetar = data.destination.metar
    end

    -- Alternate airport
    if data.alternate then
        plan.alternate = data.alternate.icao_code
        plan.alternateName = data.alternate.name
    end

    -- General flight info
    if data.general then
        plan.airline = data.general.icao_airline
        plan.flightNumber = data.general.flight_number
        plan.route = data.general.route
        plan.cruiseAltitude = data.general.initial_altitude
        plan.cruiseMach = data.general.cruise_mach
        plan.cruiseTAS = data.general.cruise_tas
        plan.distance = data.general.route_distance
        plan.totalBurn = data.general.total_burn
        plan.costIndex = data.general.costindex
        plan.passengers = data.general.passengers

        -- SID/STAR
        plan.sidIdent = data.general.sid_ident
        plan.sidTrans = data.general.sid_trans
        plan.starIdent = data.general.star_ident
        plan.starTrans = data.general.star_trans
    end

    -- Aircraft info
    if data.aircraft then
        plan.aircraftType = data.aircraft.icao_code
        plan.aircraftName = data.aircraft.name
        plan.registration = data.aircraft.reg
        plan.selcal = data.aircraft.selcal
        plan.equipment = data.aircraft.equip
    end

    -- ATC info
    if data.atc then
        plan.callsign = data.atc.callsign
        plan.flightRules = data.atc.flight_rules
        plan.flightType = data.atc.flight_type
        plan.atcRoute = data.atc.route
        plan.flightplanText = data.atc.flightplan_text
    end

    -- Times
    if data.times then
        plan.estimatedEnroute = data.times.est_time_enroute
        plan.scheduledOut = data.times.sched_out
        plan.scheduledOff = data.times.sched_off
        plan.scheduledOn = data.times.sched_on
        plan.scheduledIn = data.times.sched_in
        plan.scheduledBlock = data.times.sched_block
        plan.estimatedOut = data.times.est_out
        plan.estimatedOff = data.times.est_off
        plan.estimatedOn = data.times.est_on
        plan.estimatedIn = data.times.est_in
        plan.estimatedBlock = data.times.est_block
        plan.taxiOut = data.times.taxi_out
        plan.taxiIn = data.times.taxi_in
        plan.endurance = data.times.endurance
    end

    -- Fuel
    if data.fuel then
        plan.fuelTaxi = data.fuel.taxi
        plan.fuelEnroute = data.fuel.enroute_burn
        plan.fuelContingency = data.fuel.contingency
        plan.fuelAlternate = data.fuel.alternate_burn
        plan.fuelReserve = data.fuel.reserve
        plan.fuelExtra = data.fuel.extra
        plan.fuelMinTakeoff = data.fuel.min_takeoff
        plan.fuelPlanTakeoff = data.fuel.plan_takeoff
        plan.fuelPlanRamp = data.fuel.plan_ramp
        plan.fuelPlanLanding = data.fuel.plan_landing
        plan.avgFuelFlow = data.fuel.avg_fuel_flow
    end

    -- Weights
    if data.weights then
        plan.oew = data.weights.oew
        plan.payload = data.weights.payload
        plan.cargo = data.weights.cargo
        plan.paxCount = data.weights.pax_count
        plan.paxWeight = data.weights.pax_weight
        plan.bagWeight = data.weights.bag_weight
        plan.estimatedZFW = data.weights.est_zfw
        plan.maxZFW = data.weights.max_zfw
        plan.estimatedTOW = data.weights.est_tow
        plan.maxTOW = data.weights.max_tow
        plan.estimatedLDW = data.weights.est_ldw
        plan.maxLDW = data.weights.max_ldw
        plan.estimatedRamp = data.weights.est_ramp
    end

    -- Navlog (route waypoints)
    if data.navlog and data.navlog.fix then
        plan.navlog = {}
        for i, fix in ipairs(data.navlog.fix) do
            table.insert(plan.navlog, {
                ident = fix.ident,
                type = fix.type,
                freq = fix.freq,
                lat = fix.pos_lat,
                lon = fix.pos_long,
                altitude = fix.altitude_feet,
                wind = fix.wind_dir .. "/" .. fix.wind_spd,
                oat = fix.oat,
                ete = fix.time_leg,
                fuelRemaining = fix.fuel_plan_rwy
            })
        end
    end

    -- Files and downloads
    if data.files then
        plan.pdfLink = data.files.pdf and data.files.pdf.link
        plan.filesDirectory = data.files.directory
    end

    -- FMS downloads
    if data.fms_downloads then
        plan.fmsDownloads = {}
        for format, fileInfo in pairs(data.fms_downloads) do
            if type(fileInfo) == "table" and fileInfo.link then
                plan.fmsDownloads[format] = fileInfo.link
            end
        end
    end

    -- Check if we got valid data
    if not plan.origin or not plan.destination then
        self.lastError = "Invalid response: missing origin or destination"
        return nil
    end

    return plan
end

--- Get cached flight plan (without fetching)
function SimBriefClient:getCachedFlightPlan()
    return self.cachedFlightPlan
end

--- Clear cached flight plan
function SimBriefClient:clearCache()
    self.cachedFlightPlan = nil
    self.lastFetchTime = 0
end

-- ============================================================================
-- Convenience Methods
-- ============================================================================

--- Get formatted departure time string
function SimBriefClient:getDepartureTime()
    if not self.cachedFlightPlan then
        return nil
    end
    return self.cachedFlightPlan.estimatedOff or self.cachedFlightPlan.scheduledOff
end

--- Get formatted route string
function SimBriefClient:getRouteString()
    if not self.cachedFlightPlan then
        return nil
    end

    local fp = self.cachedFlightPlan
    return string.format("%s-%s via %s FL%s", 
        fp.origin or "????",
        fp.destination or "????",
        fp.route or "DCT",
        fp.cruiseAltitude or "000"
    )
end

--- Get callsign
function SimBriefClient:getCallsign()
    if not self.cachedFlightPlan then
        return nil
    end
    return self.cachedFlightPlan.callsign
end

--- Get origin ICAO
function SimBriefClient:getOrigin()
    if not self.cachedFlightPlan then
        return nil
    end
    return self.cachedFlightPlan.origin
end

--- Get destination ICAO
function SimBriefClient:getDestination()
    if not self.cachedFlightPlan then
        return nil
    end
    return self.cachedFlightPlan.destination
end

--- Check if flight plan is loaded
function SimBriefClient:hasFlightPlan()
    return self.cachedFlightPlan ~= nil
end

-- ============================================================================
-- Return Module
-- ============================================================================

return SimBriefClient
