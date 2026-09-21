defmodule ClimbOntario.Catalogue.Import do
  @moduledoc "Atomic, validated partial listing updates and explicit replacement of confirmed sessions."
  import Ecto.Query
  import Ecto.Changeset
  alias ClimbOntario.Repo
  alias ClimbOntario.Catalogue.{Listing, Occurrence}

  @doc "Omitted sessions preserve; an explicit list replaces (including []). Returns {:ok, listing} or {:error, changeset}."
  def put_listing(attrs, sessions \\ :preserve) do
    Repo.transaction(fn ->
      identity = cast(%Listing{}, attrs, [:id])
      unless identity.valid?, do: Repo.rollback(identity)
      id = get_field(identity, :id)
      existing = if id, do: Repo.get(Listing, id), else: nil

      old_sessions =
        if existing, do: Repo.all(from o in Occurrence, where: o.listing_id == ^id), else: []

      cs = Listing.changeset(existing || %Listing{}, attrs)
      cs = legacy_location(cs, attrs)

      # label survives the original DB constraint, but is now code-owned and never displayed verbatim.
      cs = if get_field(cs, :kind), do: put_change(cs, :label, get_field(cs, :kind)), else: cs
      unless cs.valid?, do: Repo.rollback(cs)
      listing = apply_changes(cs)
      session_changesets = session_changesets(sessions, old_sessions, listing)
      cs = validate_evidence(cs, session_changesets)
      unless cs.valid?, do: Repo.rollback(cs)
      Enum.each(session_changesets, fn s -> unless s.valid?, do: Repo.rollback(s) end)

      changed_sessions =
        canonical(old_sessions) != canonical(Enum.map(session_changesets, &apply_changes/1))

      substantive =
        Map.drop(cs.changes, [:sources, :checked_on, :label, :schedule_note]) != %{} or
          changed_sessions

      cs =
        if substantive,
          do: put_change(cs, :catalogue_updated_on, ClimbOntario.Clock.today()),
          else: cs

      listing = save!(cs)

      if sessions != :preserve do
        Repo.delete_all(from o in Occurrence, where: o.listing_id == ^listing.id)
        Enum.each(session_changesets, &save!/1)
      end

      Repo.preload(listing, [:venue, occurrences: :venue], force: true)
    end)
  end

  def publish(id), do: put_listing(%{id: id, published: true})

  defp save!(cs) do
    case Repo.insert_or_update(cs) do
      {:ok, row} -> row
      {:error, invalid} -> Repo.rollback(invalid)
    end
  rescue
    # SQLite reports foreign-key failures without a constraint name, so Ecto cannot
    # attach them using foreign_key_constraint/3. Keep the transaction's error contract.
    Ecto.ConstraintError ->
      Repo.rollback(add_error(cs, :base, "violates a database integrity constraint"))
  end

  defp legacy_location(cs, attrs) do
    explicit = Map.has_key?(attrs, :location_kind) or Map.has_key?(attrs, "location_kind")

    if not explicit and get_change(cs, :offsite_name),
      do: put_change(cs, :location_kind, "offsite"),
      else: cs
  end

  defp session_changesets(:preserve, old, listing) do
    Enum.map(old, &Occurrence.changeset(&1, %{}, listing))
  end

  defp session_changesets(sessions, _, listing) when is_list(sessions) do
    Enum.map(sessions, fn session ->
      attrs =
        case session do
          %Date{} = d ->
            %{date: d}

          d when is_binary(d) ->
            %{date: d}

          m when is_map(m) and not is_struct(m) ->
            m

          _ ->
            Repo.rollback(
              add_error(change(%Occurrence{}), :date, "must be a date or session map")
            )
        end

      # Normalize known keys without creating atoms from input. Missing times use listing defaults;
      # explicit nil means unknown. Persist the snapshot, so later partial updates cannot move sessions.
      normalized =
        for key <- Occurrence.fields(), reduce: %{} do
          acc ->
            cond do
              Map.has_key?(attrs, key) ->
                Map.put(acc, key, attrs[key])

              Map.has_key?(attrs, Atom.to_string(key)) ->
                Map.put(acc, key, attrs[Atom.to_string(key)])

              key in [:start_time, :end_time, :timezone] ->
                Map.put(acc, key, Map.get(listing, key))

              true ->
                acc
            end
        end

      Occurrence.changeset(%Occurrence{}, normalized, listing)
    end)
  end

  defp session_changesets(_, _, _),
    do: Repo.rollback(add_error(change(%Occurrence{}), :date, "sessions must be a list"))

  defp validate_evidence(cs, sessions) do
    cs =
      if get_field(cs, :published) and get_field(cs, :schedule_kind) == "recurring" and
           get_field(cs, :recurrence) == nil and sessions == [],
         do:
           add_error(
             cs,
             :recurrence,
             "publishing recurring requires a structured pattern or confirmed sessions"
           ),
         else: cs

    cs =
      if get_field(cs, :schedule_kind) == "unscheduled" and
           ((sessions != [] or get_field(cs, :start_date)) || get_field(cs, :end_date) ||
              get_field(cs, :start_time) || get_field(cs, :end_time)),
         do: add_error(cs, :schedule_kind, "unscheduled must not carry dates or times"),
         else: cs

    rows = Enum.map(sessions, &apply_changes/1)

    cs =
      Enum.reduce(get_field(cs, :complete_cohorts), cs, fn cohort, cs ->
        name = if cohort == "__unnamed__", do: nil, else: cohort

        if Enum.any?(rows, &(&1.cohort == name)),
          do: cs,
          else:
            add_error(cs, :complete_cohorts, "each complete group must have confirmed sessions")
      end)

    if length(Enum.uniq(canonical(rows))) != length(rows),
      do: add_error(cs, :occurrences, "contains duplicate sessions"),
      else: cs
  end

  defp canonical(rows), do: rows |> Enum.map(&Map.take(&1, Occurrence.fields())) |> Enum.sort()
end
