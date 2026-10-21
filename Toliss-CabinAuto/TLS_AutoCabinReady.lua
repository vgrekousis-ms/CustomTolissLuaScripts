if (PLANE_AUTHOR ~= "Gliding Kiwi" and PLANE_AUTHOR ~= "GlidingKiwi") then
    return
else
    -- DATAREFS
    dataref("TOC_PAX_NUM", "AirbusFBW/NoPax", "readonly")
    dataref("TOC_BEACON_SW", "AirbusFBW/OHPLightSwitches", "readonly", 0)
    dataref("TOC_ONGND", "sim/flightmodel/failures/onground_any", "readonly")
    dataref("TOC_GSPD", "sim/cockpit2/gauges/indicators/ground_speed_kt", "readonly")
	dataref("TOC_ECAM_PHASE", "AirbusFBW/ECAMFlightPhase", "readonly")
    dataref("TOC_CKPT_DOOR", "ckpt/door", "writable")

    -- Optional / future:
    -- dataref("TOC_ENG1_N1", "sim/flightmodel/engine/ENGN_N1_[0]", "readonly")
    -- dataref("TOC_ENG2_N1", "sim/flightmodel/engine/ENGN_N1_[1]", "readonly")
    -- dataref("TOC_DOOR_ARRAY", "AirbusFBW/PaxDoorArray", "readonly")

    ------------------------------------------------------------------------
    -- DEPARTURE CABIN READY LOGIC (STATE MACHINE)
    ------------------------------------------------------------------------

    TOC_CAB_STATE = 0      -- 0 = IDLE, 1 = ARMED, 2 = COUNTDOWN, 3 = DONE
    TOC_CAB_TIMER_START = 0
    TOC_CAB_TIMER_E = 0

    function TOC_is_cockpit_door_open()
        -- Check if cockpit door is open (>0 = open, 0 = closed)
        return TOC_CKPT_DOOR > 0
    end

    function TOC_toggle_cockpit_door()
        -- Toggle cockpit door state
        if TOC_is_cockpit_door_open() then
            TOC_CKPT_DOOR = 0
            -- Close
        else
            TOC_CKPT_DOOR = 80
            -- Open
        end
    end

    -- Helper: compute cabin delay based on pax
    function TOC_compute_cabin_delay()
        local base = 240
        local t = base

        if TOC_PAX_NUM < 50 then
            t = base
        elseif TOC_PAX_NUM >= 50 and TOC_PAX_NUM < 200 then
            t = base + 0.8 * (TOC_PAX_NUM - 50)
        else
            t = 360 + 0.5 * (TOC_PAX_NUM - 200)
        end

        return t
    end

    -- Helper: engines considered running (placeholder, can refine)
    function TOC_engines_running()
        -- If you want to be strict, uncomment and use N1 thresholds:
        -- return (TOC_ENG1_N1 > 40 and TOC_ENG2_N1 > 40)
        -- For now, assume beacon ON implies engines starting/started
        return true
    end
	
	function TOC_ECAM_PreTakeoffPhase()
		return TOC_ECAM_PHASE == 2
	end

    -- ARM logic: prepare cabin-ready sequence
    function TOC_CAB_ARM()
        -- Only arm if idle
        if TOC_CAB_STATE ~= 0 then return end

        -- Conditions to arm:
        -- Beacon ON, on ground, engines running
        if TOC_BEACON_SW == 1 and TOC_ONGND == 1 and TOC_engines_running() and TOC_ECAM_PreTakeoffPhase() then
            TOC_CAB_STATE = 1
        end
    end

    -- START logic: begin countdown once taxi / pre-takeoff phase
    function TOC_CAB_START()
        if TOC_CAB_STATE ~= 1 then return end

        -- Still on ground, low speed (e.g. < 30 kt)
        if TOC_ONGND == 1 and TOC_GSPD < 30 then
            TOC_CAB_TIMER_START = get("sim/time/total_flight_time_sec")
            local delay = TOC_compute_cabin_delay()
            TOC_CAB_TIMER_E = TOC_CAB_TIMER_START + delay
            TOC_CAB_STATE = 2
        end
    end

    -- UPDATE logic: check if time to trigger cabin-ready
    function TOC_CAB_UPDATE()
        if TOC_CAB_STATE ~= 2 then return end

        local now = get("sim/time/total_flight_time_sec")

        -- If we somehow left ground or are very fast, inhibit
        if TOC_ONGND == 0 or TOC_GSPD >= 80 then
            TOC_CAB_STATE = 3 -- mark as done/inhibited for this leg
            return
        end

        if now >= TOC_CAB_TIMER_E then
            command_once("AirbusFBW/CheckCabin")
            TOC_CAB_STATE = 3
        end
    end

    -- RESET logic: prepare for next leg
    function TOC_CAB_RESET()
        -- Reset only when on ground, beacon OFF, and sequence done
        if TOC_ONGND == 1 and TOC_BEACON_SW == 0 then
            TOC_CAB_STATE = 0
            TOC_CAB_TIMER_START = 0
            TOC_CAB_TIMER_E = 0
        end
    end

    ------------------------------------------------------------------------
    -- DESCENT / ARRIVAL CABIN CHECK (simplified, deterministic)
    ------------------------------------------------------------------------

    TOD_CAB_STATE = 0      -- 0 = IDLE, 1 = ARMED, 2 = COUNTDOWN
    TOD_CAB_TIMER_START = 0
    TOD_CAB_TIMER_E = 0

    dataref("TOD_VS_FPM", "sim/flightmodel/position/vh_ind_fpm", "readonly")
    dataref("TOD_GEAR_LEVER", "AirbusFBW/GearLever", "readonly")
    dataref("TOD_NOSE_GEAR_POS", "AirbusFBW/NoseGearPos", "readonly")
    dataref("TOD_SLAT_POS", "AirbusFBW/SlatPositionLWing", "readonly")

    function TOD_CAB_ARM()
        if TOD_CAB_STATE ~= 0 then return end

        -- Arm during descent: VS > 600 fpm OR gear down
        if TOD_VS_FPM > 600 or TOD_GEAR_LEVER == 0 then
            TOD_CAB_STATE = 1
        end
    end

    function TOD_CAB_START()
        if TOD_CAB_STATE ~= 1 then return end

        -- Conditions near landing: nose gear almost down, slats out, VS < 200 fpm
        if TOD_NOSE_GEAR_POS >= 0.9 and TOD_SLAT_POS > 0 and TOD_VS_FPM < 200 then
            TOD_CAB_TIMER_START = get("sim/time/total_flight_time_sec")
            TOD_CAB_TIMER_E = TOD_CAB_TIMER_START + 5
            TOD_CAB_STATE = 2
        end
    end

    function TOD_CAB_UPDATE()
        if TOD_CAB_STATE ~= 2 then return end

        local now = get("sim/time/total_flight_time_sec")

        if now >= TOD_CAB_TIMER_E then
            command_once("AirbusFBW/CheckCabin")
            TOD_CAB_STATE = 0
        end
    end

    add_macro("TOC Cabin Crew  - Toggle Cockpit Door", "TOC_toggle_cockpit_door()")

    create_command("TOCCabinCrew/Toggle_cockpit_door", "Toggle Cockpit Door", "TOC_toggle_cockpit_door()", "", "")
    ------------------------------------------------------------------------
    -- SCHEDULING
    ------------------------------------------------------------------------

    do_often("TOC_CAB_ARM()")
    do_often("TOC_CAB_START()")
    do_often("TOC_CAB_UPDATE()")
    do_often("TOC_CAB_RESET()")

    do_often("TOD_CAB_ARM()")
    do_often("TOD_CAB_START()")
    do_often("TOD_CAB_UPDATE()")
end
