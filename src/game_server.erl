-module(game_server).
-behaviour(gen_server).
-include("records.hrl").

%% API
-export([start/2, library_draw/2, discard_draw/2, discard/3, manual_sort/3, value_sort/1, game_state/1, stop/0]).

%% gen-server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).


%%====================================================================
%% API
%%====================================================================
start(Player1Name, Player2Name) ->
  {new_id, Id} = id_server:new_id(),
  GameName = list_to_atom(lists:concat(["g", Id])),
  {GameName, gen_server:start_link({local, GameName}, ?MODULE, [Player1Name, Player2Name], [])}.
library_draw(Game, Player) ->
  gen_server_call(Game, {library_draw, Player}).
discard_draw(Game, Player) ->
  gen_server_call(Game, {discard_draw, Player}).
discard(Game, Player, CardName) ->
  gen_server_call(Game, {discard, Player, CardName}).
manual_sort(Game, PlayerNumber, NewOrder) ->
  gen_server_call(Game, {manual_sort, PlayerNumber, NewOrder}).
value_sort(Game) ->
  gen_server_call(Game, value_sort).
game_state(Game) ->
  gen_server_call(Game, game_state).
stop() ->
  gen_server_call(?MODULE, stop).

%%====================================================================
%% gen_server callbacks
%%====================================================================
init([Player1Name, Player2Name]) ->
  {ok, game:start_game(Player1Name, Player2Name)}.

handle_cast(_Msg, State) -> {noreply, State}.

handle_info(_Info, State) -> {noreply, State}.

terminate(_Reason, _State) -> ok.

code_change(_OldVsn, State, _Extra) -> {ok, State}.

handle_call(stop, _From, State) -> {stop, normal, State };

handle_call({library_draw, Player}, _From, State) ->
  NewState = game:library_draw(Player, State),
  Message = lists:concat([player_name(State, Player), " drew a card"]),
  chat_server:broadcast(Message, NewState#game.chat_server),
  {reply, {library_draw, NewState}, NewState};

handle_call({discard_draw, Player}, _From, State) ->
  NewState = game:discard_draw(Player, State),
  Message = lists:concat([player_name(State, Player), " drew from the discard pile"]),
  chat_server:broadcast(Message, NewState#game.chat_server),
  {reply, {discard_draw, NewState}, NewState};

handle_call({discard, Player, CardName}, _From, State) ->
  NewState = game:discard(Player, CardName, State),
  Message = lists:concat([player_name(State, Player), " discarded ", CardName]),
  chat_server:broadcast(Message, NewState#game.chat_server),
  {reply, {discard, NewState}, NewState};

handle_call({manual_sort, PlayerNumber, NewOrder}, _From, State) ->
  NewState = game:manual_sort(PlayerNumber, NewOrder, State),
  chat_server:refresh(NewState#game.chat_server),
  {reply, {manual_sort, NewState}, NewState};

handle_call(value_sort, _From, State) ->
  NewState = game:value_sort(State),
  chat_server:refresh(NewState#game.chat_server),
  {reply, {value_sort, NewState}, NewState};

handle_call(game_state, _From, State) ->
  {reply, {game_state, State}, State}.

%%====================================================================
%%% Internal functions
%%====================================================================
player_name(#game{ players=Players }, Number) ->
  Player = lists:nth(Number, Players),
  Player#player.name.

gen_server_call(Pid, Message) when is_list(Pid) ->
  AtomicPid = list_to_atom(Pid),
  gen_server:call(AtomicPid, Message).

%%====================================================================
%%% Unit tests
%%====================================================================

