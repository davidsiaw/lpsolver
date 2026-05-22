# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe LpSolver::ConstraintSpec do
  describe '#bounds' do
    it 'returns correct bounds for <=' do
      spec = LpSolver::ConstraintSpec.new(:le, { 0 => 2.0 }, 0, 10)
      lb, ub = spec.bounds
      expect(lb).to eq(-Float::INFINITY)
      expect(ub).to eq(10.0)
    end

    it 'returns correct bounds for >=' do
      spec = LpSolver::ConstraintSpec.new(:ge, { 0 => 2.0 }, 0, 10)
      lb, ub = spec.bounds
      expect(lb).to eq(10.0)
      expect(ub).to eq(Float::INFINITY)
    end

    it 'returns correct bounds for ==' do
      spec = LpSolver::ConstraintSpec.new(:eq, { 0 => 2.0 }, 3, 10)
      lb, ub = spec.bounds
      expect(lb).to eq(7.0)
      expect(ub).to eq(7.0)
    end
  end
end
