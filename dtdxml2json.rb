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

def cdata(arr, el)
  arr << {:name => :cdata}
end

def element(arr, el)
  element = {:name => el.attribute('name').value.downcase}
  if el.attribute('occurrence')
    element[:occurrence] = el.attribute('occurrence').value
  end

  arr << {:name => :element, :model => element}
end

def and_group(arr, el)
  and_group = {:children => []}
  if el.attribute('occurrence')
    and_group[:occurrence] = el.attribute('occurrence').value
  end
 
  el.elements.each do |and_group_child|
    case and_group_child.name
    when 'or-group'
      or_group(and_group[:children], and_group_child)

    when 'element-name'
      element(and_group[:children], and_group_child)

    else
      throw 'Unknown child element type (and group).'
    end
  end

  arr << {:name => :andGroup, :model => and_group}
end

def or_group(arr, el)
  or_group = {:children => []}
  if el.attribute('occurrence')
    or_group[:occurrence] = el.attribute('occurrence').value
  end
  
  el.elements.each do |or_group_child|
    case or_group_child.name
    when 'element-name'
      element(or_group[:children], or_group_child)

      next
    when 'pcdata'
      or_group[:children] << {:text => true}

      next
    when 'or-group'
      or_group(or_group[:children], or_group_child)

      next
    else
      throw 'Unknown child element type (or group).'
    end
  end

  arr << {:name => :orGroup, :model => or_group} 
end

def sequence_group(arr, el)
  sequence_group = {:children => []}
  el.elements.each do |seq_group_child|
    case seq_group_child.name
    when 'element-name'
      element(sequence_group[:children], seq_group_child)
      
      next
    when 'or-group'
      or_group(sequence_group[:children], seq_group_child)

      next
    when 'pcdata'
      sequence_group[:children] << {:text => true}

      next
    else
      throw 'Unknown child element type (sequence group).'
    end
  end
  arr << {:name => :sequenceGroup, :model => sequence_group}
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
    :model => {},
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
          and_group(cme, cme_child)

        when 'or-group'
          or_group(cme, cme_child)

        when 'sequence-group'
          sequence_group(cme, cme_child)

        when 'cdata'
          cdata(cme, cme_child)

        else
          throw 'Unknown child element type (content model expanded).'
        end
      end
      element[:model][:expanded] = cme

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
      element[:model][:inclusions] = incs

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
      element[:model][:exclusions] = excs
    else
      throw 'Unknown child element type'
    end
  end

  obj[name.downcase] = element
end

def add_attlist(obj, el)
  el.elements.each do |child|
    next if child.name == 'attdecl'

    name = child.attribute('name').value.downcase
    type = child.attribute('type').value.downcase
    default = child.attribute('default').value.downcase
    value = child.attribute('value').value.downcase

    obj[:attributes][name] = {:default => default, :type => type, :value => value}
  end
end

dtd_name = ARGV[0]
if dtd_name.nil?
  puts "No .dtd.xml file given as parameter?"
  exit
end

dtd_json = {:entity => {}, :element => {}}
doc = REXML::Document.new(File.read(dtd_name))

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

puts dtd_json.to_json
