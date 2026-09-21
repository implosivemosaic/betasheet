defmodule ClimbOntarioWeb.InterestTest do
  use ClimbOntarioWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog
  alias ClimbOntario.{Interest, Repo}

  test "inherits editable criteria, validates email and consent, saves privately and deduplicates",
       %{conn: conn} do
    {:ok, view, _} = live(conn, "/?near=Aurora&km=100&kind=ocf,class&for=youth")
    view |> element("button", "Get updates like these") |> render_click()
    assert has_element?(view, "input[name='interest[location]'][value='Aurora']")
    assert has_element?(view, "input[name='interest[radius_km]'][value='100']")
    assert has_element?(view, "select[name='interest[kinds][]'] option[value='ocf'][selected]")

    assert has_element?(
             view,
             "select[name='interest[audience][]'] option[value='youth'][selected]"
           )

    assert render(view) =~ "Updates are not sending yet"

    attrs = %{
      email: "not-email",
      location: "Toronto",
      radius_km: "40",
      kinds: ["class"],
      audience: ["adult"],
      consent: "true"
    }

    view |> form("#interest-form", interest: attrs) |> render_submit()
    assert Repo.aggregate(Interest, :count) == 0

    view
    |> form("#interest-form", interest: %{attrs | email: "private@example.org", consent: "false"})
    |> render_submit()

    assert Repo.aggregate(Interest, :count) == 0

    logs =
      capture_log([level: :debug], fn ->
        view
        |> form("#interest-form", interest: %{attrs | email: "private@example.org"})
        |> render_submit()
      end)

    refute logs =~ "private@example.org"
    assert render(view) =~ "Interest saved. No emails sent. This is not a subscription."
    refute render(view) =~ "private@example.org"
    row = Repo.one!(Interest)
    assert row.email == "private@example.org"
    assert row.location == "Toronto"
    assert row.radius_km == 40
    assert row.kinds == ["class"]
    assert row.audience == ["adult"]
    assert row.consented_at
    assert :ok = Interest.save(%{attrs | email: " PRIVATE@example.org "})
    assert Repo.aggregate(Interest, :count) == 1
    assert Repo.one!(Interest).consented_at == row.consented_at
    assert :ok = Interest.save(%{attrs | email: "private@example.org", kinds: ["camp"]})
    assert Repo.aggregate(Interest, :count) == 2
    {:ok, _, public} = live(recycle(conn), "/")
    refute public =~ "private@example.org"
    refute function_exported?(Interest, :send_email, 1)
    refute Code.ensure_loaded?(ClimbOntario.Mailer)
  end

  test "unknown criteria fail; blank selection means province-wide interest" do
    attrs = %{email: "valid@example.org", consent: true}

    for extra <- [
          %{location: "zzqx"},
          %{radius_km: -1},
          %{kinds: ["bogus"]},
          %{audience: ["bogus"]}
        ] do
      assert {:error, _} = Interest.save(Map.merge(attrs, extra))
    end

    assert :ok = Interest.save(Map.merge(attrs, %{location: "", kinds: [""], audience: [""]}))
    assert Repo.one!(Interest).kinds == []
  end

  test "preview gate disables capture and server writes", %{conn: conn} do
    Application.put_env(:climb_ontario, :preview_interest, false)
    on_exit(fn -> Application.put_env(:climb_ontario, :preview_interest, true) end)
    {:ok, _, html} = live(conn, "/")
    refute html =~ "Get updates like these"
    assert {:error, :disabled} = Interest.save(%{email: "valid@example.org", consent: true})
    assert Repo.aggregate(Interest, :count) == 0
  end
end
