# Run this program using
#
# mpirun -np numprocs ruby kmeans.rb numpoints numclusters
#
# where numprocs, numpoints and numclusters are integers
# and numprocs <= numpoints and numclusters <= numpoints
#
# Parallelization assumes that numclusters << numpoints
# and that numprocs << numpoints
#
# The program is based on the description at
# https://en.wikipedia.org/wiki/K-means_clustering

require "mpi"
if defined?(NumRu::NArray)
  include NumRu
end

def generate_points count
  x = NArray.float(count).random
  y = NArray.float(count).random
  return x , y 
end

MPI.Init

world = MPI::Comm::WORLD

size = world.size
rank = world.rank

def usage(rank)
 if rank==0
   print <<EOF
Usage: mpirun -np numproc ruby #$0 numpoints numclusters

       numpoints and numclusters must be integers > 0
       numclusters <= numpoints and numproc <= numpoints
EOF
 end
  MPI.Finalize
  exit -1
end

usage(rank) if ARGV.length != 2
usage(rank) if ( ( /^\d+$/ =~ ARGV[0] ) != 0)
usage(rank) if ( ( /^\d+$/ =~ ARGV[1] ) != 0)
n_points = ARGV[0].to_i
n_clusters = ARGV[1].to_i
usage(rank) unless n_points > size
usage(rank) unless n_clusters > 0
usage(rank) unless n_points >= n_clusters

my_points = n_points.div(size) 
if ( n_points % size > rank  ) 
  my_points +=  1
end

cluster_x = NArray.float(n_clusters)
cluster_y = NArray.float(n_clusters)
my_cluster = NArray.int(my_points)
min_distance = NArray.float(my_points)
distance = NArray.float(n_clusters)
count = NArray.int(n_clusters).indgen(0,1)
cluster_member_count = NArray.int(n_clusters)
total_cluster_x_sum = NArray.float(n_clusters)
total_cluster_y_sum = NArray.float(n_clusters)
total_cluster_member_count = NArray.int(n_clusters)
my_cluster_x = NArray.float(n_clusters)
my_cluster_y = NArray.float(n_clusters)
my_cluster_member_count = NArray.int(n_clusters)
my_energy = NArray.float(1)
total_energy = NArray.float(1)
random_x = NArray.float(n_clusters)
random_y = NArray.float(n_clusters)

my_x, my_y = generate_points my_points
if rank == 0
  cluster_x, cluster_y = generate_points n_clusters
end
world.Bcast(cluster_x,0)
world.Bcast(cluster_y,0)

iter = 0
# Do 10 iterations for testing purposes
# in practice would use some convergence 
# criteria
while iter < 10 do
  # Find cluster and calculate energy
  i = 0 
  my_energy[0] = 0
  while i < my_points do
    distance = ( cluster_x - my_x[i] )**2 + ( cluster_y - my_y[i] )**2
    min_distance = distance.min
    my_energy[0] += min_distance
    my_cluster[i] = (count[ distance.eq(min_distance) ]).sum
    i +=1
  end
  world.Allreduce(my_energy,total_energy,MPI::Op::SUM)
  if rank == 0
    p total_energy[0]
  end
  # Find new cluster centroids
  j = 0
  while j < n_clusters do
    mask = my_cluster.eq(j)
    my_cluster_member_count[j] = mask.count_true
    if mask.any?
      my_cluster_x[j] = (my_x[mask]).sum
      my_cluster_y[j] = (my_y[mask]).sum
    end
    j +=1
  end
  world.Allreduce(my_cluster_member_count,total_cluster_member_count,MPI::Op::SUM)
  world.Allreduce(my_cluster_x,total_cluster_x_sum,MPI::Op::SUM)
  world.Allreduce(my_cluster_y,total_cluster_y_sum,MPI::Op::SUM)
  # If a cluster is empty, choose a random point to try
  no_members = total_cluster_member_count.eq(0)
  if no_members.any?
    if rank == 0
      random_x, random_y = generate_points no_members.count_true
      total_cluster_member_count[no_members]= 1
      total_cluster_x_sum[no_members] = random_x
      total_cluster_y_sum[no_members] = random_y
      cluster_x = total_cluster_x_sum / total_cluster_member_count
      cluster_y = total_cluster_y_sum / total_cluster_member_count
    end
    world.Bcast(cluster_x,0)
    world.Bcast(cluster_y,0)
  else
    cluster_x = total_cluster_x_sum / total_cluster_member_count
    cluster_y = total_cluster_y_sum / total_cluster_member_count
  end
iter += 1
end

MPI.Finalize
