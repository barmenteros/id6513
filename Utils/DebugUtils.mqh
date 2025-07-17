//+------------------------------------------------------------------+
//|                                              DebugUtils.mqh     |
//|                         Copyright © 2025, barmenteros FX        |
//|                                  https://barmenteros.com        |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, barmenteros FX"
#property link      "https://barmenteros.com"

//+------------------------------------------------------------------+
//| Enhanced Debug Print with Function Context                      |
//+------------------------------------------------------------------+
void DebugPrint(const string message, const string functionName = "")
{
    if(DebugMode) {
        string logMsg = "[" + TimeToString(TimeCurrent(), TIME_SECONDS) + "]";
        if(functionName != "") {
            logMsg += "[" + functionName + "]";
        }
        logMsg += ": " + message;
        Print(logMsg);
    }
}

//+------------------------------------------------------------------+
//| Debug Macro for Automatic Function Context                      |
//+------------------------------------------------------------------+
#define LOG_DEBUG(msg) DebugPrint(msg, __FUNCTION__)