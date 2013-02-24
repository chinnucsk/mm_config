%%  Copyright (C) 2011 - Molchanov Maxim,
%% @author Maxim Molchanov <elzor.job@gmail.com>
%% @copyright 2004-2012 OptimeDev

-module(utils).
-compile(nowarn_unused_vars).
-compile(strong_validation).
%-compile({hipe, [{regalloc,linear_scan}, o2]}).
-compile(inline).
-compile({inline_size,50}).

%% Base
-export([
  blank/0,
	unix_timestamp/0,
  msec_timestamp/0,
	file_exists/1,
	type_of/1,
	prepend/2,
	payload_decode/1,
  payload_encode/1,
  test_avg/4,
  is_process_alive/2,
  sleep/1,
  floor/1,
  ceiling/1
	]).

blank()->
  ok.

%% Unix time
unix_timestamp()->
  {Mega, Secs, _} = erlang:now(),
  Mega*1000000 + Secs.

%% Unix time miliseconds (aka java)
%% for cassandra driver
msec_timestamp()->
  {Mega,Sec,Micro} = erlang:now(),
  (Mega*1000000+Sec)*1000000+Micro.


%% Exists of file
file_exists(Fname)->
  filelib:is_regular(Fname).

%% Type of variable
type_of(X) when is_integer(X)   -> integer;
type_of(X) when is_float(X)     -> float;
type_of(X) when is_list(X)      -> list;
type_of(X) when is_tuple(X)     -> tuple;
type_of(X) when is_bitstring(X) -> bitstring;  % will fail before e12
type_of(X) when is_binary(X)    -> binary;
type_of(X) when is_boolean(X)   -> boolean;
type_of(X) when is_function(X)  -> function;
type_of(X) when is_pid(X)       -> pid;
type_of(X) when is_port(X)      -> port;
type_of(X) when is_reference(X) -> reference;
type_of(X) when is_atom(X)      -> atom;
type_of(_X)                     -> unknown.

%% Prepend for Tuples
prepend(X, Tuple) ->
  list_to_tuple([X | tuple_to_list(Tuple)]).

%% Raw payload encode/decode
payload_decode(Payload) ->
     binary_to_term(Payload).
payload_encode(Payload) ->
     term_to_binary(Payload, [compressed]).


test_avg(M, F, A, N) when N > 0 ->
    StartTime = erlang:now(),
    L = test_loop(M, F, A, N, []),
    Length = length(L),
    Min = lists:min(L),
    Max = lists:max(L),
    Med = lists:nth(round((Length / 2)), lists:sort(L)),
    Avg = round(lists:foldl(fun(X, Sum) -> X + Sum end, 0, L) / Length),
    io:format("Range: ~b - ~b mics~n"
        "Median: ~b mics~n"
        "Average: ~b mics~n",
        [Min, Max, Med, Avg]),
    ProcTime = timer:now_diff(erlang:now(), StartTime),
    io:format("Total time: ~p mics~n",[ProcTime]).

test_loop(_M, _F, _A, 0, List) ->
    List;
test_loop(M, F, A, N, List) ->
    {T, _Result} = timer:tc(M, F, A),
    test_loop(M, F, A, N - 1, [T|List]).


is_process_alive(Pid, Timeout)->
  case process_info(Pid) of
    undefined->
      false;
    _Else->
      true
  end.
  %Pid ! {self(), ping},
  %receive
  %  {Pid, pong}->
  %    true;
  %  _->
  %    false
  %after Timeout->
  %  false
  %end.

for(N, N, F) -> [F()];
for(I, N, F) -> [F()|for(I+1, N, F)].

sleep(T) ->
  receive
  after T ->
    true
  end.

floor(X) ->
    T = erlang:trunc(X),
    case (X - T) of
        Neg when Neg < 0 -> T - 1;
        Pos when Pos > 0 -> T;
        _ -> T
    end.

ceiling(X) ->
    T = erlang:trunc(X),
    case (X - T) of
        Neg when Neg < 0 -> T;
        Pos when Pos > 0 -> T + 1;
        _ -> T
    end.