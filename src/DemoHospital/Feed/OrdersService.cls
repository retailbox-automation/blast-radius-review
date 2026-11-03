/// An adapterless HL7 feed. Its targets come from the TargetConfigNames setting, so the production diagram shows the link.
Class DemoHospital.Feed.OrdersService Extends Ens.BusinessService
{

Parameter ADAPTER;

Parameter SETTINGS = "TargetConfigNames:Basic:selector?multiSelect=1&context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId},MessageSchemaCategory:Basic";

Property TargetConfigNames As %String(MAXLEN = 1000);

/// Kept for parity with the stock HL7 services.
Property MessageSchemaCategory As %String [ InitialExpression = "2.5" ];

Method OnProcessInput(pInput As EnsLib.HL7.Message, Output pOutput As %RegisteredObject) As %Status
{
	set sc=$$$OK
	for i=1:1:$length(..TargetConfigNames,",") {
		set target=$zstrip($piece(..TargetConfigNames,",",i),"<>W")
		continue:target=""
		set sc=..SendRequestAsync(target,pInput) quit:$$$ISERR(sc)
	}
	quit sc
}

ClassMethod OnGetConnections(Output pArray As %String, pItem As Ens.Config.Item)
{
	do ##super(.pArray,pItem)
	if pItem.GetModifiedSetting("TargetConfigNames",.value) {
		for i=1:1:$length(value,",") {
			set target=$zstrip($piece(value,",",i),"<>W")
			set:target'="" pArray(target)=""
		}
	}
}

}
