//+------------------------------------------------------------------+
//|                                      PrimaryTradingSystem.mqh  |
//|                         Copyright © 2025, barmenteros FX        |
//|                                  https://barmenteros.com        |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, barmenteros FX"
#property link      "https://barmenteros.com"

#include "..\Utils\DebugUtils.mqh"

//+------------------------------------------------------------------+
//| Primary Trading System Class                                    |
//+------------------------------------------------------------------+
class CPrimaryTradingSystem {
private:
    double m_averageEntryPrice;
    int m_currentLevel;
    int m_direction; // 1 = Long, -1 = Short, 0 = None
    bool m_exitLevel1Executed;
    bool m_exitLevel2Executed;
    int m_lastDirection; // Track previous direction for change detection
    double m_lastMODLevel;         // Track previous MOD level for pullback detection
    double m_lastPrice;            // Track previous price for movement detection
    bool m_awayFromMOD;            // Flag indicating price moved away from MOD
    bool m_readyForPullbackEntry;  // Flag indicating pullback conditions are met
    double m_initialLotSize;           // Size of the initial entry
    double m_initialLotRemainingVolume; // Remaining volume from initial entry
    double m_initialEntryPrice;        // Entry price of initial position
    bool m_initialProfitTargetReached; // Flag if 50% profit target was hit
    bool m_hasInitialPosition;         // Flag indicating if initial position exists
    bool m_entryConditionsPreviouslySatisfied;  // Track previous entry conditions state for transition detection
    double m_lowestEntryPrice;     // For long positions - tracks lowest entry price
    double m_highestEntryPrice;    // For short positions - tracks highest entry price
    double m_modReferencePrice;    // Dynamic MOD reference for Martingale calculations

public:
    CPrimaryTradingSystem() : m_averageEntryPrice(0), m_currentLevel(0), m_direction(0),
        m_exitLevel1Executed(false), m_exitLevel2Executed(false),
        m_lastDirection(0), m_lastMODLevel(0), m_lastPrice(0),
        m_awayFromMOD(false), m_readyForPullbackEntry(false),
        m_entryConditionsPreviouslySatisfied(false),
        m_lowestEntryPrice(0.0), m_highestEntryPrice(0.0),
        m_modReferencePrice(0.0) {}

    // Core trading logic
    bool ShouldOpenPosition(int signalDirection);
    bool ShouldAddToPosition(double currentPrice, double atrValue);
    bool ShouldExitPosition(double currentPrice, double atrValue, double previousPrice);
    bool RecoverPositionState();
    void UpdateAveragePrice(double price, double lots);
    bool UpdatePrimaryDirection();
    bool DetectMODPullback(double currentPrice, double currentMOD);
    bool IsReadyForInitialEntry(double currentPrice, double currentMOD);
    void ResetPullbackTracking();
    void Reset();
    void ReclassifyAfterPartialExit(double currentMOD); // NEW: Dynamic MOD tracking

    // Getters and setters
    int GetLastDirection() const
    {
        return m_lastDirection;
    }
    void SetDirection(int direction)
    {
        m_direction = direction;
    }
    int GetDirection() const
    {
        return m_direction;
    }
    int GetCurrentLevel() const
    {
        return m_currentLevel;
    }
    double GetAverageEntryPrice() const
    {
        return m_averageEntryPrice;
    }
    double GetInitialEntryPrice() const
    {
        return m_initialEntryPrice;
    }
    double GetMODReferencePrice() const
    {
        return m_modReferencePrice;
    }
    double GetMostExtremeEntryPrice() const;
    double GetLowestEntryPrice() const
    {
        return m_lowestEntryPrice;
    }
    double GetHighestEntryPrice() const
    {
        return m_highestEntryPrice;
    }
    void SetLastMODLevel(double modLevel)
    {
        m_lastMODLevel = modLevel;
    }

    // Exit level tracking
    bool IsExitLevel1Executed() const
    {
        return m_exitLevel1Executed;
    }
    bool IsExitLevel2Executed() const
    {
        return m_exitLevel2Executed;
    }
    void SetExitLevel1Executed(bool executed)
    {
        m_exitLevel1Executed = executed;
    }
    void SetExitLevel2Executed(bool executed)
    {
        m_exitLevel2Executed = executed;
    }
    void ResetExitLevels();

    // Initial position tracking
    bool HasInitialPosition() const
    {
        return m_hasInitialPosition;
    }
    bool IsInitialProfitTargetReached() const
    {
        return m_initialProfitTargetReached;
    }
    double GetInitialLotSize() const
    {
        return m_initialLotSize;
    }
    double GetInitialLotRemainingVolume() const
    {
        return m_initialLotRemainingVolume;
    }
    void UpdateRemainingVolumeAfterPartialClosure(double remainingVolume);
    void SetAverageEntryPrice(double price)
    {
        m_averageEntryPrice = price;
    }
    bool IsReclassificationNeeded() const;
    void SetInitialProfitTargetReached(bool reached);

    // Profit calculations
    double CalculateInitialLotProfit(double currentPrice) const;
    double CalculateInitialLotClosureProfit(double volumeToBeClosed, double closurePrice) const;
    double Calculate50PercentProfitTarget() const;
    bool ShouldTriggerInitial50PercentExit(double currentPrice, double previousPrice) const;
};

//+------------------------------------------------------------------+
//| Reset system state                                               |
//+------------------------------------------------------------------+
void CPrimaryTradingSystem::Reset()
{
    m_averageEntryPrice = 0;
    m_currentLevel = 0;
    m_direction = 0;
    m_lastDirection = 0;
    m_exitLevel1Executed = false;
    m_exitLevel2Executed = false;

    // Reset MOD pullback tracking
    m_lastMODLevel = 0;
    m_lastPrice = 0;
    m_awayFromMOD = false;
    m_readyForPullbackEntry = false;

    // Reset initial lot tracking
    m_initialLotSize = 0.0;
    m_initialLotRemainingVolume = 0.0;
    m_initialEntryPrice = 0.0;
    m_initialProfitTargetReached = false;
    m_hasInitialPosition = false;

    // Reset entry condition tracking for new cycle
    m_entryConditionsPreviouslySatisfied = false;

    // Reset extreme price tracking
    m_lowestEntryPrice = 0.0;
    m_highestEntryPrice = 0.0;

    // Reset MOD reference
    m_modReferencePrice = 0.0;

    LOG_DEBUG("Primary System: Complete reset");
    LOG_DEBUG("  Position tracking: CLEARED");
    LOG_DEBUG("  Direction tracking: RESET");
    LOG_DEBUG("  MOD pullback detection: RESET");
    LOG_DEBUG("  Exit levels: RESET");
    LOG_DEBUG("  Extreme price tracking: RESET");
    LOG_DEBUG("  MOD reference: RESET");
    LOG_DEBUG("  System ready for: NEW ENTRY CYCLE");
}

//+------------------------------------------------------------------+
//| Reclassify position after partial exit for dynamic MOD tracking |
//+------------------------------------------------------------------+
void CPrimaryTradingSystem::ReclassifyAfterPartialExit(double currentMOD)
{
    LOG_DEBUG("=== POSITION RECLASSIFICATION FOR DYNAMIC MOD TRACKING ===");
    LOG_DEBUG("Previous MOD Reference: " + DoubleToString(m_modReferencePrice, _Digits));
    LOG_DEBUG("Current MOD Level: " + DoubleToString(currentMOD, _Digits));
    LOG_DEBUG("Previous Current Level: " + string(m_currentLevel));
    LOG_DEBUG("Previous Average Entry Price: " + DoubleToString(m_averageEntryPrice, _Digits));

    // Validate current MOD value
    if(currentMOD <= 0.0) {
        LOG_DEBUG("ERROR: Invalid MOD value for reclassification: " + DoubleToString(currentMOD, _Digits));
        return;
    }

    // Store previous values for logging
    double previousMODRef = m_modReferencePrice;
    int previousLevel = m_currentLevel;

    // CORE RECLASSIFICATION LOGIC
    // 1. Update MOD reference to current MOD position
    m_modReferencePrice = currentMOD;

    // 2. Reclassify remaining position as 1st Martingale entry
    m_currentLevel = 1;

    // 3. Update position tracking for new sequence
    // The remaining position is now considered the initial entry from the new MOD
    m_initialEntryPrice = currentMOD;  // New initial entry price is current MOD

    // 4. Update extreme price tracking for new sequence
    if(m_direction == 1) {
        // Long position: MOD becomes the new lowest entry price
        m_lowestEntryPrice = currentMOD;
        m_highestEntryPrice = 0.0;  // Reset unused tracking
    }
    else {
        // Short position: MOD becomes the new highest entry price
        m_highestEntryPrice = currentMOD;
        m_lowestEntryPrice = 0.0;   // Reset unused tracking
    }

    // 5. Reset exit levels for new sequence
    ResetExitLevels();

    // 6. Reset initial position tracking since we're starting fresh sequence
    m_hasInitialPosition = false;           // No longer tracking original initial position
    m_initialProfitTargetReached = false;   // Reset profit target tracking

    // 7. Reset initial lot tracking (remaining volume becomes new base)
    // Note: Actual remaining volume will be updated by trade executor
    // We don't modify m_initialLotSize or m_initialLotRemainingVolume here
    // as they should reflect the actual remaining position volume

    LOG_DEBUG("=== RECLASSIFICATION COMPLETE ===");
    LOG_DEBUG("New MOD Reference: " + DoubleToString(m_modReferencePrice, _Digits));
    LOG_DEBUG("New Current Level: " + string(m_currentLevel));
    LOG_DEBUG("New Initial Entry Price: " + DoubleToString(m_initialEntryPrice, _Digits));
    LOG_DEBUG("Available Martingale Slots: " + string(MaxEntryLevels - m_currentLevel));
    LOG_DEBUG("Exit levels reset for new sequence");
    LOG_DEBUG("Extreme price tracking updated for direction: " + (m_direction == 1 ? "LONG" : "SHORT"));
    LOG_DEBUG("System ready for dynamic Martingale progression from new MOD");

    // Log the transformation summary
    LOG_DEBUG("TRANSFORMATION SUMMARY:");
    LOG_DEBUG("  MOD Reference: " + DoubleToString(previousMODRef, _Digits) + " → " + DoubleToString(m_modReferencePrice, _Digits));
    LOG_DEBUG("  Martingale Level: " + string(previousLevel) + " → " + string(m_currentLevel));
    LOG_DEBUG("  Available Levels: " + string(MaxEntryLevels - previousLevel) + " → " + string(MaxEntryLevels - m_currentLevel));
    LOG_DEBUG("  Remaining position now serves as foundation for new Martingale sequence");
}

//+------------------------------------------------------------------+
//| Get most extreme entry price for Martingale calculations        |
//+------------------------------------------------------------------+
double CPrimaryTradingSystem::GetMostExtremeEntryPrice() const
{
    // For dynamic MOD tracking, use MOD reference if available
    if(m_modReferencePrice > 0.0) {
        return m_modReferencePrice;
    }

    // Fallback to traditional extreme price tracking
    if(m_direction == 1) return m_lowestEntryPrice;   // Long: use lowest
    else return m_highestEntryPrice;                  // Short: use highest
}

//+------------------------------------------------------------------+
//| Reset exit levels                                                |
//+------------------------------------------------------------------+
void CPrimaryTradingSystem::ResetExitLevels()
{
    m_exitLevel1Executed = false;
    m_exitLevel2Executed = false;
    LOG_DEBUG("Primary System: Exit levels reset");
}

//+------------------------------------------------------------------+
//| Update primary direction                                         |
//+------------------------------------------------------------------+
bool CPrimaryTradingSystem::UpdatePrimaryDirection()
{
    double primaryMidline;
    int primaryColor;

// Get current primary signal from completed bar (position 1)
    if(!g_indicatorManager.GetPrimarySignal(primaryMidline, primaryColor)) {
        LOG_DEBUG("Primary Direction: Failed to read indicator signal - maintaining last direction");
        return false; // Maintain last known direction on read failure
    }

// Validate color index (robust edge case handling)
    if(primaryColor != 0 && primaryColor != 1) {
        LOG_DEBUG("Primary Direction: Invalid color index (" + string(primaryColor) +
                  ") - maintaining last direction");
        return false; // Maintain last known direction on invalid data
    }

// Convert color to direction signal
    int newDirection = (primaryColor == 0) ? 1 : -1; // 0=Blue=Long, 1=Magenta=Short

// Check for direction change
    bool directionChanged = (m_lastDirection != 0 && m_lastDirection != newDirection);

    if(directionChanged) {
        LOG_DEBUG("=== PRIMARY DIRECTION CHANGE DETECTED ===");
        LOG_DEBUG("Previous Direction: " + (m_lastDirection == 1 ? "LONG" : "SHORT"));
        LOG_DEBUG("New Direction: " + (newDirection == 1 ? "LONG" : "SHORT"));
        LOG_DEBUG("Midline Value: " + DoubleToString(primaryMidline, _Digits));

        // Handle existing positions when direction changes
        if(g_tradeExecutor.IsPrimaryPositionOpen()) {
            LOG_DEBUG("Primary Direction: Existing positions detected - continuing Martingale management");
            LOG_DEBUG("Primary Direction: Exit levels remain active for existing positions");
            // Note: We do NOT reset exit levels here - they continue for existing positions
        }

        LOG_DEBUG("Primary Direction: Updated for future entries");

        // Properly maintain state transition
        m_lastDirection = m_direction;  // Store current as previous
        m_direction = newDirection;     // Update to new direction
    }
    else {
        // No change detected - just update current direction
        m_direction = newDirection;
    }

// Primary direction status now included in consolidated STATUS UPDATE - remove individual logging
// This information is captured in the main OnTick() consolidated status update every 5 minutes

    return directionChanged;
}

//+------------------------------------------------------------------+
//| Enhanced ShouldOpenPosition with intra-bar MOD detection        |
//+------------------------------------------------------------------+
bool CPrimaryTradingSystem::ShouldOpenPosition(int signalDirection)
{
    // Don't open if we already have a position in any direction
    if(m_direction != 0 && m_currentLevel > 0) {
        return false;
    }

    // Don't open if no clear signal
    if(signalDirection == 0) {
        return false;
    }

    // Get current real-time price for intra-bar execution
    double currentPrice = (signalDirection == 1) ?
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                          SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Get current MOD level
    double currentMOD = 0.0;
    // Note: In the actual implementation, this should get MOD from indicator manager
    // For now, we'll rely on the MOD value passed from ProcessPrimarySystem

    // Check entry conditions using intra-bar detection
    bool modPullbackDetected = DetectMODPullback(currentPrice, m_lastMODLevel);
    bool readyForEntry = IsReadyForInitialEntry(currentPrice, m_lastMODLevel);

    // Entry decision based on pullback or immediate MOD touch
    bool shouldEnter = modPullbackDetected || readyForEntry;

    if(shouldEnter) {
        LOG_DEBUG("=== ENTRY CONDITIONS SATISFIED ===");
        LOG_DEBUG("Signal Direction: " + (signalDirection == 1 ? "LONG" : "SHORT"));
        LOG_DEBUG("Entry Type: " + (modPullbackDetected ? "MOD PULLBACK" : "MOD TOUCH"));
        LOG_DEBUG("Current Price: " + DoubleToString(currentPrice, _Digits));
        LOG_DEBUG("MOD Level: " + DoubleToString(m_lastMODLevel, _Digits));
        LOG_DEBUG("=== READY FOR POSITION OPENING ===");
    }

    return shouldEnter;
}

//+------------------------------------------------------------------+
//| Check if should add to position (Dynamic MOD-tracking Martingale)|
//+------------------------------------------------------------------+
bool CPrimaryTradingSystem::ShouldAddToPosition(double currentPrice, double atrValue)
{
    // Don't add if no position exists
    if(m_direction == 0 || m_currentLevel <= 0) {
        return false;
    }

    // Don't add if already at maximum level
    if(CMartingaleManager::IsMaxLevelReached(m_currentLevel)) {
        return false;
    }

    // Get current MOD reference for dynamic tracking
    double modReference = GetMODReferencePrice();
    if(modReference <= 0.0) {
        // Fallback to current MOD if no reference set
        modReference = g_indicatorManager.GetPrimaryMOD();
        if(modReference <= 0.0) {
            LOG_DEBUG("Martingale Add: No valid MOD reference available");
            return false;
        }
    }

    // Check if price has reached next Martingale level
    bool shouldTrigger = CMartingaleManager::ShouldTriggerNextEntry(
                             currentPrice,
                             modReference,
                             atrValue,
                             m_currentLevel,
                             m_direction
                         );

    if(shouldTrigger) {
        LOG_DEBUG("=== MARTINGALE ADDITION TRIGGERED ===");
        LOG_DEBUG("Current Level: " + string(m_currentLevel) + " → " + string(m_currentLevel + 1));
        LOG_DEBUG("MOD Reference: " + DoubleToString(modReference, _Digits));
        LOG_DEBUG("Current Price: " + DoubleToString(currentPrice, _Digits));
        LOG_DEBUG("Direction: " + (m_direction == 1 ? "LONG" : "SHORT"));
    }

    return shouldTrigger;
}

//+------------------------------------------------------------------+
//| Enhanced exit position check with proper crossover detection    |
//+------------------------------------------------------------------+
bool CPrimaryTradingSystem::ShouldExitPosition(double currentPrice, double atrValue, double previousPrice)
{
    if(m_averageEntryPrice <= 0.0 || atrValue <= 0.0 || m_currentLevel <= 0) {
        return false;
    }

    // Check initial 50% profit target first (if applicable)
    if(m_hasInitialPosition && !m_initialProfitTargetReached && m_initialLotRemainingVolume > 0.0) {
        if(ShouldTriggerInitial50PercentExit(currentPrice, previousPrice)) {
            LOG_DEBUG("=== INITIAL 50% EXIT TRIGGERED ===");
            return true;
        }
    }

    // Check ATR-based exit levels
    double exitLevel1Price = 0.0;
    double exitLevel2Price = 0.0;

    if(m_direction == 1) {
        // Long position: exit levels above AEP
        exitLevel1Price = m_averageEntryPrice + (ExitLevel1_ATR * atrValue);
        exitLevel2Price = m_averageEntryPrice + (ExitLevel2_ATR * atrValue);
    }
    else if(m_direction == -1) {
        // Short position: exit levels below AEP
        exitLevel1Price = m_averageEntryPrice - (ExitLevel1_ATR * atrValue);
        exitLevel2Price = m_averageEntryPrice - (ExitLevel2_ATR * atrValue);
    }

    // Check for exit level 1 trigger (crossover detection)
    if(!m_exitLevel1Executed) {
        bool level1Triggered = false;

        if(m_direction == 1) {
            level1Triggered = (currentPrice >= exitLevel1Price && previousPrice < exitLevel1Price);
        }
        else if(m_direction == -1) {
            level1Triggered = (currentPrice <= exitLevel1Price && previousPrice > exitLevel1Price);
        }

        if(level1Triggered) {
            LOG_DEBUG("=== ATR EXIT LEVEL 1 TRIGGERED (AEP-BASED) ===");
            LOG_DEBUG("AEP: " + DoubleToString(m_averageEntryPrice, _Digits));
            LOG_DEBUG("Exit Level 1 (" + DoubleToString(ExitLevel1_ATR, 1) + " ATR): " + DoubleToString(exitLevel1Price, _Digits));
            LOG_DEBUG("Current Price: " + DoubleToString(currentPrice, _Digits));
            LOG_DEBUG("Exit Percentage: " + DoubleToString(ExitLevel1_Percentage, 1) + "%");
            return true;
        }
    }

    // Check for exit level 2 trigger (crossover detection)
    if(!m_exitLevel2Executed) {
        bool level2Triggered = false;

        if(m_direction == 1) {
            level2Triggered = (currentPrice >= exitLevel2Price && previousPrice < exitLevel2Price);
        }
        else if(m_direction == -1) {
            level2Triggered = (currentPrice <= exitLevel2Price && previousPrice > exitLevel2Price);
        }

        if(level2Triggered) {
            LOG_DEBUG("=== ATR EXIT LEVEL 2 TRIGGERED (AEP-BASED) ===");
            LOG_DEBUG("AEP: " + DoubleToString(m_averageEntryPrice, _Digits));
            LOG_DEBUG("Exit Level 2 (" + DoubleToString(ExitLevel2_ATR, 1) + " ATR): " + DoubleToString(exitLevel2Price, _Digits));
            LOG_DEBUG("Current Price: " + DoubleToString(currentPrice, _Digits));
            LOG_DEBUG("Exit Percentage: " + DoubleToString(ExitLevel2_Percentage, 1) + "%");
            return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Recover position state from existing open positions             |
//+------------------------------------------------------------------+
bool CPrimaryTradingSystem::RecoverPositionState()
{
    LOG_DEBUG("=== POSITION STATE RECOVERY ===");

    // Check if primary positions exist
    if(!g_tradeExecutor.IsPrimaryPositionOpen()) {
        LOG_DEBUG("No primary positions found - starting fresh");
        return true;
    }

    // Get position details
    double totalVolume = g_tradeExecutor.GetPrimaryPositionVolume();
    double currentProfit = g_tradeExecutor.GetPrimaryPositionProfit();
    ENUM_POSITION_TYPE positionType = g_tradeExecutor.GetPrimaryPositionType();

    LOG_DEBUG("Existing position found:");
    LOG_DEBUG("  Volume: " + DoubleToString(totalVolume, 2));
    LOG_DEBUG("  Type: " + (positionType == POSITION_TYPE_BUY ? "BUY" : "SELL"));
    LOG_DEBUG("  Profit: $" + DoubleToString(currentProfit, 2));

    // Set direction based on position type
    m_direction = (positionType == POSITION_TYPE_BUY) ? 1 : -1;

    // Estimate level based on volume (this is an approximation)
    double estimatedLevel = MathRound(totalVolume / InitialLotSize);
    m_currentLevel = (int)MathMax(1, estimatedLevel);

    // Set initial position tracking
    m_hasInitialPosition = true;
    m_initialLotSize = InitialLotSize; // Use configured initial size
    m_initialLotRemainingVolume = totalVolume; // Assume all remaining volume is initial

    // Calculate average entry price from current position
    // This is an approximation - actual AEP would need to be calculated from trade history
    double currentPrice = (positionType == POSITION_TYPE_BUY) ?
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    // Estimate AEP based on current profit and volume
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if(tickValue > 0.0 && tickSize > 0.0 && totalVolume > 0.0) {
        double profitPerLot = currentProfit / totalVolume;
        double priceDifference = (profitPerLot * tickSize) / tickValue;

        if(positionType == POSITION_TYPE_BUY) {
            m_averageEntryPrice = currentPrice - priceDifference;
        }
        else {
            m_averageEntryPrice = currentPrice + priceDifference;
        }
    }
    else {
        m_averageEntryPrice = currentPrice; // Fallback
    }

    // Set MOD reference to current MOD for dynamic tracking
    double currentMOD = g_indicatorManager.GetPrimaryMOD();
    if(currentMOD > 0.0) {
        m_modReferencePrice = currentMOD;
    }
    else {
        m_modReferencePrice = m_averageEntryPrice; // Fallback
    }

    // Initialize extreme price tracking
    if(m_direction == 1) {
        m_lowestEntryPrice = m_averageEntryPrice;
        m_highestEntryPrice = 0.0;
    }
    else {
        m_highestEntryPrice = m_averageEntryPrice;
        m_lowestEntryPrice = 0.0;
    }

    LOG_DEBUG("Recovery complete:");
    LOG_DEBUG("  Direction: " + (m_direction == 1 ? "LONG" : "SHORT"));
    LOG_DEBUG("  Estimated Level: " + string(m_currentLevel));
    LOG_DEBUG("  Estimated AEP: " + DoubleToString(m_averageEntryPrice, _Digits));
    LOG_DEBUG("  MOD Reference: " + DoubleToString(m_modReferencePrice, _Digits));
    LOG_DEBUG("  Initial Lot Remaining: " + DoubleToString(m_initialLotRemainingVolume, 2));

    return true;
}

//+------------------------------------------------------------------+
//| Update average price with new position                          |
//+------------------------------------------------------------------+
void CPrimaryTradingSystem::UpdateAveragePrice(double price, double lots)
{
    if(m_currentLevel == 0) {
        // First position - this is the initial entry
        m_averageEntryPrice = price;
        m_currentLevel = 1;
        m_initialLotSize = lots;
        m_initialLotRemainingVolume = lots;
        m_initialEntryPrice = price;
        m_hasInitialPosition = true;
        m_initialProfitTargetReached = false;
        m_modReferencePrice = price; // Set MOD reference to initial entry

        // Initialize extreme price tracking
        if(m_direction == 1) {
            m_lowestEntryPrice = price;   // Long: track lowest
            m_highestEntryPrice = 0.0;    // Reset unused
        }
        else {
            m_highestEntryPrice = price;  // Short: track highest
            m_lowestEntryPrice = 0.0;     // Reset unused
        }

        ResetExitLevels();
        LOG_DEBUG("Primary System: INITIAL position created - Size: " + DoubleToString(lots, 2) +
                  " | Price: " + DoubleToString(price, _Digits) +
                  " | MOD Reference: " + DoubleToString(m_modReferencePrice, _Digits));
    }
    else {
        // Subsequent positions - these are Martingale additions
        // This will be implemented with proper volume-weighted average calculation
        m_currentLevel++;
        LOG_DEBUG("Primary System: MARTINGALE position added - Level: " + string(m_currentLevel));

        // Log reclassification status if applicable
        if(m_currentLevel == 1 && m_modReferencePrice > 0.0) {
            LOG_DEBUG("RECLASSIFIED POSITION: Level 1 entry from MOD reference: " +
                      DoubleToString(m_modReferencePrice, _Digits));
        }
    }
}

//+------------------------------------------------------------------+
//| Detect MOD pullback for entry - Intra-bar implementation        |
//+------------------------------------------------------------------+
bool CPrimaryTradingSystem::DetectMODPullback(double currentPrice, double currentMOD)
{
    if(currentMOD <= 0.0) {
        return false;
    }

    // Calculate tolerance based on ATR (configurable precision)
    double tolerance = 0.0001; // Default minimal tolerance, can be enhanced with ATR-based calculation

    // Check if price is currently at MOD level (within tolerance)
    bool atMODLevel = (MathAbs(currentPrice - currentMOD) <= tolerance);

    // Track price movement to detect pullback pattern
    static double s_previousPrice = 0.0;
    static double s_previousMOD = 0.0;
    static bool s_awayFromMOD = false;

    // Initialize on first call
    if(s_previousPrice == 0.0) {
        s_previousPrice = currentPrice;
        s_previousMOD = currentMOD;
        LOG_DEBUG("MOD Pullback Detection: Initialized tracking");
        return false;
    }

    // Detect if MOD level has changed significantly (new MOD reference)
    double modChange = MathAbs(currentMOD - s_previousMOD);
    if(modChange > tolerance * 10) { // Significant MOD change
        LOG_DEBUG("MOD Pullback Detection: MOD level changed significantly - Reset tracking");
        s_awayFromMOD = false; // Reset away status for new MOD level
    }

    // Track if price has moved away from MOD (establishes pullback potential)
    if(!s_awayFromMOD) {
        double distanceFromMOD = MathAbs(currentPrice - currentMOD);
        double significantDistance = tolerance * 5; // Must move at least 5x tolerance away

        if(distanceFromMOD > significantDistance) {
            s_awayFromMOD = true;
            LOG_DEBUG("MOD Pullback Detection: Price moved away from MOD - Distance: " +
                      DoubleToString(distanceFromMOD, _Digits));
        }
    }

    // Detect pullback: price was away and now returns to MOD level
    bool pullbackDetected = s_awayFromMOD && atMODLevel;

    if(pullbackDetected) {
        LOG_DEBUG("=== MOD PULLBACK DETECTED ===");
        LOG_DEBUG("Current Price: " + DoubleToString(currentPrice, _Digits));
        LOG_DEBUG("MOD Level: " + DoubleToString(currentMOD, _Digits));
        LOG_DEBUG("Distance: " + DoubleToString(MathAbs(currentPrice - currentMOD), _Digits));
        LOG_DEBUG("Tolerance: " + DoubleToString(tolerance, _Digits));
        LOG_DEBUG("=== PULLBACK CONFIRMED ===");

        // Reset tracking after detection
        s_awayFromMOD = false;
    }

    // Update tracking variables
    s_previousPrice = currentPrice;
    s_previousMOD = currentMOD;

    return pullbackDetected;
}

//+------------------------------------------------------------------+
//| Check if ready for initial entry - Intra-bar implementation     |
//+------------------------------------------------------------------+
bool CPrimaryTradingSystem::IsReadyForInitialEntry(double currentPrice, double currentMOD)
{
    // Don't enter if we already have a position
    if(m_direction != 0 && m_currentLevel > 0) {
        return false;
    }

    // Validate inputs
    if(currentMOD <= 0.0 || currentPrice <= 0.0) {
        return false;
    }

    // Check if price is at MOD level (intra-bar detection)
    double tolerance = 0.0001; // Minimal tolerance for precise MOD touch detection
    bool atMODLevel = (MathAbs(currentPrice - currentMOD) <= tolerance);

    if(!atMODLevel) {
        return false;
    }

    // Additional entry readiness checks can be added here
    // For example: trend confirmation, volatility filters, etc.

    LOG_DEBUG("=== INITIAL ENTRY READINESS CHECK ===");
    LOG_DEBUG("Current Price: " + DoubleToString(currentPrice, _Digits));
    LOG_DEBUG("MOD Level: " + DoubleToString(currentMOD, _Digits));
    LOG_DEBUG("Distance: " + DoubleToString(MathAbs(currentPrice - currentMOD), _Digits));
    LOG_DEBUG("At MOD Level: " + (atMODLevel ? "YES" : "NO"));
    LOG_DEBUG("Ready for Entry: " + (atMODLevel ? "YES" : "NO"));

    return atMODLevel;
}

//+------------------------------------------------------------------+
//| Reset pullback tracking                                         |
//+------------------------------------------------------------------+
void CPrimaryTradingSystem::ResetPullbackTracking()
{
    m_readyForPullbackEntry = false;
    m_awayFromMOD = false;
    LOG_DEBUG("Primary System: MOD pullback tracking reset");
}

//+------------------------------------------------------------------+
//| Calculate initial lot profit at current price                   |
//+------------------------------------------------------------------+
double CPrimaryTradingSystem::CalculateInitialLotProfit(double currentPrice) const
{
    if(m_averageEntryPrice <= 0.0 || m_initialLotRemainingVolume <= 0.0 || currentPrice <= 0.0) {
        return 0.0;
    }

    // Calculate P&L based on AEP and remaining initial lot volume
    double priceDifference = 0.0;

    if(m_direction == 1) {
        // Long position: profit when current price > AEP
        priceDifference = currentPrice - m_averageEntryPrice;
    }
    else if(m_direction == -1) {
        // Short position: profit when current price < AEP
        priceDifference = m_averageEntryPrice - currentPrice;
    }

    // Convert price difference to monetary value
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    double profitPerLot = (priceDifference / tickSize) * tickValue;
    double totalProfit = profitPerLot * m_initialLotRemainingVolume;

    LOG_DEBUG("Initial Lot Profit Calculation (AEP-Based):");
    LOG_DEBUG("  AEP: " + DoubleToString(m_averageEntryPrice, _Digits));
    LOG_DEBUG("  Current Price: " + DoubleToString(currentPrice, _Digits));
    LOG_DEBUG("  Price Difference: " + DoubleToString(priceDifference, _Digits));
    LOG_DEBUG("  Remaining Volume: " + DoubleToString(m_initialLotRemainingVolume, 2));
    LOG_DEBUG("  Calculated Profit: $" + DoubleToString(totalProfit, 2));

    return totalProfit;
}

//+------------------------------------------------------------------+
//| Calculate profit for specific volume closure at specific price  |
//+------------------------------------------------------------------+
double CPrimaryTradingSystem::CalculateInitialLotClosureProfit(double volumeToBeClosed, double closurePrice) const
{
    if(m_averageEntryPrice <= 0.0 || volumeToBeClosed <= 0.0 || closurePrice <= 0.0) {
        return 0.0;
    }

    // Calculate P&L based on AEP
    double priceDifference = 0.0;

    if(m_direction == 1) {
        // Long position: profit when closure price > AEP
        priceDifference = closurePrice - m_averageEntryPrice;
    }
    else if(m_direction == -1) {
        // Short position: profit when closure price < AEP
        priceDifference = m_averageEntryPrice - closurePrice;
    }

    // Convert to monetary value
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    double profitPerLot = (priceDifference / tickSize) * tickValue;
    double totalProfit = profitPerLot * volumeToBeClosed;

    LOG_DEBUG("Closure Profit Calculation (AEP-Based):");
    LOG_DEBUG("  AEP: " + DoubleToString(m_averageEntryPrice, _Digits));
    LOG_DEBUG("  Closure Price: " + DoubleToString(closurePrice, _Digits));
    LOG_DEBUG("  Volume to Close: " + DoubleToString(volumeToBeClosed, 2));
    LOG_DEBUG("  Expected Profit: $" + DoubleToString(totalProfit, 2));

    return totalProfit;
}

//+------------------------------------------------------------------+
//| Calculate initial 50% profit target price with proper ATR       |
//+------------------------------------------------------------------+
double CPrimaryTradingSystem::Calculate50PercentProfitTarget() const
{
    if(m_averageEntryPrice <= 0.0 || !m_hasInitialPosition) {
        return 0.0;
    }

    // Get current ATR value from indicator manager
    double atrValue = g_indicatorManager.GetPrimaryATR();

    if(atrValue <= 0.0) {
        LOG_DEBUG("WARNING: Invalid ATR value for 50% profit target calculation");
        return 0.0;
    }

    // Calculate 50% profit target: AEP + 1.0 ATR for long, AEP - 1.0 ATR for short
    double profitTargetPrice = 0.0;

    if(m_direction == 1) {
        // Long position: profit target above AEP
        profitTargetPrice = m_averageEntryPrice + (1.0 * atrValue);
    }
    else if(m_direction == -1) {
        // Short position: profit target below AEP
        profitTargetPrice = m_averageEntryPrice - (1.0 * atrValue);
    }

    LOG_DEBUG("=== 50% PROFIT TARGET CALCULATION (AEP-BASED) ===");
    LOG_DEBUG("Average Entry Price (AEP): " + DoubleToString(m_averageEntryPrice, _Digits));
    LOG_DEBUG("ATR Value: " + DoubleToString(atrValue, _Digits));
    LOG_DEBUG("Direction: " + (m_direction == 1 ? "LONG" : "SHORT"));
    LOG_DEBUG("50% Profit Target Price: " + DoubleToString(profitTargetPrice, _Digits));

    return profitTargetPrice;
}

//+------------------------------------------------------------------+
//| Check if should trigger initial 50% exit                        |
//+------------------------------------------------------------------+
bool CPrimaryTradingSystem::ShouldTriggerInitial50PercentExit(double currentPrice, double previousPrice) const
{
    // Only applicable if we have initial position and haven't reached profit target yet
    if(!m_hasInitialPosition || m_initialProfitTargetReached || m_initialLotRemainingVolume <= 0.0) {
        return false;
    }

    // Calculate profit target price based on AEP
    double profitTargetPrice = Calculate50PercentProfitTarget();

    if(profitTargetPrice <= 0.0) {
        return false;
    }

    // Check if price has crossed the profit target
    bool targetReached = false;

    if(m_direction == 1) {
        // Long position: trigger when price crosses above profit target
        targetReached = (currentPrice >= profitTargetPrice && previousPrice < profitTargetPrice);
    }
    else if(m_direction == -1) {
        // Short position: trigger when price crosses below profit target
        targetReached = (currentPrice <= profitTargetPrice && previousPrice > profitTargetPrice);
    }

    if(targetReached) {
        LOG_DEBUG("=== INITIAL 50% EXIT TRIGGER (AEP-BASED) ===");
        LOG_DEBUG("AEP: " + DoubleToString(m_averageEntryPrice, _Digits));
        LOG_DEBUG("Profit Target: " + DoubleToString(profitTargetPrice, _Digits));
        LOG_DEBUG("Current Price: " + DoubleToString(currentPrice, _Digits));
        LOG_DEBUG("Previous Price: " + DoubleToString(previousPrice, _Digits));
        LOG_DEBUG("Direction: " + (m_direction == 1 ? "LONG" : "SHORT"));
        LOG_DEBUG("=== 50% EXIT CONFIRMED ===");
    }

    return targetReached;
}

//+------------------------------------------------------------------+
//| Update remaining volume after partial closure                   |
//+------------------------------------------------------------------+
void CPrimaryTradingSystem::UpdateRemainingVolumeAfterPartialClosure(double remainingVolume)
{
    // Update initial lot remaining volume to reflect current state
    m_initialLotRemainingVolume = remainingVolume;

    // After reclassification, the remaining volume becomes the new "initial" size
    m_initialLotSize = remainingVolume;

    LOG_DEBUG("Volume updated after partial closure:");
    LOG_DEBUG("  Remaining Volume: " + DoubleToString(remainingVolume, 2));
    LOG_DEBUG("  New Initial Lot Size: " + DoubleToString(m_initialLotSize, 2));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CPrimaryTradingSystem::SetInitialProfitTargetReached(bool reached)
{
    m_initialProfitTargetReached = reached;
}

//+------------------------------------------------------------------+
//| Check if position reclassification is needed                    |
//+------------------------------------------------------------------+
bool CPrimaryTradingSystem::IsReclassificationNeeded() const
{
    // Reclassification is needed when:
    // 1. We have a position (level > 0)
    // 2. We're not at the maximum level
    // 3. We have remaining volume after partial closure

    return (m_currentLevel > 0 &&
            m_currentLevel < MaxEntryLevels &&
            m_initialLotRemainingVolume > 0.0);
}
//+------------------------------------------------------------------+
