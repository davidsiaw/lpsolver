# frozen_string_literal: true

# Coin Purse Optimization Problem
# Find the minimum-weight combination of US coins that sums to exactly 999 cents.

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'lpsolver'

# Coin specifications (value in cents, weight in grams)
COINS = {
  penny: { value: 1.0, weight: 2.500 },
  nickel: { value: 5.0, weight: 5.000 },
  dime: { value: 10.0, weight: 2.268 },
  quarter: { value: 25.0, weight: 5.670 },
  half_dollar: { value: 50.0, weight: 11.340 },
  dollar: { value: 100.0, weight: 8.100 }
}.freeze

TARGET = 999.0
PENALTY = 1000.0

model = LpSolver::Model.new('coin_purse')

# Create integer variables for each coin type
coin_vars = {}
COINS.each_key do |coin|
  coin_vars[coin] = model.add_variable(coin, lb: 0, integer: true)
end

# Deviation variable (continuous, >= 0) to handle target approximation
deviation = model.add_variable(:deviation, lb: 0)

# Build value and weight expressions
value_expr = coin_vars.to_a.sum(LpSolver::LinearExpression.new) { |coin, var| var * COINS[coin][:value] }
weight_expr = coin_vars.to_a.sum(LpSolver::LinearExpression.new) { |coin, var| var * COINS[coin][:weight] }

# Constraint: value - deviation <= TARGET
model.add_constraint(:upper_deviation, (value_expr - deviation) <= TARGET)
# Constraint: value + deviation >= TARGET
model.add_constraint(:lower_deviation, (value_expr + deviation) >= TARGET)

# Objective: minimize weight + PENALTY * deviation
solution = model.minimize!(weight_expr + (deviation * PENALTY))

if solution.infeasible?
  puts 'ERROR: No feasible solution found!'
  exit 1
end

deviation_val = solution[:deviation]
total_value = COINS.keys.sum { |coin| solution[coin] * COINS[coin][:value] }

puts "\n=== Coin Purse Solution ==="
puts "Target: #{TARGET} cents"
puts "Optimal weight: #{solution.objective_value.round(3)}g"
puts "Deviation from target: #{deviation_val.round(6)} cents"
puts ''
puts 'Coin counts:'
sorted_coins = %i[dollar half_dollar quarter dime nickel penny]
sorted_coins.each do |coin|
  count = solution[coin].round
  value = count * COINS[coin][:value]
  puts "  #{coin.to_s.capitalize.ljust(14)}: #{count.to_s.rjust(3)} coins (#{value.round}¢)"
end
puts ''
total_coins = solution.values_at(*coin_vars.keys).sum.round
puts "Total: #{total_coins} coins = #{total_value.round}¢"
puts "Weight: #{solution.objective_value.round(3)}g"
puts '==========================='
