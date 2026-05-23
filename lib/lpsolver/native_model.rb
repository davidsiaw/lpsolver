# frozen_string_literal: true

module LpSolver
  # A native (C extension) backed model solver for HiGHS.
  #
  # This class uses the native C extension to call HiGHS directly,
  # bypassing the LP file serialization overhead of the CLI approach.
  # It requires the native extension to be compiled and linked against
  # the HiGHS library.
  #
  # @note This is a prototype. The native extension must be compiled
  #   separately using `rake compile` or `ruby ext/lpsolver/extconf.rb && make`.
  #
  # @example Basic usage
  #   require 'lpsolver/native_model'
  #
  #   model = LpSolver::NativeModel.new
  #   x = model.add_variable(:x, lb: 0)
  #   y = model.add_variable(:y, lb: 0)
  #
  #   model.add_constraint(:c1, (x + y) >= 4)
  #   solution = model.minimize!(x * 3 + y * 5)
  #
  #   puts solution[:x]  # => 4.0
  #
  # @example With MIP
  #   model = LpSolver::NativeModel.new
  #   x = model.add_variable(:x, lb: 0, integer: true)
  #   y = model.add_variable(:y, lb: 0, integer: true)
  #
  #   model.add_constraint(:c1, (x + y) == 10)
  #   solution = model.minimize!(x * 2 + y * 3)
  #
  #   puts solution[:x]  # => 10.0
  class NativeModel
    # @return [String] A descriptive name for this model.
    attr_reader :name

    # @return [Hash{Symbol => Variable}] All variables in the model.
    attr_reader :variables

    # @return [Array<Hash>] Constraint data for each constraint.
    attr_reader :constraints

    # @return [Symbol] Optimization sense (:minimize or :maximize).
    attr_reader :sense

    # @return [Hash{Integer => Float}] Linear objective coefficients.
    attr_reader :objective

    # @return [Array<[Integer, Integer, Float]>] Quadratic terms (for QP).
    attr_reader :quadratic_terms

    # Creates a new empty model.
    #
    # @param name [String] An optional name for this model.
    def initialize(name = nil)
      @name = name || 'untitled'
      @variables = {}
      @constraints = []
      @var_counter = 0
      @sense = :minimize
      @objective = {}
      @quadratic_terms = []
      @var_types = {}
      @var_bounds = {}
    end

    # Adds a variable to the model.
    #
    # @param name [Symbol, String] The variable name.
    # @param lb [Float] Lower bound (default: 0.0).
    # @param ub [Float] Upper bound (default: Float::INFINITY).
    # @param integer [Boolean] Whether the variable must be integer (default: false).
    # @return [Variable] The variable object.
    def add_variable(name, lb: 0.0, ub: Float::INFINITY, integer: false)
      name = name.to_sym
      idx = @var_counter
      var = Variable.new(idx, name)
      @variables[name] = var
      @var_types[name] = integer ? 1 : 0
      @var_bounds[name] = [lb, ub]
      @var_counter += 1
      var
    end

    # Adds a constraint to the model.
    #
    # @param name [Symbol, String] The constraint name.
    # @param expr [ConstraintSpec] The constraint specification.
    # @return [Symbol] The constraint name.
    def add_constraint(name, expr)
      name = name.to_sym
      lb_val, ub_val = expr.bounds
      data_expr = expr.expr

      @constraints << {
        name: name,
        lb: lb_val,
        ub: ub_val,
        expr: data_expr
      }
      name
    end

    # Sets the optimization sense to minimization.
    #
    # @return [void]
    def minimize
      @sense = :minimize
    end

    # Sets the optimization sense to maximization.
    #
    # @return [void]
    def maximize
      @sense = :maximize
    end

    # Sets the objective function.
    #
    # @param objective [LinearExpression, QuadraticExpression] The objective.
    # @return [void]
    def set_objective(objective)
      if objective.is_a?(QuadraticExpression)
        @objective = objective.linear_terms.transform_values(&:to_f)
        @quadratic_terms = objective.hessian_entries
      elsif objective.is_a?(LinearExpression)
        @objective = objective.terms.transform_values(&:to_f)
        @quadratic_terms = []
      end
    end

    # Solves the model using the native extension.
    #
    # @return [Solution] The solution object.
    # @raise [SolverError] If the solver encounters an error.
    # @raise [LoadError] If the native extension is not available.
    def solve
      unless defined?(LpSolver::Native)
        raise LoadError, 'Native extension not available. Compile with: rake compile'
      end

      num_col = @var_counter
      num_row = @constraints.size

      # Build column arrays
      col_cost = Array.new(num_col, 0.0)
      col_lower = Array.new(num_col)
      col_upper = Array.new(num_col)
      col_integrality = Array.new(num_col, 0)

      @var_bounds.each do |name, (lb, ub)|
        idx = @variables[name].index
        col_lower[idx] = lb
        col_upper[idx] = ub
        col_integrality[idx] = @var_types[name] || 0
      end

      @objective.each do |idx, coeff|
        col_cost[idx] = coeff
      end

      # Build constraint arrays (sparse matrix in CSC format)
      row_lower = Array.new(num_row)
      row_upper = Array.new(num_row)
      astart = Array.new(num_row + 1, 0)
      aindex = []
      avalues = []
      nz_count = 0

      @constraints.each_with_index do |constr, row_idx|
        row_lower[row_idx] = constr[:lb]
        row_upper[row_idx] = constr[:ub]

        constr[:expr].each do |col_idx, coeff|
          aindex << col_idx
          avalues << coeff
          astart[row_idx + 1] += 1
          nz_count += 1
        end
      end

      # Adjust astart to be cumulative
      cumulative = 0
      astart.each_with_index do |val, i|
        old = astart[i]
        astart[i] = cumulative
        cumulative += val
      end

      # Determine sense
      sense = @sense == :maximize ? :maximize : :minimize

      # Build quadratic arrays (for QP)
      q_start = [0]
      q_index = []
      q_values = []

      @quadratic_terms.each do |i1, i2, coeff|
        q_index << i2
        q_values << coeff
        q_start << q_index.size
      end

      # Call native solver
      if @quadratic_terms.any?
        result = LpSolver::Native.solve_qp(
          num_col, num_row,
          col_cost, col_lower, col_upper,
          row_lower, row_upper,
          astart, aindex, avalues,
          q_start, q_index, q_values,
          sense
        )
      else
        result = LpSolver::Native.solve_lp(
          num_col, num_row,
          col_cost, col_lower, col_upper, col_integrality,
          row_lower, row_upper,
          astart, aindex, avalues,
          sense
        )
      end

      # Parse result
      variables = {}
      result[:col_value].each_with_index do |val, idx|
        var_name = @variables.find { |_, v| v.index == idx }&.first
        variables[var_name.to_s] = val if var_name
      end

      Solution.new(
        variables: variables,
        objective_value: result[:objective],
        model_status: result[:status].to_s,
        iterations: 0
      )
    end

    # Sets the optimization sense, objective, and solves in one call.
    #
    # @param objective [LinearExpression, QuadraticExpression] The objective.
    # @return [Solution] The solution object.
    def minimize!(objective)
      @sense = :minimize
      set_objective(objective)
      solve
    end

    # Sets the optimization sense, objective, and solves in one call.
    #
    # @param objective [LinearExpression, QuadraticExpression] The objective.
    # @return [Solution] The solution object.
    def maximize!(objective)
      @sense = :maximize
      set_objective(objective)
      solve
    end
  end
end
