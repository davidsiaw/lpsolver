# frozen_string_literal: true

# Portfolio Optimization (Markowitz Mean-Variance)
# Minimize portfolio variance subject to a target return.

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'lpsolver'

# Expected returns (annualized)
RETURNS = { tech: 0.15, bonds: 0.05, gold: 0.08, real_estate: 0.12 }.freeze

# Covariance matrix (simplified)
COVARIANCE = {
  tech: { tech: 0.0400, bonds: 0.0010, gold: -0.0020, real_estate: 0.0030 },
  bonds: { tech: 0.0010, bonds: 0.0025, gold: 0.0015, real_estate: 0.0020 },
  gold: { tech: -0.0020, bonds: 0.0015, gold: 0.0100, real_estate: 0.0010 },
  real_estate: { tech: 0.0030, bonds: 0.0020, gold: 0.0010, real_estate: 0.0064 }
}.freeze

TARGET_RETURN = 0.10 # 10% target return

model = LpSolver::Model.new('portfolio')

# Decision variables: portfolio weights
tech = model.add_variable(:tech, lb: 0)
bonds = model.add_variable(:bonds, lb: 0)
gold = model.add_variable(:gold, lb: 0)
real_estate = model.add_variable(:real_estate, lb: 0)

# Constraint: weights sum to 1
model.add_constraint(:sum, (tech + bonds + gold + real_estate) == 1)

# Constraint: target return
model.add_constraint(:return,
                     ((tech * RETURNS[:tech]) + (bonds * RETURNS[:bonds]) +
                      (gold * RETURNS[:gold]) + (real_estate * RETURNS[:real_estate])) >= TARGET_RETURN)

# Objective: minimize portfolio variance
# x^T * Σ * x — manually build each term from the covariance matrix
quad = tech * tech * COVARIANCE[:tech][:tech]
quad += (bonds * bonds * COVARIANCE[:bonds][:bonds])
quad += (gold * gold * COVARIANCE[:gold][:gold])
quad += (real_estate * real_estate * COVARIANCE[:real_estate][:real_estate])

# Off-diagonal terms (each pair appears once in the quadratic form)
quad += ((tech * bonds) * 2 * COVARIANCE[:tech][:bonds])
quad += ((tech * gold) * 2 * COVARIANCE[:tech][:gold])
quad += ((tech * real_estate) * 2 * COVARIANCE[:tech][:real_estate])
quad += ((bonds * gold) * 2 * COVARIANCE[:bonds][:gold])
quad += ((bonds * real_estate) * 2 * COVARIANCE[:bonds][:real_estate])
quad += ((gold * real_estate) * 2 * COVARIANCE[:gold][:real_estate])

solution = model.minimize!(quad)

if solution.infeasible?
  puts 'ERROR: No feasible portfolio found for target return!'
  exit 1
end

puts 'Solving portfolio optimization...'
puts "Target return: #{(TARGET_RETURN * 100).round(1)}%\n"

puts "\n=== Optimal Portfolio ==="
puts 'Variance:  %.6f' % solution.objective_value
puts format('Std dev:   %.4f%%', Math.sqrt(solution.objective_value) * 100)
actual_return = (solution[:tech] * RETURNS[:tech]) + (solution[:bonds] * RETURNS[:bonds]) +
                (solution[:gold] * RETURNS[:gold]) + (solution[:real_estate] * RETURNS[:real_estate])
puts "Actual return: #{actual_return.round(10)}"
puts "\nAllocation:"
%i[tech bonds gold real_estate].each do |asset|
  weight = solution[asset]
  if weight > 0.001
    puts format('  %-14s: %.1f%%  (return: %.1f%%)', asset.to_s.capitalize, weight * 100, RETURNS[asset] * 100)
  end
end
puts ''

# Show LP format
puts '=== LP Format ==='
puts model.to_lp
