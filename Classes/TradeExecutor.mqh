//+------------------------------------------------------------------+
//|                                            TradeExecutor.mqh    |
//|                         Copyright © 2025, barmenteros FX        |
//|                                  https://barmenteros.com        |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, barmenteros FX"
#property link      "https://barmenteros.com"

#include <Trade\Trade.mqh>
#include "..\Utils\DebugUtils.mqh"

//+------------------------------------------------------------------+
//| Trade Executor Class                                            |
//+------------------------------------------------------------------+
class CTradeExecutor {
private:
    CTrade m_primaryTrade;   // Trade object for primary system

public:
    CTradeExecutor()
    {
        // Initialize trade object with magic number
        m_primaryTrade.SetExpertMagicNumber(MagicNumberPrimary);
        m_primaryTrade.LogLevel(LOG_LEVEL_ERRORS);
    }

    // Primary system trading methods
    bool OpenPrimaryPosition(ENUM_ORDER_TYPE orderType, double lots, const string comment = "");
    bool ClosePrimaryPosition(double percentage);
    bool ClosePrimaryPositionByVolume(double volumeToClose, const string comment = "Partial Volume Close");
    bool CloseAllPrimaryPositions();
    bool ModifyPrimarySLTP(double sl, double tp);

    // Utility methods
    bool IsPrimaryPositionOpen();
    double GetPrimaryPositionVolume();
    double GetPrimaryPositionProfit();
    ENUM_POSITION_TYPE GetPrimaryPositionType();

    // Access to CTrade error information
    uint GetLastPrimaryRetcode()
    {
        return m_primaryTrade.ResultRetcode();
    }
    string GetLastPrimaryError()
    {
        return m_primaryTrade.ResultRetcodeDescription();
    }
    double GetLastExecutionPrice()
    {
        return m_primaryTrade.ResultPrice();
    }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CTradeExecutor::OpenPrimaryPosition(ENUM_ORDER_TYPE orderType, double lots, const string comment)
{
    if(orderType == ORDER_TYPE_BUY) {
        return m_primaryTrade.Buy(lots, _Symbol, 0.0, 0.0, 0.0, comment);
    }
    else if(orderType == ORDER_TYPE_SELL) {
        return m_primaryTrade.Sell(lots, _Symbol, 0.0, 0.0, 0.0, comment);
    }
    return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CTradeExecutor::ClosePrimaryPosition(double percentage)
{
    if(percentage <= 0.0 || percentage > 100.0) {
        LOG_DEBUG("Trade Executor: Invalid close percentage: " + DoubleToString(percentage, 2));
        return false;
    }

// Get total primary position volume
    double totalVolume = GetPrimaryPositionVolume();
    if(totalVolume <= 0.0) {
        LOG_DEBUG("Trade Executor: No primary positions to close");
        return false;
    }

// Calculate volume to close
    double volumeToClose = (totalVolume * percentage) / 100.0;

// Apply broker lot step normalization
    double brokerLotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(brokerLotStep > 0.0) {
        volumeToClose = MathRound(volumeToClose / brokerLotStep) * brokerLotStep;
    }

// Normalize volume using CTrade validation
    double normalizedVolume = m_primaryTrade.CheckVolume(_Symbol, volumeToClose,
                              SymbolInfoDouble(_Symbol, SYMBOL_BID),
                              ORDER_TYPE_SELL);

// Get broker's minimum tradable lot size for intelligent closure handling
    const double brokerMinLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    const double tolerance = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 100; // Tolerance for floating point comparison

    bool result = false;

// --- ENHANCED LOGIC: Handle untradable partial volumes ---
// Check if the calculated partial volume is too small (e.g., 0.005)
// AND if the remaining total volume is at or very near the broker's minimum tradable lot (e.g., 0.01)
    if(normalizedVolume < brokerMinLot && MathAbs(totalVolume - brokerMinLot) < tolerance) {
        LOG_DEBUG("Intelligent closure triggered: Partial volume " + DoubleToString(volumeToClose, 4) +
                  " below broker minimum " + DoubleToString(brokerMinLot, 4) +
                  " - closing 100% of remaining " + DoubleToString(totalVolume, 4) + " lots");

        // Execute full closure of the remaining minimum position
        result = m_primaryTrade.PositionClose(_Symbol);

        if(result) {
            LOG_DEBUG("Intelligent closure success: Full closure executed for minimum lot position - profit realized, triggers re-evaluation");
        }
        else {
            LOG_DEBUG("Intelligent closure failed: " + m_primaryTrade.ResultRetcodeDescription() + " (" + string(m_primaryTrade.ResultRetcode()) + ")");
        }
    }
// --- END ENHANCED LOGIC ---
    else if(normalizedVolume <= 0.0) {
        LOG_DEBUG("Trade Executor: Invalid volume after normalization: " + DoubleToString(volumeToClose, 2) +
                  " -> " + DoubleToString(normalizedVolume, 2) + " (cannot trade zero or negative volume)");
        return false;
    }
    else if(normalizedVolume >= totalVolume * 0.99) { // Close all if very close to 100%
        LOG_DEBUG("Trade Executor: Closing all primary positions (normalized volume close to 100%)");
        result = m_primaryTrade.PositionClose(_Symbol);
    }
    else {
        LOG_DEBUG("Trade Executor: Standard partial close - Volume: " + DoubleToString(normalizedVolume, 2) +
                  " of " + DoubleToString(totalVolume, 2));
        result = m_primaryTrade.PositionClosePartial(_Symbol, normalizedVolume);
    }

    if(!result) {
        LOG_DEBUG("Trade Executor: Close failed - " + m_primaryTrade.ResultRetcodeDescription());
    }

    return result;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CTradeExecutor::ClosePrimaryPositionByVolume(double volumeToClose, const string comment = "Partial Volume Close")
{
    if(volumeToClose <= 0.0) {
        LOG_DEBUG("Trade Executor: Invalid volume to close: " + DoubleToString(volumeToClose, 2));
        return false;
    }

// Get total primary position volume
    double totalVolume = GetPrimaryPositionVolume();
    if(totalVolume <= 0.0) {
        LOG_DEBUG("Trade Executor: No primary positions to close");
        return false;
    }

    if(volumeToClose > totalVolume) {
        LOG_DEBUG("Trade Executor: Volume to close (" + DoubleToString(volumeToClose, 2) +
                  ") exceeds total volume (" + DoubleToString(totalVolume, 2) + ")");
        return false;
    }

// Apply broker lot step normalization
    double brokerLotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(brokerLotStep > 0.0) {
        volumeToClose = MathRound(volumeToClose / brokerLotStep) * brokerLotStep;
    }

// Normalize volume using CTrade validation
    double normalizedVolume = m_primaryTrade.CheckVolume(_Symbol, volumeToClose,
                              SymbolInfoDouble(_Symbol, SYMBOL_BID),
                              ORDER_TYPE_SELL);

// Get broker's minimum tradable lot size for intelligent closure handling
    const double brokerMinLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    const double tolerance = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 100; // Tolerance for floating point comparison

    bool result = false;

// --- ENHANCED LOGIC: Handle untradable partial volumes ---
// Check if the calculated partial volume is too small (e.g., 0.005)
// AND if the remaining total volume is at or very near the broker's minimum tradable lot (e.g., 0.01)
    if(normalizedVolume < brokerMinLot && MathAbs(totalVolume - brokerMinLot) < tolerance) {
        LOG_DEBUG("Intelligent volume closure triggered: Requested volume " + DoubleToString(volumeToClose, 4) +
                  " below broker minimum " + DoubleToString(brokerMinLot, 4) +
                  " - closing 100% of remaining " + DoubleToString(totalVolume, 4) + " lots");

        // Execute full closure of the remaining minimum position
        result = m_primaryTrade.PositionClose(_Symbol);

        if(result) {
            LOG_DEBUG("Intelligent volume closure success: Full closure executed for minimum lot position - " + comment + " (adjusted to full closure)");
        }
        else {
            LOG_DEBUG("Intelligent volume closure failed: " + m_primaryTrade.ResultRetcodeDescription() + " (" + string(m_primaryTrade.ResultRetcode()) + ")");
        }
    }
// --- END ENHANCED LOGIC ---
    else if(normalizedVolume <= 0.0) {
        LOG_DEBUG("Trade Executor: Invalid volume after normalization: " + DoubleToString(volumeToClose, 2));
        return false;
    }
    else if(normalizedVolume >= totalVolume * 0.99) { // Close all if very close to 100%
        LOG_DEBUG("Trade Executor: Closing all primary positions (normalized volume close to total)");
        result = m_primaryTrade.PositionClose(_Symbol);
    }
    else {
        LOG_DEBUG("Trade Executor: Specific volume close - Target: " + DoubleToString(volumeToClose, 2) +
                  " | Normalized: " + DoubleToString(normalizedVolume, 2) +
                  " | Total: " + DoubleToString(totalVolume, 2));
        result = m_primaryTrade.PositionClosePartial(_Symbol, normalizedVolume);
    }

    if(!result) {
        LOG_DEBUG("Trade Executor: Volume-specific close failed - " + m_primaryTrade.ResultRetcodeDescription());
    }

    return result;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CTradeExecutor::CloseAllPrimaryPositions()
{
    return m_primaryTrade.PositionClose(_Symbol);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CTradeExecutor::ModifyPrimarySLTP(double sl, double tp)
{
    return m_primaryTrade.PositionModify(_Symbol, sl, tp);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CTradeExecutor::IsPrimaryPositionOpen()
{
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetSymbol(i) == _Symbol) {
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumberPrimary) {
                return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CTradeExecutor::GetPrimaryPositionVolume()
{
    double totalVolume = 0.0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetSymbol(i) == _Symbol) {
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumberPrimary) {
                totalVolume += PositionGetDouble(POSITION_VOLUME);
            }
        }
    }
    return totalVolume;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CTradeExecutor::GetPrimaryPositionProfit()
{
    double totalProfit = 0.0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetSymbol(i) == _Symbol) {
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumberPrimary) {
                totalProfit += PositionGetDouble(POSITION_PROFIT);     // Floating P&L
                totalProfit += PositionGetDouble(POSITION_SWAP);       // Rollover costs
//                totalProfit += PositionGetDouble(POSITION_COMMISSION); // Trading costs
            }
        }
    }
    return totalProfit;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_POSITION_TYPE CTradeExecutor::GetPrimaryPositionType()
{
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetSymbol(i) == _Symbol) {
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumberPrimary) {
                return (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            }
        }
    }
    return (ENUM_POSITION_TYPE) - 1; // No position found
}
//+------------------------------------------------------------------+
