# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Driver fallback' do
  let(:model) { LpSolver::Model.new }

  let(:x) { model.add_variable(:x, lb: 0) }
  let(:y) { model.add_variable(:y, lb: 0) }

  before do
    model.add_constraint(:c1, (x + y) >= 4)
  end

  it 'uses CliDriver by default' do
    expect(model.driver).to be_a(LpSolver::Drivers::CliDriver)
  end

  it 'solves when CLI driver works' do
    model.driver = LpSolver::Drivers::CliDriver.new
    model.minimize!(x * 3 + y * 5)
    solution = model.solve
    expect(solution.feasible?).to be true
    expect(solution.objective_value).to be_within(0.001).of(12.0)
  end

  it 'solves when native driver works' do
    model.driver = LpSolver::Drivers::NativeDriver.new
    model.minimize!(x * 3 + y * 5)
    solution = model.solve
    expect(solution.feasible?).to be true
    expect(solution.objective_value).to be_within(0.001).of(12.0)
  end

  it 'falls back to native driver when CLI driver fails' do
    cli_mock = double('CliDriver')
    allow(cli_mock).to receive(:class).and_return(LpSolver::Drivers::CliDriver)
    allow(cli_mock).to receive(:solve).and_raise(LpSolver::SolverError, 'CLI failed')

    model.driver = cli_mock
    model.minimize!(x * 3 + y * 5)

    # Should fall back to native driver
    solution = model.solve
    expect(solution.feasible?).to be true
    expect(solution.objective_value).to be_within(0.001).of(12.0)
  end

  it 'raises error when CLI fails and native is not available' do
    cli_mock = double('CliDriver')
    allow(cli_mock).to receive(:class).and_return(LpSolver::Drivers::CliDriver)
    allow(cli_mock).to receive(:solve).and_raise(LpSolver::SolverError, 'CLI failed')

    allow(LpSolver::Drivers::NativeDriver).to receive(:new).and_raise(LoadError, 'Native unavailable')

    model.driver = cli_mock

    expect { model.minimize!(x * 3 + y * 5) }.to raise_error(LpSolver::SolverError, 'CLI failed')
  end

  it 'does not fall back when native driver is explicitly set and fails' do
    native_mock = instance_double(LpSolver::Drivers::NativeDriver)
    allow(native_mock).to receive(:solve).and_raise(LpSolver::SolverError, 'Native failed')

    model.driver = native_mock

    expect { model.minimize!(x * 3 + y * 5) }.to raise_error(LpSolver::SolverError, 'Native failed')
  end

  it 'Model.default_driver returns CliDriver when HiGHS binary exists' do
    driver = LpSolver::Model.default_driver
    expect(driver).to be_a(LpSolver::Drivers::CliDriver)
  end
end
