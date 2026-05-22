# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'README Examples' do
  # Verify every code example in the README actually runs and produces correct results.

  describe 'LP: Diet Problem (simple)' do
    it 'minimizes food cost with nutritional constraints' do
      model = LpSolver::Model.new

      bread = model.add_variable(:bread, lb: 0)
      milk = model.add_variable(:milk, lb: 0)

      # Rules first
      model.add_constraint(:calories, ((bread * 80) + (milk * 60)) >= 2000)
      model.add_constraint(:protein, ((bread * 3) + (milk * 3.2)) >= 50)

      # Then solve
      solution = model.minimize!((bread * 0.50) + (milk * 1.20))

      expect(solution.feasible?).to be true
      expect(solution.objective_value).to be > 0
      # Verify constraints are satisfied
      expect((solution[:bread] * 80) + (solution[:milk] * 60)).to be >= 1999.9
      expect((solution[:bread] * 3) + (solution[:milk] * 3.2)).to be >= 49.9
    end
  end

  describe 'LP: Simple Example' do
    it 'minimizes cost with budget and demand constraints' do
      model = LpSolver::Model.new

      # 1. Add variables
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)

      # 2. Add constraints
      model.add_constraint(:budget, ((x * 2) + y) <= 100)
      model.add_constraint(:demand, (x + (y * 2)) >= 50)

      # 3. Solve
      solution = model.minimize!((x * 3) + (y * 5))

      expect(solution.feasible?).to be true
      expect(solution.objective_value).to be > 0
      expect((solution[:x] * 2) + solution[:y]).to be <= 100.001
      expect(solution[:x] + (solution[:y] * 2)).to be >= 49.999
    end
  end

  describe 'LP: Maximization' do
    it 'maximizes profit with resource constraints' do
      model = LpSolver::Model.new
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)

      model.add_constraint(:c1, (x + y) <= 10)
      solution = model.maximize!((x * 3) + (y * 5))

      expect(solution.feasible?).to be true
      expect(solution.objective_value).to be_within(0.001).of(50.0)
      expect(solution[:x] + solution[:y]).to be_within(0.001).of(10.0)
    end
  end

  describe 'MIP: Integer Example' do
    it 'solves with whole-number constraints' do
      model = LpSolver::Model.new

      # integer: true means the value must be a whole number
      car = model.add_variable(:car, lb: 0, integer: true)
      bike = model.add_variable(:bike, lb: 0, integer: true)

      model.add_constraint(:vehicles, (car + bike) >= 10)
      model.add_constraint(:wheels, ((car * 4) + (bike * 2)) >= 24)

      solution = model.minimize!((car * 30) + (bike * 5)) # minimize cost

      expect(solution.feasible?).to be true
      # Both must be integers
      expect(solution[:car]).to be_within(0.001).of(solution[:car].round)
      expect(solution[:bike]).to be_within(0.001).of(solution[:bike].round)
      # Constraints satisfied
      expect(solution[:car] + solution[:bike]).to be >= 9.999
      expect((solution[:car] * 4) + (solution[:bike] * 2)).to be >= 23.999
    end
  end

  describe 'QP: Portfolio Optimization' do
    it 'minimizes portfolio variance with return constraint' do
      model = LpSolver::Model.new

      tech = model.add_variable(:tech, lb: 0)
      bonds = model.add_variable(:bonds, lb: 0)
      gold = model.add_variable(:gold, lb: 0)

      # Rules first
      model.add_constraint(:all_money, (tech + bonds + gold) == 1)
      model.add_constraint(:target_return, ((tech * 0.15) + (bonds * 0.05) + (gold * 0.08)) >= 0.10)

      # Then solve — minimize portfolio variance (risk)
      solution = model.minimize!(
        (tech * tech * 0.04) +       # tech variance
        (bonds * bonds * 0.0025) +   # bonds variance
        (gold * gold * 0.01) +       # gold variance
        ((tech * bonds) * 0.002) +   # tech-bonds interaction
        ((tech * gold) * -0.004) # tech-gold interaction (negative = they move apart)
      )

      expect(solution.feasible?).to be true
      expect(solution.objective_value).to be >= -0.001 # variance should be non-negative
      # Weights sum to 1
      expect(solution[:tech] + solution[:bonds] + solution[:gold]).to be_within(0.001).of(1.0)
      # Return meets target
      expect((solution[:tech] * 0.15) + (solution[:bonds] * 0.05) + (solution[:gold] * 0.08)).to be >= 0.0999
    end
  end

  describe 'Complex Expressions' do
    it 'handles chained arithmetic and constraints' do
      model = LpSolver::Model.new
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)

      # Build expressions

      # Use in constraints
      model.add_constraint(:c, ((x * 2) + (y * 3) + 5) <= 100)
      model.add_constraint(:c2, ((x * 2) + (y * 3) + 5) >= 10)
      model.add_constraint(:c3, ((x * 2) + (y * 3) + 5) == 50)

      solution = model.minimize!(x + y)

      expect(solution.feasible?).to be true
      # The == constraint should dominate
      expect((solution[:x] * 2) + (solution[:y] * 3) + 5).to be_within(0.001).of(50.0)
    end
  end

  describe 'Export LP Format' do
    it 'generates valid LP format string' do
      model = LpSolver::Model.new
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)

      model.add_constraint(:c1, ((x * 2) + y) <= 10)
      model.set_objective(x + y)

      lp = model.to_lp

      expect(lp).to include('Minimize')
      expect(lp).to include('obj:')
      expect(lp).to include('Subject To')
      expect(lp).to include('2 x + 1 y <= 10')
      expect(lp).to include('Bounds')
      expect(lp).to include('End')

      # Write to file and read back
      require 'tempfile'
      tmp = Tempfile.new(['test', '.lp'])
      model.write_lp(tmp.path)
      content = File.read(tmp.path)
      expect(content).to eq(lp)
      tmp.close
      tmp.unlink
    end
  end

  describe 'Legacy API (minimize + set_objective + solve)' do
    it 'still works for backwards compatibility' do
      model = LpSolver::Model.new
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)

      model.add_constraint(:c, (x + y) >= 4)
      model.minimize
      model.set_objective((x * 3) + (y * 5))

      solution = model.solve

      expect(solution.feasible?).to be true
      expect(solution.objective_value).to be_within(0.001).of(12.0)
    end

    it 'maximize with legacy API works' do
      model = LpSolver::Model.new
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)

      model.add_constraint(:c, (x + y) <= 10)
      model.maximize
      model.set_objective((x * 3) + (y * 5))

      solution = model.solve

      expect(solution.feasible?).to be true
      expect(solution.objective_value).to be_within(0.001).of(50.0)
    end
  end
end
