require "test/unit"

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require "mpi/utils"

class TestMPIUtils < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_task_divide
    [[4,1], [6,3], [7,3], [15,4], [3, 7]].each do |m, size|
      ary = MPI.task_divide(m, size)
      assert ary.max-ary.min <= 1
    end
  end

end
