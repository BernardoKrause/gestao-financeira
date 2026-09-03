class Users::RegistrationsController < Devise::RegistrationsController
  def create
    super do |resource|
      UserOnboarding.call(resource) if resource.persisted?
    end
  end

  protected

  def after_sign_up_path_for(resource)
    dashboard_path
  end
end
