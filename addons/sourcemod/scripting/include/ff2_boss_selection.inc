#if defined _ff2_boss_selection_included
 #endinput
#endif
#define _ff2_boss_selection_included


native void FF2Selection_ViewInfoMenu(int client, int bossIndex);

native void FF2Selection_AddInfoMenu(const char[] itemName, const char[] functionName, int itemFlags = ITEMDRAW_DEFAULT);

/*
    Called when client called
*/
forward Action FF2_OnCheckSelectRules(int client, int characterIndex, const char[] ruleName, const char[] value);

forward void FF2Selection_InfoMenuReady(int client, const int bossIndex);

forward void FF2Selection_OnInfoMenuCreated(int client, const char[] functionName, const int bossIndex);
