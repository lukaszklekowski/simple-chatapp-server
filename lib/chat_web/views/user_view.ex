defmodule ChatWeb.UserView do
  use ChatWeb, :view
  alias ChatWeb.UserView

  def render("login.json", %{refresh_token: refresh_token, token: token}) do
    %{code: 200, token: token,
    refresh_token: refresh_token}
  end

  def render("token.json", %{token: token}) do
    %{code: 200, token: token}
  end

  def render("error.json", %{code: code, message: message}) do
    %{code: code,
      message: message}
  end
end