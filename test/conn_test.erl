-module(conn_test).

-export([start_tcp/0, start_ssh/0]).

start_tcp() ->
        emqttcli:start(),
	Conn = emqttcli:open_network_channel(tcp, <<"alvaro">>, {127,0,0,1}, 1883, [binary]),
	emqttcli:connect(Conn, <<>>, <<>>),
	emqttcli:disconnect(Conn).

	
start_ssh() ->
    ssh:start(),
    emqttcli:start(),
    Conn = emqttcli:open_network_channel(ssh, <<"alvaro">>, "192.168.56.101", 1884,
    [
      {user_dir, "/home/alvaro/devel/testes/erl-ssh-subsystem-test/client_key"},
      {silently_accept_hosts, true},
      {user_interaction, false},
      {user, "alvaro"},
      {nodelay, true}
      
    ]),
    emqttcli:connect(Conn, <<>>, <<>>).