/// The agent is propose-only, and that holds whatever the model asks for.
Class BlastRadiusTests.PolicyTest Extends %UnitTest.TestCase
{

Method TestApplyIsRefusedInAnyCase()
{
	set p=##class(BlastRadius.Agent.Auth).%New()
	for name="ApplyChange","applychange","APPLYCHANGE","tools.ApplyChange","x:ApplyChange" {
		set sc=p.%CanExecute(name,{"name":(name)},{})
		do $$$AssertTrue($$$ISERR(sc),name_" is refused")
	}
}

Method TestUnknownToolIsRefused()
{
	set sc=##class(BlastRadius.Agent.Auth).%New().%CanExecute("DropTable",{"name":"DropTable"},{})
	do $$$AssertTrue($$$ISERR(sc))
}

Method TestEvidenceToolsAreAllowed()
{
	set p=##class(BlastRadius.Agent.Auth).%New()
	for name="FindItems","ConfiguredLinks","TrafficLinks","QueueDepth","TransformsOf","ListTransforms","ShadowRun","OwnerOf","SubmitDecision","TRAFFICLINKS" {
		do $$$AssertStatusOK(p.%CanExecute(name,{"name":(name)},{}),name_" is allowed")
	}
}

/// Every tool the class offers has to be either allowed or refused on purpose, so a new tool cannot slip through unnoticed.
Method TestEveryToolIsAccountedFor()
{
	set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT Name FROM %Dictionary.CompiledMethod WHERE parent='BlastRadius.Agent.Tools' AND ClassMethod=1 AND Origin='BlastRadius.Agent.Tools'")
	set p=##class(BlastRadius.Agent.Auth).%New()
	while rs.%Next() {
		set sc=p.%CanExecute(rs.Name,{"name":(rs.Name)},{})
		if rs.Name="ApplyChange" { do $$$AssertTrue($$$ISERR(sc),"ApplyChange stays refused") }
		else { do $$$AssertStatusOK(sc,rs.Name_" is allowed") }
	}
}

/// Everything the model can see is deliberate. On 3 November a helper class method here was offered as a tool, and a model called it.
Method TestNoHelperIsOfferedAsATool()
{
	set offered=##class(BlastRadius.Agent.Tools).%New().%Discover().%ToJSON()
	do $$$AssertTrue(offered["TrafficLinks","control: the discovery lists a real tool")
	do $$$AssertTrue(offered'["CollectEvidence")
	do $$$AssertTrue(offered'["Keep")
}

/// A review that timed out or never decided must not replace a good recording.
Method TestUnfinishedRunIsNotRecorded()
{
	kill ^||BR
	do $$$AssertNotTrue(##class(BlastRadius.Replay.Recorder).Finished(),"no decision yet")
	set ^||BR("ev","decision")=1
	do $$$AssertTrue(##class(BlastRadius.Replay.Recorder).Finished(),"control: a decided run is kept")
	set ^||BR("failed")=1
	do $$$AssertNotTrue(##class(BlastRadius.Replay.Recorder).Finished(),"a failed run is not")
	kill ^||BR
}

/// AI Hub stops a run after 300 seconds, which is too short for a local model on a busy machine.
Method TestLiveTimeoutIsLongerThanTheDefault()
{
	do $$$AssertTrue(##class(BlastRadius.Agent.Adapter).TimeoutSeconds()>300)
}

Method TestDenialIsWrittenToTheAuditTable()
{
	set ^||BR("cr")="CR-TEST", ^||BR("round")=1
	do ##class(BlastRadius.Agent.Audit).%New().%LogDenial({"name":"ApplyChange","arguments":"{\"item\":\"LAB-OLD.Out\"}"},{},$$$ERROR($$$GeneralError,"agent is propose-only"))
	set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT Outcome,Tool,Detail FROM BlastRadius_Data.AuditEvent WHERE CRId='CR-TEST' ORDER BY ID DESC")
	do $$$AssertTrue(rs.%Next(),"a row was written")
	do $$$AssertEquals(rs.Outcome,"DENIED")
	do $$$AssertEquals(rs.Tool,"ApplyChange")
	do $$$AssertTrue(rs.Detail["propose-only")
	kill ^||BR
	&sql(DELETE FROM BlastRadius_Data.AuditEvent WHERE CRId='CR-TEST')
}

}
