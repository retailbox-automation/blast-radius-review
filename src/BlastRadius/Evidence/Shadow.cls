/// Runs a candidate transform over stored message bodies and compares the output with the current transform's.
/// Nothing is saved and nothing is sent, so a shadow-run cannot touch the production.
Class BlastRadius.Evidence.Shadow Extends %RegisteredObject
{

/// The model picks the class names, so nothing but a data transform is ever run.
ClassMethod IsTransform(pClass As %String) As %Boolean
{
	quit:'##class(%Dictionary.CompiledClass).%ExistsId(pClass) 0
	try { set is=$classmethod(pClass,"%Extends","Ens.DataTransform") } catch { set is=0 }
	quit is
}

/// pItem is the host whose stored inbound messages form the sample. See Sample for how they are picked.
ClassMethod Run(pItem As %String, pCurrent As %String, pCandidate As %String, pSample As %Integer = 120) As %DynamicObject
{
	if '..IsTransform(pCurrent) quit {"error":("No such transform: "_pCurrent)}
	if '..IsTransform(pCandidate) quit {"error":("No such transform: "_pCandidate)}
	set t0=$zh
	set processed=0, changed=0, failed=0
	kill fields
	do ..Sample(pItem,pSample,.rows)
	set row=""
	for {
		set row=$order(rows(row),1,picked) quit:row=""
		set from=$list(picked,1), session=$list(picked,3)
		set body=##class(EnsLib.HL7.Message).%OpenId($list(picked,2))
		continue:'$isobject(body)
		set sc1=$classmethod(pCurrent,"Transform",body,.a)
		set sc2=$classmethod(pCandidate,"Transform",body,.b)
		if ($$$ISERR(sc1))||($$$ISERR(sc2))||('$isobject($get(a)))||('$isobject($get(b))) {
			set failed=failed+1, processed=processed+1
			continue
		}
		set diff=##class(BlastRadius.Evidence.Diff).Fields(a.OutputToString(),b.OutputToString())
		set processed=processed+1
		set dyn={}.%FromJSON(diff)
		if dyn.%Size()>0 set changed=changed+1
		set iter=dyn.%GetIterator()
		kill thisMessage
		while iter.%GetNext(.k,.d) {
			set f=d.field_"|"_d.kind
			// Counted per message: a message with two orders changes OBR-4 twice, but it is still one message.
			continue:$data(thisMessage(f))
			set thisMessage(f)=""
			set fields(f)=$get(fields(f))+1
			set fields(f,"src",from)=$get(fields(f,"src",from))+1
			if '$data(fields(f,"before")) {
				set fields(f,"before")=d.before, fields(f,"after")=d.after, fields(f,"session")=session
			}
		}
		kill a,b
	}
	set out=[]
	set f=""
	for {
		set f=$order(fields(f),1,count) quit:f=""
		set sources=[], s=""
		for { set s=$order(fields(f,"src",s),1,c) quit:s=""  do sources.%Push({"sender":(s),"messages":(c)}) }
		do out.%Push({"field":($piece(f,"|",1)),"kind":($piece(f,"|",2)),"messages":(count),"senders":(sources),"example_before":($get(fields(f,"before"))),"example_after":($get(fields(f,"after"))),"example_session":(+$get(fields(f,"session")))})
	}
	quit {"item":(pItem),"current":(pCurrent),"candidate":(pCandidate),"messages_processed":(processed),"messages_identical":(processed-changed-failed),"messages_changed":(changed),"messages_failed":(failed),"field_differences":(out),"seconds":($fnumber($zh-t0,"",2)+0)}
}

/// Newest messages first, but every sender is guaranteed a share of the sample.
/// The rare sender nobody planned for is exactly the one a plain "newest N" would miss on a busy route.
ClassMethod Sample(pItem As %String, pSample As %Integer, Output pRows)
{
	kill pRows
	set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT DISTINCT %EXACT(SourceConfigName) s FROM Ens.MessageHeader WHERE TargetConfigName=? AND Type=1 AND MessageBodyClassName='EnsLib.HL7.Message'",pItem)
	set senders=0
	while rs.%Next() { set senders=senders+1, sender(senders)=rs.s }
	quit:senders=0
	set share=pSample\senders, taken=0
	set stmt="SELECT TOP ? ID,MessageBodyId b,SessionId sid FROM Ens.MessageHeader WHERE TargetConfigName=? AND SourceConfigName=? AND Type=1 AND MessageBodyClassName='EnsLib.HL7.Message' ORDER BY TimeCreated DESC, ID DESC"
	for i=1:1:senders {
		set rs=##class(BlastRadius.Evidence.Sql).Run(stmt,share,pItem,sender(i))
		while rs.%Next() { set pRows(rs.ID)=$listbuild(sender(i),rs.b,rs.sid), taken=taken+1 }
	}
	quit:taken>=pSample
	// Whatever the shares left over goes to the newest messages not picked yet.
	set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT TOP ? ID,%EXACT(SourceConfigName) s,MessageBodyId b,SessionId sid FROM Ens.MessageHeader WHERE TargetConfigName=? AND Type=1 AND MessageBodyClassName='EnsLib.HL7.Message' ORDER BY TimeCreated DESC, ID DESC",pSample+taken,pItem)
	while rs.%Next(),taken<pSample {
		continue:$data(pRows(rs.ID))
		set pRows(rs.ID)=$listbuild(rs.s,rs.b,rs.sid), taken=taken+1
	}
}

}
