-module(emqttcli_socket_ssh_subsystem).

%% Implement the ssh_daemon_channel 
-behaviour(ssh_daemon_channel).

-export([start_link/3,
         init/1, 
         handle_ssh_msg/2, 
         handle_msg/2, 
         terminate/2, 
         code_change/3, 
         handle_call/3, 
         handle_cast/2]).

-record(state, {client_id, 
                conn_mgr, 
                channel_id, 
                emqttcli_connection_pid, 
                emqttcli_socket}).


start_link(CM, ChannelId, ClientId) ->
    ssh_channel:start(CM, ChannelId, ?MODULE, [ClientId]).
    
init([ClientId]) ->
    State = #state{client_id = ClientId},
    {ok, State}.
  

%%Received some data, let's forward it!!
handle_ssh_msg({ssh_cm, _ConnectionManager,
		{data, _ChannelId, Type, Data}}, 
               #state{emqttcli_connection_pid = EmqttcliConnectionPid, emqttcli_socket = EmqttcliSocket} = State) ->
    error_logger:info_msg("ssh_cm.data, ConnectionManager=~p, ChannelId=~p, Type=~p, Data=~s, State=~p~n", [_ConnectionManager, _ChannelId, Type, Data, State]),
    emqttcli_socket:send_data_to_conn(EmqttcliConnectionPid, Data, EmqttcliSocket),
    {ok, State};

handle_ssh_msg({ssh_cm, _, {eof, ChannelId}}, State) ->
    error_logger:info_msg("ssh_cm.eof, ChannelId=~p, State=~p~n", [ChannelId, State]),
    {stop, ChannelId, State};

handle_ssh_msg({ssh_cm, _, {signal, _, _}}, State) ->
    %% Ignore signals according to RFC 4254 section 6.9.
    error_logger:info_msg("ssh_cm.signal, State=~p~n", [State]),
    {ok, State};
 
handle_ssh_msg({ssh_cm, _, {exit_signal, ChannelId, _, Error, _}}, #state{emqttcli_connection_pid = EmqttcliConnectionPid, emqttcli_socket = EmqttcliSocket} = State) ->
    emqttcli_socket:send_error_to_conn(EmqttcliConnectionPid, Error, EmqttcliSocket),
    Report = io_lib:format("Connection closed by peer ~n Error ~p~n",
			   [Error]),
    error_logger:error_report(Report),
    {stop, ChannelId,  State};

handle_ssh_msg({ssh_cm, _, {exit_status, ChannelId, 0}}, #state{emqttcli_connection_pid = EmqttcliConnectionPid, emqttcli_socket = EmqttcliSocket} = State) ->
    emqttcli_socket:send_closed_to_conn(EmqttcliConnectionPid, EmqttcliSocket),
    error_logger:info_msg("ssh_cm.exit, ChannelId=~p, State=~p~n", [ChannelId, State]),
    {stop, ChannelId, State};

handle_ssh_msg({ssh_cm, _, {exit_status, ChannelId, Status}}, State) ->
    
    Report = io_lib:format("Connection closed by peer ~n Status ~p~n",
			   [Status]),
    error_logger:error_report(Report),
    {stop, ChannelId, State}.

handle_msg({ssh_channel_up, ChannelId, ConnectionManager}, State) ->
    error_logger:info_msg("ssh_channel_up, ChannelId=~p, ConnectioManager=~p, State=~p~n", [ChannelId, ConnectionManager, State]),
    %Here I have to recreate the socket record because of the SSH structure
    EmqttcliSocket = emqttcli_socket:create_socket(ssh, ConnectionManager, ChannelId, self()),

    {ok, State#state{conn_mgr = ConnectionManager, channel_id = ChannelId, emqttcli_socket = EmqttcliSocket}}.    
		     
terminate(Reason, State) ->
    error_logger:info_msg("terminate, Reason=~p, State=~p~n", [Reason, State]),
    ok. 

handle_call(_Msg, _From, State) -> 
    {noreply, State}.

handle_cast({emqttcli_connection_pid, EmqttcliConnection}, State) ->
    io:fwrite("SSH Subsystem received emqttcli_connection_pid~n"),
    {noreply, State#state{emqttcli_connection_pid = EmqttcliConnection}};

handle_cast(Msg, State) ->
    io:fwrite("Received cast with Msg=~p, State=~p~n", [Msg, State]),
    {noreply, State}.


code_change(_OldVsn, State, _Extra) -> 
    {ok, State}.
