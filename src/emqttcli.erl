-module(emqttcli).

-include("emqttcli.hrl").

-export([connect/6]).


%Connect function for TCP
connect(tcp, ClientId, Address, Port, Options, CallbackModule) ->
    %Start the TCP connection
    {ok, Socket} = gen_tcp:connect(Address, Port, Options),

    %Create the #emqttcli_socket record
    EmqttcliSocket = emqttcli_socket:create_socket(tcp, Socket),

    %Start the gen_server that will handle this TCP connection
    {ok, EmqttcliSocketTCP} = supervisor:start_child(emqttcli_socket_sup, emqttcli_socket_tcp:spec(ClientId, EmqttcliSocket)),

    %Transfer the ownership of the Socket to the emqttcli_socket_tcp gen_server
    gen_tcp:controlling_process(Socket, EmqttcliSocketTCP),

    %Start the emqttcli_connection (gen_fsm) responsible to handle the protocol status...
    {ok, EmqttcliConnection} = supervisor:start_child(emqttcli_connection_sup, emqttcli_connection:spec(ClientId, CallbackModule)),
    
    %set the PID of the emqttcli_connection gen_fsm in the emqttcli_socket_tcp gen_server, so that it can forward the data to be handled by the emqttcli_connection
    emqttcli_socket_tcp:set_emqttcli_connection_pid(EmqttcliSocketTCP, EmqttcliConnection),

    %Return record for the user, so he can call other functions
    #emqttcli{emqttcli_id = ClientId, emqttcli_socket = EmqttcliSocket}.
    
