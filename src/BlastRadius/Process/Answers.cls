/// Folds a Workflow response into the JSON list of owner answers.
Class BlastRadius.Process.Answers Extends %RegisteredObject
{

/// The key comes from the task's subject, because owners answer in any order.
ClassMethod Add(pAnswers As %String, pResponse As EnsLib.Workflow.TaskResponse) As %String
{
	set arr=[].%FromJSON(pAnswers)
	set comment=""
	try { set comment=pResponse.%FormValues.GetAt("Comment") } catch {}
	do arr.%Push({"key":(..KeyFromSubject(pResponse.%Subject)),"role":(pResponse.%RoleName),"action":(pResponse.%Action),"comment":(comment),"user":(pResponse.%UserName)})
	quit arr.%ToJSON()
}

/// "CR-0142: confirm annex-7" gives sender:annex-7, and "CR-0142: review ORC-12" gives diff:ORC-12.
ClassMethod KeyFromSubject(pSubject As %String) As %String
{
	set what=$zstrip($piece(pSubject,":",2,*),"<>W")
	quit $select($piece(what," ",1)="confirm":"sender:",1:"diff:")_$piece(what," ",2,*)
}

}
