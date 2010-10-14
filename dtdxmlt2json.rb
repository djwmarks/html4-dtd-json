#!/usr/bin/env ruby

require('json')
require('rexml/document')

#
# Assumes Ruby 1.9+
#
def extract_keys(string)
  string.gsub(/(^\(|\)$)/, '').split(/\s*\|\s*/)
end

def add_entity(obj, el)
  name = el.attribute('name').value
  type = el.attribute('type').value

  valueEl = el.elements['text-expanded']
  value = valueEl.nil? ? nil : valueEl.text

  case name
  when 'block', 'flow', 'fontstyle', 'formctrl', 'head.misc', 'heading', 'inline',
       'InputType', 'list', 'phrase', 'pre.exclusion', 'Scope', 'Shape', 'special', 
       'TAlign', 'TFrame', 'TRules'
    value = extract_keys(value.downcase)
    obj[name] = {:type => type, :value => value}
  end
end

def or_group(arr, el)
  or_group = {:children => [], :elements => [], :text => false}
  if el.attribute('occurrence')
    or_group[:occurrence] = el.attribute('occurrence').value
  end
  
  el.elements.each do |or_group_child|
    case or_group_child.name
    when 'element-name'
      or_group[:elements] << or_group_child.attribute('name').value.downcase
      next
    when 'pcdata'
      or_group[:text] = true
      next
    when 'or-group'
      or_group(or_group[:children], or_group_child)
      next
    else
      throw 'Unknown child element type (or group).'
    end
  end

  arr << {:orGroup => or_group} 
end

def sequence_group(arr, el)
  sequence_group = {:children => [], :elements => [], :text => false}
  el.elements.each do |seq_group_child|
    case seq_group_child.name
    when 'element-name'
      sequence_group[:elements] << seq_group_child.attribute('name').value.downcase
      
      next
    when 'or-group'
      or_group(sequence_group[:children], seq_group_child)

      next
    when 'pcdata'
      sequence_group[:text] = true

      next
    else
      throw 'Unknown child element type (sequence group).'
    end
  end
  arr << {:sequenceGroup => sequence_group}
end

def add_element(obj, el)
  name = el.attribute('name').value
  start_tag_omit = el.attribute('stagm').value == 'O'
  end_tag_omit = el.attribute('etagm').value == 'O'
  content_type = el.attribute('content-type').value

  element = {
    :attributes => {},
    :cdata => false,
    :childElements => [],
    :contentType => content_type,
    :contentModel => {},
    :empty => false,
    :omitStart=> start_tag_omit,
    :omitEnd => end_tag_omit,
    :text => false
  }

  content_model = el.elements['content-model-expanded']
  if content_model.elements['empty']
    element[:empty] = true
    obj[name.downcase] = element

    return
  end

  el.elements.each do |child|
    case child.name
    when 'content-model-expanded'
      cme = []
      child.elements.each do |cme_child|
        case cme_child.name
        when 'and-group'
          and_group = []
          cme_child.elements.each do |and_group_child|
            case and_group_child
            when 'or-group'
              or_group(and_group, and_group_child)

            when 'element-name'
              and_child = {
                :name => and_group_child.attribute('name').value.downcase,
              }
              if and_group_child.attribute('occurrence') 
                and_child[:occurrence] = and_group_child.attribute('occurrence').value
              end
              and_group << and_child
            end
          end
          cme << {:andGroup => and_group}

        when 'or-group'
          or_group(cme, cme_child)

        when 'sequence-group'
          sequence_group(cme, cme_child)

        when 'cdata'
          element[:cdata] = true

        else
          throw 'Unknown child element type (content model expanded).'
        end
      end
      element[:contentModel][:expanded] = cme

    when 'inclusions'
      incs = []
      child.elements.each do |inc_child|
        case inc_child.name
        when 'or-group'
          or_group(incs, inc_child)

        else
          throw 'Unknown child element type (inclusions).'
        end
      end
      element[:contentModel][:inclusions] = incs

    when 'exclusions'
      excs = []
      child.elements.each do |exc_child|
        case exc_child.name
        when 'or-group'
          or_group(excs, exc_child)

        when 'sequence-group'
          sequence_group(excs, exc_child)

        else
          throw 'Unknown child element type (exclusions).'
        end
      end
      element[:contentModel][:exclusions] = excs
    else
      throw 'Unknown child element type'
    end
  end

  obj[name.downcase] = element
end

def add_attlist(obj, el)
  el.elements.each do |child|
    next if child.name == 'attdecl'

    name = child.attribute('name').value
    type = child.attribute('type').value
    default = child.attribute('default').value
    value = child.attribute('value').value

    obj[:attributes][name] = {:default => default, :type => type, :value => value}
  end
end

['strict', 'loose', 'frameset'].each do |dtd_name|
  dtd_json = {:entity => {}, :element => {}}

  puts ">> #{dtd_name}"
  doc = REXML::Document.new(File.read(dtd_name + '.dtd.xml'))

  doc.root.elements.each('entity') do |entity|
    add_entity(dtd_json[:entity], entity)
  end

  doc.root.elements.each('element') do |element|
    add_element(dtd_json[:element], element)
  end

  doc.root.elements.each('attlist') do |attlist|
    element_name = attlist.attribute('name').value.downcase
    element = dtd_json[:element][element_name]
    if element.nil?
      throw 'Unknown element type: ' + element_name
    end

    add_attlist(element, attlist) 
  end

  File.open(dtd_name + '.json', 'w') do |f|
    f.write(dtd_json.to_json)
  end
end
