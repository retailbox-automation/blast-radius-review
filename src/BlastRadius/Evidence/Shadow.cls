/// Runs a candidate transform over stored message bodies and compares the output with the current transform's.
/// Nothing is saved and nothing is sent, so a shadow-run cannot touch the production.
Class BlastRadius.Evidence.Shadow Extends %RegisteredObject
{

/// pItem is the host whose stored inbound messages form the sample. The newest pSample messages are used.
ClassMethod Run(pItem As %String, pCurrent As %String, pCandidate As %String, pSample As %Integer = 120) As %DynamicObject
{
	if '##class(%Dictionary.CompiledClass).%ExistsId(pCurrent) quit {"error":("No such transform: "_pCurrent)}
	if '##class(%Dictionary.CompiledClass).%ExistsId(pCandidate) quit {"error":("No such transform: "_pCandidate)}
	set t0=$zh
	set processed=0, changed=0, failed=0
	kill fields
	set stmt="SELECT TOP ? ID,SourceConfigName s,MessageBodyId b,SessionId sid FROM Ens.MessageHeader WHERE TargetConfigName=? AND Type=1 AND MessageBodyClassName='EnsLib.HL7.Message' ORDER BY TimeCreated DESC, ID DESC"
	set rs=##class(BlastRadius.Evidence.Sql).Run(stmt,pSample,pItem)
	while rs.%Next() {
		set body=##class(EnsLib.HL7.Message).%OpenId(rs.b)
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
			set fields(f,"src",rs.s)=$get(fields(f,"src",rs.s))+1
			if '$data(fields(f,"before")) {
				set fields(f,"before")=d.before, fields(f,"after")=d.after, fields(f,"session")=rs.sid
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

}
