-module(emqttcli_socket).

-include("emqttcli_socket.hrl").

-export([send/2, 
         close/1, 
         send_data_to_conn/3, 
         send_closed_to_conn/2, 
         send_error_to_conn/3,
         create_socket/2,
         create_socket/4]).

send(#emqttcli_socket{type = tcp, connection = Conn}, Data) when is_binary(Data) ->
     gen_tcp:send(Conn, Data);

send(#emqttcli_socket{type = tcp}, _Data) ->
    {error, "Data is not binary"};

send(#emqttcli_socket{type = ssh, connection = ConnMgr, channel = ChannelId}, Data) when is_binary(Data)->
    ssh_connection:send(ConnMgr, ChannelId, Data, 5000);

send(_, _) ->
    {error, "Impossible to send the data"}.



close(#emqttcli_socket{type = tcp, connection = Conn}) ->
    gen_tcp:close(Conn);

close(#emqttcli_socket{type = ssh, connection = ConnMgr, channel = ChannelId}) ->
    ssh_connection:close(ConnMgr, ChannelId).


create_socket(tcp, Socket) ->
    #emqttcli_socket{type = tcp, connection = Socket}.

create_socket(ssh, CM, ChannelId, ChannelPid) ->
    #emqttcli_socket{type = ssh, connection = CM, channel = ChannelId, ssh_channel_pid = ChannelPid}.

send_data_to_conn(ConnectionMgr, Data, EmqttcliSocket) ->
    emqttcli_connection:recv_data(ConnectionMgr, Data, EmqttcliSocket).

send_closed_to_conn(ConnectionMgr, EmqttcliSocket) ->
    emqttcli_connection:recv_closed(ConnectionMgr, EmqttcliSocket).

send_error_to_conn(ConnectionMgr, Reason, EmqttcliSocket) ->
    emqttcli_connection:recv_error(ConnectionMgr, Reason, EmqttcliSocket).
