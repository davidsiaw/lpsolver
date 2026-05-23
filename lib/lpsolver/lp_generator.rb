# frozen_string_literal: true

module LpSolver
  # Generates HiGHS LP format strings from a model's data.
  #
  # This class handles all serialization logic for converting a model's
  # variables, constraints, objectives, and bounds into the HiGHS LP format.
  # It is used by both the CLI and native drivers.
  #
  # @example Basic usage
  #   generator = LpSolver::LpGenerator.new(model)
  #   puts generator.generate
  class LpGenerator
    # Creates a new LP generator for the given model.
    #
    # @param model [Model] The model to serialize.
    def initialize(model)
      @model = model
    end

    # Generates the HiGHS LP format string.
    #
    # @return [String] The LP format content.
    # @example
    #   puts generator.generate
    #   # Minimize
    #   #  obj: 3 x + 5 y
    #   # Subject To
    #   #  budget: 2 x + 1 y <= 100
    #   #  demand: 1 x + 2 y >= 50
    #   # Bounds
    #   #  0 <= x <= +Inf
    #   #  0 <= y <= +Inf
    #   # End
    def generate
      lines = []
      lines << (@model.heading == :minimize ? 'Minimize' : 'Maximize')
      lines << generate_objective
      lines.concat(generate_constraints) if @model.constraints.any?
      lines.concat(generate_bounds) if @model.var_bounds.any?
      lines.concat(generate_integers) if has_integer_variables?
      lines << 'End'
      lines.join("\n")
    end

    private

    # Generates the objective line.
    #
    # @return [String] The objective line (e.g., " obj: 3 x + 5 y").
    def generate_objective
      obj_terms = @model.objective.map do |var_idx, coeff|
        var_name = find_var_name(var_idx)
        "#{format_coeff(coeff)} #{sanitize_name(var_name)}"
      end.join(' + ')

      if @model.quadratic_terms.any?
        quad_parts = @model.quadratic_terms.map do |i1, i2, coeff|
          n1 = sanitize_name(find_var_name(i1))
          n2 = sanitize_name(find_var_name(i2))
          if i1 == i2
            "#{format_coeff(coeff)} #{n1} ^ 2"
          else
            "#{format_coeff(coeff)} #{n1} * #{n2}"
          end
        end.join(' + ')
        " obj: #{obj_terms} + [ #{quad_parts} ] / 2"
      else
        " obj: #{obj_terms}"
      end
    end

    # Generates the constraints section.
    #
    # @return [Array<String>] Array of constraint lines.
    def generate_constraints
      lines = ['Subject To']
      @model.constraints_data.each do |name, data|
        terms = data[:expr].map do |var_idx, coeff|
          var_name = find_var_name(var_idx)
          "#{format_coeff(coeff)} #{sanitize_name(var_name)}"
        end.join(' + ')

        lines << format_constraint(name, terms, data[:lb], data[:ub])
      end
      lines
    end

    # Formats a single constraint line.
    #
    # @param name [Symbol] The constraint name.
    # @param terms [String] The constraint terms (e.g., "2 x + 1 y").
    # @param lb [Float] Lower bound.
    # @param ub [Float] Upper bound.
    # @return [String] The formatted constraint line.
    def format_constraint(name, terms, lb, ub)
      sname = sanitize_name(name)
      if lb == -Float::INFINITY && ub == Float::INFINITY
        " #{sname}: #{terms} free"
      elsif lb == -Float::INFINITY
        " #{sname}: #{terms} <= #{format_bound(ub)}"
      elsif ub == Float::INFINITY
        " #{sname}: #{terms} >= #{format_bound(lb)}"
      elsif (ub - lb).abs < 1e-12
        " #{sname}: #{terms} = #{format_bound(lb)}"
      else
        " #{sname}: #{terms} >= #{format_bound(lb)}\n #{sname}_ub: #{terms} <= #{format_bound(ub)}"
      end
    end

    # Generates the bounds section.
    #
    # @return [Array<String>] Array of bound lines.
    def generate_bounds
      lines = ['Bounds']
      @model.variables.each do |name, _var|
        lb, ub = @model.var_bounds[name]
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
      lines
    end

    # Generates the integer variables section.
    #
    # @return [Array<String>] Array of integer declaration lines.
    def generate_integers
      int_vars = @model.variables.select { |sym, _| @model.var_types[sym] == :integer }
      return [] unless int_vars.any?

      lines = ['Integers']
      int_vars.each { |name, _| lines << " #{sanitize_name(name)}" }
      lines
    end

    # Looks up a variable name by its internal index.
    #
    # @param idx [Integer] The internal variable index.
    # @return [String] The variable name, or "v#{idx}" if not found.
    def find_var_name(idx)
      @model.variables.find { |_, var| var.index == idx }&.first || "v#{idx}"
    end

    # Checks if the model has any integer variables.
    #
    # @return [Boolean] True if any variable has :integer type.
    def has_integer_variables?
      @model.var_types.values.any? { |t| t == :integer }
    end

    # Normalizes bound values for LP format output.
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
  end
end
