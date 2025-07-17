//+------------------------------------------------------------------+
//|                                           PositionSizer.mqh     |
//|                         Copyright © 2025, barmenteros FX        |
//|                                  https://barmenteros.com        |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, barmenteros FX"
#property link      "https://barmenteros.com"

#include "..\Utils\DebugUtils.mqh"

//+------------------------------------------------------------------+
//| Position Sizer Class                                            |
//+------------------------------------------------------------------+
class CPositionSizer {
public:
    CPositionSizer() {}

    double CalculateLotSize(int level, double atrValue);
    double CalculateNextLevelLotSize(int currentLevel, double atrValue);
    double GetMinimumLotSize() const;
};

// Method stubs - will be implemented in subsequent tasks
double CPositionSizer::CalculateLotSize(int level, double atrValue) { return InitialLotSize; }
double CPositionSizer::CalculateNextLevelLotSize(int currentLevel, double atrValue) { return InitialLotSize; }
double CPositionSizer::GetMinimumLotSize() const { return InitialLotSize; }