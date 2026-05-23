# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LpSolver::Drivers::NativeDriver do
  let(:driver) { LpSolver::Drivers::NativeDriver.new }

  context 'when native extension is available' do
    it 'solves a simple LP problem' do
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

    it 'solves a simple QP problem (via CLI fallback)' do
      pending 'NativeDriver does not support QP yet'
      model = LpSolver::Model.new
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)
      model.add_constraint(:c, (x + y) >= 2)
      model.minimize!(x * x + y * y)
      solution = driver.solve(model)

      expect(solution.feasible?).to be true
      expect(solution.objective_value).to be_within(0.01).of(2.0)
    end

    it 'solves a QP problem with cross terms (via CLI fallback)' do
      pending 'NativeDriver does not support QP yet'
      model = LpSolver::Model.new
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)
      model.add_constraint(:c1, (x + y) >= 2)
      model.add_constraint(:c2, (x - y) >= 0)
      model.minimize!(x * x + y * y + (x * y) * 2)
      solution = driver.solve(model)

      expect(solution.feasible?).to be true
      expect(solution[:x]).to be_within(0.01).of(1.0)
    end

    it 'raises LoadError when native extension is not available' do
      # This test verifies the error message
      allow_any_instance_of(described_class).to receive(:call_native).and_raise(LoadError, 'Native extension not available')
      model = LpSolver::Model.new
      x = model.add_variable(:x, lb: 0)
      y = model.add_variable(:y, lb: 0)
      model.add_constraint(:c1, (x + y) >= 4)

      expect { driver.solve(model) }.to raise_error(LoadError, /Native extension not available/)
    end
  end
end
