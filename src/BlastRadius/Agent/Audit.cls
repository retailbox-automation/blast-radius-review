/// Writes every tool call and every refusal to a table, tied to its change request.
Class BlastRadius.Agent.Audit Extends %AI.Policy.Audit
{

Method %LogExecution(call As %DynamicObject, metadata As %DynamicObject, result As %DynamicObject, duration As %Integer, status As %Status) As %Status
{
	set ok=$$$ISOK(status)
	do ..Write($select(ok:"ALLOWED",1:"FAILED"),call,$select(ok:"",1:$system.Status.GetOneErrorText(status)),duration,$select($isobject(result):result.%ToJSON(),1:result))
	return $$$OK
}

Method %LogDenial(call As %DynamicObject, metadata As %DynamicObject, status As %Status) As %Status
{
	do ..Write("DENIED",call,$system.Status.GetOneErrorText(status),0,"")
	return $$$OK
}

Method Write(pOutcome As %String, pCall As %DynamicObject, pDetail As %String, pDuration As %Integer, pResult As %String)
{
	try {
		// On this build call.arguments is a JSON string here and an object in authorization hooks.
		set args=pCall.arguments
		if $isobject(args) set args=args.%ToJSON()
		set e=##class(BlastRadius.Data.AuditEvent).%New()
		set e.CRId=$get(^||BR("cr")), e.ReviewRound=$get(^||BR("round"))
		set e.Outcome=pOutcome, e.Tool=pCall.name, e.Arguments=args, e.Detail=$extract(pDetail,1,2000), e.DurationMs=pDuration
		do e.%Save()
		set n=$increment(^||BR("calls"))
		set ^||BR("calls",n)=$listbuild(pCall.name,args,pOutcome,$extract(pResult,1,3000),pDuration)
	} catch ex {
		// A failure in here would be swallowed by the SDK, so leave a trail where it can be read.
		set ^BlastRadius.AuditErrors($increment(^BlastRadius.AuditErrors))=ex.DisplayString()
	}
}

}
