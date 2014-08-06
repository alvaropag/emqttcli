%%%-------------------------------------------------------------------
%%% @author Alvaro Pagliari <alvaro@alvaro-vaio>
%%% @copyright (C) 2014, Alvaro Pagliari
%%% @doc
%%%
%%% @end
%%% Created :  5 Aug 2014 by Alvaro Pagliari <alvaro@alvaro-vaio>
%%%-------------------------------------------------------------------
-module(emqttcli_socket_tcp).

-behaviour(gen_server).

-include("emqttcli_socket.hrl").

%% API
-export([start_link/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-export([spec/2, set_emqttcli_connection_pid/2, activate_socket/1]).

-define(SERVER, ?MODULE).

-record(state, {emqttcli_socket, emqttcli_connection = undefined}).
%%%===================================================================
%%% API
%%%===================================================================

spec(ClientId, EmqttcliSocket) when is_binary(ClientId) ->
    {list_to_atom(binary:bin_to_list(ClientId)), {emqttcli_socket_tcp, start_link, [EmqttcliSocket]},
     permanent,
     5000,
     worker,
     [emqttcli_socket_tcp]}.

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link([EmqttcliSocket]) ->
    gen_server:start_link(?MODULE, [EmqttcliSocket], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([EmqttcliSocket]) ->
    {ok, #state{emqttcli_socket = EmqttcliSocket}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------

handle_cast({emqttcli_connection, EmqttcliConnPID}, State) ->
    {noreply, State#state{emqttcli_connection = EmqttcliConnPID}};

handle_cast(activate_socket, #state{emqttcli_connection = EmqttcliConnPid} = State) when EmqttcliConnPid == undefined ->
    {stop, "No emqttcli_connection defined", State};

handle_cast(activate_socket, #state{emqttcli_socket = EmqttcliSocket} = State) ->
    TcpSocket = EmqttcliSocket#emqttcli_socket.connection,
    inet:setopts(TcpSocket, [{active, once}]),
    {noreply, State};
    
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------

%% Receive the data from the Socket and forward to the manager...

handle_info({tcp, Socket, Data}, #state{emqttcli_socket = EmqttcliSocket, emqttcli_connection = EmqttcliConnection} = State) ->
    Socket = EmqttcliSocket#emqttcli_socket.connection,
    emqttcli_socket:forward_data_to_mgr(EmqttcliConnection, Data, EmqttcliSocket),
    inet:setopts(Socket, [{active, once}]),
    {noreply, State};

handle_info({tcp_closed, Socket}, #state{emqttcli_socket = EmqttcliSocket, emqttcli_connection = EmqttcliConnection} = State) ->
    Socket = EmqttcliSocket#emqttcli_socket.connection,
    emqttcli_socket:forward_closed_to_mgr(EmqttcliConnection, EmqttcliSocket),
    {stop, shutdown, State};

handle_info({tcp_error, Socket, Reason}, #state{emqttcli_socket = EmqttcliSocket, emqttcli_connection = EmqttcliConnection} = State) ->
    Socket = EmqttcliSocket#emqttcli_socket.connection,
    emqttcli_socket:foward_error_to_mgr(EmqttcliConnection, Reason, EmqttcliSocket),
    {stop, {tcp_error, Reason}, State};

handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


set_emqttcli_connection_pid(SocketPid, EmqttcliConnectionPid) ->
    gen_server:cast(SocketPid, {emqttcli_connection, EmqttcliConnectionPid}).

activate_socket(SocketPid) ->
    gen_server:cast(SocketPid, activate_socket).

%%%===================================================================
%%% Internal functions
%%%===================================================================


