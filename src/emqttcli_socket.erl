-module(emqttcli_socket).

-include("emqttcli_socket.hrl").

-export([send/2, 
         close/1, 
         send_data_to_mgr/3, 
         send_closed_to_mgr/2, 
         send_error_to_mgr/3]).

send(#emqttcli_socket{type = tcp, connection = Conn}, Data) when is_binary(Data) ->
     gen_tcp:send(Conn, Data);

send(#emqttcli_socket{type = tcp}, Data) ->
    {error, "Data is not binary"};

send(#emqttcli_socket{type = ssh, connection = ConnMgr, channel = ChannelId}, Data) when is_binary(Data)->
    ssh_connection:send(ConnMgr, ChannelId, Data, 5000);

send(_, _) ->
    {error, "Impossible to send the data"}.



close(#emqttcli_socket{type = tcp, connection = Conn}) ->
    gen_tcp:close(Conn);

close(#emqttcli_socket{type = ssh, connection = ConnMgr, channel = ChannelId}) ->
    ssh_connection:close(ConnMgr, ChannelId).


send_data_to_mgr(ConnectionMgr, Data, EmqttcliSocket) ->
    ok. %%gen_fsm:send_event(ConnectionMgr, {data, Data, EmqttcliSocket})

send_closed_to_mgr(ConnectionMgr, EmqttcliSocket) ->
    ok. %%gen_fsm:send_all_state_event(ConnectionMgr, {closed, EmqttcliSocket}).

send_error_to_mgr(ConnectionMgr, Reason, EmqttcliSocket) ->
    ok. %%gen_fsm:send_all_state_event(ConnectionMgr, {error, Reason, EmqttcliSocket}).