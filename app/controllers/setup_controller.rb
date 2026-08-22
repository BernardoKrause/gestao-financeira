class SetupController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :redirect_if_setup_complete

  def new
    @user = User.new
  end

  def create
    @user = User.new(setup_params)
    if @user.save
      sign_in(@user)
      redirect_to root_path, notice: "Conta criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def redirect_if_setup_complete
    redirect_to new_user_session_path, alert: "Configuração já concluída." if User.exists?
  end

  def setup_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
