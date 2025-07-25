﻿//+------------------------------------------------------------------+
//|                                                    ID6498 EA.mq5 |
//|                                 Copyright © 2025, barmenteros FX |
//|                                          https://barmenteros.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, barmenteros FX"
#property link      "https://barmenteros.com"
#define EA_VERSION  "2.10"
#property version   EA_VERSION
#property description "Single-chart dynamic MOD-tracking trading system with Martingale entries"

#define CUSTOM_INDICATOR_NAME "Midline_Trader"
#property tester_indicator CUSTOM_INDICATOR_NAME

//+------------------------------------------------------------------+
//| Enums                                                            |
//+------------------------------------------------------------------+
enum ENUM_SIZING_METHOD {
    SIZING_FIXED_LOTS,      // Fixed lot sizes
    SIZING_PERCENTAGE       // Percentage-based sizing
};

enum ENUM_EXIT_TYPE {
    EXIT_NONE = 0,               // No exit condition met
    EXIT_INITIAL_50_PERCENT,     // Initial 50% profit target (1 ATR from AEP)
    EXIT_ATR_LEVEL_1,           // ATR-based exit level 1
    EXIT_ATR_LEVEL_2            // ATR-based exit level 2
};

// Include modular components
#include "Classes\StateManager.mqh"
#include "Classes\IndicatorManager.mqh"
#include "Classes\PrimaryTradingSystem.mqh"
#include "Classes\RiskManager.mqh"
#include "Classes\PositionSizer.mqh"
#include "Classes\TradeExecutor.mqh"
#include "Classes\MartingaleManager.mqh"
#include "Utils\DebugUtils.mqh"
#include "Utils\TimeUtils.mqh"
#include <Jason.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
//input group "=== EA IDENTITY ==="
int MagicNumberPrimary = 211864501;     // Magic number for primary chart trades

input group "=== TRADING TIME RESTRICTIONS ==="
input bool EnableTimeRestrictions = false;    // Enable trading time restrictions
input int TradingStartHour = 9;               // Trading start hour (broker time)
input int TradingEndHour = 16;                // Trading end hour (broker time)

input group "=== MIDLINE INDICATOR SETTINGS ==="
input double VertTextPct = 99.0;              // Midline: Vertical text percentage
input double RiskPerTrade = 200.0;            // Midline: Risk per trade ($)
input int PlotRiskOnScreen = 1;               // Midline: Plot risk on screen
input double MinLotSize = 0.01;               // Midline: Minimum lot size
input ENUM_APPLIED_PRICE Price = PRICE_CLOSE; // Midline: Price type for main calculation
input ENUM_APPLIED_PRICE MODDPrice = PRICE_CLOSE; // Midline: Price type for MODD calculation
input int NoOfATRsToPlot = 3;                 // Midline: Number of ATRs to plot
input int EffRatioLengthL = 10;               // Midline: Efficiency ratio length (Long)
input int FastAvgLengthL = 3;                 // Midline: Fast MA length (Long)
input int SlowAvgLengthL = 50;                // Midline: Slow MA length (Long)
input int EffRatioLengthS = 10;               // Midline: Efficiency ratio length (Short)
input int FastAvgLengthS = 2;                 // Midline: Fast MA length (Short)
input int SlowAvgLengthS = 35;                // Midline: Slow MA length (Short)
input int ModEffRatioLength = 10;             // Midline: MOD efficiency ratio length
input int ModFastAvgLength = 1;               // Midline: MOD fast MA length
input int ModSlowAvgLength = 30;              // Midline: MOD slow MA length
input int ATRLength = 25;                     // Midline: ATR length
input double ATREnvelopes = 1.0;              // Midline: ATR envelope multiplier
input color BandColor = clrDarkGray;          // Midline: Band color
input color ColourUp = clrDodgerBlue;         // Midline: Up color (Blue = Long)
input color ColourDn = clrMagenta;            // Midline: Down color (Magenta = Short)
input bool MidLineOnOrOff = true;             // Midline: Show midline
input bool ModLineOnOrOff = true;             // Midline: Show MOD line

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "=== ENTRY SYSTEM (MARTINGALE) ==="
input double ATRMultiplier = 1.0;             // ATR distance multiplier for entries
input int MaxEntryLevels = 8;                 // Maximum entry levels (1-8)
input ENUM_SIZING_METHOD SizingMethod = SIZING_FIXED_LOTS;           // Position sizing method
input double InitialLotSize = 2.0;            // Initial lot size
input double LotMultiplier = 1.5;             // Lot size multiplier for next levels
input double RiskPercentage = 2.0;            // Risk percentage of account (for percentage method)

input group "=== EXIT SYSTEM ==="
input double ExitLevel1_ATR = 1.0;            // Exit level 1 distance (ATR)
input double ExitLevel2_ATR = 2.0;            // Exit level 2 distance (ATR)
input double ExitLevel1_Percentage = 50.0;    // Percentage to close at level 1 (%)
input double ExitLevel2_Percentage = 50.0;    // Percentage to close at level 2 (%)

input group "=== RISK MANAGEMENT ==="
input double MinimumProfitThreshold = 100.0;  // Minimum profit required for system reset ($)
input double DrawdownStopLossPercentage = 20.0; // Drawdown stop loss percentage

input group "=== DISPLAY SETTINGS ==="
input bool ShowInfoPanel = true;             // Show information panel on chart

input group "=== DEBUG SETTINGS ==="
input bool DebugMode = true;                 // Enable debug messages (disable for production)

//+------------------------------------------------------------------+
//| Global Objects                                                  |
//+------------------------------------------------------------------+
CStateManager g_stateManager(_Symbol, MagicNumberPrimary);
CIndicatorManager g_indicatorManager;
CPrimaryTradingSystem g_primarySystem;
CRiskManager g_riskManager;
CPositionSizer g_positionSizer;
CTradeExecutor g_tradeExecutor;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
// Check if account supports hedging
    ENUM_ACCOUNT_MARGIN_MODE marginMode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
    if(marginMode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) {
        Print("ERROR: This EA requires a hedging account");
        Print("Current account margin mode: ", EnumToString(marginMode));
        Print("Required: ACCOUNT_MARGIN_MODE_RETAIL_HEDGING");
        Print("Please use a hedging account or contact your broker");
        return INIT_PARAMETERS_INCORRECT;
    }

    LOG_DEBUG("SUCCESS: Hedging account confirmed - Margin mode: " + EnumToString(marginMode));

// Validate inputs
    double brokerMinLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double brokerLotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minimumRequired = brokerLotStep * 2.0;
    minimumRequired = MathMax(minimumRequired, brokerMinLot);

    if(InitialLotSize < minimumRequired) {
        Print("ERROR: Initial lot size (" + DoubleToString(InitialLotSize, 2) +
              ") must be at least twice broker lot step (" + DoubleToString(brokerLotStep * 2.0, 2) +
              ") and meet broker minimum (" + DoubleToString(brokerMinLot, 2) +
              ") to ensure proper exit divisibility");
        return INIT_PARAMETERS_INCORRECT;
    }

    if(ExitLevel1_Percentage + ExitLevel2_Percentage != 100.0) {
        Print("ERROR: Exit percentages must sum to 100%");
        return INIT_PARAMETERS_INCORRECT;
    }

    if(MaxEntryLevels < 1 || MaxEntryLevels > 8) {
        Print("ERROR: Maximum entry levels must be between 1 and 8");
        return INIT_PARAMETERS_INCORRECT;
    }

    if(MinimumProfitThreshold <= 0.0) {
        Print("ERROR: Minimum profit threshold must be positive - Current: $" + DoubleToString(MinimumProfitThreshold, 2));
        return INIT_PARAMETERS_INCORRECT;
    }

    if(DrawdownStopLossPercentage <= 0.0) {
        Print("ERROR: Drawdown stop loss percentage must be positive - Current: " + DoubleToString(DrawdownStopLossPercentage, 2) + "%");
        return INIT_PARAMETERS_INCORRECT;
    }

    if(DrawdownStopLossPercentage > 200.0) {
        Print("ERROR: Drawdown stop loss percentage is excessive (" + DoubleToString(DrawdownStopLossPercentage, 2) + "%) - Maximum allowed: 200%");
        return INIT_PARAMETERS_INCORRECT;
    }

    if(DrawdownStopLossPercentage > 100.0) {
        Print("WARNING: Drawdown stop loss percentage is very high (" + DoubleToString(DrawdownStopLossPercentage, 2) + "%) - This may not provide effective risk protection");
        Print("Recommended range: 10-50% for optimal risk management");
    }

// Initialize indicator manager (PRIMARY ONLY)
    if(!g_indicatorManager.Init()) {
        Print("ERROR: Failed to initialize primary indicator manager");
        return INIT_FAILED;
    }

// Initialize risk manager
    g_riskManager.InitializeSystemStartTime();

    LOG_DEBUG("ID6498 EA v" + EA_VERSION + " initialized | Magic: " + string(MagicNumberPrimary) + " | Debug: " + (DebugMode ? "ON" : "OFF"));

// Log time restriction settings
    if(EnableTimeRestrictions) {
        string tradingStatus = IsWithinTradingHours() ? "ALLOWED" : "BLOCKED";
        if(TradingStartHour < 0 || TradingStartHour > 23 || TradingEndHour < 0 || TradingEndHour > 23) {
            LOG_DEBUG("Time restrictions: ENABLED | Window: INVALID (defaulting to 24h) | Status: " + tradingStatus);
        }
        else if(TradingStartHour == TradingEndHour) {
            LOG_DEBUG("Time restrictions: ENABLED | Window: 24h | Status: " + tradingStatus);
        }
        else {
            LOG_DEBUG("Time restrictions: ENABLED | Window: " + string(TradingStartHour) + ":00-" + string(TradingEndHour) + ":00 | Status: " + tradingStatus);
        }
    }
    else {
        LOG_DEBUG("Time restrictions: DISABLED (24h trading)");
    }

// Try to recover state from file first
    if(!g_stateManager.LoadState()) {
        LOG_DEBUG("No valid state file - starting fresh");

        if(g_tradeExecutor.IsPrimaryPositionOpen()) {
            // Optional: estimate for logging purposes only
            if(g_primarySystem.EstimatePositionStateFromTrades()) {
                LOG_DEBUG("Position estimation (for reference): Level ~" +
                          string(g_primarySystem.GetCurrentLevel()));
            }
            // But don't actually use the estimated state
            g_primarySystem.Reset(); // Start fresh regardless
        }
    }

// Log system configuration
    LOG_DEBUG("System config: Dynamic MOD-Tracking | Max levels: " + string(MaxEntryLevels) + " | ATR mult: " + DoubleToString(ATRMultiplier, 1) + " | Initial lot: " + DoubleToString(InitialLotSize, 2) + " | Sizing: " + EnumToString(SizingMethod));

// Log risk management settings
    LOG_DEBUG("Risk management: Profit threshold: $" + DoubleToString(MinimumProfitThreshold, 2) + " | Drawdown stop: " + DoubleToString(DrawdownStopLossPercentage, 2) + "%");

    LOG_DEBUG("Primary system recovery: Level " + string(g_primarySystem.GetCurrentLevel()) + " | Initialization complete");

// Trigger initial tick processing
    OnTick();

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
// Handle state management based on deinit reason
    g_stateManager.HandleDeinit(reason);

// Standard cleanup
    g_indicatorManager.DeInit();
    Comment("");

    LOG_DEBUG("Single-Chart Dynamic MOD-Tracking EA deinitialized | Reason: " + string(reason));
}

//+------------------------------------------------------------------+
//| Modified OnTick() - Reduced repetitive direction logging        |
//+------------------------------------------------------------------+
void OnTick()
{
    datetime currentTime = TimeCurrent();
    /*
        // Consolidated status update every 5 minutes to reduce log clutter
        static datetime lastStatusTime = 0;

        if(currentTime - lastStatusTime >= 300) {
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            int primaryPositions = g_tradeExecutor.GetPrimaryPositionCount();

            // Get primary direction info
            int primaryDirection = g_primarySystem.GetDirection();
            string primaryDirStr = (primaryDirection == 1) ? "LONG" : (primaryDirection == -1) ? "SHORT" : "NONE";
            string primaryColorStr = (primaryDirection == 1) ? "Blue" : (primaryDirection == -1) ? "Magenta" : "None";

            // Get primary midline value for status
            double primaryMidline = 0.0;
            int primaryColor = 0;
            if(g_indicatorManager.GetPrimarySignal(primaryMidline, primaryColor)) {
                // Midline value available for status
            }
            else {
                primaryMidline = 0.0; // Fallback if unable to read
            }

            LOG_DEBUG("=== PERIODIC STATUS UPDATE ===");
            LOG_DEBUG("Price: " + DoubleToString(currentPrice, _Digits) +
                      " | Primary Positions: " + string(primaryPositions) +
                      " | Direction: " + primaryDirStr + " (" + primaryColorStr + ")" +
                      " | Midline: " + DoubleToString(primaryMidline, _Digits));

            lastStatusTime = currentTime;
        }
    */
// STEP 1: Update primary direction and get indicator values
    bool primaryDirectionChanged = g_primarySystem.UpdatePrimaryDirection();
    int primaryDirection = g_primarySystem.GetDirection();

// Time-gated logging for "no valid direction" to prevent spam
    static datetime lastNoDirectionLog = 0;
    static int consecutiveNoDirectionCount = 0;

    if(primaryDirection == 0) {
        consecutiveNoDirectionCount++;

        // Log every 2 minutes when no direction is available, or on first occurrence
        if(consecutiveNoDirectionCount == 1 || (currentTime - lastNoDirectionLog >= 120)) {
            LOG_DEBUG("No valid direction available (" + string(consecutiveNoDirectionCount) + " consecutive), skipping tick processing");
            lastNoDirectionLog = currentTime;
        }
        return; // Skip processing if no valid direction
    }

// Reset counter when valid direction is found
    if(consecutiveNoDirectionCount > 0) {
        consecutiveNoDirectionCount = 0;
        LOG_DEBUG("Valid direction restored - " + (primaryDirection == 1 ? "LONG" : "SHORT"));
    }

// STEP 2: Get indicator values for trading logic
    double primaryMidline;
    int primaryColor;

// Get primary midline value
    if(!g_indicatorManager.GetPrimarySignal(primaryMidline, primaryColor)) {
        primaryMidline = 0.0; // Fallback for display purposes
    }

// Get ATR values and MOD level
    double primaryATR = g_indicatorManager.GetPrimaryATR();
    double primaryMOD = g_indicatorManager.GetPrimaryMOD();

// STEP 3: Process primary trading system only
    ProcessPrimarySystem(primaryDirection, primaryATR, primaryMOD);

// STEP 4: Update information panel (single-chart only)
    UpdateInfoPanel(primaryDirection, primaryMidline, primaryATR, primaryMOD);
}

//+------------------------------------------------------------------+
//| Process Primary Trading System                                  |
//+------------------------------------------------------------------+
void ProcessPrimarySystem(int direction, double atrValue, double modLevel)
{
    if(atrValue <= 0.0) {
        LOG_DEBUG("Invalid ATR value, skipping processing");
        return;
    }

// Get current price for intra-bar execution
    double currentPrice = (direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

// Closure Detection and Re-evaluation Logic
    static double previousPrimaryVolume = -1.0;
    double currentPrimaryVolume = g_tradeExecutor.GetPrimaryPositionVolume();
    bool positionExists = g_tradeExecutor.IsPrimaryPositionOpen();

// Initialize previous volume on first run
    if(previousPrimaryVolume == -1.0) {
        previousPrimaryVolume = currentPrimaryVolume;
    }

// Detect closure events (volume decreased)
    bool closureDetected = (previousPrimaryVolume > 0.0 && currentPrimaryVolume < previousPrimaryVolume);
    bool completeClosureDetected = (previousPrimaryVolume > 0.0 && currentPrimaryVolume <= 0.001);

    if(closureDetected) {
        double volumeChange = previousPrimaryVolume - currentPrimaryVolume;

        LOG_DEBUG("Detected position closure: " + DoubleToString(volumeChange, 2) + " lots | Remaining: " + DoubleToString(currentPrimaryVolume, 2));

        if(completeClosureDetected) {
            LOG_DEBUG("Complete closure detected | System reset | Waiting for new MOD pullback");

            // Reset system state for new cycle (required for state clearing)
            g_primarySystem.Reset();

            g_stateManager.SaveState();
            
            previousPrimaryVolume = currentPrimaryVolume;

            // Return early to ensure no further processing in this tick
            // This prevents any immediate re-entry logic from executing
            return;
        }
        else {
            LOG_DEBUG("Partial closure detected | Position reclassified to Level " + string(g_primarySystem.GetCurrentLevel()) + " | Available slots: " + string(MaxEntryLevels - g_primarySystem.GetCurrentLevel()));

            // Reclassify remaining position as 1st Martingale entry from current MOD
            g_primarySystem.ReclassifyAfterPartialExit(modLevel);

            // Update remaining volume tracking
            g_primarySystem.UpdateRemainingVolumeAfterPartialClosure(currentPrimaryVolume);

            // Update average entry price to current MOD (since position is reclassified)
            // This ensures exit calculations use the new reference point
            g_primarySystem.SetAverageEntryPrice(modLevel);

            LOG_DEBUG("Partial closure - reclassified to Level " + string(g_primarySystem.GetCurrentLevel()) +
                      " | " + string(MaxEntryLevels - g_primarySystem.GetCurrentLevel()) + " slots available");
        }

        g_stateManager.SaveState();
    }

// Update volume tracking for next iteration
    previousPrimaryVolume = currentPrimaryVolume;

// Check if we should open initial position (MOD pullback logic)
    if(!g_tradeExecutor.IsPrimaryPositionOpen()) {
        // Check trading time restrictions before attempting entry
        if(!IsWithinTradingHours()) {
            static datetime lastTimeRestrictionLog = 0;
            datetime currentTime = TimeCurrent();
            if(currentTime - lastTimeRestrictionLog >= 1800) {
                LOG_DEBUG("Initial entry blocked: Outside trading hours | Current: " + TimeToString(currentTime, TIME_MINUTES) + " | Window: " + string(TradingStartHour) + ":00-" + string(TradingEndHour) + ":00");
                lastTimeRestrictionLog = currentTime;
            }
            return;
        }

        // Update primary system with current MOD level for detection logic
        g_primarySystem.SetLastMODLevel(modLevel); // Store MOD level for detection

        if(g_primarySystem.ShouldOpenPosition(direction)) {
            ENUM_ORDER_TYPE orderType = (direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

            // Calculate lot size ensuring minimum 2 lots requirement
            double lotSize = g_positionSizer.CalculateLotSize(1, atrValue);

            // Normalize to broker requirements
            const double brokerLotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            const double brokerMinLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            const double minimumRequired = MathMax(brokerLotStep * 2.0, brokerMinLot);

            // Apply normalization
            lotSize = MathMax(lotSize, minimumRequired);
            lotSize = MathRound(lotSize / brokerLotStep) * brokerLotStep;

            // Validate normalized result
            if(lotSize <= 0.0) {
                LOG_DEBUG("Initial entry failed: Invalid lot size after normalization: " + DoubleToString(lotSize, 2));
                return;
            }

            LOG_DEBUG("Initial entry executing: " + (direction == 1 ? "LONG" : "SHORT") + " | Price: " + DoubleToString(currentPrice, _Digits) + " | MOD: " + DoubleToString(modLevel, _Digits) + " | Lots: " + DoubleToString(lotSize, 2));

            if(g_tradeExecutor.OpenPrimaryPosition(orderType, lotSize, "Primary INITIAL Entry - MOD Pullback")) {
                g_primarySystem.SetDirection(direction);
                g_primarySystem.UpdateAveragePrice(currentPrice, lotSize);

                g_stateManager.SaveState();

                LOG_DEBUG("Initial entry success: " + (direction == 1 ? "LONG" : "SHORT") + " | AEP: " + DoubleToString(g_primarySystem.GetAverageEntryPrice(), _Digits) + " | Level: 1");
            }
            else {
                LOG_DEBUG("Initial entry failed: " + (direction == 1 ? "LONG" : "SHORT") + " | Error: " + g_tradeExecutor.GetLastPrimaryError() + " (" + string(g_tradeExecutor.GetLastPrimaryRetcode()) + ")");
            }
        }
        return;
    }

// Check for Martingale addition and exit conditions
    if(g_tradeExecutor.IsPrimaryPositionOpen()) {
        static double previousPrice = 0.0;

        // Initialize previous price on first run
        if(previousPrice == 0.0) {
            previousPrice = currentPrice;
        }

        // Check for exit conditions first
        ENUM_EXIT_TYPE exitType = g_primarySystem.ShouldExitPosition(currentPrice, atrValue, previousPrice);

        if(exitType != EXIT_NONE) {
            bool exitExecuted = false;

            switch(exitType) {
            case EXIT_INITIAL_50_PERCENT: {
                double initialLotRemaining = g_primarySystem.GetInitialLotRemainingVolume();
                double volumeToClose = initialLotRemaining * 0.5;

                double brokerLotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
                if(brokerLotStep > 0.0) {
                    volumeToClose = MathRound(volumeToClose / brokerLotStep) * brokerLotStep;
                }

                LOG_DEBUG("Initial 50% exit: Remaining: " + DoubleToString(initialLotRemaining, 2) + " | Closing: " + DoubleToString(volumeToClose, 2));

                if(volumeToClose > 0.0) {
                    if(g_tradeExecutor.ClosePrimaryPositionByVolume(volumeToClose, "Initial 50% Profit Target")) {
                        double newRemainingVolume = initialLotRemaining - volumeToClose;
                        g_primarySystem.UpdateRemainingVolumeAfterPartialClosure(newRemainingVolume);
                        g_primarySystem.SetInitialProfitTargetReached(true);
                        exitExecuted = true;
                        LOG_DEBUG("Initial 50% exit success | New remaining: " + DoubleToString(newRemainingVolume, 2));
                    }
                    else {
                        LOG_DEBUG("Initial 50% exit failed: " + g_tradeExecutor.GetLastPrimaryError());
                    }
                }
                break;
            }

            case EXIT_ATR_LEVEL_1: {
                LOG_DEBUG("ATR Exit L1 executing: " + DoubleToString(ExitLevel1_Percentage, 1) + "%");
                if(g_tradeExecutor.ClosePrimaryPosition(ExitLevel1_Percentage)) {
                    LOG_DEBUG("ATR Exit L1 success");
                    g_primarySystem.SetExitLevel1Executed(true);
                    exitExecuted = true;
                }
                else {
                    LOG_DEBUG("ATR Exit L1 failed: " + g_tradeExecutor.GetLastPrimaryError());
                }
                break;
            }

            case EXIT_ATR_LEVEL_2: {
                LOG_DEBUG("ATR Exit L2 executing: " + DoubleToString(ExitLevel2_Percentage, 1) + "%");
                if(g_tradeExecutor.ClosePrimaryPosition(ExitLevel2_Percentage)) {
                    LOG_DEBUG("ATR Exit L2 success");
                    g_primarySystem.SetExitLevel2Executed(true);
                    exitExecuted = true;
                }
                else {
                    LOG_DEBUG("ATR Exit L2 failed: " + g_tradeExecutor.GetLastPrimaryError());
                }
                break;
            }

            case EXIT_NONE:
            default:
                LOG_DEBUG("WARNING: Unexpected exit type in execution logic: " + EnumToString(exitType));
                break;
            }

            // Post-exit processing if any exit was executed
            if(exitExecuted) {
                if(g_tradeExecutor.IsPrimaryPositionOpen()) {
                    double remainingVolume = g_tradeExecutor.GetPrimaryPositionVolume();
                    LOG_DEBUG("Post-exit: Partial closure | Remaining: " + DoubleToString(remainingVolume, 2));

                    if(g_primarySystem.IsReclassificationNeeded()) {
                        double currentMOD = g_indicatorManager.GetPrimaryMOD();
                        if(currentMOD > 0.0) {
                            g_primarySystem.ReclassifyAfterPartialExit(currentMOD);
                            g_primarySystem.UpdateRemainingVolumeAfterPartialClosure(remainingVolume);
                            LOG_DEBUG("Post-exit reclassification: MOD: " + DoubleToString(currentMOD, _Digits) + " | Available slots: " + string(MaxEntryLevels - g_primarySystem.GetCurrentLevel()));
                        }
                    }
                }
                else {
                    LOG_DEBUG("Post-exit: Complete closure | Transitioning to idle");
                }
            }
        }

        // Check for Martingale addition
        if(g_primarySystem.ShouldAddToPosition(currentPrice, atrValue)) {
            LOG_DEBUG("Martingale addition triggered");

            int currentLevel = g_primarySystem.GetCurrentLevel();
            int nextLevel = currentLevel + 1;
            int direction = g_primarySystem.GetDirection();

            // Validate we can add another level
            if(nextLevel > MaxEntryLevels) {
                LOG_DEBUG("ERROR: Cannot add Martingale level " + string(nextLevel) + " - exceeds maximum (" + string(MaxEntryLevels) + ")");
                return;
            }

            // Calculate lot size for next Martingale level
            double lotSize = g_positionSizer.CalculateNextLevelLotSize(currentLevel, atrValue);
            if(lotSize <= 0.0) {
                LOG_DEBUG("ERROR: Invalid lot size calculated for Martingale level " + string(nextLevel) + ": " + DoubleToString(lotSize, 2));
                return;
            }

            // Get MOD reference for dynamic tracking
            double modReference = g_primarySystem.GetMODReferencePrice();
            if(modReference <= 0.0) {
                // Fallback to current MOD if no reference set
                modReference = g_indicatorManager.GetPrimaryMOD();
                if(modReference <= 0.0) {
                    LOG_DEBUG("ERROR: No valid MOD reference for Martingale level " + string(nextLevel));
                    return;
                }
            }

            // Calculate target entry price using dynamic MOD-tracking
            double targetEntryPrice = CMartingaleManager::CalculateNextEntryPrice(modReference, atrValue, currentLevel, direction);
            if(targetEntryPrice <= 0.0) {
                LOG_DEBUG("ERROR: Invalid target entry price for Martingale level " + string(nextLevel));
                return;
            }

            // Prepare order type
            ENUM_ORDER_TYPE orderType = (direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

            // Apply broker normalization to lot size
            double brokerLotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            double brokerMinLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            lotSize = MathMax(lotSize, brokerMinLot);
            lotSize = MathRound(lotSize / brokerLotStep) * brokerLotStep;

            LOG_DEBUG("Martingale entry: Level " + string(currentLevel) + ">" + string(nextLevel) + " | " + (direction == 1 ? "LONG" : "SHORT") + " | MOD: " + DoubleToString(modReference, _Digits) + " | Target: " + DoubleToString(targetEntryPrice, _Digits) + " | Lots: " + DoubleToString(lotSize, 2));

            // Execute Martingale entry
            string comment = "Martingale Level " + string(nextLevel) + " - Dynamic MOD Tracking";

            if(g_tradeExecutor.OpenPrimaryPosition(orderType, lotSize, comment)) {
                double actualExecutionPrice = g_tradeExecutor.GetLastExecutionPrice();
                g_primarySystem.UpdateAveragePrice(actualExecutionPrice, lotSize);

                double newAEP = g_primarySystem.GetAverageEntryPrice();
                double totalVolume = g_tradeExecutor.GetPrimaryPositionVolume();

                LOG_DEBUG("Martingale success: Level " + string(g_primarySystem.GetCurrentLevel()) + " | Volume: " + DoubleToString(totalVolume, 2) + " | AEP: " + DoubleToString(newAEP, _Digits) + " | Available: " + string(MaxEntryLevels - g_primarySystem.GetCurrentLevel()));

                if(g_primarySystem.GetCurrentLevel() >= MaxEntryLevels) {
                    LOG_DEBUG("Max Martingale reached | Risk monitoring active");
                    double currentPnL = g_tradeExecutor.GetPrimaryPositionProfit();
                    if(currentPnL < 0.0) {
                        g_riskManager.SetDrawdownAtMaxMartingale(currentPnL);
                        LOG_DEBUG("Drawdown stop loss activated: $" + DoubleToString(currentPnL, 2));
                    }
                }
            }
            else {
                LOG_DEBUG("Martingale failed: Level " + string(nextLevel) + " " + (direction == 1 ? "LONG" : "SHORT") + " | Error: " + g_tradeExecutor.GetLastPrimaryError() + " (" + string(g_tradeExecutor.GetLastPrimaryRetcode()) + ")");
            }
        }

        g_stateManager.SaveState();

        // Update previous price for next iteration
        previousPrice = currentPrice;
    }

// Check for drawdown stop loss when at maximum Martingale level
    if(g_primarySystem.GetCurrentLevel() == MaxEntryLevels &&
            g_tradeExecutor.IsPrimaryPositionOpen()) {

        // Set drawdown reference if reaching max level for first time
        double currentPnL = g_tradeExecutor.GetPrimaryPositionProfit();
        if(currentPnL < 0.0) {
            g_riskManager.SetDrawdownAtMaxMartingale(currentPnL);
        }

        // Check if drawdown stop loss should trigger
        if(g_riskManager.CheckDrawdownStopLoss()) {
            // Execute emergency system reset
            if(g_riskManager.ExecuteSystemReset()) {
                return; // Exit processing after emergency reset
            }
            else {
                LOG_DEBUG("CRITICAL ERROR: Emergency drawdown stop loss reset failed - manual intervention may be required");
                // Continue processing despite failure (let normal risk management handle)
            }
        }

        g_stateManager.SaveState();
    }

// Periodic state backup (every 5 minutes) - safety measure
    static datetime lastStateSave = 0;
    datetime currentTime = TimeCurrent();
    if(currentTime - lastStateSave >= 300) {
        g_stateManager.SaveState();
        lastStateSave = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Update information panel - Enhanced single-chart monitoring     |
//+------------------------------------------------------------------+
void UpdateInfoPanel(int primaryDir, double primaryMidline, double primaryATR, double primaryMOD)
{
    if(!ShowInfoPanel) {
        Comment("");
        return;
    }

    string info = "\n\n\n\n\n\n";
    info += "=== Single-Chart Dynamic MOD-Tracking EA v" + EA_VERSION + " ===\n";
    info += "Debug: " + (DebugMode ? "ON" : "OFF") + " | ";
    info += "Time: " + TimeToString(TimeCurrent(), TIME_SECONDS) + " | ";
    info += "Magic: " + string(MagicNumberPrimary) + "\n";
    info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
// MARKET CONTEXT & SIGNAL STATUS
    info += "Primary Direction: " + (primaryDir == 1 ? "[LONG] Blue" : "[SHORT] Magenta") + "\n";
    info += "Midline Value: " + DoubleToString(primaryMidline, _Digits) + "\n";
    info += "MOD Level: " + DoubleToString(primaryMOD, _Digits) + "\n";
    info += "ATR Value: " + DoubleToString(primaryATR, _Digits) + "\n";

// Show current price relative to MOD for immediate context
    double currentPrice = (primaryDir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double modDistance = MathAbs(currentPrice - primaryMOD);
    double modDistancePercent = (primaryMOD > 0) ? (modDistance / primaryMOD) * 100 : 0;

    info += "Current Price: " + DoubleToString(currentPrice, _Digits) + "\n";
    info += "Distance to MOD: " + DoubleToString(modDistance, _Digits) +
            " (" + DoubleToString(modDistancePercent, 2) + "%)\n";
    info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

// POSITION STATUS & AVERAGE ENTRY PRICE (MOST PROMINENT)
    bool hasPosition = g_tradeExecutor.IsPrimaryPositionOpen();
    if(hasPosition) {
        info += "Status: [OPEN] | Level: " + string(g_primarySystem.GetCurrentLevel()) + "/" + string(MaxEntryLevels) + "\n";
        info += "Volume: " + DoubleToString(g_tradeExecutor.GetPrimaryPositionVolume(), 2) + " lots\n";

        double currentPnL = g_tradeExecutor.GetPrimaryPositionProfit();
        string pnlStatus = (currentPnL >= 0) ? "[PROFIT]" : "[LOSS]";
        info += "P&L: " + pnlStatus + " $" + DoubleToString(currentPnL, 2) + "\n";

        // *** PROMINENTLY DISPLAY AVERAGE ENTRY PRICE (AEP) ***
        if(g_primarySystem.GetCurrentLevel() > 0) {
            double aep = g_primarySystem.GetAverageEntryPrice();
            info += "Average Entry Price (AEP): " + DoubleToString(aep, _Digits) + "\n";

            // Show MOD reference for dynamic tracking context
            double modRef = g_primarySystem.GetMODReferencePrice();
            if(modRef > 0.0) {
                double modDrift = MathAbs(aep - modRef);
                info += "MOD Reference: " + DoubleToString(modRef, _Digits) +
                        " (Drift: " + DoubleToString(modDrift, _Digits) + ")\n";
            }
        }
    }
    else {
        info += "Status: [CLOSED] - IDLE STATE\n";
        info += "System: Monitoring for MOD pullback opportunity\n";

        // Show MOD proximity for entry readiness
        double tolerance = primaryATR * 0.1; // 10% of ATR as tolerance
        bool atMODLevel = (modDistance <= tolerance);
        string readinessStatus = atMODLevel ? "[READY]" : "[MONITORING]";
        info += "Entry Readiness: " + readinessStatus + " " +
                (atMODLevel ? "(At MOD)" : "(Away from MOD)") + "\n";
    }
    info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

// DYNAMIC MARTINGALE LEVELS (Enhanced with visual indicators)
    if(hasPosition && g_primarySystem.GetCurrentLevel() > 0) {
        if(g_primarySystem.GetCurrentLevel() < MaxEntryLevels) {
            int currentLevel = g_primarySystem.GetCurrentLevel();
            int direction = g_primarySystem.GetDirection();
            double modRef = g_primarySystem.GetMODReferencePrice();
            double currentMODRef = (modRef > 0.0) ? modRef : primaryMOD;

            // Show next immediate level
            int nextLevel = currentLevel + 1;
            double nextEntryPrice = CMartingaleManager::CalculateNextEntryPrice(currentMODRef, primaryATR, currentLevel, direction);
            if(nextEntryPrice > 0.0) {
                double distanceToNext = MathAbs(currentPrice - nextEntryPrice);
                double distancePercent = (nextEntryPrice > 0) ? (distanceToNext / nextEntryPrice) * 100 : 0;

                info += ">> Next Entry Level " + string(nextLevel) + ": " + DoubleToString(nextEntryPrice, _Digits) + "\n";
                info += "   Distance: " + DoubleToString(distanceToNext, _Digits) +
                        " (" + DoubleToString(distancePercent, 2) + "%)\n";

                // Show trigger proximity
                bool nearTrigger = (direction == 1) ? (currentPrice <= nextEntryPrice * 1.02) : (currentPrice >= nextEntryPrice * 0.98);
                if(nearTrigger) {
                    info += "    APPROACHING TRIGGER ZONE!\n";
                }
            }

            // Show one level ahead for planning
            if(nextLevel < MaxEntryLevels) {
                double nextEntryPrice2 = CMartingaleManager::CalculateNextEntryPrice(currentMODRef, primaryATR, nextLevel, direction);
                if(nextEntryPrice2 > 0.0) {
                    info += ">> Future Level " + string(nextLevel + 1) + ": " + DoubleToString(nextEntryPrice2, _Digits) + "\n";
                }
            }

            // Show available slots
            int availableSlots = MaxEntryLevels - currentLevel;
            info += "Available Slots: " + string(availableSlots) + " / " + string(MaxEntryLevels) + "\n";
        }
        else {
            info += "    MAXIMUM MARTINGALE LEVEL REACHED (" + string(MaxEntryLevels) + ")\n";
            info += "    No additional entries available\n";
        }
        info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    }

// EXIT TARGETS (AEP-Based with enhanced visualization)
    if(hasPosition && g_primarySystem.GetCurrentLevel() > 0) {
        double aep = g_primarySystem.GetAverageEntryPrice();
        int direction = g_primarySystem.GetDirection();

        // Calculate exit levels
        double exitLevel1 = (direction == 1) ? aep + (ExitLevel1_ATR * primaryATR) : aep - (ExitLevel1_ATR * primaryATR);
        double exitLevel2 = (direction == 1) ? aep + (ExitLevel2_ATR * primaryATR) : aep - (ExitLevel2_ATR * primaryATR);

        // Show exit level 1
        if(!g_primarySystem.IsExitLevel1Executed()) {
            double distanceToExit1 = MathAbs(currentPrice - exitLevel1);
            double progressToExit1 = (exitLevel1 != aep) ? (1.0 - (distanceToExit1 / MathAbs(exitLevel1 - aep))) * 100 : 0;
            progressToExit1 = MathMax(0, MathMin(100, progressToExit1));

            info += "[TARGET] Exit Level 1: " + DoubleToString(exitLevel1, _Digits) +
                    " (" + DoubleToString(ExitLevel1_Percentage, 0) + "%)\n";
            info += "         Progress: " + DoubleToString(progressToExit1, 1) + "% | Distance: " +
                    DoubleToString(distanceToExit1, _Digits) + "\n";
        }
        else {
            info += "[DONE] Exit Level 1: EXECUTED (" + DoubleToString(ExitLevel1_Percentage, 0) + "%)\n";
        }

        // Show exit level 2
        if(!g_primarySystem.IsExitLevel2Executed()) {
            double distanceToExit2 = MathAbs(currentPrice - exitLevel2);
            double progressToExit2 = (exitLevel2 != aep) ? (1.0 - (distanceToExit2 / MathAbs(exitLevel2 - aep))) * 100 : 0;
            progressToExit2 = MathMax(0, MathMin(100, progressToExit2));

            info += "[TARGET] Exit Level 2: " + DoubleToString(exitLevel2, _Digits) +
                    " (" + DoubleToString(ExitLevel2_Percentage, 0) + "%)\n";
            info += "         Progress: " + DoubleToString(progressToExit2, 1) + "% | Distance: " +
                    DoubleToString(distanceToExit2, _Digits) + "\n";
        }
        else {
            info += "[DONE] Exit Level 2: EXECUTED (" + DoubleToString(ExitLevel2_Percentage, 0) + "%)\n";
        }

        info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    }

// DRAWDOWN STOP LOSS (Enhanced with visual status indicators)
    info += "Stop Loss Percentage: " + DoubleToString(DrawdownStopLossPercentage, 1) + "%\n";

    if(hasPosition && g_primarySystem.GetCurrentLevel() == MaxEntryLevels) {
        info += "Status: [ACTIVE] (Max Martingale reached)\n";

        double currentPnL = g_tradeExecutor.GetPrimaryPositionProfit();
        if(currentPnL < 0.0) {
            double additionalDrawdownAllowed = MathAbs(currentPnL) * (DrawdownStopLossPercentage / 100.0);
            double triggerLevel = currentPnL - additionalDrawdownAllowed;
            double distanceToTrigger = currentPnL - triggerLevel;
            double triggerProximity = (additionalDrawdownAllowed > 0) ? (distanceToTrigger / additionalDrawdownAllowed) * 100 : 0;

            info += "Current P&L: $" + DoubleToString(currentPnL, 2) + "\n";
            info += "Trigger Level: $" + DoubleToString(triggerLevel, 2) + "\n";
            info += "Additional Risk: $" + DoubleToString(additionalDrawdownAllowed, 2) + "\n";
            info += "Safety Buffer: " + DoubleToString(triggerProximity, 1) + "%\n";

            // Visual warning based on proximity to trigger
            if(triggerProximity < 25) {
                info += "    CRITICAL: Very close to stop loss trigger!\n";
            }
            else if(triggerProximity < 50) {
                info += "    WARNING: Approaching stop loss trigger zone\n";
            }
            else {
                info += "[SAFE] Adequate buffer from stop loss trigger\n";
            }
        }
        else {
            info += "Current P&L: $" + DoubleToString(currentPnL, 2) + " (Profitable)\n";
            info += "[SAFE] Position in profit, stop loss inactive\n";
        }
    }
    else if(hasPosition) {
        info += "Status: [STANDBY] (Activates at Level " + string(MaxEntryLevels) + ")\n";
        int levelsToActivation = MaxEntryLevels - g_primarySystem.GetCurrentLevel();
        info += "Levels to Activation: " + string(levelsToActivation) + "\n";
    }
    else {
        info += "Status: [INACTIVE] (No position)\n";
    }
    info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

// RISK MANAGEMENT SUMMARY
    double combinedPnL = g_riskManager.GetCombinedPnL();
    string pnlStatus = (combinedPnL >= 0) ? "[PROFIT]" : "[LOSS]";
    info += "Combined P&L: " + pnlStatus + " $" + DoubleToString(combinedPnL, 2) + "\n";
    info += "Profit Threshold: $" + DoubleToString(MinimumProfitThreshold, 2) + "\n";

// Show reset readiness
    bool thresholdMet = (combinedPnL >= MinimumProfitThreshold);
    bool atMaxLevel = (g_primarySystem.GetCurrentLevel() >= MaxEntryLevels);
    info += "Reset Eligible: " + (thresholdMet && atMaxLevel ? "[YES]" : "[NO]") + "\n";

    if(thresholdMet && atMaxLevel) {
        info += "    System ready for profitable reset when position closes\n";
    }
    else if(!thresholdMet && atMaxLevel) {
        info += "    At max level but profit threshold not met\n";
    }
    else if(thresholdMet && !atMaxLevel) {
        info += "[INFO] Profit threshold met, not at max level\n";
    }

    info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

// TIME RESTRICTIONS (Compact display)
    if(EnableTimeRestrictions) {
        bool withinHours = IsWithinTradingHours();
        datetime currentTime = TimeCurrent();
        MqlDateTime timeStruct;
        TimeToStruct(currentTime, timeStruct);

        info += "--- TIME RESTRICTIONS -------------------------------------------\n";
        info += "Status: " + (withinHours ? "[ACTIVE]" : "[BLOCKED]") + " | ";
        info += "Window: " + string(TradingStartHour) + ":00-" + string(TradingEndHour) + ":00 | ";
        info += "Current: " + IntegerToString(timeStruct.hour, 2, '0') + ":" + IntegerToString(timeStruct.min, 2, '0') + "\n";
        info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    }

    Comment(info);
}
//+------------------------------------------------------------------+
