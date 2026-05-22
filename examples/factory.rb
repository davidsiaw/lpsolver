# frozen_string_literal: true

# Factory Production Planning Problem
# A factory produces 3 products. Each product uses different amounts of
# raw materials and labor, and generates different profit.

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'lpsolver'

# Product data: [profit_per_unit, labor_hours, steel_kg, aluminum_kg]
PRODUCTS = {
  widget: { profit: 25, labor: 2.0, steel: 1.5, aluminum: 0.5 },
  gadget: { profit: 40, labor: 3.0, steel: 1.0, aluminum: 2.0 },
  doohickey: { profit: 30, labor: 1.5, steel: 2.0, aluminum: 1.5 }
}.freeze

# Available resources
MAX_LABOR = 300    # hours
MAX_STEEL = 200    # kg
MAX_ALUMINUM = 150 # kg

model = LpSolver::Model.new('factory')

# Decision variables: how many units of each product to produce
widget = model.add_variable(:widget, lb: 0)
gadget = model.add_variable(:gadget, lb: 0)
doohickey = model.add_variable(:doohickey, lb: 0)

# Resource constraints
model.add_constraint(:labor, ((widget * PRODUCTS[:widget][:labor]) +
                               (gadget * PRODUCTS[:gadget][:labor]) +
                               (doohickey * PRODUCTS[:doohickey][:labor])) <= MAX_LABOR)

model.add_constraint(:steel, ((widget * PRODUCTS[:widget][:steel]) +
                                (gadget * PRODUCTS[:gadget][:steel]) +
                                (doohickey * PRODUCTS[:doohickey][:steel])) <= MAX_STEEL)

model.add_constraint(:aluminum, ((widget * PRODUCTS[:widget][:aluminum]) +
                                   (gadget * PRODUCTS[:gadget][:aluminum]) +
                                   (doohickey * PRODUCTS[:doohickey][:aluminum])) <= MAX_ALUMINUM)

# Objective: maximize profit
solution = model.maximize!((widget * PRODUCTS[:widget][:profit]) +
                          (gadget * PRODUCTS[:gadget][:profit]) +
                          (doohickey * PRODUCTS[:doohickey][:profit]))

if solution.infeasible?
  puts 'ERROR: No feasible production plan found!'
  exit 1
end

puts "\n=== Optimal Production Plan ==="
puts "Max profit: $%.2f\n" % solution.objective_value
puts 'Products to produce:'
%i[widget gadget doohickey].each do |prod|
  qty = solution[prod]
  next unless qty > 0.001

  data = PRODUCTS[prod]
  puts format('  %-12s: %6.1f units  (profit: $%.2f/unit)', prod.to_s.capitalize, qty, data[:profit])
end
puts ''

# Resource usage
puts 'Resource usage:'
puts format('  Labor:   %.1f / %d hours', (solution[:widget] * PRODUCTS[:widget][:labor]) +
  (solution[:gadget] * PRODUCTS[:gadget][:labor]) +
  (solution[:doohickey] * PRODUCTS[:doohickey][:labor]), MAX_LABOR)
puts format('  Steel:   %.1f / %d kg', (solution[:widget] * PRODUCTS[:widget][:steel]) +
  (solution[:gadget] * PRODUCTS[:gadget][:steel]) +
  (solution[:doohickey] * PRODUCTS[:doohickey][:steel]), MAX_STEEL)
puts format('  Aluminum: %.1f / %d kg', (solution[:widget] * PRODUCTS[:widget][:aluminum]) +
  (solution[:gadget] * PRODUCTS[:gadget][:aluminum]) +
  (solution[:doohickey] * PRODUCTS[:doohickey][:aluminum]), MAX_ALUMINUM)
puts '================================'
