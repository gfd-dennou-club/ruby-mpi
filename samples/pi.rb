# Run this program using
#
# mpirun -np 2 ruby pi.rb numpoints
#
# where numpoints is an integer
# 
# The program is based on an example from
# https://carpentries-incubator.github.io/hpc-intro/16-parallel/index.html

require "mpi"
if defined?(NumRu::NArray)
  include NumRu
end

def inside_circle my_count
  x = NArray.float(my_count).random
  y = NArray.float(my_count).random
  a = ((x**2 + y**2) < 1.0)
  return a.count_true
end

MPI.Init

world = MPI::Comm::WORLD

size = world.size
rank = world.rank

n_samples = ARGV[0].to_i
my_samples = n_samples.div(size) 
if ( n_samples % size > rank  ) 
  my_samples = my_samples + 1
end

my_count = NArray[1]
count = NArray[0]

my_count[0] = inside_circle my_samples 

world.Reduce(my_count,count,MPI::Op::SUM,0)
if ( rank == 0 )
  p "Pi is approximately " + ((count[0]*4.0)/(1.0*n_samples)).to_s
end

MPI.Finalize
