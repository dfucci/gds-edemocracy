defmodule ExVoteWeb.UserController do
  use ExVoteWeb, :controller

  alias ExVote.Accounts

  def login(%{:method => "GET"} = conn, params) do
    # TODO: Create changeset_login
    changeset = Accounts.User.changeset_create(%Accounts.User{}, params)

    conn
    |> assign(:changeset, changeset)
    |> render("login.html")
  end

  def login(conn, %{"user" => user} = params) do
    case ExVote.Accounts.login(user) do
      {:ok, user} ->
        conn
        |> put_session(:user, user)
        |> put_flash(:info, "Login success!")
        |> redirect(to: "/")
      {:error, changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("login.html")
    end
  end

  def logout(conn, _params) do
    conn
    |> delete_session(:user)
    |> redirect(to: "/")
  end
end