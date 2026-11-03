/// Routing rule of the patient administration router.
Class DemoHospital.Rules.Adt Extends Ens.Rule.Definition
{

Parameter RuleAssistClass = "EnsLib.HL7.MsgRouter.RuleAssist";

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition alias="" context="EnsLib.HL7.MsgRouter.RoutingEngine" production="DemoHospital.Production">
<ruleSet name="ADT events" effectiveBegin="" effectiveEnd="">
<rule name="All events" disabled="false">
<constraint name="msgClass" value="EnsLib.HL7.Message"></constraint>
<when condition="1">
<send transform="" target="bed-board.Out"></send>
<send transform="DemoHospital.DTL.AdtToBilling" target="billing.Out"></send>
<return></return>
</when>
</rule>
</ruleSet>
</ruleDefinition>
}

}
