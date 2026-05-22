# frozen_string_literal: true

module LpSolver
  # Represents a linear expression: sum of (coefficient * variable) + constant.
  #
  # Linear expressions are the fundamental building blocks of linear programming
  # models. They represent quantities like costs, resource usage, or returns
  # that scale linearly with decision variables.
  #
  # A linear expression has the mathematical form:
  #   c₀ + c₁·x₁ + c₂·x₂ + ... + cₙ·xₙ
  #
  # where c₀ is the constant offset and cᵢ are the coefficients for each variable.
  #
  # @example Building a linear expression
  #   x = model.add_variable(:x, lb: 0)
  #   y = model.add_variable(:y, lb: 0)
  #   expr = x * 2 + y * 3 + 5   # 2x + 3y + 5
  #   expr.terms      # => {0 => 2.0, 1 => 3.0}
  #   expr.constant   # => 5.0
  #
  # @example Using in constraints
  #   model.add_constraint(:budget, (x * 2 + y * 3 + 5) <= 100)
  #
  # @example Using in objectives
  #   model.set_objective(x * 2 + y * 3 + 5)
  class LinearExpression
    # @return [Hash{Integer => Float}] Maps variable indices to their coefficients.
    #   The keys are the internal indices assigned by the model, and the values
    #   are the floating-point coefficients.
    # @example
    #   (x * 2 + y * 3).terms  # => {0 => 2.0, 1 => 3.0}
    attr_reader :terms

    # @return [Float] The constant offset in the expression.
    # @example
    #   (x * 2 + 5).constant  # => 5.0
    attr_reader :constant

    # Creates a new LinearExpression.
    #
    # @param terms [Hash{Integer => Float}] Maps variable indices to coefficients.
    # @param constant [Float] The constant offset (default: 0.0).
    def initialize(terms = {}, constant = 0.0)
      @terms = terms
      @constant = constant
    end

    # Adds another expression, variable, constant, or quadratic expression.
    #
    # When adding a LinearExpression or Variable, returns a new LinearExpression.
    # When adding a QuadraticExpression, returns a new QuadraticExpression
    # that combines the linear and quadratic parts.
    #
    # @param other [LinearExpression, QuadraticExpression, Variable, Numeric] The operand to add.
    # @return [LinearExpression] When +other+ is a Numeric, Variable, or LinearExpression.
    # @return [QuadraticExpression] When +other+ is a QuadraticExpression.
    # @example Adding two linear expressions
    #   (x * 2 + 3) + (x + 5)  # => 3x + 8
    # @example Adding a quadratic expression
    #   (x * 2) + (y * y)  # => QuadraticExpression with linear: {x => 2}, quadratic: [[y, y, 1]]
    def +(other)
      if other.is_a?(Variable)
        LinearExpression.new(
          merge_terms(@terms, { other.index => 1.0 }),
          @constant
        )
      elsif other.is_a?(LinearExpression)
        LinearExpression.new(
          merge_terms(@terms, other.terms),
          @constant + other.constant
        )
      elsif other.is_a?(QuadraticExpression)
        new_linear = other.linear_terms.dup
        @terms.each { |idx, coeff| new_linear[idx] = (new_linear[idx] || 0) + coeff }
        QuadraticExpression.new(new_linear.reject { |_, v| v.zero? }, other.quadratic_terms.dup)
      else
        LinearExpression.new(@terms.dup, @constant + other.to_f)
      end
    end

    # Subtracts another expression, variable, constant, or quadratic expression.
    #
    # @param other [LinearExpression, QuadraticExpression, Variable, Numeric] The operand to subtract.
    # @return [LinearExpression] When +other+ is a Numeric, Variable, or LinearExpression.
    # @return [QuadraticExpression] When +other+ is a QuadraticExpression.
    # @example Subtracting a linear expression
    #   (x * 5 + 10) - (x * 2 + 3)  # => 3x + 7
    def -(other)
      if other.is_a?(Variable)
        LinearExpression.new(
          merge_terms(@terms, { other.index => -1.0 }),
          @constant
        )
      elsif other.is_a?(LinearExpression)
        LinearExpression.new(
          merge_terms(@terms, negate_terms(other.terms)),
          @constant - other.constant
        )
      elsif other.is_a?(QuadraticExpression)
        new_linear = other.linear_terms.dup
        @terms.each { |idx, coeff| new_linear[idx] = (new_linear[idx] || 0) + coeff }
        neg_quad = other.quadratic_terms.map { |i1, i2, c| [i1, i2, -c] }
        QuadraticExpression.new(new_linear.reject { |_, v| v.zero? }, neg_quad)
      else
        LinearExpression.new(@terms.dup, @constant - other.to_f)
      end
    end

    # Multiplies this expression by a scalar.
    #
    # Scales both the variable coefficients and the constant by the given factor.
    #
    # @param scalar [Numeric] The scalar multiplier.
    # @return [LinearExpression] A new expression with all coefficients scaled.
    # @example
    #   (x * 2 + 3) * 4  # => 8x + 12
    # @param [Object] other
    def *(other)
      s = other.to_f
      LinearExpression.new(
        @terms.transform_values { |c| c * s },
        @constant * s
      )
    end

    # Returns a LinearExpression with all coefficients and the constant negated.
    #
    # @return [LinearExpression] A new expression with negated terms.
    # @example
    #   -(x * 3 + 5)  # => -3x - 5
    def -@
      LinearExpression.new(
        @terms.transform_values { |c| -c },
        -@constant
      )
    end

    # Creates a less-than-or-equal-to constraint specification.
    #
    # @param value [Numeric] The right-hand side upper bound.
    # @return [ConstraintSpec] A constraint specification with operator :le.
    # @example
    #   model.add_constraint(:c, (x * 2 + y * 3 + 5) <= 100)
    # @param [Object] other
    def <=(other)
      ConstraintSpec.new(:le, @terms.dup, @constant, other.to_f)
    end

    # Creates a greater-than-or-equal-to constraint specification.
    #
    # @param value [Numeric] The right-hand side lower bound.
    # @return [ConstraintSpec] A constraint specification with operator :ge.
    # @example
    #   model.add_constraint(:c, (x * 2 + y * 3 + 5) >= 50)
    # @param [Object] other
    def >=(other)
      ConstraintSpec.new(:ge, @terms.dup, @constant, other.to_f)
    end

    # Creates an equality constraint specification.
    #
    # @param value [Numeric] The exact value the expression must equal.
    # @return [ConstraintSpec] A constraint specification with operator :eq.
    # @example
    #   model.add_constraint(:c, (x * 2 + y * 3 + 5) == 75)
    # @param [Object] other
    def ==(other)
      ConstraintSpec.new(:eq, @terms.dup, @constant, other.to_f)
    end

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

    # Negates all coefficients in a term hash.
    #
    # @param terms [Hash{Integer => Float}] The term hash to negate.
    # @return [Hash{Integer => Float}] A new hash with negated coefficients.
    def negate_terms(terms)
      terms.transform_values { |c| -c }
    end
  end
end
