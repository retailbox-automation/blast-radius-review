/// The whole workflow in replay mode: real production, real tools, real gate, recorded model answers.
/// Skipped in live mode, where the model's words are not fixed.
Class BlastRadiusTests.EndToEndTest Extends %UnitTest.TestCase
{

/// Submits a request the way the REST API does and waits for it to settle.
ClassMethod Submit(pText As %String, pWaitFor As %String = "DONE,WAITING-OWNERS") As BlastRadius.Data.Review
{
	set id="CR-"_$translate($justify($increment(^BlastRadius.CR),4)," ","0")
	set r=##class(BlastRadius.Data.Review).%New()
	set r.CRId=id, r.Text=pText, r.Requester="test", r.Status="IN-REVIEW"
	$$$ThrowOnError(r.%Save())
	set msg=##class(BlastRadius.Msg.ChangeRequest).%New()
	set msg.CRId=id, msg.Text=pText, msg.Requester="test"
	$$$ThrowOnError(##class(Ens.Director).CreateBusinessService("BlastRadius.ChangeRequests",.svc))
	$$$ThrowOnError(svc.ProcessInput(msg,.out))
	quit ..Settle(id,pWaitFor)
}

ClassMethod Settle(pId As %String, pWaitFor As %String, pSecs As %Integer = 60) As BlastRadius.Data.Review
{
	// An object already open in this process would come back as it was, so it has to be reloaded to see the production's writes.
	set r=##class(BlastRadius.Data.Review).Find(pId)
	for i=1:1:pSecs*2 {
		do r.%Reload()
		quit:(","_pWaitFor_",")[(","_r.Status_",")
		hang 0.5
	}
	quit r
}

ClassMethod Preset(pId As %String) As %String
{
	set it=##class(BlastRadius.Api.Presets).All().%GetIterator()
	while it.%GetNext(.k,.p) { return:p.id=pId p.text }
	quit ""
}

/// Answers the task whose subject contains pWord, then gives the process a moment to raise the next one.
ClassMethod Answer(pCRId As %String, pWord As %String, pAction As %String) As %Boolean
{
	for i=1:1:40 {
		set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT ID FROM EnsLib_Workflow.TaskResponse WHERE %Subject %STARTSWITH ? AND %Subject LIKE ? AND TaskStatus_IsComplete=0",pCRId_":","%"_pWord_"%")
		if rs.%Next() {
			set t=##class(EnsLib.Workflow.TaskResponse).%OpenId(rs.ID)
			$$$ThrowOnError(t.CompleteTask(pAction))
			return 1
		}
		hang 0.5
	}
	quit 0
}

/// Finishes whatever a test left open, so the inbox stays clean for whoever opens it next.
ClassMethod AnswerAll(pCRId As %String)
{
	for i=1:1:20 {
		hang 0.5
		set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT ID FROM EnsLib_Workflow.TaskResponse WHERE %Subject %STARTSWITH ? AND TaskStatus_IsComplete=0",pCRId_":")
		while rs.%Next() { do ##class(EnsLib.Workflow.TaskResponse).%OpenId(rs.ID).CompleteTask("Reject") }
	}
}

Method Skip() As %Boolean
{
	if ##class(BlastRadius.Agent.Adapter).Mode()'="replay" {
		do $$$LogMessage("Skipped: the end-to-end test needs BR_LLM_MODE=replay")
		quit 1
	}
	quit 0
}

Method TestRetireHoldsAndNamesTheSender()
{
	quit:..Skip()
	set r=..Submit(..Preset("retire"))
	do $$$AssertEquals(r.Verdict,"HOLD")
	do $$$AssertEquals(r.Status,"WAITING-OWNERS")
	do $$$AssertEquals(##class(BlastRadius.Replay.Recorder).RecordedModel(r.Text,1),r.Model,"the card names the recorded model")
	do $$$AssertTrue(r.GateReasons["annex-7","the gate names annex-7")
	do $$$AssertTrue(r.GateReasons["41 messages","with its real count")
	do $$$AssertTrue(r.GateReasons["ORC-12","and the lost field")
	do $$$AssertTrue(r.GateReasons["3 of 120","with its real count")
	// Both owners confirm: the process continues by itself and the second review ends after the queue.
	do $$$AssertTrue(..Answer(r.CRId,"annex-7","Confirm"),"first task exists")
	do $$$AssertTrue(..Answer(r.CRId,"ORC-12","Confirm"),"second task exists")
	set done=..Settle(r.CRId,"DONE")
	do $$$AssertEquals(done.Status,"DONE")
	do $$$AssertEquals(done.Round,2)
	do $$$AssertEquals(done.Verdict,"APPLY-AFTER-DRAIN")
	do $$$AssertTrue(done.GateReasons["4 messages")
}

/// Must differ from the case above: one owner's answer changes the outcome.
Method TestOwnerRejectionKeepsTheHold()
{
	quit:..Skip()
	set r=..Submit(..Preset("retire"))
	do $$$AssertTrue(..Answer(r.CRId,"annex-7","Reject"),"first task exists")
	do $$$AssertTrue(..Answer(r.CRId,"ORC-12","Confirm"),"second task exists")
	set done=..Settle(r.CRId,"DONE")
	do $$$AssertEquals(done.Round,2)
	do $$$AssertEquals(done.Verdict,"HOLD")
	do $$$AssertTrue(done.GateReasons["rejected")
}

Method TestRevisedRequestAppliesAfterDrain()
{
	quit:..Skip()
	set r=..Submit(..Preset("retire-fixed"))
	do $$$AssertEquals(r.Verdict,"APPLY-AFTER-DRAIN")
	do $$$AssertEquals(r.Status,"DONE")
	do $$$AssertTrue(r.GateReasons["4 messages")
	do $$$AssertTrue(r.GateReasons'["ORC-12","the candidate keeps the field")
}

Method TestUnusedOutputCanBeApplied()
{
	quit:..Skip()
	set r=..Submit(..Preset("unused"))
	do $$$AssertEquals(r.Verdict,"APPLY")
	do $$$AssertEquals(r.Status,"DONE")
}

Method TestBillingTransformGoesToCanary()
{
	quit:..Skip()
	set r=..Submit(..Preset("billing"))
	do $$$AssertEquals(r.Verdict,"CANARY-FIRST")
}

Method TestPressureIsDeniedAndAudited()
{
	quit:..Skip()
	set before=+$get(^BlastRadius.ApplyAttempts)
	set r=..Submit(..Preset("pressure"))
	do $$$AssertEquals(r.Verdict,"HOLD")
	do $$$AssertEquals(+$get(^BlastRadius.ApplyAttempts),before,"ApplyChange never ran")
	set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT COUNT(*) c FROM BlastRadius_Data.AuditEvent WHERE CRId=? AND Tool='ApplyChange' AND Outcome='DENIED'",r.CRId)
	do rs.%Next()
	do $$$AssertTrue(rs.c>0,"the refusal is in the audit table")
	do ..AnswerAll(r.CRId)
}

/// Control: replay must not invent a review for text it has no recording of.
Method TestUnknownTextIsAnHonestHold()
{
	quit:..Skip()
	set r=..Submit("Some request nobody has recorded, number "_$random(1000000))
	do $$$AssertEquals(r.Verdict,"HOLD")
	do $$$AssertTrue(r.Summary["only knows the recorded requests")
}

/// Every message of a review belongs to one session, so Visual Trace shows the whole thing.
Method TestReviewIsOneSessionInTheProduction()
{
	quit:..Skip()
	set r=..Submit(..Preset("retire-fixed"))
	set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT COUNT(*) c FROM Ens.MessageHeader WHERE SessionId=? AND TargetConfigName='BlastRadius.ToolLedger'",r.SessionId)
	do rs.%Next()
	do $$$AssertTrue(rs.c>=8,"tool calls appear in the session")
}

}
