/// Every tool the agent called or was refused, written by the AI Hub audit policy.
Class BlastRadius.Data.AuditEvent Extends %Persistent
{

Property CRId As %String;

Property ReviewRound As %Integer;

Property LoggedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp,3)} ];

/// ALLOWED or DENIED.
Property Outcome As %String;

Property Tool As %String(MAXLEN = 200);

Property Arguments As %String(MAXLEN = "");

Property Detail As %String(MAXLEN = 2000);

Property DurationMs As %Integer;

Index CRIdIndex On CRId;

Storage Default
{
<Data name="AuditEventDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>CRId</Value>
</Value>
<Value name="3">
<Value>ReviewRound</Value>
</Value>
<Value name="4">
<Value>LoggedAt</Value>
</Value>
<Value name="5">
<Value>Outcome</Value>
</Value>
<Value name="6">
<Value>Tool</Value>
</Value>
<Value name="7">
<Value>Arguments</Value>
</Value>
<Value name="8">
<Value>Detail</Value>
</Value>
<Value name="9">
<Value>DurationMs</Value>
</Value>
</Data>
<DataLocation>^BlastRadius.Data.AuditEventD</DataLocation>
<DefaultData>AuditEventDefaultData</DefaultData>
<IdLocation>^BlastRadius.Data.AuditEventD</IdLocation>
<IndexLocation>^BlastRadius.Data.AuditEventI</IndexLocation>
<StreamLocation>^BlastRadius.Data.AuditEventS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
