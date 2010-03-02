-module(game_controller,[Env]).
-export([handle_request/2]).
-include("records.hrl").

handle_request("start",[]) ->
    PlayerOneName = beepbeep_args:get_param("player_one_name",Env),
    PlayerTwoName = beepbeep_args:get_param("player_two_name",Env),

    Game             = gin_rummy:start_game(PlayerOneName, PlayerTwoName),
    PlayerOne        = Game#game.player1,
    PlayerTwo        = Game#game.player2,

    {render,"game/start.html",[
      {game,            io_lib:print(Game)},
      {player_one_name, PlayerOne#player.name},
      {player_two_name, PlayerTwo#player.name},
      {card_count,      length(PlayerOne#player.hand)},
      {your_hand,       card_list(PlayerOne)},
      {top_of_discard,  top_of_discard(Game#game.discard)},
      {deck_size,       length(Game#game.deck)},
      {opponent_size,   length(PlayerTwo#player.hand)}
    ]}.

card_list(Player) ->
  Hand = Player#player.hand,
  lists:map(fun(Card) -> Card#card.name end, Hand).

top_of_discard([]) ->
  false;
top_of_discard([Head|_Tail]) ->
  Head.
