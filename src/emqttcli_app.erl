-module(emqttcli_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
    {ok, Pid} = emqttcli_sup:start_link(),
    register(emqttcli, self()),
    {ok, Pid}.

stop(_State) ->
    ok.
