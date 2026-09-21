alias ClimbOntario.Catalogue.Import
manifest = Jason.decode!(File.read!("/workspace/dot-files/knowledge/ontario-gyms/luna-conversion-assignments.json"))
allowed = MapSet.new((manifest["1"]["first_ten"] |> Enum.map(& &1["id"])) ++ manifest["1"]["remaining_ids"])
targets = MapSet.new([286,287,288,289,290,291,292,293,294,295])
unless MapSet.subset?(targets, allowed), do: raise "target subset is outside worker 1 manifest"
p = fn a,s -> case Import.put_listing(a,s) do {:ok,_}->:ok; {:error,c}->raise "#{inspect(a.id)} #{inspect(c.errors)}" end end
d = fn xs -> Enum.map(xs,&Date.from_iso8601!/1) end
fri=d.(~w[2026-09-18 2026-09-25 2026-10-02 2026-10-16 2026-10-23 2026-10-30 2026-11-06 2026-11-13 2026-11-20 2026-11-27])
sun=d.(~w[2026-09-20 2026-09-27 2026-10-04 2026-10-18 2026-10-25 2026-11-01 2026-11-08 2026-11-15 2026-11-22 2026-11-29])
mon=d.(~w[2026-09-21 2026-09-28 2026-10-05 2026-10-19 2026-10-26 2026-11-02 2026-11-09 2026-11-16 2026-11-23 2026-11-30])
wed=d.(~w[2026-09-23 2026-09-30 2026-10-07 2026-10-21 2026-10-28 2026-11-04 2026-11-11 2026-11-18 2026-11-25 2026-12-02])
tue=d.(~w[2026-09-22 2026-09-29 2026-10-06 2026-10-20 2026-10-27 2026-11-03 2026-11-10 2026-11-17 2026-11-24 2026-12-01])
base = fn id, title, summary, ages, cohorts, sd, ed -> %{id: id, title: title, summary: summary, ages: ages, cohorts: cohorts, kind: "class", schedule_kind: "course", start_date: sd, end_date: ed, audience: ["youth"]} end
putco = fn attrs, rows -> p.(attrs, Enum.flat_map(rows, fn {name, ds, st, et} -> Enum.map(ds, &%{date: &1, cohort: name, start_time: st, end_time: et}) end)) end
putco.(base.(286,"Senior Crushers — Fall 2026","Recreational youth climbing for children born 2010–2015.","Born 2010–2015",["Friday 18:15","Sunday 10:15","Monday 19:45","Wednesday 17:00"],~D[2026-09-18],~D[2026-12-02]), [{"Friday 18:15",fri,~T[18:15:00],~T[19:15:00]},{"Sunday 10:15",sun,~T[10:15:00],~T[11:15:00]},{"Monday 19:45",mon,~T[19:45:00],~T[20:45:00]},{"Wednesday 17:00",wed,~T[17:00:00],~T[18:00:00]}])
putco.(base.(287,"Lemurs Level 1 — Fall 2026","Beginner youth climbing development for children born 2018–2021.","Born 2018–2021",["Friday 18:15"],~D[2026-09-18],~D[2026-11-27]), [{"Friday 18:15",fri,~T[18:15:00],~T[19:15:00]}])
putco.(base.(288,"Lemurs Level 2 — Fall 2026","Intermediate youth climbing development for children born 2018–2021.","Born 2018–2021",["Monday 18:15"],~D[2026-09-21],~D[2026-11-30]), [{"Monday 18:15",mon,~T[18:15:00],~T[19:15:00]}])
putco.(base.(289,"Chimpanzees Level 1 — Fall 2026","Beginner youth climbing development for children born 2014–2017.","Born 2014–2017",["Tuesday 18:15","Wednesday 18:15"],~D[2026-09-22],~D[2026-12-02]), [{"Tuesday 18:15",tue,~T[18:15:00],~T[19:15:00]},{"Wednesday 18:15",wed,~T[18:15:00],~T[19:15:00]}])
putco.(base.(290,"Chimpanzees Level 2 — Fall 2026","Intermediate youth climbing development for children born 2014–2017.","Born 2014–2017",["Tuesday 18:15","Thursday 18:15"],~D[2026-09-22],~D[2026-12-03]), [{"Tuesday 18:15",tue,~T[18:15:00],~T[19:15:00]},{"Thursday 18:15",d.(~w[2026-09-24 2026-10-01 2026-10-08 2026-10-22 2026-10-29 2026-11-05 2026-11-12 2026-11-19 2026-11-26 2026-12-03]),~T[18:15:00],~T[19:30:00]}])
for {id,title,ages,ds,st,et,sd,ed} <- [{293,"Gorillas Level 2 — Fall 2026","Born 2010–2013",mon,~T[19:30:00],~T[20:45:00],~D[2026-09-21],~D[2026-11-30]},{294,"Gorillas Level 3 — Fall 2026","Born 2010–2013",d.(~w[2026-09-24 2026-10-01 2026-10-08 2026-10-22 2026-10-29 2026-11-05 2026-11-12 2026-11-19 2026-11-26 2026-12-03]),~T[20:00:00],~T[21:15:00],~D[2026-09-24],~D[2026-12-03]},{295,"Teen Boulder Club — Fall 2026","Born 2010–2015",wed,~T[18:15:00],~T[19:15:00],~D[2026-09-23],~D[2026-12-02]}] do putco.(base.(id,title,title<>".",ages,["Primary cohort"],sd,ed),[{"Primary cohort",ds,st,et}]) end
p.(%{id: 291, schedule_kind: "unscheduled", start_date: nil, end_date: nil, start_time: nil, end_time: nil, recurrence: nil, weekday: nil, cohorts: []},:preserve)
p.(%{id: 292, schedule_kind: "unscheduled", start_date: nil, end_date: nil, start_time: nil, end_time: nil, recurrence: nil, weekday: nil, cohorts: []},:preserve)
IO.puts("repaired Junction IDs 286-295")
