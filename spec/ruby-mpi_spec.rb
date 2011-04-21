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
    message = "Hello"
    world.Send(message, 0, 0)
    str = " "*(message.length)
    world.Recv(str, 0, 0)
    str.should eql(message)
  end

  it "should be able to send and receive NArray" do
    world = MPI::Comm::WORLD
    ary0 = NArray[1,2,3]
    world.Send(ary0, 0, 0)
    ary1 = NArray.new(ary0.typecode, ary0.total)
    world.Recv(ary1, 0, 0)
    ary1.should == ary0
  end
end
