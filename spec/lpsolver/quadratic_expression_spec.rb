# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe LpSolver::QuadraticExpression do
  describe 'arithmetic' do
    it 'supports addition of two quadratic expressions' do
      x = LpSolver::Variable.new(0, :x)
      y = LpSolver::Variable.new(1, :y)
      quad1 = x * x
      quad2 = y * y
      result = quad1 + quad2
      expect(result).to be_a(LpSolver::QuadraticExpression)
      expect(result.linear_terms).to eq({})
      expect(result.quadratic_terms).to eq([[0, 0, 1.0], [1, 1, 1.0]])
    end

    it 'supports addition of linear expression and quadratic expression' do
      x = LpSolver::Variable.new(0, :x)
      y = LpSolver::Variable.new(1, :y)
      linear = (x * 2) + (y * 3)
      quad = (x * x) + (y * y)
      result = linear + quad
      expect(result).to be_a(LpSolver::QuadraticExpression)
      expect(result.linear_terms).to eq({ 0 => 2.0, 1 => 3.0 })
      expect(result.quadratic_terms).to eq([[0, 0, 1.0], [1, 1, 1.0]])
    end

    it 'supports subtraction' do
      x = LpSolver::Variable.new(0, :x)
      y = LpSolver::Variable.new(1, :y)
      quad1 = (x * x) + (y * y)
      quad2 = x * y
      result = quad1 - quad2
      expect(result).to be_a(LpSolver::QuadraticExpression)
      expect(result.quadratic_terms).to eq([[0, 0, 1.0], [1, 1, 1.0], [0, 1, -1.0]])
    end

    it 'supports scalar multiplication' do
      x = LpSolver::Variable.new(0, :x)
      y = LpSolver::Variable.new(1, :y)
      quad = (x * x) + (y * y) + (x * y)
      result = quad * 2
      expect(result).to be_a(LpSolver::QuadraticExpression)
      expect(result.quadratic_terms).to eq([[0, 0, 2.0], [1, 1, 2.0], [0, 1, 2.0]])
    end

    it 'supports unary minus' do
      x = LpSolver::Variable.new(0, :x)
      y = LpSolver::Variable.new(1, :y)
      quad = (x * x) + (y * y)
      result = -quad
      expect(result).to be_a(LpSolver::QuadraticExpression)
      expect(result.quadratic_terms).to eq([[0, 0, -1.0], [1, 1, -1.0]])
    end
  end

  describe '#hessian_entries' do
    it 'combines symmetric entries and multiplies by 2 for LP format' do
      x = LpSolver::Variable.new(0, :x)
      y = LpSolver::Variable.new(1, :y)
      # x * y + y * x = 2xy → combined as [0, 1, 4.0] after * 2
      # In LP: [4xy]/2 = 2xy
      quad = (x * y) + (y * x)
      entries = quad.hessian_entries
      expect(entries).to eq([[0, 1, 4.0]])
    end

    it 'handles diagonal terms' do
      x = LpSolver::Variable.new(0, :x)
      quad = x * x
      entries = quad.hessian_entries
      # In LP: [2x^2]/2 = x^2
      expect(entries).to eq([[0, 0, 2.0]])
    end
  end
end
