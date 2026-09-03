class Users::RegistrationsController < Devise::RegistrationsController
  def create
    super do |resource|
      UserOnboarding.call(resource) if resource.persisted?
    end
  end
end
