module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    def google_oauth2
      handle_auth("Google")
    end

    def apple
      handle_auth("Apple")
    end

    def failure
      redirect_to new_user_session_path, alert: "Não foi possível autenticar com o provedor."
    end

    private

    def handle_auth(kind)
      @user = User.from_omniauth(request.env["omniauth.auth"])

      if @user.persisted?
        sign_in_and_redirect @user, event: :authentication
        set_flash_message(:notice, :success, kind: kind) if is_navigational_format?
      else
        redirect_to new_user_registration_path, alert: "Não foi possível autenticar com #{kind}."
      end
    end
  end
end
