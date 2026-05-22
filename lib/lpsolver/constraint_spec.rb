# frozen_string_literal: true

module LpSolver
  # Represents a constraint specification derived from comparing an expression with a value.
  #
  # ConstraintSpec objects are created when comparison operators (<=, >=, ==) are
  # applied to LinearExpression or Variable objects. They encode the constraint's
  # operator type, variable coefficients, and bounds.
  #
  # A constraint specification has the form:
  #   operator: sum(coeff_i * x_i) + constant_offset compared to rhs
  #
  # The bounds are computed by rearranging the expression to isolate the
  # variables on the left-hand side:
  #   sum(coeff_i * x_i) <= (rhs - constant_offset)  for <= constraints
  #   sum(coeff_i * x_i) >= (rhs - constant_offset)  for >= constraints
  #   sum(coeff_i * x_i) == (rhs - constant_offset)  for == constraints
  #
  # @example Creating a constraint specification
  #   x = model.add_variable(:x, lb: 0)
  #   y = model.add_variable(:y, lb: 0)
  #   spec = (x * 2 + y * 3 + 5) <= 100
  #   spec.operator    # => :le
  #   spec.terms       # => {x_idx => 2.0, y_idx => 3.0}
  #   spec.lhs_constant # => 5.0
  #   spec.rhs         # => 100.0
  #   spec.bounds      # => [-Infinity, 95.0]
  #
  # @example Using in a model
  #   model.add_constraint(:budget, (x * 2 + y * 3 + 5) <= 100)
  class ConstraintSpec
    # @return [Symbol] The constraint operator: :le (<=), :ge (>=), or :eq (==).
    attr_reader :operator

    # @return [Hash{Integer => Float}] Maps variable indices to their coefficients
    #   in the expression (excluding the constant offset).
    attr_reader :terms

    # @return [Float] The constant offset on the left-hand side of the comparison.
    #   For example, in `(x * 2 + y * 3 + 5) <= 100`, this is 5.0.
    attr_reader :lhs_constant

    # @return [Float] The right-hand side value of the comparison.
    #   For example, in `(x * 2 + y * 3 + 5) <= 100`, this is 100.0.
    attr_reader :rhs

    # Creates a new ConstraintSpec.
    #
    # @param operator [Symbol] The constraint operator: :le, :ge, or :eq.
    # @param terms [Hash{Integer => Float}] Maps variable indices to coefficients.
    # @param lhs_constant [Float] The constant offset on the left-hand side.
    # @param rhs [Float] The right-hand side value.
    def initialize(operator, terms, lhs_constant, rhs)
      @operator = operator
      @terms = terms
      @lhs_constant = lhs_constant
      @rhs = rhs
    end

    # Converts this constraint specification to lower and upper bounds.
    #
    # Rearranges the constraint expression to isolate the variable terms,
    # computing the effective bounds for the expression.
    #
    # @return [Array<Float, Float>] An array [lb, ub] representing the
    #   lower and upper bounds for the variable terms.
    # @example For (x * 2 + y * 3 + 5) <= 100
    #   spec.bounds  # => [-Infinity, 95.0]
    # @example For (x * 2 + y * 3 + 5) >= 50
    #   spec.bounds  # => [45.0, Infinity]
    # @example For (x * 2 + y * 3 + 5) == 75
    #   spec.bounds  # => [70.0, 70.0]
    def bounds
      case @operator
      when :le
        [-Float::INFINITY, @rhs - @lhs_constant]
      when :ge
        [@rhs - @lhs_constant, Float::INFINITY]
      when :eq
        v = @rhs - @lhs_constant
        [v, v]
      end
    end

    # Returns the expression terms as an array of [variable_index, coefficient] pairs.
    #
    # This format is used internally when serializing the model to HiGHS LP format.
    #
    # @return [Array<[Integer, Float]>] Array of [var_index, coefficient] pairs.
    # @example
    #   spec.expr  # => [[0, 2.0], [1, 3.0]]
    def expr
      @terms.map { |idx, coeff| [idx, coeff] }
    end
  end
end
