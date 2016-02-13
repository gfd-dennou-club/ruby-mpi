require "mkmf"

CONFIG['CC'] = "mpicc"
gem_path = nil
begin
  require "rubygems"
  if Gem::Specification.respond_to?(:find_by_name)
    if spec = ( Gem::Specification.find_by_name("numru-narray") || Gem::Specification.find_by_name("narray") )
      gem_path = spec.full_gem_path
    end
  else
    if (spec = (Gem.source_index.find_name("numru-narray") || Gem.source_index.find_name("narray")) ).any?
      gem_path = spec.full_gem_path
    end
  end
  gem_path = File.join(gem_path, "ext", "numru", "narray")
rescue LoadError
  dir_config("narray", RbConfig::CONFIG["sitearchdir"])
end

unless find_header("narray.h", gem_path)
  find_header("narray.h", File.join(gem_path,"src"))
end

create_makefile("mpi")
