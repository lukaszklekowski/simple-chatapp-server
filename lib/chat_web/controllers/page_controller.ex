defmodule ChatWeb.PageController do
  use ChatWeb, :controller

  def index(conn, _params) do
    redirect conn, external: "/"
#    render conn, "index.html"
  end
end
