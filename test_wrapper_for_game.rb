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
      @turn = turn.clone
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
        return 1
      elsif game_won?(:O)
        return -1
      else
        return 0
      end
    end

    def possible_choices(b)
      result = b.select {|x| x.is_a?(Integer)}
      result
    end

    def min_max_algo(game, main_game)
      if game.game_over?
        main_game.mini_max_scores << game.score
        return main_game.mini_max_scores
      end
      i = 0
      possible_choices = possible_choices(game.board)
      while i < possible_choices.size
        another_game = Game.new(game.turn)
        another_game.set_board(game.board)
        another_game.display_board
        the_choice = possible_choices[i]
        another_game.set_a_new_board(the_choice, another_game.turn)
        another_game.display_board
        min_max_algo(another_game, main_game)
        i += 1
      end
      return main_game.mini_max_scores
    end

    def initiate_min_max
      i = 0
      min_max_scores = {}
      possible_choices = possible_choices(board)
      while i < possible_choices.size
        the_choice = possible_choices[i]
        another_game = Game.new(turn)
        another_game.set_board(board)
        another_game.set_a_new_board(the_choice, another_game.turn)
        result = min_max_algo(another_game, another_game)
        puts ("the possible choice is #{the_choice} and the score of that possible choice is #{result}")
        min_max_scores = min_max_scores.merge ({the_choice => result})
        puts(min_max_scores)
        i += 1
      end
      return min_max_scores
    end

    def choose_possible_choice(scorehash)
      scorehash.each do |key, array|
        if array.all?{|x| x == 1}
          return key
        elsif array.all? {|x| x == 1 || x == 0}
          return key
        end
      end
    end


    def main_game
      puts "give me some input"
      result = gets.chomp
      puts "give me the next result apart from #{result}"
      result2 = gets.chomp
      puts "nice you have finished with the final result #{result2}"
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

  def test_if_previous_game_would_ever_get_mutated_when_board_is_changed
    game = Game.new(:X)
    game.set_board([:O, :X, :X, :X, 5, 6, :X, :O, :O])
    new_turn = game.turn
    new_board = game.board
    new_game = Game.new(new_turn)
    new_game.set_board(new_board)
    new_game.set_a_new_board(5, new_game.turn)
    assert(new_game.board != game.board)
  end

  def test_append_scores
    game = Game.new(:X)
    game.push_score_min_max_score(+10)
    game.push_score_min_max_score(-10)
    assert_equal([10, -10], game.mini_max_scores)
  end

  def test_initiate_min_max
    game = Game.new(:X)
    game.set_board([:O, 2, :X, :X, 5, 6, :X, :O, :O])
    assert_equal ({2 => [-1, 1], 5 => [1], 6 => [1, -1]}), (game.initiate_min_max)
  end

  def test_choose_the_move
    game = Game.new (:X)
    game.set_board([:O, 2, :X, :X, 5, 6, :X, :O, :O])
    result = game.initiate_min_max
    another_result = ({2 => [1, 1], 5 => [1], 6 => [1, 1]})
    assert_equal 5,game.choose_possible_choice(result)
    # if all possible values are positive
    assert_equal 2  , game.choose_possible_choice(another_result)
    some_other_result = ({2 => [1, 0], 5 => [1, -1], 6 => [1, 1]})
    # if there are no positive, what happens?? To be something to think about
    assert_equal 6, game.choose_possible_choice(some_other_result)

  end
end