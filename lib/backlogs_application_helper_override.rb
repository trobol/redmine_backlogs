ApplicationHelper.module_eval do
  # Original generates a link to a version
  # Now generate a link to a sprint
  alias_method :link_to_version_without_backlogs, :link_to_version
  alias_method :format_object_without_backlogs, :format_object

  def link_to_version(version, options = {})
    return '' unless version && version.is_a?(Version)

    return link_to_version_without_backlogs(version, options) unless Backlogs.configured?

    link_to_sprint(version, options.merge({team: true}))
  end

  def format_object_custom_field(object, html=true, &block)
    return object.value.to_s unless object.custom_field

    if object.custom_field.id == Backlogs.setting[:show_backlog_story_marker_support_id].to_i && object.value.present?
      string = ""
      object.value.split(/[\s,]+/).each_with_index do |case_id, i|
        if case_id.starts_with?(Backlogs.setting[:support_id_URL_start_match])
          string+= "<a href='#{object.custom_field.format_store[:url_pattern]}#{case_id}' target='_blank'>#{case_id}</a>"
        else
          string += case_id
        end
        string += ', ' unless i == object.value.split(/[\s,]+/).size - 1
      end
      f = string.html_safe
    else
      f = object.custom_field.format.formatted_custom_value(self, object, html)
    end

    if f.nil? || f.is_a?(String)
      return f
    else
      return format_object_without_backlogs(f, html, &block)
    end
  end
  
  def format_object(object, html=true, &block)
    if object.class.name == 'CustomFieldValue' || object.class.name == 'CustomValue'
      format_object_custom_field(object, html, &block)
    elsif object.class.name == 'User' && params[:controller] == 'rb_refine_stories'
      link_to "#{object.to_s}", project_issues_path({"set_filter"=>"1", "sort"=>"id:desc", "f"=>["status_id", "assigned_to_id", ""], "op"=>{"status_id"=>"=", "assigned_to_id"=>"="}, "v"=>{"status_id"=>Backlogs.setting[:status_for_validating], "assigned_to_id"=>["#{object.id}"]}, "t"=>[""]})
    else
      format_object_without_backlogs(object, html, &block)
    end 
  end

end
