%%%-------------------------------------------------------------------
%%% @author Alvaro Pagliari <alvaro@alvaro-vaio>
%%% @copyright (C) 2014, Alvaro Pagliari
%%% @doc
%%%
%%% @end
%%% Created :  6 Aug 2014 by Alvaro Pagliari <alvaro@alvaro-vaio>
%%%-------------------------------------------------------------------
-module(emqttcli_connection).

-behaviour(gen_fsm).

-include("emqttcli_frames.hrl").

%% API
-export([start_link/1, spec/1]).

%% gen_fsm callbacks
-export([init/1, handle_event/3, handle_sync_event/4, handle_info/3, terminate/3, code_change/4]).


%% API
-export([
         recv_data/3, 
         recv_error/3, 
         recv_closed/2, 
         register_recv_msg_cb/2,
         unregister_recv_msg_cb/2]).



%% States
-export([
         loading/3,
         connecting/2,
         connected/2,
         disconnected/2,
         setSocket/2
         ]).

-define(SERVER, ?MODULE).

-record(state, {client_id, 
                emqttcli_socket = undefined, 
                cb_pid = undefined, 
                buffer = <<>>, 
                parse_fun,
                pending_reply = []}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Creates a gen_fsm process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this
%% function does not return until Module:init/1 has returned.
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link(ClientId) when is_binary(ClientId) ->
    gen_fsm:start_link({local, list_to_atom(binary:bin_to_list(ClientId))}, ?MODULE, [ClientId], []).

spec(ClientId) when is_binary(ClientId) ->
    {list_to_atom(binary:bin_to_list(ClientId)), {emqttcli_connection, start_link, [ClientId]}, 
     permanent, 
     5000, 
     worker, 
     [emqttcli_connection]}.

%%%===================================================================
%%% gen_fsm callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm is started using gen_fsm:start/[3,4] or
%% gen_fsm:start_link/[3,4], this function is called by the new
%% process to initialize.
%%
%% @spec init(Args) -> {ok, StateName, State} |
%%                     {ok, StateName, State, Timeout} |
%%                     ignore |
%%                     {stop, StopReason}
%% @end
%%--------------------------------------------------------------------
init([ClientId]) ->
    {ok, loading, #state{client_id = ClientId, parse_fun = fun emqttcli_framing:parse/1}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_event/2, the instance of this function with the same
%% name as the current state name StateName is called to handle
%% the event. It is also called if a timeout occurs.
%%
%% @spec state_name(Event, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------

recv_data(Pid, Data, EmqttcliSocket) ->
    gen_fsm:send_all_state_event(Pid, {net_data, Data, EmqttcliSocket}).

recv_error(Pid, Reason, EmqttcliSocket) ->
    gen_fsm:send_all_state_event(Pid, {net_error, Reason, EmqttcliSocket}).

recv_closed(Pid, EmqttcliSocket) ->
    gen_fsm:send_all_state_event(Pid, {net_closed, EmqttcliSocket}).

register_recv_msg_cb(Pid, CBPid) ->
    gen_fsm:send_all_state_event(Pid, {reg_recv_msg_cb, CBPid}),
    ok.

unregister_recv_msg_cb(Pid, CBPid) ->
    gen_fsm:send_all_state_event(Pid, {unreg_recv_msg_cb, CBPid}),
    ok.

setSocket(Pid, EmqttcliSocket) ->
    gen_fsm:send_all_state_event(Pid, {emqttcli_socket, EmqttcliSocket}).

%%States

loading({try_connect, ConnFrame}, From, #state{emqttcli_socket = Socket} = State) ->
    State1 = State#state{pending_reply = [From]},
    case emqttcli_socket:sync_send(Socket, emqttcli_framing:serialise(ConnFrame)) of
        ok -> {next_state, connecting, State1};
        {error, Reason} -> 
            io:fwrite("Error sending data with reason ~p~n", [Reason]),
            {next_state, error, State1}
    end.


connecting({conn_ack, ok}, #state{pending_reply = [To]} = State) ->
    gen_fsm:reply(To, ok),
    {next_state, connected, State#state{pending_reply = []}};

connecting({conn_ack, {error, Reason}}, #state{pending_reply = [To]} = State) ->
    gen_fsm:reply(To, {error, Reason}),
    {next_state, error, State#state{pending_reply = []}}.


    
connected({data, Data, EmqttcliSocket}, State) -> 
    State1 = handle_data(Data, EmqttcliSocket, State),
    {next_state, ready, State1};

connected({error, _Reason, _EmqttcliSocket}, State) ->
    {next_state, error, State};

connected({closed, _EmqttcliSocket}, State) ->
    {next_state, disconnected, State};


connected(_Event, State) ->
    {stop, "Invalid event", State}.

disconnected(_Event, State) ->
    {stop, "Invalid event", State}.


    

%%--------------------------------------------------------------------
%% @private
%% @doc
%% There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_event/[2,3], the instance of this function with
%% the same name as the current state name StateName is called to
%% handle the event.
%%
%% @spec state_name(Event, From, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {reply, Reply, NextStateName, NextState} |
%%                   {reply, Reply, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState} |
%%                   {stop, Reason, Reply, NewState}
%% @end
%%--------------------------------------------------------------------
%state_name(_Event, _From, State) ->
%    Reply = ok,
%    {reply, Reply, state_name, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_all_state_event/2, this function is called to handle
%% the event.
%%
%% @spec handle_event(Event, StateName, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------

handle_event({net_data, Data, EmqttcliSocket}, StateName, State) ->
    case handle_data(Data, EmqttcliSocket, State) of
        {ok, NewState} -> {next_state, StateName, NewState};

        {error, Reason} -> 
            gen_fsm:sen_event(self(), {error, Reason}),
            {next_state, error, State}
    end;


% Receives the error from the network, generate the event to change the state
% and return the function with the actual StateName.
handle_event({net_error, Reason, _EmqttcliSocket}, StateName, State) ->
    gen_fsm:send_all_state_event(self(), {error, Reason}),
    {next_state, StateName, State};

handle_event({net_closed, _EmqttcliSocket}, StateName, State) ->
    gen_fsm:send_event(self(), disconnected),
    {next_state, StateName, State};

% Don't notify about the error... 
handle_event({error, _Reason}, _StateName, State) ->
    {next_state, error, State};

handle_event({reg_recv_msg_cb, CBPid}, StateName, State) ->
    {next_state, StateName, State#state{cb_pid = CBPid}};

% The Pid is not necessary, but if later we want to have any kind of 
% validation or support multiple callbacks then it is already in the API
handle_event({unreg_recv_msg_cb, _CBPid}, StateName, State) ->
    {next_state, StateName, State#state{cb_pid = undefined}};

handle_event({emqttcli_socket, EmqttcliSocket}, StateName, State) ->
    io:fwrite("Received socket ~p~n", [EmqttcliSocket]),
    {next_state, StateName, State#state{emqttcli_socket = EmqttcliSocket}};


handle_event(disconnect, _StateName, #state{emqttcli_socket = EmqttcliSocket} = State) ->
    emqttcli_socket:sync_send(EmqttcliSocket, emqttcli_framing:serialise(disconnect)),
    {next_state, disconnected, State};

handle_event(_Event, StateName, State) ->
    {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_all_state_event/[2,3], this function is called
%% to handle the event.
%%
%% @spec handle_sync_event(Event, From, StateName, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {reply, Reply, NextStateName, NextState} |
%%                   {reply, Reply, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState} |
%%                   {stop, Reason, Reply, NewState}
%% @end
%%--------------------------------------------------------------------
handle_sync_event(_Event, _From, StateName, State) ->
    Reply = ok,
    {reply, Reply, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_fsm when it receives any
%% message other than a synchronous or asynchronous event
%% (or a system message).
%%
%% @spec handle_info(Info,StateName,State)->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------
handle_info(_Info, StateName, State) ->
    {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_fsm when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_fsm terminates with
%% Reason. The return value is ignored.
%%
%% @spec terminate(Reason, StateName, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _StateName, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, StateName, State, Extra) ->
%%                   {ok, StateName, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, StateName, State, _Extra) ->
    {ok, StateName, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

handle_data(Data, _EmqttcliSocket, #state{buffer = Buffer, parse_fun = Process} = State) ->
    AllData = <<Buffer/binary, Data/binary>>,
    case Process(AllData) of
        %%Interpreted a frame, has to do something...
        {frame, MqttFrame, Rest} -> 
            process_frame(MqttFrame, State), 
            {ok, State#state{parse_fun = fun emqttcli_framing:parse/1, buffer = Rest}};

        %% I interpreted some of it, send me more data that I can continue...
        {more, KeepFromHere} ->
            {ok, State#state{parse_fun = KeepFromHere}};

        %% Ops, something went wrong....
        {error, Why} -> 
            {error, Why}

    end.

%% How to propagate errors and messages?

% Process Received Data
process_frame(#connack{return_code = ok}, _State) ->
    io:fwrite("Mqtt Connection accepted~n"),
    gen_fsm:send_event(self(), {conn_ack, ok});

process_frame(#connack{return_code = ReturnCode}, _State) ->
    gen_fsm:send_event(self(), {conn_ack, {error, ReturnCode}});

%First response of #publish for QoS1
%process_frame(#puback{message_id = MsgId}) ->

%First response of #publish for QoS2
%process_frame(#pubrec{message_id = MsgId}) ->

%QoS 2, can be received by the client
%process_frame(#pubrel{dup = Duplicated, message_id = MsgId}) ->

%process_frame(#suback{message_id = MsgId, qoses = []}) ->

process_frame(disconnect, _State) ->
    ok;


process_frame(_, _State) -> ok.

    
