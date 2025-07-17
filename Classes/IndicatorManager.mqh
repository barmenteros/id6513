//+------------------------------------------------------------------+
//|                                           IndicatorManager.mqh  |
//|                         Copyright © 2025, barmenteros FX        |
//|                                  https://barmenteros.com        |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, barmenteros FX"
#property link      "https://barmenteros.com"

#include "..\Utils\DebugUtils.mqh"

//+------------------------------------------------------------------+
//| Indicator Manager Class - Single Chart Only                      |
//+------------------------------------------------------------------+
class CIndicatorManager {
private:
    int m_primaryHandle;
    int m_barPosition;

public:
    CIndicatorManager() : m_primaryHandle(INVALID_HANDLE), m_barPosition(1) {}
    ~CIndicatorManager()
    {
        DeInit();
    }

    // Core indicator management
    bool Init();
    void DeInit();

    // Bar position control
    void SetBarPosition(int position)
    {
        m_barPosition = position;    // 0=current, 1=previous, etc.
    }
    int GetBarPosition() const
    {
        return m_barPosition;
    }

    // Primary chart indicator data retrieval
    bool GetPrimarySignal(double &midlineValue, int &colorIndex);
    double GetPrimaryATR();
    double GetPrimaryMOD();
};

//+------------------------------------------------------------------+
//| Initialize primary indicator                                     |
//+------------------------------------------------------------------+
bool CIndicatorManager::Init()
{
    // Initialize Primary Timeframe Midline Indicator
    m_primaryHandle = iCustom(
                          _Symbol,                    // Symbol
                          _Period,                    // Current chart timeframe
                          CUSTOM_INDICATOR_NAME,      // Indicator name
                          // All indicator parameters in exact order from the source
                          VertTextPct,               // {-1=Auto, 0->100}
                          RiskPerTrade,              // Risk per trade ($)
                          PlotRiskOnScreen,          // Plot risk on screen (1=Yes, 0=No)
                          MinLotSize,                // Minimum lot size for CFD
                          Price,                     // Price type for main calculation
                          MODDPrice,                 // Price type for MODD calculation
                          NoOfATRsToPlot,            // Number of ATRs to plot (3-6)
                          EffRatioLengthL,           // Efficiency ratio length (Long)
                          FastAvgLengthL,            // Fast MA length (Long)
                          SlowAvgLengthL,            // Slow MA length (Long)
                          EffRatioLengthS,           // Efficiency ratio length (Short)
                          FastAvgLengthS,            // Fast MA length (Short)
                          SlowAvgLengthS,            // Slow MA length (Short)
                          ModEffRatioLength,         // MOD efficiency ratio length
                          ModFastAvgLength,          // MOD fast MA length
                          ModSlowAvgLength,          // MOD slow MA length
                          ATRLength,                 // ATR length
                          ATREnvelopes,              // ATR envelope multiplier
                          BandColor,                 // Band color
                          ColourUp,                  // Up color
                          ColourDn,                  // Down color
                          MidLineOnOrOff,            // Midline on/off
                          ModLineOnOrOff             // MOD line on/off
                      );

    if(m_primaryHandle == INVALID_HANDLE) {
        string errorMsg = "CRITICAL ERROR: Failed to load Midline_Trader indicator for current timeframe (" + EnumToString(_Period) + ")";
        Print(errorMsg);
        Alert(errorMsg + "\nPlease ensure Midline_Trader.mq5 is compiled and available in your indicators folder.");
        return false;
    }

    // Wait for indicators to calculate initial values
    Sleep(100);

    // Test primary indicator (Buffer 0 = MidLine, Buffer 1 = Color)
    double testBuffer[1];
    double testColorBuffer[1];

    if(CopyBuffer(m_primaryHandle, 0, 0, 1, testBuffer) <= 0 ||
            CopyBuffer(m_primaryHandle, 1, 0, 1, testColorBuffer) <= 0) {
        Print("ERROR: Primary Midline indicator not providing data");
        DeInit();
        return false;
    }

    LOG_DEBUG("SUCCESS: Midline indicator initialized successfully");
    LOG_DEBUG("Primary Handle: " + string(m_primaryHandle));

    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize indicator                                           |
//+------------------------------------------------------------------+
void CIndicatorManager::DeInit()
{
    if(m_primaryHandle != INVALID_HANDLE) {
        IndicatorRelease(m_primaryHandle);
        m_primaryHandle = INVALID_HANDLE;
        Print("Primary indicator handle released");
    }
}

//+------------------------------------------------------------------+
//| Get primary signal                                               |
//+------------------------------------------------------------------+
bool CIndicatorManager::GetPrimarySignal(double &midlineValue, int &colorIndex)
{
    if(m_primaryHandle == INVALID_HANDLE) {
        Print("ERROR: Primary indicator handle is invalid");
        return false;
    }

    // Get Midline value from buffer 0 at specified bar position
    double midlineBuffer[1];
    if(CopyBuffer(m_primaryHandle, 0, m_barPosition, 1, midlineBuffer) <= 0) {
        Print("ERROR: Failed to read Primary Midline value");
        return false;
    }

    // Get color index from buffer 1 at specified bar position
    double colorBuffer[1];
    if(CopyBuffer(m_primaryHandle, 1, m_barPosition, 1, colorBuffer) <= 0) {
        Print("ERROR: Failed to read Primary Midline color");
        return false;
    }

    // Return the values
    midlineValue = midlineBuffer[0];
    colorIndex = (int)colorBuffer[0];  // 0=Blue/Long, 1=Magenta/Short

    // Debug output for verification (print only when bar changes)
    static datetime lastPrimaryBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, _Period, m_barPosition);
    if(currentBarTime != lastPrimaryBarTime) {
        LOG_DEBUG("PRIMARY Signal - Bar: " + TimeToString(currentBarTime) +
                  " | Midline: " + DoubleToString(midlineValue, _Digits) +
                  " | Color: " + (colorIndex == 0 ? "BLUE (Long)" : "MAGENTA (Short)"));
        lastPrimaryBarTime = currentBarTime;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Get primary ATR                                                  |
//+------------------------------------------------------------------+
double CIndicatorManager::GetPrimaryATR()
{
    if(m_primaryHandle == INVALID_HANDLE) {
        Print("ERROR: Primary indicator handle is invalid for ATR reading");
        return 0.0;
    }

    // Get MidLine value (buffer 0)
    double midlineBuffer[1];
    if(CopyBuffer(m_primaryHandle, 0, m_barPosition, 1, midlineBuffer) <= 0) {
        Print("ERROR: Failed to read Primary Midline for ATR calculation");
        return 0.0;
    }

    // Get ATRAbove1 value (buffer 2 based on indicator source code)
    double atrAbove1Buffer[1];
    if(CopyBuffer(m_primaryHandle, 2, m_barPosition, 1, atrAbove1Buffer) <= 0) {
        Print("ERROR: Failed to read Primary ATRAbove1 buffer");
        return 0.0;
    }

    // Calculate base ATR: ATR = (ATRAbove1 - MidLine) / ATREnvelopes
    double baseATR = (atrAbove1Buffer[0] - midlineBuffer[0]) / ATREnvelopes;

    return baseATR;
}

//+------------------------------------------------------------------+
//| Get Primary MOD value for pullback entry detection              |
//+------------------------------------------------------------------+
double CIndicatorManager::GetPrimaryMOD()
{
    if(m_primaryHandle == INVALID_HANDLE) {
        Print("ERROR: Primary indicator handle is invalid for MOD reading");
        return 0.0;
    }

    // Get MOD value from buffer 14 (based on indicator source code)
    double modBuffer[1];
    if(CopyBuffer(m_primaryHandle, 14, m_barPosition, 1, modBuffer) <= 0) {
        Print("ERROR: Failed to read Primary MOD buffer");
        return 0.0;
    }

    return modBuffer[0];
}
//+------------------------------------------------------------------+
