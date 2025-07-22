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
    double m_initialLotSize;           // Size of the initial entry
    double m_initialLotRemainingVolume; // Remaining volume from initial entry
    double m_initialEntryPrice;        // Entry price of initial position
    bool m_initialProfitTargetReached; // Flag if 50% profit target was hit
    bool m_hasInitialPosition;         // Flag indicating if initial position exists
    bool m_entryConditionsPreviouslySatisfied;  // Track previous entry conditions state for transition detection
    double m_lowestEntryPrice;     // For long positions - tracks lowest entry price
    double m_highestEntryPrice;    // For short positions - tracks highest entry price
    double m_modReferencePrice;    // Dynamic MOD reference for Martingale calculations
    bool m_isReclassified;         // Track if position was reclassified

public:
    CPrimaryTradingSystem() : m_averageEntryPrice(0), m_currentLevel(0), m_direction(0),
        m_exitLevel1Executed(false), m_exitLevel2Executed(false),
        m_lastDirection(0), m_lastMODLevel(0), m_lastPrice(0),
        m_entryConditionsPreviouslySatisfied(false),
        m_lowestEntryPrice(0.0), m_highestEntryPrice(0.0),
        m_modReferencePrice(0.0), m_isReclassified(false) {}

    // Core trading logic
    bool ShouldOpenPosition(int signalDirection);
    bool ShouldAddToPosition(double currentPrice, double atrValue);
    ENUM_EXIT_TYPE ShouldExitPosition(double currentPrice, double atrValue, double previousPrice);
    bool EstimatePositionStateFromTrades();
    void UpdateAveragePrice(double price, double lots);
    bool UpdatePrimaryDirection();
    bool DetectMODPullback(double currentPrice, double currentMOD);
    void Reset();
    void ReclassifyAfterPartialExit(double currentMOD); // Dynamic MOD tracking

    // State restoration setters
    void SetMODReferencePrice(double price)
    {
        m_modReferencePrice = price;
    }
    void SetCurrentLevel(int level)
    {
        m_currentLevel = level;
    }
    void SetInitialEntryPrice(double price)
    {
        m_initialEntryPrice = price;
    }
    void SetLowestEntryPrice(double price)
    {
        m_lowestEntryPrice = price;
    }
    void SetHighestEntryPrice(double price)
    {
        m_highestEntryPrice = price;
    }
    void SetInitialLotSize(double size)
    {
        m_initialLotSize = size;
    }
    void SetInitialLotRemainingVolume(double volume)
    {
        m_initialLotRemainingVolume = volume;
    }
    void SetHasInitialPosition(bool hasPos)
    {
        m_hasInitialPosition = hasPos;
    }
    void SetIsReclassified(bool reclassified)
    {
        m_isReclassified = reclassified;
    }
    void SetInitialProfitTargetReached(bool reached)
    {
        m_initialProfitTargetReached = reached;
    }

    // Getters and setters
    bool IsReclassified() const
    {
        return m_isReclassified;
    }
    void SetReclassified(bool reclassified)
    {
        m_isReclassified = reclassified;
    }
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

    // Reset initial lot tracking
    m_initialLotSize = 0.0;
    m_initialLotRemainingVolume = 0.0;
    m_initialEntryPrice = 0.0;
    m_initialProfitTargetReached = false;
    m_hasInitialPosition = false;

    m_entryConditionsPreviouslySatisfied = false;
    m_lowestEntryPrice = 0.0;
    m_highestEntryPrice = 0.0;
    m_modReferencePrice = 0.0;
    m_isReclassified = false;

    LOG_DEBUG("Primary system reset: Position tracking cleared | Direction reset | MOD pullback reset | Exit levels reset | Extreme price reset | MOD reference reset | Ready for new entry cycle");
}

//+------------------------------------------------------------------+
//| Reclassify position after partial exit for dynamic MOD tracking |
//+------------------------------------------------------------------+
void CPrimaryTradingSystem::ReclassifyAfterPartialExit(double currentMOD)
{
    LOG_DEBUG("Position reclassification: Level " + string(m_currentLevel) + " | MOD: " + DoubleToString(m_modReferencePrice, _Digits) +
              " > " + DoubleToString(currentMOD, _Digits) + " | AEP: " + DoubleToString(m_averageEntryPrice, _Digits));

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

    m_isReclassified = true;  // Mark as reclassified

    // 7. Reset initial lot tracking (remaining volume becomes new base)
    // Note: Actual remaining volume will be updated by trade executor
    // We don't modify m_initialLotSize or m_initialLotRemainingVolume here
    // as they should reflect the actual remaining position volume

    LOG_DEBUG("Reclassification complete: Level " + string(m_currentLevel) + " | MOD: " + DoubleToString(m_modReferencePrice, _Digits) +
              " | " + string(MaxEntryLevels - m_currentLevel) + " slots available | Exit levels reset");
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
        LOG_DEBUG("Direction: Failed to read indicator signal - maintaining last direction");
        return false; // Maintain last known direction on read failure
    }

// Validate color index (robust edge case handling)
    if(primaryColor != 0 && primaryColor != 1) {
        LOG_DEBUG("Direction: Invalid color index (" + string(primaryColor) +
                  ") - maintaining last direction");
        return false; // Maintain last known direction on invalid data
    }

// Convert color to direction signal
    int newDirection = (primaryColor == 0) ? 1 : -1; // 0=Blue=Long, 1=Magenta=Short

// Check for direction change
    bool directionChanged = (m_lastDirection != 0 && m_lastDirection != newDirection);

    if(directionChanged) {
        LOG_DEBUG("Direction change: " + (m_lastDirection == 1 ? "LONG" : "SHORT") + " to " + (newDirection == 1 ? "LONG" : "SHORT") +
                  " | Midline: " + DoubleToString(primaryMidline, _Digits));

        // Handle existing positions when direction changes
        if(g_tradeExecutor.IsPrimaryPositionOpen()) {
            LOG_DEBUG("Existing position detected - continuing Martingale management, exit levels remain active");
            // Note: We do NOT reset exit levels here - they continue for existing positions
        }

        // Properly maintain state transition
        m_lastDirection = m_direction;  // Store current as previous
        m_direction = newDirection;     // Update to new direction
    }
    else {
        // No change detected - just update current direction
        m_direction = newDirection;
    }

    return directionChanged;
}

//+------------------------------------------------------------------+
//| Enhanced with crossing-based MOD detection   |
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
    double currentPrice = iClose(_Symbol, _Period, 0);

    // Check if MOD crossing detected - this is sufficient for entry decision
    bool shouldEnter = DetectMODPullback(currentPrice, m_lastMODLevel);

    if(shouldEnter) {
        LOG_DEBUG("Entry conditions satisfied: " + (signalDirection == 1 ? "LONG" : "SHORT") +
                  " | Price: " + DoubleToString(currentPrice, _Digits) + " | MOD: " + DoubleToString(m_lastMODLevel, _Digits));
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

    return shouldTrigger;
}

//+------------------------------------------------------------------+
//| Enhanced exit position check with proper crossover detection    |
//+------------------------------------------------------------------+
ENUM_EXIT_TYPE CPrimaryTradingSystem::ShouldExitPosition(double currentPrice, double atrValue, double previousPrice)
{
    // Validate inputs
    if(m_averageEntryPrice <= 0.0 || atrValue <= 0.0 || m_currentLevel <= 0) {
        return EXIT_NONE;
    }

    // Check initial 50% profit target first (highest priority)
    if(m_hasInitialPosition && !m_initialProfitTargetReached && m_initialLotRemainingVolume > 0.0) {
        if(ShouldTriggerInitial50PercentExit(currentPrice, previousPrice)) {
            LOG_DEBUG("Exit condition detected: INITIAL_50_PERCENT");
            return EXIT_INITIAL_50_PERCENT;
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
    else {
        return EXIT_NONE; // Invalid direction
    }

    // Check for ATR exit level 1 trigger (crossover detection)
    if(!m_exitLevel1Executed) {
        bool level1Triggered = false;

        if(m_direction == 1) {
            level1Triggered = (currentPrice >= exitLevel1Price && previousPrice < exitLevel1Price);
        }
        else if(m_direction == -1) {
            level1Triggered = (currentPrice <= exitLevel1Price && previousPrice > exitLevel1Price);
        }

        if(level1Triggered) {
            LOG_DEBUG("Exit condition detected: ATR_LEVEL_1 | Price: " + DoubleToString(currentPrice, _Digits) +
                      " | Target: " + DoubleToString(exitLevel1Price, _Digits));
            return EXIT_ATR_LEVEL_1;
        }
    }

    // Check for ATR exit level 2 trigger (crossover detection)
    if(!m_exitLevel2Executed) {
        bool level2Triggered = false;

        if(m_direction == 1) {
            level2Triggered = (currentPrice >= exitLevel2Price && previousPrice < exitLevel2Price);
        }
        else if(m_direction == -1) {
            level2Triggered = (currentPrice <= exitLevel2Price && previousPrice > exitLevel2Price);
        }

        if(level2Triggered) {
            LOG_DEBUG("Exit condition detected: ATR_LEVEL_2 | Price: " + DoubleToString(currentPrice, _Digits) +
                      " | Target: " + DoubleToString(exitLevel2Price, _Digits));
            return EXIT_ATR_LEVEL_2;
        }
    }

    // No exit conditions met
    return EXIT_NONE;
}

//+------------------------------------------------------------------+
//| Recover position state from existing open positions             |
//+------------------------------------------------------------------+
bool CPrimaryTradingSystem::EstimatePositionStateFromTrades()
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
//| Detect MOD crossing for entry - Enhanced crossing detection     |
//+------------------------------------------------------------------+
bool CPrimaryTradingSystem::DetectMODPullback(double currentPrice, double currentMOD)
{
    // Validate inputs
    if(currentPrice <= 0.0 || currentMOD <= 0.0) {
        LOG_DEBUG("Primary Entry: Invalid price or MOD values for crossing detection");
        return false;
    }

    // Special case: Reset static variables when called with invalid parameters
    if(currentPrice < 0.0 || currentMOD < 0.0) {
        static double previousPrice = -1.0;
        previousPrice = -1.0; // Reset static variable
        LOG_DEBUG("MOD Crossing Detection: Static variables reset");
        return false;
    }

    // RATIONALE: MOD Crossing Detection Strategy
    // We detect when price crosses the MOD level from either direction (above or below).
    // This approach triggers immediate entry opportunities without waiting for complex
    // "move away then return" patterns. The crossing detection is direction-agnostic:
    // - Any crossing of MOD level indicates potential entry readiness
    // - Signal direction (long/short) is determined separately by Midline color
    // - Entry execution validates proximity to MOD using tolerance for practical execution
    // This ensures faster response to MOD pullback opportunities while maintaining precision.

    // Static variable to track previous price for crossing detection
    static double previousPrice = -1.0;

    // Initialize on first call
    if(previousPrice == -1.0) {
        previousPrice = currentPrice;
        LOG_DEBUG("Primary Entry: Initializing MOD crossing detection - MOD: " +
                  DoubleToString(currentMOD, _Digits) + " | Price: " + DoubleToString(currentPrice, _Digits));
        return false;
    }

    // Detect crossing from above: previousPrice > MOD && currentPrice <= MOD
    bool crossedFromAbove = (previousPrice > currentMOD && currentPrice <= currentMOD);

    // Detect crossing from below: previousPrice < MOD && currentPrice >= MOD
    bool crossedFromBelow = (previousPrice < currentMOD && currentPrice >= currentMOD);

    // Any crossing triggers entry readiness
    bool crossingDetected = (crossedFromAbove || crossedFromBelow);

    if(crossingDetected) {
        LOG_DEBUG("MOD crossing detected: " + (crossedFromAbove ? "FROM ABOVE" : "FROM BELOW") +
                  " | Price: " + DoubleToString(previousPrice, _Digits) + " > " + DoubleToString(currentPrice, _Digits) +
                  " | MOD: " + DoubleToString(currentMOD, _Digits));
    }

    // Update previous price for next iteration
    previousPrice = currentPrice;

    return crossingDetected;
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
        LOG_DEBUG("50% profit target: " + DoubleToString(profitTargetPrice, _Digits) +
                  " | AEP: " + DoubleToString(m_averageEntryPrice, _Digits) +
                  " | ATR: " + DoubleToString(atrValue, _Digits) + " | LONG");
    }
    else if(m_direction == -1) {
        // Short position: profit target below AEP
        profitTargetPrice = m_averageEntryPrice - (1.0 * atrValue);
        LOG_DEBUG("50% profit target: " + DoubleToString(profitTargetPrice, _Digits) +
                  " | AEP: " + DoubleToString(m_averageEntryPrice, _Digits) +
                  " | ATR: " + DoubleToString(atrValue, _Digits) + " | SHORT");
    }

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
        LOG_DEBUG("Initial 50% exit triggered: " + (m_direction == 1 ? "LONG" : "SHORT") +
                  " | AEP: " + DoubleToString(m_averageEntryPrice, _Digits) +
                  " | Target: " + DoubleToString(profitTargetPrice, _Digits) +
                  " | Price: " + DoubleToString(previousPrice, _Digits) + " > " + DoubleToString(currentPrice, _Digits));
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

    LOG_DEBUG("Remaining volume reclassified as new initial lot size: " + DoubleToString(remainingVolume, 2) + " lots");
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
