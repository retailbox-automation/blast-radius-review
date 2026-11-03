/// Entry point: a change request becomes a production message here.
Class BlastRadius.Service.ChangeRequests Extends Ens.BusinessService
{

Parameter ADAPTER;

Parameter SETTINGS = "TargetConfigName:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId}";

Property TargetConfigName As Ens.DataType.ConfigName [ InitialExpression = "BlastRadius.Review" ];

Method OnProcessInput(pInput As BlastRadius.Msg.ChangeRequest, Output pOutput As %RegisteredObject) As %Status
{
	set sc=..SendRequestAsync(..TargetConfigName,pInput)
	set pOutput=##class(Ens.StringContainer).%New(..%SessionId)
	quit sc
}

ClassMethod OnGetConnections(Output pArray As %String, pItem As Ens.Config.Item)
{
	do ##super(.pArray,pItem)
	if pItem.GetModifiedSetting("TargetConfigName",.value) { set pArray(value)="" }
}

}
