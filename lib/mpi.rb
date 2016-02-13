begin
  require "rubygems"
rescue LoadError
end
begin
  require "numru/narray"
rescue LoadError
  err = $!
  begin
    require "narray"
  rescue LoadError
    STDERR.puts "You should install numru-narray or narray to use ruby-mpi"
    raise err
  end
end
require "mpi.so"
