//+------------------------------------------------------------------+
//|                                             RiskManager.mqh     |
//|                         Copyright © 2025, barmenteros FX        |
//|                                  https://barmenteros.com        |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, barmenteros FX"
#property link      "https://barmenteros.com"

#include "..\Utils\DebugUtils.mqh"

//+------------------------------------------------------------------+
//| Risk Manager Class                                              |
//+------------------------------------------------------------------+
class CRiskManager {
private:
    double m_totalClosedProfits;
    double m_maxDrawdown;
    double m_primaryClosedProfits;
    double m_totalClosedVolume;
    bool m_resetConditionMet;
    datetime m_systemStartTime;
    double m_drawdownAtMaxMartingale; // For drawdown stop loss

public:
    CRiskManager() : m_totalClosedProfits(0), m_maxDrawdown(0),
        m_primaryClosedProfits(0), m_totalClosedVolume(0),
        m_resetConditionMet(false), m_systemStartTime(0),
        m_drawdownAtMaxMartingale(0) {}

    // Core risk management methods
    bool ShouldRestartSystem();
    void UpdateProfitLoss();
    bool CheckCombinedPnLResetCondition();
    bool CheckDrawdownStopLoss(); // NEW: Drawdown stop loss check
    double CalculatePrimaryDrawdown();
    double CalculateCombinedProfit();
    bool ExecuteSystemReset();
    void InitializeSystemStartTime();
    void ResetCounters();
    void SetDrawdownAtMaxMartingale(double drawdown); // NEW: Set drawdown reference

    // Getters
    double GetTotalClosedProfits() const
    {
        return m_totalClosedProfits;
    }
    double GetPrimaryClosedProfits() const
    {
        return m_primaryClosedProfits;
    }
    double GetCombinedPnL()
    {
        return CalculateCombinedProfit();
    }
    void SetSystemStartTime(datetime startTime)
    {
        m_systemStartTime = startTime;
    }
};

//+------------------------------------------------------------------+
//| Update profit/loss tracking with minimal logging               |
//+------------------------------------------------------------------+
void CRiskManager::UpdateProfitLoss()
{
    // This method is called every second via timer
    // Only log significant changes or periodically for status

    static datetime lastPnLUpdateLog = 0;
    static double lastLoggedProfit = 0.0;
    datetime currentTime = TimeCurrent();

    double currentCombinedProfit = CalculateCombinedProfit();
    double profitChange = MathAbs(currentCombinedProfit - lastLoggedProfit);

    // Only log if significant change (>$10) or every 5 minutes for status
    if(DebugMode && (profitChange > 10.0 || (currentTime - lastPnLUpdateLog >= 300))) {
        LOG_DEBUG("=== P&L UPDATE ===");
        LOG_DEBUG("Combined P&L: $" + DoubleToString(currentCombinedProfit, 2));

        if(profitChange > 10.0) {
            LOG_DEBUG("Significant change: $" + DoubleToString(profitChange, 2));
        }

        lastPnLUpdateLog = currentTime;
        lastLoggedProfit = currentCombinedProfit;
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CRiskManager::InitializeSystemStartTime()
{
    m_systemStartTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Execute complete system reset - Only when no positions remain   |
//+------------------------------------------------------------------+
bool CRiskManager::ExecuteSystemReset()
{
    LOG_DEBUG("=== COMPLETE SYSTEM RESET EVALUATION ===");

    // Check if any primary positions are still open
    bool primaryPositionExists = g_tradeExecutor.IsPrimaryPositionOpen();
    double primaryVolume = g_tradeExecutor.GetPrimaryPositionVolume();

    LOG_DEBUG("Primary Position Check:");
    LOG_DEBUG("  Position Exists: " + (primaryPositionExists ? "YES" : "NO"));
    LOG_DEBUG("  Current Volume: " + DoubleToString(primaryVolume, 2));

    // CRITICAL: Only execute reset if NO positions remain open
    if(primaryPositionExists || primaryVolume > 0.001) {
        LOG_DEBUG("=== SYSTEM RESET BLOCKED ===");
        LOG_DEBUG("Reason: Positions still exist - cannot reset while trading");
        LOG_DEBUG("Reset will be available after complete position closure");
        return false;
    }

    LOG_DEBUG("=== EXECUTING COMPLETE SYSTEM RESET ===");
    LOG_DEBUG("Confirmed: No open positions detected");

    // Close any remaining positions as safety measure (should be none at this point)
    bool allPositionsClosed = true;

    if(g_tradeExecutor.IsPrimaryPositionOpen()) {
        LOG_DEBUG("Safety closure: Closing any remaining primary positions");
        if(!g_tradeExecutor.CloseAllPrimaryPositions()) {
            LOG_DEBUG("WARNING: Failed to close remaining primary positions");
            LOG_DEBUG("Error: " + g_tradeExecutor.GetLastPrimaryError());
            allPositionsClosed = false;
        }
        else {
            LOG_DEBUG("Safety closure: All remaining positions closed successfully");
        }
    }

    if(!allPositionsClosed) {
        LOG_DEBUG("=== SYSTEM RESET FAILED ===");
        LOG_DEBUG("Reason: Could not close all positions");
        return false;
    }

    // Reset all system components for fresh cycle
    LOG_DEBUG("=== RESETTING SYSTEM COMPONENTS ===");

    // 1. Reset primary trading system (clears all position tracking)
    g_primarySystem.Reset();
    LOG_DEBUG("✓ Primary trading system reset");

    // 2. Reset risk manager counters
    ResetCounters();
    LOG_DEBUG("✓ Risk manager counters reset");

    // 3. Reset system start time for new cycle
    m_systemStartTime = TimeCurrent();
    LOG_DEBUG("✓ System start time reset to: " + TimeToString(m_systemStartTime));

    // 4. Reset drawdown tracking
    m_drawdownAtMaxMartingale = 0.0;
    LOG_DEBUG("✓ Drawdown stop loss tracking reset");

    // 5. Clear reset condition flag
    m_resetConditionMet = false;
    LOG_DEBUG("✓ Reset condition flag cleared");

    LOG_DEBUG("=== COMPLETE SYSTEM RESET SUCCESSFUL ===");
    LOG_DEBUG("System Status: IDLE - Ready for new MOD pullback opportunity");
    LOG_DEBUG("Next Action: Monitor for fresh initial entry conditions");
    LOG_DEBUG("Available Levels: " + string(MaxEntryLevels) + " (full Martingale sequence)");

    // Log the transition state
    LOG_DEBUG("=== TRANSITION TO IDLE STATE ===");
    LOG_DEBUG("EA will now:");
    LOG_DEBUG("  1. Monitor primary chart Midline direction");
    LOG_DEBUG("  2. Wait for MOD pullback conditions");
    LOG_DEBUG("  3. Execute fresh initial entry when conditions are met");
    LOG_DEBUG("  4. Begin new Martingale sequence from scratch");

    return true;
}

//+------------------------------------------------------------------+
//| Reset risk manager counters for new cycle                       |
//+------------------------------------------------------------------+
void CRiskManager::ResetCounters()
{
    LOG_DEBUG("=== RESETTING RISK MANAGER COUNTERS ===");

    // Store previous values for logging
    double prevTotalProfit = m_totalClosedProfits;
    double prevPrimaryProfit = m_primaryClosedProfits;
    double prevVolume = m_totalClosedVolume;
    double prevMaxDrawdown = m_maxDrawdown;

    // Reset all counters
    m_totalClosedProfits = 0.0;
    m_primaryClosedProfits = 0.0;
    m_totalClosedVolume = 0.0;
    m_maxDrawdown = 0.0;
    m_drawdownAtMaxMartingale = 0.0;
    m_resetConditionMet = false;

    LOG_DEBUG("Counter Reset Summary:");
    LOG_DEBUG("  Total Closed Profits: $" + DoubleToString(prevTotalProfit, 2) + " → $0.00");
    LOG_DEBUG("  Primary Closed Profits: $" + DoubleToString(prevPrimaryProfit, 2) + " → $0.00");
    LOG_DEBUG("  Total Closed Volume: " + DoubleToString(prevVolume, 2) + " → 0.00");
    LOG_DEBUG("  Max Drawdown: $" + DoubleToString(prevMaxDrawdown, 2) + " → $0.00");
    LOG_DEBUG("  Drawdown at Max Martingale: Reset to $0.00");
    LOG_DEBUG("  Reset Condition: Cleared");
    LOG_DEBUG("=== COUNTERS RESET COMPLETE ===");
}

//+------------------------------------------------------------------+
//| Check if system should restart (enhanced for complete closure)  |
//+------------------------------------------------------------------+
bool CRiskManager::ShouldRestartSystem()
{
    // Check combined P&L reset condition (existing logic)
    bool combinedPnLMet = CheckCombinedPnLResetCondition();

    // Check if at maximum Martingale level
    bool atMaxLevel = (g_primarySystem.GetCurrentLevel() >= MaxEntryLevels);

    // Check if minimum profit threshold is met
    double combinedProfit = CalculateCombinedProfit();
    bool profitThresholdMet = (combinedProfit >= MinimumProfitThreshold);

    // Only suggest restart if conditions are met and we're at max level
    bool shouldRestart = combinedPnLMet && atMaxLevel && profitThresholdMet;

    // Time-gated restart condition logging (every 5 minutes to avoid spam)
    static datetime lastRestartConditionLog = 0;
    datetime currentTime = TimeCurrent();

    if(DebugMode && shouldRestart && (currentTime - lastRestartConditionLog >= 300)) {
        LOG_DEBUG("=== SYSTEM RESTART CONDITIONS MET ===");
        LOG_DEBUG("Combined P&L Reset: " + (combinedPnLMet ? "MET" : "NOT MET"));
        LOG_DEBUG("At Max Martingale Level: " + (atMaxLevel ? "YES" : "NO"));
        LOG_DEBUG("Profit Threshold: " + (profitThresholdMet ? "MET" : "NOT MET"));
        LOG_DEBUG("Combined Profit: $" + DoubleToString(combinedProfit, 2));
        LOG_DEBUG("Note: Actual reset will only execute after complete position closure");
        lastRestartConditionLog = currentTime;
    }

    return shouldRestart;
}

//+------------------------------------------------------------------+
//| Check combined P&L reset condition (existing enhanced logic)    |
//+------------------------------------------------------------------+
bool CRiskManager::CheckCombinedPnLResetCondition()
{
    // Calculate primary drawdown
    double primaryDrawdown = CalculatePrimaryDrawdown();

    // Calculate combined profit (closed trades + current open profits)
    double combinedProfit = CalculateCombinedProfit();

    // Two conditions must be met for reset eligibility:
    // 1. Combined profit must offset primary drawdown
    bool drawdownOffsetMet = (combinedProfit > MathAbs(primaryDrawdown));

    // 2. Combined profit must meet minimum threshold
    bool thresholdMet = (combinedProfit >= MinimumProfitThreshold);

    // Time-gated detailed analysis logging (every 2 minutes to reduce spam)
    static datetime lastResetAnalysisLog = 0;
    datetime currentTime = TimeCurrent();

    if(DebugMode && (currentTime - lastResetAnalysisLog >= 120)) {
        LOG_DEBUG("=== COMBINED P&L RESET ANALYSIS (PERIODIC) ===");
        LOG_DEBUG("Primary Drawdown: $" + DoubleToString(primaryDrawdown, 2));
        LOG_DEBUG("Combined Profit: $" + DoubleToString(combinedProfit, 2));
        LOG_DEBUG("Minimum Threshold: $" + DoubleToString(MinimumProfitThreshold, 2));
        LOG_DEBUG("Drawdown Offset: " + (drawdownOffsetMet ? "MET" : "NOT MET"));
        LOG_DEBUG("Threshold Met: " + (thresholdMet ? "MET" : "NOT MET"));
        LOG_DEBUG("Overall Condition: " + (drawdownOffsetMet && thresholdMet ? "SATISFIED" : "NOT SATISFIED"));
        lastResetAnalysisLog = currentTime;
    }

    return (drawdownOffsetMet && thresholdMet);
}

//+------------------------------------------------------------------+
//| Calculate primary drawdown                                       |
//+------------------------------------------------------------------+
double CRiskManager::CalculatePrimaryDrawdown()
{
    if(!g_tradeExecutor.IsPrimaryPositionOpen()) {
        return 0.0;
    }

    double currentProfit = g_tradeExecutor.GetPrimaryPositionProfit();

    // Drawdown is negative profit (loss)
    double drawdown = (currentProfit < 0.0) ? currentProfit : 0.0;

    LOG_DEBUG("Primary Drawdown Calculation: $" + DoubleToString(drawdown, 2));

    return drawdown;
}

//+------------------------------------------------------------------+
//| Calculate combined profit from all sources                      |
//+------------------------------------------------------------------+
double CRiskManager::CalculateCombinedProfit()
{
    // Get current open profit from primary system
    double currentOpenProfit = g_tradeExecutor.IsPrimaryPositionOpen() ?
                               g_tradeExecutor.GetPrimaryPositionProfit() : 0.0;

    // Combine closed profits with current open profits
    double combinedProfit = m_primaryClosedProfits + currentOpenProfit;

    // Time-gated logging to prevent spam (every 60 seconds)
    static datetime lastCombinedProfitLog = 0;
    datetime currentTime = TimeCurrent();

    if(DebugMode && (currentTime - lastCombinedProfitLog >= 60)) {
        LOG_DEBUG("=== COMBINED PROFIT CALCULATION (PERIODIC) ===");
        LOG_DEBUG("  Closed Profits: $" + DoubleToString(m_primaryClosedProfits, 2));
        LOG_DEBUG("  Current Open P&L: $" + DoubleToString(currentOpenProfit, 2));
        LOG_DEBUG("  Combined Total: $" + DoubleToString(combinedProfit, 2));
        lastCombinedProfitLog = currentTime;
    }

    return combinedProfit;
}

//+------------------------------------------------------------------+
//| Check drawdown stop loss for emergency risk management          |
//+------------------------------------------------------------------+
bool CRiskManager::CheckDrawdownStopLoss()
{
    // Only active when at maximum Martingale level with open position
    if(g_primarySystem.GetCurrentLevel() != MaxEntryLevels) {
        return false; // Not at max level - stop loss not active
    }

    if(!g_tradeExecutor.IsPrimaryPositionOpen()) {
        return false; // No position open - nothing to check
    }

    // Get current primary position P&L
    double currentPrimaryPnL = g_tradeExecutor.GetPrimaryPositionProfit();

    // Initialize drawdown reference if not set (first time at max level)
    if(m_drawdownAtMaxMartingale == 0.0 && currentPrimaryPnL < 0.0) {
        m_drawdownAtMaxMartingale = currentPrimaryPnL;
        LOG_DEBUG("=== DRAWDOWN STOP LOSS ACTIVATED ===");
        LOG_DEBUG("Maximum Martingale level reached - Initializing drawdown reference");
        LOG_DEBUG("Reference Drawdown: $" + DoubleToString(m_drawdownAtMaxMartingale, 2));
        LOG_DEBUG("Stop Loss Percentage: " + DoubleToString(DrawdownStopLossPercentage, 2) + "%");

        // Calculate and log the trigger level for transparency
        double additionalDrawdown = MathAbs(m_drawdownAtMaxMartingale) * (DrawdownStopLossPercentage / 100.0);
        double triggerLevel = m_drawdownAtMaxMartingale - additionalDrawdown;
        LOG_DEBUG("Stop Loss Trigger Level: $" + DoubleToString(triggerLevel, 2));
        LOG_DEBUG("Current P&L: $" + DoubleToString(currentPrimaryPnL, 2));
        LOG_DEBUG("=== MONITORING ACTIVE ===");

        return false; // Don't trigger on initialization
    }

    // Skip check if reference drawdown not properly set
    if(m_drawdownAtMaxMartingale >= 0.0) {
        return false; // Reference should be negative (loss) to be valid
    }

    // Calculate stop loss trigger level
    // Formula: CurrentDrawdown + (CurrentDrawdown * DrawdownStopLossPercentage / 100.0)
    // Since drawdown is negative, this creates a more negative (worse) threshold
    double additionalDrawdownAmount = MathAbs(m_drawdownAtMaxMartingale) * (DrawdownStopLossPercentage / 100.0);
    double stopLossTriggerLevel = m_drawdownAtMaxMartingale - additionalDrawdownAmount;

    // Check if current P&L has breached the stop loss level
    bool stopLossTriggered = (currentPrimaryPnL <= stopLossTriggerLevel);

    // Log monitoring status periodically (every 30 seconds to avoid spam)
    static datetime lastMonitoringLog = 0;
    datetime currentTime = TimeCurrent();
    if(currentTime - lastMonitoringLog >= 30) {
        LOG_DEBUG("=== DRAWDOWN STOP LOSS MONITORING ===");
        LOG_DEBUG("Reference Drawdown: $" + DoubleToString(m_drawdownAtMaxMartingale, 2));
        LOG_DEBUG("Current P&L: $" + DoubleToString(currentPrimaryPnL, 2));
        LOG_DEBUG("Stop Loss Trigger: $" + DoubleToString(stopLossTriggerLevel, 2));
        LOG_DEBUG("Additional Drawdown Allowed: $" + DoubleToString(additionalDrawdownAmount, 2) +
                  " (" + DoubleToString(DrawdownStopLossPercentage, 2) + "%)");
        LOG_DEBUG("Status: " + (stopLossTriggered ? "TRIGGERED - EMERGENCY STOP" : "MONITORING"));
        lastMonitoringLog = currentTime;
    }

    if(stopLossTriggered) {
        LOG_DEBUG("=== DRAWDOWN STOP LOSS TRIGGERED ===");
        LOG_DEBUG("EMERGENCY RISK MANAGEMENT ACTIVATION");
        LOG_DEBUG("Reference Drawdown: $" + DoubleToString(m_drawdownAtMaxMartingale, 2));
        LOG_DEBUG("Current P&L: $" + DoubleToString(currentPrimaryPnL, 2));
        LOG_DEBUG("Stop Loss Trigger: $" + DoubleToString(stopLossTriggerLevel, 2));
        LOG_DEBUG("Drawdown Breach: $" + DoubleToString(currentPrimaryPnL - stopLossTriggerLevel, 2));
        LOG_DEBUG("Stop Loss Percentage: " + DoubleToString(DrawdownStopLossPercentage, 2) + "%");
        LOG_DEBUG("=== EXECUTING EMERGENCY SYSTEM RESET ===");

        // Reset the drawdown reference to prevent repeated triggers
        m_drawdownAtMaxMartingale = 0.0;
    }

    return stopLossTriggered;
}

//+------------------------------------------------------------------+
//| Set drawdown reference when reaching max Martingale level       |
//+------------------------------------------------------------------+
void CRiskManager::SetDrawdownAtMaxMartingale(double drawdown)
{
    // Only set if this is a valid drawdown (negative value) and we're at max level
    if(drawdown < 0.0 && g_primarySystem.GetCurrentLevel() == MaxEntryLevels) {
        // Only update if not already set (prevent overwriting during max level)
        if(m_drawdownAtMaxMartingale == 0.0) {
            m_drawdownAtMaxMartingale = drawdown;
            LOG_DEBUG("=== DRAWDOWN REFERENCE SET ===");
            LOG_DEBUG("Max Martingale level reached - Drawdown reference captured");
            LOG_DEBUG("Reference Drawdown: $" + DoubleToString(m_drawdownAtMaxMartingale, 2));
            LOG_DEBUG("Stop Loss will trigger at: " + DoubleToString(DrawdownStopLossPercentage, 2) + "% additional loss");
        }
    }
}
//+------------------------------------------------------------------+
