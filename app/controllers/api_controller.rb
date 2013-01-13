class ApiController < RestfulController

  skip_load_and_authorize_resource

  rescue_from ActiveRecord::RecordNotFound, :with => :render_404

  ##
  # Show a list of resources
  #
  # @url [GET] /api
  # 
  # @example_response
  # TODO
  def index
    render :formats => "xml"
  end
end
