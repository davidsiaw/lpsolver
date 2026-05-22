# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe LpSolver::Model do
  describe 'basic LP with operators' do
    it 'solves a simple minimization problem' do
      model = LpSolver::Model.new('simple_min')
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)

      model.add_constraint(:c1, (x + y) >= 4)
      model.minimize
      model.set_objective((x * 3) + (y * 5))

      solution = model.solve

      expect(solution.feasible?).to be true
      expect(solution[:x] + solution[:y]).to be_within(0.001).of(4.0)
      expect(solution[:x]).to be_within(0.001).of(4.0)
      expect(solution[:y]).to be_within(0.001).of(0.0)
      expect(solution.objective_value).to be_within(0.001).of(12.0)
    end

    it 'solves a simple maximization problem' do
      model = LpSolver::Model.new('simple_max')
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)

      model.add_constraint(:budget, (x + y) <= 10)
      model.add_constraint(:resource, ((x * 2) + y) <= 16)
      model.maximize
      model.set_objective((x * 3) + (y * 5))

      solution = model.solve

      expect(solution.feasible?).to be true
      expect(solution[:x]).to be_within(0.001).of(0.0)
      expect(solution[:y]).to be_within(0.001).of(10.0)
      expect(solution.objective_value).to be_within(0.001).of(50.0)
    end

    it 'handles equality constraints' do
      model = LpSolver::Model.new('equality_test')
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)

      model.add_constraint(:eq, (x + y) == 10)
      model.minimize
      model.set_objective((x * 2) + (y * 3))

      solution = model.solve

      expect(solution.feasible?).to be true
      expect(solution[:x] + solution[:y]).to be_within(0.001).of(10.0)
      expect(solution[:x]).to be_within(0.001).of(10.0)
      expect(solution[:y]).to be_within(0.001).of(0.0)
      expect(solution.objective_value).to be_within(0.001).of(20.0)
    end

    it 'handles constant offsets in constraints' do
      model = LpSolver::Model.new('constant_test')
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)

      # x * 2 + y * 3 + 5 >= 20  →  x * 2 + y * 3 >= 15
      model.add_constraint(:c, ((x * 2) + (y * 3) + 5) >= 20)
      model.minimize
      model.set_objective(x + y)

      solution = model.solve

      expect(solution.feasible?).to be true
      # At x=0, y=5: 2*0 + 3*5 = 15 >= 15, obj = 5
      # At x=7.5, y=0: 2*7.5 + 3*0 = 15 >= 15, obj = 7.5
      # Optimal: x=0, y=5 with objective = 5
      expect(solution.objective_value).to be_within(0.001).of(5.0)
      expect(solution[:x]).to be_within(0.001).of(0.0)
      expect(solution[:y]).to be_within(0.001).of(5.0)
    end

    it 'handles complex expressions' do
      model = LpSolver::Model.new('complex_test')
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)
      z = model.add_variable(:z, lb: 0)

      # x * 2 + y * 3 - z + 5 <= 20  →  x * 2 + y * 3 - z <= 15
      model.add_constraint(:c, ((x * 2) + (y * 3) - z + 5) <= 20)
      model.minimize
      model.set_objective(x + y + z)

      solution = model.solve

      expect(solution.feasible?).to be true
    end
  end

  describe 'basic LP with arrays (legacy)' do
    it 'solves a simple minimization problem' do
      model = LpSolver::Model.new('simple_min')
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)

      model.add_constraint(:c1, [[x.index, 1], [y.index, 1]], lb: 4)
      model.minimize
      model.set_objective({ x.index => 3.0, y.index => 5.0 })

      solution = model.solve

      expect(solution.feasible?).to be true
      expect(solution[:x]).to be_within(0.001).of(4.0)
      expect(solution[:y]).to be_within(0.001).of(0.0)
      expect(solution.objective_value).to be_within(0.001).of(12.0)
    end
  end

  describe 'MIP (Mixed Integer Programming)' do
    it 'solves the coin purse problem' do
      PENNY_VALUE = 1.0
      NICKEL_VALUE = 5.0
      DIME_VALUE = 10.0
      QUARTER_VALUE = 25.0
      HALF_DOLLAR_VALUE = 50.0
      DOLLAR_VALUE = 100.0

      PENNY_WEIGHT = 2.500
      NICKEL_WEIGHT = 5.000
      DIME_WEIGHT = 2.268
      QUARTER_WEIGHT = 5.670
      HALF_DOLLAR_WEIGHT = 11.340
      DOLLAR_WEIGHT = 8.100

      TARGET = 999.0
      PENALTY = 1000.0

      model = LpSolver::Model.new('coin_purse')

      penny = model.add_variable(:penny, lb: 0, integer: true)
      nickel = model.add_variable(:nickel, lb: 0, integer: true)
      dime = model.add_variable(:dime, lb: 0, integer: true)
      quarter = model.add_variable(:quarter, lb: 0, integer: true)
      half_dollar = model.add_variable(:half_dollar, lb: 0, integer: true)
      dollar = model.add_variable(:dollar, lb: 0, integer: true)

      d = model.add_variable(:deviation, lb: 0)

      value_expr = [
        [penny.index, PENNY_VALUE],
        [nickel.index, NICKEL_VALUE],
        [dime.index, DIME_VALUE],
        [quarter.index, QUARTER_VALUE],
        [half_dollar.index, HALF_DOLLAR_VALUE],
        [dollar.index, DOLLAR_VALUE]
      ]

      weight_expr = [
        [penny.index, PENNY_WEIGHT],
        [nickel.index, NICKEL_WEIGHT],
        [dime.index, DIME_WEIGHT],
        [quarter.index, QUARTER_WEIGHT],
        [half_dollar.index, HALF_DOLLAR_WEIGHT],
        [dollar.index, DOLLAR_WEIGHT]
      ]

      model.add_constraint(:upper_deviation, value_expr + [[d.index, -1.0]], ub: TARGET)
      model.add_constraint(:lower_deviation, value_expr + [[d.index, 1.0]], lb: TARGET)

      obj = weight_expr + [[d.index, PENALTY]]
      model.minimize
      model.set_objective(Hash[obj])

      solution = model.solve

      expect(solution.feasible?).to be true
      expect(solution.infeasible?).to be false

      deviation = solution[:deviation]
      expect(deviation).to be < 0.001

      total_value = (
        (solution[:penny] * PENNY_VALUE) +
        (solution[:nickel] * NICKEL_VALUE) +
        (solution[:dime] * DIME_VALUE) +
        (solution[:quarter] * QUARTER_VALUE) +
        (solution[:half_dollar] * HALF_DOLLAR_VALUE) +
        (solution[:dollar] * DOLLAR_VALUE)
      )
      expect(total_value).to be_within(0.001).of(TARGET)

      %i[penny nickel dime quarter half_dollar dollar].each do |coin|
        val = solution[coin]
        expect(val).to be >= 0
        expect(val).to be_within(0.001).of(val.round)
      end

      puts "\n=== Coin Purse Solution ==="
      puts "Target: #{TARGET} cents"
      puts "Optimal weight: #{solution.objective_value.round(3)}g"
      puts "Deviation from target: #{deviation.round(6)} cents"
      puts ''
      puts 'Coin counts:'
      %i[dollar half_dollar quarter dime nickel penny].each do |coin|
        count = solution[coin].round
        value = count * case coin
                        when :penny then PENNY_VALUE
                        when :nickel then NICKEL_VALUE
                        when :dime then DIME_VALUE
                        when :quarter then QUARTER_VALUE
                        when :half_dollar then HALF_DOLLAR_VALUE
                        when :dollar then DOLLAR_VALUE
                        end
        puts "  #{coin.to_s.capitalize.ljust(14)}: #{count.to_s.rjust(3)} coins (#{value.round}¢)"
      end
      puts ''
      total = solution[:penny] + solution[:nickel] +
              solution[:dime] + solution[:quarter] +
              solution[:half_dollar] + solution[:dollar]
      puts "Total: #{total.round} coins = #{total_value.round}¢"
      puts "Weight: #{solution.objective_value.round(3)}g"
      puts '==========================='
    end

    it 'handles infeasible models' do
      model = LpSolver::Model.new('infeasible_test')
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)

      model.add_constraint(:c1, [[x.index, 1], [y.index, 1]], lb: 10)
      model.add_constraint(:c2, [[x.index, 1], [y.index, 1]], ub: 5)
      model.minimize
      model.set_objective({ x.index => 1.0, y.index => 1.0 })

      solution = model.solve

      expect(solution.infeasible?).to be true
    end
  end

  describe 'QP (Quadratic Programming)' do
    it 'solves a simple quadratic minimization' do
      # Minimize x^2 + y^2 subject to x + y >= 2, x,y >= 0
      # Optimal: x = 1, y = 1, objective = 2
      model = LpSolver::Model.new('qp_test')
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)

      model.add_constraint(:c, (x + y) >= 2)
      model.minimize
      model.set_objective((x * x) + (y * y))

      solution = model.solve

      expect(solution.feasible?).to be true
      expect(solution[:x]).to be_within(0.01).of(1.0)
      expect(solution[:y]).to be_within(0.01).of(1.0)
      expect(solution.objective_value).to be_within(0.01).of(2.0)
    end

    it 'solves a quadratic objective with cross terms' do
      # Minimize x^2 + 2xy + y^2 + x + y subject to x + y >= 3, x,y >= 0
      # (x+y)^2 + (x+y) = z^2 + z where z = x+y >= 3
      # Optimal at z=3: objective = 9 + 3 = 12
      model = LpSolver::Model.new('qp_cross')
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)

      model.add_constraint(:c, (x + y) >= 3)
      model.minimize
      model.set_objective((x * x) + ((x * y) * 2) + (y * y) + x + y)

      solution = model.solve

      expect(solution.feasible?).to be true
      expect(solution.objective_value).to be_within(0.01).of(12.0)
    end

    it 'generates correct LP from quadratic objective' do
      model = LpSolver::Model.new('qp_lp_test')
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)

      model.add_constraint(:c, (x + y) >= 2)
      model.minimize
      model.set_objective((x * x) + (y * y))

      lp = model.to_lp
      expect(lp).to include('obj:')
      expect(lp).to include('[')
      expect(lp).to include('] / 2')
    end
  end

  describe 'LP format generation' do
    it 'handles integer variables in LP format' do
      model = LpSolver::Model.new('int_test')
      x = model.add_variable(:x, lb: 0, integer: true)
      y = model.add_variable(:y, lb: 0)

      model.add_constraint(:c1, [[x.index, 1], [y.index, 1]], lb: 5)
      model.minimize
      model.set_objective({ x.index => 1.0, y.index => 2.0 })

      lp = model.to_lp
      expect(lp).to include('Integers')
      expect(lp).to include('x')
    end

    it 'handles unbounded variables' do
      model = LpSolver::Model.new('unbounded_test')
      model.add_variable(:x, lb: -Float::INFINITY)

      lp = model.to_lp
      expect(lp).to include('Bounds')
    end

    it 'handles fixed variables' do
      model = LpSolver::Model.new('fixed_test')
      model.add_variable(:x, lb: 5, ub: 5)

      lp = model.to_lp
      expect(lp).to include('= 5')
    end

    it 'generates correct LP from operator-style constraints' do
      model = LpSolver::Model.new('op_test')
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)

      model.add_constraint(:c1, ((x * 2) + y) <= 10)
      model.add_constraint(:c2, (x + (y * 2)) >= 8)
      model.minimize
      model.set_objective(x + y)

      lp = model.to_lp
      expect(lp).to include('Subject To')
      expect(lp).to include('2 x + 1 y <= 10')
      expect(lp).to include('1 x + 2 y >= 8')
    end
  end
end
