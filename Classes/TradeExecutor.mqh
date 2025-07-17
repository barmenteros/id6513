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
    int GetPrimaryPositionCount();
    ENUM_POSITION_TYPE GetPrimaryPositionType();

    // Access to CTrade error information
    uint GetLastPrimaryRetcode() { return m_primaryTrade.ResultRetcode(); }
    string GetLastPrimaryError() { return m_primaryTrade.ResultRetcodeDescription(); }
};

// Method stubs - will be implemented in subsequent tasks
bool CTradeExecutor::OpenPrimaryPosition(ENUM_ORDER_TYPE orderType, double lots, const string comment) { return false; }
bool CTradeExecutor::ClosePrimaryPosition(double percentage) { return false; }
bool CTradeExecutor::ClosePrimaryPositionByVolume(double volumeToClose, const string comment) { return false; }
bool CTradeExecutor::CloseAllPrimaryPositions() { return false; }
bool CTradeExecutor::ModifyPrimarySLTP(double sl, double tp) { return false; }
bool CTradeExecutor::IsPrimaryPositionOpen() { return false; }
double CTradeExecutor::GetPrimaryPositionVolume() { return 0.0; }
double CTradeExecutor::GetPrimaryPositionProfit() { return 0.0; }
int CTradeExecutor::GetPrimaryPositionCount() { return 0; }
ENUM_POSITION_TYPE CTradeExecutor::GetPrimaryPositionType() { return (ENUM_POSITION_TYPE)-1; }