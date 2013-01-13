require "libxml"

module RestfulHelper
  def parse_xml(xml)
    LibXML::XML::Document.string(xml).root
  rescue LibXML::XML::Error => ex
    raise XmlValidationError.new(:message => ex.message, :inner_exception => ex)
  end
end
