/// Routing rule of the new lab router.
Class DemoHospital.Rules.LabNew Extends Ens.Rule.Definition
{

Parameter RuleAssistClass = "EnsLib.HL7.MsgRouter.RuleAssist";

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition alias="" context="EnsLib.HL7.MsgRouter.RoutingEngine" production="DemoHospital.Production">
<ruleSet name="New lab orders" effectiveBegin="" effectiveEnd="">
<rule name="All orders" disabled="false">
<constraint name="msgClass" value="EnsLib.HL7.Message"></constraint>
<when condition="1">
<send transform="DemoHospital.DTL.OrderToLabNew" target="LAB-NEW.Out"></send>
<return></return>
</when>
</rule>
</ruleSet>
</ruleDefinition>
}

}
