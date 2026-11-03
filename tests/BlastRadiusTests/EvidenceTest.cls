/// The evidence tools against the seeded production. No model involved.
Class BlastRadiusTests.EvidenceTest Extends %UnitTest.TestCase
{

ClassMethod Sender(pTraffic As %DynamicObject, pName As %String) As %DynamicObject
{
	set it=pTraffic."senders_seen".%GetIterator()
	while it.%GetNext(.k,.row) { return:row.sender=pName row }
	quit ""
}

Method TestTrafficFindsTheUndeclaredSender()
{
	set t=##class(BlastRadius.Evidence.Traffic).Links("LAB-OLD.Router",30)
	set a=..Sender(t,"annex-7")
	do $$$AssertTrue($isobject(a),"annex-7 appears in traffic")
	do $$$AssertEquals(a.messages,41)
	do $$$AssertEquals(a.pattern,"Tuesdays 06:00")
	do $$$AssertEquals(a.configured,0)
	do $$$AssertEquals(t."active_senders_not_in_configuration".%ToJSON(),"[""annex-7""]")
}

/// The feeds that moved are in the window, but stopped about four weeks ago.
Method TestMovedFeedsAreNotActive()
{
	set t=##class(BlastRadius.Evidence.Traffic).Links("LAB-OLD.Router",30)
	set e=..Sender(t,"orders-ed")
	do $$$AssertTrue($isobject(e),"orders-ed appears in traffic")
	do $$$AssertEquals(e."still_active",0)
	do $$$AssertTrue(e."days_since_last">=26,"last seen about four weeks ago")
}

Method TestConfigurationIsWrongInBothDirections()
{
	set l=##class(BlastRadius.Evidence.Wiring).Links("LAB-OLD.Router")
	do $$$AssertEquals(l."configured_senders".%Size(),1,"only the disabled research feed names LAB-OLD")
	do $$$AssertEquals(l."configured_senders".%Get(0).sender,"orders-research")
	do $$$AssertEquals(l."configured_senders".%Get(0).enabled,0)
	do $$$AssertTrue(l."configured_targets".%ToJSON()["LAB-OLD.Out","the router rule target is found")
	do $$$AssertTrue(l.%ToJSON()'["annex-7","configuration knows nothing of annex-7")
}

Method TestShadowRunFindsTheLostField()
{
	set s=##class(BlastRadius.Evidence.Shadow).Run("LAB-OLD.Router","DemoHospital.DTL.OrderToLabOld","DemoHospital.DTL.OrderToLabNew",120)
	do $$$AssertEquals(s."messages_processed",120)
	do $$$AssertEquals(s."messages_failed",0)
	set it=s."field_differences".%GetIterator()
	while it.%GetNext(.k,.d) { set f(d.field)=d }
	do $$$AssertTrue($data(f("ORC-12")),"ORC-12 differs")
	do $$$AssertEquals(f("ORC-12").messages,3)
	do $$$AssertEquals(f("ORC-12").kind,"lost")
	do $$$AssertEquals(f("ORC-12").senders.%Get(0).sender,"annex-7")
	do $$$AssertTrue($data(f("MSH-5")),"the receiving application changes, as intended")
}

Method TestFixedTransformKeepsTheField()
{
	set s=##class(BlastRadius.Evidence.Shadow).Run("LAB-OLD.Router","DemoHospital.DTL.OrderToLabOld","DemoHospital.DTL.OrderToLabNewV2",120)
	do $$$AssertEquals(s."messages_processed",120)
	do $$$AssertTrue(s."field_differences".%ToJSON()'["ORC-12")
	do $$$AssertTrue(s."field_differences".%ToJSON()["MSH-5")
}

/// Control: a transform compared with itself has to show nothing. If this ever fails, the diff itself is broken.
Method TestSameTransformShowsNoDifference()
{
	set s=##class(BlastRadius.Evidence.Shadow).Run("LAB-OLD.Router","DemoHospital.DTL.OrderToLabOld","DemoHospital.DTL.OrderToLabOld",120)
	do $$$AssertEquals(s."messages_identical",120)
	do $$$AssertEquals(s."field_differences".%Size(),0)
}

/// A shadow-run must leave no trace in the production's data.
Method TestShadowRunSavesNothing()
{
	set before=..Count("EnsLib_HL7.Message"), beforeH=..Count("Ens.MessageHeader")
	do ##class(BlastRadius.Evidence.Shadow).Run("LAB-OLD.Router","DemoHospital.DTL.OrderToLabOld","DemoHospital.DTL.OrderToLabNew",50)
	do $$$AssertEquals(..Count("EnsLib_HL7.Message"),before,"no new HL7 messages")
	do $$$AssertEquals(..Count("Ens.MessageHeader"),beforeH,"no new message headers")
}

ClassMethod Count(pTable As %String) As %Integer
{
	set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT COUNT(*) c FROM "_pTable)
	do rs.%Next()
	quit rs.c
}

Method TestQueueDepth()
{
	do $$$AssertEquals(##class(BlastRadius.Evidence.Traffic).QueueDepth("LAB-OLD.Out").queued,4)
	do $$$AssertEquals(##class(BlastRadius.Evidence.Traffic).QueueDepth("LAB-NEW.Out").queued,0)
}

Method TestOwnerComesFromBusinessPartner()
{
	set o=##class(BlastRadius.Evidence.Wiring).OwnerOf("annex-7")
	do $$$AssertEquals(o.contact,"Dana Reyes")
	do $$$AssertEquals(o."workflow_role","Owner-Annex7")
	do $$$AssertEquals(##class(BlastRadius.Evidence.Wiring).OwnerOf("orders-ed")."workflow_role","Owner-IntegrationLead")
}

Method TestFindItemsMatchesWords()
{
	set f=##class(BlastRadius.Evidence.Wiring).Find("LAB-OLD")
	do $$$AssertTrue(f.items.%ToJSON()["LAB-OLD.Router")
	do $$$AssertTrue(f.items.%ToJSON()["LAB-OLD.Out")
	do $$$AssertTrue(f.items.%ToJSON()'["billing.Out")
	do $$$AssertTrue(f.items.%ToJSON()'["BlastRadius.","the review tool does not review itself")
}

Method TestTransformsOfReadsTheRule()
{
	set t=##class(BlastRadius.Evidence.Wiring).TransformsOf("LAB-OLD.Router")
	do $$$AssertEquals(t.transforms.%ToJSON(),"[""DemoHospital.DTL.OrderToLabOld""]")
}

Method TestReplayKeyMatchesThePrompt()
{
	set nl=$char(10)
	set prompt="Review this change request."_nl_"CHANGE REQUEST:"_nl_"Retire LAB-OLD"_nl_"END OF REQUEST"_nl_"ROUND: 2"_nl_"OWNER ANSWERS:"_nl_"[{""key"":""sender:annex-7"",""action"":""Confirm"",""comment"":""ok""}]"_nl_"END OF ANSWERS"
	set direct=##class(BlastRadius.Replay.Recorder).Key("Retire LAB-OLD",2,"[{""key"":""sender:annex-7"",""action"":""Confirm"",""comment"":""different words""}]")
	do $$$AssertEquals(##class(BlastRadius.Replay.Recorder).KeyFromPrompt(prompt),direct,"comments do not change the key")
	set other=##class(BlastRadius.Replay.Recorder).Key("Retire LAB-OLD",2,"[{""key"":""sender:annex-7"",""action"":""Reject""}]")
	do $$$AssertNotEquals(other,direct,"the owner's decision does")
}

}
