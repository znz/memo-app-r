# frozen_string_literal: true

module ApplicationHelper
  def full_title(page_title = "")
    base_title = I18n.t(:"nav.site_name")
    if page_title.empty?
      base_title
    else
      "#{page_title} | #{base_title}"
    end
  end

  def nav_link_to(name, path, link_options: {})
    active = request.path == path
    nav_item_html_class = active ? "nav-item active" : "nav-item"
    tag.li class: nav_item_html_class do
      link_to path, class: "nav-link", **link_options do
        if active
          h(name) + tag.span("(current)", class: "sr-only")
        else
          name
        end
      end
    end
  end

  def make_link(text)
    out = "".html_safe
    link = false
    text.split(/\b(https?:[^\s"']+)/) do |s|
      out << if link
        tag.a(href: s) { s }
      else
        s
      end
      link = !link
    end
    out
  end

  def format_content(text, type)
    return unless text
    case type
    when :auto
      case text
      when /```/ # markdown
        tag.pre { tag.code { text } }
      when /</ # html
        simple_format text
      else
        simple_format text
      end
    when :simple_format
      simple_format(make_link(text))
    when :oneline
      make_link(text)
    else
      text
    end
  end
end
