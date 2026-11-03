/// What actually happened, from Ens.MessageHeader. Independent of what the configuration claims.
Class BlastRadius.Evidence.Traffic Extends %RegisteredObject
{

/// A sender counts as still active if it was seen within this many days.
Parameter ACTIVEDAYS = 14;

/// Who sent to pName, and whom pName sent to, in the last pDays. Each sender is compared with the configuration.
ClassMethod Links(pName As %String, pDays As %Integer = 30) As %DynamicObject
{
	set since=$zdatetime($ztimestamp-pDays_","_$piece($ztimestamp,",",2),3)
	set activeSince=$zdatetime($ztimestamp-..#ACTIVEDAYS_","_$piece($ztimestamp,",",2),3)
	set senders=[], unknown=[]
	set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT %EXACT(SourceConfigName) s, COUNT(*) n, MIN(TimeCreated) f, MAX(TimeCreated) l FROM Ens.MessageHeader WHERE TargetConfigName=? AND Type=1 AND TimeCreated>=? GROUP BY %EXACT(SourceConfigName) ORDER BY 2 DESC",pName,since)
	while rs.%Next() {
		set sender=rs.s
		continue:sender=""
		set configured=##class(BlastRadius.Evidence.Wiring).IsConfigured(sender,pName)
		set active=(rs.l]]activeSince)
		set row={"sender":(sender),"messages":(+rs.n),"first_seen":(rs.f),"last_seen":(rs.l),"pattern":(..Pattern(sender,pName,since))}
		do row.%Set("configured",configured,"boolean")
		do row.%Set("still_active",active,"boolean")
		do row.%Set("days_since_last",$system.SQL.Functions.DATEDIFF("day",rs.l,$zdatetime($ztimestamp,3)),"number")
		do senders.%Push(row)
		if active,'configured do unknown.%Push(sender)
	}
	set targets=[]
	set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT %EXACT(TargetConfigName) t, COUNT(*) n, MAX(TimeCreated) l FROM Ens.MessageHeader WHERE SourceConfigName=? AND Type=1 AND TimeCreated>=? GROUP BY %EXACT(TargetConfigName) ORDER BY 2 DESC",pName,since)
	while rs.%Next() {
		continue:rs.t=""
		do targets.%Push({"target":(rs.t),"messages":(+rs.n),"last_seen":(rs.l)})
	}
	quit {"item":(pName),"window_days":(pDays),"senders_seen":(senders),"targets_seen":(targets),"active_senders_not_in_configuration":(unknown)}
}

/// A plain description of when a sender usually sends, such as "Tuesdays 06:00", read from the timestamps.
ClassMethod Pattern(pSender As %String, pTarget As %String, pSince As %String) As %String
{
	set total=0, max=0, best=""
	set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT TimeCreated t FROM Ens.MessageHeader WHERE SourceConfigName=? AND TargetConfigName=? AND Type=1 AND TimeCreated>=?",pSender,pTarget,pSince)
	while rs.%Next() {
		set h=$zdatetimeh(rs.t,3)
		set key=$zdate(+h,10)_"|"_($piece(h,",",2)\3600)
		set n=$increment(buckets(key)), total=total+1
		if n>max { set max=n, best=key }
		set hour=$piece(h,",",2)\3600, hours(hour)=$get(hours(hour))+1
		set days(+h)=""
	}
	quit:total=0 ""
	if (max/total)>=0.8 {
		set names="Sundays,Mondays,Tuesdays,Wednesdays,Thursdays,Fridays,Saturdays"
		quit $piece(names,",",$piece(best,"|",1)+1)_" "_$translate($justify($piece(best,"|",2),2)," ","0")_":00"
	}
	set dayCount=0, d="" for { set d=$order(days(d)) quit:d=""  set dayCount=dayCount+1 }
	quit "about "_(total\dayCount)_" a day on "_dayCount_" days"
}

/// One entry per day a sender sent to a target: how many days ago, and how many messages. Draws the pulse on the decision screen.
ClassMethod Pulse(pSender As %String, pTarget As %String, pDays As %Integer = 30) As %DynamicArray
{
	set today=+$ztimestamp
	set since=$zdatetime(today-pDays_",0",3)
	set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT TimeCreated t FROM Ens.MessageHeader WHERE SourceConfigName=? AND TargetConfigName=? AND Type=1 AND TimeCreated>=?",pSender,pTarget,since)
	while rs.%Next() { set d=+$zdatetimeh(rs.t,3), n(d)=$get(n(d))+1 }
	set out=[], d=""
	for { set d=$order(n(d),1,c) quit:d=""  do out.%Push({"days_ago":(today-d),"messages":(c)}) }
	quit out
}

/// How many messages are waiting in an item's queue right now.
ClassMethod QueueDepth(pName As %String) As %DynamicObject
{
	set n=+##class(Ens.Queue).GetCount(pName)
	quit {"item":(pName),"queued":(n)}
}

}
