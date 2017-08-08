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

    def set_board(board)
      @board = board
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
        board = @board
        index_choices = possible_choices(board)
        if index_choices.include? index
          @board[index - 1] = new_turn
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
      display_board
      winning_sequences = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]]
      winning_sequences.each {|sequence|
        if sequence.all? {|a| @board[a] == player}
          return true
        end
      }
    end

    def ready_for_min_max?
      if @player == :X
        true
      else
        false
      end
    end

    def game_over?
      return !@board.all? {|x| x.is_a?(Integer)} || game_won?(:X) || game_won?(:O)
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

    def score(game)
      if game.game_won?(:X)
        return 10
      elsif game.game_won?(:O)
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
    def minimax(game)
      i = 1
      # When you calculate minimax, you need to ensure that the existing player
      # is :X, that is turn == :X
      scores = []
      # this minmax algorithm is only for computer player. Computer just needs to win the game.
      temporary_board = game.board
      # this game should start with computer player, we simulate the future games starting from anothergame.
      # This is recursive. Hence we create a new game in every recursive call, making sure that the main game
      # is not mutated by any chance.
      another_game = Game.new(game.turn)
      another_game.set_board(temporary_board)
      # The initial set of possible choices with the current state of the board
      possible_choices = possible_choices(temporary_board)
      while i < possible_choices
        # Every possible choice leads to a state change.
        # A change in state of the board and player mainly, and obviously the score.
        # We could create new instance of the game everytime we make a possible choice
        # calculate the score and select the choice that gives the maximum score and outside
        # the recursion, you need to set the new game with the new board and the new player
        the_choice = possible_choices[i]
        another_game.set_a_new_board(the_choice, another_game.turn)
        if score(another_game)
          possible_choices = @board.select {|x| x.is_a?(Integer)}
        end
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
    assert_equal true, new_game.game_won?(:X)
  end
end