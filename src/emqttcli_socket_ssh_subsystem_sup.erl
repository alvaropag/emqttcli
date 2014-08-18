%%%-------------------------------------------------------------------
%%% @author Alvaro Pagliari <alvaropag@gmail.com>
%%% @copyright (C) 2014, Alvaro Pagliari
%%% @doc
%%%
%%% @end
%%% Created : 18 Aug 2014 by Alvaro Pagliari <alvaropag@gmail.com>
%%%-------------------------------------------------------------------
-module(emqttcli_socket_ssh_subsystem_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).



%% API
-export([start_child/1, spec/3]).

-define(SERVER, ?MODULE).

%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%%
%% @spec init(Args) -> {ok, {SupFlags, [ChildSpec]}} |
%%                     ignore |
%%                     {error, Reason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    RestartStrategy = one_for_one,
    MaxRestarts = 1000,
    MaxSecondsBetweenRestarts = 3600,

    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},

    %Restart = permanent,
    %Shutdown = 2000,
    %Type = worker,

    {ok, {SupFlags, []}}.


start_child(Spec) ->
    supervisor:start_child(emqttcli_socket_ssh_subsystem_sup, Spec).


spec(CM, ChannelId, ClientId) ->
    {list_to_atom(binary:bin_to_list(ClientId)),
     {emqttcli_socket_ssh_subsystem, start_link, [CM, ChannelId, ClientId]}, 
     permanent, 5000, worker, [emqttcli_socket_ssh_subsystem]}.


%%%===================================================================
%%% Internal functions
%%%===================================================================

