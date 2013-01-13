require "thread"

class ConcurrentHash
  def initialize
    @reader, @writer = {}, {}
    @lock = Mutex.new
  end

  def [](key)
    @reader[key]
  end

  def []=(key, value)
    @lock.synchronize do
      @writer[key] = value
      @reader, @writer = @writer, @reader
      @writer[key] = value
    end
  end

  def delete(key)
    @lock.synchronize do
      @writer.delete(key)
      @reader, @writer = @writer, @reader
      @writer.delete(key)
    end
  end
end


class DeployersManager
  @@deployers = ConcurrentHash.new

  def self.get_deployer(key)
    @@deployers[key]
  end

  def self.add_deployer(key, deployer)
    @@deployers[key] = deployer
  end

  def self.delete_deployer(key)
    @@deployers.delete(key)
  end
end