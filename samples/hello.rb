require "mpi"

MPI.Init


world = MPI::Comm::WORLD

if world.size == 1
  print "Size is one, so do nothing\n"
  exit
end

rank = world.rank

if rank == 0
  (world.size-1).times do |i|
    str ="\x00"*100
    world.Recv(str, i+1, 0) 
    p str.gsub(/\000/,"")
  end
else
  message = "Hello from #{rank}"
  world.Send(message, 0, 0)
end


MPI.Finalize
