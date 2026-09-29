enum DisnetEvent
{
	NONE = 0,
	CONNECTED = 1,
	DISCONNECTED = 2,
	RELIABLE = 3,
	UNRELIABLE = 4
}

function net_join(host, selected_lobby=-1)
{
	with(obj_netclient)
	{
		// The join box is a single line, so a port is written after a colon:
		// "203.0.113.10:20000". Without this the client could only ever reach
		// 8606, which made a server published on a relay port unjoinable.
		// Remembered in base_port so a reconnect, which passes the bare
		// address back in, returns to the same server instead of the default.
		var _host = host;
		var _mark = string_last_pos(":", _host);

		if(_mark > 0)
		{
			var _tail = string_copy(_host, _mark + 1, string_length(_host) - _mark);

			// string_digits strips everything else, so this only matches when
			// the tail is digits and nothing else.
			if(_tail != "" && string_digits(_tail) == _tail)
			{
				var _n = real(_tail);
				if(_n > 0 && _n < 65536)
				{
					base_port = _n;
					_host = string_copy(_host, 1, _mark - 1);
				}
			}
		}

		ip = _host;
		port = selected_lobby == -1 ? base_port : selected_lobby;
		want_lobby = selected_lobby;

		if(isConnected)
			return;

		room_goto(room_connecting);
	}

	return true;
}

function net_poll()
{
	var event = DisnetEvent.NONE;
	do
	{
		event = disnet_poll(buffer_get_address(buffer));
		switch(event)
		{
			case DisnetEvent.CONNECTED:
				show_debug_message("connected!");
				if(room != room_connecting)
				{
					net_reset();
					return;
				}
	
				ds_map_clear(pings);
				ds_map_clear(players);
				isReady = false;
				state = STATE_PENDING;
				udp_timeout = 60 * 5;
				sendTimeout = 60;
				isInit = false;
				exeId = 0;
				chance = 0;
				lvlId = -1;
				avCharacters = 
				[ 
					false, //0 (exe) (cannot)
					true,  //1 (tails)
					true,
					true,
					true,
					true,
					true
				];
		
				isConnected = true;
				room_goto(room_waiting);
				return;
		
			case DisnetEvent.DISCONNECTED:
				if(global.errorCode == -1)
				{
					show_debug_message("disconnected!");
					
					buffer_seek(buffer, buffer_seek_start, 0);
					global.errorCode = buffer_read(buffer, buffer_u32);
					room_goto(room_message);
				}
				return;
			
			case DisnetEvent.RELIABLE:
				buffer_seek(buffer, buffer_seek_start, 0);
			
				if(net_tcpprocess(buffer))
					return;
				
				break;
		
			case DisnetEvent.UNRELIABLE:
				if(state != STATE_GAME)
					break;
					
				buffer_seek(buffer, buffer_seek_start, 0);
				net_udpprocess(buffer);
				break;
		}
	
	}
	until(event == 0);
}