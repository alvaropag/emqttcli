-module(emqttcli_socket).

-include("emqttcli_socket.hrl").

-export([sync_send/2, 
         async_send/2,
         close/1, 
         send_data_to_conn/3, 
         send_closed_to_conn/2, 
         send_error_to_conn/3,
         create_socket/3,
         create_socket/4]).

sync_send(#emqttcli_socket{type = tcp, socket_pid = SocketPid}, Data) -> % when is_binary(Data) ->
    gen_server:call(SocketPid, {sync_send, Data});

sync_send(#emqttcli_socket{type = ssh, socket_pid = SocketPid}, Data) -> %when is_binary(Data)->
    gen_server:call(SocketPid, {sync_send, Data});

% Worst error message EVER!
sync_send(Socket, Data) ->
    IsBinary = is_binary(Data),
    lager:debug("emqttcli_socket:sync_send(~p, ~s) is_binary = ~p~n", [Socket, Data, IsBinary]),
    {error, "General error"}.


%async_send(#emqttcli_socket{type = tcp, socket_pid = SocketPid}, Data) when is_binary(Data) ->
%    gen_server:cast(SocketPid, {async_send, Data});

%async_send(#emqttcli_socket{type = ssh, socket_pid = SocketPid}, Data) when is_binary(Data)  ->
%    gen_server:cast(SocketPid, {async_send, Data});

async_send(_, _) ->
    {error, "General error"}.


close(#emqttcli_socket{type = tcp, connection = Conn}) ->
    gen_tcp:close(Conn);

close(#emqttcli_socket{type = ssh, connection = ConnMgr, channel = ChannelId}) ->
    ssh_connection:close(ConnMgr, ChannelId).


create_socket(tcp, Socket, EmqttcliSocketPid) ->
    #emqttcli_socket{type = tcp, connection = Socket, channel = undefined, socket_pid = EmqttcliSocketPid}.

create_socket(ssh, CM, ChannelId, EmqttcliSocketPid) ->
    #emqttcli_socket{type = ssh, connection = CM, channel = ChannelId, socket_pid = EmqttcliSocketPid}.

send_data_to_conn(ConnectionMgr, Data, EmqttcliSocket) ->
    emqttcli_connection:recv_data(ConnectionMgr, Data, EmqttcliSocket).

send_closed_to_conn(ConnectionMgr, EmqttcliSocket) ->
    emqttcli_connection:recv_closed(ConnectionMgr, EmqttcliSocket).

send_error_to_conn(ConnectionMgr, Reason, EmqttcliSocket) ->
    emqttcli_connection:recv_error(ConnectionMgr, Reason, EmqttcliSocket).
