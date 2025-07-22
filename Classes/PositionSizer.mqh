//+------------------------------------------------------------------+
//|                                           PositionSizer.mqh     |
//|                         Copyright © 2025, barmenteros FX        |
//|                                  https://barmenteros.com        |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, barmenteros FX"
#property link      "https://barmenteros.com"

#include "..\Utils\DebugUtils.mqh"
#include <Custom\PositionSizeCalculator.mqh>

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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CPositionSizer::CalculateLotSize(int level, double atrValue)
{
    double baseLotSize = 0.0;

    if(SizingMethod == SIZING_FIXED_LOTS) {
        // Fixed lot sizing with multiplier progression
        baseLotSize = InitialLotSize * MathPow(LotMultiplier, level - 1);
    }
    else { // Percentage-based sizing
        // Initialize the position size calculator
        PositionSizeCalculator calculator;

        // Calculate money to risk (RiskPercent% of account equity)
        double moneyToRisk = calculator.CalculateMoneyToRisk(RiskPercentage, kModeEquity, 0);

        // Get current price for potential calculations
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

        // Since we don't have specific stop loss here, we use a simpler calculation method
        // that gives us lot size based on money to risk without considering stop loss distance
        baseLotSize = calculator.CalculatePositionSize(currentPrice, 0, _Symbol, moneyToRisk);
    }

// Apply broker requirements and divisibility validation
    double brokerMinLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double brokerLotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minimumRequired = MathMax(brokerLotStep * 2.0, brokerMinLot);

// Ensure minimum requirements are met
    baseLotSize = MathMax(baseLotSize, minimumRequired);

// Ensure multiple of broker lot step for proper divisibility
    baseLotSize = MathRound(baseLotSize / brokerLotStep) * brokerLotStep;

    LOG_DEBUG("Position Sizing: Level " + string(level) +
              " | Initial Input: " + DoubleToString(InitialLotSize, 2) +
              " | Calculated: " + DoubleToString(InitialLotSize * MathPow(LotMultiplier, level - 1), 2) +
              " | Min Required: " + DoubleToString(minimumRequired, 2) +
              " | Final: " + DoubleToString(baseLotSize, 2));

    return baseLotSize;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CPositionSizer::CalculateNextLevelLotSize(int currentLevel, double atrValue)
{
// Validate we can add another level
    if(CMartingaleManager::IsMaxLevelReached(currentLevel)) {
        LOG_DEBUG("Cannot calculate - at maximum levels (" + string(currentLevel) + ")");
        return 0.0;
    }

    int nextLevel = currentLevel + 1;
    return CalculateLotSize(nextLevel, atrValue);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CPositionSizer::GetMinimumLotSize() const
{
    double brokerLotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minimumRequired = MathMax(brokerLotStep * 2.0, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
    return MathMax(InitialLotSize, minimumRequired);
}
//+------------------------------------------------------------------+
