class Array
  def to_hash
    result = {}
    each { |hash, pair| result[hash] = pair }
    result
  end

  def index_by
    map { |n| [yield(n), n] }.to_hash
  end

  def subarray_count(subarray)
    each_cons(subarray.length).count(subarray)
  end

  def occurences_count
    result = Hash.new(0)
    each { |item| result[item] = count(item) }
    result
  end
end