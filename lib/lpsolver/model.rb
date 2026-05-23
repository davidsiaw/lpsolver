# frozen_string_literal: true

module LpSolver
  # A high-level interface to HiGHS for building and solving LP/QP/MIP models.
  #
  # The Model class provides a Ruby DSL for defining variables, constraints,
  # and objectives. Models are solved via a pluggable driver.
  #
  class Model
    # @return [Hash{Symbol => Variable}] All variables defined in this model.
    attr_reader :variables
    # @return [Integer] The next available variable index.
    attr_reader :var_counter
    # @return [Symbol] The current optimization heading.
    attr_reader :heading
    # @return [Array<Hash>] Constraint data as an array of {name, lb, ub, expr}.
    def constraints
      @constraints_data.values
    end
    # @return [Hash{Symbol => Hash}] Maps constraint names to their data.
    attr_reader :constraints_data
    # @return [Hash{Symbol => Symbol}] Maps variable names to their types.
    attr_reader :var_types
    # @return [Hash{Integer => Float}] Maps variable indices to coefficients.
    attr_reader :objective
    # @return [Array<[Integer, Integer, Float]>] Quadratic term entries.
    attr_reader :quadratic_terms
    # @return [Hash{Symbol => Array<Float>}] Maps variable names to [lb, ub] bounds.
    attr_reader :var_bounds
    # @return [String] The model name.
    attr_reader :name
    # @return [Drivers::CliDriver, Drivers::NativeDriver] The configured solver driver.
    attr_reader :driver

    # Returns the default solver driver.
    #
    # Tries CliDriver first (if HiGHS binary is available), then falls back
    # to NativeDriver (if native extension is compiled), then raises an error.
    #
    # @return [Drivers::CliDriver, Drivers::NativeDriver] The default driver.
    # @raise [RuntimeError] If neither CLI nor native driver is available.
    def self.default_driver
      begin
        Drivers::CliDriver.new
      rescue
        begin
          Drivers::NativeDriver.new
        rescue LoadError
          raise 'No solver available. Install HiGHS or compile the native extension with: rake compile'
        end
      end
    end

    # Solves the model using the configured driver, with automatic fallback.
    #
    # If the configured driver is CliDriver and the HiGHS binary is not found,
    # automatically falls back to NativeDriver. If NativeDriver is also not
    # available, raises the original error.
    #
    # @return [Solution] The solution object.
    # @raise [SolverError] If the solver encounters an error.
    # @raise [LoadError] If no driver is available.
    def solve
      begin
        @driver.solve(self)
      rescue SolverError, LoadError => e
        # If CLI driver fails and native driver is available, try it
        if @driver.class.name.end_with?('CliDriver')
          begin
            @driver = Drivers::NativeDriver.new
            @driver.solve(self)
          rescue LoadError
            raise e
          end
        else
          raise e
        end
      end
    end

    # Creates a new empty LP/QP/MIP model.
    #
    # @param name [String] An optional name for this model, used for
    #   debugging and identification in logs. Defaults to 'untitled'.
    def initialize(name = nil)
      @name = name || 'untitled'
      @variables = {}       # { symbol => Variable }
      @constraints = {}     # { symbol => index }
      @var_counter = 0
      @constr_counter = 0
      @heading = :minimize
      @solution = nil
      @objective = {}       # { var_index => coefficient }
      @quadratic_terms = [] # [[var1_idx, var2_idx, coefficient], ...]
      @var_types = {}       # { symbol => :continuous | :integer }
      @var_bounds = {}      # { symbol => [lb, ub] }
      @constraints_data = {} # { symbol => { lb:, ub:, expr: [[var_idx, coeff], ...] } }
      @driver = self.class.default_driver
    end

    # Adds a variable to the model.
    #
    # @param name [Symbol, String] The variable name.
    # @param lb [Float] Lower bound (default: 0.0).
    # @param ub [Float] Upper bound (default: +Inf).
    # @param integer [Boolean] Whether the variable is integer (default: false).
    # @return [Variable] The variable object.
    def add_variable(name, lb: 0.0, ub: Float::INFINITY, integer: false)
      name = name.to_sym
      idx = @var_counter
      var = Variable.new(idx, name)
      @variables[name] = var
      @var_types[name] = integer ? :integer : :continuous
      @var_bounds[name] = [normalize_bound(lb), normalize_bound(ub)]
      @var_counter += 1
      var
    end

    # Adds a constraint to the model.
    #
    # @param name [Symbol, String] The constraint name.
    # @param expr [ConstraintSpec, Array<[Integer, Float]>] The constraint
    #   specification (DSL expression or legacy array format).
    # @param lb [Float] Lower bound (default: -Inf).
    # @param ub [Float] Upper bound (default: +Inf).
    # @return [Symbol] The constraint name.
    def add_constraint(name, expr, lb: -Float::INFINITY, ub: Float::INFINITY)
      name = name.to_sym

      if expr.is_a?(ConstraintSpec)
        lb_val, ub_val = expr.bounds
        data_expr = expr.expr
      else
        lb_val = lb
        ub_val = ub
        data_expr = expr
      end

      idx = @constr_counter
      @constraints[name] = idx
      @constraints_data[name] = {
        lb: normalize_bound(lb_val),
        ub: normalize_bound(ub_val),
        expr: data_expr
      }
      @constr_counter += 1
      name
    end

    # Sets heading to minimize, sets the objective, and solves.
    #
    # @param objective [LinearExpression, QuadraticExpression, Hash{Integer => Float}] The objective.
    # @return [Solution] The solution object.
    # @raise [SolverError] If the solver encounters an error.
    def minimize!(objective)
      @heading = :minimize
      set_objective_internal(objective)
      solve
    end

    # Sets heading to maximize, sets the objective, and solves.
    #
    # @param objective [LinearExpression, QuadraticExpression, Hash{Integer => Float}] The objective.
    # @return [Solution] The solution object.
    # @raise [SolverError] If the solver encounters an error.
    def maximize!(objective)
      @heading = :maximize
      set_objective_internal(objective)
      solve
    end

    private

    # Sets the objective function internally.
    #
    # @param objective [LinearExpression, QuadraticExpression, Hash{Integer => Float}] The objective.
    def set_objective_internal(objective)
      if objective.is_a?(QuadraticExpression)
        @objective = objective.linear_terms.transform_values(&:to_f)
        @quadratic_terms = objective.hessian_entries
      elsif objective.is_a?(LinearExpression)
        @objective = objective.terms.transform_values(&:to_f)
        @quadratic_terms = []
      else
        @objective = objective.transform_values { |v| v.is_a?(Variable) ? 1.0 : v.to_f }
        @quadratic_terms = []
      end
    end

    public

    # Converts the model to HiGHS LP format string.
    #
    # Delegates to LpGenerator for serialization.
    #
    # @return [String] The LP format content.
    # @example
    #   puts model.to_lp
    #   # Minimize
    #   #  obj: 3 x + 5 y
    #   # Subject To
    #   #  budget: 2 x + 1 y <= 100
    #   #  demand: 1 x + 2 y >= 50
    #   # Bounds
    #   #  0 <= x <= +Inf
    #   #  0 <= y <= +Inf
    #   # End
    def to_lp
      LpGenerator.new(self).generate
    end

    # Writes the model to an LP file.
    #
    # @param filename [String] The output file path.
    # @return [void]
    # @example
    #   model.write_lp('my_model.lp')
    def write_lp(filename)
      File.write(filename, to_lp)
    end

    # Sets the solver driver.
    #
    # @param driver [Drivers::CliDriver, Drivers::NativeDriver] The driver to use for solving.
    def driver=(driver)
      @driver = driver
    end

    private

    # Normalizes bound values for internal storage.
    #
    # Converts special infinity values to their canonical forms.
    #
    # @param val [Float] The bound value to normalize.
    # @return [Float] The normalized bound value.
    def normalize_bound(val)
      return -Float::INFINITY if val == -Float::INFINITY || val == -1.0 / 0.0
      return Float::INFINITY if val == Float::INFINITY || val == 1.0 / 0.0
      val.to_f
    end
  end
end
