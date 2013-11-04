-module(lager_logstash_backend).

%% Started from the lager logstash backend
-author('marc.e.campbell@gmail.com').
-author('mhald@mac.com').

-behaviour(gen_event).

-export([init/1,
         handle_call/2,
         handle_event/2,
         handle_info/2,
         terminate/2,
         code_change/3,
         logtime/0,
         get_app_version/0
]).

-record(state, {socket :: pid(),
                lager_level_type :: 'mask' | 'number' | 'unknown',
                level :: atom(),
                logstash_host :: string(),
                logstash_port :: number(),
                logstash_address :: inet:ip_address(),
                node_role :: string(),
                node_version :: string(),
                metadata :: list()
}).

init(Params) ->
  %% we need the lager version, but we aren't loaded, so... let's try real hard
  %% this is obviously too fragile
  {ok, Properties}     = application:get_all_key(),
  {vsn, Lager_Version} = proplists:lookup(vsn, Properties),
  Lager_Level_Type =
    case string:to_float(Lager_Version) of
      {V1, _} when V1 < 2.0 ->
        'number';
      {V2, _} when V2 =:= 2.0 ->
        'mask';
      {_, _} ->
        'unknown'
    end,

  Level = lager_util:level_to_num(proplists:get_value(level, Params, debug)),
  Popcorn_Host = proplists:get_value(logstash_host, Params, "localhost"),
  Popcorn_Port = proplists:get_value(logstash_port, Params, 9125),
  Node_Role = proplists:get_value(node_role, Params, "no_role"),
  Node_Version = proplists:get_value(node_version, Params, "no_version"),

  Metadata = proplists:get_value(metadata, Params, []) ++
     [
         {pid, [{encoding, process}]},
         {line, [{encoding, integer}]},
         {file, [{encoding, string}]},
         {module, [{encoding, atom}]}
     ],

 {Socket, Address} =
   case inet:getaddr(Popcorn_Host, inet) of
     {ok, Addr} ->
       {ok, Sock} = gen_udp:open(0, [list]),
       {Sock, Addr};
     {error, _Err} ->
       {undefined, undefined}
   end,

  {ok, #state{socket = Socket,
              lager_level_type = Lager_Level_Type,
              level = Level,
              logstash_host = Popcorn_Host,
              logstash_port = Popcorn_Port,
              logstash_address = Address,
              node_role = Node_Role,
              node_version = Node_Version,
              metadata = Metadata}}.

handle_call({set_loglevel, Level}, State) ->
  {ok, ok, State#state{level=lager_util:level_to_num(Level)}};

handle_call(get_loglevel, State) ->
  {ok, State#state.level, State};

handle_call(_Request, State) ->
  {ok, ok, State}.

handle_event({log, _}, #state{socket=S}=State) when S =:= undefined ->
  {ok, State};
handle_event({log, {lager_msg, Q, Metadata, Severity, {Date, Time}, _, Message}}, State) ->
  handle_event({log, {lager_msg, Q, Metadata, Severity, {Date, Time}, Message}}, State);

handle_event({log, {lager_msg, _, Metadata, Severity, {Date, Time}, Message}}, #state{level=L, metadata=Config_Meta}=State) ->
  case lager_util:level_to_num(Severity) =< L of
    true ->
      Encoded_Message = encode_payload(State#state.lager_level_type,
                                                  node(),
                                                  State#state.node_role,
                                                  State#state.node_version,
                                                  Severity,
                                                  Date,
                                                  Time,
                                                  Message,
                                                  metadata(Metadata, Config_Meta)),
      gen_udp:send(State#state.socket,
                   State#state.logstash_address,
                   State#state.logstash_port,
                   Encoded_Message);
    _ ->
      ok
  end,
  {ok, State};

handle_event(_Event, State) ->
  {ok, State}.

handle_info(_Info, State) ->
  {ok, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  %% TODO version number should be read here, or else we don't support upgrades
  Vsn = get_app_version(),
  {ok, State#state{node_version=Vsn}}.

encode_payload('mask', Node, Node_Role, Node_Version, Severity, _Date, _Time, Message, Metadata) ->
  jiffy:encode({[
                {<<"message">>, safe_list_to_binary(Message)},
                {<<"@timestamp">>, list_to_binary(logtime())},
                {<<"@schema">>, <<"1">>},
                {<<"@severity">>, Severity},
                {<<"host">>, Node},
                {<<"type">>, list_to_binary(Node_Role)},
                {<<"version">>, list_to_binary(Node_Version)}
            ] ++ Metadata
  }).

safe_list_to_binary(L) when is_list(L) ->
  list_to_binary(L);
safe_list_to_binary(L) when is_binary(L) ->
  L.

get_app_version() ->
  [App,_Host] = string:tokens(atom_to_list(node()), "@"),
  Apps = application:which_applications(),
  case proplists:lookup(list_to_atom(App), Apps) of
    none ->
      "no_version";
    {_, _, V} ->
      V
  end.

logtime() ->
    {{Year, Month, Day}, {Hour, Minute, Second}} = erlang:universaltime(),
    lists:flatten(io_lib:format("~4.10.0B-~2.10.0B-~2.10.0BT~2.10.0B:~2.10.0B:~2.10.0B.~.10.0BZ",
        [Year, Month, Day, Hour, Minute, Second, 0])).

metadata(Metadata, Config_Meta) ->
    Expanded = [{Name, Properties, proplists:get_value(Name, Metadata)} || {Name, Properties} <- Config_Meta],
    [{list_to_binary(atom_to_list(Name)), encode_value(Value, proplists:get_value(encoding, Properties))} || {Name, Properties, Value} <- Expanded, Value =/= undefined].

encode_value(Val, string) -> list_to_binary(Val);
encode_value(Val, binary) -> Val;
encode_value(Val, process) -> list_to_binary(pid_to_list(Val));
encode_value(Val, integer) -> list_to_binary(integer_to_list(Val));
encode_value(Val, atom) -> list_to_binary(atom_to_list(Val));
encode_value(_Val, undefiend) -> throw(encoding_error).
