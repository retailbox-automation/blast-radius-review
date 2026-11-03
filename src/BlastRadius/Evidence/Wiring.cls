/// Reads the production definition as data: the same source the production diagram uses.
Class BlastRadius.Evidence.Wiring Extends %RegisteredObject
{

/// The production being reviewed: the running one.
ClassMethod ProductionName() As %String
{
	do ##class(Ens.Director).GetProductionStatus(.name,.state)
	if name="" set name="DemoHospital.Production"
	quit name
}

/// Items that are part of the production under review. The review tool's own items are left out.
ClassMethod Items(ByRef pItems) As %Status
{
	kill pItems
	set prod=##class(Ens.Config.Production).%OpenId(..ProductionName(),,.sc)
	quit:$$$ISERR(sc) sc
	for i=1:1:prod.Items.Count() {
		set item=prod.Items.GetAt(i)
		continue:item.Category="BlastRadius"
		set pItems(item.Name)=item
	}
	quit $$$OK
}

/// Outbound links the configuration declares for one item, including routing rule targets.
ClassMethod Outbound(pItem As Ens.Config.Item, ByRef pTargets)
{
	kill pTargets
	try {
		set conn=""
		do $classmethod(pItem.ClassName,"OnGetConnections",.conn,pItem)
		set t=""
		for { set t=$order(conn(t)) quit:t=""  set pTargets(t)="" }
	} catch ex {}
}

/// JSON summary of every item whose name or comment mentions one of the words. No words means every item.
ClassMethod Find(pWords As %String) As %DynamicObject
{
	set out=[]
	set sc=..Items(.items)
	set words=$zconvert($translate(pWords,",;","  "),"U")
	set name=""
	for {
		set name=$order(items(name),1,item) quit:name=""
		set hay=$zconvert(name_" "_item.Comment_" "_item.ClassName,"U")
		set hit=(words="")
		for w=1:1:$length(words," ") {
			set word=$piece(words," ",w)
			if ($length(word)>2),(hay[word) set hit=1
		}
		continue:'hit
		do out.%Push(..Describe(item))
	}
	quit {"production":(..ProductionName()),"items":(out),"count":(out.%Size())}
}

ClassMethod Describe(pItem As Ens.Config.Item) As %DynamicObject
{
	set o={"name":(pItem.Name),"class":(pItem.ClassName),"category":(pItem.Category),"enabled":(pItem.Enabled),"comment":(pItem.Comment)}
	do o.%Set("enabled",pItem.Enabled,"boolean")
	do pItem.GetModifiedSetting("BusinessPartner",.partner)
	do o.%Set("owner",$get(partner))
	quit o
}

/// Configured links in both directions for one item.
ClassMethod Links(pName As %String) As %DynamicObject
{
	set sc=..Items(.items)
	quit:'$data(items(pName)) {"item":(pName),"found":false,"error":"No such item in the production"}
	set inbound=[], outbound=[]
	do ..Outbound(items(pName),.targets)
	set t="" for { set t=$order(targets(t)) quit:t=""  do outbound.%Push(t) }
	set name=""
	for {
		set name=$order(items(name),1,item) quit:name=""
		do ..Outbound(item,.targets)
		continue:'$data(targets(pName))
		set row={"sender":(name)}
		do row.%Set("enabled",item.Enabled,"boolean")
		do inbound.%Push(row)
	}
	set res={"item":(pName),"found":true,"configured_senders":(inbound),"configured_targets":(outbound)}
	quit res
}

/// True when the configuration declares a link from pSender to pTarget.
ClassMethod IsConfigured(pSender As %String, pTarget As %String) As %Boolean
{
	set sc=..Items(.items)
	quit:'$data(items(pSender)) 0
	do ..Outbound(items(pSender),.targets)
	quit $data(targets(pTarget))>0
}

/// Transforms named by an item's routing rule.
ClassMethod TransformsOf(pName As %String) As %DynamicObject
{
	set sc=..Items(.items)
	quit:'$data(items(pName)) {"item":(pName),"found":false,"transforms":[]}
	set out=[]
	do items(pName).GetModifiedSetting("BusinessRuleName",.rule)
	if $get(rule)'="" {
		set xd=##class(%Dictionary.CompiledXData).%OpenId(rule_"||RuleDefinition")
		if $isobject(xd) {
			set text=xd.Data.Read(1000000)
			set m=##class(%Regex.Matcher).%New("transform=""([^""]+)""",text)
			while m.Locate() { do out.%Push(m.Group(1)) }
		}
	}
	quit {"item":(pName),"found":true,"rule":($get(rule)),"transforms":(out)}
}

/// Every data transform class in this namespace, with the first line of its description.
ClassMethod ListTransforms() As %DynamicObject
{
	set out=[]
	set rs=##class(%Dictionary.ClassDefinitionQuery).SubclassOfFunc("Ens.DataTransform")
	while rs.%Next() {
		set c=rs.Name
		// Only this production's own transforms, not the hundreds the platform ships with.
		continue:($extract(c,1,7)="EnsLib.")||($extract(c,1,4)="Ens.")||($extract(c)="%")||($extract(c,1,3)="HS.")||($extract(c,1,5)="HSMOD")||($extract(c,1,4)="HSFH")
		set d=##class(%Dictionary.CompiledClass).%OpenId(c)
		continue:'$isobject(d)
		do out.%Push({"class":(c),"description":($piece(d.Description,$char(13,10),1))})
	}
	quit {"transforms":(out)}
}

/// Named owner of an item, from its Business Partner, and the Workflow role that reaches them.
ClassMethod OwnerOf(pName As %String) As %DynamicObject
{
	set sc=..Items(.items)
	quit:'$data(items(pName)) {"item":(pName),"found":false}
	do items(pName).GetModifiedSetting("BusinessPartner",.partner)
	set partner=$get(partner)
	set contact="", title=""
	if partner'="" {
		set bp=##class(Ens.Config.BusinessPartner).%OpenId(partner)
		if $isobject(bp) { set contact=bp.PrimaryContact.Name, title=bp.PrimaryContact.Title }
	}
	set role=$select(partner="":"",1:##class(Ens.Util.LookupTable).%GetValue("BlastRadiusOwners",partner))
	if role="" set role="Owner-IntegrationLead"
	quit {"item":(pName),"found":true,"partner":(partner),"contact":(contact),"title":(title),"workflow_role":(role)}
}

}
