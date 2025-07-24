//+------------------------------------------------------------------+
//|                                         MartingaleManager.mqh   |
//|                         Copyright © 2025, barmenteros FX        |
//|                                  https://barmenteros.com        |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, barmenteros FX"
#property link      "https://barmenteros.com"

#include "..\Utils\DebugUtils.mqh"

//+------------------------------------------------------------------+
//| Martingale Manager Class - Dynamic MOD-Tracking Implementation  |
//+------------------------------------------------------------------+
class CMartingaleManager {
private:
    static double GetLevelSpacing(int level);

public:
    CMartingaleManager() {}

    // Core Martingale calculation methods - Dynamic MOD-Tracking
    static double CalculateNextEntryPrice(double modReferencePrice, double atrValue, int currentLevel, int direction);
    static bool ShouldTriggerNextEntry(double currentPrice, double modReferencePrice, double atrValue, int currentLevel, int direction);

    // Utility methods
    static bool IsMaxLevelReached(int currentLevel);
    static int GetMaxLevels();
    static double CalculateRequiredDistance(int nextLevel, double atrValue, string context = "", double targetPrice = 0.0);
    static double CalculateVolumeWeightedAverage(double currentAverage, double currentVolume, double newPrice, double newVolume);
    static bool ValidateLevel(int level);
    static bool ValidateDirection(int direction);
    static double CalculateCumulativeDistance(int level, double atrValue);
};

//+------------------------------------------------------------------+
//| Get ATR spacing for specific level (Progressive spacing)        |
//+------------------------------------------------------------------+
double CMartingaleManager::GetLevelSpacing(int level)
{
    // Progressive ATR spacing based on level
    if(level <= 3) return 1.0;      // Levels 1-3: 1 ATR
    else if(level <= 6) return 2.0; // Levels 4-6: 2 ATR
    else return 3.0;                // Levels 7-8: 3 ATR
}

//+------------------------------------------------------------------+
//| Calculate cumulative distance from MOD reference for given level|
//+------------------------------------------------------------------+
double CMartingaleManager::CalculateCumulativeDistance(int level, double atrValue)
{
    if(level <= 1) return 0.0; // Level 1 is at MOD reference

    double cumulativeDistance = 0.0;

    // Calculate cumulative distance based on progressive spacing
    for(int i = 2; i <= level; i++) {
        cumulativeDistance += GetLevelSpacing(i) * atrValue;
    }

    return cumulativeDistance;
}

//+------------------------------------------------------------------+
//| Calculate next entry price using dynamic MOD reference          |
//+------------------------------------------------------------------+
double CMartingaleManager::CalculateNextEntryPrice(double modReferencePrice, double atrValue, int currentLevel, int direction)
{
    // Validate inputs
    if(!ValidateLevel(currentLevel) || !ValidateDirection(direction)) {
        LOG_DEBUG("MARTINGALE ERROR: Invalid level (" + string(currentLevel) + ") or direction (" + string(direction) + ")");
        return 0.0;
    }

    if(modReferencePrice <= 0.0 || atrValue <= 0.0) {
        LOG_DEBUG("MARTINGALE ERROR: Invalid MOD reference (" + DoubleToString(modReferencePrice, _Digits) +
                  ") or ATR (" + DoubleToString(atrValue, _Digits) + ")");
        return 0.0;
    }

    if(IsMaxLevelReached(currentLevel)) {
        LOG_DEBUG("MARTINGALE WARNING: Maximum level reached (" + string(currentLevel) + ")");
        return 0.0;
    }

    int nextLevel = currentLevel + 1;

    // Calculate cumulative distance from MOD reference for the next level
    double cumulativeDistance = CalculateCumulativeDistance(nextLevel, atrValue);

    // Apply ATR multiplier from input parameter
    cumulativeDistance *= ATRMultiplier;

    // Calculate entry price based on direction
    double entryPrice = 0.0;

    if(direction == 1) {
        // Long position: next entry is BELOW MOD reference
        entryPrice = modReferencePrice - cumulativeDistance;
    }
    else {
        // Short position: next entry is ABOVE MOD reference
        entryPrice = modReferencePrice + cumulativeDistance;
    }

    // Log calculation details
/*
    LOG_DEBUG("Martingale calculation: Level " + string(currentLevel) + ">" + string(nextLevel) +
              " | MOD: " + DoubleToString(modReferencePrice, _Digits) +
              " | Entry: " + DoubleToString(entryPrice, _Digits) +
              " | Distance: " + DoubleToString(cumulativeDistance, _Digits) +
              " (" + DoubleToString(GetLevelSpacing(nextLevel), 1) + " ATR)");
*/

    return entryPrice;
}

//+------------------------------------------------------------------+
//| Check if should trigger next Martingale entry                   |
//+------------------------------------------------------------------+
bool CMartingaleManager::ShouldTriggerNextEntry(double currentPrice, double modReferencePrice, double atrValue, int currentLevel, int direction)
{
    // Validate inputs
    if(!ValidateLevel(currentLevel) || !ValidateDirection(direction)) {
        return false;
    }

    if(modReferencePrice <= 0.0 || atrValue <= 0.0 || currentPrice <= 0.0) {
        return false;
    }

    if(IsMaxLevelReached(currentLevel)) {
        return false; // Already at maximum level
    }

    // Calculate the target price for the next entry
    double targetPrice = CalculateNextEntryPrice(modReferencePrice, atrValue, currentLevel, direction);

    if(targetPrice <= 0.0) {
        return false; // Invalid target price
    }

    // Check if current price has reached the target entry level
    bool shouldTrigger = false;

    if(direction == 1) {
        // Long position: trigger when price drops to or below target
        shouldTrigger = (currentPrice <= targetPrice);
    }
    else {
        // Short position: trigger when price rises to or above target
        shouldTrigger = (currentPrice >= targetPrice);
    }

    // Log trigger evaluation
    if(shouldTrigger) {
        LOG_DEBUG("Martingale trigger: Level " + string(currentLevel) + ">" + string(currentLevel + 1) +
                  " | Price: " + DoubleToString(currentPrice, _Digits) +
                  " | Target: " + DoubleToString(targetPrice, _Digits) +
                  " | MOD: " + DoubleToString(modReferencePrice, _Digits) +
                  " | " + (direction == 1 ? "LONG" : "SHORT"));
    }

    return shouldTrigger;
}

//+------------------------------------------------------------------+
//| Check if maximum level reached                                   |
//+------------------------------------------------------------------+
bool CMartingaleManager::IsMaxLevelReached(int currentLevel)
{
    return (currentLevel >= MaxEntryLevels);
}

//+------------------------------------------------------------------+
//| Get maximum allowed levels                                       |
//+------------------------------------------------------------------+
int CMartingaleManager::GetMaxLevels()
{
    return MaxEntryLevels;
}

//+------------------------------------------------------------------+
//| Calculate required distance for next level                      |
//+------------------------------------------------------------------+
double CMartingaleManager::CalculateRequiredDistance(int nextLevel, double atrValue, string context, double targetPrice)
{
    if(nextLevel <= 1) return 0.0;

    double distance = CalculateCumulativeDistance(nextLevel, atrValue) * ATRMultiplier;

    if(context != "") {
        LOG_DEBUG("Distance calculation for " + context + " - Level " + string(nextLevel) +
                  ": " + DoubleToString(distance, _Digits));
    }

    return distance;
}

//+------------------------------------------------------------------+
//| Calculate volume-weighted average                                |
//+------------------------------------------------------------------+
double CMartingaleManager::CalculateVolumeWeightedAverage(double currentAverage, double currentVolume, double newPrice, double newVolume)
{
    if(currentVolume <= 0.0) return newPrice;

    double totalVolume = currentVolume + newVolume;
    double weightedAverage = ((currentAverage * currentVolume) + (newPrice * newVolume)) / totalVolume;

    LOG_DEBUG("Volume-Weighted Average: " + DoubleToString(currentAverage, _Digits) +
              " (" + DoubleToString(currentVolume, 2) + ") + " +
              DoubleToString(newPrice, _Digits) + " (" + DoubleToString(newVolume, 2) +
              ") = " + DoubleToString(weightedAverage, _Digits));

    return weightedAverage;
}

//+------------------------------------------------------------------+
//| Validate level parameter                                         |
//+------------------------------------------------------------------+
bool CMartingaleManager::ValidateLevel(int level)
{
    return (level >= 0 && level <= MaxEntryLevels);
}

//+------------------------------------------------------------------+
//| Validate direction parameter                                     |
//+------------------------------------------------------------------+
bool CMartingaleManager::ValidateDirection(int direction)
{
    return (direction == 1 || direction == -1);
}
//+------------------------------------------------------------------+
