/// Allow list for the agent's tools. Anything not named here is refused, including ApplyChange.
Class BlastRadius.Agent.Auth Extends %AI.Policy.Authorization
{

Parameter ALLOWED = ",FindItems,ConfiguredLinks,TrafficLinks,QueueDepth,TransformsOf,ListTransforms,ShadowRun,OwnerOf,SubmitDecision,";

Method %CanExecute(toolref As %String, call As %DynamicObject, metadata As %DynamicObject) As %Status
{
	// Model output can change a tool name's case, so compare without it.
	set name=$piece($piece(toolref,":",*),".",*)
	if $zconvert(..#ALLOWED,"L")'[(","_$zconvert(name,"L")_",") {
		quit $$$ERROR($$$GeneralError,"agent is propose-only: "_name_" is not allowed")
	}
	quit $$$OK
}

}
