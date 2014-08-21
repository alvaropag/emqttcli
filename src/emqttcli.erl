-module(emqttcli).

-include("emqttcli.hrl").

-include("emqttcli_frames.hrl").
-include("emqttcli_types.hrl").


-export([
         start/0,
         open_network_channel/5, 
         open_network_channel/6, 
         connect/3,
         connect/4,
         connect/5,
         connect/6,
         disconnect/1, 
         subscribe/2,
         unsubscribe/2,
         publish/4,
         publish/5,
         recv_msg/1,
         register_recv_msg_cb/2, 
         unregister_recv_msg_cb/2]).


start() ->
    application:start(sals),
    lager:start(),
    ssh:start(),
    application:start(emqttcli).

open_network_channel(Type, ClientId, Address, Port, Options) ->
   open_network_channel(Type, ClientId, Address, Port, Options, undefined).

%Connect function for TCP
open_network_channel(tcp, ClientId, Address, Port, Options, CBPid) ->
     %Start the gen_server that will handle this TCP connection
    {ok, EmqttcliSocketTCPPid} = emqttcli_socket_sup:start_child(emqttcli_socket_tcp:spec(ClientId)),

    case  emqttcli_socket_tcp:open_conn_channel(EmqttcliSocketTCPPid, Address, Port, Options) of
        {ok, EmqttcliSocket} ->

            %Start the emqttcli_connection (gen_fsm) responsible to handle the protocol status...
            {ok, EmqttcliConnection} = supervisor:start_child(emqttcli_connection_sup, 
                emqttcli_connection:spec(ClientId)),

            register_recv_msg_cb(EmqttcliConnection, CBPid),

            % I know it's not elegant, but I need the Socket and the Connection to know
            % about each other...
            lager:debug("Sending Socket ~p to Connection ~p~n", [EmqttcliSocket, EmqttcliConnection]),
            emqttcli_connection:setSocket(EmqttcliConnection, EmqttcliSocket),
    
            %set the PID of the emqttcli_connection gen_fsm in the emqttcli_socket_tcp 
            %gen_server, so that it can forward the data to be handled by the emqttcli_connection
            emqttcli_socket_tcp:set_emqttcli_connection_pid(EmqttcliSocketTCPPid, EmqttcliConnection),
       
            %Starts the socket to receive data
            emqttcli_socket_tcp:activate_socket(EmqttcliSocketTCPPid),
            
            %Return record for the user, so he can call other functions
            #emqttcli{emqttcli_id = ClientId, emqttcli_connection = EmqttcliConnection, emqttcli_socket = EmqttcliSocket};

        %%Ops, something went wrong...
        {error, Reason} -> {error, Reason}
    end;


%Connect function for SSH
open_network_channel(ssh, ClientId, Address, Port, Options, CBPid) ->
    %Create the socket process
    {ok, EmqttcliSocketSSHPid} = emqttcli_socket_sup:start_child(emqttcli_socket_ssh:spec(ClientId)),

    %Open the SSH connection + channel + subsystem
    case emqttcli_socket_ssh:open_conn_channel(EmqttcliSocketSSHPid, Address, Port, Options, ClientId) of
        {ok, EmqttcliSocket} ->

            %Start the emqttcli_connection (gen_fsm) responsible to handle the protocol status...
            {ok, EmqttcliConnection} = supervisor:start_child(emqttcli_connection_sup, 
                emqttcli_connection:spec(ClientId)),

            emqttcli_connection:setSocket(EmqttcliConnection, EmqttcliSocket),

            register_recv_msg_cb(EmqttcliConnection, CBPid),
    
            %set the PID of the emqttcli_connection gen_fsm in the emqttcli_socket_tcp 
            %gen_server, so that it can forward the data to be handled by the emqttcli_connection
            emqttcli_socket_ssh:set_emqttcli_connection_pid(EmqttcliSocketSSHPid, EmqttcliConnection),
       
            %Return record for the user, so he can call other functions
            #emqttcli{emqttcli_id = ClientId, emqttcli_connection = EmqttcliConnection, emqttcli_socket = EmqttcliSocket};


        {error, Reason} -> {error, Reason}
    end.


%connect(#emqttcli, username, password, clean_session, will)
connect(EmqttcliRec, UserName, Password) ->
    connect(EmqttcliRec, UserName, Password, true).

connect(EmqttcliRec, UserName, Password, CleanSession) ->
    connect(EmqttcliRec, UserName, Password, CleanSession, 60).

connect(EmqttcliRec, UserName, Password, CleanSession, KeepAlive) ->
    connect(EmqttcliRec, UserName, Password, CleanSession, KeepAlive, undefined).

connect(#emqttcli{emqttcli_id = ClientId, emqttcli_connection = EmqttcliConnection}, UserName, Password, CleanSession, KeepAlive, Will) ->
    Connect = #connect{
        clean_session = CleanSession, 
        will = Will, 
        username = UserName, 
        password = Password, 
        client_id = ClientId, 
        keep_alive = KeepAlive},
    gen_fsm:sync_send_event(EmqttcliConnection, {try_connect, Connect}, 60000).


%Disconnects the client
disconnect(#emqttcli{emqttcli_socket = EmqttcliSocket, emqttcli_connection = EmqttcliConnection}) ->
    gen_fsm:send_all_state_event(EmqttcliConnection, disconnect),
    timer:sleep(5000),
    emqttcli_socket:close(EmqttcliSocket),
    ok.

subscribe(#emqttcli{emqttcli_connection = EmqttcliConnection}, Subscriptions) ->
    gen_fsm:sync_send_event(EmqttcliConnection, {subscribe, Subscriptions}).


unsubscribe(#emqttcli{emqttcli_connection = EmqttcliConnection}, Subscriptions) ->
    gen_fsm:sync_send_event(EmqttcliConnection, {unsubscribe, Subscriptions}).

% Publish with QoS 0
publish(#emqttcli{emqttcli_connection = EmqttcliConnection}, Topic, Msg, Retain) ->
    Pub = #publish{
       qos = 'at_most_once',
       retain = Retain,
       topic = Topic,
       payload = Msg
    },
    gen_fsm:sync_send_event(EmqttcliConnection, {publish, Pub}).

% Publish with QoS 1 or 2
publish(EmqttcliRec, Topic, Msg, Retain, QoS) when is_atom(QoS) ->
    publish(EmqttcliRec, Topic, Msg, Retain, #qos{level = QoS});

publish(#emqttcli{emqttcli_connection = EmqttcliConnection}, Topic, Msg, Retain, QoS) ->
    Pub = #publish{
       qos = QoS,
       retain = Retain,
       topic = Topic,
       payload = Msg
    },
    gen_fsm:sync_send_event(EmqttcliConnection, {publish, Pub}).
    

recv_msg(#emqttcli{emqttcli_connection = EmqttcliConnection}) ->
    gen_fsm:sync_send_event(EmqttcliConnection, {get_msgs}).


%Async
register_recv_msg_cb(EmqttcliConnection, CBPid) when is_pid(CBPid)->
    emqttcli_connection:register_recv_msg_cb(EmqttcliConnection, CBPid);

register_recv_msg_cb(_, _) -> ok.

%Async
unregister_recv_msg_cb(EmqttcliConnection, CBPid) when is_pid(CBPid) ->
    emqttcli_connection:register_recv_msg_cb(EmqttcliConnection, CBPid);

unregister_recv_msg_cb(_, _) -> ok.
