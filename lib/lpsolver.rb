# frozen_string_literal: true

# LpSolver - A Ruby gem for solving Linear Programming (LP), Quadratic
# Programming (QP), and Mixed Integer Programming (MIP) problems.
#
# This gem provides a Ruby DSL for building optimization models and
# interfaces with the HiGHS solver via its command-line interface.
#
# == Quick Start
#
#   require 'lpsolver'
#
#   model = LpSolver::Model.new
#   x = model.add_variable(:x, lb: 0)
#   y = model.add_variable(:y, lb: 0)
#
#   model.add_constraint(:budget, (x * 2 + y) <= 100)
#   model.minimize
#   model.set_objective(x * 3 + y * 5)
#
#   solution = model.solve
#   puts solution.objective_value  # => 12.0
#
# @see LpSolver::Model
# @see LpSolver::Variable
# @see LpSolver::Solution
module LpSolver
end

require_relative 'lpsolver/version'
require_relative 'lpsolver/exception'

# Core DSL classes (loaded in dependency order)
require_relative 'lpsolver/constraint_spec'
require_relative 'lpsolver/variable'
require_relative 'lpsolver/linear_expression'
require_relative 'lpsolver/quadratic_expression'

# Solvers and data classes
require_relative 'lpsolver/solution'
require_relative 'lpsolver/model'
