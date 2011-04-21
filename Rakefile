require 'rubygems'
require 'bundler'
require "rake/clean"
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "ruby-mpi"
  gem.homepage = "http://github.com/seiya/ruby-mpi"
  gem.license = "MIT"
  gem.summary = "A ruby binding of MPI"
  gem.description = "A ruby binding of Message Passing Interface (MPI), which is an API specification that allows processes to communicate with one another by sending and receiving messages."
  gem.email = "seiya@gfd-dennou.org"
  gem.authors = ["Seiya Nishizawa"]
  # Include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
  #  gem.add_runtime_dependency 'jabber4r', '> 0.1'
  #  gem.add_development_dependency 'rspec', '> 1.2.3'
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "ruby-mpi #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end


CLEAN.include("ext/mpi/*.o")
CLEAN.include("ext/mpi/mkmf.log")
CLOBBER.include("ext/mpi/mpi.so")
CLOBBER.include("ext/mpi/Makefile")
