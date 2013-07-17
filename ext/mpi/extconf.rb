require "mkmf"

CONFIG['CC'] = "mpicc"
gem_path = nil
begin
  require "rubygems"
  if (spec = Gem.source_index.find_name("narray")).any?
    gem_path = spec.last.full_gem_path
  end
rescue LoadError
  dir_config("narray", Config::CONFIG["sitearchdir"])
end
find_header("narray.h", File.join(gem_path,"src"))

create_makefile("mpi")
