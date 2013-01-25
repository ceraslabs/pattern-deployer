class DocController < ActionController::Base

  def index
    @url = request.protocol + request.host_with_port
  end

end