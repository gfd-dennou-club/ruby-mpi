module MPI

  module_function

  def task_divide(m, size)
    dm = m.to_f/size
    ary = Array.new(size)
    ary[0] = dm.round
    sum = ary[0]
    (size-1).times do|i|
      ary[i+1] = (dm*(i+2)).round - sum
      sum += ary[i+1]
    end
    ary
  end

end # module MPI
