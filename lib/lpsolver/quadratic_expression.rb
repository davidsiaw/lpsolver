# frozen_string_literal: true

module LpSolver
  # Represents a quadratic expression: linear terms + quadratic terms.
  #
  # Quadratic expressions extend linear expressions by including second-order
  # terms (products of two variables). They are used to model quadratic objectives
  # in Quadratic Programming (QP) problems, such as portfolio variance,
  # least-squares residuals, or convex penalty functions.
  #
  # A quadratic expression has the mathematical form:
  #   c₀ + Σᵢ cᵢ·xᵢ + ½ Σᵢⱼ Qᵢⱼ·xᵢ·xⱼ
  #
  # where c₀ is the constant, cᵢ are linear coefficients, and Q is the
  # symmetric Hessian matrix of quadratic coefficients.
  #
  # @note The Hessian is stored in a normalized form where off-diagonal
  #   entries (i ≠ j) are stored once as [i, j, coefficient], and the
  #   LP format automatically applies the ½ factor.
  #
  # @example Building a quadratic expression
  #   x = model.add_variable(:x, lb: 0)
  #   y = model.add_variable(:y, lb: 0)
  #   quad = x * x + y * y + (x * y) * 2   # x² + 2xy + y² = (x+y)²
  #   quad.linear_terms      # => {}
  #   quad.quadratic_terms   # => [[0, 0, 1.0], [1, 1, 1.0], [0, 1, 2.0]]
  #
  # @example Using in a QP model
  #   model.minimize
  #   model.set_objective(x * x + y * y)
  #   solution = model.solve
  class QuadraticExpression
    # @return [Hash{Integer => Float}] Maps variable indices to linear coefficients.
    #   The keys are internal variable indices, and the values are the coefficients
    #   of the linear terms (e.g., 2x + 3y → {x_idx => 2.0, y_idx => 3.0}).
    attr_reader :linear_terms

    # @return [Array<[Integer, Integer, Float]>] Quadratic term pairs.
    #   Each element is [var1_index, var2_index, coefficient], representing
    #   coefficient * var1 * var2. For diagonal terms (var1 == var2), this
    #   represents coefficient * var1².
    # @example
    #   (x * x).quadratic_terms  # => [[0, 0, 1.0]]
    #   (x * y).quadratic_terms  # => [[0, 1, 1.0]]
    attr_reader :quadratic_terms

    # Creates a new QuadraticExpression.
    #
    # @param linear_terms [Hash{Integer => Float}] Maps variable indices to linear coefficients.
    # @param quadratic_terms [Array<[Integer, Integer, Float]>] Quadratic term pairs.
    def initialize(linear_terms = {}, quadratic_terms = [])
      @linear_terms = linear_terms
      @quadratic_terms = quadratic_terms
    end

    # Adds another expression, variable, constant, or quadratic expression.
    #
    # @param other [QuadraticExpression, LinearExpression, Variable, Numeric] The operand to add.
    # @return [QuadraticExpression] A new expression combining the operands.
    # @example Adding two quadratic expressions
    #   (x * x) + (y * y)  # => QuadraticExpression with [[0,0,1.0], [1,1,1.0]]
    # @example Adding a linear expression
    #   (x * x) + (x * 2 + 1)  # => QuadraticExpression with linear: {x => 2}, constant: 1
    def +(other)
      if other.is_a?(Variable)
        new_linear = @linear_terms.dup
        new_linear[other.index] = (new_linear[other.index] || 0) + 1
        QuadraticExpression.new(new_linear, @quadratic_terms.dup)
      elsif other.is_a?(LinearExpression)
        new_linear = @linear_terms.dup
        other.terms.each { |idx, coeff| new_linear[idx] = (new_linear[idx] || 0) + coeff }
        QuadraticExpression.new(new_linear.reject { |_, v| v.zero? }, @quadratic_terms.dup)
      elsif other.is_a?(QuadraticExpression)
        new_linear = @linear_terms.dup
        other.linear_terms.each { |idx, coeff| new_linear[idx] = (new_linear[idx] || 0) + coeff }
        new_linear.reject! { |_, v| v.zero? }
        QuadraticExpression.new(new_linear, @quadratic_terms + other.quadratic_terms)
      else
        new_linear = @linear_terms.dup
        new_linear[0] = (new_linear[0] || 0) + other.to_f
        QuadraticExpression.new(new_linear, @quadratic_terms.dup)
      end
    end

    # Subtracts another expression, variable, constant, or quadratic expression.
    #
    # @param other [QuadraticExpression, LinearExpression, Variable, Numeric] The operand to subtract.
    # @return [QuadraticExpression] A new expression representing the difference.
    # @example
    #   (x * x + y * y) - (x * y)  # => QuadraticExpression with [[0,0,1.0], [1,1,1.0], [0,1,-1.0]]
    def -(other)
      if other.is_a?(Variable)
        new_linear = @linear_terms.dup
        new_linear[other.index] = (new_linear[other.index] || 0) - 1
        QuadraticExpression.new(new_linear.reject { |_, v| v.zero? }, @quadratic_terms.dup)
      elsif other.is_a?(LinearExpression)
        new_linear = @linear_terms.dup
        other.terms.each { |idx, coeff| new_linear[idx] = (new_linear[idx] || 0) - coeff }
        QuadraticExpression.new(new_linear.reject { |_, v| v.zero? }, @quadratic_terms.dup)
      elsif other.is_a?(QuadraticExpression)
        new_linear = @linear_terms.dup
        other.linear_terms.each { |idx, coeff| new_linear[idx] = (new_linear[idx] || 0) - coeff }
        new_linear.reject! { |_, v| v.zero? }
        neg_quad = other.quadratic_terms.map { |i1, i2, c| [i1, i2, -c] }
        QuadraticExpression.new(new_linear, @quadratic_terms + neg_quad)
      else
        new_linear = @linear_terms.dup
        new_linear[0] = (new_linear[0] || 0) - other.to_f
        QuadraticExpression.new(new_linear, @quadratic_terms.dup)
      end
    end

    # Multiplies this expression by a scalar.
    #
    # Scales both linear coefficients and quadratic coefficients by the given factor.
    #
    # @param scalar [Numeric] The scalar multiplier.
    # @return [QuadraticExpression] A new expression with all coefficients scaled.
    # @example
    #   (x * x + y * y) * 2  # => QuadraticExpression with [[0,0,2.0], [1,1,2.0]]
    # @param [Object] other
    def *(other)
      s = other.to_f
      new_linear = @linear_terms.transform_values { |c| c * s }
      new_linear.reject! { |_, v| v.zero? }
      new_quad = @quadratic_terms.map { |i1, i2, c| [i1, i2, c * s] }
      QuadraticExpression.new(new_linear, new_quad)
    end

    # Returns a QuadraticExpression with all coefficients negated.
    #
    # @return [QuadraticExpression] A new expression with negated terms.
    # @example
    #   -(x * x + y * y)  # => QuadraticExpression with [[0,0,-1.0], [1,1,-1.0]]
    def -@
      QuadraticExpression.new(
        @linear_terms.transform_values { |c| -c }.reject { |_, v| v.zero? },
        @quadratic_terms.map { |i1, i2, c| [i1, i2, -c] }
      )
    end

    # Converts quadratic terms to HiGHS Hessian entries.
    #
    # Combines symmetric entries (e.g., x*y and y*x) and multiplies by 2
    # to account for the ½ factor in the HiGHS LP format:
    #   [ 2·Qᵢⱼ·xᵢ·xⱼ ] / 2 = Qᵢⱼ·xᵢ·xⱼ
    #
    # @return [Array<[Integer, Integer, Float]>] Hessian entries as [var1_idx, var2_idx, coefficient].
    #   Each coefficient represents the value that will be divided by 2 in the LP format.
    # @example
    #   (x * x).hessian_entries  # => [[0, 0, 2.0]]  → LP: [2x²]/2 = x²
    #   (x * y + y * x).hessian_entries  # => [[0, 1, 4.0]]  → LP: [4xy]/2 = 2xy
    def hessian_entries
      # Normalize: combine symmetric entries
      pairs = {}
      @quadratic_terms.each do |i1, i2, c|
        key = [i1, i2].sort
        pairs[key] = (pairs[key] || 0) + c
      end
      # Multiply by 2 to account for the "/ 2" in the LP format
      pairs.map { |key, c| [key[0], key[1], c * 2.0] }
    end
  end
end
