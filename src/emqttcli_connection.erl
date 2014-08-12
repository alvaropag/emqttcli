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
-export([start_link/2, spec/2]).

%% gen_fsm callbacks
-export([init/1, handle_event/3, handle_sync_event/4, handle_info/3, terminate/3, code_change/4]).


%% API
-export([recv_data/3, recv_error/3, recv_closed/2, recv_new_connection/2]).


-define(SERVER, ?MODULE).

-record(state, {client_id, cb_mod, buffer = <<>>, parse_fun}).

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
start_link(ClientId, CallbackModule) when is_binary(ClientId) ->
    gen_fsm:start_link({local, list_to_atom(binary:bin_to_list(ClientId))}, ?MODULE, [ClientId, CallbackModule], []).

spec(ClientId, CallbackModule) when is_binary(ClientId) ->
    {list_to_atom(binary:bin_to_list(ClientId)), {emqttcli_connection, start_link, [ClientId, CallbackModule]}, 
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
init([ClientId, CallbackModule]) ->
    {ok, connected, #state{client_id = ClientId, cb_mod = CallbackModule, parse_fun = fun emqttcli_framing:parse/1}}.

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
    gen_fsm:send_event(Pid, {data, Data, EmqttcliSocket}).

recv_error(Pid, Reason, EmqttcliSocket) ->
    gen_fsm:send__event(Pid, {error, Reason, EmqttcliSocket}).

recv_closed(Pid, EmqttcliSocket) ->
    gen_fsm:send_event(Pid, {closed, EmqttcliSocket}).

recv_new_connection(Pid, EmqttcliSocket) ->
    gen_fsm:send_all_state_event(Pid, {new_conn, EmqttcliSocket}).



%%States
connected({data, Data, EmqttcliSocket}, State) -> 
    State1 = handle_data(Data, EmqttcliSocket, State),
    {next_state, ready, State1};

connected({error, _Reason, _EmqttcliSocket}, State) ->
    {next_state, disconnected, State};

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
handle_event({new_conn, _Socket}, _StateName, State) ->
    {next_state, connected, State};

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

handle_data(Data, EmqttcliSocket, #state{buffer = Buffer, parse_fun = Process} = State) ->
    AllData = <<Buffer/binary, Data/binary>>,
    case Process(AllData) of
        %%Interpreted a frame, has to do something...
        {frame, MqttFrame, Rest} -> 
            process_frame(MqttFrame, State), 
            {next_state, connected, State#state{parse_fun = fun emqttcli_framing:parse/1, buffer = Rest}};

        %% I interpreted some of it, send me more data that I can continue...
        {more, KeepFromHere} ->
            {next_state, connected, State#state{parse_fun = KeepFromHere}};

        %% Ops, something went wrong....
        {error, Why} -> 
            gen_fsm:send_event(self(), {error, Why}), 
            {next_state, disconnected, State}

    end.

%% How to propagate errors and messages?

% Process Received Data
process_frame(#connack{return_code = ReturnCode}, _State) ->
    ReturnCode;

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

    
