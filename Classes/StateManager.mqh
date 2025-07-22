//+------------------------------------------------------------------+
//|                                            StateManager.mqh     |
//|                         Copyright © 2025, barmenteros FX        |
//|                                  https://barmenteros.com        |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, barmenteros FX"
#property link      "https://barmenteros.com"

#include "..\Utils\DebugUtils.mqh"
#include <Jason.mqh>

//+------------------------------------------------------------------+
//| State Manager Class - Simple JSON-based state persistence      |
//+------------------------------------------------------------------+
class CStateManager {
private:
    string m_filename;
    string m_symbol;
    int m_magicNumber;

public:
    CStateManager(string symbol, int magicNumber)
    {
        m_symbol = symbol;
        m_magicNumber = magicNumber;
        m_filename = StringFormat("EA_State_%s_%d.json", symbol, magicNumber);
    }

    // Core state management
    bool SaveState();
    bool LoadState();
    bool IsStateFileValid();
    void CleanupStateFile();
    void HandleDeinit(int reason)
    {
        bool shouldSave = true;
        bool shouldCleanup = false;

        switch(reason) {
        // Only clean up state file if context is truly invalid
        case REASON_REMOVE: // User manually removed EA
        case REASON_ACCOUNT: // Different account
        case REASON_INITFAILED: // Corrupted state
            shouldSave = false;
            shouldCleanup = true;
            break;
        // Preserve state for all other scenarios
        default:
            shouldSave = true;
            shouldCleanup = false;
            break;
        }

        if(shouldSave) {
            SaveState();
            LOG_DEBUG("State preserved (reason: " + string(reason) + ")");
        }

        if(shouldCleanup) {
            CleanupStateFile();
            LOG_DEBUG("State cleaned up (reason: " + string(reason) + ")");
        }
    }

private:
    // Helper functions
    CJAVal CreateStateJSON();
    bool ApplyLoadedState(CJAVal &json);
    bool ValidateLoadedState(CJAVal &json);
    string GetSafeFilename();
};

//+------------------------------------------------------------------+
//| Save current EA state to JSON file                              |
//+------------------------------------------------------------------+
bool CStateManager::SaveState()
{
// Create JSON from current state
    CJAVal json = CreateStateJSON();

// Serialize to string
    string jsonContent = json.Serialize();
    if(jsonContent == "") {
        LOG_DEBUG("Failed to serialize JSON");
        return false;
    }

// Write to file using atomic write pattern (temp file + rename)
    string tempFilename = m_filename + ".tmp";

    int fileHandle = FileOpen(tempFilename, FILE_WRITE | FILE_TXT);
    if(fileHandle == INVALID_HANDLE) {
        LOG_DEBUG("Cannot create temp file: " + tempFilename);
        return false;
    }

    FileWriteString(fileHandle, jsonContent);
    FileClose(fileHandle);

// Atomic rename (if supported by filesystem)
    FileDelete(m_filename); // Delete old file first
    if(!FileMove(tempFilename, 0, m_filename, 0)) {
        // Fallback: copy content if move fails
        LOG_DEBUG("File move failed, using fallback method");

        int sourceHandle = FileOpen(tempFilename, FILE_READ | FILE_TXT);
        int destHandle = FileOpen(m_filename, FILE_WRITE | FILE_TXT);

        if(sourceHandle != INVALID_HANDLE && destHandle != INVALID_HANDLE) {
            string content = "";
            while(!FileIsEnding(sourceHandle)) {
                content += FileReadString(sourceHandle);
                if(!FileIsEnding(sourceHandle)) content += "\n";
            }
            FileWriteString(destHandle, content);
            FileClose(sourceHandle);
            FileClose(destHandle);
            FileDelete(tempFilename); // Clean up temp file
        }
        else {
            LOG_DEBUG("Fallback save method failed");
            if(sourceHandle != INVALID_HANDLE) FileClose(sourceHandle);
            if(destHandle != INVALID_HANDLE) FileClose(destHandle);
            return false;
        }
    }

//    LOG_DEBUG("State saved successfully to " + m_filename);
    return true;
}

//+------------------------------------------------------------------+
//| Load EA state from JSON file                                    |
//+------------------------------------------------------------------+
bool CStateManager::LoadState()
{
// Check if file exists
    if(!FileIsExist(m_filename)) {
        LOG_DEBUG("No state file found: " + m_filename);
        return false;
    }

// Read file content
    int fileHandle = FileOpen(m_filename, FILE_READ | FILE_TXT);
    if(fileHandle == INVALID_HANDLE) {
        LOG_DEBUG("Cannot open state file: " + m_filename);
        return false;
    }

    string jsonContent = "";
    while(!FileIsEnding(fileHandle)) {
        jsonContent += FileReadString(fileHandle);
        if(!FileIsEnding(fileHandle)) jsonContent += "\n";
    }
    FileClose(fileHandle);

    if(jsonContent == "") {
        LOG_DEBUG("Empty state file");
        return false;
    }

// Parse JSON
    CJAVal json;
    if(!json.Deserialize(jsonContent)) {
        LOG_DEBUG("Failed to parse JSON from state file");
        return false;
    }

// Validate loaded state
    if(!ValidateLoadedState(json)) {
        LOG_DEBUG("State file validation failed");
        return false;
    }

// Apply loaded state to EA
    bool success = ApplyLoadedState(json);

    if(success) {
        LOG_DEBUG("State loaded successfully from " + m_filename);
    }
    else {
        LOG_DEBUG("Failed to apply loaded state");
    }

    return success;
}

//+------------------------------------------------------------------+
//| Create JSON object from current EA state                        |
//+------------------------------------------------------------------+
CJAVal CStateManager::CreateStateJSON()
{
    CJAVal json;

// Metadata
    json["metadata"]["symbol"] = m_symbol;
    json["metadata"]["magicNumber"] = m_magicNumber;
    json["metadata"]["version"] = "2.0";
    json["metadata"]["lastUpdate"] = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
    json["metadata"]["timeframe"] = EnumToString(_Period);

// Position data
    bool hasPosition = g_tradeExecutor.IsPrimaryPositionOpen();
    json["position"]["exists"] = hasPosition;

    if(hasPosition) {
        json["position"]["direction"] = g_primarySystem.GetDirection();
        json["position"]["currentLevel"] = g_primarySystem.GetCurrentLevel();
        json["position"]["totalVolume"] = g_tradeExecutor.GetPrimaryPositionVolume();
        json["position"]["averageEntryPrice"] = NormalizeDouble(g_primarySystem.GetAverageEntryPrice(), _Digits);
        json["position"]["initialEntryPrice"] = NormalizeDouble(g_primarySystem.GetInitialEntryPrice(), _Digits);
        json["position"]["modReferencePrice"] = NormalizeDouble(g_primarySystem.GetMODReferencePrice(), _Digits);
        json["position"]["hasInitialPosition"] = g_primarySystem.HasInitialPosition();
        json["position"]["initialProfitTargetReached"] = g_primarySystem.IsInitialProfitTargetReached();
        json["position"]["initialLotSize"] = g_primarySystem.GetInitialLotSize();
        json["position"]["initialLotRemainingVolume"] = g_primarySystem.GetInitialLotRemainingVolume();
        json["position"]["isReclassified"] = g_primarySystem.IsReclassified();

        // Extreme price tracking
        json["position"]["lowestEntryPrice"] = NormalizeDouble(g_primarySystem.GetLowestEntryPrice(), _Digits);
        json["position"]["highestEntryPrice"] = NormalizeDouble(g_primarySystem.GetHighestEntryPrice(), _Digits);
    }

// Exit tracking
    json["exitTracking"]["exitLevel1Executed"] = g_primarySystem.IsExitLevel1Executed();
    json["exitTracking"]["exitLevel2Executed"] = g_primarySystem.IsExitLevel2Executed();

// Validation data (for integrity checking)
    if(hasPosition) {
        // Get first position ticket for validation
        ulong positionTicket = 0;
        datetime openTime = 0;

        for(int i = 0; i < PositionsTotal(); i++) {
            if(PositionGetSymbol(i) == m_symbol &&
                    PositionGetInteger(POSITION_MAGIC) == m_magicNumber) {
                positionTicket = PositionGetInteger(POSITION_TICKET);
                openTime = (datetime)PositionGetInteger(POSITION_TIME);
                break;
            }
        }

        json["validation"]["positionTicket"] = (long)positionTicket;
        json["validation"]["openTime"] = TimeToString(openTime, TIME_DATE | TIME_SECONDS);
    }

    return json;
}

//+------------------------------------------------------------------+
//| Apply loaded state to EA components                             |
//+------------------------------------------------------------------+
bool CStateManager::ApplyLoadedState(CJAVal &json)
{
    if(json["position"]["exists"].ToBool()) {
        // Extract all state values
        int direction = (int)json["position"]["direction"].ToInt();
        int currentLevel = (int)json["position"]["currentLevel"].ToInt();
        double averageEntryPrice = json["position"]["averageEntryPrice"].ToDbl();
        double initialEntryPrice = json["position"]["initialEntryPrice"].ToDbl();
        double modReferencePrice = json["position"]["modReferencePrice"].ToDbl();
        double initialLotSize = json["position"]["initialLotSize"].ToDbl();
        double initialLotRemainingVolume = json["position"]["initialLotRemainingVolume"].ToDbl();
        bool hasInitialPosition = json["position"]["hasInitialPosition"].ToBool();
        bool initialProfitTargetReached = json["position"]["initialProfitTargetReached"].ToBool();
        double lowestEntryPrice = json["position"]["lowestEntryPrice"].ToDbl();
        double highestEntryPrice = json["position"]["highestEntryPrice"].ToDbl();

        // ✅ ACTUALLY RESTORE THE STATE
        g_primarySystem.SetDirection(direction);
        g_primarySystem.SetCurrentLevel(currentLevel);
        g_primarySystem.SetAverageEntryPrice(averageEntryPrice);
        g_primarySystem.SetInitialEntryPrice(initialEntryPrice);
        g_primarySystem.SetMODReferencePrice(modReferencePrice);  // ✅ CRITICAL FIX
        g_primarySystem.SetInitialLotSize(initialLotSize);
        g_primarySystem.SetInitialLotRemainingVolume(initialLotRemainingVolume);
        g_primarySystem.SetHasInitialPosition(hasInitialPosition);
        g_primarySystem.SetInitialProfitTargetReached(initialProfitTargetReached);
        g_primarySystem.SetLowestEntryPrice(lowestEntryPrice);
        g_primarySystem.SetHighestEntryPrice(highestEntryPrice);

        // Restore exit tracking
        bool exitLevel1Executed = json["exitTracking"]["exitLevel1Executed"].ToBool();
        bool exitLevel2Executed = json["exitTracking"]["exitLevel2Executed"].ToBool();
        g_primarySystem.SetExitLevel1Executed(exitLevel1Executed);
        g_primarySystem.SetExitLevel2Executed(exitLevel2Executed);

        LOG_DEBUG("=== COMPLETE STATE RESTORATION ===");
        LOG_DEBUG("Direction: " + (direction == 1 ? "LONG" : "SHORT"));
        LOG_DEBUG("Current Level: " + string(currentLevel));
        LOG_DEBUG("MOD Reference: " + DoubleToString(modReferencePrice, _Digits));
        LOG_DEBUG("Average Entry Price: " + DoubleToString(averageEntryPrice, _Digits));
        LOG_DEBUG("Initial Entry Price: " + DoubleToString(initialEntryPrice, _Digits));
        LOG_DEBUG("Exit L1/L2: " + (exitLevel1Executed ? "DONE" : "PENDING") +
                  "/" + (exitLevel2Executed ? "DONE" : "PENDING"));
    }
    else {
        LOG_DEBUG("State Recovery: No position to restore");
    }

    return true;
}

//+------------------------------------------------------------------+
//| Validate loaded state against current positions                 |
//+------------------------------------------------------------------+
bool CStateManager::ValidateLoadedState(CJAVal &json)
{
// Basic JSON structure validation
    if(json["metadata"].Size() == 0 || json["position"].Size() == 0) {
        LOG_DEBUG("State Validation: Missing required JSON sections");
        return false;
    }

// Symbol and magic number validation
    string savedSymbol = json["metadata"]["symbol"].ToStr();
    long savedMagic = json["metadata"]["magicNumber"].ToInt();

    if(savedSymbol != m_symbol || savedMagic != m_magicNumber) {
        LOG_DEBUG("State Validation: Symbol/Magic mismatch - File: " + savedSymbol +
                  "/" + string(savedMagic) + " Expected: " + m_symbol + "/" + string(m_magicNumber));
        return false;
    }

// Position existence validation
    bool fileHasPosition = json["position"]["exists"].ToBool();
    bool actualHasPosition = g_tradeExecutor.IsPrimaryPositionOpen();

    if(fileHasPosition != actualHasPosition) {
        LOG_DEBUG("State Validation: Position existence mismatch - File: " +
                  (fileHasPosition ? "YES" : "NO") + " Actual: " + (actualHasPosition ? "YES" : "NO"));
        // This might be acceptable if position was closed between saves
        LOG_DEBUG("State Validation: Allowing position existence mismatch (position may have been closed)");
    }

// If position exists in both file and reality, validate ticket
    if(fileHasPosition && actualHasPosition) {
        if(json["validation"].Size() > 0) {
            long savedTicket = json["validation"]["positionTicket"].ToInt();

            // Check if saved ticket still exists
            bool ticketFound = false;
            for(int i = 0; i < PositionsTotal(); i++) {
                if(PositionGetSymbol(i) == m_symbol &&
                        PositionGetInteger(POSITION_MAGIC) == m_magicNumber &&
                        PositionGetInteger(POSITION_TICKET) == savedTicket) {
                    ticketFound = true;
                    break;
                }
            }

            if(!ticketFound) {
                LOG_DEBUG("State Validation: Position ticket not found - may be different position");
                // Don't fail validation - position might have been modified/closed/reopened
            }
            else {
                LOG_DEBUG("State Validation: Position ticket verified successfully");
            }
        }
    }

    LOG_DEBUG("State Validation: Passed");
    return true;
}

//+------------------------------------------------------------------+
//| Check if state file exists and is readable                      |
//+------------------------------------------------------------------+
bool CStateManager::IsStateFileValid()
{
    if(!FileIsExist(m_filename)) {
        return false;
    }

// Try to read and parse file quickly
    int fileHandle = FileOpen(m_filename, FILE_READ | FILE_TXT);
    if(fileHandle == INVALID_HANDLE) {
        return false;
    }

    string firstLine = FileReadString(fileHandle);
    FileClose(fileHandle);

// Basic JSON validation - should start with '{'
    return (StringFind(firstLine, "{") == 0);
}

//+------------------------------------------------------------------+
//| Clean up state file                                             |
//+------------------------------------------------------------------+
void CStateManager::CleanupStateFile()
{
    if(FileIsExist(m_filename)) {
        if(FileDelete(m_filename)) {
            LOG_DEBUG("State file deleted: " + m_filename);
        }
        else {
            LOG_DEBUG("Failed to delete state file: " + m_filename);
        }
    }

// Also clean up any temp files
    string tempFile = m_filename + ".tmp";
    if(FileIsExist(tempFile)) {
        FileDelete(tempFile);
    }
}
//+------------------------------------------------------------------+
