-- Run after migrations as postgres, inside a rollback transaction. No external provider calls.
begin;
do $$
declare
 u uuid:=gen_random_uuid(); p uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); w uuid:=gen_random_uuid(); t uuid:=gen_random_uuid();
 ctx record; result record; plan jsonb; test_date date:='2026-11-02'; slots jsonb; saved boolean; rev text; d2 uuid:=gen_random_uuid(); claimed uuid[]; due timestamptz;
begin
 insert into auth.users(id) values(u);
 insert into public.plants(id,name,time_zone,price_area) values(p,'Spot import integration fixture','Europe/Stockholm','SE3');
 insert into public.plant_members(plant_id,auth_user_id,role) values(p,u,'owner');
 insert into public.schedule_collections(id,plant_id,name) values(c,p,'test');
 update public.plants set active_schedule_collection_id=c where id=p;
 insert into public.daily_schedules(id,schedule_collection_id,name) values(d,c,'test');
 insert into public.week_schedules(id,schedule_collection_id,name) values(w,c,'test');
 insert into public.week_schedule_day_assignments(week_schedule_id,day_of_week,daily_schedule_id,priority)
 select w,n,d,0 from generate_series(1,7)n;
 perform set_config('request.jwt.claim.sub',u::text,true);
 perform set_config('request.jwt.claim.role','authenticated',true);
 perform public.replace_daily_schedule_segments(d,jsonb_build_array(jsonb_build_object('start_time','08:00','end_time','10:00','peak_shaving_w',6000,'control_kind','spot_import','import_energy_wh',4500)));
 select id into t from public.time_segments where daily_schedule_id=d;
 select * into ctx from public.get_spot_import_work('2026-11-02 00:00Z') x where x.plant_id=p and x.segment_id=t and x.local_date=test_date;
 assert ctx.target_wh=4500 and jsonb_array_length(ctx.slots)=8,'Expected eight eligible quarters';
 assert (ctx.slots->0->>'start')::timestamptz='2026-11-02 07:00Z'::timestamptz,'Local timezone mapping';
 assert not has_function_privilege('authenticated','public.save_spot_import_plan(jsonb)','execute'),'Members cannot generate plans';
 assert not has_table_privilege('authenticated','public.spot_import_plans','insert'),'Members cannot insert generated plans';
 assert not has_table_privilege('authenticated','public.spot_price_cache','select'),'Source cache is service-only';
 begin
  perform public.replace_daily_schedule_segments(d,'[{"start_time":"08:00","end_time":"10:00","peak_shaving_w":6000}]');
  raise exception 'Legacy save unexpectedly accepted';
 exception when others then if sqlerrm='Legacy save unexpectedly accepted' then raise; end if; end;
 begin
  perform public.replace_daily_schedule_segments(d,jsonb_build_array(jsonb_build_object('id',t,'start_time','08:00','end_time','10:00','peak_shaving_w',6000,'control_kind','spot_import','import_energy_wh',12001)));
  raise exception 'Overcapacity unexpectedly accepted';
 exception when check_violation then null; end;
 select jsonb_agg(jsonb_build_object('start',x->>'start','end',x->>'end','selected',n in (1,3,6),'price_per_kwh',n,'energy_wh',case when n in(1,3,6) then 1500 else 0 end) order by n) into slots
 from jsonb_array_elements(ctx.slots) with ordinality q(x,n);
 plan:=jsonb_build_object('plant_id',p,'segment_id',t,'local_date',test_date,'revision_key',ctx.revision_key,'price_area','SE3','peak_shaving_w',6000,'target_wh',4500,'window_start',ctx.window_start,'window_end',ctx.window_end,'status','ready','slots',slots);
 saved:=public.save_spot_import_plan(plan);
 assert saved,'Save current revision';
 assert (select count(*) from public.get_plant_import_plan(p,test_date))=1,'Member can read current plan';
 -- Freeze is clock-driven; simulate an occurrence that has already started.
 update public.spot_import_plans set window_start=now()-interval '1 hour' where plant_id=p;
 assert not public.save_spot_import_plan(plan || jsonb_build_object('slots','[]'::jsonb)),'Started ready plan cannot be overwritten';
 assert (select jsonb_array_length(sp.slots) from public.spot_import_plans sp where sp.plant_id=p)=8,'Frozen quarters preserved';
 update public.spot_import_plans set window_start=(plan->>'window_start')::timestamptz where plant_id=p;
 -- Claiming reserves a separate lease; it must never consume the due boundary.
 update public.plant_runtime set next_due_at=now()+interval '1 minute',lease_until=null where plant_id=p;
 select array_agg(z.plant_id) into claimed from public.claim_due_plants(10000,300) z;
 assert not(p=any(coalesce(claimed,'{}'::uuid[]))),'Future control not claimed early';
 due:=now()-interval '1 minute';
 update public.plant_runtime set next_due_at=due,lease_until=null where plant_id=p;
 select array_agg(z.plant_id) into claimed from public.claim_due_plants(10000,300) z;
 assert p=any(coalesce(claimed,'{}'::uuid[])),'Due control claimed';
 assert (select pr.next_due_at=due and pr.lease_until>now() from public.plant_runtime pr where pr.plant_id=p),'Lease does not overwrite due time';
 select array_agg(z.plant_id) into claimed from public.claim_due_plants(10000,300) z;
 assert not(p=any(coalesce(claimed,'{}'::uuid[]))),'Concurrent claim cannot take active lease';
 assert not public.release_plant_lease(p,now()-interval '1 hour'),'Stale owner cannot release lease';
 assert (select pr.lease_until is not null from public.plant_runtime pr where pr.plant_id=p),'Stale release preserves active lease';
 assert public.release_plant_lease(p,(select pr.lease_until from public.plant_runtime pr where pr.plant_id=p)),'Current owner releases lease';
 select * into result from public.compute_plant_desired_control(p,'2026-11-02 07:00Z');
 assert result.source='spot_import' and result.desired_grid_charging_allowed and result.desired_peak_shaving_w=6000,'Selected quarter charges at cap';
 assert result.next_due_at='2026-11-02 07:15Z'::timestamptz,'Generated next quarter boundary';
 assert (select a.segment_id=t and a.slot_start='2026-11-02 07:00Z'::timestamptz and a.slot_end='2026-11-02 07:15Z'::timestamptz from public.get_spot_import_context(p,'2026-11-02 07:00Z') a),'Audit context identifies occurrence and current interval';
 assert not has_function_privilege('authenticated','public.get_spot_import_context(uuid,timestamptz)','execute'),'Audit context is service-only';
 select * into result from public.compute_plant_desired_control(p,'2026-11-02 07:15Z');
 assert result.source='spot_peak_shave' and not result.desired_grid_charging_allowed and result.desired_peak_shaving_w=6000,'Unselected quarter only peak shaves';
 insert into public.overrides(plant_id,created_by_auth_user_id,starts_at,ends_at,peak_shaving_w,is_active)
 values(p,u,'2026-11-02 07:00Z','2026-11-02 07:30Z',2000,true);
 select * into result from public.compute_plant_desired_control(p,'2026-11-02 07:15Z');
 assert result.source='override' and result.desired_peak_shaving_w=2000 and not result.desired_grid_charging_allowed,'Partial override uses generated base';
 update public.overrides set is_active=false where plant_id=p;
 insert into public.overrides(plant_id,created_by_auth_user_id,starts_at,until_next_segment,peak_shaving_w,is_active)
 values(p,u,'2026-11-02 07:00Z',true,2000,true);
 select * into result from public.compute_plant_desired_control(p,'2026-11-02 07:00Z');
 assert result.source='override' and result.desired_grid_charging_allowed and result.next_due_at='2026-11-02 07:15Z'::timestamptz,'Partial until-next override retains selected-quarter boundary';
 select * into result from public.compute_plant_desired_control(p,'2026-11-02 07:15Z');
 assert result.source='override' and not result.desired_grid_charging_allowed and result.next_due_at='2026-11-02 07:30Z'::timestamptz,'Partial until-next override follows unselected quarter';
 assert exists(select 1 from public.overrides o where o.plant_id=p and o.is_active and o.until_next_segment),'Quarter boundary does not expire configured-window override';
 update public.overrides set is_active=false where plant_id=p;
 rev:=ctx.revision_key;
 perform public.replace_daily_schedule_segments(d,jsonb_build_array(jsonb_build_object('id',t,'start_time','08:00','end_time','10:00','peak_shaving_w',6000,'control_kind','spot_import','import_energy_wh',6000)));
 assert exists(select 1 from public.time_segments where id=t),'Identity stable on save';
 assert exists(select 1 from public.spot_import_plans where segment_id=t),'Budget ledger survives save';
 assert not public.save_spot_import_plan(plan),'Stale revision rejected';
 select * into result from public.compute_plant_desired_control(p,'2026-11-02 07:00Z');
 assert not result.desired_grid_charging_allowed and result.source='spot_waiting_prices','Stale plan cannot charge';
 insert into public.daily_schedules(id,schedule_collection_id,name) values(d2,c,'Higher priority');
 insert into public.time_segments(daily_schedule_id,start_time,end_time,peak_shaving_w,grid_charging_allowed) values(d2,'08:15','08:30',1000,false);
 insert into public.week_schedule_day_assignments(week_schedule_id,day_of_week,daily_schedule_id,priority) values(w,1,d2,1);
 select * into ctx from public.get_spot_import_work('2026-11-02 00:00Z') x where x.plant_id=p and x.segment_id=t and x.local_date=test_date;
 assert not (ctx.slots->1->>'eligible')::boolean and (ctx.slots->0->>'eligible')::boolean,'Higher priority excludes only its own quarters';
 select * into result from public.compute_plant_desired_control(p,'2026-11-02 07:15Z');
 assert result.source='schedule' and result.desired_peak_shaving_w=1000,'Higher priority fixed controls take precedence';
 begin
  update public.plants set price_area=null where id=p;
  raise exception 'Missing price area unexpectedly accepted';
 exception when others then if sqlerrm='Missing price area unexpectedly accepted' then raise; end if; end;
 perform public.replace_daily_schedule_segments(d,jsonb_build_array(jsonb_build_object('id',t,'start_time','02:00','end_time','02:30','peak_shaving_w',6000,'control_kind','spot_import','import_energy_wh',1500)));
 select * into result from public.compute_plant_desired_control(p,'2026-10-25 00:30Z');
 assert result.source='default' and result.next_due_at<='2026-10-25 01:00Z'::timestamptz,'Fall-back inactive gap must wake before repeated window';
 select * into result from public.compute_plant_desired_control(p,'2026-10-25 01:00Z');
 assert result.source='spot_waiting_prices','Repeated local spot window resolves again';
 perform public.replace_daily_schedule_segments(d,jsonb_build_array(jsonb_build_object('id',t,'start_time','00:00','end_time','24:00','peak_shaving_w',6000,'control_kind','spot_import','import_energy_wh',4500)));
 select * into ctx from public.get_spot_import_work('2026-10-25 00:00Z') x where x.plant_id=p and x.local_date='2026-10-25';
 assert jsonb_array_length(ctx.slots)=100,'Autumn DST has 100 distinct UTC quarters';
 select * into ctx from public.get_spot_import_work('2026-03-29 00:00Z') x where x.plant_id=p and x.local_date='2026-03-29';
 assert jsonb_array_length(ctx.slots)=92,'Spring DST has 92 quarters';
 -- The all-day segment above is active at now() regardless of the test host date.
 begin
  update public.plants set time_zone='UTC' where id=p;
  raise exception 'Active timezone edit unexpectedly accepted';
 exception when others then
  if sqlerrm<>'Change time zone outside active spot-import windows' then raise; end if;
 end;
 assert (select z.time_zone='Europe/Stockholm' from public.plants z where z.id=p),'Rejected timezone edit preserves occurrence date';
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 begin
  perform public.get_plant_import_plan(p,test_date);
  raise exception 'Nonmember read unexpectedly accepted';
 exception when others then if sqlerrm='Nonmember read unexpectedly accepted' then raise; end if; end;
 raise notice 'Spot import database integration assertions passed';
end $$;
rollback;
