#include <sourcemod>
#include <ff2_boss_selection>


public void FF2Selection_InfoMenuReady(int client, const int bossIndex)
{
    FF2Selection_AddInfoMenu("TEST", "TEST_FUNCTION");

    // NOTE: Since we are using SourceMod's Menu, ITEMDRAW_RAWLINE is not working here.
    // Probably you do better with using ITEMDRAW_DISABLED and use \n to inform about item.
    FF2Selection_AddInfoMenu("TESTITEM\nINSERT_INFO_WHYITCANTBESELECTED!", "TEST_INFO", ITEMDRAW_DISABLED);
}

public void FF2Selection_OnInfoMenuCreated(int client, const char[] functionName, const int bossIndex)
{
    if(StrEqual(functionName, "TEST_FUNCTION"))
        PrintToChatAll("Hello, %N!", client);

    if(StrEqual(functionName, "TEST_INFO"))
        PrintToChatAll("HOW DID YOU GET HERE? %N?", client);

    return;
}