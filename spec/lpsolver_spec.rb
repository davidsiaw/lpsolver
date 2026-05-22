# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe LpSolver do
  it 'has a version number' do
    expect(LpSolver::VERSION).not_to be_nil
  end
end
