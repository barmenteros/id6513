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

    if(profitChange > 10.0 || (currentTime - lastPnLUpdateLog >= 300)) {
        LOG_DEBUG("P&L update: Combined: $" + DoubleToString(currentCombinedProfit, 2) +
                  (profitChange > 10.0 ? " | Change: $" + DoubleToString(profitChange, 2) : ""));
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
    LOG_DEBUG("System reset evaluation: Position check starting");

    bool primaryPositionExists = g_tradeExecutor.IsPrimaryPositionOpen();
    double primaryVolume = g_tradeExecutor.GetPrimaryPositionVolume();

    LOG_DEBUG("Position check: Exists: " + (primaryPositionExists ? "YES" : "NO") + " | Volume: " + DoubleToString(primaryVolume, 2));

    if(primaryPositionExists || primaryVolume > 0.001) {
        LOG_DEBUG("System reset blocked: Positions still exist | Reset available after complete closure");
        return false;
    }

    LOG_DEBUG("System reset executing: No open positions confirmed");

    // Close any remaining positions as safety measure
    bool allPositionsClosed = true;
    if(g_tradeExecutor.IsPrimaryPositionOpen()) {
        LOG_DEBUG("Safety closure: Closing remaining primary positions");
        if(!g_tradeExecutor.CloseAllPrimaryPositions()) {
            LOG_DEBUG("Safety closure failed: " + g_tradeExecutor.GetLastPrimaryError());
            allPositionsClosed = false;
        }
    }

    if(!allPositionsClosed) {
        LOG_DEBUG("System reset failed: Could not close all positions");
        return false;
    }

    LOG_DEBUG("System components resetting: Primary system | Risk manager | Counters");
    g_primarySystem.Reset();
    ResetCounters();

    m_systemStartTime = TimeCurrent();
    m_drawdownAtMaxMartingale = 0.0;
    m_resetConditionMet = false;

    LOG_DEBUG("System reset complete: Status IDLE | Ready for new MOD pullback | Available levels: " + string(MaxEntryLevels) + " | Next: Monitor Midline direction > MOD pullback > Execute fresh entry");

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

    LOG_DEBUG("Risk manager counters reset: " +
              "Total profits: $" + DoubleToString(prevTotalProfit, 2) + ">$0 | " +
              "Primary profits: $" + DoubleToString(prevPrimaryProfit, 2) + ">$0 | " +
              "Volume: " + DoubleToString(prevVolume, 2) + ">0 | " +
              "Max drawdown: $" + DoubleToString(prevMaxDrawdown, 2) + ">$0");
}

//+------------------------------------------------------------------+
//| Check if system should restart (enhanced for complete closure)  |
//+------------------------------------------------------------------+
bool CRiskManager::ShouldRestartSystem()
{
    bool combinedPnLMet = CheckCombinedPnLResetCondition();
    bool atMaxLevel = (g_primarySystem.GetCurrentLevel() >= MaxEntryLevels);
    double combinedProfit = CalculateCombinedProfit();
    bool profitThresholdMet = (combinedProfit >= MinimumProfitThreshold);
    bool shouldRestart = combinedPnLMet && atMaxLevel && profitThresholdMet;

    static datetime lastRestartConditionLog = 0;
    datetime currentTime = TimeCurrent();

    if(shouldRestart && (currentTime - lastRestartConditionLog >= 300)) {
        LOG_DEBUG("System restart conditions met: P&L reset: " + (combinedPnLMet ? "YES" : "NO") +
                  " | Max level: " + (atMaxLevel ? "YES" : "NO") +
                  " | Profit threshold: " + (profitThresholdMet ? "YES" : "NO") +
                  " | Combined: $" + DoubleToString(combinedProfit, 2) +
                  " | Reset available after complete closure");
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
    bool drawdownOffsetMet = (combinedProfit > MathAbs(primaryDrawdown));
    bool thresholdMet = (combinedProfit >= MinimumProfitThreshold);

    static datetime lastResetAnalysisLog = 0;
    datetime currentTime = TimeCurrent();

    if(currentTime - lastResetAnalysisLog >= 120) {
        LOG_DEBUG("Reset analysis: Drawdown: $" + DoubleToString(primaryDrawdown, 2) +
                  " | Profit: $" + DoubleToString(combinedProfit, 2) +
                  " | Threshold: $" + DoubleToString(MinimumProfitThreshold, 2) +
                  " | Status: " + (drawdownOffsetMet && thresholdMet ? "SATISFIED" : "NOT SATISFIED"));
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

//    LOG_DEBUG("Primary Drawdown Calculation: $" + DoubleToString(drawdown, 2));

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

    if(m_drawdownAtMaxMartingale == 0.0 && currentPrimaryPnL < 0.0) {
        m_drawdownAtMaxMartingale = currentPrimaryPnL;
        double additionalDrawdown = MathAbs(m_drawdownAtMaxMartingale) * (DrawdownStopLossPercentage / 100.0);
        double triggerLevel = m_drawdownAtMaxMartingale - additionalDrawdown;

        LOG_DEBUG("Drawdown stop loss activated: Reference: $" + DoubleToString(m_drawdownAtMaxMartingale, 2) +
                  " | Stop: " + DoubleToString(DrawdownStopLossPercentage, 2) + "% | Trigger: $" + DoubleToString(triggerLevel, 2));
        return false;
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

    static datetime lastMonitoringLog = 0;
    datetime currentTime = TimeCurrent();
    if(currentTime - lastMonitoringLog >= 30) {
        LOG_DEBUG("Drawdown monitoring: Reference: $" + DoubleToString(m_drawdownAtMaxMartingale, 2) +
                  " | Current: $" + DoubleToString(currentPrimaryPnL, 2) +
                  " | Trigger: $" + DoubleToString(stopLossTriggerLevel, 2) +
                  " | Status: " + (stopLossTriggered ? "TRIGGERED" : "MONITORING"));
        lastMonitoringLog = currentTime;
    }

    if(stopLossTriggered) {
        LOG_DEBUG("EMERGENCY: Drawdown stop loss triggered | Reference: $" + DoubleToString(m_drawdownAtMaxMartingale, 2) +
                  " | Current: $" + DoubleToString(currentPrimaryPnL, 2) +
                  " | Breach: $" + DoubleToString(currentPrimaryPnL - stopLossTriggerLevel, 2));
        m_drawdownAtMaxMartingale = 0.0;
    }

    return stopLossTriggered;
}

//+------------------------------------------------------------------+
//| Set drawdown reference when reaching max Martingale level       |
//+------------------------------------------------------------------+
void CRiskManager::SetDrawdownAtMaxMartingale(double drawdown)
{
    if(drawdown < 0.0 && g_primarySystem.GetCurrentLevel() == MaxEntryLevels) {
        if(m_drawdownAtMaxMartingale == 0.0) {
            m_drawdownAtMaxMartingale = drawdown;
            LOG_DEBUG("Drawdown reference set: $" + DoubleToString(m_drawdownAtMaxMartingale, 2) +
                      " | Stop loss: " + DoubleToString(DrawdownStopLossPercentage, 2) + "%");
        }
    }
}
//+------------------------------------------------------------------+
