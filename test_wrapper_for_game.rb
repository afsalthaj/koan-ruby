require File.expand_path(File.dirname(__FILE__) + '/neo')

class TestWrapperForGame < Neo::Koan
  class TurnError < RuntimeError
  end

  class ChoiceError < RuntimeError
  end

  class Game
    attr_reader :turn
    attr_reader :board
    attr_reader :players
    attr_reader :mini_max_scores

    def push_score_min_max_score(score)
      @mini_max_scores << score
    end

    def set_board(board)
      @board = board.clone
    end

    def set_a_new_board(index, new_turn)
      # A change in a board automatically results in the change in the player for the game.
      # Please note, that only place where we create future games to predict the future score is in min_max
      # and we create new Games dynamically to create no troubles
      # to the existing state of the game. We should ensure the player `new_turn` who is making this
      # move should be the potential player `turn`. `Game over` check is provided in the place where
      # set_a_new_board is called. set_a_new_board is called or allowed to called only when the game is not
      # over or not
      if players.include?(turn) && new_turn == turn
        b = board
        index_choices = possible_choices(b)
        if index_choices.include? index
          b[index - 1] = new_turn
          set_board(b)
        else
          raise ChoiceError, "Your choice #{index} has gone wrong. Sorry that this simple game allowed you to do it !!"
        end
        if turn == :X
          @turn = :O
        else
          @turn = :X
        end
      else
        raise TurnError, "Either Player #{turn} doesn't exist, or player #{turn} is playing consecutively"
      end
    end

    def initialize(turn)
      @players = [:X, :O]
      @board = (1..9).to_a
      @running = true
      @turn = turn
      @mini_max_scores = []
    end

    def display_board
      puts "\n--------------------"
      @board.each_slice(3) do |row|
        print ' '
        puts row.join('|')
        puts '------------------'
      end
    end

    def game_won?(player)
      winning_sequences = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]]
      result = winning_sequences.each {|sequence|
        if sequence.all? {|a| @board[a] == player}
          return true
        end
      }
      # not sure if there is any other easy way, to get around the truthy nature of Ruby conditional statements
      if result == true
        true
      else
        false
      end
    end

    def ready_for_min_max?
      if @player == :X
        true
      else
        false
      end
    end

    def game_over?
      @board.all? {|x| players.include?(x)} ||
          game_won?(:X) || game_won?(:O)
    end

    def result?
      if game_won?
        display_board
        puts "Game Over"
        @running = false
      elsif is_match_a_draw?
        display_board
        puts "Draw"
        @running = false
      end
    end

    def score
      if game_won?(:X)
        return 10
      elsif game_won?(:O)
        return -10
      else
        return 0
      end
    end

    def possible_choices(b)
      result = b.select {|x| x.is_a?(Integer)}
      result
    end

    # Call minimax instead of game.set_a_new_board if the next turn is :X
    # You may need to pass the existing game, as it is recursive in nature.
    # the function arguments takes two games to make things safe.
    # the future game and main_game, where main_game never change
    def mini_max(game, main_game)
      i = 0
      # When you calculate minimax, you need to ensure that the existing player
      # is :X, that is turn == :X
      # The initial set of possible choices with the current state of the board
      possible_choices = possible_choices(game.board)
      while i < possible_choices.size
        # Every possible choice leads to a state change.
        # A change in state of the board and player mainly, and obviously the score.
        # We could create new instance of the game everytime we make a possible choice
        # calculate the score and select the choice that gives the maximum score and outside
        # the recursion, you need to set the new game with the new board and the new player
        # every possible game is a new game.
        # this game should start with computer player, we simulate the future games starting from anothergame.
        # This is recursive. Hence we create a new game in every recursive call, making sure that the main game
        # is not mutated by any chance.
        another_game = Game.new(game.turn)
        another_game.set_board(game.board)
        the_choice = possible_choices[i]
        another_game.set_a_new_board(the_choice, another_game.turn)
        if another_game.game_over?
          main_game.push_score_min_max_score(another_game.score)
        else
          another_game.mini_max(another_game, main_game)
        end
        i += 1
      end
    end
  end

  def test_all_attributes_in_game
    new_game = Game.new(:X)
    assert_equal [:X, :O], new_game.players
    assert_equal :X, new_game.turn
    assert_equal [1, 2, 3, 4, 5, 6, 7, 8, 9], new_game.board
  end

  def test_possible_choices_gives_the_right_result
    # my new game, the first player is :X
    new_game = Game.new(:X)
    # initial possible choices that any player can make
    result = new_game.possible_choices(new_game.board)
    assert_equal [1, 2, 3, 4, 5, 6, 7, 8, 9], result
    # First player is X and X made a move, and we got a new board.
    new_game.set_a_new_board(3, :X)
    assert_equal [1, 2, :X, 4, 5, 6, 7, 8, 9], new_game.board
    # Change in board resulted in the change in player in the Game automatically
    assert_equal :O, new_game.turn
    # X trying to play consecutively, but with the right choice
    assert_raise (TurnError) do
      new_game.set_a_new_board(4, :X)
    end
    # X trying to play (consecutively) and a wrong choice (previous choice), resulting
    assert_raise (TurnError) do
      new_game.set_a_new_board(3, :X)
    end
    # O trying to play with a wrong choice (previous choice made by X)
    assert_raise (ChoiceError) do
      new_game.set_a_new_board(3, :O)
    end
    # O trying to play with a right choice (previous choice made by X)
    new_game.set_a_new_board(4, :O)
    assert_equal [1, 2, :X, :O, 5, 6, 7, 8, 9], new_game.board
    next_possible_choices = new_game.possible_choices(new_game.board)
    assert_equal [1, 2, 5, 6, 7, 8, 9], next_possible_choices
    # see if we can map over next_possible_choices
    assert_equal([2, 3, 6, 7, 8, 9, 10], next_possible_choices.map {|x| x + 1})
  end

  def test_game_over_function
    new_game = Game.new(:X)
    new_game.set_board([:X, :X, :X, :X, :X, :X, :X, :X, :X])
    assert_equal true, new_game.game_over?
    new_game.set_board([:X, :O, :O, :O, :X, :O, :O, :O, :X])
    assert_equal true, new_game.game_over?
    assert_equal true, new_game.game_won?(:X)
    new_game.set_board([:O, :X, :X, :X, :O, :X, :X, :X, :O])
    assert_equal true, new_game.game_won?(:O)
    new_game.set_board ([:O, :X, :X, :X, 5, 6, :X, :O, :O])
    assert_equal false, new_game.game_over?
    new_game.set_board ([:O, :X, :X, :X, :O, :X, :X, :O, :X])
    assert_equal true, new_game.game_over?
    new_game.set_board ([:O, :X, :X, :X, :O, :X, :X, :O, 9])
    assert_equal false, new_game.game_over?
  end

  def test_mini_max_to_work_perfectly
    game = Game.new(:X)
    game.set_board([:O, 2, :X, :X, 5, 6, :X, :O, :O])
    # if the output of mini_max recursive function is equal to the mini_max_scores in game
    print("the is amazing\n")
    # print("this is amazing #{game.mini_max(game)}" )
    game.mini_max(game, game)
    print ("OK! MinMax is over, see what is the min_max_scores now\n")
    print game.mini_max_scores

    #OK! Has the games initial board changed?, No it hasn't
    assert_equal [:O, 2, :X, :X, 5, 6, :X, :O, :O], game.board
    assert_equal [-10, 10, 10, 10, -10], game.mini_max_scores
  end

  def test_if_previous_game_would_ever_get_mutated_when_board_is_changed
    game = Game.new(:X)
    game.set_board([:O, :X, :X, :X, 5, 6, :X, :O, :O])
    new_turn = game.turn
    new_board = game.board
    new_game = Game.new(new_turn)
    new_game.set_board(new_board)
    new_game.set_a_new_board(5, new_game.turn)
    new_game.display_board
    game.display_board
    assert(new_game.board != game.board)
  end

  def test_append_scores
    game = Game.new(:X)
    game.push_score_min_max_score(+10)
    game.push_score_min_max_score(-10)
    assert_equal([10, -10], game.mini_max_scores)
  end
end