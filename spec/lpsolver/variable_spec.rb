# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe LpSolver::Variable do
  describe 'arithmetic' do
    it 'supports multiplication by scalar' do
      x = LpSolver::Variable.new(0, :x)
      expr = x * 2
      expect(expr).to be_a(LpSolver::LinearExpression)
      expect(expr.terms).to eq({ 0 => 2.0 })
    end

    it 'supports addition of variables' do
      x = LpSolver::Variable.new(0, :x)
      y = LpSolver::Variable.new(1, :y)
      expr = x + y
      expect(expr.terms).to eq({ 0 => 1.0, 1 => 1.0 })
    end

    it 'supports subtraction of variables' do
      x = LpSolver::Variable.new(0, :x)
      y = LpSolver::Variable.new(1, :y)
      expr = x - y
      expect(expr.terms).to eq({ 0 => 1.0, 1 => -1.0 })
    end

    it 'supports unary minus' do
      x = LpSolver::Variable.new(0, :x)
      expr = -x
      expect(expr.terms).to eq({ 0 => -1.0 })
    end

    it 'supports adding a constant' do
      x = LpSolver::Variable.new(0, :x)
      expr = x + 5
      expect(expr.terms).to eq({ 0 => 1.0 })
      expect(expr.constant).to eq(5.0)
    end

    it 'supports subtracting a constant' do
      x = LpSolver::Variable.new(0, :x)
      expr = x - 5
      expect(expr.terms).to eq({ 0 => 1.0 })
      expect(expr.constant).to eq(-5.0)
    end
  end

  describe 'comparison operators' do
    it 'builds <= constraint' do
      x = LpSolver::Variable.new(0, :x)
      spec = x <= 10
      expect(spec.operator).to eq(:le)
      expect(spec.terms).to eq({ 0 => 1.0 })
      expect(spec.rhs).to eq(10.0)
      lb, ub = spec.bounds
      expect(lb).to eq(-Float::INFINITY)
      expect(ub).to eq(10.0)
    end

    it 'builds >= constraint' do
      x = LpSolver::Variable.new(0, :x)
      spec = x >= 10
      expect(spec.operator).to eq(:ge)
      lb, ub = spec.bounds
      expect(lb).to eq(10.0)
      expect(ub).to eq(Float::INFINITY)
    end

    it 'builds == constraint' do
      x = LpSolver::Variable.new(0, :x)
      spec = x == 10
      expect(spec.operator).to eq(:eq)
      lb, ub = spec.bounds
      expect(lb).to eq(10.0)
      expect(ub).to eq(10.0)
    end
  end
end
