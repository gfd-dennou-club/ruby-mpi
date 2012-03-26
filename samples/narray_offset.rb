require "mpi"

MPI.Init


world = MPI::Comm::WORLD

if world.size == 1
  print "Size is one, so do nothing\n"
  exit
end

rank = world.rank
size = world.size

length = 2
if rank == 0
  a = NArray.float(length,size-1)
  (size-1).times do |i|
    world.Recv(a, i+1, 1, length, i*length)
  end
  p a
else
  a = NArray.float(length).indgen + rank*10
  world.Send(a, 0, 1)
end


MPI.Finalize
