/// One tool call the agent made. Sent to the ledger so each call appears in Visual Trace in its session.
Class BlastRadius.Msg.ToolCallRecord Extends Ens.Request
{

Property CRId As %String;

Property Round As %Integer;

Property Tool As %String(MAXLEN = 200);

Property Arguments As %String(MAXLEN = "");

Property Outcome As %String;

Property Result As %String(MAXLEN = "");

Property DurationMs As %Integer;

Storage Default
{
<Data name="ToolCallRecordDefaultData">
<Subscript>"ToolCallRecord"</Subscript>
<Value name="1">
<Value>CRId</Value>
</Value>
<Value name="2">
<Value>Round</Value>
</Value>
<Value name="3">
<Value>Tool</Value>
</Value>
<Value name="4">
<Value>Arguments</Value>
</Value>
<Value name="5">
<Value>Outcome</Value>
</Value>
<Value name="6">
<Value>Result</Value>
</Value>
<Value name="7">
<Value>DurationMs</Value>
</Value>
</Data>
<DefaultData>ToolCallRecordDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
