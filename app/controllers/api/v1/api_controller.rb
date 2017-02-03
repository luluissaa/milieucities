class Api::V1::ApiController < ActionController::API
  include CanCan::ControllerAdditions
  before_action :set_locale


  # rescue_from CanCan::AccessDenied do |exception|
  #   respond_to do |format|
  #     format.json { render json: {}, status: 403 }
  #   end
  # end

  def default_url_options(options = {})
    { locale: I18n.locale }.merge options
  end

  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end


  private

  def authenticate_request
    @current_user = AuthorizeApiRequest.call(request.headers).result
    render json: {error: 401, description: 'Not Authorized'}, status: 401 unless @current_user
  end
end
