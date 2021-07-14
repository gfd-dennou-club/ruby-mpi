require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

if defined?(NumRu::NArray)
  include NumRu
end

describe "MPI" do
  before(:all) do
    MPI.Init()
  end
  after(:all) do
    MPI.Finalize()
  end

  before do
    @world = MPI::Comm::WORLD
  end

  it "should give version" do
    expect(MPI::VERSION.class).to eq(Integer)
    expect(MPI::SUBVERSION.class).to eq(Integer)
  end

  it "should give rank and size" do
    expect(@world.rank.class).to eql(Integer)
    expect(@world.size.class).to eql(Integer)
    expect(@world.size).to be > 0
  end

  it "should send and receive String" do
    rank = @world.rank
    message = "Hello from #{rank}"
    tag = 0
    @world.Send(message, 0, tag) if rank != 0
    if rank == 0
      (@world.size-1).times do |i|
        str = " "*"Hello from #{i+1}".length
        status = @world.Recv(str, i+1, tag)
        expect(status.source).to eql(i+1)
        expect(status.tag).to eql(tag)
        expect(str).to match /\AHello from #{i+1}/
      end
    end
  end

  it "should send and receive NArray" do
    tag = 10
    rank = @world.rank
    [NArray[1,2,3], NArray[3.0,2.0,1.0]].each_with_index do |ary0,j|
      @world.Send(ary0, 0, tag+j) if rank != 0
      if rank == 0
        (@world.size-1).times do |i|
          ary1 = NArray.new(ary0.typecode, ary0.total)
          status = @world.Recv(ary1, i+1, tag+j)
          expect(status.source).to eql(i+1)
          expect(status.tag).to eql(tag+j)
          expect(ary1).to be == ary0
        end
      end
    end
  end

  it "should send and receive without blocking" do
    tag = 20
    rank = @world.rank
    message = "Hello from #{rank}"
    if rank != 0
      request = @world.Isend(message, 0, tag)
      status = request.Wait
    end
    if rank == 0
      request_recv = []
      str = []
      (@world.size-1).times do |i|
        str.push " "*"Hello from #{i+1}".length
        request_recv.push @world.Irecv(str[-1], i+1, tag)
      end
      status = MPI.Waitall(request_recv)
      (@world.size-1).times do |i|
        expect(status[i].source).to eql(i+1)
        expect(status[i].tag).to eql(tag)
        expect(str[i]).to match(/\AHello from #{i+1}/)
      end
    end
  end

  it "should gather data" do
    rank = @world.rank
    size = @world.size
    root = 0
    bufsize = 2
    sendbuf = rank.to_s[0,1]*bufsize
    recvbuf = rank == root ? "?"*bufsize*size  : nil
    @world.Gather(sendbuf, recvbuf, root)
    if rank == root
      str = ""
      size.times{|i| str << i.to_s[0,1]*bufsize}
      expect(recvbuf).to eql(str)
    end
  end

  it "should gather data without blocking" do
    rank = @world.rank
    size = @world.size
    root = 0
    bufsize = 2
    sendbuf = rank.to_s[0,1]*bufsize
    recvbuf = rank == root ? "?"*bufsize*size  : nil
    request = @world.Igather(sendbuf, recvbuf, root)
    if rank == root
      str = ""
      size.times{|i| str << i.to_s[0,1]*bufsize}
      request.Wait
      expect(recvbuf).to eql(str)
    end
  end

  it "should gather data of various sizes (gatherv)" do
    rank = @world.rank
    size = @world.size
    root = 0
    sendbuf = rank.to_s*(rank+1)
    recvcounts = []
    displs = [0]
    size.times do |i|
      recvcounts.push i.to_s.length * (i+1)
      displs[i+1] = displs[i] + recvcounts[-1] if i<size-1
    end
    bufsize = displs[-1] + recvcounts[-1]
    recvbuf = rank == root ? "?"*bufsize  : nil
    @world.Gatherv(sendbuf, recvbuf, recvcounts, displs, root)
    if rank == root
      str = ""
      size.times{|i| str << i.to_s*(i+1)}
      expect(recvbuf).to eql(str)
    end
  end

  it "should gather data of various sizes without blocking (igatherv)" do
    rank = @world.rank
    size = @world.size
    root = 0
    sendbuf = rank.to_s*(rank+1)
    recvcounts = []
    displs = [0]
    size.times do |i|
      recvcounts.push i.to_s.length * (i+1)
      displs[i+1] = displs[i] + recvcounts[-1] if i<size-1
    end
    bufsize = displs[-1] + recvcounts[-1]
    recvbuf = rank == root ? "?"*bufsize  : nil
    request = @world.Igatherv(sendbuf, recvbuf, recvcounts, displs, root)
    if rank == root
      str = ""
      size.times{|i| str << i.to_s*(i+1)}
      request.Wait
      expect(recvbuf).to eql(str)
    end
  end

  it "should gather data to all processes (allgather)" do
    rank = @world.rank
    size = @world.size
    bufsize = 2
    sendbuf = rank.to_s[0,1]*bufsize
    recvbuf = "?"*bufsize*size
    @world.Allgather(sendbuf, recvbuf)
    str = ""
    size.times{|i| str << i.to_s[0,1]*bufsize}
    expect(recvbuf).to eql(str)
  end

  it "should gather data to all processes without blocking (iallgather)" do
    rank = @world.rank
    size = @world.size
    bufsize = 2
    sendbuf = rank.to_s[0,1]*bufsize
    recvbuf = "?"*bufsize*size
    request = @world.Iallgather(sendbuf, recvbuf)
    str = ""
    size.times{|i| str << i.to_s[0,1]*bufsize}
    request.Wait
    expect(recvbuf).to eql(str)
  end

  it "should gather data of various sizes to all processes (allgatherv)" do
    rank = @world.rank
    size = @world.size
    sendbuf = rank.to_s*(rank+1)
    str = ""
    recvcounts = []
    displs = [0]
    size.times do |i|
      tmp = i.to_s*(i+1)
      str << tmp
      recvcounts.push tmp.length
      displs[i+1] = displs[i] + recvcounts[-1] if i<size-1
    end
    recvbuf = "?"*str.length
    @world.Allgatherv(sendbuf, recvbuf, recvcounts, displs)
    expect(recvbuf).to eql(str)
  end

  it "should gather data of various sizes to all processes without blocking (iallgatherv)" do
    rank = @world.rank
    size = @world.size
    sendbuf = rank.to_s*(rank+1)
    str = ""
    recvcounts = []
    displs = [0]
    size.times do |i|
      tmp = i.to_s*(i+1)
      str << tmp
      recvcounts.push tmp.length
      displs[i+1] = displs[i] + recvcounts[-1] if i<size-1
    end
    recvbuf = "?"*str.length
    request = @world.Iallgatherv(sendbuf, recvbuf, recvcounts, displs)
    request.Wait
    expect(recvbuf).to eql(str)
  end

  it "should broad cast data (bcast)" do
    rank = @world.rank
    root = 0
    bufsize = 2
    if rank == root
      buffer = rank.to_s*bufsize
    else
      buffer = " "*bufsize
    end
    @world.Bcast(buffer, root)
    expect(buffer).to eql(root.to_s*bufsize)
  end

  it "should broad cast data without blocking (ibcast)" do
    rank = @world.rank
    root = 0
    bufsize = 2
    if rank == root
      buffer = rank.to_s*bufsize
    else
      buffer = " "*bufsize
    end
    request = @world.Ibcast(buffer, root)
    request.Wait
    expect(buffer).to eql(root.to_s*bufsize)
  end

  it "should scatter data" do
    rank = @world.rank
    size = @world.size
    root = 0
    bufsize = 2
    if rank == root
      sendbuf = ""
      size.times{|i| sendbuf << i.to_s*bufsize}
    else
      sendbuf = nil
    end
    recvbuf = " "*bufsize
    @world.Scatter(sendbuf, recvbuf, root)
    expect(recvbuf).to eql(rank.to_s*bufsize)
  end

  it "should scatter data without blocking" do
    rank = @world.rank
    size = @world.size
    root = 0
    bufsize = 2
    if rank == root
      sendbuf = ""
      size.times{|i| sendbuf << i.to_s*bufsize}
    else
      sendbuf = nil
    end
    recvbuf = " "*bufsize
    request = @world.Iscatter(sendbuf, recvbuf, root)
    request.Wait
    expect(recvbuf).to eql(rank.to_s*bufsize)
  end

  it "should scatter data of various sizes (scatterv)" do
    rank = @world.rank
    size = @world.size
    root = 0
    if rank == root
      sendbuf = ""
      sendcounts = []
      displs = [0]
      size.times do |i|
        tmp = i.to_s*(i+1)
        sendbuf << tmp
        sendcounts.push tmp.length
        displs[i+1] = displs[i] + sendcounts[-1] if i<size-1
      end
    else
      sendbuf = nil
      sendcounts = nil
      displs = nil
    end
    recvbuf = "?"*rank.to_s.length*(rank+1)
    @world.Scatterv(sendbuf, sendcounts, displs, recvbuf, root)
    expect(recvbuf).to eql(rank.to_s*(rank+1))
  end

  it "should scatter data of various sizes without blocking (iscatterv)" do
    rank = @world.rank
    size = @world.size
    root = 0
    if rank == root
      sendbuf = ""
      sendcounts = []
      displs = [0]
      size.times do |i|
        tmp = i.to_s*(i+1)
        sendbuf << tmp
        sendcounts.push tmp.length
        displs[i+1] = displs[i] + sendcounts[-1] if i<size-1
      end
    else
      sendbuf = nil
      sendcounts = nil
      displs = nil
    end
    recvbuf = "?"*rank.to_s.length*(rank+1)
    request = @world.Iscatterv(sendbuf, sendcounts, displs, recvbuf, root)
    request.Wait
    expect(recvbuf).to eql(rank.to_s*(rank+1))
  end

  it "should send and recv data (sendrecv)" do
    rank = @world.rank
    size = @world.size
    dest = rank-1
    dest = size-1 if dest < 0
    #dest = MPI::PROC_NULL if dest < 0
    source = rank+1
    source = 0 if source > size-1
    #source = MPI::PROC_NULL if source > size-1
    sendtag = 30 + rank
    recvtag = 30 + source
    bufsize = 2
    sendbuf = rank.to_s*bufsize
    recvbuf = " "*bufsize
    @world.Sendrecv(sendbuf, dest, sendtag, recvbuf, source, recvtag);
    if source != MPI::PROC_NULL
      expect(recvbuf).to  eql(source.to_s*bufsize)
    end
  end

  it "should change data between each others (alltoall)" do
    rank = @world.rank
    size = @world.size
    bufsize = 2
    sendbuf = rank.to_s*bufsize*size
    recvbuf = "?"*bufsize*size
    @world.Alltoall(sendbuf, recvbuf)
    str = ""
    size.times{|i| str << i.to_s*bufsize}
    expect(recvbuf).to eql(str)
  end

  it "should change data between each others without blocking (ialltoall)" do
    rank = @world.rank
    size = @world.size
    bufsize = 2
    sendbuf = rank.to_s*bufsize*size
    recvbuf = "?"*bufsize*size
    request = @world.Ialltoall(sendbuf, recvbuf)
    str = ""
    size.times{|i| str << i.to_s*bufsize}
    request.Wait
    expect(recvbuf).to eql(str)
  end

  it "should change data of various sizes between each others (alltoallv)" do
    rank = @world.rank
    size = @world.size
    sendbuf = rank.to_s * (rank+1) * size
    sendcounts = Array.new(size)
    sdispls = Array.new(size)
    len = rank.to_s.length * (rank+1)
    size.times do |i|
      sendcounts[i] = len
      sdispls[i] = len * i
    end
    recvcounts = Array.new(size)
    rdispls = [0]
    str = ""
    size.times do |i|
      tmp = i.to_s * (i+1)
      str << tmp
      recvcounts[i] = tmp.length
      rdispls[i+1] = rdispls[i] + recvcounts[i] if i<size-1
    end
    recvbuf = "?" * str.length
    @world.Alltoallv(sendbuf, sendcounts, sdispls, recvbuf, recvcounts, rdispls)
    expect(recvbuf).to eql(str)
  end

  it "should change data of various sizes between each others without blocking (ialltoallv)" do
    rank = @world.rank
    size = @world.size
    sendbuf = rank.to_s * (rank+1) * size
    sendcounts = Array.new(size)
    sdispls = Array.new(size)
    len = rank.to_s.length * (rank+1)
    size.times do |i|
      sendcounts[i] = len
      sdispls[i] = len * i
    end
    recvcounts = Array.new(size)
    rdispls = [0]
    str = ""
    size.times do |i|
      tmp = i.to_s * (i+1)
      str << tmp
      recvcounts[i] = tmp.length
      rdispls[i+1] = rdispls[i] + recvcounts[i] if i<size-1
    end
    recvbuf = "?" * str.length
    request = @world.Ialltoallv(sendbuf, sendcounts, sdispls, recvbuf, recvcounts, rdispls)
    request.Wait
    expect(recvbuf).to eql(str)
  end

  it "should reduce data" do
    rank = @world.rank
    size = @world.size
    root = 0
    bufsize = 2
    sendbuf = NArray.to_na([rank]*bufsize)
    recvbuf = rank == root ? NArray.new(sendbuf.typecode,bufsize) : nil
    @world.Reduce(sendbuf, recvbuf, MPI::Op::SUM, root)
    if rank == root
      ary = NArray.new(sendbuf.typecode,bufsize).fill(size*(size-1)/2.0)
      expect(recvbuf).to be == ary
    end
  end

  it "should reduce data without blocking" do
    rank = @world.rank
    size = @world.size
    root = 0
    bufsize = 2
    sendbuf = NArray.to_na([rank]*bufsize)
    recvbuf = rank == root ? NArray.new(sendbuf.typecode,bufsize) : nil
    request = @world.Ireduce(sendbuf, recvbuf, MPI::Op::SUM, root)
    if rank == root
      ary = NArray.new(sendbuf.typecode,bufsize).fill(size*(size-1)/2.0)
      request.Wait
      expect(recvbuf).to be == ary
    end
  end

  it "should reduce and scatter data" do
    rank = @world.rank
    size = @world.size
    recvcounts = []
    size.times do |i|
      recvcounts[i] = i+1
    end
    bufsize = recvcounts.inject{|r,i| r+i}
    sendbuf = NArray.to_na([rank]*bufsize)
    recvbuf = NArray.new(sendbuf.typecode,recvcounts[rank])
    @world.Reduce_scatter(sendbuf, recvbuf, recvcounts, MPI::Op::SUM)
    ary = NArray.new(sendbuf.typecode,recvcounts[rank]).fill(size*(size-1)/2.0)
    expect(recvbuf).to be == ary
  end

  it "should reduce and scatter data without blocking" do
    rank = @world.rank
    size = @world.size
    recvcounts = []
    size.times do |i|
      recvcounts[i] = i+1
    end
    bufsize = recvcounts.inject{|r,i| r+i}
    sendbuf = NArray.to_na([rank]*bufsize)
    recvbuf = NArray.new(sendbuf.typecode,recvcounts[rank])
    request = @world.Ireduce_scatter(sendbuf, recvbuf, recvcounts, MPI::Op::SUM)
    ary = NArray.new(sendbuf.typecode,recvcounts[rank]).fill(size*(size-1)/2.0)
    request.Wait
    expect(recvbuf).to be == ary
  end

  it "should reduce and scatter block" do
    rank = @world.rank
    size = @world.size
    recvcount = 2
    sendbuf = NArray.to_na([rank]*(recvcount*size))
    recvbuf = NArray.new(sendbuf.typecode,recvcount)
    @world.Reduce_scatter_block(sendbuf, recvbuf, MPI::Op::SUM)
    ary = NArray.new(sendbuf.typecode,recvcount).fill(size*(size-1)/2.0)
    expect(recvbuf).to be == ary
  end

  it "should reduce and scatter block without blocking" do
    rank = @world.rank
    size = @world.size
    recvcount = 2
    sendbuf = NArray.to_na([rank]*(recvcount*size))
    recvbuf = NArray.new(sendbuf.typecode,recvcount)
    request = @world.Ireduce_scatter_block(sendbuf, recvbuf, MPI::Op::SUM)
    ary = NArray.new(sendbuf.typecode,recvcount).fill(size*(size-1)/2.0)
    request.Wait
    expect(recvbuf).to be == ary
  end

  it "should scan data" do
    rank = @world.rank
    size = @world.size
    count = 2
    sendbuf = NArray.to_na([rank]*count)
    recvbuf = NArray.new(sendbuf.typecode,count)
    @world.Scan(sendbuf, recvbuf, MPI::Op::SUM)
    ary = NArray.new(sendbuf.typecode,count).fill(rank*(rank+1)/2.0)
    expect(recvbuf).to be == ary
  end

  it "should scan data withoug blocking" do
    rank = @world.rank
    size = @world.size
    count = 2
    sendbuf = NArray.to_na([rank]*count)
    recvbuf = NArray.new(sendbuf.typecode,count)
    request = @world.Iscan(sendbuf, recvbuf, MPI::Op::SUM)
    ary = NArray.new(sendbuf.typecode,count).fill(rank*(rank+1)/2.0)
    request.Wait
    expect(recvbuf).to be == ary
  end

  it "should exclusively scan data" do
    rank = @world.rank
    size = @world.size
    count = 2
    sendbuf = NArray.to_na([rank]*count)
    recvbuf = NArray.new(sendbuf.typecode,count)
    @world.Exscan(sendbuf, recvbuf, MPI::Op::SUM)
    if rank > 0
      ary = NArray.new(sendbuf.typecode,count).fill(rank*(rank-1)/2.0)
      expect(recvbuf).to be == ary
    end
  end

  it "should exclusively scan data without blocking" do
    rank = @world.rank
    size = @world.size
    count = 2
    sendbuf = NArray.to_na([rank]*count)
    recvbuf = NArray.new(sendbuf.typecode,count)
    request = @world.Iexscan(sendbuf, recvbuf, MPI::Op::SUM)
    if rank > 0
      ary = NArray.new(sendbuf.typecode,count).fill(rank*(rank-1)/2.0)
      request.Wait
      expect(recvbuf).to be == ary
    end
  end

  it "should reduce data and send to all processes (allreduce)" do
    rank = @world.rank
    size = @world.size
    bufsize = 2
    sendbuf = NArray.to_na([rank]*bufsize)
    recvbuf = NArray.new(sendbuf.typecode,bufsize)
    @world.Allreduce(sendbuf, recvbuf, MPI::Op::SUM)
    ary = NArray.new(sendbuf.typecode,bufsize).fill(size*(size-1)/2.0)
    expect(recvbuf).to be == ary
  end

  it "should reduce data and send to all processes without blocking (iallreduce)" do
    rank = @world.rank
    size = @world.size
    bufsize = 2
    sendbuf = NArray.to_na([rank]*bufsize)
    recvbuf = NArray.new(sendbuf.typecode,bufsize)
    request = @world.Iallreduce(sendbuf, recvbuf, MPI::Op::SUM)
    ary = NArray.new(sendbuf.typecode,bufsize).fill(size*(size-1)/2.0)
    request.Wait
    expect(recvbuf).to be == ary
  end

  it "should not raise exception in calling barrier" do
    @world.Barrier
  end

  it "should not raise exception in calling barrier without blocking" do
    request = @world.Ibarrier
    request.Wait
  end


  it "shoud raise exeption" do
    expect { @world.Send("", @world.size+1, 0) }.to raise_error(MPI::ERR::RANK)
    expect(@world.Errhandler).to eql(MPI::Errhandler::ERRORS_RETURN)
  end

end
