# frozen_string_literal: true

# Unbounded LP Example
# A maximization problem with no upper bound on the objective.
#
# Problem: Maximize x + y with only x >= 0, y >= 0 and no upper bounds.
# The objective can grow infinitely.

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'lpsolver'

model = LpSolver::Model.new('unbounded')

x = model.add_variable(:x, lb: 0)
y = model.add_variable(:y, lb: 0)

# No constraint limiting x or y — the objective can grow infinitely

solution = model.maximize!(x + y)

if solution.unbounded?
  puts "=== Unbounded Problem ==="
  puts "The objective can increase without limit."
  puts "No upper bound exists on x or y."
  puts "Status: #{solution.status}"
else
  puts "ERROR: Expected unbounded but got status: #{solution.status}"
  exit 1
end
