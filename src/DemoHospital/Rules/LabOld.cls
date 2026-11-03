/// Routing rule of the legacy lab router.
Class DemoHospital.Rules.LabOld Extends Ens.Rule.Definition
{

Parameter RuleAssistClass = "EnsLib.HL7.MsgRouter.RuleAssist";

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition alias="" context="EnsLib.HL7.MsgRouter.RoutingEngine" production="DemoHospital.Production">
<ruleSet name="Legacy lab orders" effectiveBegin="" effectiveEnd="">
<rule name="All orders" disabled="false">
<constraint name="msgClass" value="EnsLib.HL7.Message"></constraint>
<when condition="1">
<send transform="DemoHospital.DTL.OrderToLabOld" target="LAB-OLD.Out"></send>
<return></return>
</when>
</rule>
</ruleSet>
</ruleDefinition>
}

}
