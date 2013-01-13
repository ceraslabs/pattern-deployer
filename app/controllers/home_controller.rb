class HomeController < ApplicationController

  def index
    if user_signed_in?
      redirect_to edit_user_registration_path(current_user)
    else
      resource = User.new
      redirect_to new_user_session_path(resource)
    end
    return
  end
end
