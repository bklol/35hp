#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
//#include <nekocore>

#define iClutch 3

bool VoteAlready;
bool GiveSnowBall;
bool IsBlock;
int hp;

int g_iOpponents; 
int g_iClutchFor;

public void OnPluginStart()
{
	GiveSnowBall = false;
	
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("round_prestart", VoteHp);
	
	HookEvent("round_end", Event_RoundEnd); 
	HookEvent("player_death", Event_Death); 
	
	RegConsoleCmd("sm_knifeadmin",knifeadmin);
	
}

public void OnMapStart()
{
	IsBlock = true;
	VoteAlready = false;
	hp = 35;
	
	PrecacheSound("weapons/party_horn_01.wav");
	
}

public Action PlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	
	int client=GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidClient(client))
	{
		RemoveGuns(client);
		CreateTimer(0.2,GiveHp,client);
	}
}

public Action GiveHp(Handle timer, int client)
{
	SetEntProp(client, Prop_Send, "m_iHealth", hp, 1);
	SetEntProp(client, Prop_Send, "m_ArmorValue",0, 1);
}

public Action knifeadmin(int client,int ags)
{
	/**
	if(!NEKO_IsAdmin(client))
	{
		PrintToChat(client,"没有权限");
		return;
	}
	**/
	Menus_Show(client);
}

void Menus_Show(int client)
{
	Menu menu = new Menu(Handler_MainMenu);
	menu.SetTitle("[Neko]刀服菜单");
	char buffer[32];
	Format(buffer,32,"出生装备雪球%s",GiveSnowBall?"[开启]":"[关闭]");
	menu.AddItem("1", buffer);
	Format(buffer,32,"屏蔽地图强制35HP%s",IsBlock?"[开启]":"[关闭]");
	menu.AddItem("2", buffer);
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_MainMenu(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch (itemNum)
		{
			case 0:
			{
				GiveSnowBall = !GiveSnowBall;
				PrintToChatAll("管理员%N，%s 了 给每个玩家出生时一个雪球",client,GiveSnowBall?"开启":"关闭");
			}
			case 1:
			{
				IsBlock = !IsBlock;
				PrintToChatAll("管理员%N，%s 了 屏蔽地图 强制35HP",client,IsBlock?"开启":"关闭");
			}
		}
	}
}

//block map trigger

public void OnEntityCreated(int entity, const char[] classname) {

	if(StrEqual(classname, "trigger_multiple"))
	{
		SDKHook(entity, SDKHook_Use, OnEntityUse);
		SDKHook(entity, SDKHook_StartTouch, OnEntityUse);
		SDKHook(entity, SDKHook_Touch, OnEntityUse);
		SDKHook(entity, SDKHook_EndTouch, OnEntityUse);
	}
}

public Action OnEntityUse(int entity, int client)
{
	if(IsBlock)
		return Plugin_Handled;
	return Plugin_Continue;
}

public Action VoteHp(Event event, const char[] name, bool dontBroadcast)
{

	if (GameRules_GetProp("m_bWarmupPeriod"))
    {
		VoteAlready = false;
		return;
	}
	if (!VoteAlready)
		DoVoteMenu();
}

public int Handle_VoteMenu(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        /* This is called after VoteEnd */
        delete menu;
    }
}
 
public void Handle_VoteResults(Menu menu, 
        int num_votes, 
        int num_clients, 
        const int[][] client_info, 
        int num_items, 
        const int[][] item_info)
{
	int winner = 0;
	if (num_items > 1
	&& (item_info[0][VOTEINFO_ITEM_VOTES] == item_info[1][VOTEINFO_ITEM_VOTES])
	&& (item_info[1][VOTEINFO_ITEM_VOTES] == item_info[2][VOTEINFO_ITEM_VOTES]))
	{
		winner = GetRandomInt(0, 2);
	}
	
	char results[8];
	menu.GetItem(item_info[winner][VOTEINFO_ITEM_INDEX], results, sizeof(results));
	hp = StringToInt(results);
	PrintToChatAll("投票结束,血量设定为%i",hp);
	ServerCommand("mp_restartgame 2");
	VoteAlready = true;
	
}

void DoVoteMenu()
{
	if (IsVoteInProgress())
	{
		return;
	}
	Menu menu = new Menu(Handle_VoteMenu);
	menu.VoteResultCallback = Handle_VoteResults;
	menu.SetTitle("出生血量投票");
	menu.AddItem("35", "35Hp");
	menu.AddItem("50", "50Hp");
	menu.AddItem("100", "100Hp");
	menu.ExitButton = false;
	menu.DisplayVoteToAll(20);
}

RemoveGuns(client)
{
	
	int WpnId = GetPlayerWeaponSlot(client,0);
	if (WpnId!=-1)
	{
		RemovePlayerItem(client, WpnId);
		AcceptEntityInput(WpnId, "Kill");
	}
	
	WpnId = GetPlayerWeaponSlot(client,1);
	if (WpnId!=-1)
	{
		RemovePlayerItem(client, WpnId);
		AcceptEntityInput(WpnId, "Kill");
	}
	
	WpnId = GetPlayerWeaponSlot(client,2);
	while (WpnId!=-1)
	{
		RemovePlayerItem(client, WpnId);
		AcceptEntityInput(WpnId, "Kill");
		WpnId = GetPlayerWeaponSlot(client,2);
	}
	
	WpnId = GetPlayerWeaponSlot(client,3);
	while (WpnId!=-1)
	{
		RemovePlayerItem(client, WpnId);
		AcceptEntityInput(WpnId, "Kill");
		WpnId = GetPlayerWeaponSlot(client,3);
	}
	
	GivePlayerItem(client,"weapon_knife");
	if(GiveSnowBall)
		GivePlayerItem(client,"weapon_snowball");
}

public void Event_BombPickup(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	StripC4(client); 
}

bool StripC4(int client)
{
    if (IsValidClient(client) && IsPlayerAlive(client))
    {
        int c4Index = GetPlayerWeaponSlot(client, CS_SLOT_C4);
        if (c4Index != -1)
        {
            char weapon[24];
            GetClientWeapon(client, weapon, sizeof(weapon));
            /* If the player is holding C4, switch to the best weapon before removing it. */
            if (StrEqual(weapon, "weapon_c4"))
            {
                ClientCommand(client, "slot2");
            }
            RemovePlayerItem(client, c4Index);
            AcceptEntityInput(c4Index, "Kill");
            return true;
        }
    }
    return false;
}

public void OnClientPutInServer(int client)
{
	//SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
	SDKHook(client, SDKHook_WeaponDropPost, Event_WeaponDrop);
	//SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Event_WeaponDrop(client, weapon)
{
	if(!IsValidEntity(weapon)|| weapon < 0)
		return;
	CreateTimer(0.1, removeWeapon, EntIndexToEntRef(weapon), TIMER_FLAG_NO_MAPCHANGE);
}

public Action removeWeapon(Handle hTimer, any iWeaponRef)
{
	static weapon;
	weapon = EntRefToEntIndex(iWeaponRef);
	if(iWeaponRef == INVALID_ENT_REFERENCE || !IsValidEntity(weapon)|| weapon < 0)
		return;
	AcceptEntityInput(weapon, "kill");
    
}

public void OnClientDisconnect_Post(int client)
{
	CheckAlive();
}

public Action Event_Death(Event event, char[] name, bool dontBroadcast) 
{ 
	CheckAlive();
} 

public void CheckAlive()
{
	// if already in a clutch situation then dont continue
	if(g_iClutchFor > 0)
		return;
		
	// get alive cts and ts
	int g_iTeamCT, g_iTeamT; 
	for (int i = 1; i <= MaxClients; i++) 
	{ 
		if(IsClientInGame(i) && IsPlayerAlive(i)) 
		{ 
			if(GetClientTeam(i) == CS_TEAM_CT) 
				g_iTeamCT++; 
			else if(GetClientTeam(i) == CS_TEAM_T) 
				g_iTeamT++; 
		} 
	} 
	
	// if only 1 player alive in the then and enought players in the other team
	
	if(g_iTeamT == 1  && g_iTeamCT >= iClutch) 
	{ 
		g_iClutchFor = CS_TEAM_T; // get clutch team
		g_iOpponents = g_iTeamCT; // get oponnents number
	} 
	else if(g_iTeamCT == 1  && g_iTeamT >= iClutch) 
	{
		g_iClutchFor = CS_TEAM_CT;
		g_iOpponents = g_iTeamT; 
	} 
} 

public Action Event_RoundEnd(Event event, char[] name, bool dontBroadcast) 
{ 
	if(g_iClutchFor != 0 && g_iOpponents >= iClutch) 
	{
		// if team winner is equal to the clutch player
		if(GetEventInt(event, "winner") == g_iClutchFor)
		{
			// get the last player alive that is should be the protagonist
			int client = GetClutchPlayerIndex();
			if(client > 0)
			{
        		PrintToChatAll(" [\x06翻盘成功\x01] 玩家 %N 获得了一次 单人翻盘的胜利！", client); 
        		CreateParticle(client, "weapon_confetti_balloons", 5.0); 
        	}
		}
	}
	g_iClutchFor = 0;
	g_iOpponents = 0; 
} 

stock void CreateParticle(int ent, char[] particleType, float time) 
{ 
    int particle = CreateEntityByName("info_particle_system"); 
     
    char name[64]; 
     
    if (IsValidEdict(particle)) 
    { 
        float position[3]; 
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", position); 
        TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR); 
        GetEntPropString(ent, Prop_Data, "m_iName", name, sizeof(name)); 
        DispatchKeyValue(particle, "targetname", "tf2particle"); 
        DispatchKeyValue(particle, "parentname", name); 
        DispatchKeyValue(particle, "effect_name", particleType); 
        DispatchSpawn(particle); 
        SetVariantString(name); 
        AcceptEntityInput(particle, "SetParent", particle, particle, 0); 
        ActivateEntity(particle); 
        AcceptEntityInput(particle, "start"); 
        CreateTimer(time, DeleteParticle, particle); 
    } 
    EmitSoundToAll("weapons/party_horn_01.wav");   
} 

public Action DeleteParticle(Handle timer, any particle) 
{ 
    if (IsValidEntity(particle)) 
    { 
        char classN[64]; 
        GetEdictClassname(particle, classN, sizeof(classN)); 
        if (StrEqual(classN, "info_particle_system", false)) 
        { 
            AcceptEntityInput(particle, "Kill");
        } 
    } 
}

int GetClutchPlayerIndex()
{
	int index;
	
	for (int i = 1; i <= MaxClients; i++) 
	{ 
		if(IsClientInGame(i) && IsPlayerAlive(i)) 
		{ 
			if(GetClientTeam(i) == g_iClutchFor) 
				index = i;
		} 
	} 	
    
	return index;
}

stock bool IsValidClient( client )
{
	if ( client < 1 || client > MaxClients ) return false;
	if ( !IsClientConnected( client )) return false;
	if ( !IsClientInGame( client )) return false;
	//if ( IsFakeClient(client)) return false;
	return true;
}