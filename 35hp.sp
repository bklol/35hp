  
#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>

ConVar sv_full_alltalk;

public void OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn);
	sv_full_alltalk = FindConVar("sv_full_alltalk");
	sv_full_alltalk.IntValue = 1;
	HookConVarChange(sv_full_alltalk,OnMapCvrChanged);
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
		SetEntProp(client, Prop_Send, "m_iHealth", 35, 1);
		SetEntProp(client, Prop_Send, "m_ArmorValue",0, 1);
		
	}
}

RemoveGuns(client)
{
	
	int WpnId = GetPlayerWeaponSlot(client,1)
	if (WpnId!=-1)
	{
		RemovePlayerItem(client, WpnId)
		AcceptEntityInput(WpnId, "Kill")
	}
	WpnId = GetPlayerWeaponSlot(client,2)
	if (WpnId!=-1)
	{
		RemovePlayerItem(client, WpnId)
		AcceptEntityInput(WpnId, "Kill")
	}
	WpnId = GetPlayerWeaponSlot(client,3)
	if (WpnId!=-1)
	{
		RemovePlayerItem(client, WpnId)
		AcceptEntityInput(WpnId, "Kill")
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
                ClientCommand(client, "slot3");
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
	//SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_WeaponDropPost, Event_WeaponDrop);
}

public Event_WeaponDrop(client, weapon)
{
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