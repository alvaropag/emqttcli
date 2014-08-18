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

-include("emqttcli_socket.hrl").

%% API
-export([start_link/1, 
         spec/1, 
         open_conn_channel/5]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).


-export([set_emqttcli_connection_pid/2]).

-define(SERVER, ?MODULE).

-record(state, {client_id, conn_mgr, channel_id, emqttcli_cb_pid, emqttcli_socket, channel_pid}).

%%%===================================================================
%%% API
%%%===================================================================

spec(ClientId) when is_binary(ClientId) ->
    {list_to_atom(binary:bin_to_list(ClientId)), 
       {emqttcli_socket_ssh, start_link, [ClientId]}, 
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
        {ok, EmqttcliSocket, ChannelPid} ->
            {reply, {ok, EmqttcliSocket}, State#state{emqttcli_socket = EmqttcliSocket, channel_pid = ChannelPid}, 5000};
        {error, Reason} -> {error, Reason}
    end;


handle_call({sync_send, Data}, _From, #state{emqttcli_socket = #emqttcli_socket{type = ssh, connection = Conn, channel = Channel}} = State) ->
    io:fwrite("Sending SSH data to channel ~p~n", [Channel]),
    Return = ssh_connection:send(Conn, Channel, Data, 5000),
    io:fwrite("Reply of sending SSH data ~p~n", [Return]),
    {reply, Return, State};
    
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
handle_cast({emqttcli_connection_pid, EmqttcliConnection}, #state{channel_pid = ChannelPid } = State) ->
    ssh_channel:cast(ChannelPid, {emqttcli_connection_pid, EmqttcliConnection}),
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


set_emqttcli_connection_pid(Pid, EmqttcliConnectionPid) ->
    gen_server:cast(Pid, {emqttcli_connection_pid, EmqttcliConnectionPid}).


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
            %{ok, ChannelPid} = ssh_channel:start_link(CM, ChannelId, emqttcli_socket_ssh_subsystem, 
            %   [ClientId]),

            {ok, ChannelPid} = emqttcli_socket_ssh_subsystem_sup:start_link(emqttcli_socket_ssh_subsystem_sup:spec(CM, ChannelId, ClientId)),
 
            io:fwrite("ChannelPid of SSH Subsystem = ~p~n", [ChannelPid]),


            %%Return the socket
            {ok, emqttcli_socket:create_socket(ssh, CM, ChannelId, self()), ChannelPid};
            
        {error, Reason} -> {error, Reason}
    end.
            
