  
#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>


ConVar sv_full_alltalk;

bool VoteAlready;

int hp;

public void OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("round_start", VoteHp);
	sv_full_alltalk = FindConVar("sv_alltalk");
	sv_full_alltalk.IntValue = 1;
	HookConVarChange(sv_full_alltalk,OnMapCvrChanged);
}

public void OnMapStart()
{
	VoteAlready = false;
	hp = 35;
}

public void OnMapCvrChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	sv_full_alltalk.IntValue = 1;
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
	return Plugin_Handled;
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

stock bool IsValidClient( client )
{
	if ( client < 1 || client > MaxClients ) return false;
	if ( !IsClientConnected( client )) return false;
	if ( !IsClientInGame( client )) return false;
	if ( IsFakeClient(client)) return false;
	return true;
}