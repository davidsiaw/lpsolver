# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rbconfig'
require 'tmpdir'

RSpec::Core::RakeTask.new(:spec)

# Platform detection for HiGHS precompiled binaries
def platform_key
  case RbConfig::CONFIG['host_os']
  when /linux/
    'x86_64-linux-gnu'
  when /darwin/
    if RbConfig::CONFIG['host_cpu'] == 'arm64'
      'arm-apple'
    else
      'x86_64-apple'
    end
  else
    abort "Unsupported platform: #{RbConfig::CONFIG['host_os']}"
  end
end

# Download and extract HiGHS precompiled static library (no CMake needed)
task :build_highs do
  highs_src = File.expand_path('ext/lpsolver-highs', __dir__)
  build_dir = File.join(highs_src, 'build')
  key = platform_key

  # Skip if already built
  lib_file = File.join(build_dir, 'lib', 'libhighs.a')
  if File.exist?(lib_file)
    puts "HiGHS already built at #{lib_file}."
    next
  end

  puts "Downloading HiGHS v1.14.0 precompiled static library (#{key})..."

  # Create build directory
  FileUtils.mkdir_p(build_dir)

  # Download tarball
  url = "https://github.com/ERGO-Code/HiGHS/releases/download/v1.14.0/highs-1.14.0-#{key}-static-mit.tar.gz"
  tarball = File.join(Dir.tmpdir, "highs-#{key}.tar.gz")

  # Download using wget or curl (URI.open needs openssl which may be missing)
  downloader = nil
  downloader = 'wget' if system('which', 'wget', out: File::NULL, err: File::NULL)
  downloader = 'curl' if system('which', 'curl', out: File::NULL, err: File::NULL) && downloader.nil?
  unless downloader
    abort <<~ERROR
      Neither wget nor curl found. Cannot download HiGHS precompiled binary.

      Please:
        1. Install wget or curl, or
        2. Download manually from:
           #{url}
           and extract lib/libhighs.a and include/ into:
           #{build_dir}/
        3. Set HIGHS_DIR=/path/to/highs to point to an existing installation
    ERROR
  end

  if downloader == 'wget'
    system(downloader, '-q', url, '-O', tarball) || abort('wget download failed')
  else
    # curl: -L follow redirects, -s silent, -o output file
    system(downloader, '-L', '-s', '-o', tarball, url) || abort('curl download failed')
  end

  unless File.exist?(tarball) && File.size(tarball) > 1000
    abort <<~ERROR
      Downloaded file is empty or too small (#{File.exist?(tarball) ? File.size(tarball) : 0} bytes).

      This platform may not have a precompiled binary available.
      You can:
        1. Install HiGHS system-wide: sudo apt install highs (Debian/Ubuntu)
        2. Set HIGHS_DIR=/path/to/highs to point to an existing installation
    ERROR
  end

  # Extract — tarball contents go directly into the target dir
  # (no versioned subdirectory prefix)
  Dir.chdir(build_dir) do
    system('tar', 'xzf', tarball) || abort('HiGHS extraction failed')
  end

  # Clean up tarball
  File.delete(tarball) if File.exist?(tarball)

  # Verify extraction
  unless File.exist?(lib_file)
    abort "HiGHS static library not found at #{lib_file} after extraction."
  end

  puts "HiGHS v1.14.0 precompiled static library installed to #{lib_file}."
end

# Compile the native extension (HiGHS C API wrapper)
task :compile do
  ext_dir = File.expand_path('ext/lpsolver', __dir__)
  lib_dir = File.expand_path('lib/lpsolver', __dir__)
  Dir.mkdir(lib_dir) unless Dir.exist?(lib_dir)

  Dir.chdir(ext_dir) do
    puts 'Configuring native extension...'
    system('ruby extconf.rb') || abort('extconf.rb failed')
    puts 'Building native extension...'
    system('make') || abort('make failed')
  end

  # Copy .so to lib directory for require
  so_file = Dir.glob(File.join(ext_dir, '*.so')).first
  if so_file
    require 'fileutils'
    FileUtils.cp(so_file, lib_dir)
    puts "Copied native.so to lib/lpsolver/"
  end

  # Copy bundled HiGHS binary for Model CLI fallback
  highs_bin = File.join(__dir__, 'ext', 'lpsolver-highs', 'build', 'bin', 'highs')
  if File.exist?(highs_bin)
    FileUtils.cp(highs_bin, lib_dir)
    puts "Copied highs binary to lib/lpsolver/"
  end

  puts 'Native extension built successfully.'
end

# Run build_highs before compile
Rake::Task['compile'].prerequisites.unshift('build_highs')

task default: [:spec, :compile]
