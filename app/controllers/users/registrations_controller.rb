class Users::RegistrationsController < Devise::RegistrationsController
  def new
    redirect_to new_user_session_path, alert: "Cadastro desabilitado. Contate o administrador."
  end

  def create
    redirect_to new_user_session_path, alert: "Cadastro desabilitado. Contate o administrador."
  end

  protected

  def after_sign_up_path_for(resource)
    dashboard_path
  end
end
