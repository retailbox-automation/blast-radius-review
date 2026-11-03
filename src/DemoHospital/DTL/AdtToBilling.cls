/// Current transform to billing.
Class DemoHospital.DTL.AdtToBilling Extends Ens.DataTransformDTL [ DependsOn = EnsLib.HL7.Message ]
{

Parameter IGNOREMISSINGSOURCE = 1;

XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]
{
<transform sourceClass='EnsLib.HL7.Message' targetClass='EnsLib.HL7.Message' sourceDocType='2.5:ADT_A01' targetDocType='2.5:ADT_A01' create='copy' language='objectscript' >
<assign value='"BILLING"' property='target.{MSH:ReceivingApplication}' action='set' />
</transform>
}

}
