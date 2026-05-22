# frozen_string_literal: true

module LpSolver
  # The base exception class for all LpSolver errors.
  #
  # All LpSolver-specific exceptions inherit from this class.
  #
  # @example Rescuing LpSolver errors
  #   begin
  #     model.solve
  #   rescue LpSolver::Error => e
  #     puts "Solver error: #{e.message}"
  #   end
  class Error < StandardError; end

  # Raised when the HiGHS solver encounters an error.
  #
  # This exception is raised when the HiGHS command-line tool exits
  # with a non-zero status, indicating a problem with the model
  # (e.g., syntax error, infeasibility not handled, etc.).
  #
  # @example
  #   begin
  #     model.solve
  #   rescue LpSolver::SolverError => e
  #     puts "HiGHS error: #{e.message}"
  #     puts "Stderr: #{e.stderr}" if e.stderr
  #   end
  class SolverError < Error
    # @return [String, nil] The stderr output from the HiGHS solver.
    attr_reader :stderr

    # Creates a new SolverError.
    #
    # @param message [String] The error message.
    # @param stderr [String, nil] The stderr output from HiGHS.
    def initialize(message, stderr: nil)
      @stderr = stderr
      super(message)
    end
  end

  # Raised when the HiGHS binary cannot be found.
  #
  # This exception is raised when the HIGHS_PATH environment variable
  # is not set and 'highs' is not on the system PATH.
  #
  # @example
  #   begin
  #     model.solve
  #   rescue LpSolver::NotFoundError => e
  #     puts "HiGHS not found. Install it or set HIGHS_PATH."
  #   end
  class NotFoundError < Error; end
end
