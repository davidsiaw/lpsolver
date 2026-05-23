# frozen_string_literal: true

module LpSolver
  module Drivers
    # Solves a model using the native C extension.
    #
    # This driver builds HiGHS data structures directly from the model
    # and calls the native C API, bypassing LP file serialization.
    # It requires the native extension to be compiled and loaded.
    #
    class NativeDriver
      # Solves the model using the native C extension.
      #
      # @param model [Model] The model to solve.
      # @return [Solution] The solution object.
      # @raise [LoadError] If the native extension is not available.
      # @raise [SolverError] If the native solver encounters an error.
      def solve(model)
        unless defined?(LpSolver::HiGhSSolver)
          raise LoadError, 'Native extension not available. Compile with: rake compile'
        end

        num_col = model.var_counter
        num_row = model.constraints.size

        # Determine heading — native API always minimizes, so negate for maximize
        heading = model.heading == :maximize ? :maximize : :minimize

        # Build column arrays
        col_cost = Array.new(num_col, 0.0)
        col_lower = Array.new(num_col)
        col_upper = Array.new(num_col)
        col_integrality = Array.new(num_col, 0)

        model.var_bounds.each do |name, (lb, ub)|
          idx = model.variables[name].index
          col_lower[idx] = lb
          col_upper[idx] = ub
          col_integrality[idx] = model.var_types[name] == :integer ? 1 : 0
        end

        model.objective.each do |idx, coeff|
          col_cost[idx] = heading == :maximize ? -coeff.to_f : coeff.to_f
        end

        # Build constraint arrays
        row_lower = Array.new(num_row)
        row_upper = Array.new(num_row)

        model.constraints.each_with_index do |constr, row_idx|
          row_lower[row_idx] = constr[:lb]
          row_upper[row_idx] = constr[:ub]
        end

        # Build matrix in CSC (column-wise) format
        # a_start[col] = index into a_index/a_value where column `col` starts
        # a_index[nz] = row index of non-zero element
        # a_value[nz] = value of non-zero element
        nz_per_col = Array.new(num_col, 0)
        nz_entries = []

        model.constraints.each_with_index do |constr, row_idx|
          constr[:expr].each do |col_idx, coeff|
            nz_entries << [col_idx, row_idx, coeff.to_f]
            nz_per_col[col_idx] += 1
          end
        end

        total_nz = nz_entries.size

        # Build a_start (cumulative column starts)
        a_start = [0]
        nz_per_col.each { |count| a_start << a_start.last + count }

        # Sort entries by column index for CSC format
        nz_entries.sort_by! { |col, row, _| col }

        aindex = nz_entries.map { |_, row, _| row }
        avalues = nz_entries.map { |_, _, val| val }

        # Call native solver (skip if no columns/rows)
        if num_col > 0 && num_row > 0
          result = call_native(
            num_col, num_row, total_nz,
            col_cost, col_lower, col_upper, col_integrality,
            row_lower, row_upper,
            a_start, aindex, avalues
          )
        else
          result = { status: :unbounded, objective: 0.0, col_value: [] }
        end

        # Parse result — variables are empty for infeasible/unbounded
        variables = {}
        unless [:infeasible, :unbounded, :unbounded_or_infeasible].include?(result[:status])
          result[:col_value].each_with_index do |val, idx|
            var_name = model.variables.find { |_, v| v.index == idx }&.first
            variables[var_name.to_s] = val if var_name
          end
        end

        Solution.new(
          variables: variables,
          objective_value: heading == :maximize ? -result[:objective] : result[:objective],
          model_status: result[:status].to_s,
          iterations: 0
        )
      end

      private

      # Calls the native HiGHS solver.
      #
      # @param num_col [Integer] Number of columns.
      # @param num_row [Integer] Number of rows.
      # @param num_nz [Integer] Number of non-zero elements.
      # @param col_cost [Array<Float>] Column cost coefficients.
      # @param col_lower [Array<Float>] Column lower bounds.
      # @param col_upper [Array<Float>] Column upper bounds.
      # @param col_integrality [Array<Integer>] Column integrality flags.
      # @param row_lower [Array<Float>] Row lower bounds.
      # @param row_upper [Array<Float>] Row upper bounds.
      # @param a_start [Array<Integer>] Matrix column start indices (CSC format).
      # @param aindex [Array<Integer>] Matrix row indices.
      # @param avalues [Array<Float>] Matrix values.
      # @return [Hash] Solver result with :status, :objective, :col_value, etc.
      def call_native(num_col, num_row, num_nz, col_cost, col_lower, col_upper, col_integrality,
                      row_lower, row_upper, a_start, aindex, avalues)
        solver = LpSolver::HiGhSSolver.new
        solver.num_col = num_col
        solver.num_row = num_row
        solver.num_nz = num_nz

        solver.col_cost   = col_cost
        solver.col_lower  = col_lower
        solver.col_upper  = col_upper
        solver.col_integrality = col_integrality

        solver.row_lower = row_lower
        solver.row_upper = row_upper

        solver.a_start = a_start
        solver.a_index = aindex
        solver.a_value = avalues

        solver.solve
      end
    end
  end
end
