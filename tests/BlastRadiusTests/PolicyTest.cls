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

/// Recordings are found wherever the package was installed.
Method TestRecordingsFollowTheInstallFolder()
{
	set saved=$get(^BlastRadius.Home)
	kill ^BlastRadius.Home
	do $$$AssertEquals(##class(BlastRadius.Replay.Recorder).Dir(),"/home/irisowner/dev/replay/","container default")
	set ^BlastRadius.Home="/somewhere/else/"
	do $$$AssertEquals(##class(BlastRadius.Replay.Recorder).Dir(),"/somewhere/else/replay/","installed by IPM")
	if saved="" { kill ^BlastRadius.Home } else { set ^BlastRadius.Home=saved }
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

/// A local model on a busy machine can take far longer than a hosted one.
Method TestLiveTimeoutAllowsASlowLocalModel()
{
	do $$$AssertEquals(##class(BlastRadius.Agent.Adapter).TimeoutSeconds(),900)
}

/// The live time limit changes one key and leaves the production's other session settings alone.
Method TestTimeoutKeepsTheOtherSessionSettings()
{
	set c={}.%FromJSON(##class(BlastRadius.Agent.Adapter).WithTimeout("{""max_iterations"":14,""max_tokens"":2500,""timeout_ms"":300000}",900))
	do $$$AssertEquals(c."max_iterations",14)
	do $$$AssertEquals(c."max_tokens",2500)
	do $$$AssertEquals(c."timeout_ms",900000)
	do $$$AssertEquals({}.%FromJSON(##class(BlastRadius.Agent.Adapter).WithTimeout("",5))."timeout_ms",5000,"empty setting")
}

/// A review that dies must not look as if it is still running, because the screen would wait for ever.
Method TestAFailedReviewEndsAsAHold()
{
	set r=##class(BlastRadius.Data.Review).%New()
	set r.CRId="CR-TEST-"_$random(1000000), r.Text="t", r.Status="IN-REVIEW"
	do $$$AssertStatusOK(r.%Save())
	do ##class(BlastRadius.Operation.Agent).MarkFailed(r.CRId,"boom")
	set f=##class(BlastRadius.Data.Review).Find(r.CRId)
	do $$$AssertEquals(f.Status,"DONE")
	do $$$AssertEquals(f.Verdict,"HOLD")
	do $$$AssertTrue(f.GateReasons["boom")
	do f.%DeleteId(f.%Id())
}

/// If the agent skips the shadow-run in round two, the owners' answers still apply to the run from round one.
Method TestSecondRoundKeepsTheFirstRoundsShadowRun()
{
	set r=##class(BlastRadius.Data.Review).%New()
	set r.CRId="CR-TEST-"_$random(1000000), r.Text="t", r.Status="IN-REVIEW"
	do r.Evidence.Write({"shadow":[{"item":"LAB-OLD.Router"}]}.%ToJSON())
	do $$$AssertStatusOK(r.%Save())
	set none={}
	do ##class(BlastRadius.Operation.Agent).CarryShadowRuns(r.CRId,none)
	do $$$AssertEquals(none.shadow.%Size(),1,"carried over")
	set own={"shadow":[{"item":"LAB-NEW.Router"},{"item":"X"}]}
	do ##class(BlastRadius.Operation.Agent).CarryShadowRuns(r.CRId,own)
	do $$$AssertEquals(own.shadow.%Size(),2,"control: a new run stands")
	do r.%DeleteId(r.%Id())
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
