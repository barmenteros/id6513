//+------------------------------------------------------------------+
//|                                              TimeUtils.mqh      |
//|                         Copyright © 2025, barmenteros FX        |
//|                                  https://barmenteros.com        |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, barmenteros FX"
#property link      "https://barmenteros.com"

#include "DebugUtils.mqh"

//+------------------------------------------------------------------+
//| Check if within trading hours                                   |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
    // If time restrictions are disabled, always allow trading
    if(!EnableTimeRestrictions) {
        return true;
    }

    // Get current broker time
    datetime currentTime = TimeCurrent();
    MqlDateTime timeStruct;
    TimeToStruct(currentTime, timeStruct);

    int currentHour = timeStruct.hour;

    // Validate input parameters
    if(TradingStartHour < 0 || TradingStartHour > 23 ||
            TradingEndHour < 0 || TradingEndHour > 23) {
        LOG_DEBUG("Time Restrictions: Invalid hour parameters - Start: " + string(TradingStartHour) +
                  " | End: " + string(TradingEndHour));
        return true; // Default to allowing trading if invalid parameters
    }

    bool withinHours = false;

    // Handle normal trading hours (start < end)
    if(TradingStartHour < TradingEndHour) {
        withinHours = (currentHour >= TradingStartHour && currentHour < TradingEndHour);
    }
    // Handle overnight trading hours (start > end, e.g., 22:00 to 06:00)
    else if(TradingStartHour > TradingEndHour) {
        withinHours = (currentHour >= TradingStartHour || currentHour < TradingEndHour);
    }
    // Handle 24-hour trading (start == end)
    else {
        withinHours = true; // 24-hour trading when start equals end
    }

    // Log time restriction status periodically (every hour to avoid spam)
    static datetime lastTimeLog = 0;
    static int lastLoggedHour = -1;

    if(currentHour != lastLoggedHour) {
        LOG_DEBUG("Trading time status: " + TimeToString(currentTime, TIME_MINUTES) +
                  " | Window: " + string(TradingStartHour) + ":00-" + string(TradingEndHour) + ":00 | " + (withinHours ? "ALLOWED" : "BLOCKED") +
                  " | Restrictions: " + (EnableTimeRestrictions ? "ENABLED" : "DISABLED"));
        lastLoggedHour = currentHour;
    }

    return withinHours;
}
//+------------------------------------------------------------------+
