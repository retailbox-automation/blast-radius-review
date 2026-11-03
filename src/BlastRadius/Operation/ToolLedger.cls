/// Receives one record per agent tool call. The point is the arrow in Visual Trace; the audit table holds the permanent record.
Class BlastRadius.Operation.ToolLedger Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

Method OnMessage(pRequest As BlastRadius.Msg.ToolCallRecord, Output pResponse As Ens.Response) As %Status
{
	quit $$$OK
}

}
