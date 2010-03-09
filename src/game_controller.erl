-module(game_controller,[Env]).
-export([handle_request/2]).
-include("records.hrl").

handle_request("start",[]) ->
  PlayerOneName = beepbeep_args:get_param("player_one_name",Env),
  PlayerTwoName = beepbeep_args:get_param("player_two_name",Env),
  {AtomicGameName, _} = game_server:start(PlayerOneName, PlayerTwoName),
  {game_state, Game} = gen_server:call(AtomicGameName, game_state),
  beepbeep_args:set_session_data(AtomicGameName, player_one, Env),
  chat_server:subscribe(player_one, Game#game.chat_server),
  {redirect, lists:concat(["/game/", AtomicGameName])};

handle_request(GameName, []) ->
  AtomicGameName     = list_to_atom(GameName),
  {game_state, Game} = gen_server:call(AtomicGameName, game_state),
  PlayerOne          = Game#game.player1,
  PlayerTwo          = Game#game.player2,

  ViewData = case beepbeep_args:get_session_data(AtomicGameName, Env) of
    player_one -> html_view_data(Game, PlayerOne, PlayerTwo);
    player_two -> html_view_data(Game, PlayerTwo, PlayerOne);
    undefined ->
      beepbeep_args:set_session_data(AtomicGameName, player_two, Env),
      chat_server:subscribe(player_two, Game#game.chat_server),
      html_view_data(Game, PlayerTwo, PlayerOne)
  end,
  {render, "game/show.html", ViewData};

handle_request(GameName, ["library_draw"]) ->
  AtomicGameName    = list_to_atom(GameName),
  PlayerNumber      = beepbeep_args:get_session_data(AtomicGameName, Env),
  {library_draw, _} = gen_server:call(AtomicGameName, {library_draw, PlayerNumber}),
  {redirect, lists:concat(["/game/", GameName])};

handle_request(GameName, ["discard_draw"]) ->
  AtomicGameName    = list_to_atom(GameName),
  PlayerNumber      = beepbeep_args:get_session_data(AtomicGameName, Env),
  {discard_draw, _} = gen_server:call(AtomicGameName, {discard_draw, PlayerNumber}),
  {redirect, lists:concat(["/game/", GameName])};

handle_request(GameName, ["discard", CardName]) ->
  AtomicGameName    = list_to_atom(GameName),
  PlayerNumber      = beepbeep_args:get_session_data(AtomicGameName, Env),
  {discard, _} = gen_server:call(AtomicGameName, {discard, PlayerNumber, CardName}),
  {redirect, lists:concat(["/game/", GameName])};

handle_request(GameName, ["comet"]) ->
  AtomicGameName     = list_to_atom(GameName),
  PlayerNumber       = beepbeep_args:get_session_data(AtomicGameName, Env),
  {game_state, Game} = gen_server:call(AtomicGameName, game_state),
  chat_server:listen(PlayerNumber, self(), Game#game.chat_server),
  receive
    {chat_messages, PlayerNumber, Messages} ->
      {render, "game/comet.html", json_view_data(Game, PlayerNumber, Messages)}
  end.

html_view_data(Game, CurrentPlayer, Opponent) ->
  [
    {game_name,       beepbeep_args:get_action(Env)},
    {player_one_name, CurrentPlayer#player.name},
    {player_two_name, Opponent#player.name},
    {card_count,      length(CurrentPlayer#player.hand)},
    {your_hand,       card_list(CurrentPlayer)},
    {top_of_discard,  top_of_discard(Game#game.discard)},
    {deck_size,       length(Game#game.deck)},
    {opponent_size,   length(Opponent#player.hand)}
  ].

json_view_data(Game = #game{ player1=PlayerOne, player2=PlayerTwo }, PlayerNumber, Messages) ->
  case PlayerNumber of
    player_one -> Player = PlayerOne, Opponent = PlayerTwo;
    player_two -> Player = PlayerTwo, Opponent = PlayerOne
  end,

  [
    {player_size,     length(Player#player.hand)},
    {player_hand,     card_list(Player)},
    {opponent_size,   length(Opponent#player.hand)},
    {deck_size,       length(Game#game.deck)},
    {top_of_discard,  top_of_discard(Game#game.discard)},
    {new_messages,    Messages}
  ].

card_list(Player) ->
  Hand = Player#player.hand,
  lists:map(fun(Card) -> Card#card.name end, Hand).

top_of_discard([]) ->
  false;
top_of_discard([Head|_Tail]) ->
  Head#card.name.

