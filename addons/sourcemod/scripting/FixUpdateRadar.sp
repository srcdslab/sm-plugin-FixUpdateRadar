#pragma semicolon 1

#include <sourcemod>

#pragma newdecls required

// Should not need more than 16
#define QUEUE_SIZE		24
#define MAX_BYTES		252

bool g_bQueued[QUEUE_SIZE];
int g_iBytes[QUEUE_SIZE][MAX_BYTES];
int g_iBytesNum[QUEUE_SIZE];
int g_iLastBit[QUEUE_SIZE];
int g_iPlayers[QUEUE_SIZE][MAXPLAYERS+1];
int g_iPlayersNum[QUEUE_SIZE];

bool g_bConnected[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "Fix Update Radar",
	author = "GoD-Tony, maxime1907",
	description = "Fixes the UpdateRadar usermessage on large servers",
	version = "1.0.2",
	url = "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
	HookUserMessage(GetUserMessageId("UpdateRadar"), Hook_UpdateRadar, true);
}

public void OnClientConnected(int client)
{
	g_bConnected[client] = true;
}

public void OnClientDisconnect(int client)
{
	g_bConnected[client] = false;
}

public Action Hook_UpdateRadar(UserMsg msg_id, Handle bf, const int[] players, int playersNum, bool reliable, bool init)
{
	BfRead bfRead = UserMessageToBfRead(bf);
	int bytesLeft = bfRead.BytesLeft;
	if (bytesLeft > 253)
	{
		int count, index = GetOpenQueue();

		// We don't want the closing byte.
		// Copied a byte at a time, but the same bits as reading bit by bit while more than one byte is left:
		// every byte except the last two, then one more bit.
		for (int read = 0; read < bytesLeft - 2; read++)
		{
			g_iBytes[index][count] = bfRead.ReadByte();
			count++;
			
			// 252 bytes
			if (count == MAX_BYTES)
			{
				g_iBytesNum[index] = count;
				g_iLastBit[index] = -1;
				g_iPlayersNum[index] = playersNum;
				
				for (int i = 0; i < playersNum; i++)
				{
					g_iPlayers[index][i] = players[i];
				}
				
				g_bQueued[index] = true;
				index = GetOpenQueue();
				count = 0;
			}
		}

		g_iBytesNum[index] = count;
		g_iLastBit[index] = view_as<int>(bfRead.ReadBool());
		g_iPlayersNum[index] = playersNum;
		
		for (int i = 0; i < playersNum; i++)
		{
			g_iPlayers[index][i] = players[i];
		}
		
		g_bQueued[index] = true;

		// Block this one and send out the queued messages later.
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void SendQueuedMsg(int index)
{
	// Make sure each client is still connected.
	for (int i = 0; i < g_iPlayersNum[index]; i++)
	{
		// Remove the player from the array.
		if (!g_bConnected[g_iPlayers[index][i]])
		{
			for (int j = i; j < g_iPlayersNum[index]-1; j++)
			{
				g_iPlayers[index][j] = g_iPlayers[index][j+1];
			}
			
			g_iPlayersNum[index]--;
			i--;
		}
	}

	// Don't send the message if there are no recipients.
	if(g_iPlayersNum[index] <= 0)
		return;

	Handle hBf = StartMessage("UpdateRadar", g_iPlayers[index], g_iPlayersNum[index], USERMSG_BLOCKHOOKS);
	BfWrite bfWrite = UserMessageToBfWrite(hBf);

	for (int i = 0; i < g_iBytesNum[index]; i++)
	{
		bfWrite.WriteByte(g_iBytes[index][i]);
	}

	if (g_iLastBit[index] != -1)
		bfWrite.WriteBool(view_as<bool>(g_iLastBit[index]));

	bfWrite.WriteByte(0);
	EndMessage();
}

public int GetOpenQueue()
{
	// Return the first free queue spot we find.
	for (int i = 0; i < QUEUE_SIZE; i++)
	{
		if (!g_bQueued[i])
		{
			return i;
		}
	}

	// Free up a spot.
	g_bQueued[0] = false;
	return 0;
}

public void OnGameFrame()
{
	// Send out all queued messages.
	for (int i = 0; i < QUEUE_SIZE; i++)
	{
		if (g_bQueued[i])
		{
			SendQueuedMsg(i);
			g_bQueued[i] = false;
		}
	}
}
