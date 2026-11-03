/// Builds 30 days of synthetic traffic by sending real HL7 messages through the real production,
/// then moving each session's timestamps back. Message Viewer, Visual Trace and the SQL evidence all see ordinary messages.
/// All names and identifiers are invented. The counts are deterministic, so tests and the replay fixtures can rely on them.
Class DemoHospital.Seed Extends %RegisteredObject
{

/// Orders per day for the five feeds that moved to LAB-NEW.
Parameter FEEDS = "orders-ed:10,orders-inpatient:14,orders-surgery:4,orders-oncology:3,orders-outpatient:7";

/// Days ago the five feeds were moved.
Parameter MOVEDAYSAGO = 27;

/// Messages annex-7 sends in the 30-day window, and how many of them carry two orders.
Parameter ANNEXTOTAL = 41;

Parameter ANNEXMULTI = 3;

/// How many annex-7 messages are left waiting in the LAB-OLD.Out queue.
Parameter QUEUED = 4;

ClassMethod Run() As %Status
{
	set sc=$$$OK
	try {
		set t0=$zh
		kill ^||plan
		set now=$ztimestamp, today=+now
		set n=0
		do ..PlanFeeds(today,.n)
		do ..PlanAdt(today,.n)
		set annexLast=..PlanAnnex(today,.n)
		$$$ThrowOnError(##class(Ens.Director).EnableConfigItem("LAB-OLD.Out",1,1))
		$$$ThrowOnError(..SendPlan())
		$$$ThrowOnError(..WaitForQueues(180))
		do ..Backdate()
		$$$ThrowOnError(..QueueTail(annexLast))
		set ^BlastRadius.Seed("done")=$zdatetime($ztimestamp,3)
		set ^BlastRadius.Seed("messages")=n
		write "seeded ",n," sessions in ",$fnumber($zh-t0,"",1),"s",!
	} catch ex { set sc=ex.AsStatus() }
	quit sc
}

/// A cheap repeatable pseudo-random number in 0..(pMax-1), so the same counts come out every run.
ClassMethod Rand(ByRef pState As %Integer, pMax As %Integer) As %Integer
{
	set pState=((pState*1103515245)+12345)#2147483648
	quit pState\65536#pMax
}

ClassMethod PlanFeeds(pToday As %Integer, ByRef pN As %Integer)
{
	set state=20261103
	set feeds=..#FEEDS
	for i=1:1:$length(feeds,",") {
		set feed=$piece($piece(feeds,",",i),":",1), perDay=$piece($piece(feeds,",",i),":",2)
		for dayAgo=30:-1:1 {
			set target=$select(dayAgo>..#MOVEDAYSAGO:"LAB-OLD.Router",1:"LAB-NEW.Router")
			for k=1:1:perDay {
				set secs=(6*3600)+(..Rand(.state,14*3600))
				do ..AddPlan(.pN,feed,target,pToday-dayAgo,secs,..OrderMessage(pN,feed,pToday-dayAgo,secs,1,.state))
			}
		}
	}
}

ClassMethod PlanAdt(pToday As %Integer, ByRef pN As %Integer)
{
	set state=7
	for dayAgo=30:-1:1 {
		for k=1:1:8 {
			set secs=..Rand(.state,86400)
			do ..AddPlan(.pN,"adt-feed","ADT.Router",pToday-dayAgo,secs,..AdtMessage(pN,pToday-dayAgo,secs,.state))
		}
	}
}

/// Every Tuesday at about 06:00. Returns the date of the last batch, so the queued tail can sit on it.
ClassMethod PlanAnnex(pToday As %Integer, ByRef pN As %Integer) As %Integer
{
	set state=77
	set tuesdays=0
	for d=pToday-29:1:pToday-1 { if $zdate(d,10)=2 { set tuesdays=tuesdays+1, tuesdays(tuesdays)=d } }
	set total=..#ANNEXTOTAL-..#QUEUED
	set perWeek=total\tuesdays, extra=total#tuesdays
	set multiLeft=..#ANNEXMULTI
	for w=1:1:tuesdays {
		set day=tuesdays(w), count=perWeek+$select(w>(tuesdays-extra):1,1:0)
		for k=1:1:count {
			set orders=1
			if (multiLeft>0),(k=3) { set orders=2, multiLeft=multiLeft-1 }
			set secs=(6*3600)+(k*20)
			do ..AddPlan(.pN,"annex-7","LAB-OLD.Router",day,secs,..OrderMessage(pN,"annex-7",day,secs,orders,.state))
		}
	}
	quit tuesdays(tuesdays)
}

ClassMethod AddPlan(ByRef pN As %Integer, pFeed As %String, pTarget As %String, pDay As %Integer, pSecs As %Integer, pRaw As %String)
{
	set pN=pN+1
	set ^||plan(pDay,pSecs,pN)=$listbuild(pFeed,pTarget,pRaw)
}

ClassMethod OrderMessage(pN As %Integer, pFeed As %String, pDay As %Integer, pSecs As %Integer, pOrders As %Integer, ByRef pState As %Integer) As %String
{
	set ts=$translate($zdate(pDay,8)_$ztime(pSecs,1),":","")
	set app=$zconvert(pFeed,"U")
	set mrn=100000+..Rand(.pState,800000)
	set seg="MSH|^~\&|"_app_"|DEMOHOSP|LAB|DEMOHOSP|"_ts_"||ORM^O01|S"_pN_"|P|2.5"_$char(13)
	set seg=seg_"PID|1||"_mrn_"^^^DEMOHOSP^MR||PATIENT^TEST"_mrn_"||19700101|U"_$char(13)
	set codes="GLU^Glucose^L,CBC^Blood count^L,K^Potassium^L,TSH^Thyroid^L"
	for i=1:1:pOrders {
		set order="ORD"_pN_"-"_i
		set seg=seg_"ORC|NW|"_order_"||||||||||"_(1000+..Rand(.pState,500))_"^DOCTOR^DEMO"_$char(13)
		set seg=seg_"OBR|"_i_"|"_order_"||"_$piece(codes,",",1+..Rand(.pState,4))_"|||"_ts_$char(13)
	}
	quit seg
}

ClassMethod AdtMessage(pN As %Integer, pDay As %Integer, pSecs As %Integer, ByRef pState As %Integer) As %String
{
	set ts=$translate($zdate(pDay,8)_$ztime(pSecs,1),":","")
	set mrn=100000+..Rand(.pState,800000)
	set class=$piece("I,O,E,I,I,O,E,I",",",1+..Rand(.pState,8))
	set seg="MSH|^~\&|ADT|DEMOHOSP|BILLING|DEMOHOSP|"_ts_"||ADT^A01|S"_pN_"|P|2.5"_$char(13)
	set seg=seg_"EVN|A01|"_ts_$char(13)
	set seg=seg_"PID|1||"_mrn_"^^^DEMOHOSP^MR||PATIENT^TEST"_mrn_"||19700101|U"_$char(13)
	set seg=seg_"PV1|1|"_class_"|WARD^01^A"_$char(13)
	quit seg
}

/// Sends the plan oldest first. The five moved feeds are pointed back at LAB-OLD for their first three days.
ClassMethod SendPlan() As %Status
{
	set sc=$$$OK
	set day=""
	for {
		set day=$order(^||plan(day)) quit:day=""
		set secs=""
		for {
			set secs=$order(^||plan(day,secs)) quit:secs=""
			set n=""
			for {
				set n=$order(^||plan(day,secs,n),1,row) quit:n=""
				set feed=$list(row,1), target=$list(row,2), raw=$list(row,3)
				set msg=##class(EnsLib.HL7.Message).ImportFromString(raw,.sc) quit:$$$ISERR(sc)
				do msg.PokeDocType($select(feed="adt-feed":"2.5:ADT_A01",1:"2.5:ORM_O01"))
				set sc=msg.%Save() quit:$$$ISERR(sc)
				set ^BlastRadius.Seed("t",msg.%Id())=$lb(day,secs)
				if '$data(svc(feed)) {
					set sc=##class(Ens.Director).CreateBusinessService(feed,.s) quit:$$$ISERR(sc)
					set svc(feed)=s
				}
				if feed'="annex-7" { set svc(feed).TargetConfigNames=target }
				set sc=svc(feed).ProcessInput(msg) quit:$$$ISERR(sc)
			}
			quit:$$$ISERR(sc)
		}
		quit:$$$ISERR(sc)
	}
	kill svc
	quit sc
}

ClassMethod WaitForQueues(pTimeoutSecs As %Integer) As %Status
{
	set items=$listbuild("LAB-OLD.Router","LAB-OLD.Out","LAB-NEW.Router","LAB-NEW.Out","ADT.Router","bed-board.Out","billing.Out")
	set start=$zh
	for {
		set busy=0
		for i=1:1:$listlength(items) { set busy=busy+##class(Ens.Queue).GetCount($list(items,i)) }
		quit:busy=0
		if ($zh-start)>pTimeoutSecs { return $$$ERROR($$$GeneralError,"Demo seed: queues still hold "_busy_" messages") }
		hang 1
	}
	hang 2
	quit $$$OK
}

/// Moves each whole session back in time. Offsets inside a session are kept, so Visual Trace still reads correctly.
ClassMethod Backdate()
{
	// Called twice per seed. Without this the second call would move the first batch back a second time.
	kill ^||session
	set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT ID,MessageBodyId,TimeCreated FROM Ens.MessageHeader WHERE ID=SessionId AND MessageBodyClassName='EnsLib.HL7.Message'")
	while rs.%Next() {
		set when=$get(^BlastRadius.Seed("t",rs.MessageBodyId)) continue:when=""
		set wanted=$zdatetime($list(when,1)_","_$list(when,2),3)
		set delta=$system.SQL.Functions.DATEDIFF("second",rs.TimeCreated,wanted)
		set ^||session(rs.ID)=delta
	}
	set id=""
	for {
		set id=$order(^||session(id),1,delta) quit:id=""
		&sql(UPDATE %NOLOCK Ens.MessageHeader SET TimeCreated=DATEADD('second',:delta,TimeCreated), TimeProcessed=DATEADD('second',:delta,TimeProcessed) WHERE SessionId=:id)
	}
	kill ^BlastRadius.Seed("t")
}

/// The last annex-7 messages go through the router, but the legacy interface is stopped, so they wait in its queue.
ClassMethod QueueTail(pDay As %Integer) As %Status
{
	set sc=##class(Ens.Director).EnableConfigItem("LAB-OLD.Out",0,1) quit:$$$ISERR(sc) sc
	set state=4242
	set sc=##class(Ens.Director).CreateBusinessService("annex-7",.s) quit:$$$ISERR(sc) sc
	for k=1:1:..#QUEUED {
		set secs=(6*3600)+(600+k)
		set raw=..OrderMessage(90000+k,"annex-7",pDay,secs,1,.state)
		set msg=##class(EnsLib.HL7.Message).ImportFromString(raw,.sc) quit:$$$ISERR(sc)
		do msg.PokeDocType("2.5:ORM_O01")
		set sc=msg.%Save() quit:$$$ISERR(sc)
		set ^BlastRadius.Seed("t",msg.%Id())=$lb(pDay,secs)
		set sc=s.ProcessInput(msg) quit:$$$ISERR(sc)
	}
	quit:$$$ISERR(sc) sc
	kill s
	set items=$listbuild("LAB-OLD.Router")
	for i=1:1:60 { quit:##class(Ens.Queue).GetCount("LAB-OLD.Router")=0  hang 1 }
	hang 2
	do ..Backdate()
	quit $$$OK
}

}
