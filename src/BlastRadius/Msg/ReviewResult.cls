/// What came back from one review round: the agent's proposal, the code gate's verdict, and who has to be asked.
Class BlastRadius.Msg.ReviewResult Extends Ens.Response
{

Property CRId As %String;

Property Round As %Integer;

/// What the agent proposed.
Property AgentVerdict As %String;

/// What stands after the code gate. Never softer than the evidence allows.
Property FinalVerdict As %String;

Property Summary As %String(MAXLEN = "");

/// JSON array of the reasons the gate added.
Property GateReasons As %String(MAXLEN = "");

/// One line per owner task: role|key|subject|message
Property Owners As list Of %String(MAXLEN = 4000, STORAGEDEFAULT = "array");

Property Model As %String(MAXLEN = 200);

Property Mode As %String;

Property PromptTokens As %Integer;

Property CompletionTokens As %Integer;

Property ToolCalls As %Integer;

Property DurationMs As %Integer;

Storage Default
{
<Data name="Owners">
<Attribute>Owners</Attribute>
<Structure>subnode</Structure>
<Subscript>"BlastRadius.Msg.ReviewResult.Owners"</Subscript>
</Data>
<Data name="ReviewResultDefaultData">
<Subscript>"ReviewResult"</Subscript>
<Value name="1">
<Value>CRId</Value>
</Value>
<Value name="2">
<Value>Round</Value>
</Value>
<Value name="3">
<Value>AgentVerdict</Value>
</Value>
<Value name="4">
<Value>FinalVerdict</Value>
</Value>
<Value name="5">
<Value>Summary</Value>
</Value>
<Value name="6">
<Value>GateReasons</Value>
</Value>
<Value name="7">
<Value>Model</Value>
</Value>
<Value name="8">
<Value>Mode</Value>
</Value>
<Value name="9">
<Value>PromptTokens</Value>
</Value>
<Value name="10">
<Value>CompletionTokens</Value>
</Value>
<Value name="11">
<Value>ToolCalls</Value>
</Value>
<Value name="12">
<Value>DurationMs</Value>
</Value>
</Data>
<DefaultData>ReviewResultDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
