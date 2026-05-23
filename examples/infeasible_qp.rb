# frozen_string_literal: true

# Infeasible QP Example
# A quadratic problem where the constraints contradict each other.
#
# Problem: Minimize x^2 + y^2 subject to:
#   x + y <= 1
#   x + y >= 4
# These constraints can never both be satisfied.

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'lpsolver'

model = LpSolver::Model.new('infeasible_qp')

x = model.add_variable(:x, lb: 0)
y = model.add_variable(:y, lb: 0)

# Contradictory linear constraints
model.add_constraint(:upper_bound, (x + y) <= 1)
model.add_constraint(:lower_bound, (x + y) >= 4)

# Quadratic objective: minimize distance from origin
solution = model.minimize!(x * x + y * y)

if solution.infeasible?
  puts "=== Infeasible QP Problem ==="
  puts "No solution exists that satisfies all constraints."
  puts "The constraints 'x + y <= 1' and 'x + y >= 4' are contradictory."
  puts "Status: #{solution.status}"
else
  puts "ERROR: Expected infeasible but got status: #{solution.status}"
  exit 1
end
