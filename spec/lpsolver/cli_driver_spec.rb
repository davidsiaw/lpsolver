# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LpSolver::Drivers::CliDriver do
  let(:driver) { LpSolver::Drivers::CliDriver.new }

  context 'when HiGHS binary is available' do
    it 'solves a simple minimization problem' do
      model = LpSolver::Model.new
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)
      model.add_constraint(:c1, (x + y) >= 4)
      model.minimize!(x * 3 + y * 5)
      solution = driver.solve(model)

      expect(solution.feasible?).to be true
      expect(solution.objective_value).to be_within(0.001).of(12.0)
    end

    it 'solves a maximization problem' do
      model = LpSolver::Model.new
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)
      model.add_constraint(:c1, (x + y) <= 10)
      model.add_constraint(:c2, (x + y * 2) <= 16)
      model.maximize!(x * 3 + y * 5)
      solution = driver.solve(model)

      expect(solution.feasible?).to be true
      expect(solution.objective_value).to be_within(0.001).of(42.0)
    end

    it 'solves a MIP problem' do
      model = LpSolver::Model.new
      x = model.add_variable(:x, lb: 0, integer: true)
      y = model.add_variable(:y, lb: 0, integer: true)
      model.add_constraint(:c1, (x + y) >= 4)
      model.minimize!(x * 2 + y * 3)
      solution = driver.solve(model)

      expect(solution.feasible?).to be true
      expect(solution.objective_value).to be_within(0.001).of(8.0)
    end

    it 'detects infeasible models' do
      model = LpSolver::Model.new
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)
      model.add_constraint(:c1, (x + y) <= 2)
      model.add_constraint(:c2, (x + y) >= 5)
      model.minimize!(x + y)
      solution = driver.solve(model)

      expect(solution.infeasible?).to be true
    end

    it 'detects unbounded models' do
      model = LpSolver::Model.new
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)
      model.add_constraint(:c1, (x - y) >= 1)
      model.maximize!(x + y)
      solution = driver.solve(model)

      expect(solution.unbounded?).to be true
    end

    it 'solves a problem with equality constraints' do
      model = LpSolver::Model.new
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)
      model.add_constraint(:c1, (x + y) == 10)
      model.minimize!(x * 2 + y * 3)
      solution = driver.solve(model)

      expect(solution.feasible?).to be true
      expect(solution[:x]).to be_within(0.001).of(10.0)
    end

    it 'solves with minimize!' do
      model = LpSolver::Model.new
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)
      model.add_constraint(:c1, (x + y) >= 4)
      model.driver = driver
      solution = model.minimize!(x * 3 + y * 5)

      expect(solution.feasible?).to be true
      expect(solution.objective_value).to be_within(0.001).of(12.0)
    end

    it 'solves with maximize!' do
      model = LpSolver::Model.new
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)
      model.add_constraint(:c1, (x + y) <= 10)
      model.add_constraint(:c2, (x + y * 2) <= 16)
      model.driver = driver
      solution = model.maximize!(x * 3 + y * 5)

      expect(solution.feasible?).to be true
      expect(solution.objective_value).to be_within(0.001).of(42.0)
    end
  end
end
