# frozen_string_literal: true

# Driver classes — pluggable solving backends.
#
# Each driver implements the same interface so Model can swap them
# at runtime. See drivers/README.md for the API contract.
#
require_relative 'drivers/cli_driver'
require_relative 'drivers/native_driver'
