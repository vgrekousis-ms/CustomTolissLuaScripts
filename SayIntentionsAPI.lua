-- ============================================================================
-- SayIntentions.AI API Client for FlyWithLua NG
-- Complete implementation of the SAPI REST API
-- Documentation: https://p2.sayintentions.ai/p2/docs/
-- ============================================================================

local SayIntentionsAPI = {}
SayIntentionsAPI.__index = SayIntentionsAPI

-- ============================================================================
-- Configuration
-- ============================================================================

local BASE_URL = "https://apipri.sayintentions.ai/sapi"

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

--- Build URL with query parameters
local function buildUrl(endpoint, params)
    local url = BASE_URL .. "/" .. endpoint
    if params and next(params) ~= nil then
        local queryParams = {}
        for key, value in pairs(params) do
            table.insert(queryParams, key .. "=" .. urlEncode(tostring(value)))
        end
        url = url .. "?" .. table.concat(queryParams, "&")
    end
    return url
end

--- Parse JSON response (basic implementation)
local function parseJSON(jsonString)
    -- Try to use built-in JSON parser if available
    if json and json.decode then
        return json.decode(jsonString)
    end

    -- Fallback: very basic JSON parser for simple responses
    -- Note: For production use, consider including a proper JSON library
    local result = {}

    -- Remove outer braces and whitespace
    jsonString = jsonString:gsub("^%s*{%s*", ""):gsub("%s*}%s*$", "")

    -- Very simple key-value extraction (works for simple responses)
    for key, value in jsonString:gmatch('"([^"]+)"%s*:%s*"([^"]*)"') do
        result[key] = value
    end

    for key, value in jsonString:gmatch('"([^"]+)"%s*:%s*(%d+)') do
        result[key] = tonumber(value)
    end

    return result
end

--- Make HTTP GET request using curl (supports HTTPS)
local function httpGet(url, debug)
    -- Escape URL for command line (Windows-style)
    local escapedUrl = '"' .. url .. '"'

    -- Try curl first (available on Windows 10+)
    local command = 'curl -s -L ' .. escapedUrl

    local handle = io.popen(command)
    if not handle then
        return false, "Failed to execute HTTP request - curl not available"
    end

    local response = handle:read("*a")
    local success, exit_reason, exit_code = handle:close()

    if response and response ~= "" and not response:match("^curl:") then
        if debug then
            print("[SAPI] Response received: " .. response:sub(1, 200))
        end
        return true, response
    else
        return false, "HTTP request failed: " .. (response or "no response") .. " (exit: " .. tostring(exit_code) .. ")"
    end
end

--- Make HTTP POST request using curl (supports HTTPS)
local function httpPost(url, postData)
    -- Escape for command line
    local escapedUrl = '"' .. url .. '"'
    local escapedData = '"' .. postData:gsub('"', '\\"') .. '"'

    -- Use curl for POST
    local command = 'curl -s -L -X POST -d ' .. escapedData .. ' -H "Content-Type: application/x-www-form-urlencoded" ' .. escapedUrl

    local handle = io.popen(command)
    if not handle then
        return false, "Failed to execute HTTP request - curl not available"
    end

    local response = handle:read("*a")
    local success, exit_reason, exit_code = handle:close()

    if response and response ~= "" and not response:match("^curl:") then
        return true, response
    else
        return false, "HTTP request failed: " .. (response or "no response") .. " (exit: " .. tostring(exit_code) .. ")"
    end
end

-- ============================================================================
-- Constructor
-- ============================================================================

--- Create a new SayIntentions API client
-- @param apiKey string Your SayIntentions.AI API key
-- @return table API client instance
function SayIntentionsAPI:new(apiKey)
    local instance = {
        apiKey = apiKey or "",
        lastError = nil,
        debug = false
    }
    setmetatable(instance, SayIntentionsAPI)
    return instance
end

--- Set API key
function SayIntentionsAPI:setApiKey(apiKey)
    self.apiKey = apiKey
end

--- Enable/disable debug output
function SayIntentionsAPI:setDebug(enabled)
    self.debug = enabled
end

--- Get last error message
function SayIntentionsAPI:getLastError()
    return self.lastError
end

--- Internal method to make API request
function SayIntentionsAPI:_request(endpoint, params, method)
    params = params or {}
    method = method or "GET"

    -- Add API key to parameters
    if self.apiKey and self.apiKey ~= "" then
        params.api_key = self.apiKey
    end

    if method == "POST" then
        -- For POST, send params in body, not URL
        local postData = ""
        for key, value in pairs(params) do
            if postData ~= "" then postData = postData .. "&" end
            postData = postData .. key .. "=" .. urlEncode(tostring(value))
        end

        local url = BASE_URL .. endpoint

        if self.debug then
            print("[SAPI] " .. method .. " " .. url)
            print("[SAPI] Body: " .. postData)
        end

        success, response = httpPost(url, postData)
    else
        -- For GET, params in URL
        local url = buildUrl(endpoint, params)

        if self.debug then
            print("[SAPI] " .. method .. " " .. url)
        end

        success, response = httpGet(url, self.debug)
    end

    if not success then
        self.lastError = response
        return nil, response
    end

    -- Parse JSON response
    local data = parseJSON(response)

    -- Check for API error in response
    if data.error then
        self.lastError = data.error
        return nil, data.error
    end

    self.lastError = nil
    return data, nil
end

-- ============================================================================
-- Communication Endpoints
-- ============================================================================

--- Make any entity say a phrase or simulate pilot communications
-- @param channel string Communication channel (COM1, COM2, INTERCOM1, INTERCOM2, INTERCOM3, COM1_IN, COM2_IN, INTERCOM1_IN, INTERCOM2_IN, INTERCOM3_IN, ACARS_IN)
-- @param message string Message to be spoken (max 255 characters, 128 for ACARS_IN)
-- @param options table Optional parameters: rephrase (0/1), from (ACARS station), response_code (ACARS code), message_type ('cpdlc' or 'telex')
-- @return table Response data, or nil on error
-- @return string Error message if failed
function SayIntentionsAPI:sayAs(channel, message, options)
    options = options or {}

    local params = {
        channel = channel,
        message = message
    }

    if options.rephrase ~= nil then
        params.rephrase = options.rephrase
    end

    if options.from then
        params.from = options.from
    end

    if options.response_code then
        params.response_code = options.response_code
    end

    if options.message_type then
        params.message_type = options.message_type
    end

    return self:_request("sayAs", params)
end

--- Retrieve communication history for current flight
-- @return table Response with comm_history array and mission info, or nil on error
-- @return string Error message if failed
function SayIntentionsAPI:getCommsHistory()
    return self:_request("getCommsHistory")
end

-- ============================================================================
-- Weather & Data Endpoints
-- ============================================================================

--- Get weather information (ATIS, METAR, TAF) for airports
-- @param icao string Airport ICAO code(s), multiple separated by commas
-- @param withComms boolean Include communication frequencies (optional)
-- @return table Response with airports and comms data, or nil on error
-- @return string Error message if failed
function SayIntentionsAPI:getWX(icao, withComms)
    local params = {
        icao = icao
    }

    if withComms ~= nil then
        params.with_comms = withComms and 1 or 0
    end

    return self:_request("getWX", params)
end

--- Get current TFR (Temporary Flight Restrictions) data in GeoJSON format
-- @return table TFR data in GeoJSON format, or nil on error
-- @return string Error message if failed
function SayIntentionsAPI:getTFRs()
    return self:_request("getTFRs")
end

--- Get current VATSIM network data in GeoJSON format
-- @return table VATSIM data showing active controllers and pilots, or nil on error
-- @return string Error message if failed
function SayIntentionsAPI:getVATSIM()
    return self:_request("getVATSIM")
end

-- ============================================================================
-- Airport Operations Endpoints
-- ============================================================================

--- Request assignment to a specific gate at an airport
-- @param gate string Gate identifier (max 30 characters, alphanumeric)
-- @param airport string Airport ICAO code (3-4 characters)
-- @return table Response with assigned_gate_name, or nil on error
-- @return string Error message if failed
function SayIntentionsAPI:assignGate(gate, airport)
    local params = {
        gate = gate,
        airport = airport
    }

    return self:_request("assignGate", params)
end

--- Get current parking assignment information
-- @return table Response with parking info (id, name, lat, lon, heading), or nil on error
-- @return string Error message if failed
function SayIntentionsAPI:getParking()
    return self:_request("getParking")
end

--- Get comprehensive airport information including weather and frequencies
-- @return table Airport information for current flight plan, or nil on error
-- @return string Error message if failed
function SayIntentionsAPI:getAirport()
    return self:_request("getAirport")
end

-- ============================================================================
-- Flight Management Endpoints
-- ============================================================================

--- Set radio frequency for COM1 or COM2
-- @param freq number Frequency in MHz (e.g., 121.900)
-- @param com number Radio number: 1 or 2 (default: 1)
-- @param mode string Frequency mode: 'active' or 'standby' (default: 'active')
-- @return table Response data, or nil on error
-- @return string Error message if failed
function SayIntentionsAPI:setFreq(freq, com, mode)
    local params = {
        freq = freq
    }

    if com then
        params.com = com
    end

    if mode then
        params.mode = mode
    end

    return self:_request("setFreq", params)
end

--- Get current frequency configuration
-- @return table Current frequency settings, or nil on error
-- @return string Error message if failed
function SayIntentionsAPI:getCurrentFrequencies()
    return self:_request("getCurrentFrequencies")
end

--- Set flight simulator variable or system parameter
-- @param var string Variable name to set
-- @param value string Value to assign
-- @param category string Variable category (default: "L")
-- @return table Response data, or nil on error
-- @return string Error message if failed
function SayIntentionsAPI:setVar(var, value, category)
    local params = {
        var = var,
        value = value
    }

    if category then
        params.category = category
    end

    return self:_request("setVar", params)
end

--- Pause or unpause the ATC simulation
-- @param pause boolean true to pause, false to unpause
-- @return table Response data, or nil on error
-- @return string Error message if failed
function SayIntentionsAPI:setPause(pause)
    local params = {
        value = pause and 1 or 0
    }

    return self:_request("setPause", params)
end

-- ============================================================================
-- Virtual Airlines Endpoints
-- ============================================================================

--- Import virtual airline data to customize AI behavior
-- @param vaApiKey string Virtual airline API key (provided by SayIntentions.AI)
-- @param data table Table with optional fields: crew_data, dispatcher_data, copilot_data, skyops_data
-- @return table Response with status, or nil on error
-- @return string Error message if failed
function SayIntentionsAPI:importVAData(vaApiKey, data)
    data = data or {}

    local payload = {
        va_api_key = vaApiKey
    }

    if data.crew_data then
        payload.crew_data = data.crew_data
    end

    if data.dispatcher_data then
        payload.dispatcher_data = data.dispatcher_data
    end

    if data.copilot_data then
        payload.copilot_data = data.copilot_data
    end

    if data.skyops_data then
        payload.skyops_data = data.skyops_data
    end

    -- Convert payload to JSON string
    local payloadStr = "{"
    local first = true
    for key, value in pairs(payload) do
        if not first then payloadStr = payloadStr .. "," end
        payloadStr = payloadStr .. '"' .. key .. '":"' .. value .. '"'
        first = false
    end
    payloadStr = payloadStr .. "}"

    local params = {
        payload = payloadStr
    }

    return self:_request("importVAData", params, "POST")
end

-- ============================================================================
-- Convenience Methods
-- ============================================================================

--- Make pilot say something on COM1
function SayIntentionsAPI:pilotSayCOM1(message, rephrase)
    return self:sayAs("COM1", message, {rephrase = rephrase and 1 or 0})
end

--- Make pilot say something on COM2
function SayIntentionsAPI:pilotSayCOM2(message, rephrase)
    return self:sayAs("COM2", message, {rephrase = rephrase and 1 or 0})
end

--- Make ATC say something on COM1
function SayIntentionsAPI:atcSayCOM1(message, rephrase)
    return self:sayAs("COM1_IN", message, {rephrase = rephrase and 1 or 0})
end

--- Make ATC say something on COM2
function SayIntentionsAPI:atcSayCOM2(message, rephrase)
    return self:sayAs("COM2_IN", message, {rephrase = rephrase and 1 or 0})
end

--- Make copilot say something
function SayIntentionsAPI:copilotSay(message, rephrase)
    return self:sayAs("INTERCOM1_IN", message, {rephrase = rephrase and 1 or 0})
end

--- Make cabin crew say something
function SayIntentionsAPI:crewSay(message, rephrase)
    return self:sayAs("INTERCOM2_IN", message, {rephrase = rephrase and 1 or 0})
end

--- Send ACARS message
function SayIntentionsAPI:sendACARSMessage(message, from, responseCode, messageType)
    local options = {
        from = from,
        response_code = responseCode,
        message_type = messageType or "cpdlc"
    }
    return self:sayAs("ACARS_IN", message, options)
end

--- Get weather for single airport with comms
function SayIntentionsAPI:getAirportWeather(icao)
    return self:getWX(icao, true)
end

--- Get weather for multiple airports
function SayIntentionsAPI:getMultipleAirportWeather(icaoList)
    local icaoString = table.concat(icaoList, ",")
    return self:getWX(icaoString, false)
end

--- Set COM1 active frequency
function SayIntentionsAPI:setCOM1Active(freq)
    return self:setFreq(freq, 1, "active")
end

--- Set COM1 standby frequency
function SayIntentionsAPI:setCOM1Standby(freq)
    return self:setFreq(freq, 1, "standby")
end

--- Set COM2 active frequency
function SayIntentionsAPI:setCOM2Active(freq)
    return self:setFreq(freq, 2, "active")
end

--- Set COM2 standby frequency
function SayIntentionsAPI:setCOM2Standby(freq)
    return self:setFreq(freq, 2, "standby")
end

--- Pause ATC simulation
function SayIntentionsAPI:pause()
    return self:setPause(true)
end

--- Resume ATC simulation
function SayIntentionsAPI:resume()
    return self:setPause(false)
end

-- ============================================================================
-- Return Module
-- ============================================================================

return SayIntentionsAPI
