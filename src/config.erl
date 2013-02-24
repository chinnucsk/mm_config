%%  Copyright (C) 2012 - Molchanov Maxim,
%% @author Maxim Molchanov <elzor.job@gmail.com>
%% @doc    Main configuration module.
%% @usage  After update cofiguration file and recompilation call config:reload() or config:soft_reload().

-module(config).
-behaviour(gen_server).
-author('author Maxim Molchanov <elzor.job@gmail.com>').
-vsn(1.2).

-include("include/config.hrl").

-compile(export_all).
-compile(nowarn_unused_vars).

-export([init/1, start/0, stop/0, start_link/0, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

% API
-export([get/1, set/2, reload/0, soft_reload/0]).


-define(SERVER, ?MODULE).

-record( state, { 
	params = ?CONFIG,
	connect_time=-1
	}).

%% Public API
start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

start() ->
  gen_server:start({local, ?MODULE}, ?MODULE, [], []).

stop(Module) ->
  gen_server:cast(Module, stop).

stop() ->
  stop(?MODULE).

state(Module) ->
  gen_server:call(Module, state, infinity).

state() ->
  state(?MODULE).

get(Key)->
	gen_server:call(?MODULE, {get, Key}, infinity).

set(Key, Value)->
	gen_server:call(?MODULE, {set, Key, Value}, infinity).

reload()-> stop(), start().

soft_reload()->
  gen_server:call(?MODULE, {soft_reload}, infinity).  

init([]) ->
  case init:get_argument(program_mode) of 
    {ok, [[Mode]]}->
      case Mode of
        "slave"->
          error_logger:info_msg("Loading slave mode config file...~n"),
          CFG_FILE = "slave.conf";
        _Else->
          error_logger:info_msg("Loading default mode config file...~n"),
          CFG_FILE = "base.conf"
      end;
    _Else->
      error_logger:info_msg("Loading default config file...~n"),
      CFG_FILE = "base.conf"
  end,
  ExistBase = utils:file_exists(?CONFIG_PATH++CFG_FILE),
  if
    ExistBase == true ->
      {ok, BcString} = file:read_file(?CONFIG_PATH++CFG_FILE),
      {ok, Tokens, _} = erl_scan:string(binary_to_list(BcString)),
      {ok, [Form]} = erl_parse:parse_exprs(Tokens),
      {value, C, _} = erl_eval:expr(Form,[]),
      State = #state{connect_time=utils:unix_timestamp(), params=C};
    true->
      error_logger:error_msg("Config file ~s not found!~n", [?CONFIG_PATH++CFG_FILE]),
      State = #state{connect_time=utils:unix_timestamp()}
  end,
	{ok, State}.


handle_call({get, Key}, _From, State) ->
  case proplists:lookup(Key, State#state.params) of
    none ->
      Reply = application:get_env(Key);
    {Key, Value} ->
      Reply = {ok, Value};
    _Else->
      Reply = undefined
  end,
  {reply, Reply , State};

handle_call({soft_reload}, _From, State) ->
  case init:get_argument(program_mode) of 
    {ok, [[Mode]]}->
      case Mode of
        "slave"->
          error_logger:info_msg("Loading slave mode config file...~n"),
          CFG_FILE = "slave.conf";
        _Else->
          error_logger:info_msg("Loading ~s mode config file...~n", [Mode]),
          CFG_FILE = "base.conf"
      end;
    _Else->
      error_logger:info_msg("Loading default config file...~n"),
      CFG_FILE = "base.conf"
  end,
  ExistBase = utils:file_exists(?CONFIG_PATH++CFG_FILE),
  if
    ExistBase == true ->
      {ok, BcString} = file:read_file(?CONFIG_PATH++CFG_FILE),
      {ok, Tokens, _} = erl_scan:string(binary_to_list(BcString)),
      {ok, [Form]} = erl_parse:parse_exprs(Tokens),
      {value, C, _} = erl_eval:expr(Form,[]),
      NewState = State#state{params=C};
    true->
      error_logger:error_msg("Config file ~s not found!~n", [?CONFIG_PATH++CFG_FILE]),
      NewState = State
  end,
  {reply, reloaded , NewState};

handle_call({set, Key, Value}, _From, State) ->
  case proplists:lookup(Key, State#state.params) of
  	{Key, _}->
  		Params = proplists:delete(Key, State#state.params);
  	none->
  		Params = State#state.params
  end,
  NewParams = lists:append(Params, [{Key, Value}]),
  NewState = State#state{params = NewParams},
  {reply, ok , NewState};

handle_call(state, _From, State) ->
  {reply, State , State};

handle_call(_Request, _From, State) ->
  say("call ~p, ~p, ~p.", [_Request, _From, State]),
  {reply, ok, State}.

handle_cast(stop, State) ->
    {stop, normal, State};

handle_cast(_Msg, State) ->
  say("cast ~p, ~p.", [_Msg, State]),
  {noreply, State}.

handle_info(_Info, State) ->
  say("info ~p, ~p.", [_Info, State]),
  {noreply, State}.

terminate(_Reason, _State) ->
  say("terminate ~p, ~p", [_Reason, _State]),
  ok.

code_change(_OldVsn, State, _Extra) ->
  say("code_change ~p, ~p, ~p", [_OldVsn, State, _Extra]),
  {ok, State}.

%% Some helper methods.

say(Format) ->
  say(Format, []).
say(Format, Data) ->
  io:format("~p:~p: ~s~n", [?MODULE, self(), io_lib:format(Format, Data)]).