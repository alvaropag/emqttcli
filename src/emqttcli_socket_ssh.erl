%%%-------------------------------------------------------------------
%%% @author Alvaro Pagliari <alvaropag@gmail.com>
%%% @copyright (C) 2014, Alvaro Pagliari
%%% @doc
%%%
%%% @end
%%% Created :  7 Aug 2014 by Alvaro Pagliari <alvaropag@gmail.com>
%%%-------------------------------------------------------------------
-module(emqttcli_socket_ssh).

-behaviour(gen_server).

%% API
-export([start_link/1, spec/2, open_conn_channel/5]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {client_id, conn_mgr, channel_id, emqttcli_cb_pid, emqttcli_socket}).

%%%===================================================================
%%% API
%%%===================================================================

spec(ClientId, CallbackModule) when is_binary(ClientId) ->
    {list_to_atom(binary:bin_to_list(ClientId)), 
       {emqttcli_socket_ssh, start_link, [ClientId, CallbackModule]}, 
        permanent, 5000, worker, [emqttcli_socket_ssh]
    }.

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link(ClientId) ->
    gen_server:start_link(?MODULE, [ClientId], []).

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
init([ClientId]) ->
    {ok, #state{client_id = ClientId}}.

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
handle_call({open_conn_channel, Address, Port, Options, ClientId}, _From, State) ->
    case open_conn_channel_internal(Address, Port, Options, ClientId) of
        {ok, EmqttcliSocket} ->
            {reply, {ok, EmqttcliSocket}, State#state{emqttcli_socket = EmqttcliSocket}, 5000};
        {error, Reason} -> {error, Reason}
    end;
    
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


%% External API
open_conn_channel(Pid, Address, Port, Options, ClientId) ->
    gen_server:call(Pid, {open_conn_channel, Address, Port, Options, ClientId}).


%%%===================================================================
%%% Internal functions
%%%===================================================================
open_conn_channel_internal(Address, Port, Options, ClientId) ->
    %Connect to the SSH server
    case ssh:connect(Address, Port, Options, 5000) of
        {ok, CM} ->
            %Start the channel to communicate
            {ok, ChannelId} = ssh_connection:session_channel(CM, 5000),

            %Inform the server that you want to use a subsystem
            success = ssh_connection:subsystem(CM, ChannelId, "z_ssh_subsystem@zotonic.com", 5000),

            %Manually starts the channel that will handle the subsystem on the client
            %%TODO: understand the trap_exit(true) and handle the DOWN message
            {ok, ChannelPid} = ssh_channel:start_link(CM, ChannelId, emqttcli_socket_ssh_subsystem, 
                [ClientId]),

            %%Return the socket
            {ok, emqttcli_socket:create_socket(ssh, CM, ChannelId, ChannelPid)};
            
        {error, Reason} -> {error, Reason}
    end.
            
