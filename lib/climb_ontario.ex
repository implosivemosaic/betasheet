defmodule ClimbOntario do
  @moduledoc """
  ClimbOntario keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc "The public contact address shown on the site."
  def contact_email, do: Application.get_env(:climb_ontario, :contact_email)
end
