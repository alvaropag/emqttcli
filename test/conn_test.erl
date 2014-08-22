-module(conn_test).

-export([start_tcp/0, start_ssh/0]).

-include("../include/emqttcli_types.hrl").
start_tcp() ->
    emqttcli:start(),
    Conn = emqttcli:open_network_channel(tcp, <<"alvaro">>, "127.0.0.1", 1883, 
    [
	binary, 
	{packet, raw},
	{active, false}, 
	{nodelay, true}, 
	{keepalive, true}
    ]),
    emqttcli:connect(Conn, <<>>, <<>>, true, 60),
    emqttcli:subscribe(Conn, [{<<"/teste">>, 'at_most_once'}]),
    emqttcli:publish(Conn, <<"/teste">>, <<"Hello World!">>, false),
    emqttcli:publish(Conn, <<"/testeqos2">>, <<"Hello World QoS2!">>, false, #qos{level = 'exactly_once'}),
    %Wait for 30 sec to receive some messages...
    %I'm cheating here, but it's just for tests...
    timer:sleep(30000),
    ItemsReceived = emqttcli:recv_msg(Conn),
    io:fwrite("Received ~p ~n", [ItemsReceived]),
    emqttcli:unsubscribe(Conn, [<<"/teste">>]),
    emqttcli:disconnect(Conn).

	
start_ssh() ->
    emqttcli:start(),
    Conn = emqttcli:open_network_channel(ssh, <<"alvaro">>, "127.0.0.1", 1884,
    [
      {user_dir, "/home/alvaro/devel/testes/erl-ssh-subsystem-test/client_key"},
      {silently_accept_hosts, true},
      {user_interaction, false},
      {user, "alvaro"},
      {nodelay, true}  
    ]),
    emqttcli:connect(Conn, <<>>, <<>>, true, 60),
    emqttcli:subscribe(Conn, [{<<"/teste">>, 'at_most_once'}]),
    emqttcli:publish(Conn, <<"/teste">>, <<"Hello World!">>, false),
    emqttcli:publish(Conn, <<"/testeqos2">>, <<"Hello World QoS2!">>, false, #qos{level = 'at_least_once'}),
    %Wait for 30 sec to receive some messages...
    %I'm cheating here, but it's just for tests...
    timer:sleep(30000),
    ItemsReceived = emqttcli:recv_msg(Conn),
    io:fwrite("Received ~p ~n", [ItemsReceived]),
    emqttcli:unsubscribe(Conn, [<<"/teste">>]),
    emqttcli:disconnect(Conn).
  
