# frozen_string_literal: true

# Infeasible LP Example
# A simple LP where the constraints contradict each other — no solution exists.
#
# Problem: Find x, y >= 0 such that:
#   x + y <= 2   (sum is at most 2)
#   x + y >= 5   (sum is at least 5)
# These constraints can never both be true.

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'lpsolver'

model = LpSolver::Model.new('infeasible')

x = model.add_variable(:x, lb: 0)
y = model.add_variable(:y, lb: 0)

# Contradictory constraints
model.add_constraint(:upper_bound, (x + y) <= 2)
model.add_constraint(:lower_bound, (x + y) >= 5)

solution = model.minimize!(x + y)

if solution.infeasible?
  puts "=== Infeasible Problem ==="
  puts "No solution exists that satisfies all constraints."
  puts "The constraints 'x + y <= 2' and 'x + y >= 5' are contradictory."
  puts "Status: #{solution.status}"
else
  puts "ERROR: Expected infeasible but got status: #{solution.status}"
  exit 1
end
