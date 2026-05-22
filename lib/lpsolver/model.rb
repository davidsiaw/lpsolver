# frozen_string_literal: true

require 'tempfile'

module LpSolver
  # A high-level interface to HiGHS for building and solving LP/QP/MIP models.
  #
  # The Model class provides a Ruby DSL for defining variables, constraints,
  # and objectives. Models are serialized to HiGHS LP format and solved via
  # the HiGHS command-line interface.
  #
  # == Problem Types Supported
  #
  # * **Linear Programming (LP)**: Linear objective with linear constraints.
  #   Example: maximize profit given resource constraints.
  #
  # * **Quadratic Programming (QP)**: Quadratic objective (convex) with
  #   linear constraints. Example: minimize portfolio variance for a target return.
  #
  # * **Mixed Integer Programming (MIP)**: LP or QP with some or all variables
  #   restricted to integer values. Example: coin change problem with integer counts.
  #
  # == Usage
  #
  # The DSL uses Ruby operators to build expressions naturally:
  #
  #   model = LpSolver::Model.new
  #   x = model.add_variable(:x, lb: 0)
  #   y = model.add_variable(:y, lb: 0)
  #
  #   # Constraints
  #   model.add_constraint(:budget, (x * 2 + y) <= 100)
  #   model.add_constraint(:demand, (x + y * 2) >= 50)
  #
  #   # Objective
  #   model.minimize
  #   model.set_objective(x * 3 + y * 5)
  #
  #   # Solve
  #   solution = model.solve
  #   puts solution[:x]  # => optimal value for x
  #
  # @example Linear Programming
  #   model = LpSolver::Model.new
  #   x = model.add_variable(:x, lb: 0)
  #   y = model.add_variable(:y, lb: 0)
  #   model.add_constraint(:c1, (x + y) >= 4)
  #   model.minimize
  #   model.set_objective(x * 3 + y * 5)
  #   solution = model.solve
  #   solution.objective_value  # => 12.0
  #
  # @example Quadratic Programming
  #   model = LpSolver::Model.new
  #   x = model.add_variable(:x, lb: 0)
  #   y = model.add_variable(:y, lb: 0)
  #   model.add_constraint(:c, (x + y) >= 2)
  #   model.minimize
  #   model.set_objective(x * x + y * y)
  #   solution = model.solve
  #   solution.objective_value  # => 2.0 (at x=1, y=1)
  #
  # @example Mixed Integer Programming
  #   model = LpSolver::Model.new
  #   x = model.add_variable(:x, lb: 0, integer: true)
  #   y = model.add_variable(:y, lb: 0, integer: true)
  #   model.add_constraint(:c, (x + y) == 10)
  #   model.minimize
  #   model.set_objective(x * 2 + y * 3)
  #   solution = model.solve
  #   solution[:x]  # => 10.0 (integer)
  class Model
    # The path to the HiGHS binary.
    #
    # Set via the HIGHS_PATH environment variable, or defaults to 'highs'
    # on the system PATH. This is used to invoke the HiGHS solver via
    # the command line.
    #
    # @return [String] The path to the HiGHS executable.
    HIGHS_PATH = ENV.fetch('HIGHS_PATH', 'highs')

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
      @sense = :minimize
      @solution = nil
      @objective = {}       # { var_index => coefficient }
      @quadratic_terms = [] # [[var1_idx, var2_idx, coefficient], ...]
      @var_types = {}       # { symbol => :continuous | :integer }
      @var_bounds = {}      # { symbol => [lb, ub] }
      @constraints_data = {} # { symbol => { lb:, ub:, expr: [[var_idx, coeff], ...] } }
    end

    # Adds a variable to the model.
    #
    # Variables represent the decision quantities to be determined by the
    # solver. Each variable is assigned a unique internal index and can be
    # used in expressions via arithmetic operators.
    #
    # @param name [Symbol, String] The name of the variable. This is used
    #   for identification in the LP format output and solution results.
    # @param lb [Float] The lower bound for the variable (default: 0.0).
    #   Use -Float::INFINITY for no lower bound.
    # @param ub [Float] The upper bound for the variable (default: Float::INFINITY).
    #   Use Float::INFINITY for no upper bound. Setting lb == ub fixes the variable.
    # @param integer [Boolean] Whether the variable must take integer values
    #   (default: false). When true, the model becomes a MIP problem.
    # @return [Variable] The variable object, which supports arithmetic and
    #   comparison operators for building expressions and constraints.
    # @example Adding a continuous variable
    #   x = model.add_variable(:x, lb: 0)
    # @example Adding an integer variable
    #   count = model.add_variable(:count, lb: 0, integer: true)
    # @example Adding a fixed variable
    #   capacity = model.add_variable(:capacity, lb: 100, ub: 100)
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
    # Constraints define the feasible region of the optimization problem.
    # They can be specified using the DSL (comparison operators) or the
    # legacy array format.
    #
    # @param name [Symbol, String] The name of the constraint.
    # @param expr [ConstraintSpec, Array<[Integer, Float]>] The constraint
    #   specification. Can be either:
    #   - A ConstraintSpec from comparison operators: (x * 2 + y) <= 100
    #   - An array of [var_index, coefficient] pairs with explicit bounds
    # @param lb [Float] Lower bound for the constraint (used with array-style expr).
    #   Default: -Float::INFINITY.
    # @param ub [Float] Upper bound for the constraint (used with array-style expr).
    #   Default: Float::INFINITY.
    # @return [Symbol] The constraint name.
    # @example Using DSL comparison operators
    #   model.add_constraint(:budget, (x * 2 + y) <= 100)
    #   model.add_constraint(:demand, (x + y * 2) >= 50)
    #   model.add_constraint(:balance, (x + y) == 10)
    # @example Using legacy array format
    #   model.add_constraint(:budget, [[x.index, 2], [y.index, 1]], ub: 100)
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

    # Sets the optimization sense to minimization.
    #
    # @return [void]
    # @see #maximize
    def minimize
      @sense = :minimize
    end

    # Sets the optimization sense to maximization.
    #
    # @return [void]
    # @see #minimize
    def maximize
      @sense = :maximize
    end

    # Sets the objective function for the model.
    #
    # The objective function defines what the solver should optimize.
    # It can be a linear expression (for LP), a quadratic expression
    # (for QP), or a hash of coefficients (legacy format).
    #
    # @param objective [LinearExpression, QuadraticExpression, Hash{Variable|Integer => Float}]
    #   The objective function. Can be:
    #   - A LinearExpression: `x * 3 + y * 5`
    #   - A QuadraticExpression: `x * x + y * y + (x * y) * 2`
    #   - A Hash mapping variable indices to coefficients: `{ x.index => 3.0, y.index => 5.0 }`
    # @return [void]
    # @example Linear objective
    #   model.set_objective(x * 3 + y * 5)
    # @example Quadratic objective (QP)
    #   model.set_objective(x * x + y * y)
    def set_objective(objective)
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

    # Solves the model and returns the solution.
    #
    # Serializes the model to HiGHS LP format, invokes the HiGHS solver,
    # and parses the solution file to return a Solution object.
    #
    # @return [Solution] The solution object containing variable values,
    #   objective value, and model status.
    # @raise [SolverError] If the HiGHS solver encounters an error.
    # @example
    #   solution = model.solve
    #   solution[:x]        # => optimal value for variable x
    #   solution.objective_value  # => optimal objective value
    #   solution.feasible?  # => true
    def solve
      lp_content = to_lp
      lp_file = Tempfile.new(['model', '.lp'])
      lp_file.write(lp_content)
      lp_file.close

      solution_file = Tempfile.new(['solution', '.sol'])
      opts_file = Tempfile.new(['highs_opts', '.txt'])
      opts_file.write("log_to_console = false\noutput_flag = false\n")
      opts_file.close

      cmd = "#{self.class::HIGHS_PATH} " \
            "--model_file #{lp_file.path} " \
            "--options_file #{opts_file.path} " \
            "--solution_file #{solution_file.path}"

      output = `#{cmd} 2>&1`
      status = $?.success?

      lp_file.unlink
      opts_file.unlink

      raise SolverError, "HiGHS solver failed:\n#{output}" unless status

      @solution = parse_solution_file(solution_file.path)
      solution_file.unlink
      @solution
    end

    # Sets the optimization sense to minimization, sets the objective,
    # and solves the model in a single call.
    #
    # This is a convenience method that combines #minimize, #set_objective,
    # and #solve into one step.
    #
    # @param objective [LinearExpression, QuadraticExpression, Hash{Variable|Integer => Float}]
    #   The objective function to minimize. Can be:
    #   - A LinearExpression: `x * 3 + y * 5`
    #   - A QuadraticExpression: `x * x + y * y + (x * y) * 2`
    #   - A Hash mapping variable indices to coefficients: `{ x.index => 3.0, y.index => 5.0 }`
    # @return [Solution] The solution object containing variable values,
    #   objective value, and model status.
    # @raise [SolverError] If the HiGHS solver encounters an error.
    # @example
    #   solution = model.minimize!(x * 3 + y * 5)
    #   puts solution.objective_value  # => optimal (minimum) value
    # @example Quadratic minimization (QP)
    #   solution = model.minimize!(x * x + y * y)
    def minimize!(objective)
      @sense = :minimize
      set_objective(objective)
      solve
    end

    # Sets the optimization sense to maximization, sets the objective,
    # and solves the model in a single call.
    #
    # This is a convenience method that combines #maximize, #set_objective,
    # and #solve into one step.
    #
    # @param objective [LinearExpression, QuadraticExpression, Hash{Variable|Integer => Float}]
    #   The objective function to maximize. Can be:
    #   - A LinearExpression: `x * 3 + y * 5`
    #   - A QuadraticExpression: `x * x + y * y + (x * y) * 2`
    #   - A Hash mapping variable indices to coefficients: `{ x.index => 3.0, y.index => 5.0 }`
    # @return [Solution] The solution object containing variable values,
    #   objective value, and model status.
    # @raise [SolverError] If the HiGHS solver encounters an error.
    # @example
    #   solution = model.maximize!(x * 3 + y * 5)
    #   puts solution.objective_value  # => optimal (maximum) value
    def maximize!(objective)
      @sense = :maximize
      set_objective(objective)
      solve
    end

    # Converts the model to HiGHS LP format string.
    #
    # The LP format is a text-based representation of the optimization
    # problem that HiGHS can read. It includes the objective function,
    # constraints, variable bounds, and integer declarations.
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
      lines = []

      # Objective
      lines << (@sense == :minimize ? 'Minimize' : 'Maximize')

      obj_terms = @objective.map do |var_idx, coeff|
        var_name = find_var_name(var_idx)
        "#{format_coeff(coeff)} #{sanitize_name(var_name)}"
      end.join(' + ')

      if @quadratic_terms.any?
        quad_parts = @quadratic_terms.map do |i1, i2, coeff|
          n1 = sanitize_name(find_var_name(i1))
          n2 = sanitize_name(find_var_name(i2))
          if i1 == i2
            "#{format_coeff(coeff)} #{n1} ^ 2"
          else
            "#{format_coeff(coeff)} #{n1} * #{n2}"
          end
        end.join(' + ')
        lines << " obj: #{obj_terms} + [ #{quad_parts} ] / 2"
      else
        lines << " obj: #{obj_terms}"
      end

      # Constraints
      if @constraints.any?
        lines << 'Subject To'
        @constraints.each do |name, _idx|
          data = @constraints_data[name]
          terms = data[:expr].map do |var_idx, coeff|
            var_name = find_var_name(var_idx)
            "#{format_coeff(coeff)} #{sanitize_name(var_name)}"
          end.join(' + ')

          if data[:lb] == -Float::INFINITY && data[:ub] == Float::INFINITY
            lines << " #{sanitize_name(name)}: #{terms} free"
          elsif data[:lb] == -Float::INFINITY
            lines << " #{sanitize_name(name)}: #{terms} <= #{format_bound(data[:ub])}"
          elsif data[:ub] == Float::INFINITY
            lines << " #{sanitize_name(name)}: #{terms} >= #{format_bound(data[:lb])}"
          elsif (data[:ub] - data[:lb]).abs < 1e-12
            lines << " #{sanitize_name(name)}: #{terms} = #{format_bound(data[:lb])}"
          else
            lines << " #{sanitize_name(name)}: #{terms} >= #{format_bound(data[:lb])}"
            lines << " #{sanitize_name(name)}_ub: #{terms} <= #{format_bound(data[:ub])}"
          end
        end
      end

      # Bounds
      if @var_bounds.any?
        lines << 'Bounds'
        @variables.each do |name, _var|
          lb, ub = @var_bounds[name]
          sname = sanitize_name(name)

          if lb == ub
            lines << " #{sname} = #{format_bound(lb)}"
          elsif lb > -Float::INFINITY && ub < Float::INFINITY
            lines << " #{lb} <= #{sname} <= #{format_bound(ub)}"
          elsif lb > -Float::INFINITY
            lines << " #{sname} >= #{format_bound(lb)}"
          elsif ub < Float::INFINITY
            lines << " #{sname} <= #{format_bound(ub)}"
          end
        end
      end

      # Integer variables
      int_vars = @variables.select { |sym, _| @var_types[sym] == :integer }
      if int_vars.any?
        lines << 'Integers'
        int_vars.each { |name, _| lines << " #{sanitize_name(name)}" }
      end

      lines << 'End'
      lines.join("\n")
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

    private

    # Looks up a variable name by its internal index.
    #
    # @param idx [Integer] The internal variable index.
    # @return [String] The variable name, or "v#{idx}" if not found.
    def find_var_name(idx)
      @variables.find { |_, var| var.index == idx }&.first || "v#{idx}"
    end

    # Normalizes bound values for LP format output.
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

    # Formats a coefficient for LP output.
    #
    # Integers are output without decimal points for readability.
    #
    # @param value [Float] The coefficient value.
    # @return [String] The formatted coefficient string.
    def format_coeff(value)
      if value == value.to_i && value.abs < 1e15
        value.to_i.to_s
      else
        format('%.6g', value)
      end
    end

    # Formats a bound value for LP output.
    #
    # @param value [Float] The bound value.
    # @return [String] The formatted bound string (+Inf, -Inf, or numeric).
    def format_bound(value)
      return '+Inf' if value == Float::INFINITY
      return '-Inf' if value == -Float::INFINITY

      format_coeff(value)
    end

    # Sanitizes a name for LP format (no spaces, special characters).
    #
    # @param name [String, Symbol] The name to sanitize.
    # @return [String] The sanitized name (max 32 characters).
    def sanitize_name(name)
      name.to_s.gsub(/[^a-zA-Z0-9_]/, '_')[0, 32]
    end

    # Parses the HiGHS solution file.
    #
    # Extracts variable values, objective value, and model status from
    # the solution file format produced by HiGHS.
    #
    # @param path [String] The path to the HiGHS solution file.
    # @return [Solution] The parsed solution object.
    def parse_solution_file(path)
      content = File.read(path)
      variables = {}
      objective_value = 0.0
      model_status = 'unknown'
      iterations = 0

      status_match = content.match(/Model status\s*\n\s*(\S+)/i)
      model_status = status_match[1].downcase.gsub('_', ' ') if status_match

      obj_match = content.match(/Objective\s+(\S+)/i)
      objective_value = obj_match[1].to_f if obj_match

      in_columns = false
      content.each_line do |line|
        if line =~ /# Columns/i
          in_columns = true
          next
        end
        next unless in_columns
        break if line.strip.empty? || line.start_with?('#')

        parts = line.strip.split(/\s+/, 2)
        variables[parts[0]] = parts[1].to_f if parts.length == 2
      end

      Solution.new(
        variables: variables,
        objective_value: objective_value,
        model_status: model_status,
        iterations: iterations
      )
    end
  end
end
