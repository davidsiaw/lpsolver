# frozen_string_literal: true

module LpSolver
  # Represents a decision variable in an LP/MIP/QP model.
  #
  # Variables are the building blocks of optimization models. Each variable
  # represents a quantity to be determined by the solver (e.g., production
  # levels, investment amounts, resource allocations).
  #
  # Variables support arithmetic operators for building expressions and
  # comparison operators for creating constraints. The operator overloading
  # enables a natural, mathematical DSL:
  #
  #   x = model.add_variable(:x, lb: 0)
  #   model.add_constraint(:budget, (x * 2 + y) <= 100)
  #
  # @note Variable * Variable produces a QuadraticExpression (for QP).
  #   Variable * Scalar produces a LinearExpression (for LP).
  #
  # @example Creating a variable
  #   x = model.add_variable(:x, lb: 0, ub: 100, integer: false)
  #   x.index    # => 0
  #   x.name     # => :x
  #
  # @example Using in expressions
  #   expr = x * 2 + y * 3          # LinearExpression
  #   quad = x * x + y * y          # QuadraticExpression
  #   spec = (x * 2 + y) <= 100     # ConstraintSpec
  class Variable
    # @return [Integer] The internal index of this variable in the model.
    #   This is used internally to map the variable to a column in the
    #   solver's constraint matrix.
    attr_reader :index

    # @return [Symbol] The human-readable name of this variable.
    attr_reader :name

    # Creates a new Variable instance.
    #
    # @param index [Integer] The internal index assigned by the model.
    # @param name [Symbol] The human-readable name of this variable.
    def initialize(index, name)
      @index = index
      @name = name
    end

    # Multiplies this variable by a scalar or another variable.
    #
    # When multiplied by a Numeric, returns a LinearExpression with this
    # variable scaled by the given coefficient. When multiplied by another
    # Variable, returns a QuadraticExpression representing the product term
    # (used for quadratic objectives in QP).
    #
    # @param other [Numeric, Variable] The multiplier.
    # @return [LinearExpression] When +other+ is a Numeric.
    #   Example: `x * 2` → LinearExpression with terms {0 => 2.0}
    # @return [QuadraticExpression] When +other+ is a Variable.
    #   Example: `x * y` → QuadraticExpression with terms [[0, 1, 1.0]]
    def *(other)
      if other.is_a?(Variable)
        QuadraticExpression.new({}, [[@index, other.index, 1.0]])
      else
        LinearExpression.new({ @index => other.to_f })
      end
    end

    # Adds another variable, expression, or constant to this variable.
    #
    # Creates a new LinearExpression containing the sum of this variable
    # and the other operand.
    #
    # @param other [Variable, LinearExpression, Numeric] The operand to add.
    # @return [LinearExpression] A new expression representing the sum.
    # @example Adding two variables
    #   (x + y).terms  # => {0 => 1.0, 1 => 1.0}
    # @example Adding a constant
    #   (x + 5).constant  # => 5.0
    def +(other)
      if other.is_a?(Variable)
        LinearExpression.new({ @index => 1.0, other.index => 1.0 })
      elsif other.is_a?(LinearExpression)
        LinearExpression.new(merge_terms({ @index => 1.0 }, other.terms), other.constant)
      else
        LinearExpression.new({ @index => 1.0 }, other.to_f)
      end
    end

    # Subtracts another variable, expression, or constant from this variable.
    #
    # Creates a new LinearExpression containing the difference between this
    # variable and the other operand.
    #
    # @param other [Variable, LinearExpression, Numeric] The operand to subtract.
    # @return [LinearExpression] A new expression representing the difference.
    # @example Subtracting two variables
    #   (x - y).terms  # => {0 => 1.0, 1 => -1.0}
    # @example Subtracting a constant
    #   (x - 5).constant  # => -5.0
    def -(other)
      if other.is_a?(Variable)
        LinearExpression.new({ @index => 1.0, other.index => -1.0 })
      elsif other.is_a?(LinearExpression)
        LinearExpression.new(negate_add_terms({ @index => 1.0 }, other.terms), -other.constant)
      else
        LinearExpression.new({ @index => 1.0 }, -other.to_f)
      end
    end

    # Returns a LinearExpression with this variable negated.
    #
    # @return [LinearExpression] A new expression with negated coefficients.
    # @example
    #   (-x).terms  # => {0 => -1.0}
    def -@
      LinearExpression.new({ @index => -1.0 })
    end

    # Creates a less-than-or-equal-to constraint specification.
    #
    # This is used with Model#add_constraint to define upper bounds on
    # linear expressions. The constraint represents: expression <= value.
    #
    # @param value [Numeric] The right-hand side upper bound.
    # @return [ConstraintSpec] A constraint specification with operator :le.
    # @example
    #   model.add_constraint(:budget, (x * 2 + y) <= 100)
    # @param [Object] other
    def <=(other)
      ConstraintSpec.new(:le, { @index => 1.0 }, 0, other.to_f)
    end

    # Creates a greater-than-or-equal-to constraint specification.
    #
    # This is used with Model#add_constraint to define lower bounds on
    # linear expressions. The constraint represents: expression >= value.
    #
    # @param value [Numeric] The right-hand side lower bound.
    # @return [ConstraintSpec] A constraint specification with operator :ge.
    # @example
    #   model.add_constraint(:demand, (x + y * 2) >= 50)
    # @param [Object] other
    def >=(other)
      ConstraintSpec.new(:ge, { @index => 1.0 }, 0, other.to_f)
    end

    # Creates an equality constraint specification.
    #
    # This is used with Model#add_constraint to define exact values for
    # linear expressions. The constraint represents: expression == value.
    #
    # @param value [Numeric] The exact value the expression must equal.
    # @return [ConstraintSpec] A constraint specification with operator :eq.
    # @example
    #   model.add_constraint(:weights, (x + y + z) == 1)
    # @param [Object] other
    def ==(other)
      ConstraintSpec.new(:eq, { @index => 1.0 }, 0, other.to_f)
    end

    # Checks if two variables refer to the same underlying variable.
    #
    # @param other [Object] The object to compare against.
    # @return [Boolean] True if +other+ is a Variable with the same index.
    def equals?(other)
      other.is_a?(Variable) && other.index == @index
    end

    # Returns a string representation of this variable.
    #
    # @return [String] A string in the format "@name(index)".
    # @example
    #   x.to_s  # => "@x(0)"
    def to_s
      "@#{@name}(#{@index})"
    end

    # Converts this variable's name to a Symbol.
    #
    # @return [Symbol] The variable's name.
    # @example
    #   x.to_sym  # => :x
    def to_sym
      @name
    end

    # Returns the hash code based on this variable's index.
    #
    # @return [Integer] The hash code of the variable's index.
    def hash
      @index.hash
    end

    alias eql? equals?

    private

    # Merges two term hashes, combining coefficients for duplicate indices.
    #
    # @param a [Hash{Integer => Float}] First term hash.
    # @param b [Hash{Integer => Float}] Second term hash.
    # @return [Hash{Integer => Float}] The merged term hash with zero coefficients removed.
    def merge_terms(a, b)
      merged = a.dup
      b.each { |idx, coeff| merged[idx] = (merged[idx] || 0) + coeff }
      merged.reject! { |_, v| v.zero? }
      merged
    end

    # Merges two term hashes with subtraction (a - b).
    #
    # @param a [Hash{Integer => Float}] First term hash.
    # @param b [Hash{Integer => Float}] Second term hash to subtract.
    # @return [Hash{Integer => Float}] The difference term hash with zero coefficients removed.
    def negate_add_terms(a, b)
      merged = a.dup
      b.each { |idx, coeff| merged[idx] = (merged[idx] || 0) - coeff }
      merged.reject! { |_, v| v.zero? }
      merged
    end
  end
end
