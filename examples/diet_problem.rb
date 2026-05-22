# frozen_string_literal: true

# Diet Problem (simplified)
# Minimize food cost while meeting minimum nutritional requirements.

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'lpsolver'

# Food data: [calories, protein_g, vitaminC_mg, cost_per_serving]
FOODS = {
  bread: { calories: 70, protein: 3.0, vitC: 0.0, cost: 0.50 },
  milk: { calories: 120, protein: 8.0,  vitC: 0.0,  cost: 1.20 },
  eggs: { calories: 70,  protein: 6.0,  vitC: 0.0,  cost: 0.75 },
  chicken: { calories: 140, protein: 20.0, vitC: 0.0, cost: 2.50 },
  apple: { calories: 95, protein: 0.5, vitC: 8.0, cost: 0.80 },
  orange: { calories: 62, protein: 1.2, vitC: 53.0, cost: 0.65 }
}.freeze

model = LpSolver::Model.new('diet')

# Create continuous variables (non-negative)
food_vars = FOODS.each_key.map do |food|
  [food, model.add_variable(food, lb: 0)]
end.to_h

# Minimum nutritional requirements
MIN_CALORIES = 1500
MIN_PROTEIN = 50.0
MIN_VITC = 60.0

# Build nutrition expressions
cal_expr = food_vars.map { |food, var| var * FOODS[food][:calories] }.reduce(:+)
protein_expr = food_vars.map { |food, var| var * FOODS[food][:protein] }.reduce(:+)
vitc_expr = food_vars.map { |food, var| var * FOODS[food][:vitC] }.reduce(:+)

# Constraints
model.add_constraint(:calories, cal_expr >= MIN_CALORIES)
model.add_constraint(:protein, protein_expr >= MIN_PROTEIN)
model.add_constraint(:vitc, vitc_expr >= MIN_VITC)

# Objective: minimize cost
cost_expr = food_vars.map { |food, var| var * FOODS[food][:cost] }.reduce(:+)
solution = model.minimize!(cost_expr)

if solution.infeasible?
  puts 'ERROR: No feasible diet found!'
  exit 1
end

puts "\n=== Diet Solution ==="
puts 'Minimum daily cost: $%.2f' % solution.objective_value
puts ''
puts 'Food plan:'
%i[bread milk eggs chicken apple orange].each do |food|
  qty = solution[food]
  next unless qty > 0.001

  data = FOODS[food]
  puts format("  %-10s: %.2f servings  (#{data[:calories]} cal, %.1fg protein, %.0fmg vitC, $%.2f)",
              food.to_s.capitalize, qty, data[:protein], data[:vitC], qty * data[:cost])
end
puts ''

# Verify constraints
total_cal = food_vars.sum(0.0) { |food, _var| solution[food] * FOODS[food][:calories] }
total_protein = food_vars.sum(0.0) { |food, _var| solution[food] * FOODS[food][:protein] }
total_vitc = food_vars.sum(0.0) { |food, _var| solution[food] * FOODS[food][:vitC] }

puts 'Nutrition totals:'
puts format('  Calories:  %.0f (min: %d)', total_cal, MIN_CALORIES)
puts format('  Protein:   %.1fg (min: %.1fg)', total_protein, MIN_PROTEIN)
puts format('  Vitamin C: %.0fmg (min: %.0fmg)', total_vitc, MIN_VITC)
puts '======================='
