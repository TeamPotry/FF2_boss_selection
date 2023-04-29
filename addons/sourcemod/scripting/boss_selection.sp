#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <clientprefs>
///
#include <freak_fortress_2>
#tryinclude <ff2_modules/general>
///
#include <ff2_boss_selection>

#define PLUGIN_VERSION "2(1.0)"
#define MAX_NAME 64

int FF2Version[3];

char g_strCurrentCharacter[64];
char Incoming[MAXPLAYERS+1][64];

ConVar cvarBossPlayedCount;

Handle g_hPlayedCountCookie;
Handle OnCheckSelectRules;

KeyValues RotationInfo;
ArrayList RotationIndexArray;

Handle InfoMenuReady, InfoMenuCreated;
ArrayList AdditionalInfoMenuList;

public Plugin:myinfo = {
	name = "Freak Fortress 2: Boss Selection EX",
	description = "Allows players select their bosses by /ff2boss (2.0.0+)",
	author = "Nopied◎",
	version = PLUGIN_VERSION,
};

enum
{
	InfoMenu_ItemName = 0,
	// InfoMenu_PluginHandle,
	InfoMenu_FunctionName,
	InfoMenu_ItemFlags,
	// InfoMenu_Info,

	InfoMenuCount_Max
};

methodmap AdditionalInfoMenu < ArrayList {
	public static native AdditionalInfoMenu Create(const char[] itemName, const char[] functionName, int itemFlags = ITEMDRAW_DEFAULT);

	public void GetItemName(char[] itemName, int buffer)
	{
		this.GetString(InfoMenu_ItemName, itemName, buffer);
	}

	public void SetItemName(const char[] itemName)
	{
		this.SetString(InfoMenu_ItemName, itemName);
	}

	public void GetFunctionName(char[] functionName, int buffer)
	{
		this.GetString(InfoMenu_FunctionName, functionName, buffer);
	}

	public void SetFunctionName(const char[] functionName)
	{
		this.SetString(InfoMenu_FunctionName, functionName);
	}

	property int ItemFlags {
		public get() {
			return this.Get(InfoMenu_ItemFlags);
		}
		public set(int flags) {
			this.Set(InfoMenu_ItemFlags, flags);
		}
	}

/*
	public void GetInfo(char[] info, int buffer)
	{
		this.GetString(InfoMenu_Info, info, buffer);
	}

	public void SetInfo(const char[] info)
	{
		this.SetString(InfoMenu_Info, info);
	}

	property Handle PluginHandle {
		public get() {
			return this.Get(InfoMenu_PluginHandle);
		}
		public set(Handle plugin) {
			this.Set(InfoMenu_PluginHandle, plugin);
		}
	}
*/
}

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

	public static int GetSavedPlayedCount(int client)
	{
		char tempStr[24];
		GetClientCookie(client, g_hPlayedCountCookie, tempStr, sizeof(tempStr));

		if(tempStr[0] == '\0')
			return 0;

		return StringToInt(tempStr);
	}

	public static void SetSavedPlayedCount(int client, int count)
	{
		char tempStr[24];
		IntToString(count, tempStr, 24);
		SetClientCookie(client, g_hPlayedCountCookie, tempStr);
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
	InfoMenuReady = CreateGlobalForward("FF2Selection_InfoMenuReady", ET_Ignore, Param_Cell, Param_Cell);
	InfoMenuCreated = CreateGlobalForward("FF2Selection_OnInfoMenuCreated", ET_Ignore, Param_Cell, Param_String, Param_Cell);

	CreateNative("AdditionalInfoMenu.Create", Native_AdditionalInfoMenu_Create);

	CreateNative("FF2Selection_ViewInfoMenu", Native_ViewInfoMenu);
	CreateNative("FF2Selection_AddInfoMenu", Native_AddInfoMenu);

	MarkNativeAsOptional("FF2_GetSpecialKV");
	return APLRes_Success;
}

public int Native_AdditionalInfoMenu_Create(Handle plugin, int numParams)
{
	char itemName[128], functionName[128];
	// char info[128];

	AdditionalInfoMenu array = view_as<AdditionalInfoMenu>(new ArrayList(128));

	GetNativeString(1, itemName, 128);
	array.PushString(itemName);

	GetNativeString(2, functionName, 128);
	array.PushString(functionName);

	int itemFlags = GetNativeCell(3);
	array.Push(itemFlags);

	// GetNativeString(4, info, 128);
	// array.PushString(info);

	return view_as<int>(array);
}

public /*void*/int Native_ViewInfoMenu(Handle plugin, int numParams)
{
	ViewBossInfo(GetNativeCell(1), GetNativeCell(2));
	return 0;
}

public /*void*/int Native_AddInfoMenu(Handle plugin, int numParams)
{
	char translationName[128], functionName[128];
	GetNativeString(1, translationName, 128);
	GetNativeString(2, functionName, 128);

	int itemFlags = GetNativeCell(3);

	AdditionalInfoMenu item = AdditionalInfoMenu.Create(translationName, functionName, itemFlags);
	AdditionalInfoMenuList.Push(item);

	return 0;
}

public void OnPluginStart()
{
	FF2_GetFF2Version(FF2Version);
	if(FF2Version[0] == 2)
	{
		#if !defined _ff2_fork_general_included
			SetFailState("FF2 v2.0.0 is need ff2_potry.inc!");
		#endif
	}

	cvarBossPlayedCount = CreateConVar("ff2_bossselection_playpoint", "0", "0 - Disable, else: enabled, This cvar value is will be the price of select bosses.", _, true, 0.0, false);

	RegConsoleCmd("ff2boss", Command_SetMyBoss, "Set my FF2 boss!");

	HookEvent("teamplay_round_start", OnRoundStart);
	HookEvent("player_death", OnPlayerDeath);

	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
	LoadTranslations("ff2_boss_selection");

	// cvarBossPlayedCount.AddChangeHook(CvarChange);

	RotationIndexArray = new ArrayList();
	AdditionalInfoMenuList = new ArrayList(); // TODO: 맵 체인지 이후에 함수 주소 변경 여부 조사

	g_hPlayedCountCookie = RegClientCookie("ff2_boss_played_count", "", CookieAccess_Protected);

	RegPluginLibrary("ff2_boss_selection");
}

void ReloadAdditionalInfoMenuList(int client, int bossIndex)
{
	AdditionalInfoMenuList.Resize(0);

	Call_StartForward(InfoMenuReady);
	Call_PushCell(client);
	Call_PushCell(bossIndex);
	Call_Finish();
}

public void OnMapStart()
{
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

	return Plugin_Continue;
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker")), client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || !IsValidClient(attacker)
	|| IsFakeClient(attacker) || IsFakeClient(client)) 	return Plugin_Continue;
	else if(!IsBoss(attacker))						 	return Plugin_Continue;

	FF2BossCookie.SetSavedPlayedCount(attacker, FF2BossCookie.GetSavedPlayedCount(client) + 1);
	return Plugin_Continue;
}

#if !defined _ff2_fork_general_included
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
		if(!IsValidClient(client) || !AreClientCookiesCached(client))	continue;

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
	}
	return Plugin_Changed;
}

public Action FF2_OnCheckSelectRules(int client, int characterIndex, const char[] ruleName, const char[] value)
{
	int integerValue = StringToInt(value);
	char authId[32];
	GetClientAuthId(client, AuthId_SteamID64, authId, sizeof(authId));
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

#if defined _ff2_fork_general_included
	if(StrEqual(ruleName, "creator"))
	{
		int flags = FF2_GetBossCreatorFlags(authId, characterIndex, true);
		return flags > 0 ? Plugin_Continue : Plugin_Handled;
	}
#endif

	return Plugin_Continue;
}

public void OnClientConnected(int client)
{
	Incoming[client] = "";
}

public void OnClientCookiesCached(int client)
{
	FF2BossCookie.InitializeData(client);
}

public Action Command_SetMyBoss(int client, int args)
{
	SetGlobalTransTarget(client);

	if (client == 0)
	{
		ReplyToCommand(client, "[SM] %t", "FF2Boss InGame Only");
		return Plugin_Handled;
	}

	if (!AreClientCookiesCached(client))
	{
		CPrintToChat(client, "{olive}[FF2]{default} %t", "FF2Boss Loading PlayerData");
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
	int pointPrice = cvarBossPlayedCount.IntValue, playerPoint = FF2BossCookie.GetSavedPlayedCount(client);
	BossKV = GetCharacterKVEx(FF2BossCookie.GetSavedIncomeIndex(client));


	if(!pointPrice)
		Format(menutext, sizeof(menutext), "%t\n", "FF2Boss Skip Tip");
	else {
		Format(menutext, sizeof(menutext), "%t", "FF2Boss Info Select Boss (Played Point)", playerPoint, playerPoint - pointPrice, pointPrice);
		if(playerPoint - pointPrice < 0)
		{
			Format(menutext, sizeof(menutext), "%s\n%t", menutext, "FF2Boss Not Enough Played Point");
		}
	}


	if(!FF2BossCookie.IsPlayBoss(client))
	{
		Format(menutext, sizeof(menutext), "%s\n%t", menutext, "FF2Boss Dont Play Boss");
		Format(menutext, sizeof(menutext), "%s\n%t", menutext, "FF2Boss Saved QueuePoints", FF2BossCookie.GetSavedQueuePoints(client));
	}
	else if(BossKV == null)
	{
		Format(bossName, sizeof(bossName), "%t", "FF2Boss Menu Random");
		Format(menutext, sizeof(menutext), "%s\n%t", menutext, "FF2Boss Menu Title", bossName);
	}
	else
	{
		GetCharacterName(BossKV, bossName, MAX_NAME, client);
		Format(menutext, sizeof(menutext), "%s\n%t", menutext, "FF2Boss Menu Title", bossName);
	}
	SetMenuTitle(dMenu, menutext);

	Format(menutext, sizeof(menutext), "%t", "FF2Boss Menu Random");
	AddMenuItem(dMenu, "Random Boss", menutext);
	Format(menutext, sizeof(menutext), "%t", "FF2Boss Menu None");
	AddMenuItem(dMenu, "None", menutext);

	char spcl[MAX_NAME], banMaps[500], map[100], ruleName[80], tempRuleName[80], value[120];
	GetCurrentMap(map, sizeof(map));

	int itemflags;
	bool checked = true, multipleCheck;
	Action action;

	for (int i = 0; (BossKV = GetCharacterKVEx(i)) != null; i++)
	{
		itemflags = 0;
		checked = true;
		BossKV.Rewind();

		if (BossKV.GetNum("hidden", 0) > 0) continue;
		else if (BossKV.GetNum("blocked", 0) > 0) continue;

		BossKV.GetString("ban_map", banMaps, 500);
		Format(spcl, sizeof(spcl), "%d", i);
		GetCharacterName(BossKV, bossName, MAX_NAME, client);

		BossKV.Rewind(); // LOL?
		if(BossKV.JumpToKey("require") && BossKV.JumpToKey("selectable") && BossKV.GotoFirstSubKey(false))
		{
			do
			{
				BossKV.GetSectionName(ruleName, sizeof(ruleName));

				if(StrEqual(ruleName, "multiple") && BossKV.GotoFirstSubKey())
				{
					do
					{
						multipleCheck = false;
						if(BossKV.GotoFirstSubKey(false))
						{
							do
							{
								BossKV.GetSectionName(tempRuleName, sizeof(tempRuleName));

								Call_StartForward(OnCheckSelectRules);
								Call_PushCell(client);
								Call_PushCell(i);
								Call_PushStringEx(tempRuleName, sizeof(tempRuleName), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
								BossKV.GetString(NULL_STRING, value, 120);
								Call_PushStringEx(value, sizeof(value), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
								Call_Finish(action);

								multipleCheck = action == Plugin_Stop || action == Plugin_Handled ? false : true;
								if(multipleCheck) break;
							}
							while(BossKV.GotoNextKey(false));
							BossKV.GoBack();
						}
					}
					while(BossKV.GotoNextKey());
					BossKV.GoBack();
				}
				else
				{
					Call_StartForward(OnCheckSelectRules);
					Call_PushCell(client);
					Call_PushCell(i);
					Call_PushStringEx(ruleName, sizeof(ruleName), SM_PARAM_STRING_COPY|SM_PARAM_STRING_UTF8, SM_PARAM_COPYBACK);
					BossKV.GetString(NULL_STRING, value, 120, "");
					Call_PushStringEx(value, sizeof(value), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
					Call_Finish(action);
				}

				checked = action == Plugin_Stop || action == Plugin_Handled ? false : true;
			}
			while(BossKV.GotoNextKey(false));

			if(!checked && !multipleCheck) continue;
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
			bool isSkip = (GetClientButtons(client) & IN_RELOAD) > 0;

			SetGlobalTransTarget(client);
			char text[200];
			switch(item)
			{
				case 0:
				{
					Incoming[client] = "";
					SelectBoss(client, "Random", -1);
				}
				case 1:
				{
					if(FF2_GetQueuePoints(client) >= 0)
						FF2BossCookie.SetSavedQueuePoints(client, FF2_GetQueuePoints(client));
					CReplyToCommand(client, "{olive}[FF2]{default} %t", "FF2Boss Dont Play Boss");
				}
				default:
				{
					GetMenuItem(menu, item, text, sizeof(text));
					int bossIndex = StringToInt(text);
					bool hasPlayedPoint = cvarBossPlayedCount.IntValue > 0;

					if(isSkip && !hasPlayedPoint)
					{
						KeyValues BossKV = GetCharacterKVEx(bossIndex);
						GetCharacterName(BossKV, Incoming[client], MAX_NAME, 0);

						SelectBoss(client, Incoming[client], bossIndex);
					}
					else
					{
						ViewBossInfo(client, bossIndex);
					}
				}
			}
		}
	}
}

void ViewBossInfo(int client, int bossIndex)
{
	char realBossName[128], text[1024], temp[128];
	KeyValues BossKV = GetCharacterKVEx(bossIndex);
	int currentPlaying = 0, maxHealth, speed, rageDamage, lives;
	int pointPrice = cvarBossPlayedCount.IntValue, playerPoint = FF2BossCookie.GetSavedPlayedCount(client);

	BossKV.Rewind();
	GetCharacterName(BossKV, realBossName, MAX_NAME, client);

	for(int target = 1; target <= MaxClients; target++)
	{
		if(IsValidClient(target) && TF2_GetClientTeam(target) > TFTeam_Spectator)
		{
			currentPlaying++;
		}
	}

	#if !defined _ff2_fork_general_included
		maxHealth = ParseFormula(bossIndex, "health_formula", RoundFloat(Pow((760.8+float(currentPlaying))*(float(currentPlaying)-1.0), 1.0341)+2046.0));
		speed = BossKV.GetNum("maxspeed", 340);
		rageDamage = BossKV.GetNum("ragedamage", 1900);
		lives = BossKV.GetNum("lives", 1);
	#else
		maxHealth = ParseFormula(bossIndex, "health", RoundFloat(Pow((760.8+float(currentPlaying))*(float(currentPlaying)-1.0), 1.0341)+2046.0));
		speed = BossKV.GetNum("speed", 340);
		rageDamage = BossKV.GetNum("rage damage", 1900);
		lives = BossKV.GetNum("lives", 1);
	#endif

	Menu menu = new Menu(BossInfo_Handler);

	// Title (BossInfo)
	Format(text, sizeof(text), "%s\n", realBossName);

	Format(text, sizeof(text), "%s\n - %t", text, "FF2Boss Info Health", currentPlaying, maxHealth);
	if(lives > 1)
		Format(text, sizeof(text), "%s x%d", text, lives);

	Format(text, sizeof(text), "%s\n - %t,", text, "FF2Boss Info RageDamage", rageDamage);
	Format(text, sizeof(text), "%s %t", text, "FF2Boss Info Speed", speed);
	menu.SetTitle(text);

	// TODO: Rule 적용
	Format(temp, sizeof(temp), "%d", bossIndex);
	Format(text, sizeof(text), "%t", "FF2Boss Info Select Boss");

	if(pointPrice > 0)
		Format(text, sizeof(text), "%s (%t)", text, "FF2Boss Info Select Boss (Played Point)", playerPoint, playerPoint - pointPrice, pointPrice);

	menu.AddItem(temp, text, (pointPrice > playerPoint) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

	Format(text, sizeof(text), "%t", "FF2Boss Info View Description");
	menu.AddItem(temp, text);

	ReloadAdditionalInfoMenuList(client, bossIndex);
	int length = AdditionalInfoMenuList.Length, flags;
	AdditionalInfoMenu infoMenu;
	for(int loop = 0; loop < length; loop++)
	{
		infoMenu = AdditionalInfoMenuList.Get(loop);

		infoMenu.GetItemName(text, 128);
		infoMenu.GetFunctionName(temp, 128);
		flags = infoMenu.ItemFlags;

		Format(text, sizeof(text), "%s", text);
		menu.AddItem(temp, text, flags);
	}

	menu.ExitButton = true;
	menu.ExitBackButton = true;

	menu.Display(client, 90);
}

enum
{
	BossInfo_Select = 0,
	BossInfo_ViewDescription,

	BossInfo_Other
};

public int BossInfo_Handler(Menu menu, MenuAction action, int client, int selection)
{
	char bossName[4], text[128];

	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			if(selection == MenuCancel_ExitBack)
				Command_SetMyBoss(client, 0);
		}
		case MenuAction_Select:
		{
			SetGlobalTransTarget(client);
			GetMenuItem(menu, BossInfo_Select, bossName, sizeof(bossName));

			int bossIndex = StringToInt(bossName);
			KeyValues BossKV = GetCharacterKVEx(bossIndex);

			switch(selection)
			{
				case BossInfo_Select:
				{
					int pointPrice = cvarBossPlayedCount.IntValue, playerPoint = FF2BossCookie.GetSavedPlayedCount(client);
					FF2BossCookie.SetSavedPlayedCount(client, playerPoint - pointPrice);

					GetCharacterName(BossKV, Incoming[client], MAX_NAME, 0);
					SelectBoss(client, Incoming[client], bossIndex);
				}
				case BossInfo_ViewDescription:
				{
					ViewBossDescription(client, bossIndex);
				}

				default:
				{
					//	TODO: 서브 플러그인 지원
					GetMenuItem(menu, selection, text, sizeof(text));

					Call_StartForward(InfoMenuCreated);
					Call_PushCell(client);
					Call_PushStringEx(text, sizeof(text), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
					Call_PushCell(bossIndex);

					Call_Finish();

				}
			}
		}
	}

	return 0;
}

void ViewBossDescription(int client, int bossIndex)
{
	char text[1024], langId[4], serverLangId[4], temp[4];
	Menu menu = new Menu(BossDescription_Handler);
	KeyValues BossKV = GetCharacterKVEx(bossIndex);

	BossKV.Rewind();
	GetLanguageInfo(GetClientLanguage(client), langId, 4);
	GetLanguageInfo(GetServerLanguage(), serverLangId, 4);

	#if !defined _ff2_fork_general_included
		Format(text, sizeof(text), "description_%s", langId);
		BossKV.GetString(text, text, sizeof(text), "");

		if(text[0] == '\0')
		{
			Format(text, sizeof(text), "description_%s", serverLangId);
			BossKV.GetString(text, text, sizeof(text), "");
		}

	#else
		BossKV.JumpToKey("description", true);
		BossKV.GetString(langId, text, sizeof(text), "");

		if(text[0] == '\0')
		{
			BossKV.GetString(serverLangId, text, sizeof(text), "");
		}
	#endif
	ReplaceString(text, sizeof(text), "\\n", "\n");

	menu.SetTitle(text);

	Format(temp, sizeof(temp), "%d", bossIndex);
	Format(text, sizeof(text), "%t", "FF2Boss Info Select Boss");
	menu.AddItem(temp, text);
	menu.AddItem(temp, text, ITEMDRAW_IGNORE);

/*
	ReloadAdditionalInfoMenuList(client, bossIndex);
	int length = AdditionalInfoMenuList.Length, flags;
	AdditionalInfoMenu infoMenu;
	for(int loop = 0; loop < length; loop++)
	{
		infoMenu = AdditionalInfoMenuList.Get(loop);

		infoMenu.GetItemName(text, 128);
		infoMenu.GetFunctionName(temp, 128);

		flags = infoMenu.ItemFlags;

		Format(text, sizeof(text), "%s", text);
		menu.AddItem(temp, text, flags);
	}
*/

	menu.ExitButton = true;
	menu.ExitBackButton = true;

	menu.Display(client, 90);
}

public int BossDescription_Handler(Menu menu, MenuAction action, int client, int selection)
{
	SetGlobalTransTarget(client);
	char text[4];

	GetMenuItem(menu, 0, text, sizeof(text));
	int bossIndex = StringToInt(text);

	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			if(selection == MenuCancel_ExitBack)
				ViewBossInfo(client, bossIndex);
		}
		case MenuAction_Select:
		{
			switch(selection)
			{
				case BossInfo_Select:
				{
					KeyValues BossKV = GetCharacterKVEx(bossIndex);
					GetCharacterName(BossKV, Incoming[client], MAX_NAME, 0);

					SelectBoss(client, Incoming[client], bossIndex);
				}
			}
		}
	}

	return 0;
}

void SelectBoss(int client, char[] bossName, int bossIndex = -1)
{
	char text[256];

	if(bossIndex == -1)
	{
		FF2BossCookie.SetSavedIncoming(client, "");
		FF2BossCookie.SetSavedIncomeIndex(client, -1);
		Format(text, sizeof(text), "%t", "FF2Boss Menu Random");
		CReplyToCommand(client, "{olive}[FF2]{default} %t", "FF2Boss Selected", text);
		FF2BossCookie.SetSavedQueuePoints(client, -1);
	}
	else
	{
		char realBossName[MAX_NAME];
		KeyValues BossKV = GetCharacterKVEx(bossIndex);
		GetCharacterName(BossKV, realBossName, MAX_NAME, client);

		FF2BossCookie.SetSavedIncoming(client, bossName);
		FF2BossCookie.SetSavedIncomeIndex(client, bossIndex);
		CReplyToCommand(client, "{olive}[FF2]{default} %t", "FF2Boss Selected", realBossName);
		FF2BossCookie.SetSavedQueuePoints(client, -1);
	}
}

#if !defined _ff2_fork_general_included
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
				if(!AreClientCookiesCached(client))
				{
					// 보스 설정이 로딩되기 전, 보스 플레이 시작 시에 안내
					SetGlobalTransTarget(client);
					CPrintToChat(client, "{olive}[FF2]{default} %t", "FF2Boss Playing Before Load PlayerData");
				}

				return Plugin_Continue;
			}
		}

		char bossName[64];
		FF2BossCookie.GetSavedIncoming(client, bossName, sizeof(bossName));
		LogMessage("%N의 대기열 포인트: %d, 저장된 대기열포인트: %d", client, FF2_GetQueuePoints(client), FF2BossCookie.GetSavedQueuePoints(client));
		LogMessage("%N의 현재 보스: %s, 저장된 보스: %s", client, Incoming[client], bossName);

		strcopy(characterName, sizeof(Incoming[]), Incoming[client]);
		return Plugin_Changed;
	}
	return Plugin_Continue;
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
	#if !defined _ff2_fork_general_included
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

// Copied from FF2

enum Operators
{
	Operator_None=0,
	Operator_Add,
	Operator_Subtract,
	Operator_Multiply,
	Operator_Divide,
	Operator_Exponent,
};

stock void Operate(ArrayList sumArray, int& bracket, float value, ArrayList _operator)
{
	float sum=sumArray.Get(bracket);
	switch(_operator.Get(bracket))
	{
		case Operator_Add:
		{
			sumArray.Set(bracket, sum+value);
		}
		case Operator_Subtract:
		{
			sumArray.Set(bracket, sum-value);
		}
		case Operator_Multiply:
		{
			sumArray.Set(bracket, sum*value);
		}
		case Operator_Divide:
		{
			if(!value)
			{
				LogError("[FF2 Boss Selection] Detected a divide by 0!");
				bracket=0;
				return;
			}
			sumArray.Set(bracket, sum/value);
		}
		case Operator_Exponent:
		{
			sumArray.Set(bracket, Pow(sum, value));
		}
		default:
		{
			sumArray.Set(bracket, value);  //This means we're dealing with a constant
		}
	}
	_operator.Set(bracket, Operator_None);
}

stock void OperateString(ArrayList sumArray, int& bracket, char[] value, int size, ArrayList _operator)
{
	if(!StrEqual(value, ""))  //Make sure 'value' isn't blank
	{
		Operate(sumArray, bracket, StringToFloat(value), _operator);
		strcopy(value, size, "");
	}
}

/*
 * Parses a mathematical formula and returns the result,
 * or `defaultValue` if there is an error while parsing
 *
 * Variables may be present in the formula as long as they
 * are in the format `{variable}`.  Unknown variables will
 * be passed to the `OnParseUnknownVariable` forward
 *
 * Known variables include:
 * - players
 * - lives
 * - health
 * - speed
 *
 * @param boss          Boss index
 * @param key           The key to retrieve the formula from.  If the
 *                      key is nested, the nested sections must be
 *                      delimited by a `>` symbol like so:
 *                      "plugin name > ability name > distance"
 * @param defaultValue  The default value to return in case of error
 * @return The value of the formula, or `defaultValue` in case of error
 */
stock int ParseFormula(int boss, const char[] key, int defaultValue)
{
	char formula[1024], bossName[64];
	KeyValues kv = GetCharacterKVEx(boss);
	int playing = 0, version;

	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsValidClient(client) && TF2_GetClientTeam(client) > TFTeam_Spectator)
		{
			playing++;
		}
	}

	kv.Rewind();
	kv.GetString("name", bossName, sizeof(bossName), "=Failed name=");
	version = kv.GetNum("version", 1);

	char keyPortions[5][128];
	int portions=ExplodeString(key, ">", keyPortions, sizeof(keyPortions), 128);
	for(int i = 1; i < portions; i++)
	{
		kv.JumpToKey(keyPortions[i]);
	}
	kv.GetString(keyPortions[portions-1], formula, sizeof(formula));

	if(!formula[0])
	{
		return defaultValue;
	}

	if(version == 1)
		ReplaceString(formula, sizeof(formula), "n", "{players}");

	int size = 1;
	int matchingBrackets;
	for(int i; i <= strlen(formula); i++)  //Resize the arrays once so we don't have to worry about it later on
	{
		if(formula[i] == '(')
		{
			if(!matchingBrackets)
			{
				size++;
			}
			else
			{
				matchingBrackets--;
			}
		}
		else if(formula[i] == ')')
		{
			matchingBrackets++;
		}
	}

	ArrayList sumArray = CreateArray(_, size), _operator = CreateArray(_, size);
	int bracket;  //Each bracket denotes a separate sum (within parentheses).  At the end, they're all added together to achieve the actual sum
	bool escapeCharacter;
	sumArray.Set(0, 0.0);  //TODO:  See if these can be placed naturally in the loop
	_operator.Set(bracket, Operator_None);

	char currentCharacter[2], value[16], variable[16];  //We don't decl these because we directly append characters to them and there's no point in decl'ing currentCharacter
	for(int i; i <= strlen(formula); i++)
	{
		currentCharacter[0] = formula[i];  //Find out what the next char in the formula is
		switch(currentCharacter[0])
		{
			case ' ', '\t':  //Ignore whitespace
			{
				continue;
			}
			case '(':
			{
				bracket++;  //We've just entered a new parentheses so increment the bracket value
				sumArray.Set(bracket, 0.0);
				_operator.Set(bracket, Operator_None);
			}
			case ')':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
				if(_operator.Get(bracket) != Operator_None)  //Something like (5*)
				{
					LogError("[FF2 Boss Selection] %s's %s formula has an invalid operator at character %i", bossName, key, i + 1);
					delete sumArray;
					delete _operator;
					return defaultValue;
				}

				if(--bracket<0)  //Something like (5))
				{
					LogError("[FF2 Boss Selection] %s's %s formula has an unbalanced parentheses at character %i", bossName, key, i + 1);
					delete sumArray;
					delete _operator;
					return defaultValue;
				}

				Operate(sumArray, bracket, GetArrayCell(sumArray, bracket + 1), _operator);
			}
			case '\0':  //End of formula
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
			}
			case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.':
			{
				StrCat(value, sizeof(value), currentCharacter);  //Constant?  Just add it to the current value
			}
			/*case 'n', 'x':  //n and x denote player variables
			{
				Operate(sumArray, bracket, float(playing), _operator);
			}*/
			case '{':
			{
				escapeCharacter=true;
			}
			case '}':
			{
				if(!escapeCharacter)
				{
					LogError("[FF2 Boss Selection] %s's %s formula has an invalid escape character at character %i", bossName, key, i+1);
					delete sumArray;
					delete _operator;
					return defaultValue;
				}
				escapeCharacter=false;

				if(StrEqual(variable, "players", false))
				{
					Operate(sumArray, bracket, float(playing), _operator);
				}
				/*
				else if(StrEqual(variable, "health", false))
				{
					Operate(sumArray, bracket, float(BossHealth), _operator);
				}
				else if(StrEqual(variable, "lives", false))
				{
					Operate(sumArray, bracket, float(BossLives), _operator);
				}
				else if(StrEqual(variable, "speed", false))
				{
					Operate(sumArray, bracket, BossSpeed, _operator);
				}
				*/

				Format(variable, sizeof(variable), ""); // Reset the variable holder
			}
			case '+', '-', '*', '/', '^':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
				switch(currentCharacter[0])
				{
					case '+':
					{
						_operator.Set(bracket, Operator_Add);
					}
					case '-':
					{
						_operator.Set(bracket, Operator_Subtract);
					}
					case '*':
					{
						_operator.Set(bracket, Operator_Multiply);
					}
					case '/':
					{
						_operator.Set(bracket, Operator_Divide);
					}
					case '^':
					{
						_operator.Set(bracket, Operator_Exponent);
					}
				}
			}
			default:
			{
				if(escapeCharacter)  //Absorb all the characters into 'variable' if we hit an escape character
				{
					StrCat(variable, sizeof(variable), currentCharacter);
				}
				else
				{
					LogError("[FF2 Boss Selection] %s's %s formula has an invalid character at character %i", bossName, key, i + 1);
					delete sumArray;
					delete _operator;
					return defaultValue;
				}
			}
		}
	}

	int result = RoundFloat(GetArrayCell(sumArray, 0));
	delete sumArray;
	delete _operator;
	if(result<=0)
	{
		LogError("[FF2 Boss Selection] %s has an invalid %s formula, using default!", bossName, key);
		return defaultValue;
	}
/*
	if(bMedieval && StrEqual(key, "health"))
	{
		return RoundFloat(result / 3.6);  //TODO: Make this configurable
	}
*/
	return result;
}
