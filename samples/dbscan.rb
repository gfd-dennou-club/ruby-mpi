# The program is based on an examples from
# 
# M. Götz, C. Bodenstein, M. Riedel,
# HPDBSCAN: highly parallel DBSCAN,
# Proceedings of the Workshop on Machine Learning in High-Performance Computing Environments, ACM, 2015.
# https://github.com/Markus-Goetz/hpdbscan
#
# X. Hu, J. Huang, M. Qiu, C. Chen, W. Chu 
# "PS-DBSCAN: An Efficient Parallel DBSCAN Algorithm Based on Platform Of AI (PAI)" 
# https://arxiv.org/abs/1711.01034
#
# D. Han, A. Agrawal, W-k. Liao, A. Choudhary
# A Fast DBSCAN Algorithm with Spark Implementation 
# http://cucis.eecs.northwestern.edu/publications/pdf/HAL18.pdf
#
# Md. Mostofa Ali Patwary, D. Palsetia, A. Agrawal, W.-k. Liao, F. Manne, A. Choudhary, 
# A New Scalable Parallel DBSCAN Algorithm Using the Disjoint Set Data Structure
# Proceedings of the International Conference on High Performance Computing, Networking, 
# Storage and Analysis (Supercomputing, SC'12), pp.62:1-62:11, 2012.	  
# http://cucis.eecs.northwestern.edu/publications/pdf/PatPal12.pdf
# http://cucis.ece.northwestern.edu/projects/Clustering/download_code_dbscan.html
# https://github.com/ContinuumIO/parallel_dbscan/tree/master/dbscan-v1.0.0
#
# DBSCAN
# Matias Insaurralde
# https://github.com/matiasinsaurralde/dbscan
#
# dbscan
# ningjingzhiyuan
# https://github.com/ningjingzhiyuande/dbscan
# 
# dbscan
# Atsushi Tatsuma 
# https://github.com/yoshoku/rumale/blob/main/lib/rumale/clustering/dbscan.rb
#
# https://en.wikipedia.org/wiki/DBSCAN
# 
# The current parallelization method will not work on large data sets
# Possible options to allow this include pre- partitioning the data
# set and then using unions on local clusters

require "mpi"
if defined?(NumRu::NArray)
  include NumRu
  include NMath
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
Usage: mpirun -np numproc ruby #$0 numpoints minpoints epsilon
       numpoints and minpoints must be integers > 0 with
       minpoints <= numpoints and numproc <= numpoints
       1 > epsilon > 0 must be a real number, with an upper
       limit of 1 because all generated points are greater than
       zero and less than one.
EOF
 end
  MPI.Finalize
  exit -1
end

usage(rank) if ARGV.length != 3
usage(rank) if ( ( /^\d+$/ =~ ARGV[0] ) != 0)
usage(rank) if ( ( /^\d+$/ =~ ARGV[1] ) != 0)
usage(rank) if ( ( /^(0|)\.\d+$/ =~ ARGV[2] ) != 0)
n_points = ARGV[0].to_i
min_points = ARGV[1].to_i
epsilon = ARGV[2].to_f
usage(rank) unless n_points > size
usage(rank) unless epsilon > 0
usage(rank) unless epsilon < 1
usage(rank) unless n_points >= min_points

my_points = n_points.div(size)
if ( n_points % size > rank  )
  my_points += 1
end
my_x, my_y = generate_points my_points

nearest_neighbors = NArray.int(n_points)
nearest_neighbors_distance = NArray.float(n_points)
my_nearest_neighbors = NArray.int(n_points).fill(-1)
my_nearest_neighbors_distance = NArray.float(n_points)
distances = NArray.float(n_points)
mask = NArray.byte(n_points).fill(1)
count = NArray.int(n_points).indgen(0,1)
neighbor_loc = NArray.int(n_points)
cluster_label = NArray.int(n_points)
points_start = NArray.int(size)
points_count = NArray.int(size)
x = NArray.float(n_points)
y = NArray.float(n_points)
temp_x = NArray.float(n_points.div(size) + 1)
temp_y = NArray.float(n_points.div(size) + 1)
temp_neighbors = NArray.int(n_points.div(size) + 1)
temp_distance = NArray.float(n_points.div(size) + 1)

j = 0
while j < size do
  points_count[j] = n_points.div(size)
  if ( n_points  % size > j )
    points_count[j] += 1
  end
  if j == 0
     points_start[j] = 0
 else
     points_start[j] = points_start[j-1] + points_count[j-1]
 end
  if rank == j
    temp_x[0..(points_count[j]-1)]=my_x
    temp_y[0..(points_count[j]-1)]=my_y
  end
  world.Barrier
  world.Bcast(temp_x,j)
  world.Bcast(temp_y,j)
  x[points_start[j]..(points_start[j]+points_count[j]-1)]=
    temp_x[0..(points_count[j]-1)]
  y[points_start[j]..(points_start[j]+points_count[j]-1)]=
    temp_y[0..(points_count[j]-1)]
  j +=1
end
# Find closest neighbors by creating 
# something similar to a minimum spanning
# tree
j = points_start[rank]
while j < points_start[rank] + points_count[rank] do
  distances = (x - my_x[j - points_start[rank]])**2 + 
    (y - my_y[j - points_start[rank]])**2
  mask[j] = 0   # remove own location
  # remove any points closest to this one
  neighbor_loc = my_nearest_neighbors.eq(j)
  mask[neighbor_loc] = 0
  new = distances[mask]
  min_value = (distances[mask]).min
  min_loc = (distances[mask]).eq(min_value)
  if min_loc.count_true == 1
    my_nearest_neighbors[j] =  (count[ distances.eq(min_value) ]).sum
    my_nearest_neighbors_distance[j] = sqrt(min_value)
  else
    i=0
    while i < n_points do
      if distances[i] == min_value
        my_nearest_neighbors[j] = i
        my_nearest_neighbors_distance[j] = sqrt(min_value)
      end
      i += 1
    end
  end
  mask[j] = 1
  mask[neighbor_loc] = 1
  j += 1
end
# Exchange neighbor data
j = 0
while j < size do
 if rank == j
   temp_neighbors[0..(points_count[j]-1)]=
     my_nearest_neighbors[points_start[j]..(points_start[j]+points_count[j]-1)]
   temp_distance[0..(points_count[j]-1)]=
     my_nearest_neighbors_distance[points_start[j]..(points_start[j]+points_count[j]-1)]
  end
  world.Bcast(temp_neighbors,j)
  world.Bcast(temp_distance,j)
  nearest_neighbors[points_start[j]..(points_start[j]+points_count[j]-1)]=
    temp_neighbors[0..(points_count[j]-1)]
  nearest_neighbors_distance[points_start[j]..(points_start[j]+points_count[j]-1)]=
    temp_distance[0..(points_count[j]-1)]
  j +=1
end

# label clusters
# 0 is unlabelled
j = 0
cluster_num = 1
while j < n_points do
 if nearest_neighbors_distance[j] < epsilon
   if cluster_label[j] == 0 && cluster_label[nearest_neighbors[j]] == 0
     cluster_label[j] = cluster_num
     cluster_label[nearest_neighbors[j]] = cluster_num
     cluster_num += 1
   elsif cluster_label[j] != 0 && cluster_label[nearest_neighbors[j]] == 0
     cluster_label[nearest_neighbors[j]] = cluster_label[j]
   elsif cluster_label[j] == 0 && cluster_label[nearest_neighbors[j]] != 0
     cluster_label[j] = cluster_label[nearest_neighbors[j]]
   end
 end
 j +=1
end
# remove clusters that are too small
j = 1
while j < cluster_num do
  if (cluster_label.eq(j)).count_true < min_points
    cluster_label[cluster_label.eq(j)]=0
 end
 j += 1
end
# Print out results, cluster label of 0 is noise
if rank == 0
  p x
  p y
  p nearest_neighbors
  p nearest_neighbors_distance
  p cluster_label
end
MPI.Finalize
