#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <clientprefs>
///
#include <freak_fortress_2>
#tryinclude <ff2_potry>
///
#include <ff2_boss_selection>

#define PLUGIN_VERSION "2(1.0)"
#define MAX_NAME 64

int g_iChatCommand;
int FF2Version[3];

char g_strCurrentCharacter[64];
char Incoming[MAXPLAYERS+1][64];
char g_strChatCommand[42][50];

Handle g_hCvarChatCommand;

Handle OnCheckSelectRules;

KeyValues RotationInfo;
ArrayList RotationIndexArray;

public Plugin:myinfo = {
	name = "Freak Fortress 2: Boss Selection EX",
	description = "Allows players select their bosses by /ff2boss (2.0.0+)",
	author = "Nopied◎",
	version = PLUGIN_VERSION,
};

methodmap FF2BossCookie {
	public static Handle FindBossCookie(const char[] characterSet)
	{
		char cookieName[MAX_NAME+14];
		Format(cookieName, sizeof(cookieName), "ff2_boss_%s_incoming", characterSet);

		return FindCookieEx(cookieName);
	}

	public static Handle FindBossIndexCookie(const char[] characterSet)
	{
		char cookieName[MAX_NAME+14];
		Format(cookieName, sizeof(cookieName), "ff2_boss_%s_incomeindex", characterSet);

		return FindCookieEx(cookieName);
	}

	public static Handle FindBossQueueCookie(const char[] characterSet)
	{
		char cookieName[MAX_NAME+14];
		Format(cookieName, sizeof(cookieName), "ff2_boss_%s_queuepoint", characterSet);

		return FindCookieEx(cookieName);
	}

	public static void GetSavedIncoming(int client, char[] incoming, int buffer)
	{
		Handle bossCookie = FF2BossCookie.FindBossCookie(g_strCurrentCharacter);
		GetClientCookie(client, bossCookie, incoming, buffer);
		delete bossCookie;
	}

	public static void SetSavedIncoming(int client, const char[] incoming)
	{
		Handle bossCookie = FF2BossCookie.FindBossCookie(g_strCurrentCharacter);
		SetClientCookie(client, bossCookie, incoming);
		delete bossCookie;
	}

	public static int GetSavedQueuePoints(int client)
	{
		Handle bossCookie = FF2BossCookie.FindBossQueueCookie(g_strCurrentCharacter);
		char tempStr[8];
		GetClientCookie(client, bossCookie, tempStr, sizeof(tempStr));
		delete bossCookie;

		if(tempStr[0] == '\0')
			return -1;
		return StringToInt(tempStr);
	}

	public static void SetSavedQueuePoints(int client, int queuepoints)
	{
		Handle bossCookie = FF2BossCookie.FindBossQueueCookie(g_strCurrentCharacter);
		char tempStr[8];
		Format(tempStr, sizeof(tempStr), "%d", queuepoints);

		if(queuepoints <= -1)
		{
			if(FF2BossCookie.GetSavedQueuePoints(client) > -1)
				FF2_SetQueuePoints(client, FF2BossCookie.GetSavedQueuePoints(client));
			SetClientCookie(client, bossCookie, "");
		}
		else
		{
			FF2_SetQueuePoints(client, -1);
			SetClientCookie(client, bossCookie, tempStr);
		}

		delete bossCookie;
	}

	public static int GetSavedIncomeIndex(int client)
	{
		Handle bossCookie = FF2BossCookie.FindBossIndexCookie(g_strCurrentCharacter);
		char tempStr[8];
		GetClientCookie(client, bossCookie, tempStr, sizeof(tempStr));
		delete bossCookie;

		if(tempStr[0] == '\0')
			return -1;
		return StringToInt(tempStr);
	}

	public static void SetSavedIncomeIndex(int client, int bossIndex)
	{
		Handle bossCookie = FF2BossCookie.FindBossIndexCookie(g_strCurrentCharacter);
		char tempStr[8];
		Format(tempStr, sizeof(tempStr), "%d", bossIndex);

		if(bossIndex <= -1)
		{
			SetClientCookie(client, bossCookie, "");
		}
		else
		{
			SetClientCookie(client, bossCookie, tempStr);
		}
		delete bossCookie;
	}

	public static bool IsPlayBoss(int client)
	{
		return FF2BossCookie.GetSavedQueuePoints(client) <= -1;
	}

	public static void InitializeData(int client)
	{
		char bossName[MAX_NAME];
		FF2BossCookie.GetSavedIncoming(client, bossName, MAX_NAME);
		int bossindex = FF2BossCookie.GetSavedIncomeIndex(client);

		if(FindBossIndexByName(bossName) != bossindex)
		{
			FF2BossCookie.SetSavedIncoming(client, "");
			FF2BossCookie.SetSavedIncomeIndex(client, -1);
		}
		else
		{
			strcopy(Incoming[client], MAX_NAME, bossName);
		}
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, err_max)
{
	OnCheckSelectRules = CreateGlobalForward("FF2_OnCheckSelectRules", ET_Hook, Param_Cell, Param_Cell, Param_String, Param_String); // Client, characterIndex, Rule String, value;

	MarkNativeAsOptional("FF2_GetSpecialKV");
	return APLRes_Success;
}

public void OnPluginStart()
{
	FF2_GetFF2Version(FF2Version);
	if(FF2Version[0] == 2)
	{
		#if !defined _ff2_potry_included
			SetFailState("FF2 v2.0.0 is need ff2_potry.inc!");
		#endif
	}

	g_hCvarChatCommand = CreateConVar("ff2_bossselection_chatcommand", "ff2boss,boss,보스,보스선택");

	HookEvent("teamplay_round_start", OnRoundStart);

	AddCommandListener(Listener_Say, "say");
	AddCommandListener(Listener_Say, "say_team");

	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
	LoadTranslations("ff2_boss_selection");

	ChangeChatCommand();

	RotationIndexArray = new ArrayList();
}

public void OnMapStart()
{
	ChangeChatCommand();

	if(RotationInfo != null)
		delete RotationInfo;
	RotationInfo = GetRotationInfo();

	if(RotationIndexArray != null)
		delete RotationIndexArray;
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(RotationIndexArray == null)
		ResetRotationArray(g_strCurrentCharacter);
}

public Action Listener_Say(int client, const char[] command, int argc)
{
	if(!IsValidClient(client)) return Plugin_Continue;

	char strChat[100];
	char temp[2][64];
	GetCmdArgString(strChat, sizeof(strChat));

	int start;
	bool slient = false;

	if(strChat[start] == '"') start++;
	if(strChat[start] == '!' || strChat[start] == '/')
	{
		slient = strChat[start] == '/';
		start++;
	}
	strChat[strlen(strChat)-1] = '\0';
	ExplodeString(strChat[start], " ", temp, 2, 64, true);

	if(temp[0][0] == '\0' || temp[0][0] == ' ')
		return Plugin_Continue;

	for (int i=0; i<=g_iChatCommand; i++)
	{
		if(StrEqual(temp[0], g_strChatCommand[i], true))
		{
			if(temp[1][0] != '\0')
			{
				return slient ? Plugin_Handled : Plugin_Continue;
			}

			Command_SetMyBoss(client, 0);
			return slient ? Plugin_Handled : Plugin_Continue;
		}
	}

	return Plugin_Continue;
}
#if !defined _ff2_potry_included
	public Action FF2_OnLoadCharacterSet(int &charSetNum, char[] charSetName)
	{
		strcopy(g_strCurrentCharacter, sizeof(g_strCurrentCharacter), charSetName);
		return Plugin_Continue;
	}
#else
	public Action FF2_OnLoadCharacterSet(char[] characterSet)
	{
		strcopy(g_strCurrentCharacter, sizeof(g_strCurrentCharacter), characterSet);
		return Plugin_Continue;
	}
#endif

KeyValues GetRotationInfo()
{
	char config[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, config, sizeof(config), "data/ff2_boss_selection.cfg");

	KeyValues kv = new KeyValues("Freak Fortress 2");
	if(!kv.ImportFromFile(config))
	{
		LogError("data/ff2_boss_selection.cfg doesn't exist!");
		return null;
	}

	return kv;
}

void ResetRotationArray(char[] characterSet)
{
	if(RotationInfo == null)	return;

	char rotationId[64];
	KeyValues BossKV, tempRotationInfo;
	int count, bossCount, ratio;

	RotationInfo.Rewind();

	RotationIndexArray = new ArrayList();
	tempRotationInfo = new KeyValues("Freak Fortress 2");
	tempRotationInfo.Import(RotationInfo);

	// LogMessage("characterPackName = %s", characterSet);
	if(RotationInfo.JumpToKey("character_set"))
	{
		RotationInfo.JumpToKey(characterSet);
		tempRotationInfo.JumpToKey("rotation");

		ArrayList tempArray = new ArrayList();
		count = RotationInfo.GetNum("rotation_count", 0);

		for (bossCount = 0; (BossKV = GetCharacterKVEx(bossCount)) != null; bossCount++)
		{
			// JUST FOR bossCount;
		}

		RotationIndexArray.Resize(bossCount);

		for (int loop = 0; (BossKV = GetCharacterKVEx(loop)) != null; loop++)
		{
			BossKV.Rewind();
			// 원래 리스트에 표시 안되는 "hidden" 부류들은 여기에 포함되지 않도록
			if(BossKV.GetNum("hidden", 0) > 0) {
				RotationIndexArray.Set(loop, false);
				continue;
			}
			else if(count <= 0) {
				RotationIndexArray.Set(loop, true);
				continue;
			}

			BossKV.GetString("rotation_id", rotationId, sizeof(rotationId));
			RotationInfo.JumpToKey(rotationId, true);
			// LogMessage("rotation_id = %s", rotationId);

			if(RotationInfo.GetNum("banned", 0) > 0)
			{
				RotationIndexArray.Set(loop, false);
			}
			else if(RotationInfo.GetNum("always_appear", 0) > 0)
			{
				RotationIndexArray.Set(loop, true);
				if(RotationInfo.GetNum("can_be_count", 1) <= 0)
					count--;
			}
			else
			{
				ratio = RotationInfo.GetNum("ratio", 1);
				for(int i = 0; i < ratio; i++) {
					// LogMessage("Added %d", loop);
					tempArray.Push(loop);
				}

				RotationIndexArray.Set(loop, false);
			}

			RotationInfo.GoBack();
		}


		int random; // index;
		for(int loop = 0; loop < count; loop++)
		{
			random = tempArray.Get(GetRandomInt(0, tempArray.Length-1));
			if(!RotationIndexArray.Get(random))
				RotationIndexArray.Set(random, true);
			else
				loop--; // TODO: 예외 무한루프 방지

			/*
			while((index = tempArray.FindValue(random)) != -1)
			{
				tempArray.ShiftUp(index);
			}
			*/
		}

		delete tempArray;
	}
}

public Action FF2_OnAddQueuePoints(int add_points[MAXPLAYERS+1])
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsValidClient(client) && !IsBoss(client))
		{
			if(!FF2BossCookie.IsPlayBoss(client))
			{
				int queuepoints = FF2BossCookie.GetSavedQueuePoints(client);
				if(FF2_GetQueuePoints(client) > 0)
				{
					FF2BossCookie.SetSavedQueuePoints(client, queuepoints+FF2_GetQueuePoints(client));
				}

				add_points[client] = 0;
				FF2_SetQueuePoints(client, -1);
			}

			LogMessage("%N의 대기열 포인트: %d, 저장된 대기열포인트: %d", client, FF2_GetQueuePoints(client), FF2BossCookie.GetSavedQueuePoints(client));
		}
	}
	return Plugin_Changed;
}

public Action FF2_OnCheckSelectRules(int client, int characterIndex, const char[] ruleName, const char[] value)
{
	int integerValue = StringToInt(value);
	// CPrintToChatAll("%s: %s, %d", ruleName, value, integerValue);

	/*
	if(StrEqual(ruleName, "admin")) // FIXME: Not Working.
	{
		AdminId adminId = GetUserAdmin(client);

		if(adminId != INVALID_ADMIN_ID)
		{
			if(!adminId.HasFlag(view_as<AdminFlag>(integerValue), Access_Real))
				return Plugin_Handled;
		}
		return Plugin_Handled;
	}
	*/
	if(StrEqual(ruleName, "blocked"))	return Plugin_Handled;

	return Plugin_Continue;
}


public void OnClientPutInServer(client)
{
	Incoming[client] = "";

	if(AreClientCookiesCached(client))
	{
		FF2BossCookie.InitializeData(client);
	}
}

public Action Command_SetMyBoss(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[SM] %t", "FF2Boss InGame Only");
		return Plugin_Handled;
	}

	if(FF2_GetBossIndex(client) != -1)
	{
		CPrintToChat(client, "{olive}[FF2]{default} %t", "FF2Boss Can't change while playing boss");
		return Plugin_Handled;
	}
/*
	// TODO: Cvar
	if(!CheckCommandAccess(client, "ff2boss", ADMFLAG_BAN))
	{
		ReplyToCommand(client, "[SM] %t.", "No Access");
		return Plugin_Handled;
	}
*/

	char menutext[MAX_NAME*2], bossName[MAX_NAME];
	KeyValues BossKV;
	Handle dMenu = CreateMenu(Command_SetMyBossH);
	BossKV = GetCharacterKVEx(FF2BossCookie.GetSavedIncomeIndex(client));

	SetGlobalTransTarget(client);

	if(!FF2BossCookie.IsPlayBoss(client))
	{
		Format(menutext, sizeof(menutext), "%t", "FF2Boss Dont Play Boss");
		Format(menutext, sizeof(menutext), "%s\n%t", menutext, "FF2Boss Saved QueuePoints", FF2BossCookie.GetSavedQueuePoints(client));
		SetMenuTitle(dMenu, menutext);
	}
	else if(BossKV == null)
	{
		Format(menutext, sizeof(menutext), "%t", "FF2Boss Menu Random");
		SetMenuTitle(dMenu, "%t", "FF2Boss Menu Title", menutext);
	}
	else
	{
		GetCharacterName(BossKV, bossName, MAX_NAME, client);
		Format(menutext, sizeof(menutext), "%s", bossName);
		SetMenuTitle(dMenu, "%t", "FF2Boss Menu Title", menutext);
	}

	Format(menutext, sizeof(menutext), "%t", "FF2Boss Menu Random");
	AddMenuItem(dMenu, "Random Boss", menutext);
	Format(menutext, sizeof(menutext), "%t", "FF2Boss Menu None");
	AddMenuItem(dMenu, "None", menutext);

	char spcl[MAX_NAME], banMaps[500], map[100], ruleName[80], value[120];
	GetCurrentMap(map, sizeof(map));

	int itemflags;
	bool checked = true;
	Action action;

	for (int i = 0; (BossKV = GetCharacterKVEx(i)) != null; i++)
	{
		itemflags = 0;
		checked = true;
		BossKV.Rewind();

		if (BossKV.GetNum("hidden", 0) > 0) continue;

		BossKV.GetString("ban_map", banMaps, 500);
		Format(spcl, sizeof(spcl), "%d", i);
		GetCharacterName(BossKV, bossName, MAX_NAME, client);

		BossKV.Rewind(); // LOL?
		if(BossKV.JumpToKey("require") && BossKV.JumpToKey("selectable") && BossKV.GotoFirstSubKey(false))
		{
			do
			{
				BossKV.GetSectionName(ruleName, sizeof(ruleName));

				Call_StartForward(OnCheckSelectRules);
				Call_PushCell(client);
				Call_PushCell(i);
				Call_PushStringEx(ruleName, sizeof(ruleName), SM_PARAM_STRING_COPY|SM_PARAM_STRING_UTF8, SM_PARAM_COPYBACK);
				BossKV.GetString(NULL_STRING, value, 120, "");
				Call_PushStringEx(value, sizeof(value), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_Finish(action);

				if(action == Plugin_Stop || action == Plugin_Handled)
				{
					checked = false;
					break;
				}

			}
			while(BossKV.GotoNextKey(false));

			if(!checked) continue;
		}

		if(banMaps[0] != '\0' && !StrContains(banMaps, map, false))
		{
			Format(menutext, sizeof(menutext), "%s (%t)", bossName, "FF2Boss Cant Chosse This Map");
			itemflags |= ITEMDRAW_DISABLED;
		}
		else if(RotationIndexArray != null && !RotationIndexArray.Get(i))
		{
			Format(menutext, sizeof(menutext), "%s (%t)", bossName, "FF2Boss Cant Chosse This Now");
			itemflags |= ITEMDRAW_DISABLED;
		}
		else
		{
			Format(menutext, sizeof(menutext), "%s", bossName);
		}

		AddMenuItem(dMenu, spcl, menutext, itemflags);
	}
	SetMenuExitButton(dMenu, true);
	DisplayMenu(dMenu, client, 90);
	return Plugin_Handled;
}

public Command_SetMyBossH(Handle menu, MenuAction action, int client, int item)
{
	switch(action)
	{
		case MenuAction_End:
		{
			CloseHandle(menu);
		}

		case MenuAction_Select:
		{
			SetGlobalTransTarget(client);
			char text[200];
			switch(item)
			{
				case 0:
				{
					Incoming[client] = "";

					FF2BossCookie.SetSavedIncoming(client, Incoming[client]);
					FF2BossCookie.SetSavedIncomeIndex(client, -1);
					Format(text, sizeof(text), "%t", "FF2Boss Menu Random");
					CReplyToCommand(client, "{olive}[FF2]{default} %t", "FF2Boss Selected", text);
					FF2BossCookie.SetSavedQueuePoints(client, -1);
				}
				case 1:
				{
					FF2BossCookie.SetSavedQueuePoints(client, FF2_GetQueuePoints(client));
					CReplyToCommand(client, "{olive}[FF2]{default} %t", "FF2Boss Dont Play Boss");
				}
				default:
				{
					GetMenuItem(menu, item, text, sizeof(text));
					int bossIndex = StringToInt(text);
					KeyValues BossKV = GetCharacterKVEx(bossIndex);
					GetCharacterName(BossKV, Incoming[client], MAX_NAME, 0);
					GetCharacterName(BossKV, text, MAX_NAME, client);

					FF2BossCookie.SetSavedIncoming(client, Incoming[client]);
					FF2BossCookie.SetSavedIncomeIndex(client, bossIndex);
					CReplyToCommand(client, "{olive}[FF2]{default} %t", "FF2Boss Selected", text);
					FF2BossCookie.SetSavedQueuePoints(client, -1);
				}
			}
		}
	}
}

#if !defined _ff2_potry_included
	public Action FF2_OnSpecialSelected(int boss, int &character, char[] characterName, bool preset)
#else
	public Action FF2_OnBossSelected(int boss, int &character, char[] characterName, bool preset)
#endif
{
	if(preset) return Plugin_Continue;

	new client = GetClientOfUserId(FF2_GetBossUserId(boss));
	Handle BossKv = GetCharacterKVEx(boss);
	if (!boss && !StrEqual(Incoming[client], ""))
	{
		if(BossKv != INVALID_HANDLE)
		{
			char banMaps[500];
			char map[124];

			GetCurrentMap(map, sizeof(map));
			KvGetString(BossKv, "ban_map", banMaps, sizeof(banMaps), "");

			if(!StrContains(banMaps, map, false))
			{
				return Plugin_Continue;
			}
		}
		strcopy(characterName, sizeof(Incoming[]), Incoming[client]);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void Cvar_ChatCommand_Changed(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	ChangeChatCommand();
}

void ChangeChatCommand()
{
	g_iChatCommand = 0;

	char cvarV[MAX_NAME];
	GetConVarString(g_hCvarChatCommand, cvarV, sizeof(cvarV));

	for (int i=0; i<ExplodeString(cvarV, ",", g_strChatCommand, sizeof(g_strChatCommand), sizeof(g_strChatCommand[])); i++)
	{
		LogMessage("[FF2boss] Added chat command: %s", g_strChatCommand[i]);
		g_iChatCommand++;
	}
}

stock int FindBossIndexByName(const char[] bossName)
{
	char name[64];
	KeyValues BossKV;
	for (int loop = 0; (BossKV = GetCharacterKVEx(loop)) != null; loop++)
	{
		GetCharacterName(BossKV, name, 64, 0);
		if(StrEqual(name, bossName)) return loop;
	}

	return -1;
}

KeyValues GetCharacterKVEx(int bossIndex)
{
	#if !defined _ff2_potry_included
		return view_as<KeyValues>(FF2_GetSpecialKV(bossIndex, true));
	#else
		return FF2_GetCharacterKV(bossIndex);
	#endif
}

public void GetCharacterName(KeyValues characterKv, char[] bossName, int size, const int client)
{
	int currentSpot;
	characterKv.GetSectionSymbol(currentSpot);
	characterKv.Rewind();

	if(client > 0)
	{
		char language[8];
		GetLanguageInfo(GetClientLanguage(client), language, sizeof(language));
		if(characterKv.JumpToKey("name_lang"))
		{
			characterKv.GetString(language, bossName, size, "");
			if(bossName[0] != '\0')
				return;
		}
		characterKv.Rewind();
	}
	characterKv.GetString("name", bossName, size);
	characterKv.JumpToKeySymbol(currentSpot);
}

stock bool IsValidClient(client)
{
	return (0 < client && client < MaxClients && IsClientInGame(client));
}

stock bool IsBoss(int client)
{
	return (FF2_GetBossIndex(client) != -1);
}

stock Handle FindCookieEx(char[] cookieName)
{
    Handle cookieHandle = FindClientCookie(cookieName);
    if(cookieHandle == null)
    {
        cookieHandle = RegClientCookie(cookieName, "", CookieAccess_Protected);
    }

    return cookieHandle;
}
