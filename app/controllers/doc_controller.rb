class DocController < ActionController::Base
  def index
    @url = nil
    open("http://169.254.169.254/latest/meta-data/public-hostname") do |output|
      host_name = output.read
      raise "Cannot read host name" if host_name.nil? || host_name.empty?
      if request.port == 80
        @url = "http://" + host_name
      else
        @url = "http://" + host_name + ":" + request.port.to_s
      end
    end
  end
end
