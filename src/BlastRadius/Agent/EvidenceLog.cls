/// What the tools returned in this job, kept in process-private globals for the code gate.
/// This is a separate class because every class method of a %AI.Tool class is offered to the model as a tool.
Class BlastRadius.Agent.EvidenceLog Extends %RegisteredObject
{

/// Records one tool result in this job's evidence. Returns it as text for the agent.
ClassMethod Keep(pKind As %String, pResult As %DynamicObject) As %String
{
	set n=$increment(^||BR("ev",pKind))
	set ^||BR("ev",pKind,n)=pResult.%ToJSON()
	quit pResult.%ToJSON()
}

/// Everything the tools returned in this job, as one object.
ClassMethod CollectEvidence() As %DynamicObject
{
	set out={}
	set kind=""
	for {
		set kind=$order(^||BR("ev",kind)) quit:kind=""
		set arr=[], n=""
		for {
			set n=$order(^||BR("ev",kind,n),1,json) quit:n=""
			do arr.%Push({}.%FromJSON(json))
		}
		do out.%Set(kind,arr)
	}
	quit out
}

}
