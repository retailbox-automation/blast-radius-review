/// Folds a Workflow response into the JSON list of owner answers.
Class BlastRadius.Process.Answers Extends %RegisteredObject
{

ClassMethod Add(pAnswers As %String, pKey As %String, pRole As %String, pResponse As EnsLib.Workflow.TaskResponse) As %String
{
	set arr=[].%FromJSON(pAnswers)
	set comment=""
	try { set comment=pResponse.%FormValues.GetAt("Comment") } catch {}
	do arr.%Push({"key":(pKey),"role":(pRole),"action":(pResponse.%Action),"comment":(comment),"user":(pResponse.%UserName)})
	quit arr.%ToJSON()
}

}
