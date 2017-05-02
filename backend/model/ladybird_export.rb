class LadybirdExport

  COLUMNS = [
    {:header => "{F1}",                :proc => Proc.new {|row| ''}},
    {:header => "{F2}",                :proc => Proc.new {|row| ''}},
    {:header => "{F3}",                :proc => Proc.new {|row| ''}},
    {:header => "{F4}",                :proc => Proc.new {|row| ''}},
    {:header => "{F5}",                :proc => Proc.new {|row| ''}},
    {:header => "{F6}",                :proc => Proc.new {|row| ''}},
    {:header => "{F20}",               :proc => Proc.new {|row| ''}},
    {:header => "{F21}",               :proc => Proc.new {|row| ''}},
    # Local record ID {fdid=56}
    {:header => "{fdid=56}",           :proc => Proc.new {|row| local_record_id(row)}},
    # Call number {fdid=58}
    {:header => "{fdid=58}",           :proc => Proc.new {|row| call_number(row)}},
    # Box {fdid=60}
    {:header => "{fdid=60}",           :proc => Proc.new {|row| box(row)}},
    # Folder {fdid=61}
    {:header => "{fdid=61}",           :proc => Proc.new {|row| folder(row)}},
    # Host, Creator {fdid=62}
    {:header => "{fdid=62}",           :proc => Proc.new {|row, export| host_creator(row, export)}},
    # Host, Title {fdid=63}
    {:header => "{fdid=63}",           :proc => Proc.new {|row| host_title(row)}},
    # Host, note {fdid=68}
    {:header => "{fdid=68}",           :proc => Proc.new {|row, export| host_note(row, export)}},
    # Creator {fdid=69}
    {:header => "{fdid=69}",           :proc => Proc.new {|row, export| creator(row, export)}},
    # Title {fdid=70}
    {:header => "{fdid=70}",           :proc => Proc.new {|row, export| title(row, export)}},
    {:header => "{fdid=79}",           :proc => Proc.new {|row| ''}},
    {:header => "{fdid=82}",           :proc => Proc.new {|row| ''}},
    {:header => "{fdid=84}",           :proc => Proc.new {|row| ''}},
    # Note {fdid=86}
    {:header => "{fdid=86}",           :proc => Proc.new {|row, export| note(row, export)}},
    # Abstract {fdid=87}
    {:header => "{fdid=87}",           :proc => Proc.new {|row, export| abstract(row, export)}},
    {:header => "{fdid=88}",           :proc => Proc.new {|row| ''}},
    {:header => "{fdid=90}",           :proc => Proc.new {|row| ''}},
    {:header => "{fdid=91}",           :proc => Proc.new {|row| ''}},
    {:header => "{fdid=98}",           :proc => Proc.new {|row| ''}},
    {:header => "{fdid=99}",           :proc => Proc.new {|row| ''}},
    {:header => "{fdid=100}",           :proc => Proc.new {|row| ''}},
    {:header => "{fdid=102}",           :proc => Proc.new {|row| ''}},
    {:header => "{fdid=103}",           :proc => Proc.new {|row| ''}},
    # Barcode {fdid=105}
    {:header => "{fdid=105}",           :proc => Proc.new {|row| barcode(row)}},
    {:header => "{fdid=106}",           :proc => Proc.new {|row| ''}},
    {:header => "{fdid=156}",           :proc => Proc.new {|row| ''}},
    {:header => "{fdid=180}",           :proc => Proc.new {|row| ''}},
    {:header => "{fdid=187}",           :proc => Proc.new {|row| ''}},
    {:header => "{fdid=275}",           :proc => Proc.new {|row| ''}},
    {:header => "{fdid=280}",           :proc => Proc.new {|row| ''}},
    {:header => "{fdid=288}",           :proc => Proc.new {|row| ''}},
  ]

  def initialize(uris)
    @uris = uris
    @ids = archival_object_ids
  end

  def to_stream
    rows = []

    dataset.each do |row|
      result = {}
      COLUMNS.map {|col|
        result[col.fetch(:header)] = col[:proc].call(row, self)
      }
      rows << result
    end

    rows.to_json
  end

  def creators_for_archival_object(id)
    creators = []

    @agents.each do |row|
      if row[:archival_object_id] == id
        creators << (row[:person] || row[:corporate_entity] || row[:family] || row[:software])
      end
    end

    creators
  end

  def creators_for_resource(id)
    creators = []

    @resource_agents.each do |row|
      if row[:resource_id] == id
        creators << (row[:person] || row[:corporate_entity] || row[:family] || row[:software])
      end
    end

    creators
  end

  def notes_for_archival_object(id)
    notes = {}

    @notes.each do |row|
      if row[:archival_object_id] == id
        note = ASUtils.json_parse(row[:note])

        type = note.fetch('type')
        subnotes = note.fetch('subnotes')

        content = subnotes.collect{|n| n.fetch('content')}

        notes[type] ||= []
        notes[type] << content
      end
    end

    notes
  end

  private

  def dataset
    ds = SubContainer
           .left_outer_join(:instance, :instance__id => :sub_container__instance_id)
           .left_outer_join(:archival_object, :archival_object__id => :instance__archival_object_id)
           .left_outer_join(:resource, :resource__id => :archival_object__root_record_id)
           .left_outer_join(:top_container_link_rlshp, :top_container_link_rlshp__sub_container_id => :sub_container__id)
           .left_outer_join(:top_container, :top_container__id => :top_container_link_rlshp__top_container_id)
           .filter(:instance__archival_object_id => @ids)

    # archival object bits
    ds = ds.select_append(Sequel.as(:archival_object__id, :archival_object_id))
    ds = ds.select_append(Sequel.as(:archival_object__repo_id, :repo_id))
    ds = ds.select_append(Sequel.as(:archival_object__title, :archival_object_title))

    # resource bits
    ds = ds.select_append(Sequel.as(:resource__id, :resource_id))
    ds = ds.select_append(Sequel.as(:resource__identifier, :resource_identifier))
    ds = ds.select_append(Sequel.as(:resource__title, :resource_title))

    # top container bits 
    ds = ds.select_append(Sequel.as(:top_container__indicator, :top_container_indicator))
    ds = ds.select_append(Sequel.as(:top_container__barcode, :top_container_barcode))

    # sub_container bits
    ds = ds.select_append(Sequel.as(:sub_container__indicator_2, :sub_container_folder))

    # linked agents
    creator_enum_id = EnumerationValue
                          .filter(:enumeration_id => Enumeration.filter(:name => 'linked_agent_role').select(:id))
                          .select(:id)

    @agents = ArchivalObject
              .left_outer_join(:linked_agents_rlshp, :linked_agents_rlshp__archival_object_id => :archival_object__id)
              .left_outer_join(:agent_person, :agent_person__id => :linked_agents_rlshp__agent_person_id)
              .left_outer_join(:agent_corporate_entity, :agent_corporate_entity__id => :linked_agents_rlshp__agent_corporate_entity_id)
              .left_outer_join(:agent_family, :agent_family__id => :linked_agents_rlshp__agent_family_id)
              .left_outer_join(:agent_software, :agent_software__id => :linked_agents_rlshp__agent_software_id)
              .left_outer_join(:name_person, :name_person__id => :agent_person__id)
              .left_outer_join(:name_corporate_entity, :name_corporate_entity__id => :agent_corporate_entity__id)
              .left_outer_join(:name_family, :name_family__id => :agent_family__id)
              .left_outer_join(:name_software, :name_software__id => :agent_software__id)
              .filter(:archival_object__id => @ids)
              .and(Sequel.|({:name_person__is_display_name => 1}, {:name_person__is_display_name => nil}))
              .and(Sequel.|({:name_corporate_entity__is_display_name => 1}, {:name_corporate_entity__is_display_name => nil}))
              .and(Sequel.|({:name_family__is_display_name => 1}, {:name_family__is_display_name => nil}))
              .and(Sequel.|({:name_software__is_display_name => 1}, {:name_software__is_display_name => nil}))
              .and(:linked_agents_rlshp__role_id => creator_enum_id)
              .select(Sequel.as(:archival_object__id, :archival_object_id),
                      Sequel.as(:name_person__sort_name, :person),
                      Sequel.as(:name_corporate_entity__sort_name, :corporate_entity),
                      Sequel.as(:name_family__sort_name, :family),
                      Sequel.as(:name_software__sort_name, :software))
              .distinct
              .all

    @resource_agents = Resource
                         .left_outer_join(:linked_agents_rlshp, :linked_agents_rlshp__resource_id => :resource__id)
                         .left_outer_join(:agent_person, :agent_person__id => :linked_agents_rlshp__agent_person_id)
                         .left_outer_join(:agent_corporate_entity, :agent_corporate_entity__id => :linked_agents_rlshp__agent_corporate_entity_id)
                         .left_outer_join(:agent_family, :agent_family__id => :linked_agents_rlshp__agent_family_id)
                         .left_outer_join(:agent_software, :agent_software__id => :linked_agents_rlshp__agent_software_id)
                         .left_outer_join(:name_person, :name_person__id => :agent_person__id)
                         .left_outer_join(:name_corporate_entity, :name_corporate_entity__id => :agent_corporate_entity__id)
                         .left_outer_join(:name_family, :name_family__id => :agent_family__id)
                         .left_outer_join(:name_software, :name_software__id => :agent_software__id)
                         .left_outer_join(:archival_object, :archival_object__root_record_id => :resource__id)
                         .filter(:archival_object__id => @ids)
                         .and(Sequel.|({:name_person__is_display_name => 1}, {:name_person__is_display_name => nil}))
                         .and(Sequel.|({:name_corporate_entity__is_display_name => 1}, {:name_corporate_entity__is_display_name => nil}))
                         .and(Sequel.|({:name_family__is_display_name => 1}, {:name_family__is_display_name => nil}))
                         .and(Sequel.|({:name_software__is_display_name => 1}, {:name_software__is_display_name => nil}))
                         .and(:linked_agents_rlshp__role_id => creator_enum_id)
                         .select(Sequel.as(:resource__id, :resource_id),
                                 Sequel.as(:name_person__sort_name, :person),
                                 Sequel.as(:name_corporate_entity__sort_name, :corporate_entity),
                                 Sequel.as(:name_family__sort_name, :family),
                                 Sequel.as(:name_software__sort_name, :software))
                         .distinct
                         .all

    # linked notes
    @notes = Note
              .filter(:note__archival_object_id => @ids)
              .select(Sequel.as(:note__archival_object_id, :archival_object_id),
                      Sequel.as(:note__notes, :note))
              .all

    ds
  end

  def archival_object_ids
    ids = []

    @uris.each do |uri|
      parsed = JSONModel.parse_reference(uri)

      # only archival_objects
      next unless parsed[:type] == "archival_object"

      ids << parsed[:id]
    end

    ids
  end

  def self.local_record_id(row)
    "/repositories/#{row[:repo_id]}/archival_objects/#{row[:archival_object_id]}"
  end

  def self.call_number(row)
    JSON.parse(row[:resource_identifier]).compact.join('.')
  end

  def self.box(row)
    row[:top_container_indicator]
  end

  def self.barcode(row)
    row[:top_container_barcode]
  end

  def self.folder(row)
    row[:sub_container_folder]
  end

  def self.host_creator(row, export)
    creators = export.creators_for_resource(row[:resource_id])
    creators.join('; ')
  end

  def self.host_title(row)
    row[:resource_title]
  end

  def self.host_note(row, export)
    # FIXME this is a breadcrumb
  end

  def self.note(row, export)
    notes = export.notes_for_archival_object(row[:archival_object_id])

    notes_to_show = []

    notes.map{|type, content|
      next if type == 'scopecontent'
      next if type == 'accessrestrict'

      notes_to_show << content.flatten
    }

    notes_to_show.flatten.join(' | ')
  end

  def self.abstract(row, export)
    notes = export.notes_for_archival_object(row[:archival_object_id])

    notes_to_show = []

    notes.map{|type, content|
      next unless type == 'scopecontent'

      notes_to_show << content.flatten
    }

    notes_to_show.flatten.join(' | ')
  end

  def self.title(row, export)
    # FIXME need to append dates or show date if no title 
    row[:archival_object_title]
  end

  def self.creator(row, export)
    creators = export.creators_for_archival_object(row[:archival_object_id])
    creators.join('; ')
  end

end