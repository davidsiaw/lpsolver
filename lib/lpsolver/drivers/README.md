# LpSolver Drivers

Pluggable solving backends for `LpSolver::Model`.

## API Contract

Every driver must implement the following interface:

### `#initialize(opts = {})`

Optional constructor. Drivers may accept configuration options.

| Driver | Options |
|--------|---------|
| `CliDriver` | `highs_path: String` — path to HiGHS binary (uses `HIGHS_PATH` resolution if omitted) |
| `NativeDriver` | None |

### `#solve(model) → Solution`

Solves the given model and returns a `Solution` object.

**Parameters:**
- `model` (`LpSolver::Model`) — the model to solve

**Returns:**
- `LpSolver::Solution` — contains variable values, objective value, and model status

**Raises:**
- `LpSolver::SolverError` — if the solver encounters an error (e.g., HiGHS binary not found)
- `LoadError` — if required dependencies are missing (e.g., native extension not compiled)

## Model Data Access

Drivers read model state via the following `Model` accessors:

| Accessor | Type | Description |
|----------|------|-------------|
| `model.var_counter` | `Integer` | Number of variables |
| `model.heading` | `Symbol` | `:minimize` or `:maximize` |
| `model.constraints` | `Array<Hash>` | Constraint data: `{ name:, lb:, ub:, expr: [[col, coeff], ...] }` |
| `model.constraints_data` | `Hash` | Named constraint map |
| `model.var_types` | `Hash{Symbol => Symbol}` | Variable types: `:continuous` or `:integer` |
| `model.objective` | `Hash{Integer => Float}` | Objective coefficients by variable index |
| `model.quadratic_terms` | `Array<[Integer, Integer, Float]>` | Quadratic terms: `[col1, col2, coeff]` |
| `model.var_bounds` | `Hash{Symbol => [Float, Float]}` | Variable bounds: `[lb, ub]` |
| `model.variables` | `Hash{Symbol => Variable}` | Variable map (name → Variable object) |

## Writing a Custom Driver

To create a new driver:

```ruby
require 'lpsolver/drivers'

module LpSolver
  module Drivers
    class MyCustomDriver
      def initialize(**opts)
        # driver-specific setup
      end

      def solve(model)
        # 1. Read model state via model.var_counter, model.constraints, etc.
        # 2. Call your solver
        # 3. Return a LpSolver::Solution
        LpSolver::Solution.new(
          variables: { 'x' => 1.0, 'y' => 2.0 },
          objective_value: 12.0,
          model_status: 'optimal',
          iterations: 0
        )
      end
    end
  end
end
```

Then use it:

```ruby
model = LpSolver::Model.new
model.driver = LpSolver::Drivers::MyCustomDriver.new
solution = model.solve
```

## Available Drivers

| Driver | Description | Dependencies |
|--------|-------------|-------------|
| `CliDriver` | HiGHS subprocess via LP file | `highs` binary |
| `NativeDriver` | HiGHS C extension | Compiled native extension (`rake compile`) |
