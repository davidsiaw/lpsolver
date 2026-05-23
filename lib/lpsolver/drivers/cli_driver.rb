# frozen_string_literal: true

require 'tempfile'

module LpSolver
  module Drivers
    # Solves a model using the HiGHS command-line interface.
    #
    # This driver serializes the model to HiGHS LP format, invokes the
    # HiGHS executable as a subprocess, and parses the solution file.
    #
    class CliDriver
      # The path to the HiGHS binary.
      #
      # Resolution order:
      #   1. Path passed to initialize
      #   2. HIGHS_PATH environment variable
      #   3. Bundled binary at lib/lpsolver/highs (from rake compile)
      #   4. 'highs' on system PATH
      #
      # @return [String] The path to the HiGHS executable.
      HIGHS_PATH = begin
        env_path = ENV.fetch('HIGHS_PATH', nil)
        if env_path
          env_path
        else
          bundled = File.expand_path('../../../lib/lpsolver/highs', __dir__)
          if File.exist?(bundled)
            bundled
          else
            'highs'
          end
        end
      end

      # Creates a new CLI driver.
      #
      # @param highs_path [String, nil] Path to the HiGHS binary.
      #   If nil, uses the default resolution order.
      def initialize(highs_path: nil)
        @highs_path = highs_path || HIGHS_PATH
      end

      # Solves the model using the HiGHS CLI.
      #
      # @param model [Model] The model to solve.
      # @return [Solution] The solution object.
      # @raise [SolverError] If the HiGHS solver encounters an error.
      def solve(model)
        lp_content = model.to_lp
        lp_file = Tempfile.new(['model', '.lp'])
        lp_file.write(lp_content)
        lp_file.close

        solution_file = Tempfile.new(['solution', '.sol'])
        opts_file = Tempfile.new(['highs_opts', '.txt'])
        opts_file.write("log_to_console = false\noutput_flag = false\n")
        opts_file.close

        cmd = "#{@highs_path} " \
              "--model_file #{lp_file.path} " \
              "--options_file #{opts_file.path} " \
              "--solution_file #{solution_file.path}"

        output = `#{cmd} 2>&1`
        lp_file.unlink
        opts_file.unlink

        # HiGHS returns non-zero exit code for infeasible/unbounded problems,
        # but still writes a valid solution file. Check for valid status instead.
        solution_content = File.read(solution_file.path)
        status_match = solution_content.match(/Model status\s*\n\s*(\S+)/i)
        unless status_match
          raise SolverError, "HiGHS solver failed:\n#{output}" unless $?.success?
        end

        parse_solution(solution_file.path)
      ensure
        solution_file&.unlink
        opts_file&.unlink
      end

      private

      # Parses the HiGHS solution file.
      #
      # @param path [String] The path to the HiGHS solution file.
      # @return [Solution] The parsed solution object.
      def parse_solution(path)
        content = File.read(path)
        variables = {}
        objective_value = 0.0
        model_status = 'unknown'

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
          iterations: 0
        )
      end
    end
  end
end
