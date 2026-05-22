# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe LpSolver::LinearExpression do
  describe 'arithmetic' do
    it 'supports addition' do
      x = LpSolver::Variable.new(0, :x)
      y = LpSolver::Variable.new(1, :y)
      expr = ((x * 2) + (y * 3)) + ((x * 1) + (y * 1))
      expect(expr.terms).to eq({ 0 => 3.0, 1 => 4.0 })
      expect(expr.constant).to eq(0.0)
    end

    it 'supports subtraction' do
      x = LpSolver::Variable.new(0, :x)
      expr = ((x * 5) + 10) - ((x * 2) + 3)
      expect(expr.terms).to eq({ 0 => 3.0 })
      expect(expr.constant).to eq(7.0)
    end

    it 'supports scalar multiplication' do
      x = LpSolver::Variable.new(0, :x)
      expr = ((x * 2) + 3) * 4
      expect(expr.terms).to eq({ 0 => 8.0 })
      expect(expr.constant).to eq(12.0)
    end

    it 'supports unary minus' do
      x = LpSolver::Variable.new(0, :x)
      expr = -((x * 3) + 5)
      expect(expr.terms).to eq({ 0 => -3.0 })
      expect(expr.constant).to eq(-5.0)
    end
  end

  describe 'comparison operators' do
    it 'builds <= constraint' do
      x = LpSolver::Variable.new(0, :x)
      spec = ((x * 2) + 3) <= 10
      expect(spec.operator).to eq(:le)
      expect(spec.terms).to eq({ 0 => 2.0 })
      expect(spec.lhs_constant).to eq(3.0)
      expect(spec.rhs).to eq(10.0)
      lb, ub = spec.bounds
      expect(lb).to eq(-Float::INFINITY)
      expect(ub).to eq(7.0)
    end

    it 'builds >= constraint' do
      x = LpSolver::Variable.new(0, :x)
      spec = ((x * 2) + 3) >= 10
      expect(spec.operator).to eq(:ge)
      lb, ub = spec.bounds
      expect(lb).to eq(7.0)
      expect(ub).to eq(Float::INFINITY)
    end

    it 'builds == constraint' do
      x = LpSolver::Variable.new(0, :x)
      spec = ((x * 2) + 3) == 10
      expect(spec.operator).to eq(:eq)
      lb, ub = spec.bounds
      expect(lb).to eq(7.0)
      expect(ub).to eq(7.0)
    end
  end
end
