#if defined _ff2_boss_selection_included
 #endinput
#endif
#define _ff2_boss_selection_included


/*
    Called when client called
*/
forward Action FF2_OnCheckSelectRules(int client, int characterIndex, const char[] ruleName, const char[] value);
