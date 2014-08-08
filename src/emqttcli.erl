-module(emqttcli).

-include("emqttcli.hrl").

-export([connect/6, disconnect/1]).


%Connect function for TCP
connect(tcp, ClientId, Address, Port, Options, CallbackModule) ->
     %Start the gen_server that will handle this TCP connection
    {ok, EmqttcliSocketTCPPid} = emqttcli_socket_sup:start_child(emqttcli_socket_tcp:spec(ClientId)),

    case  emqttcli_socket_tcp:open_conn_channel(EmqttcliSocketTCPPid, Address, Port, Options) of
        {ok, EmqttcliSocket} ->
            %Start the emqttcli_connection (gen_fsm) responsible to handle the protocol status...
            {ok, EmqttcliConnection} = supervisor:start_child(emqttcli_connection_sup, 
                emqttcli_connection:spec(ClientId, CallbackModule)),
    
            %set the PID of the emqttcli_connection gen_fsm in the emqttcli_socket_tcp 
            %gen_server, so that it can forward the data to be handled by the emqttcli_connection
            emqttcli_socket_tcp:set_emqttcli_connection_pid(EmqttcliSocketTCPPid, EmqttcliConnection),
       
            %Starts the socket to receive data
            emqttcli_socket_tcp:activate_socket(EmqttcliSocketTCPPid),
            
            %Return record for the user, so he can call other functions
            #emqttcli{emqttcli_id = ClientId, emqttcli_socket = EmqttcliSocket};

        %%Ops, something went wrong...
        {error, Reason} -> {error, Reason}
    end;


%Connect function for SSH
connect(ssh, ClientId, Address, Port, Options, CallbackModule) ->
    %Create the socket process
    {ok, EmqttcliSocketSSHPid} = emqttcli_socket_sup:start_child(emqttcli_socket_ssh:spec(ClientId, CallbackModule)),

    %Open the SSH connection + channel + subsystem
    case emqttcli_socket_ssh:open_conn_channel(EmqttcliSocketSSHPid, Address, Port, Options, ClientId) of
        {ok, EmqttcliSocket} ->
            #emqttcli{emqttcli_id = ClientId, emqttcli_socket = EmqttcliSocket};
        {error, Reason} -> {error, Reason}
    end.


%Disconnects the socket
disconnect(#emqttcli{emqttcli_socket = EmqttcliSocket}) ->
   emqttcli_socket:close(EmqttcliSocket).


%publish
%subscribe
%unsubscribe

    
