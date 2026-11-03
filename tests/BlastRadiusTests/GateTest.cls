/// The code gate on its own, with made-up evidence. No model, no production.
Class BlastRadiusTests.GateTest Extends %UnitTest.TestCase
{

/// Evidence where annex-7 is active and declared nowhere, and a shadow-run changed two fields.
ClassMethod Evidence(pQueued As %Integer = 0) As %DynamicObject
{
	quit {
		"traffic":[{"item":"LAB-OLD.Router","window_days":30,
			"senders_seen":[{"sender":"annex-7","messages":41,"pattern":"Tuesdays 06:00"}],
			"active_senders_not_in_configuration":["annex-7"]},
			{"item":"LAB-OLD.Out","window_days":30,"senders_seen":[],"active_senders_not_in_configuration":[]}],
		"queue":[{"item":"LAB-OLD.Out","queued":(pQueued)}],
		"shadow":[{"item":"LAB-OLD.Router","candidate":"Demo.New","messages_processed":120,"messages_failed":0,
			"field_differences":[
				{"field":"MSH-5","kind":"changed","messages":120},
				{"field":"ORC-12","kind":"lost","messages":3}]}]
	}
}

ClassMethod Decision(pVerdict As %String, pOrc12 As %String = "intended") As %DynamicObject
{
	set d={"verdict":(pVerdict),"summary":"s","items":["LAB-OLD.Out"],"diff_classification":{"MSH-5":"intended"}}
	do d."diff_classification".%Set("ORC-12",pOrc12)
	quit d
}

Method TestNoDecisionHolds()
{
	set r=##class(BlastRadius.Gate.Floor).Decide({},"","anything")
	do $$$AssertEquals(r.verdict,"HOLD")
}

Method TestUnknownVerdictHolds()
{
	set r=##class(BlastRadius.Gate.Floor).Decide({},{"verdict":"YOLO","items":["x"]},"anything")
	do $$$AssertEquals(r.verdict,"HOLD")
}

Method TestUnnamedSenderOverridesAgentApply()
{
	set r=##class(BlastRadius.Gate.Floor).Decide(..Evidence(),..Decision("APPLY"),"Retire LAB-OLD")
	do $$$AssertEquals(r.proposed,"APPLY")
	do $$$AssertEquals(r.verdict,"HOLD")
	do $$$AssertTrue(r.reasons.%ToJSON()["annex-7")
	do $$$AssertTrue(r.tasks.%ToJSON()["sender:annex-7")
}

/// Must differ from the case above: only the request text changes.
Method TestSenderNamedInRequestLiftsTheHold()
{
	set r=##class(BlastRadius.Gate.Floor).Decide(..Evidence(),..Decision("APPLY"),"Retire LAB-OLD, annex-7 is moving too")
	do $$$AssertEquals(r.verdict,"APPLY")
}

Method TestOwnerConfirmationLiftsTheHold()
{
	set answers=[{"key":"sender:annex-7","action":"Confirm"}]
	set r=##class(BlastRadius.Gate.Floor).Decide(..Evidence(),..Decision("APPLY"),"Retire LAB-OLD",answers)
	do $$$AssertEquals(r.verdict,"APPLY")
}

Method TestOwnerRejectionHolds()
{
	set answers=[{"key":"sender:annex-7","action":"Reject"}]
	set r=##class(BlastRadius.Gate.Floor).Decide(..Evidence(),..Decision("APPLY"),"Retire LAB-OLD, annex-7 too",answers)
	do $$$AssertEquals(r.verdict,"HOLD")
}

Method TestUnintendedDiffHolds()
{
	set r=##class(BlastRadius.Gate.Floor).Decide(..Evidence(),..Decision("APPLY","unintended"),"Retire LAB-OLD, annex-7 too")
	do $$$AssertEquals(r.verdict,"HOLD")
	do $$$AssertTrue(r.reasons.%ToJSON()["ORC-12")
	do $$$AssertTrue(r.tasks.%ToJSON()["diff:ORC-12")
}

Method TestUnclassifiedDiffHolds()
{
	set d={"verdict":"APPLY","items":["LAB-OLD.Out"],"diff_classification":{"MSH-5":"intended"}}
	set r=##class(BlastRadius.Gate.Floor).Decide(..Evidence(),d,"Retire LAB-OLD, annex-7 too")
	do $$$AssertEquals(r.verdict,"HOLD")
}

Method TestOwnerAcceptsDiff()
{
	set answers=[{"key":"diff:ORC-12","action":"Confirm"}]
	set r=##class(BlastRadius.Gate.Floor).Decide(..Evidence(),..Decision("APPLY","unintended"),"Retire LAB-OLD, annex-7 too",answers)
	do $$$AssertEquals(r.verdict,"APPLY")
}

Method TestFailedShadowMessagesHold()
{
	set e=..Evidence()
	set e.shadow.%Get(0)."messages_failed"=2
	set r=##class(BlastRadius.Gate.Floor).Decide(e,..Decision("APPLY"),"Retire LAB-OLD, annex-7 too")
	do $$$AssertEquals(r.verdict,"HOLD")
}

Method TestQueueRaisesApplyToDrain()
{
	set r=##class(BlastRadius.Gate.Floor).Decide(..Evidence(4),..Decision("APPLY"),"Retire LAB-OLD, annex-7 too")
	do $$$AssertEquals(r.verdict,"APPLY-AFTER-DRAIN")
	do $$$AssertTrue(r.reasons.%ToJSON()["4 messages")
}

/// A queue on an item this change does not touch must not matter.
Method TestQueueElsewhereIsIgnored()
{
	set e=..Evidence()
	set e.queue=[{"item":"billing.Out","queued":9},{"item":"LAB-OLD.Out","queued":0}]
	set r=##class(BlastRadius.Gate.Floor).Decide(e,..Decision("APPLY"),"Retire LAB-OLD, annex-7 too")
	do $$$AssertEquals(r.verdict,"APPLY")
}

Method TestAgentMayBeStricterThanTheFloor()
{
	set r=##class(BlastRadius.Gate.Floor).Decide(..Evidence(),..Decision("CANARY-FIRST"),"Retire LAB-OLD, annex-7 too")
	do $$$AssertEquals(r.floor,"APPLY")
	do $$$AssertEquals(r.verdict,"CANARY-FIRST")
}

/// A failed check must not look like an empty result. This is the failure that would wrongly say "nobody uses this".
Method TestFailedTrafficCheckHolds()
{
	set e={"traffic":[{"item":"LAB-OLD.Out","window_days":30,"error":"SQL -1"}],"queue":[{"item":"LAB-OLD.Out","queued":0}]}
	set r=##class(BlastRadius.Gate.Floor).Decide(e,{"verdict":"APPLY","items":["LAB-OLD.Out"]},"Retire LAB-OLD.Out")
	do $$$AssertEquals(r.verdict,"HOLD")
}

Method TestFailedShadowRunHolds()
{
	set e=..Evidence()
	set e.shadow=[{"item":"LAB-OLD.Router","candidate":"x","error":"boom"}]
	set r=##class(BlastRadius.Gate.Floor).Decide(e,..Decision("APPLY"),"Retire LAB-OLD, annex-7 too")
	do $$$AssertEquals(r.verdict,"HOLD")
}

/// Control: a bad statement must throw, not return an empty result.
Method TestBadSqlThrows()
{
	set thrown=0
	try { do ##class(BlastRadius.Evidence.Sql).Run("SELECT nosuchcolumn FROM Ens.MessageHeader") } catch { set thrown=1 }
	do $$$AssertTrue(thrown,"a bad statement throws")
}

/// LAB-OLD.Router has a rule with a transform, so naming it without a shadow-run is not enough.
Method TestRouterWithoutShadowRunHolds()
{
	set e={"traffic":[{"item":"LAB-OLD.Router","window_days":30,"senders_seen":[{"sender":"x","messages":1,"pattern":"p"}],"active_senders_not_in_configuration":[]}],"queue":[]}
	set r=##class(BlastRadius.Gate.Floor).Decide(e,{"verdict":"APPLY","items":["LAB-OLD.Router"]},"Retire LAB-OLD.Router")
	do $$$AssertEquals(r.verdict,"HOLD")
	do $$$AssertTrue(r.reasons.%ToJSON()["no shadow-run")
}

/// An agent that skips a check gets no credit for it: the gate runs the check itself, and what it finds counts.
Method TestGateRunsTheChecksTheAgentSkipped()
{
	set e={}
	set r=##class(BlastRadius.Gate.Floor).Decide(e,{"verdict":"APPLY","items":["LAB-OLD.Out"]},"Retire LAB-OLD.Out")
	do $$$AssertEquals(e.traffic.%Size(),1,"the traffic check was run")
	do $$$AssertEquals(e.queue.%Size(),1,"the queue check was run")
	do $$$AssertEquals(r.verdict,"APPLY-AFTER-DRAIN","and the 4 queued messages count against the agent's APPLY")
}

/// The shadow-run on the old route covers the move: naming the replacement router must not raise a second hold.
Method TestReplacementRouterNeedsNoSecondShadowRun()
{
	set e={"traffic":[{"item":"LAB-OLD.Router","window_days":30,"senders_seen":[{"sender":"x","messages":1,"pattern":"p"}],"active_senders_not_in_configuration":[]},{"item":"LAB-NEW.Router","window_days":30,"senders_seen":[{"sender":"y","messages":1,"pattern":"p"}],"active_senders_not_in_configuration":[]}],"queue":[{"item":"LAB-OLD.Router","queued":0},{"item":"LAB-NEW.Router","queued":0}],"shadow":[{"item":"LAB-OLD.Router","candidate":"c","messages_processed":10,"messages_failed":0,"field_differences":[]}]}
	set r=##class(BlastRadius.Gate.Floor).Decide(e,{"verdict":"APPLY","items":["LAB-OLD.Router","LAB-NEW.Router"]},"Retire LAB-OLD.Router")
	do $$$AssertEquals(r.verdict,"APPLY")
}

Method TestNoItemsHolds()
{
	set r=##class(BlastRadius.Gate.Floor).Decide({},{"verdict":"APPLY","items":[]},"anything")
	do $$$AssertEquals(r.verdict,"HOLD")
}

/// An empty verdict must not outrank the floor.
Method TestEmptyVerdictHolds()
{
	do $$$AssertEquals(##class(BlastRadius.Gate.Floor).Rank(""),0)
	do $$$AssertEquals(##class(BlastRadius.Gate.Floor).Rank("APPLY"),1,"control")
	do $$$AssertEquals(##class(BlastRadius.Gate.Floor).Rank("HOLD"),4,"control")
	set r=##class(BlastRadius.Gate.Floor).Decide({},{"verdict":"","summary":"s","items":["nightly-report.Out"]},"Remove it")
	do $$$AssertEquals(r.verdict,"HOLD")
}

/// A name with the wrong case, or a rule's name alone, gives the gate nothing to check.
Method TestItemsNotInTheProductionHold()
{
	set r=##class(BlastRadius.Gate.Floor).Decide({},{"verdict":"APPLY","summary":"s","items":["lab-old.router"]},"Retire it")
	do $$$AssertEquals(r.verdict,"HOLD")
	do $$$AssertTrue(r.reasons.%ToJSON()["None of the items","the reason says so")
}

/// A sender is named as a whole word, in any case. Part of another name does not count.
Method TestRequestNamesASenderAsAWholeWord()
{
	do $$$AssertEquals(##class(BlastRadius.Gate.Floor).Names("Retire LIS-OLD","LIS"),0)
	do $$$AssertEquals(##class(BlastRadius.Gate.Floor).Names("the annex-7-batch job","annex-7"),0)
	do $$$AssertEquals(##class(BlastRadius.Gate.Floor).Names("Retire LAB-OLD.Router","LAB-OLD"),0)
	do $$$AssertEquals(##class(BlastRadius.Gate.Floor).Names("the owner of annex-7 will move it","annex-7"),1)
	do $$$AssertEquals(##class(BlastRadius.Gate.Floor).Names("Ask ANNEX-7.","annex-7"),1)
	do $$$AssertEquals(##class(BlastRadius.Gate.Floor).Names("annex-7, then the rest","annex-7"),1)
}

/// A run that found a difference still counts after later runs that found none.
Method TestALaterRunDoesNotHideAFinding()
{
	set e=..Evidence(0)
	do e.shadow.%Push({"item":"LAB-OLD.Router","current":"Demo.New","candidate":"Demo.New","messages_processed":120,"messages_failed":0,"field_differences":[]})
	do e.shadow.%Push({"item":"LAB-OLD.Router","current":"Demo.Old","candidate":"Demo.V2","messages_processed":120,"messages_failed":0,"field_differences":[]})
	set r=##class(BlastRadius.Gate.Floor).Decide(e,..Decision("APPLY","unintended"),"annex-7 moves too")
	do $$$AssertEquals(r.verdict,"HOLD")
	do $$$AssertTrue(r.reasons.%ToJSON()["ORC-12")
}

/// The same difference found by two runs is one question for the owner.
Method TestTwoRunsAskTheOwnerOnce()
{
	set e=..Evidence(0)
	do e.shadow.%Push({"item":"LAB-OLD.Router","current":"Demo.Old","candidate":"Demo.V2","messages_processed":120,"messages_failed":0,"field_differences":[{"field":"ORC-12","kind":"lost","messages":3}]})
	set r=##class(BlastRadius.Gate.Floor).Decide(e,..Decision("APPLY","unintended"),"annex-7 moves too")
	set asked=0, it=r.tasks.%GetIterator()
	while it.%GetNext(.k,.t) { set:t.key="diff:ORC-12" asked=asked+1 }
	do $$$AssertEquals(asked,1)
}

ClassMethod BusyRouter(pRun As %DynamicObject) As %DynamicObject
{
	quit {
		"traffic":[{"item":"LAB-OLD.Router","window_days":30,"senders_seen":[{"sender":"annex-7","messages":41,"pattern":"Tuesdays 06:00"}],"active_senders_not_in_configuration":[]}],
		"queue":[{"item":"LAB-OLD.Router","queued":0}],
		"shadow":[(pRun)]
	}
}

/// The same transform on both sides tests nothing, so the router still has no shadow-run.
Method TestSameTransformTwiceIsNotAShadowRun()
{
	set run={"item":"LAB-OLD.Router","current":"DemoHospital.DTL.OrderToLabOld","candidate":"DemoHospital.DTL.OrderToLabOld","messages_processed":120,"messages_failed":0,"field_differences":[]}
	set r=##class(BlastRadius.Gate.Floor).Decide(..BusyRouter(run),{"verdict":"APPLY","summary":"s","items":["LAB-OLD.Router"]},"Retire it")
	do $$$AssertEquals(r.verdict,"HOLD")
	do $$$AssertTrue(r.reasons.%ToJSON()["no shadow-run")
}

/// A run on an item the decision does not name says nothing about the items it does name.
Method TestARunElsewhereDoesNotCount()
{
	set run={"item":"ADT.Router","current":"Demo.Old","candidate":"Demo.New","messages_processed":120,"messages_failed":0,"field_differences":[]}
	set r=##class(BlastRadius.Gate.Floor).Decide(..BusyRouter(run),{"verdict":"APPLY","summary":"s","items":["LAB-OLD.Router"]},"Retire it")
	do $$$AssertEquals(r.verdict,"HOLD")
	do $$$AssertTrue(r.reasons.%ToJSON()["no shadow-run")
}

/// Control for the two above: a real run on the named router clears the rule.
Method TestARealRunClearsTheRule()
{
	set run={"item":"LAB-OLD.Router","current":"Demo.Old","candidate":"Demo.New","messages_processed":120,"messages_failed":0,"field_differences":[]}
	set r=##class(BlastRadius.Gate.Floor).Decide(..BusyRouter(run),{"verdict":"APPLY","summary":"s","items":["LAB-OLD.Router"]},"Retire it")
	do $$$AssertNotTrue(r.reasons.%ToJSON()["no shadow-run")
}

}
