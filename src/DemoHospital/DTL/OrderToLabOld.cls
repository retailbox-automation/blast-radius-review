/// Current transform to the legacy lab: copies the order and stamps the receiving application.
Class DemoHospital.DTL.OrderToLabOld Extends Ens.DataTransformDTL [ DependsOn = EnsLib.HL7.Message ]
{

Parameter IGNOREMISSINGSOURCE = 1;

XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]
{
<transform sourceClass='EnsLib.HL7.Message' targetClass='EnsLib.HL7.Message' sourceDocType='2.5:ORM_O01' targetDocType='2.5:ORM_O01' create='copy' language='objectscript' >
<assign value='"LAB-OLD"' property='target.{MSH:ReceivingApplication}' action='set' />
</transform>
}

}
