defmodule ClimbOntario.StatsHealthzTest do
  use ClimbOntario.DataCase, async: false
  alias ClimbOntario.{Repo, Stats}

  test "health checks are never counted; a page view is" do
    before = Repo.aggregate(Stats.PageView, :count)
    assert Stats.track(%{path: "/healthz", ip: "1.2.3.4", user_agent: "Consul Health Check"}) == :skipped
    assert Stats.track(%{path: "/healthz?x=1", ip: "1.2.3.4", user_agent: "Mozilla/5.0"}) == :skipped
    assert Stats.track(%{path: "/", ip: "1.2.3.4", user_agent: "Mozilla/5.0 (iPhone)"}) == :ok
    assert Repo.aggregate(Stats.PageView, :count) == before + 1
  end
end
