# The program is based on an exampls from
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

require "mpi"
if defined?(NumRu::NArray)
  include NumRu
end


MPI.Init

world = MPI::Comm::WORLD

size = world.size
rank = world.rank

MPI.Finalize
