# frozen_string_literal: true

module LpSolver
  # Represents the solution returned by solving a model.
  #
  # The Solution object contains the optimal (or best-found) values for
  # all decision variables, the optimal objective value, and metadata
  # about the solver's execution.
  #
  # @example Accessing solution values
  #   solution = model.solve
  #   solution[:x]        # => 4.0 (value of variable x)
  #   solution[:y]        # => 0.0 (value of variable y)
  #   solution.objective_value  # => 12.0 (optimal objective)
  #
  # @example Checking solution status
  #   solution.feasible?      # => true
  #   solution.infeasible?    # => false
  #   solution.unbounded?     # => false
  class Solution
    # @return [Hash{String => Float}] Maps variable names to their optimal values.
    #   The keys are the variable names as strings (as produced by HiGHS),
    #   and the values are the optimal decision variable values.
    #   When the solution is infeasible, this hash is empty.
    #   Always check `infeasible?` or `unbounded?` before reading variable values.
    attr_reader :variables

    # @return [Float] The optimal objective function value.
    #   For minimization problems, this is the minimum value.
    #   For maximization problems, this is the maximum value.
    #   When the solution is infeasible, this returns `0.0`.
    #   Always check `infeasible?` or `unbounded?` before reading this value.
    attr_reader :objective_value

    # @return [String] The status of the model as reported by HiGHS.
    #   Possible values include:
    #   - "optimal": An optimal solution was found.
    #   - "infeasible": No feasible solution exists.
    #   - "unbounded": The objective can be improved without bound.
    #   - "unknown": The solver could not determine the status.
    attr_reader :model_status

    # @return [Integer] The number of iterations the solver performed.
    #   This is a diagnostic metric; may be 0 for some solver types.
    attr_reader :iterations

    # Returns the model status as a Symbol.
    #
    # @return [Symbol] The solver status as a Ruby symbol:
    #   - :optimal — An optimal solution was found.
    #   - :infeasible — No feasible solution exists.
    #   - :unbounded — The objective can be improved without bound.
    #   - :unknown — The solver could not determine the status.
    # @example
    #   solution.status  # => :optimal
    def status
      @model_status.to_sym
    end

    # Creates a new Solution object.
    #
    # @param variables [Hash{String => Float}] Maps variable names to values.
    # @param objective_value [Float] The optimal objective value.
    # @param model_status [String] The solver-reported model status.
    # @param iterations [Integer] The number of solver iterations.
    def initialize(variables:, objective_value:, model_status:, iterations:)
      @variables = variables
      @objective_value = objective_value
      @model_status = model_status
      @iterations = iterations
    end

    # Retrieves the value of a variable by name.
    #
    # @param name [Symbol, String, Variable] The variable name (Symbol, String,
    #   or Variable object).
    # @return [Float] The optimal value of the variable, or `nil` if the
    #   solution is infeasible or unbounded.
    # @raise [KeyError] If the variable name is not found in the solution.
    # @example
    #   solution[:x]        # => 4.0 (by symbol)
    #   solution['x']       # => 4.0 (by string)
    #   solution[x]         # => 4.0 (by Variable object)
    # @note When the solution is infeasible, all variables are empty.
    #   Check `infeasible?` first before accessing variable values.
    def [](name)
      key = if name.is_a?(Variable)
        name.name.to_s
      else
        name.to_s
      end
      variables[key]
    end

    # Retrieves values for multiple variables by name.
    #
    # @param *names [Symbol, String, Variable] The variable names to retrieve.
    # @return [Array<Float>] An array of variable values in the same order.
    # @example
    #   solution.values_at(:x, :y)      # => [4.0, 0.0]
    #   solution.values_at(x, y)        # => [4.0, 0.0] (by Variable objects)
    #   solution.values_at(:x, y, 'z')  # => [4.0, 0.0, 3.0] (mixed types)
    def values_at(*names)
      names.map { |name| self[name] }
    end

    # Returns all variables as a hash with Symbol keys.
    #
    # This is a convenience method that converts the internal String-keyed
    # variables hash to a Symbol-keyed hash for easier Ruby-style access.
    #
    # @return [Hash{Symbol => Float}] Maps variable names (as symbols) to
    #   their optimal values.
    # @example
    #   solution.all_variables
    #   # => { :x => 4.0, :y => 0.0 }
    def all_variables
      variables.transform_keys(&:to_sym)
    end

    # Returns the solution as a plain hash with Symbol keys.
    #
    # This is equivalent to #all_variables and is provided for Ruby
    # convention compatibility.
    #
    # @return [Hash{Symbol => Float}] Maps variable names to values.
    # @example
    #   solution.to_h  # => { :x => 4.0, :y => 0.0 }
    def to_h
      all_variables
    end

    # Iterates over all variables and their optimal values.
    #
    # Yields each variable name (as a Symbol) and its value.
    #
    # @yieldparam name [Symbol] The variable name.
    # @yieldparam value [Float] The optimal value of the variable.
    # @return [self] self for chaining.
    # @example
    #   solution.each_variable { |name, value| puts "#{name} = #{value}" }
    def each_variable
      all_variables.each { |name, value| yield name, value }
      self
    end

    # Checks if a variable exists in the solution.
    #
    # @param name [Symbol, String, Variable] The variable name to check.
    # @return [Boolean] True if the variable exists in the solution.
    # @example
    #   solution.has_variable?(:x)  # => true
    #   solution.has_variable?(:z)  # => false
    def has_variable?(name)
      key = if name.is_a?(Variable)
        name.name.to_s
      else
        name.to_s
      end
      variables.key?(key)
    end

    # Checks if the solution is feasible.
    #
    # A solution is feasible if the solver found a solution that satisfies
    # all constraints and bounds.
    #
    # @return [Boolean] True if the model status is "optimal".
    def feasible?
      @model_status == 'optimal'
    end

    # Checks if the model is infeasible.
    #
    # A model is infeasible if no solution exists that satisfies all
    # constraints simultaneously.
    #
    # @return [Boolean] True if the model status is "infeasible".
    def infeasible?
      @model_status == 'infeasible'
    end

    # Checks if the model is unbounded.
    #
    # A model is unbounded if the objective can be improved indefinitely
    # without violating any constraints.
    #
    # @return [Boolean] True if the model status is "unbounded".
    def unbounded?
      @model_status == 'unbounded'
    end

    # Returns a string representation of the solution.
    #
    # @return [String] A formatted string showing variable values and
    #   the objective value.
    # @example
    #   puts solution
    #   # x = 4.0
    #   # y = 0.0
    #   # Objective: 12.0
    def to_s
      lines = variables.map { |name, value| "#{name} = #{value}" }
      lines << "Objective: #{objective_value}"
      lines.join("\n")
    end
  end
end
