# LpSolver

A Ruby gem for solving optimization problems using the [HiGHS](https://github.com/ERGO-Code/HiGHS) solver.

## What is this for?

Imagine you want to **maximize profit** or **minimize cost** while following certain rules (like a budget limit or a minimum requirement). This gem helps you find the best answer.

You describe your problem in simple math, and the solver finds the optimal solution.

### Real-world examples

- **Coin change**: You need exactly $9.99 in coins. Which combination uses the least weight?
- **Diet plan**: You need 2000 calories, 50g protein, and 100g carbs per day. What combination of foods costs the least?
- **Factory**: You have limited materials and labor. How many of each product should you make to maximize profit?
- **Investment**: You want to split money across stocks, bonds, and gold. How do you minimize risk while earning a target return?

## Linear Programming (LP)

**LP** is for problems where everything scales in a straight line. If making one widget earns $5, making two earns $10. There are no "bulk discounts" or "diminishing returns" — just simple multiplication.

**Use LP when:**
- Your goal is a simple sum: `total_cost = price_a * qty_a + price_b * qty_b`
- Your rules are simple: `total_cost <= budget`, `qty_a + qty_b >= 100`

### LP Example: Diet Problem

```ruby
require 'lpsolver'

model = LpSolver::Model.new

bread = model.add_variable(:bread, lb: 0)   # how many slices
milk = model.add_variable(:milk, lb: 0)      # how many liters

# Rules first
model.add_constraint(:calories, (bread * 80 + milk * 60) >= 2000)
model.add_constraint(:protein, (bread * 3 + milk * 3.2) >= 50)

# Then solve
solution = model.minimize!(bread * 0.50 + milk * 1.20)

puts solution.objective_value  # minimum cost
```

## Quadratic Programming (QP)

**QP** is like LP, but your goal can involve multiplying variables together. This is useful when the "cost" or "risk" depends on how things interact, not just their individual values.

The most common use: **minimizing variance** (risk) in a portfolio. If Stock A and Stock B tend to move together, the combined risk isn't just the sum of their individual risks — it also depends on how they correlate.

**Use QP when:**
- Your goal involves squares or products: `risk = x² + y² + 2xy`
- You need to minimize deviation: `(actual - target)²`

### QP Example: Portfolio Optimization

```ruby
require 'lpsolver'

model = LpSolver::Model.new

tech = model.add_variable(:tech, lb: 0)
bonds = model.add_variable(:bonds, lb: 0)
gold = model.add_variable(:gold, lb: 0)

# Rules first
model.add_constraint(:all_money, (tech + bonds + gold) == 1)
model.add_constraint(:target_return, (tech * 0.15 + bonds * 0.05 + gold * 0.08) >= 0.10)

# Then solve — minimize portfolio variance (risk)
solution = model.minimize!(
  tech * tech * 0.04 +       # tech variance
  bonds * bonds * 0.0025 +   # bonds variance
  gold * gold * 0.01 +       # gold variance
  (tech * bonds) * 0.002 +   # tech-bonds interaction
  (tech * gold) * (-0.004)   # tech-gold interaction (negative = they move apart)
)

puts "Std dev: #{(Math.sqrt(solution.objective_value) * 100).round(2)}%"
```

## LP vs QP: Quick Comparison

| | LP | QP |
|---|---|---|
| **Goal** | Simple sum: `2x + 3y` | Includes products: `x² + 2xy + y²` |
| **Best for** | Cost, profit, weight, time | Risk, variance, error, deviation |
| **Speed** | Very fast | Fast |
| **Example** | "Minimize shipping cost" | "Minimize investment risk" |

## Installation

Add to your Gemfile:

```ruby
gem 'lpsolver'
```

Then:

```bash
bundle install
```

Or run directly from source:

```bash
ruby -Ilib examples/coin_purse.rb
```

> **HiGHS is bundled automatically.** The `rake compile` task (run during `bundle install` or `rake`) downloads the HiGHS v1.14.0 precompiled static library from GitHub and links it into the gem. No system-level HiGHS installation is required — it ships with the gem.

## Usage

### Simple Example (Operator DSL)

The recommended approach uses Ruby operators for natural, readable code. Build the model first, then call `minimize!` or `maximize!` at the end — it sets the objective, picks the direction, and solves in one call:

```ruby
require 'lpsolver'

model = LpSolver::Model.new

# 1. Add variables
x = model.add_variable(:x, lb: 0)
y = model.add_variable(:y, lb: 0)

# 2. Add constraints
model.add_constraint(:budget, (x * 2 + y) <= 100)
model.add_constraint(:demand, (x + y * 2) >= 50)

# 3. Solve
solution = model.minimize!(x * 3 + y * 5)

puts "Cost: $#{solution.objective_value}"
puts "x = #{solution[:x]}"
puts "y = #{solution[:y]}"

# Extract all variable values
puts solution.all_variables  # => { :x => 0.0, :y => 100.0 }
puts solution.to_h           # => { :x => 0.0, :y => 100.0 }

# Iterate over all variables
solution.each_variable { |name, value| puts "#{name} = #{value}" }

# Check if a variable exists
puts solution.has_variable?(:x)  # => true
puts solution.has_variable?(:z)  # => false

# Access by Variable object directly
puts solution[x]  # => 0.0
puts solution[y]  # => 100.0

# Get values for multiple variables
puts solution.values_at(:x, :y)      # => [0.0, 100.0]
puts solution.values_at(x, y)        # => [0.0, 100.0]

# List all variables defined in the model
model.variables.each { |name, var| puts "#{name} => #{var}" }
```

### Integer (MIP) Example

Some problems require whole numbers only (you can't make half a car):

```ruby
model = LpSolver::Model.new

# integer: true means the value must be a whole number
car = model.add_variable(:car, lb: 0, integer: true)
bike = model.add_variable(:bike, lb: 0, integer: true)

model.add_constraint(:vehicles, (car + bike) >= 10)
model.add_constraint(:wheels, (car * 4 + bike * 2) >= 24)

solution = model.minimize!(car * 30 + bike * 5)  # minimize cost
puts solution
```

### Maximization

```ruby
model = LpSolver::Model.new
x = model.add_variable(:x, lb: 0)
y = model.add_variable(:y, lb: 0)

model.add_constraint(:c1, (x + y) <= 10)
solution = model.maximize!(x * 3 + y * 5)
puts solution.objective_value  # => 50.0
```

### Complex Expressions

You can chain operators with constants and unary minus:

```ruby
x = model.add_variable(:x, lb: 0)
y = model.add_variable(:y, lb: 0)

# Arithmetic
expr = x * 2 + y * 3           # LinearExpression
expr = x * 2 + y * 3 + 5       # add constant
expr = x * 2 - y * 3 - 5       # subtract
expr = -(x * 2 + y * 3)        # negate

# Constraints
model.add_constraint(:c, (x * 2 + y * 3 + 5) <= 100)
model.add_constraint(:c, (x * 2 + y * 3 + 5) >= 100)
model.add_constraint(:c, (x * 2 + y * 3 + 5) == 100)
```

### Export LP Format

```ruby
model = LpSolver::Model.new
x = model.add_variable(:x, lb: 0)
y = model.add_variable(:y, lb: 0)

model.add_constraint(:c1, (x * 2 + y) <= 10)
model.set_objective(x + y)

# Print the LP file format
puts model.to_lp

# Or write to a file
model.write_lp('model.lp')
```

## DSL Quick Reference

### Variable (from `model.add_variable`)

| Operator | Example | Result |
|----------|---------|--------|
| `*` | `x * 2` | Linear expression (2x) |
| `*` | `x * y` | Quadratic term (xy) |
| `+` | `x + y`, `x + 5` | Sum or constant offset |
| `-` | `x - y`, `x - 5` | Difference or negative constant |
| `-` | `-x` | Negated expression |
| `<=` | `x + y <= 10` | Upper bound constraint |
| `>=` | `x + y >= 5` | Lower bound constraint |
| `==` | `x + y == 10` | Exact equality constraint |

### LinearExpression (from arithmetic)

| Operator | Example | Result |
|----------|---------|--------|
| `*` | `expr * 2` | Scaled expression |
| `+` | `expr + y`, `expr + 5` | Combined expression |
| `-` | `expr - y`, `expr - 5` | Difference expression |
| `-` | `-expr` | Negated expression |
| `<=`, `>=`, `==` | `expr <= 10` | Constraint |

### QuadraticExpression (from `Variable * Variable`)

| Operator | Example | Result |
|----------|---------|--------|
| `*` | `quad * 2` | Scaled expression |
| `+` | `quad + expr`, `quad + 5` | Combined expression |
| `-` | `quad - expr`, `quad - 5` | Difference expression |
| `-` | `-quad` | Negated expression |

> **Note:** `Variable * Variable` creates a quadratic term. `Variable * Scalar` creates a linear term. To scale a quadratic term, use `(x * y) * 2` (not `2 * (x * y)`).

## API Reference

### `Model#add_variable(name, lb: 0, ub: Float::INFINITY, integer: false)`
Add a variable. Returns a `Variable` object.
- `name` — variable name (Symbol or String)
- `lb` — lower bound (default: 0)
- `ub` — upper bound (default: no limit)
- `integer` — set to `true` for whole-number-only variables

### `Model#add_constraint(name, expr, lb: -Float::INFINITY, ub: Float::INFINITY)`
Add a constraint. `expr` can be:
- A `ConstraintSpec` from comparison operators: `(x * 2 + y) <= 100`
- An array of `[variable_index, coefficient]` pairs (legacy format)

### `Model#minimize!(objective)`
Set the objective to minimize and solve in one call.

### `Model#maximize!(objective)`
Set the objective to maximize and solve in one call.

### `Model#minimize`
Set the optimization sense to minimization (legacy, use `minimize!` instead).

### `Model#maximize`
Set the optimization sense to maximization (legacy, use `maximize!` instead).

### `Model#set_objective(objective)`
Set the objective function without solving (legacy, use `minimize!`/`maximize!` instead).
- `objective` can be a `LinearExpression`, `QuadraticExpression`, or Hash.

### `Model#to_lp`
Returns the model as a HiGHS LP format string.

### `Model#write_lp(filename)`
Writes the model to an LP file.

### `Model#solve`
Solves the model without setting an objective (legacy).

### `Solution#[]`
Get a variable's value. Accepts Symbol, String, or Variable object.

```ruby
solution[:x]        # => 4.0 (by symbol)
solution['x']       # => 4.0 (by string)
solution[x]         # => 4.0 (by Variable object)
```

### `Solution#values_at(*names)`
Get multiple values. Accepts Symbol, String, or Variable objects.

```ruby
solution.values_at(:x, :y)      # => [4.0, 0.0]
solution.values_at(x, y)        # => [4.0, 0.0]
solution.values_at(:x, y, 'z')  # => [4.0, 0.0, 3.0]
```

### `Solution#all_variables`
Returns all variables as a Symbol-keyed Hash.

```ruby
solution.all_variables  # => { :x => 4.0, :y => 0.0 }
```

### `Solution#to_h`
Alias for `all_variables`. Returns a plain Hash.

### `Solution#each_variable { |name, value| ... }`
Iterate over all variables and their values.

```ruby
solution.each_variable { |name, value| puts "#{name} = #{value}" }
```

### `Solution#has_variable?(name)`
Check if a variable exists in the solution. Accepts Symbol, String, or Variable.

```ruby
solution.has_variable?(:x)  # => true
solution.has_variable?(:z)  # => false
```

### `Model#variables`
Returns all defined variables as a Hash mapping names to Variable objects.

```ruby
model.variables  # => { :x => @x(0), :y => @y(1) }
model.variables.each { |name, var| puts "#{name} => #{var}" }
```

### `Solution#objective_value`
The optimal (best) objective value.

### `Solution#feasible?`
True if a valid solution was found.

### `Solution#infeasible?`
True if no solution satisfies all constraints.

### `Solution#unbounded?`
True if the objective can improve without limit.

## Examples

- `examples/coin_purse.rb` — Minimize coin weight for exactly $9.99 (MIP)
- `examples/diet_problem.rb` — Minimize food cost while meeting nutrition (LP)
- `examples/factory.rb` — Maximize factory profit (LP)
- `examples/portfolio.rb` — Minimize investment risk (QP)

## Supported Problem Types

| Type | Goal | Constraints | Whole Numbers? |
|------|------|-------------|----------------|
| LP | Linear sum | Linear | No |
| QP | Quadratic (squares/products) | Linear | No |
| MIP | Linear | Linear | Yes |

## License

[MIT License](https://opensource.org/licenses/MIT)

## Code of Conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
