# frozen_string_literal: true

require 'mkmf'
require 'rbconfig'

# Find HiGHS from bundled submodule build directory
ext_dir = File.expand_path(__dir__)  # ext/lpsolver
gem_root = File.expand_path('../..', ext_dir)  # lpsolver/
highs_src = File.join(gem_root, 'ext', 'lpsolver-highs')  # ext/lpsolver-highs
highs_build = File.join(highs_src, 'build')

highs_found = false



# Priority: 1. HIGHS_DIR env var, 2. submodule build, 3. system paths
highs_dir = ENV.fetch('HIGHS_DIR', nil)

if highs_dir
  highs_include = File.join(highs_dir, 'include', 'highs')
  highs_lib = File.join(highs_dir, 'lib')

  if File.exist?(File.join(highs_include, 'interfaces', 'highs_c_api.h')) &&
     (File.exist?(File.join(highs_lib, 'libhighs.so')) || File.exist?(File.join(highs_lib, 'libhighs.a')))
    $INCFLAGS += " -I#{highs_include}"
    $LDFLAGS += " -L#{highs_lib}"
    $LIBS += " -lhighs -lstdc++"
    $LOAD_PATH << highs_lib
    highs_found = true
  end
end

unless highs_found
  # Check bundled submodule (CMake build or precompiled tarball)
  if File.exist?(File.join(highs_build, 'lib', 'libhighs.so')) ||
     File.exist?(File.join(highs_build, 'lib', 'libhighs.a'))
    highs_lib = File.join(highs_build, 'lib')

    # CMake build: HConfig.h is in build dir, headers in highs/ subdir
    # Precompiled tarball: HConfig.h is in build/include/highs/, headers in include/highs/
    highs_config = File.join(highs_build, 'HConfig.h')
    if File.exist?(highs_config)
      # CMake build layout
      highs_include = File.join(highs_src, 'highs')
      $INCFLAGS += " -I#{highs_include} -I#{highs_build}"
    else
      # Precompiled tarball layout: headers under include/highs/
      highs_config_inc = File.join(highs_build, 'include', 'highs')
      if File.exist?(File.join(highs_config_inc, 'HConfig.h'))
        $INCFLAGS += " -I#{highs_config_inc}"
      end
    end

    $LDFLAGS += " -L#{highs_lib}"
    $LIBS += " -lhighs -lstdc++"
    $LOAD_PATH << highs_lib
    highs_found = true
  end
end

unless highs_found
  # Try system installation
  if have_library('highs', 'Highs_lpCall') && have_header('highs/interfaces/highs_c_api.h')
    $INCFLAGS += " -I/usr/include"
    $LDFLAGS += " -L/usr/lib"
    highs_found = true
  end
end

abort <<~ERROR unless highs_found
  HiGHS not found.

  Options:
    1. Build from submodule: rake build_highs && rake compile
    2. Set HIGHS_DIR=/path/to/highs
    3. Install system-wide: brew install highs (macOS) or sudo apt install highs (Linux)

  Submodule location: #{highs_src}
  Build output: #{highs_build}/lib/libhighs.a
ERROR

create_makefile('lpsolver/native')
