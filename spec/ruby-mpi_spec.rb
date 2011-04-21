require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Mpi" do
  before(:all) do
    MPI.Init()
  end
  after(:all) do
    MPI.Finalize()
  end
  it "should have Comm:WORLD" do
    MPI::Comm.constants.should include("WORLD")
    world = MPI::Comm::WORLD
    world.rank.class.should eql(Fixnum)
    world.size.class.should eql(Fixnum)
    world.size.should > 0
  end

  it "should be able to send and receive String" do
    world = MPI::Comm::WORLD
    message = "Hello from #{world.rank}"
    tag = 0
    world.Send(message, 0, tag)
    if world.rank == 0
      world.size.times do |i|
        str = " "*30
        err, status = world.Recv(str, i, tag)
        err.should eql(MPI::SUCCESS)
        status.source.should eql(0)
        status.tag.should eql(tag)
        status.error.should eq(MPI::SUCCESS)
        str.should match(/\AHello from #{i}+/)
      end
    end
  end

  it "should be able to send and receive NArray" do
    world = MPI::Comm::WORLD
    tag = 0
    [NArray[1,2,3], NArray[3.0,2.0,1.0]].each do |ary0|
      ary0 = NArray[1,2,3]
      world.Send(ary0, 0, tag)
      if world.rank == 0
        world.size.times do |i|
          ary1 = NArray.new(ary0.typecode, ary0.total)
          err, status = world.Recv(ary1, i, tag)
          err.should eql(MPI::SUCCESS)
          status.source.should eql(0)
          status.tag.should eql(tag)
          status.error.should eq(MPI::SUCCESS)
          ary1.should == ary0
        end
      end
    end
  end
end
